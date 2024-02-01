#!/bin/bash

# timer_unstack.sh - Vermeiden von gleichzeitig startenden Timern
# Author MegaV0lt, Version: 210713

SVDRPSEND='/usr/bin/svdrpsend'
printf -v NOW '%(%s)T' -1    # Jetzt in Sekunden
printf -v TODAY '%(%F)T' -1  # Heute (2021-07-15)
printf -v TOMORROW '%(%F)T' $((NOW + 60*60*24))  # Morgen (2021-07-16)

f_global_rematch() {  # global_rematch "$mystring1" "$regex"
  local str="$1" re="$2"
  LC_ALL='C'  # Halbiert sie Zeit beim suchen
  while [[ "$str" =~ $re ]] ; do
    echo "${BASH_REMATCH[1]}"
    str="${str#*"${BASH_REMATCH[1]}"}"
  done
}

until pidof vdr ; do
  sleep 5 ; ((cnt++))
  [[ $cnt -ge 5 ]] && { echo "VDR not running!" ; exit 1 ;}
done

#250 93 1:43:2021-07-20:2254:2340:50:99:Leschs Kosmos~Gendern| Wahn oder Wissenschaft?:<epgsearch><channel>43 - ZDF HD</channel><searchtimer>Leschs Kosmos</searchtimer><start>1626814500</start><stop>1626817200</stop><s-id>152</s-id><eventid>455644</eventid></epgsearch>

# Alle Timer in ein Array
mapfile -t < <($SVDRPSEND LSTT)

# Nur aktive Timer von Heute und Morgen
for i in "${!MAPFILE[@]}" ; do
  IFS=':' read -r -a timer <<< "${MAPFILE[i]}"
  if [[ "${timer[0]: -1}" == '1' ]] ; then  #&& unset -v 'MAPFILE[i]'
    [[ "${timer[2]}" == "$TODAY" || "${timer[2]}" == "$TOMORROW" ]] && TIMER_LIST+=("${MAPFILE[i]}")
  fi
done

for i in "${!TIMER_LIST[@]}" ; do
  IFS=':' read -r -a timer <<< "${TIMER_LIST[i]}"  # Timer in Array
  re="(:${timer[2]}:${timer[3]}:)"  # Suchstring (Datum:Startzeit)
  mapfile -t matches < <(f_global_rematch "${TIMER_LIST[*]}" "$re")
  #[[ "${#matches[@]}" -eq 1 ]] && { unset -v 'MAPFILE[i]' ; continue ;}

  cnt="${#matches[@]}"  # Anzahl in Variable speichern
  if [[ "$cnt" -gt 1 ]] ; then
    echo "Timer: ${timer[0]:4} - $cnt x"

    # Startzeit erhöhen und Timer speichern
    if [[ "${timer[3]:2}" == '59' ]] ; then
      #start_new="${timer[3]:0:2}00"
      #echo " - Start neu: $start_new"
      echo "Minute is 59! Not implemented..." && continue
    else
      #echo -n "Start: ${timer[3]}"
      start_new=$((timer[3] + cnt - 1)) #; echo " - Start neu: $start_new"
      MOD_TIMER="${TIMER_LIST[i]//${timer[2]}:${timer[3]}/${timer[2]}:$start_new}"
      echo "$SVDRPSEND MODT \"${MOD_TIMER[*]:4}\""
    fi
    TIMER_LIST[i]="$MOD_TIMER"
  fi
done

exit
