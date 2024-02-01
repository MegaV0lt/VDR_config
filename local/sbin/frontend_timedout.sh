#!/bin/sh

# frontend_timedout.sh
# $3= [3472] frontend 0/0 timed out while tuning to channel 958, tp 111747
#     0      1        2   3     4   5     6      7  8       9    10 11

# Wird von Metalog aufgerufen wen VDSB im Log steht. Eintrag in metalog.conf:
#
#VDR_Frontend :
#    program = "vdr"
#    logdir = "/var/log/vdr"
#    #regex    = "(switching|VDSB)"
#    regex    = "frontend (0|1|2|3)/(0|1|2|3) timed out while tuning to channel"
#    command = "/usr/local/sbin/frontend_timedout.sh"
#    break = 1

# Check auf logdir (metalog Regel)
#[ ! -d "/var/log/vdr" ] && mkdipr -p "/var/log/vdr"

#logger -s -t $(basename $0) "$0 - $1 - $2 - $3"  #1: Datum/Zeit
                                                #2: programm
                                                #3: Meldung


exit


# Variablen
TMP_DIR=$(mktemp -d)

# Funktionen
function cleanup() { # Aufr�umen
  rm -rf $TMP_DIR
  exit
}

function newline() {
         echo "" >> $TMP_DIR/fe.txt
}

# Skriptstart
echo "$0 - $1 - $2 - $3" > $TMP_DIR/fe.txt

# Kanal herausfinden
CHANNEL=( $3 ) ; CHANNEL[9]=${CHANNEL[9]/,}   # Ins Array und "," entfernen
echo "Kanal: ${CHANNEL[9]}" >> $TMP_DIR/fe.txt

#newline ; echo "Tuner-Status:" >> $TMP_DIR/fe.txt
#for i in {0..2} ; do
#  echo "=> DVB${i}" >> $TMP_DIR/fe.txt
#  #femon -H -c3 -a${i} >> $TMP_DIR/fe.txt         # femon -H -c3 -a0
#  /usr/bin/svdrpsend plug femon info ${i} >> $TMP_DIR/fe.txt
#  sleep 0.5
#done

echo "=> DVB${CHANNEL[2]:0:1}" >> $TMP_DIR/fe.txt
/usr/bin/svdrpsend plug femon info ${CHANNEL[2]:0:1} >> $TMP_DIR/fe.txt

# Laufende Aufzeichnungen und Timer
NT=$(svdrpsend.pl NEXT rel |grep "^250" |cut -f 3 -d " ")
if [ "${NT:0:1}" == "-" ] ; then
   newline ; echo "Laufende Aufnahmen:" >> $TMP_DIR/fe.txt
   find -L /video -name .rec -type f -print | xargs ls -l >> $TMP_DIR/fe.txt
   newline ; echo "Laufende Timer:" >> $TMP_DIR/fe.txt
   grep "^[5..99]:" /etc/vdr/timers.conf >> $TMP_DIR/fe.txt
fi

# Logs f�r sp�tere Auswertung sichern
#cp $LOG_DIR/messages $TMP_DIR

# Die letzten xx Zeilen der messages in die info
#newline ; echo "Logmeldungen:" >> $TMP_DIR/fe.txt
#tail -n 25 $LOG_DIR/messages >> $TMP_DIR/fe.txt

# Packen (z=gzip, J=xz)
#tar cfvz [ARCHIV].tar.gz [VERZEICHNIS1] [DATEI1]
#tar cfvJ $LOG_DIR/$ARCHIV $TMP_DIR

# Nach Log
cat $TMP_DIR/fe.txt >> /log/frontend.log

# Kanal aud channels.conf l�schen
if [ ${CHANNEL[9]} -gt 300 ] ; then
   echo "L�sche Kanal ${CHANNEL[9]}"
   #/usr/bin/svdrpsend DELC ${CHANNEL[9]}
fi

cleanup

exit
