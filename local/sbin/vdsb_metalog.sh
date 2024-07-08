#!/bin/bash

# vdsb.sh
# VDR Video Data Stram Broken
VERSION=170326

# Wird von Metalog aufgerufen wenn VDSB im Log steht. Eintrag in metalog.conf:
# VDR :
#    program = "vdr"
#    logdir = "/var/log/vdr"
#    regex    = "ERROR: video data stream broken"
#    regex    = "ring buffer overflows"
#    regex    = "DVBAPI-Error: Action: read failed unknown command:"
#    command = "/usr/local/sbin/vdsb.sh"
#    break = 1

# Wenn Syslog-NG verwendet wird, startet Syslog-NG das Skript und schickt die
# Meldung via stdin an das Skript. Dazu wird eine "while" schleife verwendet.
# 20.03.2017 22:08:14 - "Mar 20 22:08:14 hdvdr01 vdr[4072]: [12841] ERROR: video data stream broken"

source /_config/bin/yavdr_funcs.sh &>/dev/null

# Check auf logdir (metalog Regel)
# [ ! -d "/var/log/vdr" ] && mkdipr -p "/var/log/vdr"

# logger -s -t $(basename $0) "$0 - $1 - $2 - $3"  # 1: Datum/Zeit
                                                   # 2: programm
                                                   # 3: Meldung

OSCAM_LOG_DIR='/mnt/hp-t5730_root/var/log'         # Log-Dir von OSCAM (Server)
LOG_DIR='/var/log'                                # System-Logdir
LOCALOSCAM_LOG="${LOG_DIR}/oscam/oscam.log"        # Lokales Log (DVBAPI)
ARCHIV="VDSB_$(date +%s).tar.xz"                 # Archivname
TMP_DIR="$(mktemp -d)"
MAILFILE='/tmp/~vdsb_mail.txt'
KILLFLAG='/tmp/.killflag'                        # killall vdr
OLDIFS="$IFS"                                    # Feldtrenner merken
LOGNUM=0 ; RINGBUFFER=0 ; cnt=0
XARGS_OPT=('--null' '--no-run-if-empty')  # Optionen für "xargs"
LAST_MSG="$SECONDS"  # SECONDS ist eine interne BASH-Variable

trap 'f_cleanup 1' QUIT INT TERM EXIT  # Aufräumen beim beenden

# --- Funktionen ---
f_cleanup() {  # Aufräumen
  echo "Cleanup..."
  # Lösche alte VDSB_*- und DVBAPI_UK_*-Dateien die älter als 14 Tage sind
  # find "$LOG_DIR" -maxdepth 1 -type f -mtime +14 \( -name "VDSB_*" -o -name "DVBAPI_UK_*" \) \
  #     -print0 | xargs "${XARGS_OPT[@]}" rm
  # Lösche alte .rec-Dateien die älter als 2 Tage sind
	find /video -type f -mtime +2 -name '.rec' -print0 | xargs "${XARGS_OPT[@]}" rm
  rm -rf "$TMP_DIR"
  [[ ! $(pidof syslog-ng) || "$1" == "1" ]] && exit  # Exit nur wenn kein Syslog-NG läuft
}

collect_dvbapidata() {
  cp "${LOG_DIR}/messages" "$TMP_DIR"
  cp "$LOCALOSCAM_LOG" "$TMP_DIR"
  cp "${LOCALOSCAM_LOG}-prev" "$TMP_DIR"
  cp "${OSCAM_LOG_DIR}/oscam.log" "${TMP_DIR}/oscam-server.log"
  cp "${OSCAM_LOG_DIR}/oscam.log-prev" "${TMP_DIR}/oscam-server.log-prev"
  sleep 0.25
  # Packen
  ARCHIV="${ARCHIV/VDSB/DVBAPI_UK}"
  tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"
  # OSCam (lokal) neustart - Abhilfe?
  # /etc/init.d/oscam restart # Deaktiviert weil OSCam auf dem Server läuft
  # Mail senden
  if [[ "$1" != "NO_MAIL" ]] ; then
    { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
      echo "T0: $MAIL_ADRESS"
      echo "Subject: DVBAPI Unknown Command - $HOSTNAME"
      echo -e "\nEs wurde ein 'DVBAPI-Error: Action: read failed unknown command:' entdeckt!\n"
    } > "$MAILFILE"
    echo "Ein Archiv mit Logs wurde erzeugt: $ARCHIV"
    /usr/sbin/sendmail root < "$MAILFILE"
  fi
}

find_vdsb_timer() {  # Vom VDSB betroffene Timer finden
  #  svdrpsend LSTT 147
  # 220 hdvdr01 SVDRP VideoDiskRecorder 2.2.0; Fri Nov 13 11:21:06 2015; UTF-8
  # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
  # 221 hdvdr01 closing connection
  set -x
  # Laufende Timer (LSTT) [Jede Zeile ein Feld]
  IFS=$'\n'
  TIMERS=($("$SVDRPSEND" LSTT | grep ' 9:')) ; IFS="$OLDIFS"
  # Laufende Aufnahmen (.rec) in Array
  REC_FLAGS=($(find -L /video -name .rec -type f -print))

  for rec_flag in "${REC_FLAGS[@]}" ; do
    REC_NAME="$(< "$rec_flag")"  # Der Name wie im Timer (Hoffentlich)
    REC_INDEX="${rec_flag%.rec}index"  # Index-Datei
    if [[ $(stat --format=%Y "$REC_INDEX") -le $(($(date +%s) - 20)) ]] ; then
      { echo -e "\n=> Aufnahme: \n${REC_NAME}"
        echo -e "$REC_INDEX ist älter als 20 Sekunden!\nMöglicher VDSB!"
      } >> "${TMP_DIR}/info.txt"
      # Timer bestimmen
      if [[ "${TIMERS[*]}" =~ $REC_NAME ]] ; then  # Timer in der Liste enthalten!
        for timer in "${TIMERS[@]}" ; do
          if [[ "$timer" =~ $REC_NAME ]] ; then  # Timer gefunden
            IFS=":" ; VDRTIMER=($timer) ; IFS="$OLDIFS"  # Trennzeichen ist ":"
            # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
            # ^0        ^1 ^2         ^3   ^4   ^5 ^6 ^7
            TIMER_NR="${VDRTIMER[0]:4}"  # "250 " entfernen (ab 4. Zeichen)
            TIMER_NR="${TIMER_NR% *}"  # Alles nach der Timernummer entfernen
            # echo "Deaktiviere Timer Nummer $TIMER_NR (${VDRTIMER[7]})"
            # "$SVDRP_CMD" MODT "$TIMER_NR" off  # Timer deaktivieren
            echo -e "\n=> Timer (${TIMER_NR}): $timer" >> "${TMP_DIR}/info.txt"
            break  # for Schleife beenden
          fi
        done  # for timer
      else
        echo -e "\n=> Timer für $REC_NAME nicht gefunden!" >> "${TMP_DIR}/info.txt"
      fi
    fi  # stat
  done ; set +x
}

# --- Start ---
[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]] && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

if pidof syslog-ng >/dev/null ; then  # Syslog-NG läuft
  while read -r ; do
    LOGSTRING=($REPLY)  # Meldung in Array
    RUNDATE=$(date "+%d.%m.%Y %R:%S")  # Datum und Zeit mit Sekunden

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
      "$SVDRPSEND" MESG "%>> VDSB entdeckt! (${LOGNUM}) <<"  # Meldung am VDR
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

      echo -e "\n=> Tuner-Status:"
      for i in {0..3} ; do  # 4 Tuner
        echo -n "DVB${i} "
        femon -H -c3 -a${i}  # femon -H -c3 -a0
        # svdrpsend plug femon info ${i}
        # dvbsnoop -hideproginfo -n 3 -adapter $i -s signal
        # sleep 0.5
      done

      # Laufende Aufzeichnungen und Timer
      echo -e "\n=> Laufende Aufnahmen (.rec):"
      find -L /video -name .rec -type f -print0 | xargs "${XARGS_OPT[@]}" ls -l
      echo -e "\n=> Laufende Timer:"
      grep "^[5..99]:" /etc/vdr/timers.conf

      # Die letzten xx Zeilen der messages in die info
      echo -e "\n=> Logmeldungen:"
      tail -n 75 "${LOG_DIR}/messages"

      # Die letzten xx Zeilen der vdr-sc in die info
      if [[ -e "$LOG_DIR/vdr-sc" ]] ; then
        echo -e "\n=> vdr-sc Log:"
        tail -n 75 "${LOG_DIR}/vdr-sc"
      fi
    } > "${TMP_DIR}/info.txt"

    # Logs für spätere Auswertung sichern
    cp "${OSCAM_LOG_DIR}/oscam.log" "$TMP_DIR"  # vom Server
    cp "${LOCALOSCAM_LOG}" "${TMP_DIR}/localoscam.log"
    [[ -e "$LOG_DIR/vdr-sc" ]] && cp "${LOG_DIR}/vdr-sc" "$TMP_DIR"  # SC
    cp "${LOG_DIR}/messages" "$TMP_DIR"

    # Logset nur beim ersten VDSB erstellen
    if [[ $LOGNUM -eq 1 ]] ; then
      screen -dm sh -c "/_config/bin/g2v_log.sh -v ${TMP_DIR}/logset"
      # until [[ -e "${TMP_DIR}/logset.7z" ]] ; do  # Warte auf Datei (Gen2VDR V3)
      until [[ -e "${TMP_DIR}/logset.tar.xz" ]] ; do  # Warte auf Datei (Gen2VDR ab V4)
        sleep 0.5 ; ((cnt++))
        [[ $cnt -gt 120 ]] && break  # max. 60 Sekunden
      done
    fi

    # Beim 2. VDSB oder 5. RBO VDR neu starten und Flag setzen
    if [[ $LOGNUM -eq 2 || $RINGBUFFER -eq 5 ]] ; then
      if [[ ! -e "$KILLFLAG" ]] ; then
        touch "$KILLFLAG"
        # killall vdr
        # sleep 15
        if ! "$SVDRPSEND" volu | grep -q '^250' ; then
          : # reboot  # Falls der VDR nicht mehr reagiert
        fi
      fi  # -e $KILLFALG
    fi

    find_vdsb_timer  # Von VDSB betroffene Timer finden

    cat "${TMP_DIR}/info.txt" >> "${LOG_DIR}/${SELF_NAME%.*}.log"  # Auch auf dem System loggen

    # Packen (z=gzip, J=xz)
    # tar --create --absolute-names --auto-compress --file=$LOG_DIR/$ARCHIV $TMP_DIR
    tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"

    # Mail beim ersten VDSB senden
    if [[ $LOGNUM -eq 1 ]] ; then
      { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
        echo "T0: $MAIL_ADRESS"
        echo "Subject: VDSB - ${HOSTNAME}"
        echo -e "\nEs wurde ein 'Video Data Stream Broken' entdeckt!"
        echo "Der VDR wird beim nächsten mal einmalig neu gestartet."
        echo -e "Inhalt von $TMP_DIR/info.txt:\n"
        cat "${TMP_DIR}/info.txt"
      } > "$MAILFILE"
      iconv --from-code=UTF-8 --to-code=iso-8859-1 "$MAILFILE" \
        | /usr/sbin/sendmail root
    fi
  done
  # f_cleanup
else  # Metalog?
  echo "$SELF_NAME - $1 - $2 - $3" >> "${LOG_DIR}/vdsb.log"

  if [[ "$3" =~ "DVBAPI-Error: Action: read failed unknown command:" ]] ; then
    if [[ -e "/tmp/~uk_command" ]] ; then
      ACT_DATE=$(date +%s) ; FDATE=$(stat -c %Y /tmp/~uk_command)
      DIFF=$((ACT_DATE - FDATE))
      if [[ $DIFF -gt 120 ]] ; then
        # OSCam (Server) neustart - Abhilfe?
        # logger -s -t $(basename $0) "Trying to restart OSCam on Server..."
        # echo "1" > /mnt/hp-t5730_root/tmp/.restart
        logger -s -t "$SELF_NAME" "DIFF: $DIFF seconds"
        sleep 10 #; #reboot
        touch "/tmp/~uk_command"
        collect_dvbapidata NO_MAIL
      fi
    else # Erster Fall
      logger -s -t "$SELF_NAME" "Trying to restart OSCam on Server..."
      echo "1" > "/mnt/hp-t5730_root/tmp/.restart"
      touch "/tmp/~uk_command" ; sleep 10
      collect_dvbapidata
    fi
    # f_cleanup  # Ende
  fi

  # VDSB
  if [[ "$3" =~ "video data stream broken" ]] ; then
    # Log schon vorhanden (VDSB)?
    [[ -e /tmp/.lognum ]] && LOGNUM=$(</tmp/.lognum)  # Nummer einlesen
    ((LOGNUM++)) ; echo "$LOGNUM" > "/tmp/.lognum"    # +1 und speichern
    MESG="%>> VDSB entdeckt! (${LOGNUM}) <<"
  # else
    # Log schon vorhanden (ring buffer)?
    # [ -e /tmp/.rinbuffer ] && RINGBUFFER=$(cat /tmp/.ringbuffer) # Nummer einlesen
    # ((RINGBUFFER++)) ; echo $RINGBUFFER > /tmp/.ringbuffer      # +1 und speichern
    # MESG="%>> Rinbuffer overflow! (${RINGBUFFER}) <<"
  fi

  # Meldung am VDR
  f_scvdrpsend_msgt "$MESG"
  # [[ $LOGNUM -gt 3 || $RINGBUFFER -gt 2 ]] && f_cleanup

  echo "$0 - $1 - $2 - $3" > "$TMP_DIR/info.txt"

  # Check OSCam
  # OSCAMPIDS=$(pidof oscam | wc -w)
  read -r -a OSCAMPIDS < <(pidof oscam)
  if [[ ${#OSCAMPIDS[@]} -lt 2 ]] ; then
    echo -e "\nKeine OSCam PID's! (${#OSCAMPIDS[@]})" >> "${TMP_DIR}/info.txt"
    echo "Starte OSCam..." >> "${TMP_DIR}/info.txt"
    /etc/init.d/oscam restart
  fi

  echo -e "\nTuner-Status:" >> "${TMP_DIR}/info.txt"
  for i in {0..3} ; do           # 4 Tuner
    echo "=> DVB${i}" >> "${TMP_DIR}/info.txt"
    # femon -H -c3 -a${i} >> $TMP_DIR/info.txt         # femon -H -c3 -a0
    # svdrpsend plug femon info ${i} >> $TMP_DIR/info.txt
    dvbsnoop -hideproginfo -n 3 -adapter $i -s signal >> "${TMP_DIR}/info.txt"
    # sleep 0.5
  done

  # Laufende Aufzeichnungen und Timer
  { echo -e "\nLaufende Aufnahmen (.rec):"
    find -L /video -name .rec -type f -print0 | xargs "${XARGS_OPT[@]}" ls -l
    echo -e "\nLaufende Timer:"
    grep '^[5..99]:' /etc/vdr/timers.conf
  } >> "${TMP_DIR}/info.txt"

  # Logs für spätere Auswertung sichern
  cp "${OSCAM_LOG_DIR}/oscam.log" "$TMP_DIR"  # vom Server
  cp "${LOCALOSCAM_LOG}" "${TMP_DIR}/localoscam.log"
  [[ -e "$LOG_DIR/vdr-sc"  ]] && cp "${LOG_DIR}/vdr-sc" "$TMP_DIR"  # SC
  cp "${LOG_DIR}/messages" "$TMP_DIR"

  # Die letzten xx Zeilen der messages in die info
  echo -e "\nLogmeldungen:" >> "${TMP_DIR}/info.txt"
  tail -n 75 "${LOG_DIR}/messages" >> "${TMP_DIR}/info.txt"

  # Die letzten xx Zeilen der vdr-sc in die info
  if [[ -e "$LOG_DIR/vdr-sc" ]] ; then
    echo -e "\nvdr-sc Log:" >> "${TMP_DIR}/info.txt"
    tail -n 75 "${LOG_DIR}/vdr-sc" >> "${TMP_DIR}/info.txt"
  fi

  # Logset beim ersten VDSB
  if [[ "$3" =~ "video data stream broken" ]] ; then
    if [[ $LOGNUM -eq 1 ]] ; then
      screen -dm sh -c "/_config/bin/g2v_log.sh -v ${TMP_DIR}/logset"
      # until [ -e "${TMP_DIR}/logset.7z" ] ; do    # Warte auf Datei (Gen2VDR V3)
      until [[ -e "${TMP_DIR}/logset.tar.xz" ]] ; do  # Warte auf Datei (Gen2VDR ab V4)
        sleep 0.5 ; ((cnt++))
        [[ $cnt -gt 120 ]] && break                  # max. 120 Sekunden
      done
    fi
  fi

  # Beim 2. VDSB oder 5. RBO VDR neu starten und Flag setzen
  if [[ $LOGNUM -ge 2 || $RINGBUFFER -ge 5 ]] ; then
    if [[ ! -e $KILLFLAG ]] ; then
      touch "$KILLFLAG"
      killall vdr
      sleep 15
      if ! "$SVDRP_CMD" volu | grep '^250' ; then
        : #reboot          # Falls der VDR nicht mehr reagiert
      fi
    fi
  fi

  find_vdsb_timer  # Von VDSB betroffene Timer finden

  # Packen (z=gzip, J=xz)
  # tar --create --absolute-names --auto-compress --file=$LOG_DIR/$ARCHIV $TMP_DIR
  tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"

  # Optional: Loggen und oder Mailen!
  # Mail beim ersten VDSB senden
  if [[ $LOGNUM -eq 1 ]] ; then
    { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
      echo "T0: $MAIL_ADRESS"
      echo "Subject: VDSB - ${HOSTNAME}"
      echo -e "\nEs wurde ein 'Video Data Stream Broken' entdeckt!"
      echo 'Der VDR wird beim nächsten mal einmalig neu gestartet.'
      echo -e "Inhalt von ${TMP_DIR}/info.txt:\n"
      cat "${TMP_DIR}/info.txt"
    } > "$MAILFILE"
    iconv --from-code=UTF-8 --to-code=iso-8859-1 "$MAILFILE" \
      | /usr/sbin/sendmail root
  fi
  # f_cleanup
fi

exit  # Ende
