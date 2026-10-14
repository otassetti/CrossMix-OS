#!/bin/sh
export LD_LIBRARY_PATH=./lib:/mnt/SDCARD/System/lib:$LD_LIBRARY_PATH
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
SEVENZ="/mnt/SDCARD/System/bin/7zz"
interactive=0
[ $# -eq 0 ] && interactive=1

# Function to restore individual files from the archive
restore_file() {
    path="$1"
    relative_path="${path#/}" # Remove leading "/" from the path
    [ -n "$relative_path" ] || return 1
    # Uncalibrated devices may have no joystick file in their backup.
    entries=$("$SEVENZ" l -slt "$ARCHIVE_PATH" "$relative_path") || return $?
    if ! printf '%s\n' "$entries" | grep -Fxq "Path = $relative_path"; then
        echo "No backed-up setting for $path; leaving it unchanged."
        return 0
    fi
    "$SEVENZ" x "$ARCHIVE_PATH" "$relative_path" -y -o/ || return $?
    [ -f "$path" ] || { echo "Restored file is missing: $path" >&2; return 1; }
    chmod 644 "$path" || return $?
    chown root:root "$path" || return $?
    echo "Restored: $path"
}

if ! IFS= read -r current_device </etc/trimui_device.txt && [ -z "$current_device" ]; then
    RES=$(fbset | awk '/geometry/ {print $2 "x" $3}')
    if [ "$RES" = "1280x720" ]; then
        current_device="tsp"
    else
        current_device="brick"
    fi
    echo -n $current_device >/etc/trimui_device.txt

fi
case "$current_device" in tsp|brick) ;; *) echo "Unknown device model." >&2; exit 1 ;; esac

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help                    Show this help message"
    echo "  -b, --backup                  Create a backup"
    echo "  -r, --restore FILE [TYPE]     Restore from backup file"
    echo ""
    echo "Restore types (optional):"
    echo "  all                           Restore all settings (default)"
    echo "  wifi                          Restore only wifi settings"
    echo "  joystick                      Restore only joystick calibration"
    echo "  mainui                        Restore only MainUI settings"
    echo ""
    echo "Examples:"
    echo "  $0 --backup"
    echo "  $0 --restore /path/to/backup.7z"
    echo "  $0 --restore /path/to/backup.7z wifi"
}

# Parse command line arguments
if [ $# -gt 0 ]; then
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    -b | --backup)
        selected_action="Backup"
        ;;
    -r | --restore)
        if [ -z "$2" ]; then
            echo "Error: Backup file path required for restore operation"
            show_help
            exit 1
        fi
        selected_action="Restore"
        ARCHIVE_PATH="$2"
        restore_type="${3:-all}"
        ;;
    *)
        echo "Error: Unknown option '$1'"
        show_help
        exit 1
        ;;
    esac
else
    # Interactive mode - use selector
    selector_output=$(selector -fs 200 -t "Choose an action to perform:                           (B to cancel)" -c "Backup" "Restore")
    selected_action="${selector_output#*: }"
fi

case "$selected_action" in
"Backup")
    echo "Backup mode"
    ARCHIVE_PATH="/mnt/SDCARD/System/backups/firmware_settings/$current_device/backup_$(date +'%Y%m%d-%Hh%M-%S')-$$.7z"
    partial="$ARCHIVE_PATH.partial"
    mkdir -p "/mnt/SDCARD/System/backups/firmware_settings/$current_device/" || exit 1
    [ ! -e "$ARCHIVE_PATH" ] && [ ! -e "$partial" ] || exit 1
    trap 'rm -f "$partial"' EXIT
    cd / || exit 1

    # Create the backup archive including the specified files
    [ -f mnt/UDISK/system.json ] || { echo "MainUI settings are missing; backup canceled." >&2; exit 1; }
    set --
    for file in etc/wifi/wpa_supplicant.conf mnt/UDISK/system.json mnt/UDISK/joypad.config mnt/UDISK/joypad_right.config root/.ash_history; do
        [ ! -f "$file" ] || set -- "$@" "$file"
    done
    "$SEVENZ" a -t7z "$partial" "$@" || exit 1
    "$SEVENZ" t "$partial" || exit 1
    mv "$partial" "$ARCHIVE_PATH" || exit 1
    sync || exit 1

    # Show info screen only in interactive mode
    if [ "$interactive" -eq 1 ]; then
        infoscreen.sh -m "\"$(basename "$ARCHIVE_PATH")\"    saved." -t 2
    else
        basename "$ARCHIVE_PATH"
    fi
    ;;

"Restore")

    echo "Restore mode"

    # If not in command line mode, ask the user to select the backup file
    if [ -z "$ARCHIVE_PATH" ]; then
        selector_output=$(selector -fs 150 -t "Choose a backup file to restore:" -d "/mnt/SDCARD/System/backups/firmware_settings/$current_device/")
        echo "$cleaned_input" | grep -q "No file selected" && {
            infoscreen.sh -m "Exiting..."
            exit 0
        }
        ARCHIVE_PATH="${selector_output#*: }"
    fi

    # Check if the backup archive file exists
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo "Backup archive not found: $ARCHIVE_PATH"
        exit 1
    fi
    "$SEVENZ" t "$ARCHIVE_PATH" || exit 1

    # If not in command line mode, ask what to restore
    if [ -z "$restore_type" ]; then
        selector_output=$(selector -fs 200 -t "Choose what you want to restore:" -c "All" "Wifi settings" "Joystick calibration" "MainUI settings")
        selected_restore="${selector_output#*: }"
        case "$selected_restore" in
        "All") restore_type="all" ;;
        "Wifi settings") restore_type="wifi" ;;
        "Joystick calibration") restore_type="joystick" ;;
        "MainUI settings") restore_type="mainui" ;;
        *)
            infoscreen.sh -m "Exiting..."
            exit
            ;;
        esac
    fi

    case "$restore_type" in
    "all")
        "$SEVENZ" x "$ARCHIVE_PATH" -y -o/ || exit 1
        restore_message="All settings restored."
        ;;
    "wifi")
        restore_file "/etc/wifi/wpa_supplicant.conf" || exit 1
        restore_message="Wifi settings restored."
        ;;
    "joystick")
        restore_file "/mnt/UDISK/joypad.config" || exit 1
        restore_file "/mnt/UDISK/joypad_right.config" || exit 1
        restore_message="Joystick calibration restored."
        ;;
    "mainui")
        restore_file "/mnt/UDISK/system.json" || exit 1
        restore_message="MainUI settings restored."
        ;;
    *)
        echo "No valid option selected."
        # Show info screen only in interactive mode
        if [ $# -eq 0 ]; then
            infoscreen.sh -m "Exiting..."
        fi
        exit 1
        ;;
    esac

    sync || exit 1
    # Show info screen only in interactive mode
    if [ $# -eq 0 ]; then
        infoscreen.sh -m "$restore_message" -t 2
    else
        echo "$restore_message"
    fi

    ;;

*)
    # If no valid action is selected (B pressed), exit
    echo "No valid action selected."
    # Show info screen only in interactive mode
    if [ $# -eq 0 ]; then
        infoscreen.sh -m "Exiting..."
    fi
    exit 1
    ;;
esac
