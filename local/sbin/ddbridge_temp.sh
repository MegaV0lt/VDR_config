#!/bin/bash

DDBRIDGEDIR="/sys/class/ddbridge"

if [ ! -d $DDBRIDGEDIR ] ; then
  echo "$DDBRIDGEDIR not found"
  exit
fi

for i in $DDBRIDGEDIR/* ; do
  if [ -L $i ] ; then
    NUM="$(echo $i |cut -c 29-)"	
      if [ "$(cat $i/temp0 |grep sensor)" ] ; then
        echo "DDBridge $NUM -> No Sensor"
      else
        TEMP="$(cat $i/temp0)"
        TEMP="$(($TEMP/1000))"
        echo "DDBridge $NUM -> $TEMP"°C""
      fi    
  fi
done


