refresh_source () {
    if [ ! -f "$1" ]; then
        wget "ftp.edrdg.org/pub/Nihongo/$1.gz"
        gunzip -c "$1.gz" > "$1"
        rm "$1.gz"
    else
        rsync "ftp.edrdg.org::nihongo/$1" "$1"
    fi
}

refresh_source "JMdict_e_examp"
refresh_source "JMdict"
refresh_source "JMnedict.xml"
refresh_source "kanjidic2.xml"
refresh_source "examples.utf"
