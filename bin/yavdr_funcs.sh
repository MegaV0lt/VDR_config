#!/usr/bin/env bash
# This file has to be included via source command
# VERSION=250224

trap f_exit EXIT

SELF="$(readlink /proc/$$/fd/255)" || SELF="$0"  # Own path (better $0)
SELF_NAME="${SELF##*/}"                          # Own name with extension
SVDRPSEND="$(type -p svdrpsend)"                 # svdrpsend from VDR

source /usr/lib/vdr/config-loader.sh  # yaVDR defaults
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
        #f_svdrpsend_msgt "$*" ;;
        f_dbus_send_message "$@" ;;
    esac
    logger "$parm" --tag 'yaVDR' "[$$] ${SELF_NAME}: $*"
  fi
}

f_log() {  # Outputs message to console and syslog
  [[ -t 1 ]] && echo "$*"      # Console
  logger -t "$SELF_NAME" "$*"  # Syslog
  if [[ -n "$LOG_FILE" ]] ; then
    [[ ! -e "$LOG_FILE" ]] && : >> "$LOG_FILE"        # Create file
    [[ -w "$LOG_FILE" ]] && echo "$*" >> "$LOG_FILE"  # Log to file
  fi
}

f_log2() {
  local data=("${@:-$(</dev/stdin)}")               # Accepts parameters and via stdin (|)
  [[ -t 1 ]] && printf '%s\n' "${data[@]}"          # Console if connected
  logger -t "$SELF_NAME" "${data[@]}"               # Syslog
  if [[ -n "$LOG_FILE" ]] ; then
    [[ ! -e "$LOG_FILE" ]] && : >> "$LOG_FILE"        # Create file
    [[ -w "$LOG_FILE" ]] && printf '%s\n' "${data[@]}" >> "$LOG_FILE"  # Log file
  fi
}

f_rotate_log() {  # Rotate log if too large
  local file="${LOG_FILE:-$1}" file_size
  if [[ -n "$file" && -w "$file" ]] ; then  # File exists and has write permissions
    file_size="$(stat -c %s "$file" 2>/dev/null)"
    [[ ${file_size:-51200} -ge ${MAX_LOG_SIZE:-51200} ]] && mv --force "$file" "${file}.old"
    : >> "$file"
  fi
}

#f_strstr() {  # strstr echoes nothing if s2 does not occur in s1
#  [[ -n "$2" && -z "${1/*$2*}" ]] && return 0  # Found
#  return 1
#}

f_svdrpsend_msgt() {  # Requires patched VDR
  mapfile -t < <("$SVDRPSEND" MSGT "$*")    # Check if VDR knows the command
  # 220 vdr01 SVDRP VideoDiskRecorder 2.6.1; Thu Oct 27 15:30:24 2022; UTF-8
  # 500 Command unrecognized: "MSGT"
  # 221 vdr01 closing connection
  if [[ "${MAPFILE[1]}" == "500"* ]] ; then  # MSGT not available
    : "${1#@}" ; : "${_#%}"                  # Remove '%' or '@'
    "$SVDRPSEND" MESG "${_} ${*:2}"
  fi
}

  # Sends a message to the VDR (Video Disk Recorder) system via D-Bus.
  #
  # Parameters:
  #   $1 - The message to be sent. If the message starts with '%', it is treated as a warning.
  #        If it starts with '@', it is treated as an error. Otherwise, it defaults to an info message.
  #   $2 - (Optional) The type of message (e.g., info, warning, error). Defaults to 'info' if not provided.
  #
  # The function uses the dbus-send command to dispatch the message to the VDR system, modifying the
  # message type based on the prefix of the message if necessary.

f_dbus_send_message() {
  local message="$1" type="${2:-info}"
  if [[ "${message[0]}" == '%' ]] ; then
    message="${message:1}"  # Remove %
    type='warning'
  elif [[ "${message[0]}" == '@' ]] ; then
    message="${message:1}"  # Remove @
    type='error'
  fi

  #if ! dbus-send --system --type=method_call --dest=de.tvdr.vdr --print-reply \
  #  /Skin de.tvdr.vdr.skin.SendMessage string:"$message" string:"$type" ; then
  #  f_svdrpsend_msgt "$1"
  #fi

  if ! vdr-dbus-send /Skin skin.SendMessage string:"$message" string:"$type" ; then
    f_svdrpsend_msgt "$1"
  fi
}

f_logger '<START>'
