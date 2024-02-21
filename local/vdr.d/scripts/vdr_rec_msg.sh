#!/usr/bin/env bash
#
# vdr_rec_msg.sh
# Skript dient zur Anzeige von "Aufnahme"- und "Beendet"-Meldugen
#

# VERSION=240220

if ! source /_config/bin/yavdr_funcs.sh &>/dev/null ; then  # Falls nicht vorhanden
  f_logger() { logger -t yaVDR "vdr_rec_msg.sh: $*" ;}      # Einfachere Version
fi

# Vorgabewert für Video Verzeichniss, falls nicht gesetzt
: "${VIDEO:='/video'}"

REC="$2"                # Aufnahme-Pfad
REC_FLAG="${REC}/.rec"  # Kennzeichnung für laufende Aufnahme
PID_WAIT=13             # Zeit, die gewartet wird, um PID-Wechsel zu erkennen (Im Log schon mal 11 Sekunden!)

# Unnötige Pfade entfernen
: "${REC%/*}" ; TITLE="${_#*"${VIDEO}/"}"

# Sofortaufnahmezeichen (@) am Anfang entfernen
TITLE="${TITLE##@}"

while IFS='' read -r -d '' -n 1 char ; do  # Zeichenweises Suchen und Ersetzen
  case "$char" in
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

if [[ -n "$MESG" ]] ; then    # Meldung am VDR ausgeben (OSD)
  sleep 0.25
  if [[ -n "$SELF" ]] ; then  # SELF wird in yavdr_funcs.sh gesetzt
    f_logger -o "$MESG"       # -o für OSD-Meldung
  else
    svdrpsend MESG "$MESG"    # Standalone Version
  fi
fi
