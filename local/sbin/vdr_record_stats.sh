#!/bin/bash

# vdr_record_stats.sh
# Verarbeitet die Datei 'vdr.records' im Video-Verzeichnis
# Aufnahmen aud den Vorjahren werden in einzelne Dateien verschoben und gepackt

# VERSION=170215

source /_config/bin/g2v_funcs.sh

VDR_RECORD='vdr.record'           # Die Datei, wo die Aufnahmen stehen
VDR_REC_ARCH='vdr.record.tar.xz'  # Archiv mit den alten Aufnahmen
TMP_DIR="$(mktemp -d)"             # Zum zwischenspeichern von Daten
ACT_YEAR="$(date +%Y)"            # Aktuelles Jahr (JJJJ)
cnt=0 ; del=0                     # Zählervariablen

# Testen, ob die 'vdr.record' vorhanden ist
if [[ -e "${VIDEO}/${VDR_RECORD}" ]] ; then
  echo "Verwende Datei \"${VIDEO}/${VDR_RECORD}\""
else
  echo "Datei \"${VIDEO}/${VDR_RECORD} nicht gefunden!\""
  exit 1
fi

# Archiv bereits vorhanden?
if [[ -e "${VIDEO}/${VDR_REC_ARCH}" ]] ; then
  echo "Entpacke Archiv ${VIDEO}/${VDR_REC_ARCH} nach $TMP_DIR"
  tar --extract --file="${VIDEO}/${VDR_REC_ARCH}" --directory "$TMP_DIR"
fi

# vdr.record zeilenweise lesen
while read -r ; do
  # G2V vdr_record: 2014-08-15 23:52 /tmp/vdr/vdr_record before /video/Hannibal/Höhere_Gewalt/2014-08-15.23.52.27-0.rec
  if [[ "$REPLY" =~ /([[:digit:]]{4})-(.*).rec ]] ; then  # Aufnahmen ohne *.del
    # echo "${BASH_REMATCH[1]}"  # Jahr (JJJJ)
    [[ -n "${BASH_REMATCH[1]}" ]] && echo "$REPLY" >> "${TMP_DIR}/${VDR_RECORD}.${BASH_REMATCH[1]}"
    ((cnt++))
  else
    :  # echo "Kein Jahr gefungen: $REPLY"  # Gelöschte Aufnahme
    ((del++))
  fi
done < "${VIDEO}/${VDR_RECORD}"

echo "==> $cnt Zeilen verarbeitet"
echo "==> $del Zeilen verworfen (*.del)"

# Datei für das aktuelle Jahr nach vdr_record kopieren
if [[ -e "${TMP_DIR}/${VDR_RECORD}.${ACT_YEAR}" ]] ; then
  echo "Ersetze $VDR_RECORD mit Aufnahemn aus dem aktuellem Jahr"
  cp --force "${TMP_DIR}/${VDR_RECORD}.${ACT_YEAR}" "${VIDEO}/${VDR_RECORD}"
else
  echo "Keine Aufnahmen im aktuellem Jahr gefunden!"
fi

# Datei(en) in das Archiv
cd "$TMP_DIR"  # Dateien im Archiv ohne Pfad speichern
tar --create --auto-compress --file="${VIDEO}/${VDR_REC_ARCH}" "${VDR_RECORD}".*
cd -  # Zurück zum letzten Verzeichnis

rm --recursive --force "$TMP_DIR"

exit  # Ende
