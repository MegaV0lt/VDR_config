#!/bin/bash

# SysUpdate.sh
# Skript zum Updaten von Debian/Ubuntu

### Variablen
msgERR='\e[1;41m FEHLER! \e[0;1m'  # Anzeige "FEHLER!"

[[ $EUID -ne 0 ]] && { echo -e "$msgERR Das Skript muss als Root ausgeführt werden!\e[0m" >&2 ; exit 1 ;}

echo '--> Hole Updateliste…'
apt update

echo -e '\n--> Liste der Updates:'
apt list --upgradable

#echo -e -n '\nTaste…' ; read -t 20

echo -e '\n--> Prüfe auf Updates…'
apt full-upgrade

# VDR Skripte
if [[ -e /_config/.git ]] ; then
  cd /_config || exit 1
  echo -e '\n--> Aktualisiere /_config…'
  if ! git stash && ! git pull; then
    echo -e "\n$msgERR /_config konnte nicht aktualisiert werden"
    #echo -e -n '\nTaste drücken oder 10 Sekunden warten…' ; read -t 10
  fi
  echo -e '\n--> Überprüfe/Erzeuge Symlinks und Berechtigungen…'
  ./createlinks.sh
fi

# Wakeupskript
if [[ -e /usr/share/vdr/shutdown-hooks/S90.acpiwakeup ]] ; then
  echo -e '\n--> Aktualisiere Wakeupskript…'
  if ! rm -f /usr/share/vdr/shutdown-hooks/S90.acpiwakeup ; then
    echo -e "\n$msgERR Altes Wakeupskript konnte nicht entfernt werden"
  fi

  if ! cp -f /home/darkwing/src/S90.acpiwakeup /usr/share/vdr/shutdown-hooks/S91.acpiwakeup-mv ; then
    echo -e "\n$msgERR Neues Wakeupskript konnte nicht aktualisiert werden"
  fi
fi

exit
