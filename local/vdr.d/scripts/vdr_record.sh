#!/usr/bin/env bash
#
# vdr_record.sh
#
# Wird vom VDR aufgerufen bei Start und Ende von Aufnahmen, so wie bei Schnitt
# oder wenn eine Aufnahme gelöscht wird. Aufgerufene Skripte müssen im Hintergrund laufen!
# Beispiel: 'skript.sh &>/dev/null & disown' oder mit 'screen', '| at now'

# VERSION=240207

source /_config/bin/yavdr_funcs.sh

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
    ;;
  after)  # Nach einer Aufnahme
    # echo "After recording $2"
    # 'Beednet' Meldung anzeigen
    "${VDR_SCRIPT_DIR}/vdr_rec_msg.sh" "$1" "$2" &>/dev/null &
    # Aufnahme auf SxxExx und Vollsändigkeit prüfen
    "${VDR_SCRIPT_DIR}/vdr_checkrec.sh" "$1" "$2" &>/dev/null &
    disown -a  # Alle Jobs

    # TVScraper Bild(er) verlinken, falls vorhanden
    files=(banner.jpg poster.jpg fanart.jpg)  # Bilder in der angegebenen Reihenfolge testen
    for file in "${files[@]}" ; do
      if [[ -e "${2}/${file}" ]] ; then
        ln --relative --symbolic "${2}/${file}" "${2}/cover_vdr.jpg"
        break
      fi
    done

    #INFO="$2/info"
    #[[ ! -e "$INFO" ]] && INFO="$2/info.vdr"
    #EVENTID="$(grep "^E " "$INFO" | cut -f 2 -d " ")"
    #if [[ -n "$EVENTID" ]] ; then
    #  [[ -e "${EPG_IMAGES}/${EVENTID}.jpg" ]] && cp "${EPG_IMAGES}/${EVENTID}"*.jpg "$2" && ln -s "${EVENTID}.jpg" "$2/Cover-Enigma.jpg"
    #  [[ -e "${EPG_IMAGES}/${EVENTID}.png" ]] && cp "${EPG_IMAGES}/${EVENTID}"*.png "$2" && ln -s "${EVENTID}.png" "$2/Cover-Enigma.png"
    #fi
    ;;
  editing)  # Vor dem editieren einer Aufnahme
    # echo "Editing recording $2"
    # echo "Source recording $3"
    ;;
  edited)  # Nach dem editieren einer Aufnahme
    # echo "Edited recording $2"
    # echo "Source recording $3"
    # Dateien von TVScraper und epg2vdr zur editierten Aufnahme kopieren
    files=(banner.jpg fanart.jpg poster.jpg tvscrapper.json)  # TVScraper
    files+=(cover_vdr.jpg)                                    # Verlinktes Bild vom TVScraper (Siehe oben)
    files+=(info.epg2vdr)                                     # epg2vdr
    for file in "${files[@]}" ; do
      [[ -e "${3}/${file}" ]] && cp --archive --update "${3}/${file}" "${2}"
    done

    #if [[ -n "$3" ]] ; then         # VDR > 1.7.31
    #   [[ -e "${3}/Cover-Enigma.jpg" ]] && cp -a "${3}"/*.jpg "$2"
    #   [[ -e "${3}/Cover-Enigma.png" ]] && cp -a "${3}"/*.png "$2"
    #fi
    #[[ -z "${PLUGINS/* rectags */}" ]] && sendvdrkey.sh RED
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
