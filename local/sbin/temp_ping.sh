#!/bin/sh

# temp_ping.sh
# Check SheevaPlug

SERVER="SheevaPlug"           # Server-Adresse
FLAG="/dev/shm/ServerFlag"
FLAGNUM=0
VDSBLOG="/log/vdr/current"    # VDSB-Log

[ -e $FLAG ] && FLAGNUM=$(cat $FLAG) # Nummer einlesen

ping -c 3 -W 5 $SERVER ; RC=$? # Server anpingen (RC 0 = OK)

if [ $RC -gt 0 -a $FLAGNUM -eq 0 ] ; then
  echo "$RC" > $FLAG    # Flag schreiben (Fail)
fi

if [ $RC -eq 0 -a $FLAGNUM -gt 0 ] ; then
  echo "$RC" > $FLAG    # Flag schreiben (Fail->OK)
  DO_RESTART=1
  for i in 1 2 3 ; do
    if [ "$(svdrpsend volu | grep "^250")" != "" ] ; then
         DO_RESTART=0
         break
    fi
    sleep 10
  done
  if [ "$DO_RESTART" = "1" ] ; then
    logger -s "VDR does not respond - Restarting"
    /etc/init.d/vdr stop
    kill -9 $(pidof vdr runvdr)
    /etc/init.d/vdr start
  else
    ACT_DATE=$(date +%s) ; FDATE=$(stat -c %Y "${VDSBLOG}")
    DIFF=$(($ACT_DATE - $FDATE))     # Sekunden
    if [ $DIFF -lt 45 ] ; then
      #TAGE=$((DIFF /86400)) ; STD=$((DIFF % 86400 /3600))
      #MIN=$((DIFF % 3600 /60)) ; SEK=$((DIFF % 60))
      /etc/init.d/vdr stop
      kill -9 $(pidof vdr runvdr)
      /etc/init.d/vdr start
    fi
  fi
fi

exit
