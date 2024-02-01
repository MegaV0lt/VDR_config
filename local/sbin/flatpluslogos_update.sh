#!/bin/bash

# flatpluslogos_update.sh
# Author MegaV0lt
VERSION=200203

#set -x # Debug

### Variablen
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"
GITDIR='/usr/local/src/_div/3PO_Senderlogos.git' # GIT-Dir
GITDIR2='/usr/local/src/_div/mediaportal-de-logos.git' # MediaPortal-Logos (svg)
LOGODIR='/usr/local/src/_div/flatpluslogos'      # Logo-Dir
LOG_FILE="/var/log/${SELF_NAME%.*}.log"           # Log-Datei
MAX_LOG_SIZE=$((1024*50))                          # Log-Datei: Maximale größe in Byte
RUNDATE="$(date "+%d.%m.%Y %R")"                 # Aktuelles Datum und Zeit
TMP_DIR=$(mktemp -d -p /tmp)                      # Temp-Dir im RAM

### Funktionen
log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  logger -s -t "$SELF_NAME" "$*"
  [[ -w "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log in Datei
}

### Start
[[ -w "$LOG_FILE" ]] && log "==> $RUNDATE - $SELF_NAME #${VERSION} - Start..."
[[ ! -e "$GITDIR" ]] && log "==> Logo-Dir not found! (${LOGODIR})" && exit 1

cd "$GITDIR" || exit 1
git pull >> "$LOG_FILE"

# TODO: Unterverzeichnisse einschließen
for logo in ./*.png ; do
  if [[ -L "$logo" ]] ; then              # Symlink
    if [[ ! -e "${LOGODIR}/${logo}" ]] ; then
      log "##> Neuer Symlink $logo gefunden"
      cp -d "$logo" "${LOGODIR}/${logo}"  # Erhält symbolische Links, folgt ihnen aber nicht beim Kopieren (entspricht -P --preserve=links)
    fi
    continue                              # Weiter
  fi
  if [[ "$logo" -nt "${LOGODIR}/${logo}" ]] ; then  # Neue(re) Datei?
    log "==> Update für $logo gefunden"
    if [[ -e "${LOGODIR}/${logo}.org" ]] ; then
      optipng "$logo" -backup -quiet -out "${LOGODIR}/${logo}.org"
    else
      optipng "$logo" -backup -quiet -out "${LOGODIR}/${logo}"
    fi
    rm "${LOGODIR}/${logo}.bak" &>/dev/null  # .bak-Datei löschen
    if [[ "$logo" -nt "${LOGODIR}/${logo}" ]] ; then
      log "==> $logo wird manuell kopiert (Fehler bei OptiPNG?)"
      cp --force "$logo" "${LOGODIR}/${logo}"  # Falls OptiPNG die Datei nicht verarbeitet hat
    fi
  fi
done

/usr/local/sbin/mp_logos.sh

#cd "$GITDIR2" || exit 1 # MediaPortal-Logos im SVG-Format
#git pull >> "$LOG_FILE"

# Ordner 'TV' für Fernsehsender und 'Radio' für Radio-Kanäle
# Logos mit '*- Dark.svg' ignorieren!
# 3PO-Logos sind in PNG-Format und 268x200 Pixel

# Im Ordner TV/Simple gibt es nur PNG mit 190 Pixel breite
#cd 'TV/Simple/' || exit 1

#for logo in ./*.svg ; do
#  [[ "$logo" = *'- Dark.svg' ]] && continue  # Weiter
#
#  PNGLOGO="${logo,,}" ; PNGLOGO="${PNGLOGO%.svg}.png"  # Kleinbuchstaben und png
#
#  if [[ "$logo" -nt "${LOGODIR}/${PNGLOGO}" ]] ; then  # Neue(re) Datei?
#    log "==> Update für $PNGLOGO gefunden"
#    # SVG in PNG umwandeln mit 268 Pixel Breite und 3 Pixel transparenten Rand
#    convert -background none -size 268 -matte -bordercolor none -border 3 "$logo" "${TMP_DIR}/${PNGLOGO}"
#
#    if [[ -e "${LOGODIR}/${PNGLOGO}.org" ]] ; then
#      optipng "${TMP_DIR}/${PNGLOGO}" -backup -quiet -out "${LOGODIR}/${PNGLOGO}.org"
#    else
#      optipng "${TMP_DIR}/${PNGLOGO}" -backup -quiet -out "${LOGODIR}/${PNGLOGO}"
#    fi
#    if [[ "$logo" -nt "${LOGODIR}/${PNGLOGO}" ]] ; then
#      log "==> $logo wird manuell kopiert (Fehler bei OptiPNG?)"
#      cp --force "${TMP_DIR}/${PNGLOGO}" "${LOGODIR}/${PNGLOGO}"  # Falls OptiPNG die Datei nicht verarbeitet hat
#    fi
#  fi
#done

#for logo in ./*.png ; do
#  PNGLOGO="${logo,,}"  # Kleinbuchstaben
#
#  if [[ "$logo" -nt "${LOGODIR}/${PNGLOGO}" ]] ; then  # Neue(re) Datei?
#    log "==> Update für $PNGLOGO gefunden"
#    # PNG umwandeln mit 268 Pixel Breite und 3 Pixel transparenten Rand
#    #convert -background none -size 268 -matte -bordercolor none -border 3 "$logo" "${TMP_DIR}/${PNGLOGO}"
#
#    # PNG mit 3 Pixel transparenten Rand
#    convert -background none -matte -bordercolor none -border 3 "$logo" "${TMP_DIR}/${PNGLOGO}"
#
#    #if [[ -e "${LOGODIR}/${PNGLOGO}.org" ]] ; then
#    #  optipng "${TMP_DIR}/${PNGLOGO}" -backup -quiet -out "${LOGODIR}/${PNGLOGO}.org"
#    #else
#      optipng "${TMP_DIR}/${PNGLOGO}" -backup -quiet -out "${LOGODIR}/${PNGLOGO}"
#    #fi
#    if [[ "$logo" -nt "${LOGODIR}/${PNGLOGO}" ]] ; then
#      log "==> $logo wird manuell kopiert (Fehler bei OptiPNG?)"
#      cp --force "${TMP_DIR}/${PNGLOGO}" "${LOGODIR}/${PNGLOGO}"  # Falls OptiPNG die Datei nicht verarbeitet hat
#    fi
#  fi
#done
#rm "${LOGODIR}/*.bak" &>/dev/null  # .bak-Datei(en) löschen


if [[ -e "$LOG_FILE" ]] ; then       # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG_FILE")"
  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

rm -rf "$TMP_DIR"

exit
