#!/usr/bin/env bash

# rec_genindex.sh
#
# Skript zum Erstellen der Indexdateie für einen Recording-Ordner. Wird kein Parameter übergeben
# wird das Video-Verzeichniss gescannt. Das Skript kann auch als Cronjob ausgeführt werden.
# Author: MegaV0lt @ VDR-Portal

# Variablen
LOG_FILE="/var/log/rec_genindex.log"  # Log-Datei

# shellcheck disable=SC1090
source /_config/bin/yavdr_funcs.sh &>/dev/null

# Prüfen, ob ein Verzeichnis übergeben wurde
if [[ -n "$1" ]] ; then
    if [[ ! -d "$1" ]] ; then
        f_log "Fehler: '$1' ist kein Verzeichnis"
        exit 1
    fi
    # Indexdatei erstellen
    ionice -n 3 vdr --genindex "$1" | f_log2
else  # Kein Parameter übergeben
    # Video-Verzeichniss (/video) scannen
    if [[ -d "$VIDEO" ]] ; then  # Aus der VDR-Konfiguration
        f_log "Kein Verzeichnis übergeben, scanne '$VIDEO'"
        # Nach VDR-Aufnahmen suchen (*.rec)
        RECORDINGS=$(find "$VIDEO" -type d -name "*.rec")
        if [[ -z "$RECORDINGS" ]] ; then
            f_log "Fehler: Keine Aufnahmen im Verzeichnis '$VIDEO' gefunden"
            exit 1
        fi
        # Nach der Datei index suchen und index erstellen, wenn kein index vorhanden ist
        for rec in "${RECORDINGS[@]}" ; do
            if [[ ! -f "$rec/index" ]] ; then
                f_log "Erstelle Indexdatei '$rec'"
                ionice -n 3 vdr --genindex "${rec%/index}" | f_log2
            fi
        done
    else
        f_log "Fehler: Kein Verzeichnis übergeben und VIDEO ist nicht gesetzt"
        exit 1
    fi
fi

# Log rotieren, wenn zu groß
f_rotate_log "$LOG_FILE"

exit
