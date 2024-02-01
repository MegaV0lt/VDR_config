#!/bin/bash

# nalu_stat.sh
#VERSION=200427

# Wird von Syslog-NG/Metalog aufgerufen. Eintrag in metalog.conf:

# NALUFILL :
#    maxsize  = 262144   # size in bytes (256 kb)
#    maxfiles = 2        # num files per directory
#    program = "vdr"
#    logdir = "/var/log/vdr"
#    regex    = "NALU"
#    #regex    = "cNalu"
#    command = "/usr/local/sbin/nalu_stat.sh"
#    break = 1

# Beispiel Log
# Jun 02 13:44:48 [vdr] [10987] NALU fill dumper: 125679 of 374715 packets dropped, 33% (/video/Brisant/2015-06-02.13.25.67-0.rec/00001.ts)
# ^$1             ^$2           ^$3

# Wenn Syslog-NG verwendet wird, startet Syslog-NG das Skript und schickt die
# Meldung via stdin an das Skript. Dazu wird eine "while" schleife verwendet."
# Apr  1 15:00:00 hdvdr01 vdr[3389]: [3389] NALU fill dumper: 0 of 17374783 packets dropped, 0% (/video/Arrow/Seelenjagd__(S04E05)/2016-04-01.14.05.20-0.rec/00002.ts)

# Check auf logdir (metalog Regel)
# [ ! -d "/var/log/vdr" ] && mkdipr -p "/var/log/vdr"

# logger -s -t $(basename $0) "$0 - $1 - $2 - $3"  # 1: Datum/Zeit
                                                   # 2: programm
                                                   # 3: Meldung

# --- Variablen ---
LOG_DIR='/var/log'
LOG_FILE="${LOG_DIR}/nalu_stat.log"
MAX_LOG_SIZE=$((1024*20))                         # Log-Datei: Maximale gr��e in Byte
printf -v RUNDATE '%(%d.%m.%Y %R)T' -1          # Aktuelles Datum und Zeit (31.03.2019 10:24)
NO_ZEROLOG=1                                    # Keine "0% Meldungen" loggen

# --- Funktionen ---
f_log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  # logger -s -t $(basename ${0%.*}) "$*"  # Syslog deaktiviert, da doppelt
  [[ -n "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log in Datei
}

f_check_logsize() {
  if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu gro�
    FILE_SIZE="$(stat -c %s "$LOG_FILE")"
    [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv -f "$LOG_FILE" "${LOG_FILE}.old"
  fi
}

f_format_recordstring() {
  if [[ "${LOGSTRING[-2]}" == '0%' && -n "$NO_ZEROLOG" ]] ; then
    echo "No Log (0% Dropped)"  # 0% nicht loggen
  else
    RECORDING="${LOGSTRING[@]: -1}"             # Letztes Element
    RECORDING="${RECORDING/\/video\/}"          # /video/ entfernen
    RECORDING="${RECORDING%\/*.rec*}"           # Das /*.rec/*.ts entfernen
    f_log "$RUNDATE ${LOGSTRING[@]: -10:9} ${RECORDING})"  # Nachricht in das Log
    f_check_logsize
  fi
}

# --- Start ---
if pidof syslog-ng >/dev/null ; then  # Syslog-NG l�uft
  while read -r ; do
    LOGSTRING=($REPLY)                          # Meldung in Array
    printf -v RUNDATE '%(%d.%m.%Y %R:%S)T' -1   # Aktuelles Datum und Zeit (31.03.2019 10:24:01)
    f_format_recordstring                       # String bearbeiten und Loggen
  done
else  # Metalog?
  if [[ "$3" =~ 'NALU fill dumper:' ]] ; then
    LOGSTRING=($3)  # In ein Array
    f_format_recordstring                       # String bearbeiten und Loggen
  fi
fi

sleep 0.1
f_log "Exiting (PID $$)"                        # Ende?

exit
