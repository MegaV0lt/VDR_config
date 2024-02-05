#!/usr/bin/env bash

# get_SE.sh - Hilfsskript, das von epgSearch aufgerufen wird und versucht aus
#+der Beschreibung die Werte für Staffel und Episode zu extrahieren (Sky-Kanäle)
# Zusätzlich werden im TITLE enthaltene Klammern in den SUBTITLE verschoben:
# 'Serienname (5/6)~Folgenname' -> 'Serienname~Folgenname (5/6)'
#VERSION=240131

#Folgende Variablen sind bereits intern definiert und können verwendet werden.
# %title%          - Title der Sendung
# %subtitle%       - Subtitle der Sendung
# %time%           - Startzeit im Format HH:MM
# %timeend%        - Endzeit im Format HH:MM
# %date%           - Startzeit im Format TT.MM.YY
# %datesh%         - Startdatum im Format TT.MM.
# %time_w%         - Name des Wochentages
# %time_d%         - Tag der Sendung im Format TT
# %time_lng%       - Startzeit in Sekunden seit 1970-01-01 00:00
# %chnr%           - Kanalnummer
# %chsh%           - Kanalname kurz
# %chlng%          - Kanalname lang
# %chdata%         - VDR's interne Kanaldarstellung (z.B. 'S19.2E-1-1101-28106')
#
# %summary%        - Beschreibung
# %htmlsummary%    - Beschreibung, alle CR ersetzt durch '<br />'
# %eventid%        - Event ID
#
# %colon%          - Das Zeichen ':'
# %datenow%        - Aktuelles Datum im Format TT.MM.YY
# %dateshnow%      - Aktuelles Datum im Format TT.MM.
# %timenow%        - Aktuelle Zeit im Format HH:MM
# %videodir%       - VDRs Aufnahme-Verzeichnis (z.B. /video)
# %plugconfdir%    - VDRs Verzeichnis für Plugin-Konfigurationsdateien (z.B. /etc/vdr/plugins)
# %epgsearchdir%   - epgsearchs Verzeichnis für Konfiguratzionsdateien (z.B. /etc/vdr/plugins/epgsearch)

#%Get_SE%=system(/usr/local/sbin/get_se.sh, %Title% %Subtitle% %Staffel% %Episode% %Folge% %Summary% %time_w% %date% %time%)
#                                            0       1          2         3         4       5         6        7      8
#SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
#SELF_NAME="${SELF##*/}"                          # skript.sh
DATA=("$@")                                       # Übergebene Daten in ein Array
TITLE="${DATA[0]}"                                # Titel der Sendung
SUBTITLE="${DATA[1]}"                             # Kurztext
#LOG_FILE="/var/log/${SELF_NAME/.*}.log"          # Log-Datei
#MAX_LOG_SIZE=$((100*1024))                       # Log-Datei: Maximale größe in Byte
#DEBUG='true'                                     # Debug via logger

# Für Debuggingzwecke
#logger -t "$SELF_NAME" "Erhaltene Daten(${#DATA[@]}): ${DATA[0]:-NULL}~${DATA[1]:-NULL} S:${DATA[2]:-NULL}, E:${DATA[3]:-NULL}"

# Ersetz durch verwendung von SHORTNAME bei Serientitel (epgsearch)
# Zeichen ersetzen, damit Aufnahmen nicht in unterschiedlichen Ordnern landen
#case "${DATA[0]}" in
#  *' - '*) DATA[0]="${DATA[0]//' - '/' – '}" ;;  # Kurzen durch langen Bindestrich (La_Zona_–_Do_not_cross)
#  *"’"*)   DATA[0]="${DATA[0]//"’"/'\''}"    ;;  # Schräges ’ durch gerades ' (Marvel’s_Runaways)
#  *) ;;
#esac

# Titel mit (*) am Ende?
re='\(.*\)$'
if [[ "$TITLE" =~ $re ]] ; then  #* Titel enthält Klammern am Ende!
  FOUND_BRACE="${BASH_REMATCH[0]}"   # Wert speichern '(5/6)'
  : "${TITLE%"${FOUND_BRACE}"}" ; TITLE="${_%%' '}"  # Klammern (und Leerzeichen) entfernen
fi

if [[ -z "${DATA[2]}" ]] ; then  # Staffel ist leer
  # EPG Beispiel Canal+ First:
  # Woke~Das Treffen S01 E08. Monate später glaubt Keef, dass er endlich an einem besseren Ort angekommen...
  re='(.*)S([0-9]*) E([0-9]*)' #(. [a-z]*)'
  if [[ "$SUBTITLE" =~ $re ]] ; then  #* Kurztext enthält Sxx Exx
    S="${BASH_REMATCH[2]}"  # 01
    E="${BASH_REMATCH[3]}"  # 08
    [[ ${#S} -lt 2 ]] && S="0${S}"
    [[ ${#E} -lt 2 ]] && E="0${E}"
    SE="[S${S}E${E}]"
    SUBTITLE="${BASH_REMATCH[1]:-"-"}"  # Das Treffen
    SUBTITLE="${SUBTITLE%% }"           # Leerzeichen am Ende entfernen
  fi

  # Wenn in der Beschreibung 'Staffel, Folge' entahlen ist, diese verwenden
  if [[ "${DATA[5]:0:25}" =~ 'Staffel, Folge' ]] ; then  #* Beschreibung enthält x. Staffel, Folge x:
    SE="${DATA[5]%%\:*}"  # :* abschneiden (1. Staffel, Folge 3)
    S="${SE%%\.*}"        # .* abschneiden (1)
    E="${SE##*Folge }"    # '*Folge ' abschneiden (3)
    [[ ${#S} -lt 2 ]] && S="0${S}"
    [[ ${#E} -lt 2 ]] && E="0${E}"
    SE="[S${S}E${E}]"
  fi

  if [[ -z "$SUBTITLE" ]] ; then  # VDR: Leschs Kosmos~2017.03.07-23|00-Di
    SUBTITLE="${DATA[6]}_${DATA[7]}_${DATA[8]}"  # Sendezeit, falls Leer
  fi

  [[ -n "$FOUND_BRACE" ]] && SUBTITLE+=" $FOUND_BRACE"
  [[ "${#SE}" -ge 8 ]] && SUBTITLE+="  $SE"
fi

#! -> Das Skript muss eine Zeichenkette <ohne> Zeilenumbruch zurück geben!
#echo "=> Antwort: ${TITLE:-${DATA[0]}}~${SUBTITLE:-${DATA[1]}}" >> "$LOG_FILE"
echo -n "${TITLE}~${SUBTITLE}"  # Ausgabe an epgSearch

#if [[ -e "$LOG_FILE" ]] ; then  # Log-Datei umbenennen, wenn zu groß
#  FILE_SIZE="$(stat -c %s "$LOG_FILE" 2>/dev/null)"
#  [[ $FILE_SIZE -gt $MAX_LOG_SIZE ]] && mv --force "$LOG_FILE" "${LOG_FILE}.old"
#fi

exit  # Ende
