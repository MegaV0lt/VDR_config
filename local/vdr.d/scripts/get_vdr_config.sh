#!/usr/bin/env bash

# get_vdr_config.sh
# Werte aus 00-vdr.conf auslesen und in die vdr eintragen
#
# VERSION=230619

# Variablen
VDR_CONF='/etc/vdr/conf.d/00-vdr.conf'  # VDR Konfig
VDR_CFG='/etc/vdr.d/conf/vdr'           # Für Skripte

# Funktionen
f_parse_config(){
  # Usage: f_parse_config <file> [<default array name>]

  # If no default array name is given, it defaults to 'config'.
  # If there are [section] headers in file, following entries will be
  # put in array of that name.

  # Config arrays may exist already and will appended to or overwritten.
  # If preexisting array is not associative, function exits with error.
  # New arrays will be created as needed, and remain in the environment.
  [[ ! -f "$1" ]] && { echo "$1 is not a file." >&2 ; return 1 ;}
  local -n config_array="${2:-config}"
  declare -Ag "${!config_array}" || return 1
  local line key value section_regex entry_regex
  section_regex="^[[:blank:]]*\[([[:alpha:]_][[:alnum:]_-]*)\][[:blank:]]*(#.*)?$"
  #entry_regex="^[[:blank:]]*([[:alpha:]_][[:alnum:]_-]*)[[:blank:]]*=[[:blank:]]*('[^']+'|\"[^\"]+\"|[^#[:blank:]]+)[[:blank:]]*(#.*)*$"
  # Inkl. Leerzeichen als Trenner
  entry_regex="^[[:blank:]]*([[:alpha:]_-][[:alnum:]_-]*)[[:blank:]]*[\s=][[:blank:]]*('[^']+'|\"[^\"]+\"|[^#[:blank:]]+)[[:blank:]]*(#.*)*$"
  while read -r line ; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ $section_regex ]] && {
      local -n config_array="${BASH_REMATCH[1]}"
      declare -Ag "${!config_array}" || return 1
      continue
    }
    [[ "$line" =~ $entry_regex ]] && {
      key="${BASH_REMATCH[1]//-/_}"     # Replace all '-' with '_'
      value="${BASH_REMATCH[2]#[\'\"]}" # Strip quotes
      value="${value%[\'\"]}"
      config_array["$key"]="$value"
    }
  done < "$1"
}

# Start
[[ "$VDR_CONF" -nt "$VDR_CFG" ]] && { echo "$VDR_CONF newer than ${VDR_CFG}. Exit!" ; exit ;}

# f_parse_config <file> [<default array name>]
f_parse_config "$VDR_CONF" || { echo "Error parsing $VDR_CONF" ; exit 1 ;}

for key in "${!vdr[@]}" ; do  # vdr ist der Abschnitt in der conf ([vdr])
  #echo -e "Key: $key \t Value: ${vdr[$key]}"  # Debug
  case "$key" in  # '-' are replaced with '_'
    _l|__log)   LOG_LEVEL="${vdr[$key]}" ;;
    _v|__video) VIDEO="${vdr[$key]}" ;;
  esac
done

# Werte in die /etc/vdr/conf.d/vdr übertragen
COMMENT="# Wird mit Wert aus $VDR_CONF überschrieben!"
sed -i -e "s|LOG_LEVEL=.*|LOG_LEVEL=${LOG_LEVEL:-3}  ${COMMENT}|" \
       -e "s|VIDEO=.*|VIDEO=${VIDEO:-/video}  ${COMMENT}|" "$VDR_CFG"

### Ende
