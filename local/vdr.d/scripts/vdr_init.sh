#!/usr/bin/env bash
#
# vdr_init.sh
#
# Wird kurz vor dem Start von VDR ausgeführt
# Skripte in /etc/vdr.d werden nacheinander ausgeführt
#
# VERSION=230619

source /_config/bin/yavdr_funcs.sh

export LANG='de_DE.UTF-8'
export VDR_LANG='de_DE.UTF-8'

# Starte eigene Skripte in /etc/vdr.d/
for file in /etc/vdr.d/[0-9]* ; do
  f_logger "Starting $file"
  source "$file" | logger
done

# Aktivie Coredumping, wenn Debug an ist (LOG_LEVEL=3)
if [[ "$LOG_LEVEL" -gt 2 ]] ; then
   [[ ! -d /var/tmp/corefiles ]] && mkdir /var/tmp/corefiles
   chmod 777 /var/tmp/corefiles
   echo '/var/tmp/corefiles/core' > /proc/sys/kernel/core_pattern
   echo '1' > /proc/sys/kernel/core_uses_pid
   ulimit -c unlimited
   locale -v | logger
   env | logger
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

# Defekte Symlinks in /video entfernen
find "$VIDEO"/ -xtype l -print -delete | logger

# Alte .rec löschen
find "$VIDEO"/ -name '.rec' -type f -print -delete | logger

# Auf Hintergrundjobs warten
wait

# Ende
