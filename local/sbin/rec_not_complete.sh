#!/bin/bash

# rec_not_complete.sh
# Recording not complete
VERSION=190528

# Wenn Syslog-NG verwendet wird, startet Syslog-NG das Skript und schickt die
# Meldung via stdin an das Skript. Dazu wird eine "while" schleife verwendet.
#May 25 00:17:00 vdr01 vdr[4029]: epg2vdr: Info: Recording 'The Break – Jeder kann töten~Willkommen in Heiderfeld' finished - NOT complete (91%)


SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"                          # skript.sh
LOG_DIR='/var/log'                                # System-Logdir
TMP_DIR="$(mktemp -d)"
#MAILFILE='/tmp/~vdsb_mail.txt'
SVDRP_CMD='svdrpsend'
#_IFS="$IFS"                                      # Feldtrenner merken
LOGNUM=0
#XARGS_OPT=('--null' '--no-run-if-empty')  # Optionen für "xargs"

trap 'f_cleanup 1' QUIT INT TERM EXIT  # Aufräumen beim beenden

# --- Funktionen ---
f_cleanup() {  # Aufräumen
  echo "Cleanup..."
  # Lösche alte VDSB_*- und DVBAPI_UK_*-Dateien die älter als 14 Tage sind
  # find "$LOG_DIR" -maxdepth 1 -type f -mtime +14 \( -name "VDSB_*" -o -name "DVBAPI_UK_*" \) \
  #     -print0 | xargs "${XARGS_OPT[@]}" rm
  # Lösche alte .rec-Dateien die älter als 2 Tage sind
	#find /video -type f -mtime +2 -name '.rec' -print0 | xargs "${XARGS_OPT[@]}" rm
  rm -rf "$TMP_DIR"
  [[ ! $(pidof syslog-ng) || "$1" == "1" ]] && exit  # Exit nur wenn kein Syslog-NG läuft
}

find_vdsb_timer() {  # Vom VDSB betroffene Timer finden
  #  svdrpsend LSTT 147
  # 220 hdvdr01 SVDRP VideoDiskRecorder 2.2.0; Fri Nov 13 11:21:06 2015; UTF-8
  # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
  # 221 hdvdr01 closing connection
  # set -x
  # Laufende Timer (LSTT) [Jede Zeile ein Feld]
  #IFS=$'\n'
  mapfile -t TIMERS < <("$SVDRP_CMD" LSTT | grep ' 9:')
  # Laufende Aufnahmen (.rec) in Array
  #REC_FLAGS=($(find -L /video -name .rec -type f -print))
  mapfile -t REC_FLAGS < <(find -L /video -name .rec -type f -print)

  for rec_flag in "${REC_FLAGS[@]}" ; do
    REC_NAME="$(< "$rec_flag")"  # Der Name wie im Timer (Hoffentlich)
    REC_INDEX="${rec_flag%.rec}index"  # Index-Datei
    REC_VDSB="${rec_flag%.rec}.vdsb"   # .vdsb-Datei
    printf -v _NOW '%(%s)T' -1         # Aktuelle Zeit in Sekunden
    if [[ $(stat --format=%Y "$REC_INDEX") -le $((_NOW - 20)) ]] ; then
      { echo -e "\n=> Aufnahme: \n${REC_NAME}"
        echo -e "$REC_INDEX ist älter als 20 Sekunden!\nMöglicher VDSB!"
      } >> "${TMP_DIR}/info.txt"
      echo "$_NOW - VDSB" >> "$REC_VDSB"
      # Timer bestimmen
      if [[ -e "${rec_flag%.rec}.timer" ]] ; then  # .timer (VDR 2.4.0)
        TIMER_NR="$(< "${rec_flag%.rec}.timer")"  # 61@vdr01
        #TIMER_NR="${TIMER_NR%@*}"  #61
        { echo -e "\n=> Timer $TIMER_NR: "  # 61@vdr01
          #"$SVDRP_CMD" LSTT "${TIMER_NR%@*}"  # 61
          mapfile -t < <("$SVDRP_CMD" LSTT "${TIMER_NR%@*}")
          IFS=':' read -r -a VDRTIMER <<< "${MAPFILE[1]}"
          echo "{VDRTIMER[7]}"  # nano~nano
        } >> "${TMP_DIR}/info.txt"
      fi
      if [[ -n "$REC_NAME" && "${TIMERS[*]}" =~ $REC_NAME ]] ; then  # Timer in der Liste enthalten!
        for timer in "${TIMERS[@]}" ; do
          if [[ "$timer" =~ $REC_NAME ]] ; then  # Timer gefunden
            IFS=':' read -r -a VDRTIMER <<< "$timer"  # Trennzeichen ist ":"
            # 250 147 1:92:2015-12-02:2005:2110:50:99:Mako - Einfach Meerjungfrau~Verirrte Mondseekräfte / Katzenjammer:<epgsearch><channel>92 - KiKA HD</channel><searchtimer>Mako - Einfach Meerjungfrau</searchtimer><start>1449083100</start><stop>1449087000</stop><s-id>358</s-id><eventid>42931</eventid></epgsearch>
            # ^0        ^1 ^2         ^3   ^4   ^5 ^6 ^7
            TIMER_NR="${VDRTIMER[0]:4}"  # "250 " entfernen (ab 4. Zeichen)
            TIMER_NR="${TIMER_NR% *}"  # Alles nach der Timernummer entfernen
            # echo "Deaktiviere Timer Nummer $TIMER_NR (${VDRTIMER[7]})"
            # "$SVDRP_CMD" MODT "$TIMER_NR" off  # Timer deaktivieren
            echo -e "\n=> Timer (${TIMER_NR}): $timer" >> "${TMP_DIR}/info.txt"
            break  # for Schleife beenden
          fi
        done  # for timer
      else
        echo -e "\n=> Timer für $REC_NAME nicht gefunden!" >> "${TMP_DIR}/info.txt"
      fi
    fi  # stat
  done # ; set +x
}

# --- Start ---

[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]] && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

#May 25 00:17:00 vdr01 vdr[4029]: epg2vdr: Info: Recording 'The Break – Jeder kann töten~Willkommen in Heiderfeld' finished - NOT complete (91%)
if pidof syslog-ng >/dev/null ; then  # Syslog-NG läuft
  while read -r ; do
    IFS=' ' read -r -a LOGSTRING <<< "$REPLY"  # Meldung in Array
    printf -v RUNDATE '%(%d.%m.%Y %R:%S)T' -1  # Datum und Zeit mit Sekunden
    TIMER_NAME="${REPLY%\'*}"                  # Alles nach ' abschneiden
    TIMER_NAME="${TIMER_NAME#*\'}"             # Alles vor ' abschneiden
    TIMER_PERCENT="${LOGSTRING[-1]}"           # Letztes Element (91%)

    # //TODO Timer konvertieren, um ihn im Dateisystem zu finden
    LEN=$((${#TIMER_NAME}-1)) ; i=0
    while [[ $i -le $LEN ]] ; do  # Zeichen ersetzen
    # echo "Pos: $i = ${DLURL:$i:1}"
    case "${TIMER_NAME:$i:1}" in   # Zeichenweises Suchen und Ersetzen
      'ä') DLURL="${TIMER_NAME:0:$i}ae${TIMER_NAME:$i+1}" ; ((LEN++)) ;;  # ä -> ae
      'ö') DLURL="${TIMER_NAME:0:$i}oe${TIMER_NAME:$i+1}" ; ((LEN++)) ;;  # ö -> oe
      'ü') DLURL="${TIMER_NAME:0:$i}ue${TIMER_NAME:$i+1}" ; ((LEN++)) ;;  # ü -> ue
      'ß') DLURL="${TIMER_NAME:0:$i}ss${TIMER_NAME:$i+1}" ; ((LEN++)) ;;  # ß -> ss
      '&') DLURL="${TIMER_NAME:0:$i}and${TIMER_NAME:$i+1}" ; ((LEN+=2)) ;;  # & -> and
      [.\']) DLURL="${TIMER_NAME:0:$i}-${TIMER_NAME:$i+1}" ;;               # .' -> -
      [,:!?]) DLURL="${TIMER_NAME:0:$i}${TIMER_NAME:$i+1}" ; ((i--)) ; ((LEN--)) ;;  # Löschen
      *) ;;
    esac
    ((i++))
done

    # info.txt erstellen
    { echo -e "$SELF_NAME - $VERSION\n$RUNDATE - \"${LOGSTRING[*]}\""


      # Laufende Aufzeichnungen und Timer
      #echo -e '\n=> Laufende Aufnahmen (.rec):'
      #find -L /video -name .rec -type f -print0 | xargs "${XARGS_OPT[@]}" ls -l
      #echo -e '\n=> Laufende Timer:'
      #grep '^[5..99]:' /etc/vdr/timers.conf

      # Die letzten xx Zeilen der messages in die info
      #echo -e '\n=> Logmeldungen:'
      #tail -n 75 "${LOG_DIR}/messages"

    } >> "${LOG_DIR}/rec_not_complete.log"

    find_vdsb_timer  # Von VDSB betroffene Timer finden

    #cat "${TMP_DIR}/info.txt" >> "${LOG_DIR}/${SELF_NAME%.*}.log"  # Auch auf dem System loggen

    # Packen (z=gzip, J=xz)
    # tar --create --absolute-names --auto-compress --file=$LOG_DIR/$ARCHIV $TMP_DIR
    #tar --create --auto-compress --file="${LOG_DIR}/${ARCHIV}" "$TMP_DIR"

    # Mail beim ersten VDSB senden
    if [[ $LOGNUM -eq 1 ]] ; then
      { echo "From: \"${HOSTNAME}\"<${MAIL_ADRESS}>"
        echo "T0: $MAIL_ADRESS"
        echo 'Content-Type: text/plain; charset=UTF-8'
        echo "Subject: VDSB - ${HOSTNAME^^}"
        echo -e "\nEs wurde ein 'Video Data Stream Broken' entdeckt!"
        echo "Der VDR wird beim nächsten mal einmalig neu gestartet."
        echo -e "Inhalt von ${TMP_DIR}/info.txt:\n"
        cat "${TMP_DIR}/info.txt"
      } > /usr/sbin/sendmail
      #iconv --from-code=UTF-8 --to-code=iso-8859-1 "$MAILFILE" \
      #  | /usr/sbin/sendmail root
    fi
  done
  # f_cleanup
else  # Metalog?
  echo "$SELF_NAME - $1 - $2 - $3"
  echo 'Syslog-ng scheint nicht zu laufen!' >&2
fi

exit  # Ende
