#!/bin/bash

# SysUpdate.sh
# Skript zum Updaten von Debian/Ubuntu

### Variablen
msgERR='\e[1;41m FEHLER! \e[0;1m'  # Anzeige "FEHLER!"

[[ $EUID -ne 0 ]] && SUDO='sudo'  # Kein Root?

echo '--> Hole Updateliste…'
"$SUDO" apt update

echo -e '\n--> Liste der Updates:'
"$SUDO" apt list --upgradable

#echo -e -n '\nTaste…' ; read -t 20

echo -e '\n--> Prüfe auf Updates…'
"$SUDO" apt full-upgrade

# VDR Skripte
if [[ -e /_config/.git ]] ; then
  cd /_config || exit 1
  echo -e '\n--> Aktualisiere /_config…'
  if ! "$SUDO" git pull ; then
    echo -e "\n$msgERR /_config konnte nicht aktualisiert werden"
    #echo -e -n '\nTaste drücken oder 10 Sekunden warten…' ; read -t 10
  fi
  echo -e '\n--> Überprüfe/Erzeuge Symlinks und Berechtigungen…'
  "$SUDO" ./createlinks.sh
fi

exit
