#!/bin/bash

# checknet.sh
# Prüft '/sys/class/net/eth0/carrier' und startet net.eth0 neu
VERSION=151009

#exit   # Deaktiviert!

### Variablen
ETH="eth0"                                # Interface
ETH_CARRIER="/sys/class/net/${ETH}/carrier" # 0 oder 1 (aktiv)
LOG="/var/log/$(basename ${0%.*}).log"    # Log
MAX_LOG_SIZE=$((10*1024))                   # In Bytes

### Funktionen
check_linkstate(){
  LINK_STATE=$(<$ETH_CARRIER)             # Wert einlesen
}

### Start
[ ! -e $ETH_CARRIER ] && echo "$ETH_CARRIER nicht gefunden!" && exit 1

#[ -e $LOG ] && mv -f $LOG $LOG.old        # Altes Log sichern
echo "$(date +'%F %R') - $0 Start" >> $LOG

check_linkstate                           # Link-Status einlesen
if [ "$LINK_STATE" == "1" ] ; then        # OK
  echo "Link is up!" >> $LOG
else
  echo "Restarting net.$ETH" >> $LOG
  /etc/init.d/net.$ETH restart
  check_linkstate                         # Link-Status einlesen
  [ "$LINK_STATE" == "0" ] && echo "Link is down!" >> $LOG
  #reboot                                 # Reboot to fix!?
fi

if [ -e "$LOG" ] ; then       # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE=$(stat -c %s $LOG)
  [ $FILE_SIZE -ge $MAX_LOG_SIZE ] && mv -f "$LOG" "$LOG.old"
fi

exit
