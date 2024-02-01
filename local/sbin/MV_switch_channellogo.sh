#!/bin/bash

# MV_switch_channellogo.sh
# Helferskript für das Skin flatPlus!
# Zweck ist, dass Kanallogos abhängig von der Uhrzeit getauscht werden, um z. B.
# bei "Comedy Central/VIVA" Immer das passende Logo anzuzeigen
# Starten beim VDR-Start und per cron.hourly!
VERSION=170403

# --- Variablen
LOGO_DIR='/etc/vdr/plugins/skinflatplus/logos'   # Pfad zu den Kanallogos
ALT_LOGO_DIR="$LOGO_DIR"                         # Pfad zu den alternative Kanallogos
SVDRPSEND='svdrpsend'                            # VDR's svdrpsend
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"                          # skript.sh
LOG_FILE="/var/log/${SELF_NAME%.*}.log"           # Log-Datei
MAX_LOG_SIZE=$((1024*50))                          # Log-Datei: Maximale Größe in Byte
DAY_START="$(date +%s --date="0:00")"            # 0 Uhr
#NOW="$(date +%s)"                                # Aktuelle Zeit in Sekunden
printf -v NOW '%(%s)T\n'

# --- Funktionen
f_log() {  # Gibt die Meldung auf der Konsole und im Syslog aus
  # logger -s -t "$SELF_NAME" "$*"
  [[ -n "$LOG_FILE" ]] && echo "$(date +'%d.%m.%Y %R') [$$] $*" >> "$LOG_FILE"  # Log in Datei
}

f_change_logo() {  # Logo anpassen
  local LOGO_SRC="${1,,}" LOGO_DST="${2,,}" RLFC
  [[ $# -lt 1 ]] && return 1  # Benötigt mindestens ein Logo als Parameter
  # f_log "f_log [$1] - [${2:-LEER}]"  # DEBUG
  if [[ $# -eq 1 ]] ; then  # Ein Logo = Original Logo aktivieren
    if [[ -e "${LOGO_DIR}/${LOGO_SRC}.png.org" ]] ; then
      f_log "Aktiviere original Logo ($1)"
      mv --force "${LOGO_DIR}/${LOGO_SRC}.png.org" "${LOGO_DIR}/${LOGO_SRC}.png"
      RLFC=1  # Altes Logo aus Cache entfernen
    fi
  else  # Alternatives Logo ($2 nicht leer)
    if [[ ! -e "${LOGO_DIR}/${LOGO_SRC}.png.org" ]] ; then
      f_log "Aktiviere alternatives Logo ($1 -> $2) [${CONF[2]:0:11}]"
      cp --force --preserve "${LOGO_DIR}/${LOGO_SRC}.png" "${LOGO_DIR}/${LOGO_SRC}.png.org"  # Sichern
      cp --force --preserve "${ALT_LOGO_DIR}/${LOGO_DST}.png" "${LOGO_DIR}/${LOGO_SRC}.png"  # Alternative
      RLFC=1  # Altes Logo aus Cache entfernen
    fi
  fi
  # Aus dem Changelog von flatPlus
  # Use svdrp command "RLFC" to remove a logo from cache. Specify logo filename with extension, but without path.
  # For example: svdrpsend PLUG skinflatplus RLFC "rtl ii.png"
  if [[ -n "$RLFC" ]] ; then
    LOGO_SRC="${LOGO_SRC##*/}"  # Falls ein "/" enthalten ist nur den letzten Teil verwenden. Bsp.: comedy central/viva -> viva
    "$SVDRPSEND" PLUG skinflatplus RLFC "${LOGO_SRC}.png" >/dev/null  # Altes Logo aus Cache entfernen
  fi
}

# --- Start
# Suche Konfig im aktuellen Verzeichnis, im Verzeichnis des Skripts und im eigenen etc
CONFIG_DIRS=('.' "${SELF%/*}" "${HOME}/etc") ; CONFIG_NAME="${SELF_NAME%.*}.conf"
for dir in "${CONFIG_DIRS[@]}" ; do
  CONFIG="${dir}/${CONFIG_NAME}"
  if [[ -f "$CONFIG" ]] ; then
    mapfile -t < "$CONFIG"  # Konfiguration einlesen
    CONFLOADED=1
    break  # Die erste gefundene Konfiguration wird verwendet
  fi
done

if [[ -z "$CONFLOADED" ]] ; then  # Konfiguration wurde nicht gefunden
  echo -e "\e[1;41m FEHLER \e[0;1m Keine Konfigurationsdatei gefunden!\e[0m (\"${CONFIG_DIRS[*]}\")" >&2
  exit 1
fi

# NOW=$(date +%s --date="01:00") ; echo "$NOW"  # Test

# Auswerten der Konfiguration
for i in "${!MAPFILE[@]}" ; do  # Kanal|Alternative|Zeit
  if [[ "${MAPFILE[$i]:0:1}" == '#' || "${#MAPFILE[$i]}" -eq 0 ]] ; then
    unset -v 'MAPFILE[$i]'  # Zeile aus der Liste entfernen!
    continue  # weiter
  fi
  IFS='|' ; CONF=(${MAPFILE[$i]}) ; unset -v 'IFS'  # Zeile in Array
  [[ ${#CONF[2]} -lt 11 ]] && { echo "Zeitangabe für ${CONF[0]} fehlerhaft! (${CONF[2]]})" >&2
                                continue ;}
  # echo "Kanal: ${CONF[0]} Alternative: ${CONF[1]} Zeit: ${CONF[2]}"
  ST="${CONF[2]:0:5}" ; ET="${CONF[2]:6:5}"  # Bsp.: 00:01-12:30
  START="$(date +%s --date="$ST")" ; END="$(date +%s --date="$ET")"
  [[ $END -eq $DAY_START ]] && ((END+=60*60*24))  # 24 Stunden dazu (86400)
  if [[ $END -lt $START ]] ; then  # Bsp.: 20:00-06:00 (Ende am nächsten Tag)
    [[ $NOW -gt $START || $NOW -lt $END ]] && ALTLOGO=1
  else                             # Bsp.: 06:00-20:00 (Ende am gleichen Tag)
    [[ $NOW -gt $START && $NOW -lt $END ]] && ALTLOGO=1
  fi
  # echo "${CONF[0]} - Zeitspanne: $ST bis $ET [ALT=${ALTLOGO:-0}] ($START $END)"
  if [[ $ALTLOGO -eq 1 ]] ; then
    # echo "Zwischen $ST und $ET [ALT=${ALTLOGO}] ($START $END)"
    f_change_logo "${CONF[0]}" "${CONF[1]}"  # Alternatives Logo
  else
    # echo "Ausserhalb $ST und $ET [ALT=${ALTLOGO}] ($START $END)"
    f_change_logo "${CONF[0]}"  # Original Logo
  fi
  unset -v 'ALTLOGO'
done

if [[ -e "$LOG_FILE" ]] ; then       # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG_FILE")"
  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

exit 0 # Ende
