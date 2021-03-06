#!/bin/sh

_mtd_name="config"
CONFIG_DEV_SIZE="0"
CONFIG_BLOCK_DEV="/dev/mtdblock5"
CONFIG_MNT="/config-mfg"
CONFIG_TMP="/tmp/configtmp"
CONFIG_IMG="/tmp/config-squash.img"

find_mtd_by_name()
{
	echo "Looking for MTD partition named $1"
	CONFIG_MTD=$(find /sys/class/mtd -follow -maxdepth 2 -path '/sys/class/mtd/mtd[[:digit:]+]/name' | xargs grep ^$1$)
	if [[ -n "$CONFIG_MTD" ]]; then
		#echo "CONFIG_MTD: $CONFIG_MTD"
		CONFIG_MTD=${CONFIG_MTD%%/name*}
		if [[ -n "$CONFIG_MTD" ]]; then
			#echo "CONFIG_MTD: $CONFIG_MTD"
			CONFIG_MTD=${CONFIG_MTD##*/}
			echo "CONFIG_MTD: $CONFIG_MTD"
		fi
	fi
}

find_mtd_by_name $_mtd_name
CONFIG_DEV=/dev/$CONFIG_MTD

# BEFORE WE DO ANYTHING, $CONFIG_DEV should be writable; i.e. not read-only.
# get CONFIG_DEV writable status
res="`mtdinfo $CONFIG_DEV | grep writable | grep -o false`"
if [ "$res" == "false" ]; then
    echo "error: $CONFIG_DEV must be writable -- it is not!"
    exit 1
fi

# get CONFIG_DEV size
res="`cat /sys/class/mtd/$CONFIG_MTD/size`"
if [ "$?" == "0" ]; then
    CONFIG_DEV_SIZE="$res"
    echo "size of $CONFIG_DEV is $CONFIG_DEV_SIZE bytes"
else
    echo "error: could not get size of $CONFIG_DEV"
    exit 1
fi


#
# function: is_squash_mount
# desc: verifies if the specified path is a squash mount
#
is_squash_mount() {
    
    local _mount_path="$1"
    
    if [ ! -d "$_mount_path" ]; then
        return 0
    fi
    
    res="`mount | grep $_mount_path | grep -o squashfs`"
    if [ "$res" == "squashfs" ]; then
        return 1
    else
        return 0
    fi
}

#
# function: unsquash
# desc: unsquashes a file system directly from a mtd device
#
copy_squashfs() {    
    local _squashfs_mount="$1"
    local _squashfs_tmp="$2"
            
    if [ ! -d "$_squashfs_tmp" ]; then
        mkdir $_squashfs_tmp
    fi

    cp -R $_squashfs_mount/* $_squashfs_tmp
    return $?
}

#
# function: cleanup
# desc: removes all files created by `--start`
#
cleanup() {
    rm $CONFIG_IMG
    rm -rf $CONFIG_TMP
}

#
# function: print_usage
# desc: exactly what it says... print the usage
#
print_usage() {
    echo "$0:"
    echo "--start   Setup for making changes to $CONFIG_MNT SquashFS"
    echo "          (make changes in $CONFIG_TMP)"
    echo "--commit  Generates SquashFS image from $CONFIG_TMP and"
    echo "--clean   Removes any files generated by this script"
    echo "--help    Prints this help message"
    echo ""
    echo "example:"
    echo "  $ $0 --start"
    echo "  $ cp /src/passwd $CONFIG_TMP/etc/passwd"
    echo "  $ cp /src/file2 $CONFIG_TMP/etc/file2"
    echo "  $ cp /src/file3 $CONFIG_TMP/etc/file3"
    echo "  $ $0 --commit"
}

#
# function: print_usage
# desc: run the start command to begin an update
#
cmd_start() {
    # make sure we are working with a squash mount
    is_squash_mount $CONFIG_MNT
    if [ "$?" -eq "1" ]; then
        # Copy the squashfs contents
        copy_squashfs $CONFIG_MNT $CONFIG_TMP
    else
        # Just create the temporary directory
        mkdir $CONFIG_TMP
    fi
}

#
# function: cmd_commit
# desc: commits config changes as SquashFS image
#
cmd_commit() {

    # Make sure the image doesn't exist
    rm $CONFIG_IMG 2>/dev/null

    # Create the SquashFS image
    echo "Generating new SquashFS image"
    mksquashfs $CONFIG_TMP $CONFIG_IMG >/dev/null
    if [ "$?" -ne "0" ]; then
        echo "error: could not generate $CONFIG_IMG"
        exit 1
    fi
  
    # Unmount the SquashFS
    umount $CONFIG_MNT
        
    # make sure $CONFIG_MNT is not mounted
    is_squash_mount $CONFIG_MNT
    if [ "$?" -eq "1" ]; then
        echo "error: could not unmount $CONFIG_MNT"
        exit 1
    fi
    
    # Erase the current SquashFS
    flash_erase $CONFIG_DEV 0 0
    if [ "$?" -ne "0" ]; then
        echo "error: could not erase $CONFIG_DEV"
        exit 1
    fi
  
    # Write the SquashFS image to the mtd config device
    echo "Writing new SquashFS image"
    dd if=$CONFIG_IMG of=$CONFIG_DEV 2>/dev/null
    if [ "$?" -ne "0" ]; then
        echo "error: could not dd $CONFIG_IMG to $CONFIG_DEV"
        exit 1
    fi
  
    # Make sure we are all synced up
    sync
    
    # Remount the SquashFS config-mfg
    mount -t squashfs $CONFIG_BLOCK_DEV $CONFIG_MNT
    if [ "$?" -ne "0" ]; then
        echo "could not mount $CONFIG_MNT"
        exit 1
    fi
  
    # Clean up after committing
    # cleanup
}

# If no arguments, print usage and exit
if [ "$#" -eq "0" ]; then
    print_usage $0
    exit 0
fi

# Run getopt
ARGS=`getopt -l "start,commit,help,clean" -n "$0" -- "$@"`

# Bad args
if [ "$?" -ne "0" ]; then
    exit 1
fi

case "$1" in
  --start)
    cmd_start
    echo "make your changes in $CONFIG_TMP"
    ;;
    
  --commit)
    cmd_commit
    ;;
  
  --clean)
    cleanup
    ;;
    
  --help)
    print_usage $0
    ;;
    
  *)
    print_usage $0
    ;;
esac


