#!/bin/bash

# make_oscam-svn.sh
# Aktualisiert oscam

OSCAM_DIR="/usr/local/src/_div/oscam"           # OSCam-Verzeichnis
OSCAM_SVNDIR="${OSCAM_DIR}-svn"                 # SVN-Verzeicnis
OSEMU_GITDIR="$(readlink -m $OSCAM_DIR/../osemu-git)" # OSEmu-Verzeichnis
OSCAM_DISTDIR="${OSCAM_SVNDIR}/Distribution"    # Distribution
LOGLEVEL="${OSCAM_DIR}/.loglevel"               # Datei wird im Startskript gelesen
DEBUGLEVEL=0                                    # Vorgabewert

timedout_read() {
  timeout=$1 ; varname=$2 ; old_tty_settings=`stty -g`
  stty -icanon min 0 time ${timeout}0
  read $varname
  stty "$old_tty_settings"           # See man page for "stty."
}

OLDDIR="$PWD"                        # Verzeichnis merken
cd $OSCAM_SVNDIR                     # In das SVN-Verzeichnis

[ -n "$1" ] && SVNOPT="--revision $1"
echo "SVN wird aktualisiert... $1"
svn up $SVNOPT                       # SVN aktualisieren

echo "OSCam konfiguration ändern? [j/N]"
timedout_read 5 TASTE
if [ "${TASTE^^}" = "J" ] ; then
  ./config.sh --gui
fi

[ -e $LOGLEVEL ] && DEBUGLEVEL=$(<$LOGLEVEL) # Wert einlesen
echo "OSCam DebugLevel ($DEBUGLEVEL) für Logausgabe ändern? [0..65535]"
unset TASTE ; timedout_read 5 TASTE
if [ -n "$TASTE" ] ; then
  echo $TASTE > $LOGLEVEL           # Loglevel speichern
fi

echo "OSCam nach dem Bauen sofort aktivieren? [j/N]"
timedout_read 5 TASTE
if [ "${TASTE^^}" = "J" ] ; then
  DORESTART=1
fi

if [ -d "${OSEMU_GITDIR}" ] ; then
  echo "OSEmu ebenfalls aktualisieren? [j/N]"
  timedout_read 5 TASTE
  if [ "${TASTE^^}" = "J" ] ; then
    MAKEOSEMU=1
  fi
fi

make clean
make OSCAM_BIN=$OSCAM_DISTDIR/oscam     # OSCam bauen

[ -n "$MAKEOSEMU" ] && "$(dirname $0)/make_osemu.sh" # OSEmu bauen

cd $OLDDIR                              # Zurück

# Aktivieren und OSEmu neustart
if [ -n "$DORESTART" ] ; then
  /etc/init.d/oscam stop
  cp -f "${OSCAM_DIR}/oscam" "${OSCAM_DIR}/oscam-prev"
  cp -f "${OSCAM_DISTDIR}/oscam" "${OSCAM_DIR}/oscam"
  /etc/init.d/oscam start
fi

# Anzeigen
ls -l -h "$OSCAM_DISTDIR"

exit
