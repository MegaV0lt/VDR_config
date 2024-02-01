#!/bin/bash

# checkmem.sh
VERSION=200603

#exit   # Deaktiviert!

### Variablen
LOG="/var/log/checkmem.log"    # Log
MAX_LOG_SIZE=$((10*1024*1024))   # In Bytes

### Start
printf "%(%F %R)T - $0 Start\n" >> "$LOG"

until pidof vdr ; do  # Auf VDR warten
  sleep 10
done

while true ; do
  /usr/local/src/_div/ps_mem.git/ps_mem.py >> "$LOG"
  sleep 10m  # Alle 10 Mnuten
done

if [[ -e "$LOG" ]] ; then       # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE=$(stat -c %s "$LOG")
  [[ "$FILE_SIZE" -ge "$MAX_LOG_SIZE" ]] && mv -f "$LOG" "${LOG}.old"
fi

exit
