#!/usr/bin/env bash
#
# vdr_init.sh
#
# Wird kurz vor dem Start von VDR ausgeführt
# Skripte in /etc/vdr.d werden nacheinander ausgeführt
#
# VERSION=250106

source /_config/bin/yavdr_funcs.sh &>/dev/null

# Funktionen
if ! declare -F f_logger >/dev/null ; then
  f_logger() { logger -t yaVDR "vdr_init.sh: $*" ;}  # Einfachere Version
fi

export LANG='de_DE.UTF-8'
export VDR_LANG='de_DE.UTF-8'

# Test
# /_config/local/sbin/check_setup_conf.sh &>/dev/null & disown

# From https://stackoverflow.com/a/11056286/21633953
#( your_command ) & pid=$!
#( sleep $TIMEOUT && kill -HUP $pid ) 2>/dev/null & watcher=$!
#wait $pid 2>/dev/null && pkill -HUP -P $watcher

# Starte eigene Skripte in /etc/vdr.d/
TIMEOUT=10  # Timeout für Skripte
for file in /etc/vdr.d/[0-9]* ; do
  f_logger "Starting $file"
  ("$file" | logger -t "${file##*/}") & pid=$!
  (sleep "$TIMEOUT" && kill -HUP "$pid") 2>/dev/null & watcher=$!
  wait "$pid" 2>/dev/null && pkill -HUP -P "$watcher"
done

# Aktiviere Coredumping, wenn Debug an ist (LOG_LEVEL=3)
if [[ "$LOG_LEVEL" -gt 2 ]] ; then
   [[ ! -d /var/tmp/corefiles ]] && mkdir /var/tmp/corefiles
   chmod 777 /var/tmp/corefiles
   echo '/var/tmp/corefiles/core' > /proc/sys/kernel/core_pattern
   echo '1' > /proc/sys/kernel/core_uses_pid
   ulimit -c unlimited
   locale -v | logger -t "$SELF_NAME"
   env | logger -t "$SELF_NAME"
fi

#Build commands.conf
#if [ -d /etc/vdr/commands ] ; then
#   for i in  /etc/vdr/commands/[0-9]* ; do
#      [ "${i/*\.*/}" == "" ] && continue
#      if [ "$CMDSUBMENU" = "1" ] ; then
#         echo "${i/*_/} {"
#         cat $i | sed -e "s/^\([^$]\)/  \1/"
#         echo "  }"
#      else
#         cat $i
#      fi
#      echo ""
#  done > /etc/vdr/commands.conf
#fi

#Build reccmds.conf
#if [ -d /etc/vdr/reccmds ] ; then
#   for i in  /etc/vdr/reccmds/* ; do
#      cat $i
#      echo ""
#   done > /etc/vdr/reccmds.conf
#fi

# Alte core.* Dateien entfernen
if [[ -d /var/tmp/corefiles ]] ; then
  find /var/tmp/corefiles/ -type f -mtime +30 -print -delete | logger -t "$SELF_NAME"
fi

: "${VIDEO:=/video}"  # Vorgabe wenn leer

logger -t "$SELF_NAME" 'Clean up /video directory…'

# Defekte Symlinks in /video entfernen
find "$VIDEO"/ -xtype l -print -delete | logger -t "$SELF_NAME"

# Alte .rec löschen
find "$VIDEO"/ -name '.rec' -type f -mtime +1 -print -delete | logger -t "$SELF_NAME"

# Alte .markad.pid löschen
find "$VIDEO"/ -name 'markad.pid' -type f -mtime +1 -print -delete | logger -t "$SELF_NAME"

# Leere Verzeichnisse in /video entfernen
find "$VIDEO"/ -type d -empty -print -delete | logger -t "$SELF_NAME"

# Ende
