#!/bin/bash

# dvbapi_unknown.sh
# DVBAPI-Error: Action: read failed unknown command
#VERSION=161207

# Wenn Syslog-NG verwendet wird, startet Syslog-NG das Skript und schickt die
# Meldung via stdin an das Skript. Dazu wird eine "while" schleife verwendet.
# Apr  1 15:00:00 hdvdr01 vdr[3389]: [3389] NALU fill dumper: 0 of 17374783 packets dropped, 0% (/video/Arrow/Seelenjagd__(S04E05)/2016-04-01.14.05.20-0.rec/00002.ts)

source /_config/bin/yavdr_funcs.sh &>/dev/null

# Check auf logdir (metalog Regel)
#[ ! -d "/var/log/vdr" ] && mkdipr -p "/var/log/vdr"
#logger -s -t $(basename $0) "$0 - $1 - $2 - $3"  #1: Datum/Zeit
                                                #2: programm
                                                #3: Meldung

OSCAM_LOG_DIR='/mnt/hp-t5730_root/var/log'        # Log-Dir von OSCAM (Server)
LOG_DIR='/var/log'                               # System-Logdir
LOCALOSCAM_LOG="${LOG_DIR}/oscam/oscam.log"       # Lokales Log (DVBAPI)
ARCHIV="DVBAPI_UK_$(date +%s).tar.xz"           # Archivname
TMP_DIR="$(mktemp -d)"
MAILFILE="${TMP_DIR}/mail.txt"
KILLFLAG='/tmp/.killflag'                       # killall vdr
SVDRP_CMD='/usr/bin/svdrpsend'
LOGNUM=0
SELF_NAME="${0##/*}"
XARGS_OPT='--null --no-run-if-empty'  # Optionen für "xargs"

trap 'cleanup 1' QUIT INT TERM EXIT  # Aufräumen beim beenden

### Funktionen ###
cleanup() {  # Aufräumen
  echo 'Cleanup...'
  # Lösche alte VDSB_*- und DVBAPI_UK_*-Dateien die älter als 14 Tage sind
	#find "$LOG_DIR" -maxdepth 1 -type f -mtime +14 \( -name "VDSB_*" -o -name "DVBAPI_UK_*" \) \
  #     -print0 | xargs $XARGS_OPT rm
  # Lösche alte .rec-Dateien die älter als 2 Tage sind
	#find /video -type f -mtime +2 -name ".rec" -print0 | xargs $XARGS_OPT rm
  rm -rf "$TMP_DIR"
  [[ -z "$SYSLOGNG" || "$1" == "1" ]] && exit  # Exit nur wenn kein Syslog-NG läuft
}

collect_dvbapidata() {
  cp "${LOG_DIR}/messages" "$TMP_DIR"
  cp "$LOCALOSCAM_LOG" "$TMP_DIR"
  cp "${LOCALOSCAM_LOG}-prev" "$TMP_DIR"
  cp "${OSCAM_LOG_DIR}/oscam.log" "${TMP_DIR}/oscam-server.log"
  cp "${OSCAM_LOG_DIR}/oscam.log-prev" "${TMP_DIR}/oscam-server.log-prev"
  # info.txt
  { echo "==> \"$event\""
    echo -e '\n=> Speicher:' ; free -m
    echo -e '\n=> Laufwerksbelegungen:' ; df -h
    # Laufende Aufzeichnungen und Timer
    echo -e '\n=> Laufende Aufnahmen (.rec):'
    find -L /video -name .rec -type f -print0 | xargs "$XARGS_OPT" ls -l
    echo -e '\n=> Laufende Timer:'
    grep "^[5..99]:" /etc/vdr/timers.conf
    # Die letzten xx Zeilen der messages in die info
    echo -e '\n=> Logmeldungen:'
    tail -n 75 "${LOG_DIR}/messages"
  } > "${TMP_DIR}/info.txt"
  sleep 0.25
  # Packen
  tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"
  # Mail senden
  if [[ $LOGNUM -eq 1 ]] ; then
    { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
      echo "T0: $MAIL_ADRESS"
      echo "Subject: DVBAPI Unknown Command - $HOSTNAME"
      echo -e "\nEs wurde ein 'DVBAPI-Error: Action: read failed unknown command:' entdeckt!\n"
    } > "$MAILFILE"
    echo "Ein Archiv mit Logs wurde erzeugt: $ARCHIV"
    /usr/sbin/sendmail root < "$MAILFILE"
  fi
}

### Start ###
[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]]  && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

if [[ "$(pidof syslog-ng)" ]] ; then  # Syslog-NG läuft
  while read -r event ; do

    if [[ -e "/tmp/~uk_command" ]] ; then
      ACT_DATE=$(date +%s) ; FDATE=$(stat -c %Y /tmp/~uk_command)
      DIFF=$((ACT_DATE - FDATE))
      if [[ $DIFF -gt 600 ]] ; then
        LOGNUM=0  # Älter als 10 Minuten -> Bei 0 beginnen
        # OSCam (Server) neustart - Abhilfe?
        #logger -s -t $(basename $0) "Trying to restart OSCam on Server..."
        #echo "1" > /mnt/hp-t5730_root/tmp/.restart
        #logger -s -t "$SELF_NAME" "DIFF: $DIFF seconds"
        sleep 0.25 #; #reboot
        touch '/tmp/~uk_command'
        #collect_dvbapidata
      else
        LOGNUM=$(</tmp/~uk_command)  # Nummer einlesen
      fi
    else # Erster Fall
      logger -s -t "$SELF_NAME" "DVBAPI Read Unknown command found!"
      #echo "1" > "/mnt/hp-t5730_root/tmp/.restart"
      touch '/tmp/~uk_command' ; sleep 0.25
      collect_dvbapidata
    fi
    ((LOGNUM++)) ; echo "$LOGNUM" > "/tmp/~uk_command"  # +1 und speichern
    MESG="%>> 'DVBAPI Read Unknown Command' entdeckt! (${LOGNUM}) <<"

    # Meldung am VDR
    f_svdrpsend MESG "$MESG"
    [[ $LOGNUM -gt 3 ]] && continue  # Weiter

    # Beim 2. mal VDR neu starten und Flag setzen
    if [[ $LOGNUM -ge 2 ]] ; then
      if [[ ! -e "$KILLFLAG" ]] ; then
        touch "$KILLFLAG"
        killall vdr  # VDR beenden (Startet automatisch neu)
        sleep 10
        if [[ -z "$($SVDRP_CMD volu | grep "^250")" ]] ; then
          : #reboot          # Falls der VDR nicht mehr reagiert
        fi
      fi  # -e $KILLFALG
    fi
  done
  #cleanup
else # Metalog?
  echo "No Syslog-NG running?"
  exit
fi

# Ende
