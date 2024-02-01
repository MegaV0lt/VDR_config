#!/bin/bash

# vdsb_timer.sh
# VDR Video Data Stram Broken

# Wird von Metalog aufgerufen wenn VDSB im Log steht. Eintrag in metalog.conf:

#VDR :
#    program = "vdr"
#    #logdir = "/var/log/vdr"
#    regex    = "ERROR: video data stream broken"
#    command = "/usr/local/sbin/vdsb_timer.sh"
#    break = 1

#logger -s -t $(basename $0) "$0 - $1 - $2 - $3"  #1: Datum/Zeit
                                                #2: programm
                                                #3: Meldung

### Variablen ###
LOG_DIR="/var/log"                             # System-Logdir
LOG_FILE="${LOG_DIR}/$(basename ${0%.*}).log"
MAX_LOG_SIZE=$((1024*50))                       # Log-Datei: Maximale gr��e in Byte
TMP_DIR=$(mktemp -d)
SVDRP_CMD="/usr/bin/svdrpsend"
# F�r das "Lock"
SCRIPTNAME=$(basename $0)
LOCKFILE="/var/lock/${SCRIPTNAME}"
LOCKFD=99

### Funktionen ###
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
shlock()            { _lock s; }   # obtain a shared lock
unlock()            { _lock u; }   # drop a lock

cleanup() { # Aufr�umen
  echo "Cleanup..."
  XARGS_OPT="--null --no-run-if-empty" # Optionen f�r "xargs"
  rm -rf $TMP_DIR
  # L�sche alte .rec-Dateien die �lter als 2 Tage sind
	find /video -type f -mtime +2 -name ".rec" -print0 | xargs ${XARGS_OPT} rm
  if [ -e "${LOG_FILE}" ] ; then       # Log-Datei umbenennen, wenn zu gro�
    FILE_SIZE=$(stat -c %s $LOG_FILE)
    [ $FILE_SIZE -gt $MAX_LOG_SIZE ] && mv -f "${LOG_FILE}" "${LOG_FILE}.old"
  fi
  exit
}

### Start ###
echo "$(basename $0) $0 - $1 - $2 - $3" >> ${LOG_FILE}

if [ "${1^^}" == "TEST" ] ; then
  _prepare_locking      # Prepare lock
  # Simplest example is avoiding running multiple instances of script.
  exlock_now || { echo "Already running! Exiting..." ; exit 1 ;}
  echo "[PID: $$] Waiting..."
  sleep 15
  cleanup
  exit
fi

# Meldung am VDR
#svdrpsend MESG "$MESG"
#[ $LOGNUM -gt 3 ] && cleanup    # Ende

# Laufende Aufzeichnungen und Timer
#echo -e "\nLaufende Aufnahmen (.rec):" >> $TMP_DIR/info.txt
#find -L /video -name .rec -type f -print | xargs ls -l >> $TMP_DIR/info.txt
#echo -e "\nLaufende Timer:" >> $TMP_DIR/info.txt
#grep "^[5..99]:" /etc/vdr/timers.conf >> $TMP_DIR/info.txt

# Laufende Timer (LSTT) [Jede Zeile ein Feld]
OLDIFS="$IFS" ; IFS=$'\n'
TIMERS=($(svdrpsend LSTT | grep ^9:)) ; IFS="$OLDIFS"
# Laufende Aufnahmen (.rec) in Array
REC_DIRS=($(find -L /video -name .rec -type f -print))

for rec_dir in ${REC_DIRS[@]} ; do
  REC_NAME="$(cat $rec_dir)" # Der Name wie im Timer (Hoffentlich)
  REC_INDEX="${rec_dir%.rec}index" # Index-Datei
  if [ $(stat --format=%Y $REC_INDEX) -le $(( $(date +%s) - 20 )) ]; then
    echo "$REC_INDEX ist �lter als 20 Sekunden! M�glicher VDSB!"
    # Timer bestimmen
    if [ "${TIMERS[@]}" =~ "$REC_NAME" ] ; then  # Timer in der Liste enthalten!
      for timer in ${TIMERS[@]} ; do
        if [ "$timer" =~ "$REC_NAME" ] ; then    # Timer gefunden
          OLDIFS="$IFS" ; IFS=":"
          VDRTIMER=($timer) # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekr�fte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
                            # ^0        ^1 ^2         ^3   ^4   ^5 ^6 ^7
          IFS="$OLDIFS" ; TIMER_NR="${VDRTIMER[0]:3}" # 250- entfernen
          TIMER_NR="${TIMER_NR% *}"                   # Alles nach der Timernummer entfernen
          echo "Deaktiviere Timer Nummer $TIMER_NR (${VDRTIMER[7]})"
          svdrpsend MODT $TIMER_NR off    # Timer deaktivieren
          break # for Schleife beenden
        fi
      done # for timer
    else
      echo "Timer f�r $REC_NAME nicht gefunden!"
    fi
  fi # stat
done

# Optional: Loggen und oder Mailen!

#  svdrpsend LSTT 147
#220 hdvdr01 SVDRP VideoDiskRecorder 2.2.0; Fri Nov 13 11:21:06 2015; UTF-8
#250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekr�fte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
#221 hdvdr01 closing connection


exit


# Logset beim ersten VDSB
if [[ "$3" =~ "video data stream broken" ]] ; then
  if [ $LOGNUM -eq 1 ] ; then
    screen -dm sh -c "/_config/bin/g2v_log.sh -v ${TMP_DIR}/logset"
    #until [ -e "${TMP_DIR}/logset.7z" ] ; do    # Warte auf Datei (Gen2VDR V3)
    until [ -e "${TMP_DIR}/logset.tar.xz" ] ; do # Warte auf Datei (Gen2VDR ab V4)
      sleep 0.5 ; (( cnt++ ))
      [ $cnt -gt 120 ] && break                 # max. 60 Sekunden
    done
  fi
fi

# Packen (z=gzip, J=xz)
#tar --create --absolute-names --auto-compress --file=$LOG_DIR/$ARCHIV $TMP_DIR
tar --create --auto-compress --file=$LOG_DIR/$ARCHIV $TMP_DIR


# Mail beim ersten VDSB senden
if [ $LOGNUM -eq 1 ] ; then
  echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>" > $MAILFILE
  echo "T0: ${MAIL_ADRESS}" >> $MAILFILE
  echo "Subject: VDSB - ${HOSTNAME}" >> $MAILFILE
  echo -e "\nEs wurde ein 'Video Data Stream Broken' entdeckt!" >> $MAILFILE
  echo "Der VDR wird beim n�chsten mal einmalig neu gestartet." >> $MAILFILE
  echo -e "Inhalt von $TMP_DIR/info.txt:\n" >> $MAILFILE
  cat $TMP_DIR/info.txt >> $MAILFILE
  /usr/sbin/sendmail root < $MAILFILE
fi

cleanup

exit
