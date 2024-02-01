#!/bin/bash

# renice vdr and all its threads
# VERSION=170328

source /_config/bin/g2v_funcs.sh

until [[ -n "$(pidof vdr)" ]] ; do
  echo 'Waiting for vdr...'
  sleep 30
done

# Renice main vdr thread
# renice --priority "${VDR_NICE:-0}" --pid $(pidof vdr)

# List of vdr threads
mapfile -t < <(ps --no-heading -C vdr -L)

for i in "${!MAPFILE[@]}" ; do
  LINE_ARRAY=(${MAPFILE[i]})  # 4070  4070  tty8  00:00:05  vdr
  if [[ "${LINE_ARRAY[4]}" =~ ^LIRC* ]] ; then
    # continue  # EPGSearch nicht verändern
    renice --priority "${VDR_NICE:-0}" --pid "${LINE_ARRAY[1]}"
  fi
  # renice --priority "${VDR_NICE:-0}" --pid "${LINE_ARRAY[1]}"
done

# all vdr threads
# renice -n "${VDR_NICE:-0}" -p $(ps --no-heading -Lo tid $(pidof vdr))

exit  # Ende

Beispiel von 'ps --no-heading -C vdr -L':
 4103  4103 tty8     00:00:06 vdr
 4103  4636 tty8     00:00:00 frontend 0/0 tu
 4103  4637 tty8     00:00:08 device 1 sectio
 4103  4640 tty8     00:00:00 frontend 1/0 tu
 4103  4641 tty8     00:00:25 device 2 sectio
 4103  4644 tty8     00:00:00 frontend 2/0 tu
 4103  4645 tty8     00:00:18 device 3 sectio
 4103  4647 tty8     00:00:00 frontend 3/0 tu
 4103  4648 tty8     00:00:26 device 4 sectio
 4103  4813 tty8     00:00:01 IPTV section ha
 4103  4814 tty8     00:00:00 device 6 sectio
 4103  4863 tty8     00:00:07 vdr
 4103  4864 tty8     00:00:04 Socket Handler
 4103  4865 tty8     00:00:01 SC-CI adapter o
 4103  4866 tty8     00:00:01 SC-CI adapter o
 4103  4867 tty8     00:00:01 SC-CI adapter o
 4103  4868 tty8     00:00:01 SC-CI adapter o
 4103  4869 tty8     00:00:01 SC-CI adapter o
 4103  4876 tty8     00:00:00 EPGSearch: conf
 4103  4878 tty8     00:00:00 mainloop
 4103  4879 tty8     00:00:00 gmain
 4103  4881 tty8     00:00:00 gdbus
 4103  4883 tty8     00:00:00 vdr
 4103  4900 tty8     00:00:00 Fritz Plugin In
 4103  4901 tty8     00:00:00 tvscraper
 4103  4907 tty8     00:00:01 iMonLCD: watch
 4103  4908 tty8     00:00:00 LIRC remote con
 4103  4909 tty8     00:00:01 KBD remote cont
 4103  4910 tty8     00:00:40 device 1 receiv
 4103  4911 tty8     00:00:12 osdteletext-rec
 4103  4912 tty8     00:00:09 device 1 TS buf
 4103  4913 tty8     00:00:56 vdr
 4103 10863 tty8     00:02:58 EPGSearch: sear
 4103 11353 tty8     00:00:00 pool
