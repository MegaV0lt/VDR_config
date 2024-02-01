#!/bin/bash

# flatPlus_MV_Update.sh
# Skript zum Updaten der MV-Themen
VERSION=170506

# Ordner und Dateien
ICONS='icons' ; THEMES='themes' ; DECORS='decors' ; CONFIGS='configs'
PREVIEWS='preview' ; INFO='MV_Themes.INFO' ; HIST='MV_Themes.HISTORY'

# Ordner für Direktupdate (Im aktuellem Filesystem); Beispiel für Gen2VDR
THEMEDIR='/etc/vdr/themes'
PLUGINDIR='/etc/vdr/plugins/skinflatplus'
ICONDIR="${PLUGINDIR}/icons"
DECORDIR="${PLUGINDIR}/decors"
CONFIGSDIR="${PLUGINDIR}/configs"
PREVIEWDIR="${PLUGINDIR}/preview"

LN='-------------------------------'

f_help() {
  echo "$LN"
  echo "Falsche(r) Parameter: $*"
  echo "Aufruf mit ${0##*/}"
  echo 'Parameter -Silent    Keine Abfragen (Silent Update).'
  echo 'Parameter -Direct    Direktes Update der Daten im Filesysten (/etc/vdr).'
  echo '                     !!! Speziell für Gen2VDR angepasst !!!'
  exit
}

# --- Start ---
# In Skriptordner wechseln (contrib)
cd "$(dirname "$0")"  # Skript im contrib-Ordner

if [[ ! -d "../${ICONS}" || ! -d "../${THEMES}" || ! -d "../${DECORS}" ]] ; then
  echo 'Falsches Verzeichnis! Skript muss im ./contrib-Ordner ausgeführt werden'
  exit 1
fi

if [[ -n "$1" ]] ; then         # Parameter wurde übergeben
  case "$1" in
    -Silent) SILENTUPDATE=1 ; echo "Silent Update! ($1)" ;;
    -Direct) DIRECTUPDATE=1 ; echo "Direct Update! ($1)" ; unset -v 'SILENTUPDATE' ;;
    *)       f_help "$@" ;;
  esac
fi

# MV_Themes Löschen!
if [[ -z "$SILENTUPDATE" ]] ; then
  echo "$LN"
  [[ -n "$DIRECTUPDATE" ]] && echo 'ACHTUNG: MV_Themen in /etc werden gelöscht!'
  read -p 'MV_Themen löschen? (J/n)' -t 5 TASTE
  if [[ "${TASTE^^}" == "N" ]] ; then
    echo 'Skript abgebrochen. Es wurde nichts gelöscht!'
    exit
  fi
fi

if [[ -n "$DIRECTUPDATE" ]] ; then # Löschen im Dateisystem (/etc)
  [[ -d "$ICONDIR" ]] && rm -rf "${ICONDIR}"/MV*
  [[ -d "$THEMEDIR" ]] && rm -f "${THEMEDIR}"/flatPlus-MV*
  [[ -d "$DECORDIR" ]] && rm -f "${DECORDIR}"/*MV*
  [[ -d "$CONFIGSDIR" ]] && rm -f "${CONFIGSDIR}"/*MV*
  [[ -d "$PREVIEWDIR" ]] && rm -f "${PREVIEWDIR}"/*MV*
else                             # Löschen im Source-Dir von skinflatPlus
  rm -rf ../"${ICONS}"/MV*
  rm -f ../"${THEMES}"/flatPlus-MV*
  rm -f ../"${DECORS}"/*MV*
  rm -f ../"${INFO}" ../"${HIST}"
  rm -f ../"${CONFIGS}"/*MV*
  rm -f ../"${PREVIEWS}"/*MV*
fi

echo 'MV-Themen wurden entfernt.'

# MV_Themes neu laden
if [[ -z "$SILENTUPDATE" ]] ; then
  echo "$LN"
  read -p 'MV_Themes neu herunterladen und entpacken? (J/n)' -t 5 TASTE
  [[ "${TASTE^^}" == "N" ]] && exit
fi

cd ..        # In das Source-Verzeichnis von SkinFlatPlus

# Download
[[ -n "$DIRECTUPDATE" ]] && cd /tmp
wget "https://www.dropbox.com/s/c5mh4g2qonjs25r/MV_Themes.tar.xz"
tar -xJf MV_Themes.tar.xz    # Entpacken
rm -f MV_Themes.tar.xz       # Archiv entfernen

if [[ -n "$DIRECTUPDATE" ]] ; then
  cp -f "${THEMES}"/flatPlus-MV* "$THEMEDIR"
  cp -f "${DECORS}"/*MV* "$DECORDIR"
  cp -rf "${ICONS}"/MV* "$ICONDIR"
  cp -f "${CONFIGS}"/*MV* "$CONFIGSDIR"
  cp -f "${PREVIEWS}"/*MV* "$PREVIEWDIR"
fi

echo "$LN"
echo 'MV-Themen wurden aktualisiert.'

[[ -n "$DIRECTUPDATE" ]] && exit

if [[ -z "$SILENTUPDATE" ]] ; then
  echo "$LN"
  read -p 'MV_Themen installieren (make install)? (j/N)' -t 5 TASTE
  if [[ "${TASTE^^}" == "J" ]] ; then
    #cd ..
    make install
    echo "$LN"
    echo 'MV-Themen wurden installiert.'
  fi
else     # Silentupdate - Themen instalieren
  make install
fi

echo "$LN"

exit
