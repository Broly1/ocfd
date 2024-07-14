#!/bin/bash
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt
# This script is intended to create an OpenCore USB-installer on Linux.

banner() {
    cat <<"EOF"

 ██████╗  ██████╗███████╗██████╗ 
██╔═══██╗██╔════╝██╔════╝██╔══██╗
██║   ██║██║     █████╗  ██║  ██║
██║   ██║██║     ██╔══╝  ██║  ██║
╚██████╔╝╚██████╗██║     ██████╔╝
 ╚═════╝  ╚═════╝╚═╝     ╚═════╝ 

EOF
}

check_for_internet() {
    clear
    banner "$@"
    # Check for internet connectivity
    if ping -q -c 1 -W 1 google.com >/dev/null; then
        :
    else
        printf "No internet connection. Unable to download dependencies.\n"
        exit 1
    fi
}

# This function clears the screen and checks if the user is root. If not, it will execute the script with sudo.
get_root(){
    clear
    banner "$@"
    printf "Please enter your password:\n"
    [[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
    set -e
}

# Get the USB drive selected by the user.
get_the_drive() {
    clear
    banner "$@"
    while true; do
        printf "Please Select the USB Drive\nFrom the Following List!\n"
        readarray -t lines < <(lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb")
        for ((i=0; i<${#lines[@]}; i++)); do
            printf "%d) %s\n" "$((i+1))" "${lines[i]}"
        done
        printf "r) Refresh\n"
        read -r -p "#? " choice
        clear
        banner "$@"
        if [ "$choice" == "r" ]; then
            printf "Refreshing USB Drive List...\n"
            continue
        fi
        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#lines[@]}" ]]; then
            selected_drive_line="${lines[$((choice-1))]}"
            drive=$(echo "$selected_drive_line" | awk '{print $1}')
            break
        else
            printf "Invalid selection. Please try again.\n"
        fi
    done
}

# Check if the macOS recovery file exists
get_recovery() {
    local recovery_dir="com.apple.recovery.boot"
    local recovery_file1="$recovery_dir/BaseSystem.dmg"
    local recovery_file2="$recovery_dir/RecoveryImage.dmg"
    if [ ! -e "$recovery_file1" ] && [ ! -e "$recovery_file2" ]; then
        printf "macOS recovery file not found.\nPlease download the macOS Recovery with macrecovery!\n"
        exit 1
    fi
}

# Ask user to confirm and continue installation.
confirm_continue() {
    clear
    banner "$@"
    while true; do
        printf "Warning the drive below will be erased: \n'%s' \n\nThe following tools will be installed: \nwget, curl, gdisk, and dosfstools.\nDo you want to proceed? [y/n]: " "$selected_drive_line"
        read -r yn
        case $yn in
            [Yy]*) break ;;
            [Nn]*) 
                printf "Exiting the script...\n"
                exit ;;
            *) 
                printf "Please answer yes or no.\n" ;;
        esac
    done
}

# Install dependencies based on the detected distribution
install_dependencies() {
    clear
    banner "$@"
    printf "Installing dependencies...\n\n"
    sleep 2s

    if [[ -f /etc/debian_version ]]; then
        for package in "wget" "curl" "dosfstools" "gdisk"; do
            if ! dpkg -s "$package" > /dev/null 2>&1; then
                apt install -y "$package"
            else
                printf "Package %s is already installed.\n" "$package"
            fi
        done
    elif [[ -f /etc/fedora-release ]]; then
        for package in "wget" "curl" "dosfstools" "gdisk"; do
            if ! rpm -q "$package" > /dev/null 2>&1; then
                dnf install -y "$package"
            else
                printf "Package %s is already installed.\n" "$package"
            fi
        done
    elif [[ -f /etc/arch-release ]]; then
        for package in "wget" "curl" "dosfstools" "gptfdisk"; do
            if ! pacman -Q "$package" > /dev/null 2>&1; then
                pacman -Sy --noconfirm --needed "$package"
            else
                printf "Package %s is already installed.\n" "$package"
            fi
        done
    elif [[ -f /etc/alpine-release ]]; then
        for package in "wget" "curl" "dosfstools"; do
            if ! apk info "$package" > /dev/null 2>&1; then
                apk add "$package"
            else
                printf "Package %s is already installed.\n" "$package"
            fi
        done
    elif [[ -f /etc/gentoo-release ]]; then
        for package in "wget" "curl" "dosfstools"; do
            if ! emerge --search "$package" | grep -q "^$package/"; then
                emerge --nospinner --oneshot --noreplace "$package"
            else
                printf "Package %s is already installed.\n" "$package"
            fi
        done
    else
        printf "Your distro is not supported!\n"
        exit 1
    fi
}

# Download latest 7zip binary
BASE_URL="https://sourceforge.net/projects/sevenzip/files/7-Zip/"

get_latest_version_7z() {
    page_content=$(curl -s "$BASE_URL")
    latest_version=$(echo "$page_content" | grep -oP '(?<=href="/projects/sevenzip/files/7-Zip/)[0-9]+\.[0-9]+' | sort -V | tail -n 1)
    printf "%s\n" "$latest_version"
}

download_and_extract_7zz() {
    latest_version=$(get_latest_version_7z)
    if [ -z "$latest_version" ]; then
        printf "Could not find the latest version.\n"
        exit 1
    fi
    file_url="${BASE_URL}${latest_version}/7z${latest_version//./}-linux-x64.tar.xz"
    printf "Downloading 7z%slinux-x64.tar.xz...\n" "${latest_version//./}-"
    curl -LO "$file_url"
    printf "Extracting the 7zz binary...\n"
    tar -xJf "7z${latest_version//./}-linux-x64.tar.xz" 7zz
    rm "7z${latest_version//./}-linux-x64.tar.xz"
    printf "Extracted 7zz binary for version %s\n" "$latest_version"
}

# Extract the macOS recovery image from the downloaded DMG file.
extract_recovery_dmg() {
    clear
    banner "$@"
    local recovery_dir="com.apple.recovery.boot"
    local recovery_file1="$recovery_dir/BaseSystem.dmg"
    local recovery_file2="$recovery_dir/RecoveryImage.dmg"
    rm -rf "$recovery_dir"/*.hfs
    printf "Downloading 7zip.\n"
    check_for_internet "$@"
    download_and_extract_7zz "$@"

    if [[ ! -f 7zz ]]; then
        printf "Error: 7zz was not downloaded or is missing.\n"
        exit 1
    fi
        chmod +x 7zz

    if [ -e "$recovery_file1" ]; then
        clear
        banner "$@" 
        printf "Extracting Recovery...\n%s$recovery_file1!"
        ./7zz e -bso0 -bsp1 -tdmg "$recovery_file1" -aoa -o"$recovery_dir" -- *.hfs
        rm -f "$PWD/7zz" || printf "Failed to delete 7zz"
    elif [ -e "$recovery_file2" ]; then
        clear
        banner "$@"
        printf "Extracting Recovery...\n%s$recovery_file2!"
        ./7zz e -bso0 -bsp1 -tdmg "$recovery_file2" -aoa -o"$recovery_dir" -- *.hfs
        rm -f "$PWD/7zz" || printf "Failed to delete 7zz"
    fi
}

# Format the USB drive.
format_drive(){
    clear
    banner "$@"
    printf "Formatting the USB drive...\n"
    umount "$drive"* || :
    sleep 2s
    wipefs -af "$drive"
    sgdisk "$drive" --new=0:0:+300MiB -t 0:ef00 && partprobe
    sgdisk "$drive" --new=0:0: -t 0:af00 && partprobe
    mkfs.fat -F 32 "$drive"1
    sleep 2s
}

# Burn the macOS recovery image to the target drive
burning_drive(){
    clear
    banner "$@"
    local myhfs
    myhfs=$(ls com.apple.recovery.boot/*.hfs 2>/dev/null)
    if [ -z "$myhfs" ]; then
        printf "No .hfs files found in com.apple.recovery.boot directory.\n"
        exit 1
    fi
    printf "Installing macOS recovery image...\n"
    dd bs=8M if="$myhfs" of="${drive}2" status=progress oflag=sync
    umount "$drive"* || :
    sleep 3s
    printf "The macOS recovery image has been burned to the drive!\n"
    rm -f "$myhfs"
}

# Install OpenCore to the target drive
install_OC() {
    clear
    banner "$@"
    printf "Installing OpenCore to the drive...\n"
    local temp_mount
    temp_mount="$(mktemp -d)"
    if mount -t vfat "${drive}1" "$temp_mount" -o rw,umask=000; then
        sleep 3s

        # Copy OpenCore EFI files
        cp -r ../../X64/EFI/ "$temp_mount"
        cp -r ../../Docs/Sample.plist "${temp_mount}/EFI/OC/"
        clear
        banner "$@"
        printf "OpenCore has been installed to the drive!\nPlease open '%s' and edit OC for your machine!!\n" "$temp_mount/EFI/OC"
        ls -1 "${temp_mount}/EFI/OC"
    else
        printf "Error: Failed to mount the drive.\n"
    fi
}

main() {
    check_for_internet "$@"
    get_root "$@"
    get_the_drive "$@"
    get_recovery "$@"
    confirm_continue "$@"
    install_dependencies "$@"
    extract_recovery_dmg "$@"
    format_drive "$@"
    burning_drive "$@"
    install_OC "$@"
}

main "$@"
