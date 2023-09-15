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

# Get the USB drive selected by the user.
get_the_drive(){
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

# Extract the macOS recovery image from the downloaded DMG file.
extract_recovery_dmg() {
	recovery_dir=com.apple.recovery.boot
	recovery_file1="$recovery_dir/BaseSystem.dmg"
	recovery_file2="$recovery_dir/RecoveryImage.dmg"
	rm -rf "$recovery_dir"/*.hfs

	if [ -e "$recovery_file1" ]; then
		printf "  Extracting...\n %s $recovery_file1!"
		7z e -bso0 -bsp1 -tdmg "$recovery_file1" -aoa -o"$recovery_dir" -- *.hfs
	elif [ -e "$recovery_file2" ]; then
		printf "\n  Extracting...\n %s $recovery_file2!"
		7z e -bso0 -bsp1 -tdmg "$recovery_file2" -aoa -o"$recovery_dir" -- *.hfs
	else
		printf "Please download the macOS Recovery with macrecovery!\n"
		exit 1
	fi
}

# Install the necessary dependencies for the script to run.
install_dependencies(){
	clear
	printf "Installing dependencies...\n\n"
	sleep 2s
	if [[ -f /etc/debian_version ]]; then
		apt install -y wget curl p7zip-full dosfstools
	elif [[ -f /etc/fedora-release ]]; then
		dnf install -y wget curl p7zip-plugins dosfstools
	elif [[ -f /etc/arch-release ]]; then
		pacman -Sy --noconfirm --needed wget curl p7zip dosfstools
	elif [[ -f /etc/alpine-release ]]; then
		apk add wget curl p7zip dosfstools
	elif [[ -f /etc/gentoo-release ]]; then
		emerge --nospinner --oneshot --noreplace  wget curl p7zip dosfstools
	else
		printf "Your distro is not supported!\n"
		exit 1
	fi
}

# Format the USB drive.
format_drive(){
	clear
	printf "Formatting the USB drive...\n\n"
	umount "$drive"* || :
	sleep 2s
	wipefs -af "$drive"
	sgdisk "$drive" --new=0:0:+300MiB -t 0:ef00 && partprobe
	sgdisk "$drive" --new=0:0: -t 0:af00 && partprobe
	mkfs.fat -F 32 "$drive"1
	sleep 2s
}

# Prompt the user to start installation.
prepare_for_installation(){
	while true; do
		printf " The disk '%s' will be erased,\n and the following tools will be installed:\n wget, curl, p7zip, and dosfstools.\n Do you want to proceed? [y/n]: " "$drive"
		read -r yn
		case $yn in
			[Yy]*)
				extract_recovery_dmg "$@"
				install_dependencies "$@"
				format_drive "$@"
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

# Burn the macOS recovery image to the target drive
burning_drive(){
	clear
	myhfs=$(ls com.apple.recovery.boot/*.hfs)
	printf "Installing macOS recovery image...\n"
	dd bs=8M if="$myhfs" of="$drive"2 status=progress oflag=sync
	umount "$drive"?* || :
	sleep 3s
	printf "The macOS recovery image has been burned to the drive!\n"
}

# Install OpenCore to the target drive
Install_OC() {
	clear
	printf "Installing OpenCore to the drive...\n"
	mount_point="/mnt"
	new_mount_point="ocfd15364"

	# Check if the mount point directory is not empty
	if [ -n "$(ls -A "$mount_point")" ]; then
		# Create a new mount point if it's not empty
		mount_directory="${mount_point}/${new_mount_point}"
		mkdir -p "$mount_directory"
	fi

	# Mount the target drive
	mount -t vfat "$drive"1 "${mount_point}" -o rw,umask=000
	sleep 3s

	# Copy OpenCore EFI files
	cp -r ../../X64/EFI/ "${mount_point}"
	cp -r ../../Docs/Sample.plist "${mount_point}/EFI/OC/"
	printf " OpenCore has been installed to the drive!\n Please open '/mnt' and edit OC for your machine!!\n"
	ls -1 "${mount_point}/EFI/OC"
}

main() {
	welcome "$@"
	get_the_drive "$@"
	prepare_for_installation "$@"
	burning_drive "$@"
	Install_OC "$@"
}
main "$@"
