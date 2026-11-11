#!/usr/bin/env bash

# rec_genindex.sh
#
# Script to create index files for a recording folder. If no parameter is passed
# the video directory is scanned. The script can also be run as a cron job.
# Author: MegaV0lt @ VDR-Portal

# Variables
LOG_FILE="/var/log/rec_genindex.log"  # Log file
VDR_USER='vdr'  # User under which vdr runs

# shellcheck disable=SC1090
source /_config/bin/yavdr_funcs.sh &>/dev/null

# Check if a directory was passed as parameter
if [[ -n "$1" ]] ; then
    if [[ ! -d "$1" ]] ; then
        f_log "Error: '$1' is not a directory"
        exit 1
    fi
    # Create index file (in background so script doesn't block)
    f_log "Creating index file for recording '$1'"
    f_detach ionice -n 3 vdr --genindex "$1"
else  # No parameter passed
    # Scan video directory (/video)
    if [[ -d "$VIDEO" ]] ; then  # From VDR configuration
        f_log "No directory passed, scanning '$VIDEO'"
        # Find VDR recordings (*.rec)
        mapfile -d '' -t RECORDINGS < <(find "$VIDEO"/ -maxdepth 4 -type d -name '*.rec' -print0 2>/dev/null)
        if [[ ${#RECORDINGS[@]} -eq 0 ]] ; then
            f_log "Error: No recordings found in directory '$VIDEO'"
            exit 1
        else
            f_log "Found recordings: ${#RECORDINGS[@]}"
        fi
        # Create index file if no index exists and *.ts is larger than 0 bytes
        for rec in "${RECORDINGS[@]}" ; do
            f_log "Checking recording '$rec'"
            # Skip PES recordings as they don't contain *.ts files
            if [[ -f "${rec}/001.vdr" ]] ; then
                f_log "  Skipping PES recording"
                continue
            fi
            if [[ ! -f "${rec}/index" ]] ; then
                ((++no_index))  # Number of recordings without index file
                # Check if *.ts files exist and are larger than 0 bytes
                if  [[ ! -s "${rec}"/00001.ts ]] ; then
                    ((++no_ts))  # Number of recordings without *.ts files
                    f_log "  Error: Recording has no *.ts file(s) or is empty"
                    continue
                fi
                f_log "  Creating index file"
                ionice -n 3 vdr --genindex "$rec" || \
                    f_log "  Error: 'vdr --genindex' could not create index file"
                # If index file was created, check if owner is correct
                if [[ -e "${rec}/index" ]] ; then
                    ((++index_created))  # Number of created index files
                    if [[ "$USER" != "$VDR_USER" ]] ; then
                        chown "${VDR_USER}:${VDR_USER}" "${rec}/index" || \
                            f_log "  Error: Could not set owner of index file to '$VDR_USER'"
                    fi
                else
                    ((++index_fail))  # Number of failed index file creations
                    f_log "  Error: Index file could not be created"
                fi
            fi
        done
    else
        f_log "Error: No directory passed and VIDEO is not set"
        exit 1
    fi
fi

# Print statistics
f_log "Statistics:"
f_log "  Found recordings: ${#RECORDINGS[@]}"
f_log "  Recordings without index file: ${no_index:-0}"
f_log "  Recordings without *.ts files: ${no_ts:-0}"
f_log "  Created index files: ${index_created:-0}"
f_log "  Errors creating index files: ${index_fail:-0}"

# Rotate log if too large
f_rotate_log "$LOG_FILE"

exit
