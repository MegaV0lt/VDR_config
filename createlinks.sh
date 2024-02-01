#!/usr/bin/env bash

# createlinks.sh
# - Prüft und erzeugt fehlende links zu den Ordnern "sbin" und "vdr.d"
# - Dateirechte setzen
# - Aktiviert vdr_init.sh via Service-DropIn
# - Prüft symlinks zu sendmail
# - Prüft und korrigiert ob eigen Skripte überschrieben wuden (/usr/lib/vdr)

#VERSION=231017

CONFIG_DIR='/_config'                   # Hauptordner
LOCAL_DIR="${CONFIG_DIR}/local"         # Ordner mit den zu verlinkenden Ordnern
declare -A LINK_DIRS
LINK_DIRS[sbin]='/usr/local/sbin'       # sbin lag mal hier: /usr/local/sbin
#LINK_DIRS[_div]='/usr/local/src/_div'   # _div lag mal hier: /usr/local/src/_div
LINK_DIRS[vdr.d]='/etc/vdr.d'           # vdr.d lag mal hier: /etc/vdr.d
YAVDR_VDR='/usr/local/src/yaVDR_vdr.git' # VDR Repository mit Skripten

[[ "$EUID" -ne 0 ]] && { echo 'Skript benötigt root-Rechte!' ; exit 1 ;}

cd "$LOCAL_DIR" || exit 1

# Symlinks erstellen
echo '==> Überprüfe Symlinks…'
for dir in "${!LINK_DIRS[@]}" ; do     # sbin vdr.d
  # Leeren Ordner löschen
  if [[ -d "${LINK_DIRS[$dir]}" && ! "$(ls -A ${LINK_DIRS[$dir]})" ]] ; then
    echo "Enferne leeren Ordner ${LINK_DIRS[$dir]}…"
    rm "${LINK_DIRS[$dir]}"
  fi
  if [[ ! -L "${LINK_DIRS[$dir]}" ]] ; then  # Kein Symlink
    if [[ -d "${LINK_DIRS[$dir]}" ]] ; then  # Ordner bereits vorhanden
      ls "${LINK_DIRS[$dir]}"
      echo "Warnung: Verzeichnis ${LINK_DIRS[$dir]} existiert. Bitte überprüfen!"
    else
      echo "Erstelle fehlenden Symlink nach ${LINK_DIRS[$dir]}"
      ln --symbolic "${LOCAL_DIR}/${dir}" "${LINK_DIRS[$dir]}"
    fi
  else
    echo "Symlink ${LINK_DIRS[$dir]} vorhanden. OK!"
  fi
done

# Rechte setzen (Alle Dateien in den Ordner und Unterordnern)
echo '==> Setze berechtigungen…'
chown --recursive vdr:vdr "$CONFIG_DIR"  # Eigentümer auf 'vdr' setzen
chmod --recursive 755 "$CONFIG_DIR"      # Rechte auf 755

# Aktivieren von vdr_init.sh
if [[ ! -e '/etc/systemd/system/vdr.service.d/pre-start.conf' ]] ; then
  echo '==> Erstelle /etc/systemd/system/vdr.service.d/pre-start.conf'
  mkdir --parents /etc/systemd/system/vdr.service.d
  { echo '[Service]'
    echo 'ExecStartPre=/etc/vdr.d/scripts/vdr_init.sh'
  } > /etc/systemd/system/vdr.service.d/pre-start.conf
  systemctl daemon-reload  # Units neu einlesen
fi

# Symlink für sendmail prüfen und anlegen, falls nicht gefunden
echo '==> Prüfe Links zu sendmail…'
if [[ ! -L /usr/sbin/sendmail || ! -L /usr/bin/sendmail ]] ; then  # Kein Symlink
  [[ -e /usr/sbin/sendmail ]] && echo '[!] "sendmail" ist kein Symlink aber existiert!'
  ls -l /usr/bin/sendmail
  ls -l /usr/sbin/sendmail
  #ln --symbolic "$SELF" /usr/sbin/sendmail
fi

# Skripte von VDR die überschreiben wurden wieder herstellen
echo '==> Aktualisiere eigenes yaVDR GIT auf angepasste Skripte…'
if [[ -d "${YAVDR_VDR}/.git" ]] ; then
  cd "$YAVDR_VDR"
  git pull >/dev/null  # GIT aktualisieren
  files=('merge-commands.sh' 'vdr-recordingaction' 'vdr-shutdown')
  for file in "${files[@]}" ; do
    src="${YAVDR_VDR}/debian/${file}"  # Quelle: Lokales git
    dest="/usr/lib/vdr/${file}"        # Ziel: /urs/lib/vdr
    if ! cmp --quiet "$src" "$dest" ; then
      echo -e "==> Datei $file ist nicht identisch mit ${src}!\n==> Kopiere eigene Version…"
      mv --force --verbose "$dest" "${dest}.bak"
      cp --force --verbose "$src" "$dest" || echo "Fehler beim kopieren von $src"
    fi
  done
fi

exit
