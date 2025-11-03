#!/usr/bin/env bash

# sendmail.sh (Symlink nach /usr/sbin/sendmail und /usr/bin/sendmail)
# Wrapper für msmtp. Dienste wie Anacron verwenden als From: nur root
# Fehlende Header (Z. B. Content-Type:) werden ergänzt
VERSION=251103

### Variablen
SELF="$(readlink /proc/$$/fd/255)"     # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"
LOG="/var/log/${SELF_NAME%.*}.log"     # Log
MAX_LOG_SIZE=$((100*1024))               # In Bytes
PREFER_FROM_MAIL='true'                # From-Name aus Mailtext bevorzugen
MAILER='/usr/bin/msmtp'                # Mail-Programm

### Funktionen
f_trim() {  # Entfernt Leerzeichen am Anfang und Ende
  local -n ptr="$1"
  : "${ptr%% }" ; ptr="${_## }"
}

f_log() {                                           # Akzeptiert Parameter und via stdin (|)
  local data=("${@:-$(</dev/stdin)}")
  printf '%s\n' "${data[@]}" 2>/dev/null >> "${LOG:-/dev/null}"  # Log-Datei
  [[ -t 1 ]] && printf '%s\n' "${data[@]}"          # Konsole falls verbunden
  logger -t "$SELF_NAME" "${data[@]}"               # Systemlog
}

### Start
[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]] && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}
printf '%s %(%F %R)T %b\n' '==>' -1 "- $SELF_NAME #${VERSION}" | f_log
f_log "[i] Parameter ($#): $*"

[[ $# -eq 0 ]] && { f_log '[!] Keine Parameter übergeben! (exit)'; exit 1 ;}

# Workaround für Anacron - Anacron Übergibt: -FAnacron -odi root
for par in "$@" ; do
  if [[ "$par" =~ ^-[Ff] ]] ; then  # -F oder -f
    FROM_NAME="${par/${BASH_REMATCH[0]}/}"  # Gibt "Anacron"
  fi
  ARG+=("$par")  # Parameter in Array ARG kopieren
done

# Letzter Parameter (To) enthält kein "@" und beginnt nicht mit "-"
if [[ ! "${ARG[-1]}" =~ @ && ! "${ARG[-1]}" =~ ^- ]] ; then
  f_log "[!] Letzter Parameter ohne '@': ${ARG[-1]}"
  ARG[-1]+="<${TO_ADRESS}>"  # Neue To-Adresse
fi

# Ergebnis
f_log "[i] Parameter nach Bearbeitung (${#ARG[@]}): ${ARG[*]}"

# eMail-text in Array einlesen (Von STDIN)
mapfile -t MAIL_TEXT

for i in "${!MAIL_TEXT[@]}" ; do
  if [[ "${MAIL_TEXT[i]}" =~ ^From: ]] ; then
    FROM_FOUND=1
    f_log "[i] Gefundenes \"From:\" > ${MAIL_TEXT[i]}"
    if [[ -z "$FROM_NAME" || "$PREFER_FROM_MAIL" == 'true' ]] ; then
      : "${MAIL_TEXT[i]#From:}" ; from_name="${_%<*}"
      f_trim 'from_name'  # Leerzeichen am Anfang und Ende entfernen
      [[ "${#from_name}" -ge 1 ]] && FROM_NAME="$from_name"
    fi
    NEW_FROM="From: ${FROM_NAME:-root}<${MAIL_ADRESS}>"
    MAIL_TEXT[i]="$NEW_FROM"
    f_log "[i] Geändertes \"From:\" > ${MAIL_TEXT[i]}"
    continue
  fi
  if [[ "${MAIL_TEXT[i]}" =~ ^T[oO0]: ]] ; then  # To:, TO: oder T0:
    f_log "[i] Gefundenes \"To:\" > ${MAIL_TEXT[i]}"
    if [[ -n "$TO_FOUND" ]] ; then
      f_log "[w] Entferne Doppeltes 'To:'!"
      unset -v 'MAILTEXT[i]' ; ((i-=1))
      continue  # Weiter mit nächster Zeile
    fi
    TO_FOUND=1
    if [[ ! "${MAIL_TEXT[i]}" =~ @ ]] ; then
      MAIL_TEXT[i]+="<${TO_ADRESS}>"
      f_log "[i] Geändertes \"To:\" > ${MAIL_TEXT[i]}"
    fi
    continue
  fi
  if [[ "${MAIL_TEXT[i]}" =~ ^(Content-Type:.*) ]] ; then
    f_log "[i] ${BASH_REMATCH[0]} gefunden"
    CONTENT_FOUND=1
  fi
  [[ "$i" -gt 25 ]] && break  # Nach 25 Zeilen beenden
done

# From: nicht gefunden?
if [[ -z "$FROM_FOUND" ]] ; then
  NEW_FROM="From: ${FROM_NAME:-root}<${MAIL_ADRESS}>"
  f_log "[w] Kein 'From:' gefunden! Neues \"From:\" > $NEW_FROM"
fi

# Wenn eine Empfänger-Adresse angegeben ist, dann ist '-t' nicht erlaubt!
if [[ -n "$TO_FOUND" && ! "${ARG[*]}" =~ -t && ! "${ARG[-1]}" =~ @ ]] ; then
  f_log "[i] Ergänze Parameter '-t'"
  ARG=('-t' "${ARG[@]}")
fi

if [[ -z "$CONTENT_FOUND" ]] ; then
  f_log"[i] Kein 'Content-Type:' gefunden. Erzeuge neues"
  CONTENT_TYPE='Content-Type: text/plain; charset=UTF-8'
fi

# Fehlende Header hinzufügen und eMail senden
{ #printf '%s\n' 'MIME-Version: 1.0'
  [[ -n "$CONTENT_TYPE" ]] && printf '%s\n' "$CONTENT_TYPE"
  [[ -z "$FROM_FOUND" ]] && printf '%s\n' "$NEW_FROM"
  [[ -z "${MAIL_TEXT[0]}" ]] || printf '\n'  # Leerzeile, falls nicht vorhanden
  printf '%s\n' "${MAIL_TEXT[@]}"
} | "$MAILER" "${ARG[@]}" | f_log

# Für Debug-Zwecke:
{ printf '%s\n' "[DEBUG]:"
  [[ -n "$CONTENT_TYPE" ]] && printf '%s\n' "$CONTENT_TYPE"
  [[ -z "$FROM_FOUND" ]] && printf '%s\n' "$NEW_FROM"
  printf '%s\n' "${MAIL_TEXT[@]:0:7}"  # 7 Zeilen
} | f_log

if [[ -e "$LOG" && -w "$LOG" ]] ; then  # Log-Datei umbenennen, wenn zu groß
  FILE_SIZE="$(stat -c %s "$LOG" 2>/dev/null)"
  [[ ${FILE_SIZE:-$MAX_LOG_SIZE} -ge $MAX_LOG_SIZE ]] && mv --force "$LOG" "${LOG}.old"
fi

exit 0  # Ende
