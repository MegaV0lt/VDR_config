#!/usr/bin/env bash

# rec_genindex.sh
#
# Skript zum Erstellen der Indexdateie für einen Recording-Ordner. Wird kein Parameter übergeben
# wird das Video-Verzeichniss gescannt. Das Skript kann auch als Cronjob ausgeführt werden.
# Author: MegaV0lt @ VDR-Portal

# Variablen
LOG_FILE="/var/log/rec_genindex.log"  # Log-Datei
USER='vdr'  # Benutzer, unter dem das Skript ausgeführt wird

# shellcheck disable=SC1090
source /_config/bin/yavdr_funcs.sh &>/dev/null

# Prüfen, ob ein Verzeichnis übergeben wurde
if [[ -n "$1" ]] ; then
    if [[ ! -d "$1" ]] ; then
        f_log "Fehler: '$1' ist kein Verzeichnis"
        exit 1
    fi
    # Indexdatei erstellen (Im Hintergrund, damit das Skript nicht blockiert wird)
    f_log "Erstelle Indexdatei für Aufnahme '$1'"
    f_detach ionice -n 3 vdr --genindex "$1"
else  # Kein Parameter übergeben
    # Video-Verzeichniss (/video) scannen
    if [[ -d "$VIDEO" ]] ; then  # Aus der VDR-Konfiguration
        f_log "Kein Verzeichnis übergeben, scanne '$VIDEO'"
        # Nach VDR-Aufnahmen suchen (*.rec)
        mapfile -d '' -t RECORDINGS < <(find "$VIDEO"/ -maxdepth 4 -type d -name '*.rec' -print0 2>/dev/null)
        if [[ ${#RECORDINGS[@]} -eq 0 ]] ; then
            f_log "Fehler: Keine Aufnahmen im Verzeichnis '$VIDEO' gefunden"
            exit 1
        fi
        # Nach der Datei index suchen und index erstellen, wenn kein index vorhanden ist
        for rec in "${RECORDINGS[@]}" ; do
            if [[ ! -f "$rec/index" ]] ; then
                f_log "Erstelle Indexdatei für Aufnahme '$rec'"
                ionice -n 3 vdr --genindex "$rec" | f_log2
                # Wenn nicht unter vdr ausgeführt wird, muss die Datei index auf den Benutzer vdr gesetzt werden
                if [[ "$(id -un)" != "$USER" ]] ; then
                    if [[ -e "$rec/index" ]] ; then
                        chown "$USER":"$USER" "$rec/index"
                    else
                        f_log "Fehler: Indexdatei für Aufnahme '$rec' konnte nicht erstellt werden"
                    fi
                fi
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
