#!/bin/bash
source /etc/vdr.d/conf/gen2vdr.cfg
source /etc/vdr.d/conf/vdr
#set -x

LCDDEV="/dev/lcd0"
cnt=0

function log() {
  # LOG_LEVEL (0=Aus,1=Normal,2=Info,3=Debug)
  if [ ${LOG_LEVEL} == 3 ] ; then
    logger -s "[$(basename $0)] $1"
  fi
}

log "...Starte"

# LCDd beenden
[ "$(pidof LCDd)" != "" ] && /etc/init.d/LCDd stop

until [ -c "$LCDDEV" ] ; do      # Warte auf Verzeichnis
      log "Warte auf $LCDDEV"
      sleep 0.5 ; (( cnt++ ))
      if [ $cnt -gt 5 ] ; then   # Max. 5 Versuche
         log "Kein ${LCDDEV}! Abbruch"
         exit 1
      fi
done

log "...Ende"
