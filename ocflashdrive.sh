#!/bin/bash
# Autor: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt
# This script is inteded to create an opencore usb-installer on linux

welcome(){
clear
	cat << "EOF"
################################
#    WELCOME TO OCFLASHDRIVE   #
################################

Please enter your password!

EOF

[[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
set -e
}

ImportantTools(){
    clear
	cat << "EOF"
################################
#    INSTALLING DEPENDENCIES   #
################################

Installing wget curl p7zip!

EOF
    sleep 2s
    if [[ -f /etc/debian_version ]]; then
        apt install -y wget curl p7zip-full
        elif [[ -f /etc/fedora-release ]]; then
        dnf install -y wget curl p7zip-plugins
        elif [[ -f /etc/arch-release ]]; then
        pacman -Sy --noconfirm --needed wget curl p7zip
        elif [[ -f /etc/alpine-release ]]; then
        apk add wget curl p7zip sgdisk sgdisk
    else
        printf "Your distro is not supported!\n"
        exit 1
    fi
}

partformat(){
    clear
	cat << "EOF"
###############################
#    PARTITIONING THE DRIVE   #
###############################

Formating and partitioning the drive with wipefs and sgdisk!

EOF
    umount "$drive"* || :
    sleep 2s
    wipefs -af "$drive"
    sgdisk "$drive" --new=0:0:+300MiB -t 0:ef00 && partprobe
    sgdisk "$drive" --new=0:0: -t 0:af00 && partprobe
    sleep 2s
}

formating(){
while true; do
read -r -p "$(printf %s "Drive ""$drive"" will be erased, wget, curl and p7zip will be installed do you wish to continue (y/n)? ")" yn
	case $yn in
		[Yy]*)
			ImportantTools "$@"; partformat "$@"
			break
			;;
		[Nn]*) exit ;;
		*) printf "Please answer yes or no.\n" ;;
	esac
done
}

extractor(){
    clear
	cat << "EOF"
#############################
#    EXTRACTING DMG FILE    #
#############################

Extracting BaseSystem.dmg with p7zip!

EOF
    
    FILE=(*.dmg)
    if [[ -f "${FILE[*]}" ]]; then
        rm -rf -- *.hfs
        7z e -tdmg -- *.dmg -- *.hfs
    else
        printf "Please Download the macOS Recovery with macrecovery!\n"
        exit 1
    fi
}

burning(){
    clear
	cat << "EOF"
####################################
#    COPYING IMAGE TO THE DRIVE    #
####################################

Copying image to the flash drive with dd command!

EOF
    myhfs=$(ls *.hfs)
    dd bs=8M if="$myhfs" of="$drive"2 status=progress oflag=sync
    rm -rf -- *.hfs
    umount "$drive"?* || :
    sleep 3s
}

InstallOC(){
    clear
	cat << "EOF"
#################################
#    INSTALLING OPENCORE EFI    #
#################################
EOF
    mkfs.fat -F32 -n OPENCORE "$drive"1
    mount -t vfat "$drive"1 /mnt/ -o rw,umask=000; sleep 3s
    cp -r ../../X64/EFI/ /mnt/
    cp -r ../../Docs/Sample.plist /mnt/EFI/OC/
    printf "Installation finished, open /mnt and edit oc for your machine!!\n"
}

getthedrive(){
clear
cat << "EOF"
################################################
#  WARNING: THE SELECTED DRIVE WILL BE ERASED  #
################################################

Please select the usb-drive!

EOF
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

main() {
	welcome "$@"
	getthedrive "$@"
	formating "$@"
    extractor "$@"
	burning "$@"
    InstallOC "$@"
}

main "$@"
