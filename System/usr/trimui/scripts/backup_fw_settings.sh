#!/bin/sh
# Publish a new automatic backup marker only after verifying the new archive.
IFS= read -r device < /etc/trimui_device.txt || [ -n "$device" ] || exit 1
case "$device" in tsp|brick) ;; *) exit 1 ;; esac
if output=$("/mnt/SDCARD/Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh" --backup); then
    name=$(printf '%s\n' "$output" | tail -n 1)
else
    printf '%s\n' "$output" >&2
    echo "Firmware settings backup failed. Previous backups have been kept." >&2
    exit 1
fi
case "$name" in ''|*/*|*\\*|.|..) exit 1 ;; esac
case "$name" in backup_*.7z) ;; *) exit 1 ;; esac
archive="/mnt/SDCARD/System/backups/firmware_settings/$device/$name"
[ -s "$archive" ] || { echo "New firmware backup is missing or empty." >&2; exit 1; }
# The settings tool verifies the archive before returning its filename.
marker="/mnt/SDCARD/trimui/firmwares/Last_Automatic_Backup.txt"
temporary=$(mktemp /mnt/SDCARD/trimui/firmwares/.backup-marker.XXXXXX) || exit 1
if ! printf '%s\n' "$name" >"$temporary" || ! mv "$temporary" "$marker"; then
    rm -f "$temporary"
    exit 1
fi
sync || exit 1
printf '%s\n' "$name"
