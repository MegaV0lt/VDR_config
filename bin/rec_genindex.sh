#!/usr/bin/env bash

# rec_genindex.sh
#
# Skript zum Erstellen der Indexdateie für einen Recording-Ordner.
# Author: MegaV0lt @ VDR-Portal

# shellcheck disable=SC1090
source /_config/bin/yavdr_funcs.sh &>/dev/null

# Prüfen, ob ein Verzeichnis übergeben wurde
if [[ -z "$1" ]] ; then
    f_log "Usage: $0 <directory>"
    exit 1
fi

vdr --genindex "$1" | f_log2
