#!/bin/bash

# check_dvbadapter.sh - Prüfen, wie viele DVB Adapter erkannt wurden
# Author: MegaV0lt, Version: 20131018

# Aktivierung ab GenVDR V3:
# echo /usr/local/sbin/check_dvbadapter.sh > /etc/vdr.d/8100_check_dvbadapter

# Anzahl der DVB-Karten aus /etc/vdr.d/conf/vdr (DVB_CARD_NUM)
source /etc/vdr.d/conf/vdr           # VDR-Konfig (Anzahl Karten ...)

# Einstellungen
[ -z "$DVB_CARD_NUM" ] && DVB_CARD_NUM=3 # Anzahl DVB-Adapter
DMESG=/var/log/dmesg                 # Datei "dmesg"
MESSAGES=/var/log/messages           # System-Log
CHECKUPTIME=1                        # Skript auch ausführen, wenn schon länger an?

# Optionale Einstellungen
LOG_FILE="/log/$(basename ${0%.*}).log"   # Logs sammlen
LOGSET=/log/logset_$(date +"%d%m%Y_%H%M") # Wenn gesetzt, LogSet erstellen
TEMPDIR="/tmp"                       # Temp im RAM
MAILFILE="${TEMPDIR}/mail.txt"       # Für die eMail
REBOOTFLAG="/video/.rebootflag"      # Wenn gesetzt - Maximal 2 Reboot's

# Funktionen
function log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  logger -s -t "$(basename ${0%.*})" "$*"
  [ -w "$LOG_FILE" ] && echo "$(date +"%F %T") => $*" >> "$LOG_FILE" # Zusätzlich in Datei schreiben
}

function _mail() {
  if [ -n "$MAILFILE" ] ; then  # Wenn gesetzt Mail senden
     echo "From: \"VDR\"<${MAIL_ADRESS}>" > $MAILFILE
     echo "T0: ${MAIL_ADRESS}" >> $MAILFILE
     echo "Subject: $(basename ${0%.*})" >> $MAILFILE
     echo "" >> $MAILFILE
     echo "$DVBNUM von $DVB_CARD_NUM DVB-Adapter gefunden! ($DVBNUM/$DVB_CARD_NUM)" >> $MAILFILE
     echo "$DMESG:" >> $MAILFILE
     echo "" >> $MAILFILE
     cat $DMESG >> $MAILFILE
     echo "" >> $MAILFILE
     echo "Syslog (Die letzten 75 Zeilen)" >> $MAILFILE
     tail -n75 $MESSAGES >> $MAILFILE
     echo "" >> $MAILFILE
     /usr/sbin/sendmail root < $MAILFILE
  fi
}

function checkreboot() {
  if [ -n "$LOGSET" ] ; then         # Wenn gesetzt - LogSet erstellen
     log "Logset wird erstellt"
     /_config/bin/g2v_log.sh -v "$LOGSET"
  fi
  if [ -n "$REBOOTFLAG" ] ; then     # Wenn gesetzt - Reboot?
     REBOOTNUM=0
     [ -e "$REBOOTFLAG" ] && REBOOTNUM=$(<$REBOOTFLAG)     # Nummer einlesen
     if [ "$REBOOTNUM" -le 2 ] ; then                        # Max. 2 Reboot's
        (( REBOOTNUM++ )) ; echo $REBOOTNUM > "$REBOOTFLAG" # +1 und speichern
        log "=> Reboot ($REBOOTNUM) wird ausgelöst! <="
        sleep 5 ; reboot
     fi
  fi
}

# Skript start!
[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]]  && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

if [ "$CHECKUPTIME" != "1" ] ; then                        # Nur wenn nicht 1
  UPTIME=( $(cat /proc/uptime) )                           # Get UpTime Values
  UPTIME[0]=${UPTIME[0]%.*}                                # Remove the .*
  if [ "${UPTIME[0]}" -gt 300 ] ; then
    log "System läuft länger als 5 Minuten (${UPTIME[0]} Sekunden) -> Exit."
    exit 1
  fi
fi

DVBNUM=$(find /dev/dvb/adapter* -type d | wc -l)        # Liste der Adapter
if [ "$DVBNUM" -lt "$DVB_CARD_NUM" ] ; then
   log "!!! Warnung !!! $DVBNUM von $DVB_CARD_NUM DVB-Adapter gefunden! ($DVBNUM/$DVB_CARD_NUM) <="
   _mail "$DVBNUM" ; checkreboot
else
    log "OK - $DVBNUM DVB-Adapter gefunden ($DVBNUM/$DVB_CARD_NUM)"
    [ -n "$REBOOTFLAG" ] && [ -e "$REBOOTFLAG" ] && rm -f $REBOOTFLAG # OK, Flag löschen
fi

exit
