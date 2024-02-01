#!/bin/bash

# create_recordings_old.cfg
# Skript zum Erzeugen einer recordings_old.cfg für skinFlatPlus
# Ausführen vor dem VDR-Start, bzw. per cron.daily
VERSION=160825

VIDEO_DIR="/video/"   # Verzeichnis mit den Aufnahmen (inkl. / am Ende)
LOG_FILE="/var/log/$(basename ${0%.*}).log"  # Log-Datei
MAX_LOG_SIZE=$((1024*50))                     # Log-Datei: Maximale größe in Byte
DEPTH=2               # Mindesttiefe für Serien (/video/Serie/Folge/*.rec/)
RECOLD_CFG="/etc/vdr/plugins/skinflatplus/recordings_old.cfg"
DAYS=10               # Ab wie vielen Tagen soll es als "Alt" angezeigt werden
SORT=1                # Liste sortieren

### Funktionen
function log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  logger -s -t $(basename ${0%.*}) "$*"
  [ -n "$LOG_FILE" ] && echo "$*" >> "$LOG_FILE"        # Log in Datei
}

### Start
[[ ! -d "$VIDEO_DIR" ]] && { echo "\"${VIDEO_DIR}\" nicht gefunden!" ; exit 1 ;}
[[ ! -d "${RECOLD_CFG%/*}" ]] && { echo "skinFlatPlus nicht installiert?" ; exit 1 ;}
[[ -f "$RECOLD_CFG" ]] && mv --force "$RECOLD_CFG" "${RECOLD_CFG}.old"

echo "# Erstellt von $0 [#${VERSION}]" > "$RECOLD_CFG"

while read dir ; do
  SERIES_DIR="${dir%/*}"             # Einen Ordner am Ende entfernen
  [[ $SERIES_DIR == $VIDEO_DIR ]] && continue  # Kein unterordner
  SERIES_DIR="${SERIES_DIR/${VIDEO_DIR}/}"  # VIDEO_DIR entfernen
  if [[ ! ${CFG_LINE[@]} =~ "$SERIES_DIR" ]] ; then  # Noch nicht enthalten
    CFG_LINE+=("$SERIES_DIR")  # Im Array speichern
  fi
done < <(find "$VIDEO_DIR" -mindepth $DEPTH -type d ! -name "*.rec")  # Die < <(commands) Syntax verarbeitet alles im gleichen Prozess. Änderungen von globalen Variablen sind so möglich

IFS=$'\n'
if [[ -n "$SORT" ]] ; then  # Für eine "sortierte" Ausgabe
  CFG_LINES=($(printf '%s\n' "${CFG_LINE[@]}" | sort))
else
  CFG_LINES=("${CFG_LINE[@]}")
fi

for entry in "${CFG_LINES[@]}" ; do  # Unsortiert: ${CFG_LINE[@]}
  unset -v "ch" "char" "OUT" "tmp"
  # Sonderzeichen übersetzen
  while [[ "${entry//#/}" != "$entry" ]] ; do
    tmp="${entry#*#}" ; char="${tmp:0:2}" ; ch="$(echo -e "\x$char")"
    OUT="${OUT}${entry%%#*}$ch" ; entry="${tmp:2}"
  done
  entry="${OUT}${entry}" #; echo "#xx: $entry"
  # ~ durch / ersetzen, aber auch den Unterverzeichnistrenner / durch ~
  LEN="$((${#entry}-1))" ; i=0
  while [[ $i -le $LEN ]] ; do
    case "${entry:$i:1}" in   # Zeichenweises Suchen und Ersetzen
      "/") entry="${entry:0:$i}~${entry:$i+1}" ;;
      "~") entry="${entry:0:$i}/${entry:$i+1}" ;;
      "_") entry="${entry:0:$i} ${entry:$i+1}" ;;  # _ durch Leerzeichen
        *) ;;
    esac
    ((i++))
  done
  #echo "/~: $entry"
  # Ausgabe in Datei
  echo "${entry}=${DAYS}" >> "$RECOLD_CFG"
done
unset -v IFS
