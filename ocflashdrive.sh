#!/bin/bash
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt
# This script is intended to create an OpenCore USB-installer on Linux.

# This function clears the screen and checks if the user is root. If not, it will execute the script with sudo.
welcome(){
    clear
    printf "Welcome to the OpenCore USB-installer script.\n\n"
    [[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
    set -e
}

# This function gets the USB drive selected by the user.
getthedrive(){
    clear
    printf "Please select the USB drive to use:\n\n"
    readarray -t lines < <((lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb"))
    select choice in "${lines[@]}"; do
        [[ -n "$choice" ]] || { printf ">>> Invalid Selection!\n" >&2; continue; }
        break
    done
    read -r drive _ <<<"$choice"
    if [[ -z "$choice" ]]; then
        printf "Please insert the USB Drive and try again.\n"
        exit 1
    fi
}

# This function installs the necessary dependencies for the script to run.
dependencies(){
    clear
    printf "Installing dependencies...\n\n"
    sleep 2s
    if [[ -f /etc/debian_version ]]; then
        apt install -y wget curl p7zip-full
    elif [[ -f /etc/fedora-release ]]; then
        dnf install -y wget curl p7zip-plugins
    elif [[ -f /etc/arch-release ]]; then
        pacman -Sy --noconfirm --needed wget curl p7zip
    elif [[ -f /etc/alpine-release ]]; then
        apk add wget curl p7zip
    elif [[ -f /etc/gentoo-release ]]; then
       emerge --nospinner --oneshot --noreplace  wget curl p7zip
    else
        printf "Your distro is not supported!\n"
        exit 1
    fi
}

# This function formats the USB drive.
formater(){
    clear
    printf "Formatting the USB drive...\n\n"
    umount "$drive"* || :
    sleep 2s
    wipefs -af "$drive"
    sgdisk "$drive" --new=0:0:+300MiB -t 0:ef00 && partprobe
    sgdisk "$drive" --new=0:0: -t 0:af00 && partprobe
    sleep 2s
}

# This function prompts the user if they want to continue with the formatting and installation of dependencies.
formating(){
    while true; do
        read -r -p "$(printf %s "Drive ""$drive"" will be erased, wget, curl, and p7zip will be installed. Do you wish to continue (y/n)? ")" yn
        case $yn in
            [Yy]*)
                dependencies "$@"; formater "$@"
                break
                ;;
            [Nn]*) 
                printf "Exiting the script...\n"
                exit 
                ;;
            *) 
                printf "Please answer yes or no.\n" 
                ;;
        esac
    done
}

# This function extracts the macOS recovery image from the downloaded DMG file.
extractor() {
    printf "Extracting macOS recovery image...\n"
    FILE=(com.apple.recovery.boot/*.dmg)
    if [ -n "$FILE" ]; then
        7z e -tdmg "${FILE[*]}" -ocom.apple.recovery.boot/ -- *.hfs
    else
        printf "Please download the macOS Recovery with macrecovery!\n"
        exit 1
    fi
}

# Burn the macOS recovery image to the target drive
burning(){
    clear
    myhfs=$(ls com.apple.recovery.boot/*.hfs)
    printf "Burning the macOS recovery image to $drive...\n"
    dd bs=8M if="$myhfs" of="$drive"2 status=progress oflag=sync
    rm -rf com.apple.recovery.boot/*.hfs
    umount "$drive"?* || :
    sleep 3s
    printf "The macOS recovery image has been burned to $drive!\n"
}

# Install OpenCore to the target drive
InstallOC(){
    clear    
    printf "Installing OpenCore to $drive...\n"
    MOUNTPOINT="/mnt"
    if [ "$(ls -A ${MOUNTPOINT})" ]; then    
        NEWMOUNTPOINT=""
        while [ -z $NEWMOUNTPOINT ]; do   
            read -r -p "$(printf %s "The /mnt folder is not empty! Please type a folder name to be created in /mnt/ : ")" NNEWMOUNTPOINT
                if     [ -z $NNEWMOUNTPOINT ]; then 
                        printf "Please choose a name for the folder to be created (without / or path eg. 'usb')! \n"                   
                else
                        MOUNTFOLDER="${MOUNTPOINT}/${NNEWMOUNTPOINT}" 
                        printf "Creating new mountpoint if it does not exist: ${MOUNTFOLDER}\n"
                        mkdir -p ${MOUNTFOLDER}                 
                        NEWMOUNTPOINT="${NNEWMOUNTPOINT}"
                        MOUNTPOINT="${MOUNTFOLDER}"                    
                fi
        done
    fi
    mkfs.fat -F32 -n OPENCORE "$drive"1
    mount -t vfat "$drive"1 ${MOUNTPOINT} -o rw,umask=000; sleep 3s
    cp -r ../../X64/EFI/ ${MOUNTPOINT}
    cp -r ../../Docs/Sample.plist ${MOUNTPOINT}/EFI/OC/
    printf "OpenCore has been installed to $drive! Please open ${MOUNTPOINT} and edit OC for your machine!!\n"
}

# Main function that runs all the sub-functions
main() {
    welcome "$@"
    getthedrive "$@"
    formating "$@"
    extractor "$@"
    burning "$@"
    InstallOC "$@"
}

# Run the main function with all the arguments passed to the script
main "$@"
