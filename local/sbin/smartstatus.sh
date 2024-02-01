#!/bin/bash

# smartstatus.sh
# Status der Disk(s) loggen und Mailen
#VERSION=230525

LOG_DIR='/var/log'                               # System-Logdir
SELF="$(readlink /proc/$$/fd/255)" || SELF="$0" # Eigener Pfad (besseres $0)
SELF_NAME="${SELF##*/}"
LOG_FILE="${LOG_DIR}/${SELF_NAME%.*}.log"         # Logdatei

[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]]  && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

# Parameter verwenden wenn angegeben
if [[ -n "$1" ]] ; then
  DISK="$(readlink -f "$1")"
else
  DISK=(/dev/sd?)
fi

# SMART-Status loggen
printf '==> %(%F-%R)T [%s]\n' -1 "${SELF_NAME}" > "$LOG_FILE"
for disk in "${DISK[@]}" ; do
  { echo -e "\nAktueller Status ($disk):"
    echo '----------------------------'
    smartctl -a "$disk"
  } >> "$LOG_FILE"
done

# Packen (z=gzip, J=xz)
#tar cfvz [ARCHIV].tar.gz [VERZEICHNIS1] [DATEI1]
#tar cfvJ $LOG_DIR/$ARCHIV $TMP_DIR

# Mail senden
{ echo "From: ${HOSTNAME^^}<${MAIL_ADRESS}>"
  echo "To: ${MAIL_ADRESS}"
  echo 'Content-Type: text/plain; charset=UTF-8'
  echo "Subject: [${HOSTNAME^^}] SMART-Status"
  echo -e "\nSMART-Status (${DISK[*]}) auf ${HOSTNAME^^}\n"
  #echo "Das Log ist angehängt"
  cat "$LOG_FILE"
} | /usr/sbin/sendmail root

#iconv --from-code=UTF-8 --to-code=iso-8859-1 -c "$MAILFILE" \
#  | /usr/sbin/sendmail root  #  ^Damit Umlaute richtig angezeigt werden
#mpack -s "SMART-Status" -d $MAILFILE $LOG_FILE root # Kann "root" sein, wenn in sSMTP konfiguriert

exit
