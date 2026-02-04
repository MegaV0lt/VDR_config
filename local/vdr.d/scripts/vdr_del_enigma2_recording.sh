#!/usr/bin/env bash

# vdr_del_enigma2_recording.sh
#
# Script to move Enigma2 recordings to trashcan when a VDR recording is deleted
# Called by VDR recording script with parameters:
# $1 = path to the recording directory

# VERSION=20260127

source /_config/bin/yavdr_funcs.sh &>/dev/null

# If f_logger is not defined, define it
if ! declare -F f_logger &>/dev/null ; then
  f_logger() { logger -t yaVDR "vdr_del_enigma2_recording.sh: $*" ;}
fi

# Read actual path if .linked_from_enigma2 file exists (../../../movie/Filmname.ts)
if [[ -e "${1}/.linked_from_enigma2" ]] ; then
    ENIGMA_LINK="$(<"${1}/.linked_from_enigma2")"
fi

# Check if trashcan directory exists, create if not ('/media/hdd/movie/trash' is the default in EMC)
TRASHCAN_DIR="${ENIGMA_LINK%/movie/*}/movie/trash"
if [[ ! -d "$TRASHCAN_DIR" ]] ; then
    mkdir --parents "$TRASHCAN_DIR" || {
        f_logger "Error: Failed to create trashcan directory $TRASHCAN_DIR"
        exit 1
    }
fi

# Check if the path after /movie conains a slash, indicating a subdirectory
#if [[ "$ENIGMA_LINK" == *"/movie/"*"/"* ]]; then
#    # Move the parent directory to trash instead
#    if [[ -d "$TRASHCAN_DIR" ]] ; then
#    mv "${ENIGMA_LINK%/*}" "$TRASHCAN_DIR" || {
#        f_logger "Error: Failed to move ${ENIGMA_LINK%/*} to $TRASHCAN_DIR"
#    }
#    f_logger "Moved Enigma2 recording directory ${ENIGMA_LINK%/*} to trash: ${TRASHCAN_DIR}"
#    else
#    f_logger "Error: Trash directory $TRASHCAN_DIR does not exist. Cannot move Enigma2 recording directory ${ENIGMA_LINK%/*}."
#    fi
#    # exit
#else
    # Move .ts and associated files to trash directory in /media/hdd/movie/trash
    REC_NAME="${ENIGMA_LINK%.ts}"
    for ext in .ts .meta .eit .ts.ap .cuts .sc ; do
        if [[ -f "${REC_NAME}${ext}" ]] ; then
            mv "${REC_NAME}${ext}" "$TRASHCAN_DIR" || {
                f_logger "Error: Failed to move ${REC_NAME}${ext} to $TRASHCAN_DIR"
                }
            f_logger "Moved ${REC_NAME}${ext} to trashcan: $TRASHCAN_DIR"
        fi
    done

    # Check for part files (Name_001.ts, Name_002.ts, ...)
    for ((i=1; i<1000; i++)); do
        REC_NAME_PART="${REC_NAME}_$(printf '%03d' $i).ts"
        if [[ -f "$REC_NAME_PART" ]] ; then
            mv "$REC_NAME_PART" "$TRASHCAN_DIR" || {
                f_logger "Error: Failed to move $REC_NAME_PART to $TRASHCAN_DIR"
                }
            f_logger "Moved $REC_NAME_PART to trashcan: $TRASHCAN_DIR"
        else
            break  # No more part files found
        fi
    done
    f_logger "Moved Enigma2 recording $ENIGMA_LINK to $TRASHCAN_DIR"
#fi

# End of script
