#!/bin/sh
# Restore the settings saved by the firmware upgrade wizard.
marker="/mnt/SDCARD/trimui/firmwares/Last_Automatic_Backup.txt"
[ -f "$marker" ] || exit 0
IFS= read -r backup_name < "$marker" || [ -n "$backup_name" ] || exit 1
IFS= read -r current_device < /etc/trimui_device.txt || [ -n "$current_device" ] || exit 1
case "$current_device" in tsp|brick) ;; *) exit 1 ;; esac
case "$backup_name" in ''|*/*|*\\*|.|..) exit 1 ;; esac
backup="/mnt/SDCARD/System/backups/firmware_settings/$current_device/$backup_name"
if [ ! -f "$backup" ]; then
    echo "No automatic firmware backup found: $backup"
    exit 0
fi
restore="/mnt/SDCARD/Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh"
echo "Restoring firmware settings from $backup_name"
"$restore" --restore "$backup" joystick || exit 1
"$restore" --restore "$backup" wifi
