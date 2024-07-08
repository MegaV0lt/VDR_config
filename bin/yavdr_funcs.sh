#!/usr/bin/env bash
# This file has to be included via source command
# VERSION=240219

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
        f_scvdrpsend_msgt "$*" ;;
    esac
    logger "$parm" --tag 'yaVDR' "[$$] ${SELF_NAME}: $*"
  fi
}

f_log() {  # Gibt die Meldung auf der Konsole und im Syslog aus
  [[ -t 1 ]] && echo "$*"      # Konsole
  logger -t "$SELF_NAME" "$*"  # Syslog
  [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log in Datei
}

f_log2() {
  local data=("${@:-$(</dev/stdin)}")               # Akzeptiert Parameter und via stdin (|)
  [[ -t 1 ]] && printf '%s\n' "${data[@]}"          # Konsole falls verbunden
  logger -t "$SELF_NAME" "${data[@]}"               # Systemlog
  [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && printf '%s\n' "${data[@]}" >> "$LOG_FILE"  # Log-Datei
}

f_rotate_log() {  # Log rotieren wenn zu groß
  local file="${LOG_FILE:-$1}" file_size
  if [[ -n "$file" && -w "$file" ]] ; then  # Datei Existiert und hat Schreibrechte
    file_size="$(stat -c %s "$file" 2>/dev/null)"
    [[ ${file_size:-51201} -gt ${MAX_LOG_SIZE:-51200} ]] && mv --force "$file" "${file}.old"
  fi
}

#f_strstr() {  # strstr echoes nothing if s2 does not occur in s1
#  [[ -n "$2" && -z "${1/*$2*}" ]] && return 0  # Gefunden
#  return 1
#}

f_svdrpsend_msgt() {
  mapfile -t < <("$SVDRPSEND" MSGT "${@:2}")  # Prüfen ob VDR den Befehl kennt
  # 220 vdr01 SVDRP VideoDiskRecorder 2.6.1; Thu Oct 27 15:30:24 2022; UTF-8
  # 500 Command unrecognized: "MSGT"
  # 221 vdr01 closing connection
  if [[ "${MAPFILE[1]}" == "500"* ]] ; then  # MSGT nicht vorhanden
    : "${2#@}" ; : "${_#%}"                  # '%' oder '@' entfernen
    "$SVDRPSEND" MESG "$_" "${@:3}"
  fi
}

f_logger '<START>'
