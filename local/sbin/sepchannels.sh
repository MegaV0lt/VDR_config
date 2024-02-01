#!/bin/bash

# sepchannels.sh - Kanalliste des VDR nach Satpositionen trennen
# Author: MegaV0lt, Version: 20230525

# Funktionsweise:
# Kanalliste wird Zeilenweise nach Sat-Positionen durchsucht und je Sat-Position
#+wird eine neue channles.conf.* erstellt. Kanalgruppen werden nur gespeichert,
#+wenn auch Kanäle dazu gefunden wurden.

# Einstellungen
CHANNELSCONF='/var/lib/vdr/channels.conf'  # Kanalliste des VDR
SATPOS=('9.0E' '19.2E')                    # Nach diesen Sat-Positionen wird gesucht
#LOG_FILE='/var/log/sepchannels.log'         # Zusätzliches Logfile
MAX_LOG_SIZE=$((50*1024))                    # 50 kB
printf -v RUNDATE '%(%d.%m.%Y %R)T' -1     # Aktuelles Datum und Zeit

# Funktionen
f_log() {  # Gibt die Meldung auf der Konsole und im Syslog aus
  #logger -s -t "$(basename "${0%.*}")" "$*"
  [[ -n "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"
}

# Skript start!

if [[ -n "$LOG_FILE" ]] ; then
   f_log "$RUNDATE - $(basename $0) - Start…"
fi

[[ -n "$*" ]] && SATPOS=($*)      # Übergabe Sat-Positionen via Parameter

if [[ ! -e "$CHANNELSCONF" ]] ; then        # Prüfen, ob die channels.conf existiert
   f_log "FATAL: $CHANNELSCONF nicht gefunden!"
   exit 1
fi

for SAT in "${SATPOS[@]}" ; do
    chan=0                           # Zähler auf 0 setzen (je Sat-Position)
    CHANNELSAKT="${CHANNELSCONF}.${SAT/./_}"  # . durch _ ersetzen
    [[ -e "$CHANNELSAKT" ]] && mv -f "$CHANNELSAKT" "${CHANNELSAKT}.old"  # Alte Liste sichern
    while read -r CHANNEL ; do
      if [[ "${CHANNEL:0:1}" == ':' ]] ; then  # Marker auslassen (: an 1. Stelle)
         if [[ -n "$MARKERTMP" ]] ; then       # Gespeicherter Marker vorhanden?
            f_log "Leere Kanalgruppe \"${MARKERTMP:1}\" aus $CHANNELSAKT entfernt!"
         fi
         MARKERTMP="$CHANNEL"                   # Marker zwischenspeichern
         continue                               # Weiter mit der nächsten Zeile
      fi
      if [[ "$CHANNEL" =~ $SAT ]] ; then        # Sat-Position gefunden?
        if [[ -n "$MARKERTMP" ]] ; then         # Gespeicherter Marker vorhanden?
           echo "$MARKERTMP" >> "$CHANNELSAKT"  # Marker in die neue Liste
           unset -v 'MARKERTMP'                 # Gespeicherten Marker löschen
        fi
        echo "$CHANNEL" >> "$CHANNELSAKT"       # Kanal in die neue Liste
        ((chan++))
      fi
      done < "$CHANNELSCONF"
      if [[ -n "$MARKERTMP" ]] ; then            # Gespeicherter Marker vorhanden?
         if [[ "$MARKERTMP" =~ ':==' ]] ; then   # Keine neuen Kanäle seit letzem Lauf!
            echo "$MARKERTMP" >> "$CHANNELSAKT"  # Marker in die neue Liste
         else
            f_log "Leere Kanalgruppe \"${MARKERTMP:1}\" am Ende von $CHANNELSAKT entfernt!"
         fi
         unset -v 'MARKERTMP'                    # Gespeicherten Marker löschen
      fi
      f_log "=> $chan Kanäle in $CHANNELSAKT"
done  # for

if [[ "$EUID" -eq 0 ]] ; then
  for file in /var/lib/vdr/channels.* ; do
    chown vdr:vdr "$file"
  done
fi

if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat --format=%s "$LOG_FILE" 2>/dev/null)"
  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

exit
