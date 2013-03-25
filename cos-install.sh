#!/bin/sh

set -u
set -e

usage(){
    echo "Usage: $0 [IMAGE] [STATE] [ROOT]"
    echo
    echo "PARAMETERS:"
    echo "IMAGE:   The Chromium OS image file."
    echo "STATE:   The target partition for the stateful partition."
    echo "ROOT:    The target partition for the root partition."
    exit 1
}

copy_partition(){
    target_dev=$1
    part_label=$2

    # Get the "start at" of the source partition.
    part_start=$(parted -ms $image_file unit B print | grep "$part_label" | cut -d ":" -f 2)
    # Test if there is a size.
    if [ -z $part_start ]; then
        echo "Invalid image file $image_file. Did you unzip the file after downloading?"
        exit 1
    fi

    part_start="${part_start%?}"
    echo "Partition $part_label starts from byte $part_start"

    # Mount the source partition.
    source_loop=$(sudo losetup -o $part_start -f --show $image_file)
    echo "Created loop device $source_loop for $part_label."

    echo "Mounting the source partition."
    source_mount=$(mktemp -d)
    sudo mount $source_loop $source_mount

    # Mount the target partition.
    echo "Mounting the target partition."
    target_mount=$(mktemp -d)
    sudo mount $target_dev $target_mount

    # Erasing target partition if necessary.
    echo
    echo "Do you want to erase $target_dev ?"
    echo "WARNING: Backup your data, otherwise the data will be erased!"
    read -p "If you do, enter \"erase\". Otherwise, enter something else: " yn

    if [ $yn = "erase" ]; then
        echo "Erasing $target_dev ..."
        sudo rm -rf $target_mount/*
    else
        echo "Skipped erasing ..."
    fi

    # Copy files.
    echo "Copying files ..."
    sudo cp -a $source_mount/* $target_mount

    # Clean up.
    echo "Cleaning up ..."
    sudo umount $target_mount
    sudo umount $source_mount
    sudo losetup -d $source_loop
}

# Print usage if there are not enough parameters.
if [ $# -lt 3 ] ; then
    echo "Not enough parameters."
    usage
fi

image_file=$1
state_target=$2
root_target=$3

# Check whether file exists.

if [ ! -f $image_file ]; then
    echo "Image file $image_file does not exist!"
    usage
fi

if [ ! -b $state_target ]; then
    echo "Device $state_target does not exist!"
    usage
fi

if [ ! -b $root_target ]; then
    echo "Device $root_target does not exist!"
    usage
fi

copy_partition $2 'STATE'
echo "----------------------------------------"
copy_partition $3 'ROOT-A'
