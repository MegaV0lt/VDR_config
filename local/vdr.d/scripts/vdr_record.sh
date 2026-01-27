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
    # Prüfen ob .linked_from_enigma2 Datei existiert
    if [[ -e "${2}/.linked_from_enigma2" ]] ; then
      "${VDR_SCRIPT_DIR}/vdr_del_enigma2_recording.sh" "$2" &>/dev/null & disown
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
