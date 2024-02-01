#!/usr/bin/env bash
#
# vdr_checkrec.sh
#
# Skript um unvollständige Aufnahmen zu kennzeichnen  [67,5%]
# Zusätzlich Aufnahmen von TVScraper mit SxxExx versehen  (S01E01)
# Das Skript liest beim Aufnahmestart daten zum Timer ein und beim
# Ende der Aufnahme Informationen zur tatsächlichen Länge und aufgetretenen
# Fehlern aus.
# Verwendet folgende optionale Skripte:
#   - yavdr_funcs.sh für's Loggen
#   - vdr_rec_mesg.sh für das .rec-Flag
# Skript wird vom recording_hook aufgerufen (z. B. vdr_record.sh)
# Aufruf bei 'startet' und 'after':
#   /etc/vdr.d/scripts/vdr_checkrec.sh "$1" "$2" &>/dev/null & disown

# VERSION=231212

if ! source /_config/bin/yavdr_funcs.sh &>/dev/null ; then  # Falls nicht vorhanden
  f_logger() { logger -t yaVDR "vdr_checkrec.sh: $*" ;}     # Einfachere Version
fi

# Einstellungen
ADD_SE='true'                         # (SxxExx) anhängen, wenn in der Beschreibung gefunden
ADD_UNCOMPLETE='true'                 # [67,5%] anhängen, wenn aufnahme weniger als 99% lang
MAX_LOG_SIZE=$((1024*50))               # Maximale Größe der Logdatei

# Vorgaben, falls nicht gesetzt
: "${VIDEO:=/video}"
: "${SVDRPSEND:=svdrpsend}"

# Variablen
LOG_FILE="${VIDEO}/checkrec.log"      # Logdatei (Deaktivieren mit #)
REC_DIR="${2%/}"                      # Sicher stellen, dass es ohne / am Ende ist
REC_FLAG="${REC_DIR}/.rec"            # Kennzeichnung für laufende Aufnahme (vdr_rec_msg.sh)
REC_INDEX="${REC_DIR}/index"          # VDR index Datei für die Länge der Aufnahme
REC_INFO="${REC_DIR}/info"            # VDR info Datei für die Framerate der Aufnahme
TVSCRAPER_JSON=("${REC_DIR}/tvscrapper.json" "${REC_DIR}/tvscraper.json") # Datei tvscraper.json
TIMER_FLAG="${REC_DIR}/.timer"        # Vom VDR während der Aufnahme angelegt (Inhalt: 1@vdr01)
MARKAD_PID="${REC_DIR}/markad.pid"    # MarkAD PID ist vorhanden wenn MarkAD die Aufnahme scannt
REC_INFOS="${REC_DIR}/.checkrec"      # Um die ermittelten Werte zu speichern
REC_LEN="${REC_DIR}/.rec_length"      # Angabe der Aufnahmelänge in %

# Funktionen
f_log() {  # Logmeldungen ins Systemlog (logger) und Log-Datei
  f_logger "$@"
  [[ -n "$LOG_FILE" ]] && printf '[%(%F %R)T] %s\n' -1 "$@" >> "$LOG_FILE"
}

f_get_se() {  # Werte für Episode und Staffel ermitteln
  mapfile -t < "$REC_INFO"  # Info-Datei vom VDR einlesen
  for line in "${MAPFILE[@]}" ; do
    if [[ "$line" =~ ^D' ' ]] ; then  # Beschreibung
      re_s='\|Staffel: ([0-9]+)' ; re_e='\|Episode: ([0-9]+)'
      [[ "$line" =~ $re_s ]] && printf -v STAFFEL '%02d' "${BASH_REMATCH[1]}"
      [[ "$line" =~ $re_e ]] && printf -v EPISODE '%02d' "${BASH_REMATCH[1]}"
    fi  # ^D
    [[ "$line" =~ ^F' ' ]] && FRAMERATE="${line#F }"   # 25
    [[ "$line" =~ ^O' ' ]] && REC_ERRORS="${line#O }"  # 768
  done
  [[ -n "$STAFFEL" && -n "$EPISODE" ]] && SE="(S${STAFFEL}E${EPISODE})"  # (SxxExx)

  # TVScrapper
  for json in "${TVSCRAPER_JSON[@]}" ; do  # Alte (Mit pp) und neue Version (Mit p) testen
    if [[ -e "$json" ]] ; then
      unset -v 'STAFFEL' 'EPISODE'
      mapfile -t < "$json"
      re_s='\"season_number\": ([0-9]+)' ; re_e='\"episode_number\": ([0-9]+)'
      for line in "${MAPFILE[@]}" ; do
        [[ "$line" =~ $re_s ]] && printf -v STAFFEL '%02d' "${BASH_REMATCH[1]}"
        [[ "$line" =~ $re_e ]] && printf -v EPISODE '%02d' "${BASH_REMATCH[1]}"
      done
  fi
  done
  [[ -n "$STAFFEL" && -n "$EPISODE" ]] && TVS_SE="(S${STAFFEL}E${EPISODE})"  # (SxxExx)
}

# Start
case "$1" in
  started)
    # Gespeicherte Werte schon vorhanden?
    if [[ -e "$REC_INFOS" ]] ; then
      f_logger "File $REC_INFOS already exists; PID change?"  # Möglicher PID-Wechsel
      exit
    fi

    until [[ -e "$TIMER_FLAG" ]] ; do  # Warte auf .timer vom VDR
      sleep 5 ; ((cnt++))
      [[ $cnt -gt 10 ]] && { f_log "${REC_DIR}: Error! Timer flag (.timer) not found!" ; exit ;}
    done

    # Datei .timer auslesen und Daten des Timers laden (Start- und Stopzeit)
    TIMER_ID=$(<"$TIMER_FLAG")  # 1@vdr01
    mapfile -t < <("$SVDRPSEND" LSTT "${TIMER_ID%@*}")    # Timernummer vom VDR
    #220 vdr01 SVDRP VideoDiskRecorder 2.6.1; Thu Oct 27 15:30:24 2022; UTF-8
    #250 86 0:48:2022-10-27:1455:1539:99:99:LIVE| PK Lindner zur Herbst-Steuerschätzung:
    #221 vdr01 closing connection
    IFS=':' read -r -a VDR_TIMER <<< "${MAPFILE[1]}"      # Trennzeichen ist ":"

    # Länge des Timers ermitteln
    START="$(date +%s --date="${VDR_TIMER[3]}")"  # SSMM (Uhrzeit)
    STOP="$(date +%s --date="${VDR_TIMER[4]}")"
    [[ $STOP -lt $START ]] && ((STOP+=60*60*24))  # 24 Stunden dazu (86400)
    TIMER_LENGTH=$((STOP - START))                # Länge in Sekunden

    # Ermittelte Werte für später Speichern
    { echo "TIMER_ID=$TIMER_ID" ; echo "VDR_TIMER=\"${VDR_TIMER[*]}\""
      echo "START=$START"       ; echo "STOP=$STOP"
      echo "TIMER_LENGTH=$TIMER_LENGTH"
    } > "$REC_INFOS"  # .checkrec
  ;;
  after)
    while [[ -e "$REC_FLAG" || -e "$TIMER_FLAG" ]] ; do  # Warten, bis Aufnahme beendet ist (vdr_rec_msg.sh)
      f_logger "${REC_DIR}: Waiting for end of recording…"
      sleep 5 ; ((cnt++))
      [[ $cnt -gt 10 ]] && { f_log "${REC_DIR}: Error! .rec or .timer still present!" ; exit ;}
    done

    if [[ -e "$REC_INFOS" ]] ; then  # Daten laden oder abbrechen wenn nicht vorhanden
      source "$REC_INFOS"
      [[ -z "$TIMER_LENGTH" ]] && { f_log "${REC_DIR}: Error! TIMER_LENGTH not detected!" ; unset -v 'ADD_UNCOMPLETE' ;}
    else
      f_logger "Error: File $REC_INFOS not found!"
      unset -v 'ADD_UNCOMPLETE'
    fi

    f_get_se  # VDR info Datei einlesen und Werte für Episode und Staffel ermitteln

    [[ -z "$FRAMERATE" ]] && { f_log "${REC_DIR}: Error! FRAMERATE not detected!" ; unset -v 'ADD_UNCOMPLETE' ;}

    # Größe der index Datei ermitteln und mit Timerlänge vergleichen
    if [[ "$ADD_UNCOMPLETE" == 'true' ]] ; then
      INDEX_SIZE=$(stat -c %s "$REC_INDEX" 2>/dev/null)     # In Byte
      if [[ "${INDEX_SIZE:=0}" == 0 ]] ; then
        f_log 'Error: INDEX_SIZE not detected!'             # Dateigröße in Bytes
      else
        REC_LENGTH=$((INDEX_SIZE / 8 / FRAMERATE))          # Aufnahmelänge in Sekunden
      fi
      if [[ "${REC_LENGTH:=0}" == 0 ]] ; then
        f_log 'Error: REC_LENGTH not detected!'             # Länge in Sekunden
      else
        RECORDED=$((REC_LENGTH * 100 * 10 / TIMER_LENGTH))  # In Promille (675 = 67,5%)
      fi
      if [[ -z "$RECORDED" ]] ; then
        unset -v 'ADD_UNCOMPLETE'
        f_log 'Error: RECORDED not detected!'
      else
        if [[ "${#RECORDED}" -ge 2 ]] ; then                    # Ab zwei Stellen
          dec="${RECORDED: -1}"                                 # 5
          RECORDED="${RECORDED:0:${#RECORDED}-1}.${dec}"        # 67.5
        fi
        [[ "${#RECORDED}" -eq 1 ]] && RECORDED="0.${RECORDED}"  # 0.5
      fi  # -z RECORDED
    fi  # ADD_UNCOMPLETE == true

    : "${REC_DIR%/*}"            # Verzeichnis ohne /2022-06-26.20.53.26-0.rec
    REC_NAME="${_#"${VIDEO}"/}"  # /video/ am Anfang entfernen
    REC_DATE="${REC_DIR##*/}"    # 2022-06-26.20.53.26-0.rec

    { echo "FRAMERATE=$FRAMERATE"   ; echo "REC_ERRORS=$REC_ERRORS"
      echo "INDEX_SIZE=$INDEX_SIZE" ; echo "REC_LENGTH=$REC_LENGTH"
      echo "RECORDED=$RECORDED"     ; echo "SE=$SE"
      echo "REC_NAME=$REC_NAME"     ; echo "REC_DATE=$REC_DATE"
    } >> "$REC_INFOS"  # Für Debug-Zwecke

    if [[ "$ADD_SE" == 'true' ]] ; then
      re='\(S.*E.*\)'
      if [[ ! "$REC_NAME" =~ $re ]] ; then
        [[ -n "$SE" && "$SE" == "$TVS_SE" ]] && unset -v 'TVS_SE'  # Beide gleich!
        if [[ -n "$SE" && -z "$TVS_SE" ]] ; then
          NEW_REC_NAME="${REC_NAME}__$SE"                    # SxxExx hinzufügen
          f_log "Adding $SE to $REC_NAME -> $NEW_REC_NAME"
        elif [[ -z "$SE" && -n "$TVS_SE" ]] ; then
          NEW_REC_NAME="${REC_NAME}__${TVS_SE}!"             # Keine Info aus VDR info aber von TVScraper
          f_log "Adding $TVS_SE to $REC_NAME -> $NEW_REC_NAME"
        elif [[ -n "$SE" && -n "$TVS_SE" ]] ; then
          NEW_REC_NAME="${REC_NAME}__${SE}!"                 # Unterschiedliche Info aus VDR info und TVScraper
          f_log "Adding $SE to $REC_NAME -> $NEW_REC_NAME"
        fi
      fi  # ! =~ re
    fi  # ADD_SE

    if [[ "$ADD_UNCOMPLETE" == 'true' && "${RECORDED%.*}" -lt 99 ]] ; then
      echo "$RECORDED" > "$REC_LEN"                                  # Speichern der Aufnahmelänge
      NEW_REC_NAME="${NEW_REC_NAME:-$REC_NAME}__[${RECORDED/./,}%]"  # Unvollständige Aufnahme
      f_log "Adding [${RECORDED/./,}%] to $REC_NAME -> $NEW_REC_NAME"
    fi

    # 0%-Aufnahme (Senderausfall, Gewitter oder ähnliches)
    if [[ ! -e "$REC_INDEX" || -z "$RECORDED" ]] ; then
      NEW_REC_NAME="${NEW_REC_NAME:-$REC_NAME}__[0%]"  # 0% Aufnahme
      f_log "Adding [0%] to $REC_NAME -> $NEW_REC_NAME"
      RECORDED=0
    fi

    # Statistik und Log
    f_log "Recorded ${RECORDED:-'?'}% of ${REC_NAME}. ${REC_ERRORS:-'?'} error(s) detected by VDR"

    if [[ "$REC_NAME" == "${NEW_REC_NAME:=$REC_NAME}" ]] ; then
      f_logger "No action needed for $REC_NAME"
      exit  # Keine weitere Aktion nötig
    fi

    while [[ -e "$MARKAD_PID" ]] ; do  # Warten, bis markad beendet ist
      sleep 10
    done

    # Wird die Aufnahme gerade abgespielt?
    mapfile -t DBUS_STATUS < <(vdr-dbus-send /Status status.IsReplaying)
    #method return time=1666943022.845569 sender=:1.42 -> destination=:1.71 serial=1467 reply_serial=2
    #  string "The Magicians~Von alten Göttern und Monstern  (S04E11)"
    #  string "/video/The_Magicians/Von_alten_Göttern_und_Monstern__(S04E11)/2022-06-26.20.53.26-0.rec"
    #boolean true
    read -r -a STATUS_STRING <<< "${DBUS_STATUS[2]}"
    if [[ "${STATUS_STRING[1]}" =~ $2 ]] ; then   # string "" wenn nichts abgespielt wird
      f_log "Recording $REC_NAME is currently playing. Exit!"
      exit
    fi

    # Verzeichnis umbenennen, wenn Aufnahme kleiner 99% (*_[63,5%]) oder SxxExx fehlt
    if [[ -d "$REC_DIR" ]] ; then  # Verzeichnis existiert noch?
      mkdir --parents "${VIDEO}/${NEW_REC_NAME}" \
        || { f_log "Error: Failed to create ${VIDEO}/${NEW_REC_NAME}" ; exit ;}
      if mv "$REC_DIR" "${VIDEO}/${NEW_REC_NAME}/${REC_DATE}" ; then
        : > "${VIDEO}/.update"   # Aufnahmen neu einlesen
      else
        f_log "Error: Renaming of $REC_DIR -> ${VIDEO}/${NEW_REC_NAME}/${REC_DATE} failed!"
      fi  # mv
    else
      f_log "Error: $REC_DIR not found. Already deleted?"
    fi  # -d REC_DIR
    ;;
esac

if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG_FILE" 2>/dev/null)"
  [[ $FILE_SIZE -ge $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

exit
