#!/bin/sh
 
# modified version of http://pastebin.com/iw5nYFb0
# http://www.garth.org/archives/2011,08,27,169,fix-time-machine-sparsebundle-nas-based-backup-errors.html
 
usage ()
{
  echo "usage: $0 PATH_TO_BUNDLE"
  exit
}
 
[ -e "$1" ] || usage
 
BUNDLE=$1
 
set -e
 
date
echo 'chflags...'
chflags -R nouchg "$BUNDLE/"
 
# run hdituil and from its output extract the correct /dev/...disk.
date
echo 'hdutil...'
DISKS_STRING=`hdiutil attach -nomount -noverify -noautofsck "$BUNDLE/"`
echo $DISKS_STRING
# split the output by whitespace
DISKS_ARRAY=(${DISKS_STRING//" "/ })
for ((i = 0 ; i < ${#DISKS_ARRAY[@]}; i++));
do
    if [ ${DISKS_ARRAY[$i]} = "Apple_HFS" ]
                then
                        # the correct path should be just before the Apple_HFS element in the array
                        Previous_Index=$(($i-1))
                        HFS_DISK=${DISKS_ARRAY[$Previous_Index]}
        fi
done
echo "identified HFS(X) volume as $HFS_DISK"
 
date
echo 'fsck...'
fsck_hfs -drfy $HFS_DISK
# this was to wait for the log to finish before we ran fsck explicitly, as above
# grep -q 'was repaired successfully|could not be repaired' <(tail -f -n 0 /var/log/fsck_hfs.log)
 
echo 'hdiutil detach...'
hdiutil detach $HFS_DISK
 
# make a backup of the original plist
echo 'backing up original plist...'
cp "$BUNDLE/com.apple.TimeMachine.MachineID.plist" "$BUNDLE/com.apple.TimeMachine.MachineID.plist.bak"
 
date
echo 'fixing plist...'
cat "$BUNDLE/com.apple.TimeMachine.MachineID.plist" |
  # change VerificationState to zero
  awk 'BEGIN { RS = "" } { gsub(/VerificationState<\/key>[ \t\n]*<integer>2/, "VerificationState</key>\n\t<integer>0"); print }' |
  # remove RecoveryBackupDeclinedDate and write to a temp file
  awk 'BEGIN { RS = "" } { gsub(/[ \t\n]*<key>RecoveryBackupDeclinedDate<\/key>[ \t\n]*<date>[^<]+<\/date>/, ""); print }' > /tmp/fixed-plist.plist
 
# replace the original (don't use mv; it throws weird errors when moving across this disks)
cp /tmp/fixed-plist.plist "$BUNDLE/com.apple.TimeMachine.MachineID.plist"
rm /tmp/fixed-plist.plist
 
date
echo 'done!'
echo 'eject the disk from your desktop if necessary, then rerun Time Machine'
 
# this command will tell you who's using the disk, if ejecting is a problem:
# sudo lsof -xf +d /Volumes/disk<?> # or possibly just $BUNDLE