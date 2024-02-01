#!/bin/bash

# eplists_update.sh - eplists aktualisieren
# Author MegaV0lt
VERSION=190403

# set -x # Debug

# --- Variablen ---
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"                          # skript.sh
EPLISTS='MV'                                     # GIT, ARCH oder MV verwenden!
EPLISTS_GIT='/_config/local/_div/eplists-git'    # Pfad (Lokal) zum eplists-git
EPLISTS_LOCAL='/_config/local/_div/eplists'      # Pfad (Lokal) für entpacktes Archiv
EPLISTS_MV='/_config/local/_div/eplists-mv'      # Pfad (lokal) für entpacktes Archiv
#EPLISTS_DROPBOX='/_config/local/_div/MV_eplists'  # Pfad (lokal) für Dropbox-Ordner
EPLISTS_ARCH='https://www.eplists.de/eplists_full_utf8.cgi'  # URL zum Archiv
EPLISTS_LINK='/root/.eplists/lists'              # Symlink zu den eplists-Daten
#MV_EPLISTS='https://www.dropbox.com/sh/z8dyv22h3063cd8/AAAEo1NpW_CKdXKYREgfRW_-a?dl=1'  # Eigene Listen
MV_EPLISTS='/mnt/MCP-Server_root/usr/local/src/MV_eplists/'  # Eigene Listen
LOG_FILE="/var/log/${SELF_NAME%.*}.log"           # Log-Datei
MAX_LOG_SIZE=$((1024*50))                          # Log-Datei: Maximale größe in Byte
DROPBOXDL='/usr/local/sbin/dropbox_uploader.sh'  # Doropbox Up- Downloader
DROPBOXPAR='/root/.dropbox_uploader'             # Parameter
TMP_DIR="$(mktemp -d)"                            # Temp-Dir im RAM
printf -v RUNDATE '%(%d.%m.%Y %R)T'              # Aktuelles Datum und Zeit

# --- Funktionen ---
f_log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  # logger -s -t "${SELF_NAME%.*}" "$*"
  [[ -w "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log in Datei
}

f_process_epfiles(){
  local_eplists="${1:-$EPLISTS_LOCAL}"  # Default wenn ohne Parameter
  [[ ! -d "$local_eplists" ]] && mkdir --parents "$local_eplists"
  for epfile in *.episodes ; do
    if [[ -L "$epfile" ]] ; then  # epfile ist ein Symlink
      if [[ ! -e "${local_eplists}/${epfile}" ]] ; then
        f_log "##> Neuer Symlink $epfile gefunden"
        cp -d "$epfile" "${local_eplists}/${epfile}"  # Erhält symbolische Links, folgt ihnen aber nicht beim Kopieren (entspricht -P --preserve=links)
      fi
      continue  # Weiter
    fi
    if [[ "$epfile" -nt "${local_eplists}/${epfile}" ]] ; then  # Neue(re) Datei?
      f_log "==> Update für $epfile gefunden"
      echo "# Geändert von $SELF_NAME am $RUNDATE" > "${local_eplists}/${epfile}"
      while read -r LINE ; do
        if [[ "$LINE" =~ 'n.n.' ]] ; then
          NNLINE=($LINE) # Ins Array (0=Staffel 1=Episode 2=Folge 3=Titel)
          SEASON="${NNLINE[0]}" ; EPISODE="${NNLINE[1]}"  # Season und Episode
          [[ ${#SEASON} -lt 2 ]] && SEASON="0${SEASON}"   # Zwei Stellen
          #[[ ${#EPISODE} -lt 2 ]] && EPISODE="0${EPISODE}"
          [[ "${EPISODE:0:1}" == '0' ]] && EPISODE="$((10#${EPISODE}))"  # Episode ohne führende 0
          # NNLINE[3]="S${SEASON}E${EPISODE}"             # SxxExx
          NNLINE[3]="S${SEASON} E${EPISODE} Folge ${NNLINE[2]}"  # Sxx Exx Folge x
          f_log "++ Ersetze n.n. durch ${NNLINE[3]}"
          echo -e "${NNLINE[0]}\t${NNLINE[1]}\t${NNLINE[2]}\t${NNLINE[3]}" >> "${EPLISTS_LOCAL}/${epfile}"
        else
          echo "$LINE" >> "${local_eplists}/${epfile}"
        fi
      done < "$epfile"
    fi
    sleep 0.01  # 1/100 Sekunde
  done
}

# --- Start ---
[[ -w "$LOG_FILE" ]] && f_log "==> $RUNDATE - $SELF_NAME - Start..."

if [[ ! -L "$EPLISTS_LINK" ]] ; then
  f_log "WARNUNG: Symlink (${EPLISTS_LINK}) fehlt!"
  EPLISTS_LINKDIR="$(dirname ${EPLISTS_LINK})"  # Letztes /* abschneiden
  f_log "Erstelle $EPLISTS_LINKDIR"
  mkdir --parents "$EPLISTS_LINKDIR"
fi

if [[ "$EPLISTS" == "GIT" ]] ; then  # GIT verwenden
  if [[ ! -e "$EPLISTS_GIT" ]] ; then
    f_log "!! $EPLISTS_GIT nicht gefunden!"
    exit 1
  fi
  cd "$EPLISTS_GIT"
  git pull >> "$LOG_FILE" || f_log 'git pull ist fehlgeschlagen!'
  [[ "$(readlink $EPLISTS_LINK)" != "$EPLISTS_GIT" ]] && ln -f -s "$EPLISTS_GIT" "$EPLISTS_LINK"  # Symlink setzen
elif [[ "$EPLISTS" == "ARCH" ]] ; then  # ARCH verwenden
  cd "$TMP_DIR" ; wget "$EPLISTS_ARCH" -a "$LOG_FILE" ; RC=$?  # Download
  [[ $RC -ne 0 ]] && f_log "Download Fehler ($RC)" && exit 1  # Fehler!
  tar xzf "$(basename ${EPLISTS_ARCH})"  # Entpacken (xvzf mit Output)
  [[ "$(readlink $EPLISTS_LINK)" != "$EPLISTS_LOCAL" ]] && ln -f -s "$EPLISTS_LOCAL" "$EPLISTS_LINK"  # Symlink setzen
  cd episodes # ; set -x
  f_process_epfiles  # epfile bearbeiten
elif [[ "$EPLISTS" == "MV" ]] ; then  # MV verwenden (Eigene Lisen)
  ### Dropbox
  #"$DROPBOXDL" -f "$DROPBOXPAR" download /Public/VDR/MV_eplists "${EPLISTS_DROPBOX%/*}"  # Zwischenspeicher. Es werden nur neuere heruntergeladen (Hash)
  #cd "$EPLISTS_DROPBOX" || f_log "Kann nicht in das Verzeichnis $EPLISTS_DROPBOX wechseln"
  ### MCP-server als Quelle
  mount '/mnt/MCP-Server_root'
  cd "$MV_EPLISTS" || f_log "Kann nicht in das Verzeichnis $MV_EPLISTS wechseln"
  [[ "$(readlink -m $EPLISTS_LINK)" != "$EPLISTS_MV" ]] && ln -f -s "$EPLISTS_MV" "$EPLISTS_LINK"  # Symlink setzen
  f_process_epfiles "$EPLISTS_MV"  # epfile bearbeiten
fi

if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG_FILE")"
  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

rm -rf "$TMP_DIR"

exit
