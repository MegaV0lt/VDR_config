#!/usr/bin/env bash
#
# From VDR's INSTALL file:
# The program will be called with two or three (in case of "editing" and "edited")
# string parameters. The first parameter is one of
#
#   before      if this is *before* a recording starts
#   started     if this is after a recording has *started*
#   after       if this is *after* a recording has finished
#   editing     if this is before *editing* a recording
#   edited      if this is after a recording has been *edited*
#   deleted     if this is after a recording has been *deleted*
#
# and the second parameter contains the full name of the recording's
# directory (which may not yet exists at that moment in the "before" case).
# In the "editing" and "edited" case it will be the name of the edited version
# (second parameter) and the name of the source version (third parameter).
# In the "deleted" case the extension of the directory name is ".del"
# instead of ".rec".
#
# Within this program you can do anything you would like to do before and/or
# after a recording or after an editing process. However, the program must return
# as soon as possible, because otherwise it will block further execution of VDR.
# Be especially careful to make sure the program returns before the watchdog
# timeout you may have set up with the '-w' option! If the operation you want to
# perform will take longer, you will have to run it as a background job.
#
# Example:
# R60copy_epgimage <command> <path to .rec>
#
# R60copy_epgimage after /video0/hitec/Doku/%Die_stille_Revolution_der_Mechatronik/2004-04-23.15\:25.50.99.rec
# $1 <command>  after
# $2 <path to .rec> /video0/hitec/Doku/%Die_stille_Revolution_der_Mechatronik/2004-04-23.15\:25.50.99.rec
#
# VERSION=250516

# Epg definitions
EPGIMAGESPATH='/var/cache/vdr/epgimages'
EPGIMAGESFORMAT='jpg'

# Eventid for recording
f_geteventid() {
	for file in "${src}/info"*; do
		EVENTID=$(grep -Po "(?<=^E\ )(\d+)(?=\ )" "$file")
		[[ -n "$EVENTID" ]] && return 0
	done
	return 1
}

f_copyepgimages() {
    # This function takes 3 arguments:
    src="$1"            # $1 directory that contains the info file for the recording
    target="$2"         # $2 destination for epgimages
    epgimages_dir="$3"  # $3 directory with epgimages

    if [[ -z "$src" || -z "$target" || -z "$epgimages_dir" ]]; then
        echo "f_copyepgimages: got an invalid argument" && exit 0
    fi

    f_geteventid || return 0

    shopt -s nullglob
    for file in "${epgimages_dir}/${EVENTID}"_*."${EPGIMAGESFORMAT}"; do
        cp "$file" "${target}/"
    done
    shopt -u nullglob
}

case $1 in
	before)
		# do here whatever you would like to do right BEFORE the recording $2 STARTS
		;;
	started)
		# do here whatever you would like to do right AFTER the recording $2 STARTED
		f_copyepgimages "$2" "$2" "$EPGIMAGESPATH"
		;;
	after)
		# do here whatever you would like to do right AFTER the recording $2 ENDED
		#f_copyepgimages $EPGIMAGESPATH
		;;
	edited)
		# do here whatever you would like to do right AFTER the recording $3 has been EDITED (path is $2)
		f_copyepgimages "$3" "$2" "$3"
		#[ -f "${3}/info.epg2vdr" ] && cp "${3}/info.epg2vdr" "${2}/"
		;;
	*)
		echo "Script needs two parameters. See example inside the script."
		exit 0
		;;
esac
