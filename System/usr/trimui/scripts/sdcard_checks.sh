#!/bin/sh
# Shared by the firmware wizard and the CrossMix updater.
require_fat32() {
    local entry layout
    entry=$(awk '$2 == "/mnt/SDCARD" {print $1, $3, $4; exit}' /proc/mounts)
    [ -n "$entry" ] || { echo "SD card mount not found." >&2; return 1; }
    set -- $entry
    SDCARD_DEVICE="$1"
    SDCARD_FS="$2"
    case ",$3," in
        *,rw,*) ;;
        *) echo "SD card is read-only; repair it on a PC before updating." >&2; return 1 ;;
    esac
    case "$SDCARD_FS" in
        vfat|msdos) ;;
        *) echo "SD card uses $SDCARD_FS. Back up its contents on a PC, format as FAT32, and restore the data before updating." >&2; return 1 ;;
    esac
    # vfat also mounts FAT12/16. In a FAT32 BPB, root-entry count (17-18)
    # and the FAT16 size field (22-23) are both zero. Read the actual layout.
    layout=$(/mnt/SDCARD/System/usr/trimui/scripts/busybox od -An -tu1 -j17 -N7 "$SDCARD_DEVICE") || return 1
    if ! printf '%s\n' "$layout" | awk 'NF == 7 && $1 == 0 && $2 == 0 && $6 == 0 && $7 == 0 {ok=1} END {exit !ok}'; then
        echo "The SD card is not FAT32, or its boot sector cannot be read. Back up and prepare a FAT32 card on a PC." >&2
        return 1
    fi
}

check_filesystem() {
    require_fat32 || return 1
    local today stamp status
    today=$(date +%Y-%m-%d)
    stamp="/mnt/SDCARD/System/updates/last_fsck.txt"
    # Old helpers wrote just the date even on failure. Do not trust those stamps.
    if [ "$1" != "--force" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$today $SDCARD_DEVICE" ]; then
        echo "Filesystem check already completed today ($today)."
        return 0
    fi
    echo "Checking FAT32 filesystem; please wait."
    if /mnt/SDCARD/System/bin/fsck.fat -a "$SDCARD_DEVICE"; then
        status=0
    else
        status=$?
    fi
    if [ "$status" -eq 1 ]; then
        # fsck.fat can return 1 after repairs as well as for inconsistencies.
        # Accept repaired cards only when a second, read-only check is clean.
        echo "Verifying the filesystem after the repair attempt."
        if /mnt/SDCARD/System/bin/fsck.fat -n "$SDCARD_DEVICE"; then
            status=0
        else
            status=$?
        fi
    fi
    if [ "$status" -ne 0 ]; then
        # Never let a previous successful stamp hide a later failed forced check.
        rm -f "$stamp"
        echo "Filesystem check returned $status. Check and repair the SD card on a PC before updating." >&2
        return "$status"
    fi
    mkdir -p /mnt/SDCARD/System/updates || return 1
    printf '%s %s\n' "$today" "$SDCARD_DEVICE" >"$stamp" || return 1
    return 0
}
