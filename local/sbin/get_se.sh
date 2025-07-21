#!/usr/bin/env bash

# get_SE.sh
#
# Hilfsskript, das von epgSearch aufgerufen wird und versucht aus der Beschreibung
# die Werte für Staffel und Episode zu extrahieren (SxxExx)
#
# Zusätzlich werden im Titel enthaltene Klammern am Ende in den Kurztext verschoben:
# 'Serienname (5/6)~Folgenname' -> 'Serienname~Folgenname (5/6)'
#VERSION=240724

# Folgende Variablen sind bereits intern definiert und können verwendet werden.
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

# Aufruf in epgsearchuservars.conf:
#%Get_SE%=system(/usr/local/sbin/get_se.sh,
# %Title% %Subtitle% %Staffel% %Episode% %Folge% %Summary% %time_lng% %Nummer der Staffel% %Nummer der Episode% %Name in externer Datenbank% %Name der Episode%)
#  0       1          2         3         4       5         6          7 (TVScraper)        8 (TVScraper)        9                            10

#SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
#SELF_NAME="${SELF##*/}"                          # skript.sh
DATA=("$@")                                       # Übergebene Daten in ein Array
TITLE="${DATA[0]}"                                # Titel der Sendung
SUBTITLE="${DATA[1]}"                             # Kurztext
#DEBUG='true'                                     # Debug via logger

### Funktionen
f_shorten_subtitle() {  # Kürzt den Kurztext auf 75 Zeichen
  local length=75
  if [[ "${#SUBTITLE}" -ge $length ]] ; then
      : "${SUBTITLE:0:length}"
      SUBTITLE="${_%%' '}…"  # Kürzen und Leerzeichen am Ende entfernen
  fi
}

### Start

# Titel von TVScraper verwenden
if [[ -n "${DATA[9]}" ]] ; then  # Name in externer Datenbank
  if [[ "${TITLE}" =~ ${DATA[9]} ]] ; then
    TITLE="${DATA[9]}"             # Titel der Sendung
  fi
fi

# Kurztext von TVScraper verwenden  # TODO
if [[ -n "${SUBTITLE}" && -n "${DATA[10]}" ]] ; then  # Name der Episode
  # Nur wenn in SUBTITLE enthalten
  if [[ "${SUBTITLE}" =~ ${DATA[10]} ]] ; then
    SUBTITLE_TVS="${DATA[10]}"       # Kurztext der Sendung
  fi
fi

# Zeichen ersetzen, damit Aufnahmen nicht in unterschiedlichen Ordnern landen
case "${DATA[0]}" in
  *' - '*) DATA[0]="${DATA[0]//' - '/' – '}" ;;  # Kurzen durch langen Bindestrich (La_Zona_–_Do_not_cross)
  *"’"*)   DATA[0]="${DATA[0]//’/\'}"    ;;      # Schräges ’ durch gerades ' (Marvel’s_Runaways)
  *) ;;
esac  # Ende Zeichenersetzung

# Titel mit (*) am Ende?
re='\(.*\)$'
if [[ "$TITLE" =~ $re ]] ; then     #* Titel enthält Klammern am Ende!
  FOUND_BRACE="${BASH_REMATCH[0]}"  # Wert speichern '(5/6)'
  : "${TITLE%"${FOUND_BRACE}"}" ; TITLE="${_%%' '}"  # Klammern (und Leerzeichen) entfernen
fi

f_shorten_subtitle  # Kurztext kürzen, falls zu lang ist

if [[ -z "${DATA[2]}" ]] ; then  # Staffel ist leer. Versuche Informationen aus dem Kurztext zu erhalten
  # EPG Beispiel Canal+ First:
  # Woke~Das Treffen S01 E08. Monate später glaubt Keef, dass er endlich an einem besseren Ort angekommen...
  re='(.*)S([0-9]+) E([0-9]+)' #(. [a-z]*)'
  if [[ "$SUBTITLE" =~ $re ]] ; then  #* Kurztext enthält Sxx Exx
    printf -v S '%02d' "${BASH_REMATCH[2]#0}"  # 01
    printf -v E '%02d' "${BASH_REMATCH[3]#0}"  # 08
    : "${BASH_REMATCH[1]}"  # Das Treffen
    SUBTITLE="${_%% }"      # Leerzeichen am Ende entfernen
  fi

  # EPG Beispiel 3+:
  # Superstar~Staffel 01 - Folge 03: Highlights (1) / Castingshow, Schweiz 2006
  re='Staffel ([0-9]+).*Folge ([0-9]+)(.*)'
  if [[ -z "$S" && "$SUBTITLE" =~ $re ]] ; then  #* Kurztext enthält Sxx Exx
    printf -v S '%02d' "${BASH_REMATCH[1]#0}"  # 01 # Führende Null entfernen
    printf -v E '%02d' "${BASH_REMATCH[2]#0}"  # 03
    SUBTITLE="${BASH_REMATCH[3]}"  # : Highlights (1) / Castingshow, Schweiz 2006
    re='^[:/ ]'
    while [[ "$SUBTITLE" =~ $re ]] ; do  # Alle führenden Leerzeichen, '/' oder ':' entfernen
      SUBTITLE="${SUBTITLE:1}"
    done
  fi

  # Wenn in der Beschreibung 'Staffel, Folge' entahlen ist, diese verwenden
  #re='([0-9]+).*Staffel, Folge ([0-9]+)'
  #if [[ -z "$S" && "${DATA[5]:0:25}" =~ $re ]] ; then  #* Beschreibung enthält x. Staffel, Folge x:
  #  printf -v S '%02d' "${BASH_REMATCH[1]#0}"  # 01
  #  printf -v E '%02d' "${BASH_REMATCH[2]#0}"  # 08
  #fi

  # TVScraper Daten vorhanden?
  if [[ -z "$S" && -n "${DATA[7]}" ]] ; then
    printf -v S '%02d' "${DATA[7]#0}"  # 01
    printf -v E '%02d' "${DATA[8]#0}"  # 03
  fi

  if [[ -z "$SUBTITLE" ]] ; then  # VDR: Leschs Kosmos~2017-03-07_13|00-Di.
    printf -v SUBTITLE '%(%Y-%m-%d_%H|%M-%a.)T' "${DATA[6]}"  # Sendezeit, falls Leer
  fi

  [[ -n "$FOUND_BRACE" ]] && SUBTITLE+=" $FOUND_BRACE"

  # Erstellen von [SxxExx]
  [[ -n "$S" && -n "$E" ]] && SE="[S${S}E${E}]"
  [[ "${#SE}" -ge 8 ]] && SUBTITLE+="  $SE"
fi

# Gefundene Klammern im Titel an Kurztext anhängen
if [[ -n "$FOUND_BRACE" ]] ; then
  re='(\(S[0-9]+E[0-9]+\).*)'   # (S01E01)
  re2='(\[S[0-9]+E[0-9]+\].*)'  # [S01E01]
  [[ "$SUBTITLE" =~ $re ]] && { SE="${BASH_REMATCH[1]}" ;}
  [[ "$SUBTITLE" =~ $re2 ]] && { SE2="${BASH_REMATCH[1]}" ;}
  if [[ -n "$SE" || -n "$SE2" ]] ; then
    : "${SUBTITLE%  "${SE:-$SE2}"}"
    SUBTITLE+=" ${FOUND_BRACE}  ${SE2:-$SE2}"
  fi
fi

#! -> Das Skript muss eine Zeichenkette <ohne> Zeilenumbruch zurück geben!
# echo "=> Antwort: ${TITLE}~${SUBTITLE}" >> "$LOG_FILE"
echo -n "${TITLE}~${SUBTITLE}"  # Ausgabe an epgSearch

exit  # Ende
