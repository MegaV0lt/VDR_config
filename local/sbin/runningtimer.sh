#!/bin/bash

# runningtimer.sh - Feststellen, ob ein Timer läuft
# Author MegaV0lt, Version: 20130315

SVDRPSEND="/usr/local/src/VDR/svdrpsend"
TIMEWARN="360"        # Zeit, ab der vor Timer gewarnt wird

ctrl_c() {            # Strg-C wurde erkannt
  echo " Abbruch durch Benutzer. VDR wird NICHT beendet!"
  exit 2
}

CountDown() {         # Funktion zum 'Runterzählen'
  echo "Strg-C zum abbrechen."
  for i in {6..1} ; do
    echo -e "VDR wird in > $i < Sekunde(n) beendet!\r\c"
    sleep 1
  done
  echo ""
  exit 1
}

trap ctrl_c SIGINT    # Strg-C abfangen

# Timer abfragen (rel=relativ zu jetzt) und in Array speichern
VDRNEXT=($($SVDRPSEND NEXT rel | grep ^250)) # Array (Timer[1] Sekunden[2])

# Die Variable ${VDRNEXT[2]} ist als $'2354\r' gespeichert.
# Eine Berechnung ist so nicht möglich. "\r" entfernen:
VDRNXT=${VDRNEXT[2]//$'\r'/}

# Check, ob negative Zeit (Timer läuft)
if [[ "$VDRNXT" =~ "-" ]] ; then         # Negative Zeit = Laufender Timer
   echo "WARNUNG: VDR nimmt auf!"
   CountDown
fi

# Check auf anstehenden Timer in $TIMEWARN
if [[ "$VDRNXT" -le "$TIMEWARN" ]] ; then
   echo "Aufnahmebeginn in $VDRNXT Sekunden!"
   CountDown
fi

exit
