#!/usr/bin/env bash

# eplists_check.sh - nach fehlenden Seriennummerierungen suchen  (SxxExx)
# Author MegaV0lt
VERSION=250723

# --- Variablen ---
SELF="$(readlink /proc/$$/fd/255)"      # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"
TIMERS_CONF='/var/lib/vdr/timers.conf'  # VDR's timers.conf
SEARCH='[[:space:]][[:space:]]\(S'      # Serineinfos (SxxExx)
# Logdatei
LOG_FILE="/var/log/${SELF_NAME%.*}.log"  # Log-Datei
MAX_LOG_SIZE=$((1024*50))                # Log-Datei: Maximale größe in Byte
# eMail
declare -a NF_TIMER TVSCRAPER_TIMER     # Array's
printf -v NOW '%(%s)T' -1               # Jetzt in Sekunden
MAX_DATE=$((NOW + 60*60*24*10))         # Maximale Timer in der Zukunft (10 Tage)
LC_ALL=C                                # Locale auf C setzen für schnelles Sortieren

# --- Funktionen ---
f_log() {     # Gibt die Meldung auf der Konsole und im Syslog aus
  logger -t "$SELF_NAME" "$*"
  [[ -w "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log in Datei
}

[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]] && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

mapfile -t TIMERS < "$TIMERS_CONF"  # Timer vom VDR einlesen

for i in "${!TIMERS[@]}" ; do
  # 0:S19.2E-1-1025-10325:2017-10-12:2013:2110:50:99:quer:<epgsearch><channel>60 - BR Fernsehen Süd HD</channel><searchtimer>quer</searchtimer><start>1507831980</start><stop>1507835400</stop><s-id>31</s-id><eventid>53659</eventid></epgsearch>
  IFS=':' read -r -a TIMER  <<< "${TIMERS[i]}"  # In Array
  if [[ "${TIMER[0]}" == '0' ]] ; then  # Inaktiver Timer
    unset -v 'TIMERS[i]' ; continue
  fi
  if [[ "${TIMER[7]}" =~ '~' ]] ; then  # Nur wenn ~ im Timer
    if [[ "$(date +%s -d "${TIMER[2]} ${TIMER[3]}")" -gt $MAX_DATE ]] ; then
      unset -v 'TIMERS[i]' ; continue  # Timer liegt mehr als $MAX_DATE in der Zukunft
    fi
    if [[ "${TIMER[7]}" =~ $SEARCH ]] ; then  # Eintrag (SxxExx) bereits vorhanden
      unset -v 'TIMERS[i]' ; continue
    fi
    # TODO: Warum kommen in der timers.conf zwei unterschiedliche Datum-Versionen vor?
    if [[ "${TIMER[7]}" =~ _[0-9]{2}.[0-9]{2}.[0-9]{2}_ ]] ; then  # Legion~Do._02.03.17_21|00
      unset -v 'TIMERS[i]' ; continue  # epgsearch
    fi
    if [[ "${TIMER[7]}" =~ ~[0-9]{4}.[0-9]{2}.[0-9]{2}- ]] ; then  # Leschs Kosmos~2017.03.07-23|00-Di
      unset -v 'TIMERS[i]' ; continue  # VDR
    fi
    #1:S19.2E-1-1057-61205:2022-10-31:0100:0200:10:99:The Walking Dead~Vertrauen:
    #  <tvscraper><causedBy>The Walking Dead~Vertrauen  (S11E15)</causedBy><reason>improve</reason></tvscraper>
    if [[ "${TIMER[8]}" =~ '<tvscraper>' ]] ; then
      : "${TIMERS[i]##*<causedBy>}" ; : "${_%%</causedBy>*}"
      TIMER[7]+="  [TVScraper] <- $_"
      TVSCRAPER_TIMER+=("${TIMER[7]}")
      continue
    fi
    NF_TIMER+=("${TIMER[7]}") # ; echo "Timer: $i"
  else  # Timer ohne ~
    unset -v 'TIMERS[i]'
  fi  # ~
done

# Mail senden
if [[ -n "${NF_TIMER[*]}" || -n "${TVSCRAPER_TIMER[*]}" ]] ; then
  { echo "From: \"${HOSTNAME^^}\"<${MAIL_ADRESS}>"
    echo "To: $MAIL_ADRESS"
    echo 'Content-Type: text/plain; charset=UTF-8'
    echo "Subject: Fehlende Seriennummerierungen (${#NF_TIMER[@]}/${#TVSCRAPER_TIMER[@]})"
    echo -e "\n${SELF_NAME} #${VERSION}"

    # Aktive Timer ohne (SxxExx)
    echo -e "\n==> Timer (VDR) mit fehlenden (SxxExx) (${#NF_TIMER[@]}):"
    printf '%s\n' "${NF_TIMER[@]}" | sort -u  # Sortieren und duplikate entfenen

    # Timer von TVScraper
    echo -e "\n==> Von TVScraper angelegte Timer (${#TVSCRAPER_TIMER[@]}):"
    printf '%s\n' "${TVSCRAPER_TIMER[@]}" | sort -u  # Sortieren und duplikate entfenen

    # Alle Timer
    echo -e "\n==> Aktive Timer ohne (SxxExx) (${#TIMERS[@]}):"
    printf '%s\n\n' "${TIMERS[@]}"

  } | /usr/sbin/sendmail root
fi

if [[ -e "$LOG_FILE" ]] ; then       # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG_FILE" 2>/dev/null)"
  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
fi

exit
