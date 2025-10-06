#!/usr/bin/env fish

######################################################################
#
# Copyright (c) 2025 Stephen Kraus
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
######################################################################

function _usage
    echo >&2
    echo "Usage: fetch.fish    " >&2
    echo "    -h | --help      " >&2
    echo "    -f | --file=FILE " >&2
    echo "    -d | --date=DATE " >&2
    echo "    -l | --latest    " >&2
    echo >&2
end

function _argparse_help
    argparse -i h/help -- $argv

    if set -q _flag_help
        _usage
        return 1
    end
end

function _argparse_file
    argparse -i \
        'f/file=!string match -rq \'^JMdict|JMnedict.xml|kanjidic2.xml$\' "$_flag_value"' \
        -- $argv

    if set -q _flag_file
        echo $_flag_file
    else
        echo -e "\nFILE must be one of JMdict JMnedict.xml kanjidic2.xml" >&2
        _usage
        return 1
    end
end

function _argparse_date
    argparse -i \
        'd/date=!string match -rq \'^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$\' "$_flag_value"' \
        l/latest \
        -- $argv

    if set -q _flag_date
        echo "$_flag_date"
    else if not set -q _flag_latest
        echo -e "\nEither DATE or --latest flag must be specified" >&2
        _usage
        return 1
    end
end

function _get_file_dir -a file_name
    echo "$file_name" | tr '.' _
end

function _get_patchfile -a file_name file_date
    set file_dir (_get_file_dir "$file_name")
    echo "$file_dir"/patches/(echo "$file_date" | tr '-' '/').patch.br
end

function _ensure_patch_exists -a file_name file_date
    set patchfile (_get_patchfile "$file_name" "$file_date")

    if not test -e "$patchfile"
        echo -e "\nNo patch exists for file $file_name date $file_date\n" >&2
        return 1
    end
end

function _make_patched_file -a file_name file_date
    set tmp_dir /tmp/(uuidgen)
    set file_dir (_get_file_dir "$file_name")
    set final_patchfile (_get_patchfile "$file_name" "$file_date")

    mkdir -p "$tmp_dir"

    brotli --decompress "$file_dir"/"$file_name".br \
        --output="$tmp_dir"/"$file_name"

    for patchfile in "$file_dir"/patches/**.patch.br
        brotli --force --decompress "$patchfile" \
            --output="$tmp_dir"/next.patch

        set -l patch_date ( \
            grep "^+++ " "$tmp_dir"/next.patch | \
            grep -Eo "[0-9]{4}-[0-9]{2}-[0-9]{2}\$")

        echo "Patching $file_name to version $patch_date"

        patch --quiet \
            "$tmp_dir"/"$file_name" <"$tmp_dir"/next.patch

        if test -n "$file_date" -a "$patchfile" = "$final_patchfile"
            break
        end
    end

    if test -n "$file_date"
        set out_dir patched_files/"$file_date"
    else
        set out_dir patched_files/latest
    end

    mkdir -p "$out_dir"
    brotli -4f "$tmp_dir"/"$file_name" \
        --output="$out_dir"/"$file_name".br

    rm -r "$tmp_dir"
end

function main
    _argparse_help $argv; or return 0

    set file_name (_argparse_file $argv; or return 1)
    set file_date (_argparse_date $argv; or return 1)

    if test -n "$file_date"
        _ensure_patch_exists "$file_name" "$file_date"
        or return 1
    end

    _make_patched_file "$file_name" "$file_date"
    or return 1
end

main $argv
