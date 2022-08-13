# OpenCore USB-installer Script

## Description

This script is designed to create an OpenCore USB-installer on Linux. It automates the process of formatting a USB drive, installing necessary dependencies, extracting the macOS recovery image, burning the recovery image to the USB drive, and installing OpenCore.

## Author

- **Author**: Broly
- **License**: [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.txt)

## Prerequisites

- A Linux environment is required to run this script.
- Make sure you have a USB drive ready for the installation.

## Usage

1. Open a terminal window.
2. Navigate to the directory containing the script using the `cd` command.
3. Make the script executable if it's not already: `chmod +x ocflashdrive.sh`
4. Run the script: `./ocflashdrive.sh`
5. The script will guide you through the process step by step.

## Features

- The script clears the screen and checks if the user is root. If not, it will execute the script with sudo.
- USB drive selection: The script prompts the user to select the USB drive to use.
- Dependency installation: It installs the necessary dependencies based on your Linux distribution.
- USB drive formatting: The script formats the selected USB drive for the installation.
- Extraction of macOS recovery image: It extracts the macOS recovery image from a downloaded DMG file.
- Burning the recovery image: The script burns the macOS recovery image to the USB drive.
- OpenCore installation: It installs OpenCore to the USB drive.

## Important Notes

- Make sure to backup any important data on the USB drive before running the script, as it will be formatted.
- The script requires root privileges to execute certain commands, so you may need to enter your password during the process.

## Disclaimer

- This script is provided as-is. The author do not take responsibility for any data loss or system issues that may arise from using this script. Use it at your own risk.

## License

This script is licensed under the GNU General Public License v3.0. Please review the [license terms](https://www.gnu.org/licenses/gpl-3.0.txt) before using the script.


