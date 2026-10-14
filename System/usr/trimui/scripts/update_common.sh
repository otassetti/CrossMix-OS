#!/bin/sh
UPDATE_VERSION=1.0.0
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

UPDATER_SCRIPT_DIR="${UPDATER_SCRIPT_DIR:-/mnt/SDCARD/System/usr/trimui/scripts}"
. "$UPDATER_SCRIPT_DIR/update_policy.sh" || exit 1

if [ "$1" == "-v" ]; then
    echo -n $UPDATE_VERSION
    exit
fi

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[01;35m'
NC='\033[0m' # No Color

GITHUB_REPOSITORY=cizia64/CrossMix-OS
updatedir="/mnt/SDCARD/System/updates"
Local_CrossMixVersion="$(cat "/mnt/SDCARD/System/usr/trimui/crossmix-version.txt")"
current_date=$(date "+%Y-%m-%d")
timestamp=$(date +'%Y%m%d-%Hh%M')

check_connection() {
    echo -n "Checking internet connection... "
    if wget -q --spider https://github.com >/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}\nError: https://github.com not reachable. Check your wifi connection."
        echo -ne "${YELLOW}"
        read -n 1 -s -r -p "Press A to exit"
        exit 2
    fi
}

enable_wifi() {
    # Check if the Wi-Fi interface already has an IP
    IP=$(ip route get 1 | awk '/src/ {print $NF; exit}')
    if [ -n "$IP" ]; then
        echo "Wi-Fi is already enabled. IP: $IP"
        return 0
    fi

    echo "Wi-Fi is disabled - trying to enable it..."

    pkill -9 wpa_supplicant 2>/dev/null
    pkill -9 udhcpc 2>/dev/null
    rm -rf /etc/wifi/sockets/wlan0 2>/dev/null

    # Bring up the loopback interface
    if ! ifconfig lo up; then
        echo "Failed to bring up loopback interface (lo)."
        return 1
    fi

    sleep 1

    # Bring up the Wi-Fi interface
    if ! ifconfig wlan0 up; then
        echo "Failed to bring up Wi-Fi interface (wlan0)."
        return 1
    fi

    sleep 1

    # Start wpa_supplicant
    if ! wpa_supplicant -B -D nl80211 -i wlan0 -c /etc/wifi/wpa_supplicant.conf -O /etc/wifi/sockets; then
        echo "Failed to start wpa_supplicant."
        return 1
    fi

    sleep 5

    # Start udhcpc to obtain an IP address
    if
        ! udhcpc -i wlan0 &
        >/dev/null &
    then
        echo "Failed to start udhcpc."
        return 1
    fi

    # Verify if an IP address has been obtained
    IP=$(ip route get 1 | awk '/src/ {print $NF; exit}')
    if [ -n "$IP" ]; then
        echo "Wi-Fi enabled successfully. IP: $IP"
        return 0
    else
        echo "Failed to obtain an IP address."
        return 1
    fi
}
. "$UPDATER_SCRIPT_DIR/sdcard_checks.sh" || exit 1

ReadableSizeValue() {
    local size_bytes=$1
    local result

    if [ -z "$size_bytes" ]; then
        size_bytes=0
    fi

    if [ "$size_bytes" -lt 1024 ]; then
        result="${size_bytes} Bytes"
    elif [ "$size_bytes" -lt $((1024 * 1024)) ]; then
        size_kb=$((size_bytes / 1024))
        result="${size_kb} KB"
    else
        size_mb=$(echo "$size_bytes" | awk '{printf "%.2f", $1 / (1024 * 1024)}')
        result="${size_mb} MB"
    fi

    echo "$result"
}

check_available_space() {
    required_space=$1
    echo -e "\n${BLUE}=== Checking available space on the SD Card ===${NC}\n"
    # Available space in MB
    mount_point=$(mount | grep -m 1 '/mnt/SDCARD' | awk '{print $1}')
    available_space=$(df -m $mount_point | awk 'NR==2{print $4}')
    echo "Required space: $required_space MB"
    # Check available space
    if [ "$available_space" -lt "$required_space" ]; then
        echo -e "${RED}Available space is insufficient on SD card${NC}\n"
        echo "CrossMix-OS update requires $required_space MB of free space."
        return 1
    else
        echo -e "${GREEN}Available space is sufficient on SD card (${available_space}MB)${NC}\n"
        return 0
    fi
}

download_file() {
    local url=""
    local destination_dir="."
    local destination_file=""
    local title=""

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
        -d)
            destination_dir="$2"
            shift 2
            ;;
        -f)
            destination_file="$2"
            shift 2
            ;;
        -t)
            title="$2"
            shift 2
            ;;
        *)
            url="$1"
            shift
            ;;
        esac
    done

    local filename=$(basename "$url")

    # Ensure the URL is provided
    if [ -z "$url" ]; then
        echo "Error: URL is required."
        return 1
    fi

    # Determine the filename if not explicitly set
    if [ -z "$destination_file" ]; then
        destination_file="$destination_dir/$filename"
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$destination_file")"

    # Use the title if provided, otherwise fallback to the filename
    local display_name="${title:-$filename}"

    # Temporary file name
    local temp_file="${destination_file}_tmp"

    # Download the file
    echo -e "\n${BLUE}==== Downloading: $display_name ====${NC}"
    wget --no-check-certificate --quiet --show-progress -O "$temp_file" "$url"
    if [ $? -eq 0 ] && [ -f "$temp_file" ]; then
        mv "$temp_file" "$destination_file"
        sync
        echo -e "$display_name: ${GREEN}OK${NC}\n"
        return 0
    else
        # Remove the temporary file if download failed
        [ -f "$temp_file" ] && rm "$temp_file"
        sync
        echo -e "$display_name: ${RED}Failed${NC}\n"
        return 1
    fi
}
