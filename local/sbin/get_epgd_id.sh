#!/bin/bash

# Little Script for getting ID's for EPG from TVM, TV-Spielfilm and epgdata.com.

# by 3PO
# Mod by MegaV0lt
VERSION=200302

echo "${0##/} #$VERSION"

EPGD_CONF="/etc/epgd/epgd.conf"
CHANNELSCONF="/etc/vdr/channels.conf"
OUTFILE="/tmp/channelmap.conf"

[ -f $EPGD_CONF ] && PIN="$(grep epgdata.pin $EPGD_CONF |awk '{print $3 }')"
PIN_LENGTH="$(echo "$PIN" |wc -c)"

#URL="http://wwwa.tvmovie.de/static/tvghost/html/onlinedata/cftv520/datainfo.txt"
URL='http://www.clickfinder.de/daten/onlinedata/cftv520/datainfo.txt'

download_epgdata ()
{
if [ ! "$(ping -c 1 www.epgdata.com 1>/dev/null)" ] ; then
  if [ $PIN ] ; then
     cd $HOME
     [ ! -d .epgidcheck ] && mkdir .epgidcheck
     cd .epgidcheck
     CHECK_AGE=$(find . \( -name '*.zip' \) -ctime -1 -exec ls {} \; |wc -l)
     if [ $CHECK_AGE -eq 0 ] ; then
       rm -f *.xml *.zip
       echo -e "\n loading list from \"www.epgdata.com\" ...\n"
       curl -s "http://www.epgdata.com/index.php?action=sendInclude&iOEM=vdr&pin=$PIN&dataType=xml" -o data.zip
       if [ "$(grep "Wrong value in an parameter" data.zip)" ] ; then
         echo -e "\nWrong or expired Pin detected\n"
         echo -e "\nScript terminated\n"
         exit
       fi
       unzip data.zip
       echo -e "\n\n"
     fi
  fi
else
  echo -e "\nServer www.epgdata.com not available"
  echo -e "\nScript terminated\n"
fi

}

sort_output ()
{
LOOP=0
while [ $LOOP -eq 0 ] ; do
  echo -e "\n	Please type \"a\" for sorting Channelnames in alphabetical order,"
  echo "	or type \"i\" for output sorted by IDs."
  read CHOOSE
  echo -en "\n"
  case $CHOOSE in

    [a]|[i])
    LOOP=1
    ;;

    *)
    LOOP=0
    ;;

  esac
done

}

case $1 in

   -tvm|tvm)
   sort_output
   if [ "$CHOOSE" == a ] ; then
     SORT="f"
   else
     SORT="n"
   fi
   if [ ! "$(ping -c 1 wwwa.tvmovie.de 1>/dev/null)" ] ; then
     lynx --dump $URL | tail -n +4 |while read i ; do
     if [ "$str" == "" ] ; then
     str="$i"
     else
       [ "$CHOOSE" == a ] && printf "%-28s %s\n" "${str}" "${i}"
       [ "$CHOOSE" == i ] && printf "%-10s %s\n" "${i}" "${str}"
       str=""
     fi
     done |sort -$SORT
   else
     echo -e "\nServer wwwa.tvmovie.de not available"
     echo -e "\nScript terminated\n"
   fi
   ;;

   -edc|edc)
   if [ $PIN_LENGTH != 41 ] ; then
     echo -e "\nNo, or incorrect Pin for epgdata.com found!"
     echo -e "\nScript terminated\n"
   else
     sort_output
     if [ "$CHOOSE" == a ] ; then
       SORT="f"
     else
       SORT="n"
     fi
     download_epgdata
     egrep "<ch0>|<ch4>" channel_y.xml |cut -d ">" -f2 |cut -d "<" -f1 |while read i ; do
     if [ "$str" == "" ] ; then
       str="$i"
     else
       [ "$CHOOSE" == a ] && printf "%-40s %s\n" "${str}" "${i}"
       [ "$CHOOSE" == i ] && printf "%-7s %s\n" "${i}" "${str}"
       str=""
     fi
     done |sort -$SORT
   fi
   ;;

   -tvsp|tvsp)
   URL="https://live.tvspielfilm.de/static/content/channel-list/livetv"
   echo ""
   sort_output
   if [ "$CHOOSE" == a ] ; then
     curl -s $URL | \
     gunzip -c | \
     jq -r '.[] | (.name+"                            ")[0:30] +.id' | \
     sort -f
   elif [ "$CHOOSE" == i ] ; then
     curl -s $URL | \
     gunzip -c | \
     jq -r '.[] | (.id+"                            ")[0:10] +.name' | \
     sort -f
   fi
   ;;

   -pin|pin)
   if [ $PIN_LENGTH != 41 ] ; then
     echo -e "\nNo, or incorrect Pin for epgdata.com found!"
   else
     echo -e "\n$PIN\n"
   fi
   ;;

   -parse|parse)
   if [ ! -f "$CHANNELSCONF" ] ; then
    echo -e "\n \"$CHANNELSCONF\" not found"
    echo -e "\nScript terminated\n"
    exit
   fi

   [ -f $OUTFILE ] && rm $OUTFILE
   grep -van "^:" $CHANNELSCONF | cut -f 1,2,5,11,12,13 -d ":" | while read i ; do
    nr=${i%%:*}
    i=${i#*:}
    name=${i%%:*}
    i=${i#*:}
    source=${i%%:*}
    i=${i#*:}
    sid=${i%%:*}
    i=${i#*:}
    nid=${i%%:*}
    i=${i#*:}
    tid=${i%%:*}
    printf  "%-25s %s %s\n" "$source-$nid-$tid-$sid" // "${name}" >> $OUTFILE;
   done
   echo -e "\n   $OUTFILE successful written\n"
   ;;

   *)
   echo -e "\n   Little Script for getting ID's for EPG from TV-Movie, TV-Spielfilm and epgdata.com."
   echo -e "\n   by 3PO\n"
   echo -e "\n   usage: [-tvm] [-edc] [-tvsp] [-pin] [-parse]\n"
   echo -e "	-tvm    TV-Movie IDs"
   echo -e "	-edc    epgdata.com IDs"
   echo -e "	-tvsp   TV-Spielfilm IDs"
   echo -e "	-pin    Show Pin for epgdata.com"
   echo -e "	-parse  Parse the channels.conf to channelmap.conf format\n"
   ;;

esac
