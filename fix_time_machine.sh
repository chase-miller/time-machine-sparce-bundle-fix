#!/bin/sh

# Disclaimer: While this works and is functional, I'm pretty terrible at shell scripting as I come from a Java/C# background. 
# Feel free to make any recommendations for this to be more consistent and shell-scripty-like.

# This is a modified version of http://pastebin.com/iw5nYFb0 - credit goes to anon.
# Based off a guide written by Garth Gillespie at http://www.garth.org/archives/2011,08,27,169,fix-time-machine-sparsebundle-nas-based-backup-errors.html

usage ()
{
  echo "usage: $0 PATH_TO_BUNDLE"
  exit
}

# a function to extract the dev disk from the hdiutil output
extract_dev_disk ()
{
	HDIUTIL_OUTPUT="$1"
	
	# split the hdiutil output by spaces (" ") into an array.
	DISKS_ARRAY=(${HDIUTIL_OUTPUT//" "/ })
	for ((i = 0 ; i < ${#DISKS_ARRAY[@]}; i++));
	do
		# The dev disk we're looking for should have an Apple_HFS label
	    if [ ${DISKS_ARRAY[$i]} = "Apple_HFS" ]
			then
				# The actual dev disk string should be just before the Apple_HFS element in the array
				DEV_DISK=${DISKS_ARRAY[$(($i-1))]}
		fi
	done

	echo "$DEV_DISK"
}

[ -e "$1" ] || usage

BUNDLE=$1

set -e

echo "\n"
date
echo 'chflags...'
chflags -R nouchg "$BUNDLE/"

echo "\n"
date
echo 'hdutil...'
DISKS_STRING=`hdiutil attach -nomount -noverify -noautofsck "$BUNDLE/"`
echo hdiutil output is $DISKS_STRING

echo "\n"
date
HFS_DISK=$(extract_dev_disk "$DISKS_STRING")
echo "identified HFS(X) volume as $HFS_DISK"

echo "\n"
date
echo 'fsck...'
fsck_hfs -drfy $HFS_DISK
# this was to wait for the log to finish before we ran fsck explicitly, as above
# grep -q 'was repaired successfully|could not be repaired' <(tail -f -n 0 /var/log/fsck_hfs.log)

echo "\n"
date
echo 'hdiutil detach...'
hdiutil detach $HFS_DISK

# make a backup of the original plist
echo "\n"
date
echo 'backing up original plist...'
cp "$BUNDLE/com.apple.TimeMachine.MachineID.plist" "$BUNDLE/com.apple.TimeMachine.MachineID.plist.bak"

echo "\n"
date
echo 'fixing plist...'
# change VerificationState to zero
plutil -replace VerificationState -integer 0 com.apple.TimeMachine.MachineID.plist
# remove RecoveryBackupDeclinedDate and write to a temp file
plutil -remove RecoveryBackupDeclinedDate com.apple.TimeMachine.MachineID.plist

echo "\n"
date
echo 'done!'
echo 'eject the disk from your desktop if necessary, then rerun Time Machine'

# this command will tell you who's using the disk, if ejecting is a problem:
# sudo lsof -xf +d /Volumes/disk<?> # or possibly just $BUNDLE