#!/usr/bin/env bash

# get_SE.sh
#
# Hilfsskript, das von epgSearch aufgerufen wird und versucht aus dem Kurztext oder
# der Beschreibung die Nummern für Staffel und Episode zu extrahieren (SxxExx)
#
# Zusätzlich werden im Titel enthaltene Klammern am Ende in den Kurztext verschoben:
# 'Serienname (5/6)~Folgenname' -> 'Serienname~Folgenname (5/6)'
#VERSION=250724

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

# Konfiguration einbinden
source /etc/get_se.conf 2>/dev/null

# Variablen
#SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (besseres $0)
#SELF_NAME="${SELF##*/}"                          # skript.sh
DATA=("$@")                                       # Übergebene Daten in ein Array
TITLE="${DATA[0]}"                                # Titel der Sendung
SUBTITLE="${DATA[1]}"                             # Kurztext
#DEBUG='true'                                     # Debug via logger

### Start

_LC_ALL="${LC_ALL:-${LANG}}"  # Aktuelle Locale sichern
LC_ALL=C                      # Locale auf C setzen für schnelles Sortieren und RegEx

# Falls Kurztext leer ist, Episode oder Datum/Zeit verwenden
if [[ -z "$SUBTITLE" ]] ; then
  if [[ -n "${DATA[3]}" && "${DATA[3]}" =~ [A-Za-z]* ]] ; then
    SUBTITLE="${DATA[3]}"  # Episode enthält Buchstaben (TVSP schreibt Episodennamen in die Beschreibung)
  else
    LC_ALL="$_LC_ALL" printf -v SUBTITLE '%(%Y-%m-%d_%H|%M-%a.)T' "${DATA[6]}"  # 2017-03-07_13|00-Di.
  fi
else  # Entfernen von (WH vom ...) aus dem Kurztext
re='(.*)( \(WH vom .*\))'
if [[ "$SUBTITLE" =~ $re ]] ; then  #* Kurztext enthält (WH vom ...)
  SUBTITLE="${BASH_REMATCH[1]}"     # Wert speichern
  SUBTITLE="${SUBTITLE%%' '}"       # Leerzeichen am Ende entfernen
fi

fi

# Staffel- und Episoden-Nummer ermitteln
if [[ -z "${DATA[2]}" ]] ; then  # Staffel ist leer. Versuche Informationen aus dem Kurztext zu erhalten
  if [[ -n "$DEBUG_SE" ]] ; then
    logger -t "get_se.sh" "Trying to get missing Season/Episode from Subtitle: TITLE=${TITLE:-''} SUBTITLE=${SUBTITLE:-''}"
  fi

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

  # EPG Beispiel Sky:
  # Wenn in der Beschreibung 'Staffel, Folge' entahlen ist, diese verwenden
  #re='([0-9]+).*Staffel, Folge ([0-9]+)'
  #if [[ -z "$S" && "${DATA[5]:0:25}" =~ $re ]] ; then  #* Beschreibung enthält x. Staffel, Folge x:
  #  printf -v S '%02d' "${BASH_REMATCH[1]#0}"  # 01
  #  printf -v E '%02d' "${BASH_REMATCH[2]#0}"  # 08
  #fi

  # TVScraper Daten verwenden, falls vorhanden
  if [[ -z "$S" && -n "${DATA[7]}" ]] ; then
    if [[ -n "$DEBUG_SE" ]] ; then
      logger -t "get_se.sh" "Trying to get missing Season/Episode from TVScraper: S=${DATA[7]:-''} E=${DATA[8]:-''}"
    fi
    printf -v S '%02d' "${DATA[7]#0}"  # 01
    printf -v E '%02d' "${DATA[8]#0}"  # 03
  fi

  if [[ -n "$DEBUG_SE" ]] ; then
    logger -t "get_se.sh" "Got Season/Episode: S=${S:-''} E=${E:-''}"
  fi
fi

# Kurztext kürzen, falls zu lang ist
if [[ "${#SUBTITLE}" -ge 60 ]] ; then
    : "${SUBTITLE:0:60}"
    SUBTITLE="${_%%' '}…"  # Leerzeichen am Ende entfernen und … anhängen
fi

# Titel mit (*) am Ende?
re='\(.*\)$'
if [[ "$TITLE" =~ $re ]] ; then     #* Titel enthält Klammern am Ende!
  FOUND_BRACE="${BASH_REMATCH[0]}"  # Wert speichern '(5/6)'
  : "${TITLE%"${FOUND_BRACE}"}" ; TITLE="${_%%' '}"  # Klammern (und Leerzeichen) entfernen
fi

# Titel von TVScraper verwenden wenn im Original Titel enthalten
if [[ -n "${TITLE}" && -n "${DATA[9]}" ]] ; then  # Titel und Name in externer Datenbank
  # Vergleich in Kleinbuchstaben (Kommissar Van der Valk vs. Kommissar van der Valk)
  [[ "${TITLE,,}" =~ ${DATA[9],,} ]] && TITLE="${DATA[9]}"
fi

# Zeichen ersetzen, damit Aufnahmen nicht in unterschiedlichen Ordnern landen
TITLE="${TITLE// - / – }"  # Kurzen durch langen Bindestrich (La_Zona_-_Do_not_cross)
TITLE="${TITLE//’/\'}"     # Schräges ’ durch gerades ' (Marvel’s_Runaways)

# Kurztext von TVScraper verwenden (Vergleich in Kleinbuchstaben)
if [[ -n "${DATA[10]}" && "${SUBTITLE,,}" =~ ${DATA[10],,} ]] ; then  # Nur wenn in SUBTITLE enthalten
  SUBTITLE="${DATA[10]}"
fi

# Gefundene Klammern im Titel an Kurztext anhängen (5/6)
if [[ -n "$FOUND_BRACE" ]] ; then
  re='(\(S[0-9]+E[0-9]+\).*)'    # (S01E01)
  if [[ "$SUBTITLE" =~ $re ]] ; then
    se="${BASH_REMATCH[1]}"
    : "${SUBTITLE%  "${se}"}"    # SxxExx entfernen
    SUBTITLE="$_ ${FOUND_BRACE}  ${se}"
  else
    SUBTITLE+=" ${FOUND_BRACE}"  # Klammern am Ende anhängen
  fi
fi

# Erstellen von (SxxExx) und an Kurztext anhängen
[[ -n "$S" && -n "$E" ]] && SUBTITLE+="  (S${S}E${E})"
#logger -t "get_se.sh" "Final TITLE='${TITLE}' SUBTITLE='${SUBTITLE}'"

# echo "=> Antwort: ${TITLE}~${SUBTITLE}" >> "$LOG_FILE"
#! -> Das Skript muss eine Zeichenkette <ohne> Zeilenumbruch zurück geben!
printf '%s~%s' "${TITLE}" "${SUBTITLE}"  # Ausgabe an epgSearch

exit  # Ende
