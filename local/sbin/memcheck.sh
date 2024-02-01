#!/bin/bash

# memcheck.sh
# Speicherleck beim VDR/Plugin suchen
# Im Hintergrund starten mit 'checkmem.sh &'

### Variablen
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"                          # skript.sh
printf -v RUNDATE '%(%F_%H%M)T' -1               # Datum und Zeit
LOG_DIR="/var/tmp/log/checkmem_$RUNDATE"          # Logdir
LOG_FILE="${LOG_DIR}/checkmem.log"


### Start
until VDRPID="$(pidof vdr)" ; do  # Auf VDR warten
  sleep 10
done

mkdir --parents "$LOG_DIR"

{ echo "--> $RUNDATE - $SELF_NAME Start..."
  echo "PID vom VDR: $VDRPID"
} >> "$LOG_FILE"

# Erster Check nach 30 Minuten
sleep 30m
pmap "$VDRPID" > "${LOG_DIR}/pmap.30m"
{ echo '--> pmap nach 30 Minuten'
  cat "${LOG_DIR}/pmap.30m"
} >> "$LOG_FILE"

# Jede Stunde check und diff
while true ; do
  sleep 1h  # Eine Stunde warten
  ((i+=1))  # Zähler für dei Logs
  pmap "$VDRPID" > "${LOG_DIR}/pmap.${i}h"
  diff "${LOG_DIR}/pmap.30m" "${LOG_DIR}/pmap.${i}h" > "${LOG_DIR}/diff.30m_${i}h"
  { echo -e "\n--> DIFF 30m - ${i}h"
    cat "${LOG_DIR}/diff.30m_${i}h"
  } >> "$LOG_FILE"
  if [[ "$i" -gt 1 ]] ; then
    diff "${LOG_DIR}/pmap.$((i-1))h" "${LOG_DIR}/pmap.${i}h" > "${LOG_DIR}/diff.${i}h"
    { echo -e "\n--> DIFF $((i-1))h - ${i}h"
      cat "${LOG_DIR}/diff.${i}h"
    } >> "$LOG_FILE"
  fi
done

exit


