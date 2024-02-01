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
        /usr/bin/vdr-dbus-send /Skin skin.QueueMessage string:"$*" ;;
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

f_logger '<START>'
