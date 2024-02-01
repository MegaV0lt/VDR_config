#!/bin/bash

# Skript sortiert die channels.conf ab dem Marker ":Andere"
#
# Unter Gen2VDR aktivieren:
# echo "/usr/local/sbin/sort_channels.sh" > 8002_sort_channels
#
# Original von C3PO @ VDR-Portal.de
# Bearbeitet von MegaV0lt @ VDR-Portal.de
#VERSION=230413

BAK_DIR='/var/lib/vdr/channels_bak'  # Backup für Kanallisten
KEEP_BAK=14                      # Dauer in Tagen, die Listen behalten werden
DEL_OBSOLETE=0                   # Vom VDR als Obsolete markierte Kanäle löschen [0|1]
VDRCONFDIR='/var/lib/vdr'        # VDR's Konfigordner
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
#SELF_NAME="${SELF##*/}"          # skript.sh
SELF_PATH="${SELF%/*}"           # Pfad
printf -v DATE '%(%Y-%m-%d)T' '-1'  # Aktuelles Datum (2019-03-21)
printf -v RUNDATE '%(%d.%m.%Y %R)T' '-1'  # Aktuelles Datum und Zeit (31.03.2019 10:24)

cd "$VDRCONFDIR" || { echo 'Fehler: Kanalliste nicht gefunden!' ; exit 1 ;}
[[ -f "${BAK_DIR}/channels.conf_$DATE" ]] && { echo 'Liste heute schon sortiert!' ; exit 1 ;}  # Nur ein mal pro Tag
[[ -n "$(pidof vdr)" ]] && { echo 'VDR lauft!' ; exit 1 ;}  # VDR läuft?

# Prüfen, ob "-OLD-"-Marker vorhanden sind
if [[ $(grep --text --count '\-OLD\-' channels.conf) -ne 0 ]] ; then
  echo '"-OLD-"-Marker gefunden! Ende!'
  exit 1
fi

[[ ! -d "$BAK_DIR" ]] && mkdir --parents "$BAK_DIR"
cp channels.conf "${BAK_DIR}/channels.conf_$DATE"
awk --file="${SELF_PATH}/sort.awk" channels.conf > channels.conf.sort

# Einen "Neu"-Marker am Ende einfügen
echo ":==> Neu seit $RUNDATE" >> channels.conf.sort

if [[ $DEL_OBSOLETE -eq 1 ]] ; then
  grep --text --invert-match OBSOLETE channels.conf.sort > channels.conf
  rm --force channels.conf.sort
else
  mv --force channels.conf.sort channels.conf
fi

find "$BAK_DIR" -mtime +$KEEP_BAK -delete  # Alte Kanallisten löschen

