#!/bin/bash

# invalid_lock.sh
# Stündlich ausführen via /etc/cron.hourly (Symlink ohne .sh)
#VERSION=230715

LOG_DIR='/var/log'                               # System-Logdir
#SELF="$(readlink /proc/$$/fd/255)" || SELF="$0" # Eigener Pfad (besseres $0)
#SELF_NAME="${SELF##*/}"
LOG_FILE="${LOG_DIR}/syslog"                      # Logdatei
TMP_LOG='/tmp/~invalid_lock.txt'                # Temporäres Log
#MAILFILE="/tmp/~${SELF_NAME%.*}_mail.txt"
printf -v DT '%(%F)T' -1                        # 2020-09-09

[[ -e '/etc/mailadresses' ]] && source /etc/mailadresses
[[ -z "$MAIL_ADRESS" ]]  && { f_log "[!] Keine eMail-Adresse definiert!" ; exit 1 ;}

if [[ ! -e "${LOG_FILE}_Locking_$DT" ]] ; then  # Max. ein mal pro Tag
  if grep --before-context=25 --after-context=50 --ignore-case 'invalid lock' "$LOG_FILE" > "$TMP_LOG" ; then
    # invalid lock gefunden!
    cp --force "$LOG_FILE" "${LOG_FILE}_Locking_$DT"

    # Mail senden
    { echo "From: \"${HOSTNAME^^}\" <${MAIL_ADRESS}>"
      echo "To: ${MAIL_ADRESS}"
      echo 'Content-Type: text/plain; charset=UTF-8'
      echo -e "Subject: [${HOSTNAME^^}] Invalid lock sequence!\n"
      echo "Komplettes Log in ${LOG_FILE}_Locking_$DT"
      echo "==> Datei ${TMP_LOG}:"
      cat "$TMP_LOG"
    } | /usr/sbin/sendmail root
    # Alte Logs löschen
    find "$LOG_DIR" -maxdepth 1 -name '*_Locking_*' -type f -mtime +30 -delete
  fi  # grep
fi

exit
