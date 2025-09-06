#!/usr/bin/env bash

# Get Systeminfos
# VERSION=240322

MOUNT_POINT='/mnt/MCP-Server_root'  # Einhängepunkt der Zieldatei
FILE_PATH='var/www'
INFO_FILE="${HOSTNAME^^}_Systeminfo.txt"

{ printf '%s %(%d.%m.%Y %R)T %s\n' "<### Systeminformationen (${HOSTNAME^^}) vom " -1 ' ###>'
  echo '=== inxi -Fxz ==='
  inxi --full --filter --extra  # Systeminformationen
  echo -e '\n\n=== vdr --version ==='
  vdr --version
  echo -e '\n\n=== vdr --showargs ==='
  vdr --showargs
  echo -e '\n\n=== lspci -v ==='
  lspci -v
} > "${MOUNT_POINT}/${FILE_PATH}/${INFO_FILE}" 2> "${MOUNT_POINT}/${FILE_PATH}/${INFO_FILE%.*}.err.txt"

# Ende
