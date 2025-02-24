#!/usr/bin/env bash

source /_config/bin/yavdr_funcs.sh &>/dev/null

echo 'Collecting information…'
if [[ "$1" == '-v' ]] ; then
  VERBOSE=1
  OUTPUT="$2"
elif [[ "$2" == '-v' ]] ; then
  VERBOSE=1
  OUTPUT="$1"
else
  VERBOSE=0
  OUTPUT="$1"
fi

#rm -f $(find /log/ /tmp/ -mtime +5 -type f | grep -v "g2v_log_install")
printf -v DT '%(%F_%H%M.%S)T' -1  # 2023-05-22_1834.49
LOG_ARCH="/tmp/yavdr_log_${DT}.tar.xz"
LOG_DIR="/tmp/yavdr_log_${DT}"
#rm -rf "$LOG_DIR" > /dev/null 2>&1
mkdir --parents "$LOG_DIR"
cd "$LOG_DIR"
dmesg -T > dmesg.out 2>&1
biosinfo > bios.out 2>&1
lsmod > lsmod.out 2>&1
lshw > lshw.out 2>&1
lsusb -v > lsusb.out 2>&1
lspci -vn > lspci.out 2>&1
ps -ef > ps.out 2>&1
biosinfo > qmb.out 2>&1
/_config/bin/query_mb.sh >> qmb.out 2>&1
uname -a > uname.out 2>&1
/_config/bin/detect_modules.sh > det_mod.out 2>&1
ls -l /tmp/ > lltmp.out 2>&1
ls -l /usr/local/src/ > llsrc.out 2>&1
cat /proc/meminfo > meminfo.out 2>&1
cat /proc/cpuinfo > cpuinfo.out 2>&1
top -b -d 1 -n 5 > top.out 2>&1
{ ifconfig
  ping -c 2 -w 5 www.yavdr.de
  echo -e '\nresolv.conf:'
  cat /etc/resolv.conf
} > net.out 2>&1
cat /proc/bus/input/devices > input.out 2>&1
hwinfo > hwinfo.out
mount > mount.out
df -h > df.out
cat /log/syslog > sys.log

FILES="/log/kodi.log.old /log/rc.log /log/dmsg /install.log /_config/update/update.log /etc/gen2vdr/applications  /etc/gen2vdr/remote \
 /etc/vdr.d/conf/vdr /etc/vdr/setup.conf /etc/vdr/channels.conf /etc/X11/xorg.conf /etc/vdr/plugins/admin/admin.conf /root/.kodi/temp/*log* \
 /log/vdr-xine.log /log/hibernate.log /log/Xorg.0.log /root/.xine/config /root/.xine/config_xineliboutput /etc/asound.conf /etc/asound.state \
 /etc/g2v-release /tmp/vdr/vdr_* /etc/X11/xorg.conf.d/*"

[[ "$VERBOSE" == '1' ]] && FILES+=" /etc/conf.d $(ls /log/messages-2* | tail -n3)"

cp -af "$FILES" . 2>/dev/null

/_config/bin/get_core.sh > core.out 2>&1

aplay -lL > aplay.out
for i in /proc/asound/card[0-9] ; do
   cnum=${i#*card}
   { echo "SoundCard $cnum :"
     amixer contents -c $cnum
     amixer scontents -c $cnum
     echo ''
   } >> sound.out
   alsactl store $cnum
done

tar -cJf "$LOG_ARCH" .
#f_dbus_send_message "$LOG_ARCH wurde erstellt"
f_logger -s "$LOG_ARCH wurde erstellt"
cd ..
rm -rf "$LOG_DIR"
if [[ "$OUTPUT" == '-m' ]] ; then
  TARGET=$(mount | grep " /media/" | tail -n 1 | cut -f 3 -d " ")
  if [ "$TARGET" != "" ] && [ -d "$TARGET" ] ; then
    OUTPUT="${TARGET}/"
    cp -f "$LOG_ARCH" "$TARGET/"
    sleep 3
    f_dbus_send_message "$LOG_ARCH wurde nach $TARGET kopiert"
    f_logger -s "$LOG_ARCH wurde nach $TARGET kopiert"
  fi
elif [[ -n "$OUTPUT" ]] ; then
  cp "$LOG_ARCH" "$OUTPUT.tar.xz"
  f_dbus_send_message "$LOG_ARCH wurde nach $OUTPUT.tar.xz kopiert"
  f_logger -s "$LOG_ARCH wurde nach $OUTPUT.tar.xz kopiert"
fi
