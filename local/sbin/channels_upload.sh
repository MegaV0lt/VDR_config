#!/bin/bash

# channels_upload.sh - Kanalliste des VDR nach Sat-Positionen trennen und in
#+                     die DropBox laden.
# Author: MegaV0lt
VERSION=211027

### Einstellungen
SEPCHANNELS='/usr/local/sbin/sepchannels.sh'      # Skript zum erzeugen der Kanalliste
SATPOS=('19.2E')                                  # Welche Sat-Positionen speichern?
DBUPLOADER='/usr/local/sbin/dropbox_uploader.sh'  # Skript zum Upload in die DropBox
DESTDIR='/Public/VDR/channels'                    # Zielordner in der DropBox
CHANDIR='/etc/vdr'                                # Kanallisten-Verzeichnis

### Funktionen
f_log() {     # Gibt die Meldung auf der Konsole oder im Syslog aus
  [[ -t 1 ]] && { echo "$*" ;} || logger -t "$(basename ${0%.*})" "$*"
}

### Skript start!
if [[ -n "$1" ]] ; then  # Falls dem Skript Parameter übergeben wurden.
  SATPOS="$*"
fi

if [[ -e "$SEPCHANNELS" && -e "$DBUPLOADER" ]] ; then
  "$SEPCHANNELS" "${SATPOS[@]}"  # Kanalliste(n) erzeugen
  sleep 1                        # Kurz warten
  for FILE in "${CHANDIR}/channels."* ; do  # Alle channels.* hochladen
    case "$FILE" in
      *.new|*.removed|*.bak|*.old) f_log "Überspringe $FILE" ;;
      *) f_log "Upload: $FILE"
         "$DBUPLOADER" upload "$FILE" "${DESTDIR}/$(basename ${FILE})" >/dev/null ;;
    esac
  done
else
  f_log 'FATAL: Skript(e) nicht gefunden!'
  exit 1
fi

exit
