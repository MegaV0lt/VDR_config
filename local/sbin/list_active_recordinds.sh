#!/bin/bash

# list_active_recordings.sh

# Laufende Aufzeichnungen und Timer
echo "Laufende Aufnahmen (.rec):"
find -L /video -name .rec -type f -print | xargs ls -lh
#find -L /video -name .rec -type f -print -exec ls -lh "$(dirname {})" \;

# Alte Rec-Flags löschen
echo "Lösche alte \".rec\" Dateien (24 Stunden und älter):"
find -L /video -name .rec -type f -mtime +1 -print -delete

echo "Laufende Timer (timers.conf):"
grep "^[5..99]:" /etc/vdr/timers.conf

exit
