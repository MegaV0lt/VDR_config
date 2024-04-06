#!/bin/bash

# find_last_recording.sh
# Findet das Datum der jüngsten Aufnahme eines Suchtimers
VERSION=180225

### Variablen
EPGSEARCH_CONF='/etc/vdr/plugins/epgsearch/epgsearch.conf'      # Pfad zu den Suchtimern
EPGSEARCH_DONE='/etc/vdr/plugins/epgsearch/epgsearchdone.data'  # Erledigte Aufnahmen
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"                          # skript.sh
msgERR='\e[1;41m FEHLER! \e[0;1m'  # Anzeige "FEHLER!"
msgINF='\e[42m \e[0m' ; msgWRN='\e[103m \e[0m'  # " " mit grünem/gelben Hintergrund
declare -A SEARCHTIMER   # Array
printf -v NOW '%(%s)T'   # Zeit in Sekunden (Jetzt)
ISOLD=$((60*60*24*356*2))  # Ab wann eine Suchtimer als "Alt" bertrachtet wird
LC_ALL=C  # Schneller?

# Suchtimer:
#id:Name:aktiv[0/1]
#11:nano:1:1500:2000:1:S19.2E-1-1010-11150:0:0:1:1:0:0:::1:0:0:0:nano:50:99:2:5:0:0:0::0:0:1:1:1:0:0:0:0:1:0:0::1:0:0:0:0:0:0:0:0:0:90::0
#19:Supernatural:0:::1:S19.2E-133-6-131|S19.2E-1-1010-11160:0:0:1:0:0:0:::1:0:0:1:%Serien%:50:99:7:10:0:0:1:1#|2#|3#|4#|6#|7#|8#|9#|11#|12#|13#|14#|15#|16#|17#|

# Erledigte Aufnahmen:
#R 1179471900 600 -1
#C S19.2E-1-1079-28007
#T hitec kompakt
#S Die Kunst vom Seilbahnbau
#D Deutschland, 2006
#@ <epgsearch><channel>34 - 3sat</channel><searchtimer>hitec</searchtimer><start>1179471780</start><stop>1179473100</stop><s-id>7</s-id><eventid>58828</eventid></epgsearch>
#r

### Start
# Zeilen T, S und @ in Arrays einlesen (Index muss zusammen passen)
mapfile -t < "$EPGSEARCH_DONE"
for REPLY in "${MAPFILE[@]}" ; do
  #echo "REPLY: $REPLY"
  case "${REPLY:0:1}" in
    'R') ((rec+=1)) ;;  # Zähler für die Aufnahemn
    'T') TITLE[rec]="${REPLY:2}" ;;
    'S') SHORT[rec]="${REPLY:2}" ;;
    '@') #AUX[rec]="${REPLY:2}"
      AUX_TIMER[rec]="${REPLY#*\<searchtimer\>}" ; AUX_TIMER[rec]="${AUX_TIMER[rec]%%\</searchtimer\>*}"
      i=0
      while [[ $i -lt ${#AUX_TIMER[rec]} ]] ; do  # Zeichen nach HEX wandeln
        HEX_TIMER[rec]+=$(printf '%X' "${AUX_TIMER[rec]:i:1}")
        ((i++))
      done
      # echo -e "AUX_TIMER: ${AUX_TIMER[rec]}\nHEX_TIMER: ${HEX_TIMER[rec]}"

      #AUX_TIMER[rec]="_${AUX_TIMER[rec]//[^[:ascii:]]/_}"  # Nicht-ASCII Zeichen ersetzen
      #while [[ $i -le $LEN ]] ; do  # Zeichen ersetzen, die nicht in Variablennamen gehören
      #  # echo "Pos: $i = ${AUX_TIMER[rec]:$i:1}"
      #  case "${AUX_TIMER[rec]:$i:1}" in   # Zeichenweises Suchen und Ersetzen
      #    'ä') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}ae${AUX_TIMER[rec]:$i+1}" ; ((LEN++)) ;;  # ä -> ae
      #    'ö') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}oe${AUX_TIMER[rec]:$i+1}" ; ((LEN++)) ;;  # ö -> oe
      #    'ü') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}ue${AUX_TIMER[rec]:$i+1}" ; ((LEN++)) ;;  # ü -> ue
      #    'ß') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}ss${AUX_TIMER[rec]:$i+1}" ; ((LEN++)) ;;  # ß -> ss
      #    '&') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}and${AUX_TIMER[rec]:$i+1}" ; ((LEN+=2)) ;;  # & -> and
      #    '.') AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}_${AUX_TIMER[rec]:$i+1}" ;;               # . -> _
      #    [,:!?'('')'^'$'"'"+]) AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}${AUX_TIMER[rec]:$i+1}" ; ((i--)) ; ((LEN--)) ;;  # Löschen
      #    "-") [[ "${AUX_TIMER[rec]:$i-1:1}" == '-' ]] && { AUX_TIMER[rec]="${AUX_TIMER[rec]:0:$i}${AUX_TIMER[rec]:$i+1}"  # Löschen
      #      ((i--)) ; ((LEN--)) ;} ;;  # Mehrfache "-" vermeiden
      #    *) ;;
      #  esac
      #  ((i++))
      #done
      #[[ "${AUX_TIMER[rec]: -1}" == '-' ]] && AUX_TIMER[rec]="${AUX_TIMER[rec]:0:-1}"
      #AUX_TIMER[rec]="${AUX_TIMER[rec]// /_}"  # Leerzeichen ersetzen
      AUX_START[rec]="${REPLY#*\<start\>}" ; AUX_START[rec]="${AUX_START[rec]%%\</start\>*}"
      # if [[ -z ${SEARCHTIMER[${HEX_TIMER[rec]}]} || "${AUX_START[rec]}" -gt ${SEARCHTIMER[${HEX_TIMER[rec]}]} ]] ; then
      if [[ ${AUX_START[rec]} -gt ${SEARCHTIMER[${HEX_TIMER[rec]}]} ]] ; then
        # echo "Einrag für ${AUX_TIMER[rec]} ist neuer!"
        SEARCHTIMER[${HEX_TIMER[rec]}]="${AUX_START[rec]}"
        # echo "${SEARCHTIMER[${AUX_TIMER[rec]}]}"
        # echo "${#SEARCHTIMER[@]}"
      fi
    ;;
  esac
  # [[ $rec -gt 200 ]] && break  # Max. Einträge (Test)
done

echo "$msgINF Datensätze eingelesen: $rec"
echo "$msgINF Suchtimer: ${#SEARCHTIMER[@]}"
# Suchtimer - Datum ausgeben
echo "$msgINF Suchtimer, die schon lange nicht mehr aufgenommen haben:"
OLDTIME=$((NOW - ISOLD))
for stimer in "${!SEARCHTIMER[@]}" ; do
  if [[ "${SEARCHTIMER[$stimer]}" -lt $OLDTIME ]] ; then
    i=0
    while [[ $i -lt ${#stimer} ]] ; do  # HEX nach ASCII wandeln
      printf "\x${stimer:i:2}"  # Zwei Zeichen (HEX)
      ((i+=2))
    done
    printf '%s' " - "
    printf '%(%d.%m.%Y %R)T\n' "${SEARCHTIMER[$stimer]}"
  fi
done

exit
