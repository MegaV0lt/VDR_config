#!/usr/bin/env bash
# ---
# vdr_rec_msg.sh
# Skript dient zur Anzeige von "Aufnahme"- und "Beendet"-Meldugen
# ---

# VERSION=231113

if ! source /_config/bin/yavdr_funcs.sh &>/dev/null ; then  # Falls nicht vorhanden
  f_logger() { logger -t yaVDR "vdr_rec_msg.sh: $*" ;}      # Einfachere Version
fi

# Vorgabewert, falls nicht gesetzt
: "${VIDEO:='/video'}"

REC="$2"  # Aufnahme-Pfad

# "Aufnahme:" und "Beendet:"-Meldung unnötige Pfade entfernen
: "${REC%/*}" ; TITLE="${_#*"${VIDEO}/"}"

# Sofortaufnahmezeichen (@) entfernen
while [[ "${TITLE:0:1}" == '@' ]] ; do
  TITLE="${TITLE:1}"
done

while IFS='' read -r -d '' -n 1 char ; do
  case "$char" in           # Zeichenweises Suchen und Ersetzen
    '/') title+='~' ;;      # "/" durch "~"
    '~') title+='/' ;;      # "~" durch "/"
    '_') title+=' ' ;;      # "_" durch " "
      *) title+="$char" ;;  # Originalzeichen
  esac
done < <(printf %s "$TITLE")
TITLE="$title"  # Bearbeitete Version übernehmen

# Sonderzeichen übersetzen
while [[ "${TITLE//#}" != "$TITLE" ]] ; do
  tmp="${TITLE#*#}"  # Ab dem ersten '#'
  char="${tmp:0:2}"  # Zeichen in HEX (4E = N)
  printf -v ch '%b' "\x${char}"  # ASCII-Zeichen
  OUT+="${TITLE%%#*}${ch}"
  TITLE="${tmp:2}"
done
TITLE="${OUT}${TITLE}"

# Sonderzeichen, welche die Anzeige stören oder nicht mit dem Dateisystem harmonieren maskieren
SPECIALCHARS='\ $ ` "'  # Teilweise Dateisystemabhängig
for ch in $SPECIALCHARS ; do
  TITLE="${TITLE//${ch}/\\${ch}}"
  REC="${REC//${ch}/\\${ch}}"
done

REC_FLAG="${REC}/.rec"  # Kennzeichnung für laufende Aufnahme
PID_WAIT=13             # Zeit, die gewartet wird, um PID-Wechsel zu erkennen (Im Log schon mal 11 Sekunden!)

case "$1" in
  before)
    if [[ -e "$REC_FLAG" ]] ; then
      f_logger "$TITLE: Is already recording? (PID change?) No Message!"
      : >> "$REC_FLAG"
      exit 1  # REC_FLAG existiert - Exit
    else
      until [[ -d "$REC" ]] ; do  # Warte auf Verzeichnis
        f_logger "$TITLE: Waiting for directory…"
        sleep 0.5 ; ((cnt++))
        [[ $cnt -gt 5 ]] && break
      done
      echo "$TITLE" > "$REC_FLAG" || f_logger "Error: Could not create REC_FLAG: $REC_FLAG"
      MESG="Aufnahme:  $TITLE"
    fi
    ;;
  after)
    if [[ -e "$REC_FLAG" ]] ; then
      sleep "$PID_WAIT"  # Wartezeit für PID-Wechsel
      FDATE="$(stat -c %Y "$REC_FLAG" 2>/dev/null)"
      DIFF=$((EPOCHSECONDS - FDATE))
      if [[ $DIFF -le $PID_WAIT ]] ; then  # Letzter Start vor x Sekunden!
        f_logger "$TITLE: Last start $DIFF seconds ago! (PID change?)"
        exit 1  # Exit
      else
        f_logger "$TITLE: Normal end of recording. Removing REC_FLAG!"
        rm -f "$REC_FLAG"
      fi
    else
      f_logger "Error: REC_FLAG not found: $REC_FLAG"
    fi
    MESG="Beendet:  $TITLE"
    ;;
esac

if [[ -n "$MESG" ]] ; then  # Meldung ausgeben
  sleep 0.25
  f_logger -o "$MESG"       # -o für OSD-Meldung
  #svdrpsend MESG "$MESG"   # Standalone Version
fi
