#!/usr/bin/env bash

# vdsb.sh - Video Data Stram Broken
VERSION=230801

# Wenn Syslog-NG oder rsyslog verwendet wird, startet Syslog-NG das Skript und schickt die
# Meldung via stdin an das Skript. Dazu wird eine "while" schleife verwendet.
# 20.03.2017 22:08:14 - "Mar 20 22:08:14 hdvdr01 vdr[4072]: [12841] ERROR: video data stream broken"

source /_config/bin/yavdr_funcs.sh &>/dev/null

# Variablen
OSCAM_LOG_DIR='/mnt/MCP-Server_root/var/log/ncam'  # Log-Dir von OSCAM (Server)
LOG_DIR='/var/log'                                 # System-Logdir
LOG_FILE="${LOG_DIR}/${SELF_NAME%.*}.log"
LOCALOSCAM_LOG="${LOG_DIR}/oscam/oscam.log"        # Lokales Log (DVBAPI)
TMP_DIR="$(mktemp -d)"
#KILLFLAG='/tmp/.killflag'                         # killall vdr
XARGS_OPT=('--null' '--no-run-if-empty')           # Optionen für "xargs"
LAST_MSG="$SECONDS"  # SECONDS ist eine interne BASH-Variable

trap 'f_cleanup' QUIT INT TERM EXIT                # Aufräumen beim beenden

# Funktionen
f_cleanup() {  # Aufräumen
  [[ -t 1 ]] && echo 'Cleanup…'
  rm --force --recursive "${TMP_DIR:?TMP_DIR not set}"/*
}

f_collect_dvbapidata() {
  cp "${LOG_DIR}/messages" "$TMP_DIR"
  cp "$LOCALOSCAM_LOG" "$TMP_DIR"
  cp "${LOCALOSCAM_LOG}-prev" "$TMP_DIR"
  cp "${OSCAM_LOG_DIR}/ncam.log" "${TMP_DIR}/ncam-server.log"
  cp "${OSCAM_LOG_DIR}/ncam.log-prev" "${TMP_DIR}/ncam-server.log-prev"
  sleep 0.25
  # Packen
  ARCHIV="${ARCHIV/VDSB/DVBAPI_UK}"
  tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"
  # OSCam (lokal) neustart - Abhilfe?
  # /etc/init.d/oscam restart # Deaktiviert weil OSCam auf dem Server läuft
  # Mail senden
  if [[ "$1" != 'NO_MAIL' ]] ; then
    { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
      echo "To: $MAIL_ADRESS"
      echo "Subject: DVBAPI Unknown Command - $HOSTNAME"
      echo -e "\nEs wurde ein 'DVBAPI-Error: Action: read failed unknown command:' entdeckt!\n"
    } > "$MAILFILE"
    echo "Ein Archiv mit Logs wurde erzeugt: $ARCHIV"
    /usr/sbin/sendmail root < "$MAILFILE"
  fi
}

f_find_vdsb_timer() {  # Vom VDSB betroffene Timer finden
  # svdrpsend LSTT 147
  # 220 hdvdr01 SVDRP VideoDiskRecorder 2.2.0; Fri Nov 13 11:21:06 2015; UTF-8
  # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
  # 221 hdvdr01 closing connection
  # Laufende Timer (LSTT) [Jede Zeile ein Feld]
  mapfile -t TIMERS < <("$SVDRPSEND" LSTT | grep ' 9:')
  # Laufende Aufnahmen (.rec) in Array
  mapfile -t REC_FLAGS < <(find -L /video -name .rec -type f -print)

  for rec_flag in "${REC_FLAGS[@]}" ; do
    REC_NAME="$(< "$rec_flag")"        # Der Name wie im Timer (Hoffentlich)
    REC_INDEX="${rec_flag%.rec}index"  # Index-Datei
    REC_VDSB="${rec_flag%.rec}.vdsb"   # .vdsb-Datei
    if [[ $(stat --format=%Y "$REC_INDEX" 2>/dev/null) -le $((EPOCHSECONDS - 20)) ]] ; then
      { echo -e "\n==> Aufnahme:\n${REC_NAME}"
        echo -e "$REC_INDEX ist älter als 20 Sekunden!\nMöglicher VDSB!"
      } >> "${TMP_DIR}/info.txt"
      echo "$RUNDATE - VDSB" >> "$REC_VDSB"
      # Timer bestimmen
      if [[ -e "${rec_flag%.rec}.timer" ]] ; then  # .timer (VDR 2.4.0)
        TIMER_NR="$(< "${rec_flag%.rec}.timer")"   # 61@vdr01
        { echo -e "\n==> Timer ${TIMER_NR}:"
          mapfile -t < <("$SVDRPSEND" LSTT "${TIMER_NR%@*}")  # 61
          IFS=':' read -r -a VDRTIMER <<< "${MAPFILE[1]}"     # Trennzeichen ist ":"
          echo "${VDRTIMER[7]}"  # nano~nano
        } >> "${TMP_DIR}/info.txt"
      fi
      if [[ -n "$REC_NAME" && "${TIMERS[*]}" =~ $REC_NAME ]] ; then  # Timer in der Liste enthalten!
        for timer in "${TIMERS[@]}" ; do
          if [[ "$timer" =~ $REC_NAME ]] ; then  # Timer gefunden
            IFS=':' read -r -a VDRTIMER <<< "$timer"  # Trennzeichen ist ":"
            # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
            # ^0        ^1 ^2         ^3   ^4   ^5 ^6 ^7
            TIMER_NR="${VDRTIMER[0]:4}"  # "250 " entfernen (ab 4. Zeichen)
            TIMER_NR="${TIMER_NR% *}"  # Alles nach der Timernummer entfernen
            # echo "Deaktiviere Timer Nummer $TIMER_NR (${VDRTIMER[7]})"
            # "$SVDRPSEND" MODT "$TIMER_NR" off  # Timer deaktivieren
            echo -e "\n==> Timer (${TIMER_NR}): $timer" >> "${TMP_DIR}/info.txt"
            break  # for Schleife beenden
          fi
        done  # for timer
      else
        echo -e "\n==> Timer für ${REC_NAME:-${TIMER_NR}} nicht gefunden!" >> "${TMP_DIR}/info.txt"
      fi
    fi  # stat
  done # ; set +x
}

# --- Start ---

[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]] && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

f_rotate_log  # Log rotieren

# Lösche VDSB_*- und DVBAPI_UK_*-Dateien die älter als 14 Tage sind
find "$LOG_DIR" -maxdepth 1 \( -name "VDSB_*" -o -name "DVBAPI_UK_*" \) -type f -mtime +14 -delete
# Lösche .rec-Dateien die älter als 2 Tage sind
find /video -name '.rec' -type f -mtime +2 -delete

logdaemon='rsyslogd'  # syslog-ng bei Gen2VDR
if pidof "$logdaemon" >/dev/null ; then  # rsyslog läuft (yaVDR)
  while read -r ; do
    read -r -a LOGSTRING <<< "$REPLY"  # Meldung in Array
    [[ ! "${LOGSTRING[*]}" =~ 'video data stream broken' ]] && continue
    printf -v RUNDATE '%(%d.%m.%Y %R:%S)T' -1  # Datum und Zeit mit Sekunden

    # Log schon vorhanden (VDSB)?
    # if [[ -e /tmp/.lognum ]] ; then
    #  if [[ $(stat --format=%Y /tmp/.lognum) -le $(( $(date +%s) - 600 )) ]] ; then
    #    LOGNUM=0  # Älter als 10 Minuten -> Bei 0 beginnen
    #  else
    #    LOGNUM=$(</tmp/.lognum)  # Nummer einlesen
    #  fi
    # fi

    DIFF=$((SECONDS - LAST_MSG))
    [[ $DIFF -gt 600 ]] && LOGNUM=0  # Älter als 10 Minuten -> Bei 0 beginnen
    ((LOGNUM+=1))  # Zähler um 1 erhöhen
    if [[ $LOGNUM -lt 5 || $DIFF -ge 60 ]] ; then  # Ab 5 nur ein mal pro Minute
      f_svdrpsend MESG "%>> VDSB entdeckt! (${LOGNUM}) <<"  # Meldung am VDR
      LAST_MSG="$SECONDS"
    fi

    [[ $LOGNUM -gt 3 || $RINGBUFFER -gt 2 ]] && continue  # Weiter

    # info.txt erstellen
    { echo -e "$SELF_NAME - $VERSION\n$RUNDATE - \"${LOGSTRING[*]}\""

      # Check local OSCam
      # read -r -a OSCAMPIDS < <(pidof oscam)
      # if [[ ${#OSCAMPIDS[@]} -lt 2 ]] ; then
      #  echo -e "\nKeine OSCam PID's! (${#OSCAMPIDS[@]})"
      #  echo "Starte OSCam..."
      #  /etc/init.d/oscam restart
      # fi

      # Laufende Aufzeichnungen und Timer
      echo -e '\n==> Laufende Aufnahmen (.rec):'
      find -L /video -name .rec -type f -print0 | xargs "${XARGS_OPT[@]}" ls -l
      echo -e '\n==> Laufende Timer:'
      grep '^[5..99]:' /var/lib/vdr/timers.conf

      echo -e '\n==> Tuner-Status:'
      for i in {0..3} ; do  # 4 Tuner
        echo "DVB${i}:"
        # femon -H -c3 -a${i}  # femon -H -c3 -a0  # Benötigt 'root'
        svdrpsend plug femon info "${i}"
        # dvbsnoop -hideproginfo -n 3 -adapter $i -s signal  # Benötigt 'root'
        # sleep 0.5
      done

      # Anstehende Timer
      echo -e "\n==> Anstehende Timer:"
      grep -v '^0' /var/lib/vdr/timers.conf

      # Die letzten xx Zeilen der messages in die info
      echo -e '\n==> Logmeldungen:'
      tail -n 75 "${LOG_DIR}/syslog"

      # OSCam Log
      echo -e '\n==> OSCam Server-Logmeldungen:'
      tail -n 50 "${OSCAM_LOG_DIR}/ncam.log"
    } > "${TMP_DIR}/info.txt"

    # Logs für spätere Auswertung sichern
    cp "${OSCAM_LOG_DIR}/ncam.log" "$TMP_DIR"  # vom Server
    cp "${LOCALOSCAM_LOG}" "${TMP_DIR}/localoscam.log"
    cp "${LOG_DIR}/syslog" "$TMP_DIR"

    # Logset nur beim ersten VDSB erstellen
    if [[ $LOGNUM -eq 1 ]] ; then
      /_config/bin/yavdr_log.sh -v "${TMP_DIR}/logset" &>/dev/null & disown
      until [[ -e "${TMP_DIR}/logset.tar.xz" ]] ; do  # Warte auf Datei
        sleep 0.5 ; ((cnt+=1))
        [[ $cnt -gt 120 ]] && break  # max. 60 Sekunden
      done
    fi

    # Beim 2. VDSB oder 5. RBO VDR neu starten und Flag setzen
    #if [[ $LOGNUM -eq 2 || $RINGBUFFER -eq 5 ]] ; then
    #  if [[ ! -e "$KILLFLAG" ]] ; then
    #    : > "$KILLFLAG"
    #    # killall vdr
    #    # sleep 15
    #    if ! "$SVDRP_CMD" volu | grep -q '^250' ; then
    #      : # reboot  # Falls der VDR nicht mehr reagiert
    #    fi
    #  fi  # -e $KILLFALG
    #fi

    f_find_vdsb_timer  # Von VDSB betroffene Timer finden

    cat "${TMP_DIR}/info.txt" >> "$LOG_FILE"  # Auch auf dem System loggen

    # Packen
    printf -v ARCHIV 'VDSB_%(%F_%R:%S)T.tar.xz' -1   # Archivname
    tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR" &>/dev/null & disown

    # Mail beim ersten VDSB senden
    if [[ $LOGNUM -eq 1 ]] ; then
      { echo "From: ${HOSTNAME}<${MAIL_ADRESS}>"
        echo "To: $MAIL_ADRESS"
        echo 'Content-Type: text/plain; charset=UTF-8'
        echo "Subject: [${HOSTNAME^^}] - Video Data Stream Broken"
        echo -e "\nEs wurde ein 'Video Data Stream Broken' entdeckt!"
        #echo 'Der VDR wird beim nächsten mal einmalig neu gestartet.'
        echo -e "\nInhalt von ${TMP_DIR}/info.txt:\n"
        cat "${TMP_DIR}/info.txt"
       } | /usr/sbin/sendmail root
    fi
  done
  
  f_cleanup
else  # Metalog?
  echo "$SELF_NAME - $1 - $2 - $3"
  echo 'Syslog-ng scheint nicht zu laufen!' >&2
fi

exit  # Ende
