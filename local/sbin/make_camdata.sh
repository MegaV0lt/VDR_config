#!/bin/bash

# make_camdata.sh - Datei cam.data des VDR mit allen Kanal-ID' der channels.conf füllen
# Author: MegaV0lt
#VERSION=200311

# Funktionsweise:
# Kanalliste wird Zeilenweise nach verschlüsselten Kanälen durchsucht und
#+eine Kanal-ID in der cam.data gespeichert

# Einstellungen
CHANNELSCONF='/etc/vdr/channels.conf'   # Kanalliste des VDR
CAMDATA='/var/cache/vdr/cam.data'       # cam.data Datei
LOG_FILE='/var/log/make_camdata.log'     # Zusätzliches Logfile
printf -v RUNDATE '%(%d.%m.%Y %R)T' -1  # Aktuelles Datum und Zeit

# Funktionen
log() {  # Gibt die Meldung auf der Konsole und im Syslog aus
  #logger -s -t "$(basename "${0%.*}")" "$*"
  if [[ -w "$LOG_FILE" ]] ; then
    echo "$*" >> "$LOG_FILE"
  else
    echo "$*"  # Ausgabe auf der Konsole
  fi
}

### Skript start!
if [[ -w "$LOG_FILE" ]] ; then
   : #log "$RUNDATE - $(basename $0) - Start..."
fi

if [[ ! -e "$CHANNELSCONF" ]] ; then  # Prüfen, ob die channels.conf existiert
   log "FATAL: $CHANNELSCONF nicht gefunden!"
   exit 1
fi

if [[ -s "$CAMDATA" ]] ; then  # Datei ist größer als 0 Byte!
  #log "Erstelle Backup der Datei $CAMDATA und beende"
  cp --force "$CAMDATA" "${CAMDATA}.bak"
  exit 0
else
  log "Datei $CAMDATA fehlt oder ist 0 Byte groß!"
fi

# n-tv HD;CBC:10832:HC23M5O35P0S1:S19.2E:22000:1279=27:0;1283=deu@106,1284=mul@106:36:1830,1843,1860,98C,9C4,648,650,186A,500,6CB,186D,6E2:61204:1:1057:0
# 0           1     2             3      4     5       6                           7  8                                                    9     10 11  12
while read -r CHANNEL ; do
  if [[ "${CHANNEL:0:1}" = ':' ]] ; then  # Marker auslassen (: an 1. Stelle)
    continue                              # Weiter mit der nächsten Zeile
  fi
  IFS=':' read -r -a TMPCHANNEL <<< "$CHANNEL"  # Feldtrenner in der cahnnels.conf
  if [[ "${TMPCHANNEL[8]}" == '0' ]] ; then     # Kanal ist nicht verschlüsselt
    #log "Kanal ${TMPCHANNEL[0]} ist unverschlüsselt"
    continue
  else  # Verschlüsselt  [S19.2E-1-1057-61204 1]
    TMPCAMDATA+=("${TMPCHANNEL[3]}-${TMPCHANNEL[10]}-${TMPCHANNEL[11]}-${TMPCHANNEL[9]} 1")
    #log "Kanal ${TMPCHANNEL[0]}: ID: ${TMPCAMDATA[@]: -1}"
  fi
done < "$CHANNELSCONF"

for CAMID in "${TMPCAMDATA[@]}" ; do
  echo "$CAMID" >> "$CAMDATA"
done

log "${#TMPCAMDATA[@]} Kanäle in $CAMDATA geschrieben."

if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu groß
   [[ "$LOG_FILE" -gt $((50*1024)) ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

exit
