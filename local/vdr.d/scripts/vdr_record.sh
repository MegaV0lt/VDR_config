#!/usr/bin/env bash
#
# vdr_record.sh
#
# Wird vom VDR aufgerufen bei Start und Ende von Aufnahmen, so wie bei Schnitt
# oder wenn eine Aufnahme gelöscht wird. Aufgerufene Skripte müssen im Hintergrund laufen!
# Beispiel: 'skript.sh &>/dev/null & disown' oder mit 'screen', '| at now'

# VERSION=250516

source /_config/bin/yavdr_funcs.sh >/dev/null

if ! declare -F f_logger >/dev/null ; then
  f_logger() { logger -t yaVDR "vdr_record.sh: $*" ;}
fi

VDR_SCRIPT_DIR='/etc/vdr.d/scripts'  # Verzeichnis der Skripte

[[ "$LOG_LEVEL" -gt 2 ]] && f_logger "Parameters: $*"

case "$1" in
  before)  # Vor einer Aufnahme
    # echo "Before recording $2"
    # 'Aufnahme' Meldung anzeigen
    "${VDR_SCRIPT_DIR}/vdr_rec_msg.sh" "$1" "$2" &>/dev/null & disown
    ;;
  started)  # Ein paar Sekunden nach dem Aufnahmestart
    # echo "Started recording $2"
    # Daten zur Aufnahme sammeln
    "${VDR_SCRIPT_DIR}/vdr_checkrec.sh" "$1" "$2" &>/dev/null & disown
    # Epg Bilder kopieren
    "${VDR_SCRIPT_DIR}/vdr_copyepgimages.sh" "$1" "$2" &>/dev/null & disown
    ;;
  after)  # Nach einer Aufnahme
    # echo "After recording $2"
    # 'Beednet' Meldung anzeigen
    "${VDR_SCRIPT_DIR}/vdr_rec_msg.sh" "$1" "$2" &>/dev/null &
    # Aufnahme auf SxxExx und Vollsändigkeit prüfen
    "${VDR_SCRIPT_DIR}/vdr_checkrec.sh" "$1" "$2" &>/dev/null &
    disown -a  # Alle Jobs
    ;;
  editing)  # Vor dem editieren einer Aufnahme
    # echo "Editing recording $2"
    # echo "Source recording $3"
    ;;
  edited)  # Nach dem editieren einer Aufnahme
    # echo "Edited recording $2"
    # echo "Source recording $3"
    # Dateien von TVScraper und epg2vdr zur editierten Aufnahme kopieren
    files=(banner.jpg fanart.jpg poster.jpg tvscraper.json tvscrapper.json)  # TVScraper
    files+=(info.epg2vdr)   # epg2vdr
    for file in "${files[@]}" ; do
      [[ -e "${3}/${file}" ]] && cp --archive --update "${3}/${file}" "${2}"
    done
    # Epg Bilder kopieren
    "${VDR_SCRIPT_DIR}/vdr_copyepgimages.sh" "$1" "$2" "$3" &>/dev/null & disown
    ;;
  deleted)  # Nach dem löschen einer Aufnahme
    # echo "Deleted recording $2"
    #if [[ -L "$2" ]] ; then  # Testen ob es ein Symlink ist
    #  LNK="$(readlink "$2")"             # Ziel des Links merken
    #  if [[ -d "$LNK" ]] ; then          # Ist ein Verzeichnis
    #    mv "$LNK" "${LNK%.rec}.del"      # Umbenennen -> *.del
    #    ln -s --force -n "${LNK%.rec}.del" "$2"  # Symlink ersetzen
    #    f_logger "Linkziel von $2 wurde angepasst (-> ${LNK%.rec}.del)"
    #  fi # -d
    #fi # -L
    # Prüfen ob 00001.ts ein Symlink ist (Enigma2 Aufnahme)
    if [[ -L "${2}/00001.ts" ]] ; then
      ENIGMA_LINK="$(readlink "${2}/00001.ts")"  # Ziel des Links merken -> ../../../movie/Filmname.ts
      # Move .ts and associated files to trashcan directory in /media/hdd/movie/trashcan
      TRASHCAN_DIR="${ENIGMA_LINK%/movie/*}/movie/trashcan"
      if [[ -d "$TRASHCAN_DIR" ]] ; then
        REC_NAME="${ENIGMA_LINK%.ts}"
        # Move main .ts file to trashcan
        mv "${REC_NAME}.ts" "$TRASHCAN_DIR"
        # Check for part files (Name_001.ts, Name_002.ts, ...)
        for ((i=1; i<1000; i++)); do
          if [[ -f "${REC_NAME}_$(printf '%03d' $i).ts" ]] ; then
            mv "${REC_NAME}_$(printf '%03d' $i).ts" "${TRASHCAN_DIR}" || {
              f_logger "Error: Failed to move ${REC_NAME}_$(printf '%03d' $i).ts to $TRASHCAN_DIR"
            }
            f_logger "Moved ${REC_NAME}_$(printf '%03d' $i).ts to trashcan: ${TRASHCAN_DIR}"
          else
            break  # No more part files found
          fi
        done
        # Move associated files to trashcan
        for ext in .meta .eit .ts.ap .cuts .sc ; do
          mv "${REC_NAME}${ext}" "$TRASHCAN_DIR"
        done
        f_logger "Moved Enigma2 recording $ENIGMA_LINK to $TRASHCAN_DIR"
      else
        f_logger "Error: Trashcan directory $TRASHCAN_DIR does not exist. Cannot move Enigma2 recording $ENIGMA_LINK."
      fi
    fi
    ;;
  copying)
    # echo "Destination recording $2"
    # echo "Source recording $3"
    ;;
  copied)
    # echo "Destination recording $2"
    # echo "Source recording $3"
    ;;
  renamed)
    # echo "New name of recording $2"
    # echo "Old name of recording $3"
    ;;
  moved)  # Nach dem verschieben einer Aufnahme via VDR
    # echo "New path of recording $2"
    # echo "Old path of recording $3"
    ;;
  *) f_logger -s "ERROR: Unknown state: $1" ;;
esac

exit
