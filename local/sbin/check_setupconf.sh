#!/usr/bin/env bash

# check_setupconf.sh - Prüfen, ob beim VDR-Start Fehler im der setup.conf
# vorhanden sind. Beispiel:
# Sep 03 12:30:25 [vdr] [3372] ERROR: unknown config parameter: SupportTeletext = 0

# Author: MegaV0lt
#VERSION=241204

# Aktivierung ab GenVDR V3:
# echo /usr/local/sbin/check_setupconf.sh > /etc/vdr.d/8101_check_setupconf

# set -x

# --- Einstellungen ---
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"   # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"
SETUPCONF="$(readlink -m /etc/vdr/setup.conf)"    # VDR's setup.conf
SYSLOG='/var/log/syslog'                          # Syslog, wo nach den Meldungen gesucht wird
WAITTIME=10                                       # Wartezeit, bis VDR gestartet ist
SEARCHSTRING='ERROR: unknown config parameter:'   # Ferhlerstring
FOUND_ERRORS="/var/log/${SELF_NAME%.*}.errdb"     # Gefundene Fehler
declare -a TMP_RESULT                             # Zwischenspeicher für gefundene Einträge
declare -a TMP_SETUPCONF                          # Zwischenspeicher für setup.conf

# Optionale Einstellungen
LOG="/var/log/${SELF_NAME%.*}.log"                # Logs sammlen

# --- Funktionen ---
f_log() {  # Gibt die Meldung auf der Konsole und im Syslog aus
  logger -t "${SELF_NAME%.*}" "$*"
  [[ -t 1 ]] && echo "$*"
  if [[ -n "$LOG" ]] ; then
    [[ ! -e "$LOG" ]] && : >> "$LOG"
    [[ -w "$LOG" ]] && echo "$(date +"%F %T") => $*" >> "$LOG"  # Zusätzlich in Datei schreiben
  fi
}

# --- Start ---
[[ "$1" == '--background' ]] && MAINSCRIPT=0

if [[ -e "$FOUND_ERRORS" ]] ; then       # Es sind bereits Fehler gespeichert worden
  mapfile -t < "$FOUND_ERRORS"           # Gespeicherte Fehler einlesen (Array MAPFILE)
  f_log "${#MAPFILE[@]} Einträge eingelesen! (${FOUND_ERRORS})"
  while read -r ; do                     # setup.conf zeilenweise lesen
    for entry in "${MAPFILE[@]}" ; do
      if [[ "$REPLY" == "$entry" ]] ; then
        f_log "Eintrag in $SETUPCONF gefunden! (${REPLY})"
        FOUND=true
        break  # Schleife beenden
      fi
    done

    if [[ -z "$FOUND" ]] ; then
      TMP_SETUPCONF+=("$REPLY")        # In Array speichern
      unset -v 'FOUND'
    fi
  done < "$SETUPCONF"

  if pidof vdr &>/dev/null ; then
    f_log "VDR läuft! - Speichere unter ${SETUPCONF}.new"
    printf '%s\n' "${TMP_SETUPCONF[@]}" > "${SETUPCONF}.new"  # Neue setup.conf
  else
    mv --force "$SETUPCONF" "${SETUPCONF}.bak"  # Sichern
    printf '%s\n' "${TMP_SETUPCONF[@]}" > "$SETUPCONF"  # Neue setup.conf
    rm "$FOUND_ERRORS"  # Datei löschen
  fi
else
  if [[ -z "$MAINSCRIPT" ]] ; then
    f_log "Keine ${FOUND_ERRORS}-Datei gefunden. Starte im Hintergrund neu! - Exit"
    "$SELF" --background &>/dev/null & disown  # Neu starten im Hintergrund
    sleep 0.5
  else
    until pidof vdr &>/dev/null ; do  # Warten, bis VDR gestartet ist
      f_log 'Warte auf VDR-Start…'
      sleep 1 ; ((cnt++))
      [[ "$WAITTIME" -le "$cnt" ]] && break
    done

    while read -r ; do                              # /var/log/syslog
      case "$REPLY" in
        *$SEARCHSTRING*)
          TMP_RESULT+=("${REPLY#*$SEARCHSTRING }")  # SupportTeletext = 0
          f_log "Eintrag gefunden (${REPLY#*$SEARCHSTRING })"
        ;;
      esac
    done < <(tail -n 500 "$SYSLOG")

    # Speichern und dabei doppelte Einträge löschen und sortieren
    [[ -n "${TMP_RESULT[*]}" ]] && printf '%s\n' "${TMP_RESULT[@]}" | sort -u > "$FOUND_ERRORS"
  fi
fi

f_log "Skriptende! (PID: $$)"

exit
