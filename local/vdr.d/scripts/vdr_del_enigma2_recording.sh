#!/usr/bin/env bash

# vdr_del_enigma2_recording.sh
#
# Script to move Enigma2 recordings to trashcan when a VDR recording is deleted
# Called by VDR recording script with parameters:
# $1 = path to the recording directory

# VERSION=20260127

source /_config/bin/yavdr_funcs.sh &>/dev/null

if ! declare -F f_logger &>/dev/null ; then
  f_logger() { logger -t yaVDR "vdr_del_enigma2_recording.sh: $*" ;}
fi

# Read actual path if .linked_from_enigma2 file exists (../../../movie/Filmname.ts)
if [[ -e "${1}/.linked_from_enigma2" ]] ; then
    ENIGMA_LINK="$(<"${1}/.linked_from_enigma2")"
fi
TRASHCAN_DIR="${ENIGMA_LINK%/movie/*}/movie/trashcan"

if [[ -d "$TRASHCAN_DIR" ]] ; then
    # Check if the path after /movie conains a slash, indicating a subdirectory
    if [[ "$ENIGMA_LINK" == *"/movie/"*"/"* ]]; then
        # Move the parent directory to trashcan instead
        if [[ -d "$TRASHCAN_DIR" ]] ; then
        mv "${ENIGMA_LINK%/*}" "$TRASHCAN_DIR" || {
            f_logger "Error: Failed to move ${ENIGMA_LINK%/*} to $TRASHCAN_DIR"
        }
        f_logger "Moved Enigma2 recording directory ${ENIGMA_LINK%/*} to trashcan: ${TRASHCAN_DIR}"
        else
        f_logger "Error: Trashcan directory $TRASHCAN_DIR does not exist. Cannot move Enigma2 recording directory ${ENIGMA_LINK%/*}."
        fi
        # exit
    else
        # Move .ts and associated files to trashcan directory in /media/hdd/movie/trashcan
        REC_NAME="${ENIGMA_LINK%.ts}"
        mv "${REC_NAME}.ts" "$TRASHCAN_DIR"  # Move main .ts file to trashcan
        # Check for part files (Name_001.ts, Name_002.ts, ...)
        for ((i=1; i<1000; i++)); do
            if [[ -f "${REC_NAME}_$(printf '%03d' $i).ts" ]] ; then
                mv "${REC_NAME}_$(printf '%03d' $i).ts" "${TRASHCAN_DIR}" || {
                f_logger "Error: Failed to move ${REC_NAME}_$(printf '%03d' $i).ts to $TRASHCAN_DIR"
                }
                f_logger "Moved ${REC_NAME}_$(printf '%03d' $i).ts to trashcan: ${TRASHCAN_DIR}"
            else
                break  # No more part files found
            fi
        done
        # Move associated files to trashcan
        for ext in .meta .eit .ts.ap .cuts .sc ; do
            mv "${REC_NAME}${ext}" "$TRASHCAN_DIR"
        done
        f_logger "Moved Enigma2 recording $ENIGMA_LINK to $TRASHCAN_DIR"
    fi
else
    f_logger "Error: Trashcan directory $TRASHCAN_DIR does not exist. Cannot move Enigma2 recording $ENIGMA_LINK."
fi  # -d

# End of script
