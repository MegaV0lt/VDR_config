#!/usr/bin/env bash
# ---
# copy2usb.sh
# Wird aufgerufen, wenn man im VDR Aufnahmen auf USB kopiert (rec_commands)
# ---

# VERSION=240322

source /_config/bin/yavdr_funcs.sh &>/dev/null

LIMIT=$((25*1024))            # Begrenzung beim Kopieren via USB (kb/s)
: "${VIDEO:=/video}"          # Vorgabe, falls $VIDEO leer ist
CP2USB='/tmp/~cp2usb.sh'      # Temporäres Skript
FLAG='.cp2usb'                # Zur erkennung, ob Kopiervorgang schon läuft
SRC="$1"

# Start
# Video- und Aufnahme-Verzeichnis abschneiden
: "${SRC%/*}" ; TITLE="${_#*"${VIDEO}/"}"

if ! declare -F f_logger >/dev/null ; then
  f_logger() { logger -t yaVDR "copy2usb.sh: $*" ;}
  f_svdrpsend_msgt() { svdrpsend "$@" ;}
fi

: "${TITLE//_/ }"      # Alle _ durch Leerzeichen ersetzen
: "${_//'/'/' / '}"    # / durch " / " ersetzen
TITLE="${_//'~'/'/'}"  # ~ durch / ersetzen

# Sonderzeichen übersetzen
while [[ "${TITLE//#}" != "$TITLE" ]] ; do
   tmp="${TITLE#*#}" ; char="${tmp:0:2}"
   printf -v ch '%b' "\x${char}"
   OUT+="${TITLE%%#*}${ch}" ; TITLE="${tmp:2}"
done
TITLE="${OUT}${TITLE}"

# Sehr lange Titel auf 99 Zeichen kürzen
length=99
if [[ "${#TITLE}" -ge $length ]] ; then
  re='(\(S[0-9]+E[0-9]+\).*)'   # (S01E01)
  re2='(\[S[0-9]+E[0-9]+\].*)'  # [S01E01]
  [[ "$TITLE" =~ $re ]] && { SE="${BASH_REMATCH[1]}" ; ((length-=${#SE})) ;}
  [[ "$TITLE" =~ $re2 ]] && { SE2="${BASH_REMATCH[1]}" ; ((length-=${#SE2})) ;}
  if [[ -n "$SE" && -n "$SE2" ]] ; then
    : "${TITLE:0:length}" ; TITLE="${_%%' '}…  ${SE}${SE2}"
  else
    re3='(\[[0-9]+.*%\].*)'       # [68,3%]
    [[ "$TITLE" =~ $re3 ]] && { UNCOMPLETE="${BASH_REMATCH[1]}" ; ((length-=${#UNCOMPLETE})) ;}
    : "${TITLE:0:length + 1}" ; TITLE="${_%%' '}…  $UNCOMPLETE"
  fi
fi

if [[ -e "${1}/.timer" ]] ; then  # Prüfen ob Aufnahme noch läuft
  f_logger "Recording $SRC still running! Aborting!"
  f_svdrpsend_msgt "%Aufnahme \"${TITLE}\" läuft noch. Abbruch!"
  exit 1
fi

if [[ -e "${1}/${FLAG}" ]] ; then  # Prüfen ob kopiervorgang schon läuft
  if [[ "$(stat -c %Y "${1}/${FLAG}" 2>/dev/null)" -lt $((EPOCHSECONDS - 60*60)) ]] ; then
    rm "${1}/${FLAG}"  # Entfernen, falls älter als eine Stunde
  else
    f_logger "Recording $SRC still in copy process! Aborting!"
    f_svdrpsend_msgt "%Aufnahme \"${TITLE}\" wird gerade kopiert. Abbruch!"
    exit 1
  fi
fi

IFS=' ' read -r -a TARGET_MOUNT <<< "$(grep -m 1 ' /media/vdr' /proc/mounts)"  # /dev/sdb1 /media/vdr/USB_HD ext4 rw 0 0
TARGET="${TARGET_MOUNT[1]}"  # /media/vdr/USB_HD
if [[ -n "$TARGET" && -d "$TARGET" && -n "$SRC" && -d "$SRC" ]] ; then
  : > "${1}/${FLAG}"      # Kopier-Flag erstellen
  TD="${SRC%/*}"          # "$(dirname "$SRC")"
  SPECIALCHARS='$ ` \ "'  # Teilweise Dateisystemabhängig
  for ch in $SPECIALCHARS ; do
    TD="${TD//$ch/\\$ch}"
    SRC="${SRC//$ch/\\$ch}"
  done
  TARGET_DISK="${TARGET/'/media/vdr/'}"  # USB_HD
  f_logger "Copying $1 to $TARGET"
  { echo '#!/usr/bin/env bash'
     echo 'source /_config/bin/yavdr_funcs.sh &>/dev/null'
     echo 'if ! declare -F f_logger >/dev/null ; then'
     echo "  f_logger() { logger -t yaVDR \"$CP2USB: $*\" ;}"
     echo '  f_svdrpsend_msgt() { svdrpsend "$@" ;}'
     echo 'fi'
     echo "if ! mkdir --parents \"${TARGET}${TD}\" ; then"
     echo "  f_scvdrpsend_msgt \"@FEHLER beim erstellen von '[${TARGET_DISK}]${VIDEO}/${TITLE}'\""
     echo 'fi'
     echo "f_svdrpsend_msgt \"Kopiere '${TITLE}' nach [${TARGET_DISK}]${VIDEO}\""
     echo "if rsync --archive --bwlimit=${LIMIT} --no-links \"${SRC}\" \"${TARGET}${TD}\" &> \"${CP2USB%.*}.rsync.log\" ; then"
     echo "  f_svdrpsend_msgt \"'${TITLE}' wurde nach [${TARGET_DISK}]${VIDEO} kopiert\""
     echo 'else'
     echo "  f_svdrpsend_msgt \"@FEHLER beim kopieren von '${TITLE}'\""
     echo '  exit 1'
     echo 'fi'
     echo "rm \"${1}/${FLAG}\""   # Kopier-Flag löschen
     echo ": > ${VIDEO}/.update"
  } > "$CP2USB"
  chmod a+x "$CP2USB"             # Ausführbar machen
  "$CP2USB" &>/dev/null & disown  # Temporäres Skript im Hintergrund starten

else
  f_logger -s "Illegal parameter <${1}> or no usb drive found!"
  f_scvdrpsend_msgt "@Ungültiger Parameter <${1}> oder kein USB-Laufwerk gefunden!"
fi
