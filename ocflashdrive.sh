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

# Search the system if the packages we need are already installed
install_apt_package() {
	local package_name="$1"
	if ! dpkg -l "$package_name" > /dev/null 2>&1; then
		apt update
		apt install -y "$package_name"
	else
		printf "Package '%s' is already installed (APT).\n" "$package_name"
	fi
}

install_dnf_package() {
	local package_name="$1"
	if ! rpm -q "$package_name" > /dev/null 2>&1; then
		dnf install -y "$package_name"
	else
		printf "Package '%s' is already installed (DNF).\n" "$package_name"
	fi
}

install_pacman_package() {
	local package_name="$1"
	if ! pacman -Q "$package_name" > /dev/null 2>&1; then
		pacman -Sy --noconfirm --needed "$package_name"
	else
		printf "Package '%s' is already installed (Pacman).\n" "$package_name"
	fi
}

install_apk_package() {
	local package_name="$1"
	if ! apk info "$package_name" > /dev/null 2>&1; then
		apk add "$package_name"
	else
		printf "Package '%s' is already installed (APK).\n" "$package_name"
	fi
}

install_emerge_package() {
	local package_name="$1"
	if ! emerge -pv "$package_name" | grep "install" > /dev/null 2>&1; then
		emerge --nospinner --oneshot --noreplace "$package_name"
	else
		printf "Package '%s' is already installed (Portage).\n" "$package_name"
	fi
}

install_missing_packages() {
	clear
	cat <<"EOF"
#############################
#  Installing Dependencies  #
#############################
EOF
debian_packages=("wget" "curl" "p7zip-full" "dosfstools")
fedora_packages=("wget" "curl" "p7zip-plugins" "dosfstools")
arch_packages=("wget" "curl" "p7zip" "dosfstools")
alpine_packages=("wget" "curl" "p7zip" "dosfstools")
gentoo_packages=("net-misc/wget" "net-misc/curl" "app-arch/p7zip" "sys-fs/dosfstools")

    # Check for the distribution type and call the appropriate function
    if [[ -f /etc/debian_version ]]; then
	    for package in "${debian_packages[@]}"; do
		    install_apt_package "$package"
	    done
    elif [[ -f /etc/fedora-release ]]; then
	    for package in "${fedora_packages[@]}"; do
		    install_dnf_package "$package"
	    done
    elif [[ -f /etc/arch-release ]]; then
	    for package in "${arch_packages[@]}"; do
		    install_pacman_package "$package"
	    done
    elif [[ -f /etc/alpine-release ]]; then
	    for package in "${alpine_packages[@]}"; do
		    install_apk_package "$package"
	    done
    elif [[ -f /etc/gentoo-release ]]; then
	    for package in "${gentoo_packages[@]}"; do
		    install_emerge_package "$package"
	    done
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
				install_missing_packages "$@"
				extract_recovery_dmg "$@"
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
