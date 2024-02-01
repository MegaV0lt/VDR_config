#!/usr/bin/env bash

# Get Systeminfos
# VERSION=231207

MOUNT_POINT='/mnt/MCP-Server_root'  # Einhängepunkt der Zieldatei
FILE_PATH='var/www'
INFO_FILE="${HOSTNAME^^}_Systeminfo.txt"

{ printf '%s %(%d.%m.%Y %R)T %s\n' '###' -1 '###'
  echo '=== inxi -Fxz ==='
  inxi -Fxz  # Systeminformationen
  echo '=== lspci -v ==='
  lspci -v
  echo '=== vdr --version ==='
  vdr --version
} > "${MOUNT_POINT}/${FILE_PATH}/${INFO_FILE}" 2> "${MOUNT_POINT}/${FILE_PATH}/${INFO_FILE%.*}.err.txt"

# Ende
