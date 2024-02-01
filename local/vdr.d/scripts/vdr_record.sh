#!/usr/bin/env bash
#
# vdr_record.sh
#
# Wird vom VDR aufgerufen bei Start und Ende von Aufnahmen, so wie bei Schnitt
# oder wenn eine Aufnahme gelöscht wird. Aufgerufene Skripte müssen im Hintergrund laufen!
# Beispiel: 'skript.sh &>/dev/null & disown' oder mit 'screen', '| at now'

# VERSION=231113

source /_config/bin/yavdr_funcs.sh

VDR_SCRIPT_DIR='/etc/vdr.d/scripts'  # Verzeichnis der Skripte

[[ "$LOG_LEVEL" -gt 2 ]] && f_logger "Parameters: $*"

case "$1" in
  before)
    "${VDR_SCRIPT_DIR}/vdr_rec_msg.sh" "$1" "$2" &>/dev/null & disown
    ;;
  started)  # few seconds after recording has started
    "${VDR_SCRIPT_DIR}/vdr_checkrec.sh" "$1" "$2" &>/dev/null & disown
    ;;
  after)
    "${VDR_SCRIPT_DIR}/vdr_rec_msg.sh" "$1" "$2" &>/dev/null &
    "${VDR_SCRIPT_DIR}/vdr_checkrec.sh" "$1" "$2" &>/dev/null &
    disown -a  # Alle Jobs

    #INFO="$2/info"
    #[[ ! -e "$INFO" ]] && INFO="$2/info.vdr"
    #EVENTID="$(grep "^E " "$INFO" | cut -f 2 -d " ")"
    #if [[ -n "$EVENTID" ]] ; then
    #  [[ -e "${EPG_IMAGES}/${EVENTID}.jpg" ]] && cp "${EPG_IMAGES}/${EVENTID}"*.jpg "$2" && ln -s "${EVENTID}.jpg" "$2/Cover-Enigma.jpg"
    #  [[ -e "${EPG_IMAGES}/${EVENTID}.png" ]] && cp "${EPG_IMAGES}/${EVENTID}"*.png "$2" && ln -s "${EVENTID}.png" "$2/Cover-Enigma.png"
    #fi
    ;;
  cut)  # When cutting a recording
    ;;
  edited)
    # Copy files from TVScraper and epg2vdr to edited recording
    files=(fanart.jpg poster.jpg tvscrapper.json)  # TVScraper
    files+=(info.epg2vdr)                          # epg2vdr
    for file in "${files[@]}" ; do
      [[ -e "${3}/${file}" ]] && cp --archive --update "${3}/${file}" "${2}"
    done

    #if [[ -n "$3" ]] ; then         # VDR > 1.7.31
    #   [[ -e "${3}/Cover-Enigma.jpg" ]] && cp -a "${3}"/*.jpg "$2"
    #   [[ -e "${3}/Cover-Enigma.png" ]] && cp -a "${3}"/*.png "$2"
    #else
    #   ODIR="${2//\/%//}"  # /% durch / ersetzen
    #   [[ -e "${ODIR}/Cover-Enigma.jpg" ]] && cp -a "${ODIR}"/*.jpg "$2"
    #   [[ -e "${ODIR}/Cover-Enigma.png" ]] && cp -a "${ODIR}"/*.png "$2"
    #fi
    #[[ -z "${PLUGINS/* rectags */}" ]] && sendvdrkey.sh RED
    ;;
  moved)  # After recording was moved
    ;;
  delete)  # Delete recording
    ;;
  deleted)
    #if [[ -L "$2" ]] ; then  # Testen ob es ein Symlink ist
    #  LNK="$(readlink "$2")"             # Ziel des Links merken
    #  if [[ -d "$LNK" ]] ; then          # Ist ein Verzeichnis
    #    mv "$LNK" "${LNK%.rec}.del"      # Umbenennen -> *.del
    #    ln -s --force -n "${LNK%.rec}.del" "$2"  # Symlink ersetzen
    #    f_logger "Linkziel von $2 wurde angepasst (-> ${LNK%.rec}.del)"
    #  fi # -d
    #fi # -L
    ;;
  *) f_logger -s "ERROR: Unknown state: $1" ;;
esac

exit
