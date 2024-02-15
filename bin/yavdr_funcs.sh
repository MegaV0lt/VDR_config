#!/usr/bin/env bash
# This file has to be included via source command
# VERSION=230529

trap f_exit EXIT

SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Eigener Pfad (Besseres $0)
SELF_NAME="${SELF##*/}"                          # Eigener Name mit Erweiterung
SVDRPSEND="$(type -p svdrpsend)"                 # svdrpsend vom VDR

source /usr/lib/vdr/config-loader.sh  # yaVDR Vorgaben
[[ -z "$LOG_LEVEL" ]] && source /etc/vdr.d/conf/vdr

f_exit() { f_logger '<END>' ;}

f_detach() {
  [[ -z "$*" ]] && return 1
  "$@" &>/dev/null & disown
}

f_logger() {
  local parm
  if [[ "$LOG_LEVEL" != '0' ]] ; then
    case "$1" in
      -s|--stderr)
        parm='--stderr' ; shift ;;
      -o|--osd)
        parm='--stderr' ; shift
        #/usr/bin/vdr-dbus-send /Skin skin.QueueMessage string:"$*" ;;
        f_svdrpsend MESG "$*"
    esac
    logger "$parm" --tag 'yaVDR' "[$$] ${SELF_NAME}: $*"
  fi
}

f_rotate_log() {  # Log rotieren wenn zu groß
  local file="${LOG_FILE:-$1}"
  if [[ -w "$file" ]] ; then  # FILE exists and write permission is granted
    FILE_SIZE="$(stat -c %s "$file" 2>/dev/null)"
    [[ ${FILE_SIZE:-51201} -gt ${MAX_LOG_SIZE:-51200} ]] && mv --force "$file" "${file}.old"
  fi
}

f_strstr() {  # strstr echoes nothing if s2 does not occur in s1
  [[ -n "$2" && -z "${1/*$2*}" ]] && return 0  # Gefunden
  return 1
}

f_svdrps() {
  f_logger "$SVDRPSEND $*"
  "$SVDRPSEND" "$@"
}

f_svdrpsend() {
  if [[ "${1^^}" == 'MESG' ]] ; then
    if f_vdr_has_msgt ; then
      "$SVDRPSEND" MSGT "${@:2}"
    else
      : "${2#@}" ; clean_arg="${_#%}"  # '%' und '@' entfernen
      "$SVDRPSEND" MESG "$clean_arg" "${@:3}"
    fi
  else
    "$SVDRPSEND" "$@"  # Für alles andere durchreichen
  fi
}

f_vdr_has_msgt() {
  mapfile -t < <("$SVDRPSEND" MSGT)  # Prüfen ob VDR den Befehl kennt
  # 220 vdr01 SVDRP VideoDiskRecorder 2.6.1; Thu Oct 27 15:30:24 2022; UTF-8
  # 501 Missing message / 500 Command unrecognized: "MSGT"
  # 221 vdr01 closing connection
  [[ "${MAPFILE[1]}" == "501"* ]] && return 0   # MSGT vorhanden
  # [[ "${MAPFILE[1]}" == "500"* ]] && return false  # Kein MSGT
  return 1
}

f_logger '<START>'
