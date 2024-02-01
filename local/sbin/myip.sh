#!/bin/bash

# myip.sh
# Check ext. IP

IPFILE="/dev/shm/myip.txt"
DROPBOXUPLOADER="/usr/local/sbin/dropbox_uploader.sh"

echo "[$(basename $0)] IP-Adress of HDVDR01" > $IPFILE
curl curlmyip.com >> $IPFILE
$DROPBOXUPLOADER upload $IPFILE

exit
