#!/usr/bin/env bash

#
# Add Video frame informations to vdr recordings made with vdr <= 2.6.4
#
# VERSION=240127-1502

### Functions
f_find_frameinfo() {
  read -r -a F_LINE < <(grep '^F ' "$INFO" 2>/dev/null)
  #echo "  > Found in 'info': ${F_LINE[*]}"
  [[ "${#F_LINE[*]}" -eq 2 ]] && { FPS="${F_LINE[1]}" ; return 0 ;}  # TS recording, but only framerate set
  [[ "${#F_LINE[*]}" -eq 6 ]] && return 2   # Frameinfos already set (VDR >= 2.6.5)
  [[ "${#F_LINE[*]}" -lt 2 ]] && return 1   # No Framerate. Propably an old PES recording
}

f_check_video() {
  WIDTH='' ; HEIGHT='' ; ASPECT_RATIO='' ; SCAN_TYPE='' ; FRAME_RATE=''
  local key='' result='' value=''
  local ts_file="${REC_DIR}/00001.ts"  # TODO: What if first file is too small?
            # Read only 100 packets after seeking to position 09:23: 09:23%+#100
  read -r -a result < <(ffprobe -v fatal -select_streams v:0 -read_intervals 9:23%+#100 \
            -show_entries stream=WIDTH,HEIGHT,display_ASPECT_RATIO,field_order,r_FRAME_RATE \
            -of default=nw=1:nk=0 "$ts_file")
  #echo "  > ffprobe result: ${result[*]}"
  for line in "${result[@]}" ; do
    key="${line%=*}" ; value="${line#*=}"
    case "$key" in
      'WIDTH')                WIDTH="$value" ;;
      'HEIGHT')               HEIGHT="$value" ;;
      'display_ASPECT_RATIO') ASPECT_RATIO="$value" ;;
      'field_order')          SCAN_TYPE=$(echo "$value" | sed -r 's/[bt][bt]/i/g; s/progressive/p/; /^[ip]$/!s/.*/-/') ;;
      'r_FRAME_RATE')         FRAME_RATE="$value" ;;
    esac
  done
  [[ -n "$WIDTH" && -n "$HEIGHT" && -n "$ASPECT_RATIO" && -n "$SCAN_TYPE" && -n "$FRAME_RATE" ]] &&
    return 0  # Everything found…
  return 1  # Error detecting values
}

f_insert_framedata() {
  # Order of parameters: Framerate, Width, Height, SCAN_TYPE, Aspectratio
  echo "  > Inserting: F $FPS $WIDTH $HEIGHT $SCAN_TYPE $ASPECT_RATIO"
  sed -i -e "s|^F .*|F $FPS $WIDTH $HEIGHT $SCAN_TYPE ${ASPECT_RATIO}|" "$INFO"
}

f_check_backup() {
  if [[ -e "${INFO}.bak" ]] ; then
    if [[ "${FORCE:=false}" == 'true' ]] ; then
      cp -pf "${INFO}.bak" "$INFO"
    else
      echo "  > Backup of 'info' found! Use '-f' to rescan. Skipping"
      return 1
    fi
  else
    cp -p "$INFO" "${INFO}.bak"
  fi
}

f_restore() {  # Restore original 'info' and delete backup
  if [[ -e "${INFO}.bak" ]] ; then
    echo "  > Restoring original 'info'"
    if cp -pf "${INFO}.bak" "$INFO" ; then
      rm "${INFO}.bak"
    fi
  else
    echo "  !> No backup found! Skipping"
  fi
}

f_help() {
  echo "$0 Usage:"
  echo -e "\t$0 -f  Force processing of already processed 'info'. Reuse of original 'info'!"
  echo -e "\t$0 -r  Restore backed up 'info' files"
  echo -e "\t$0 -v VIDEO_REC_DIR  Path to VDR's video REC_DIRectory (default: /video)"
  exit 0
}

### Start

while getopts ':frv:' opt ; do
  case "$opt" in
    f) FORCE='true' ;;
    r) RESTORE='true' ;;
    v) VIDEO="$OPTARG" ;;
    *) f_help ;;
  esac
done

if [[ ! -r "${VIDEO:=/video}" ]]; then
  echo "Video directory '${VIDEO}' not found or not readable - exiting"
  exit 1
fi

while IFS= read -r REC_DIR; do
  INFO="${REC_DIR}/info"
  ((cnt+=1))
  echo "=> (${cnt}) Checking ${REC_DIR}"
  if [[ "${RESTORE:=false}" == 'true' ]] ; then
    f_restore
  else
    if [[ -r "${INFO}.vdr" ]] ; then
      echo "  !> Skipping PES recording"
      continue
    fi
    if [[ ! -w "$INFO" ]] ; then
      echo "  !> 'info' file not found or is not writable! Skipping"
      continue
    fi

    f_check_backup || continue
    f_find_frameinfo || continue

    if f_check_video ; then
      echo "  > ffprobe got ${WIDTH}x${HEIGHT} @ ${FPS} scan_type: $SCAN_TYPE  ar: ${ASPECT_RATIO}"
      f_insert_framedata
    else
      echo "  !> ffprobe error!"
    fi
  fi  # if RESTORE
done < <(find "${VIDEO}/" -type d -name '*.rec')

# End
