#!/bin/sh
# Local packages must retain their reviewed updater rather than refresh upstream scripts.
ota_updates_allowed() {
    [ ! -f /mnt/SDCARD/System/etc/local-release.txt ] || return 1
    # Earlier personal packages did not include the marker.
    case "${Local_CrossMixVersion:-$(cat /mnt/SDCARD/System/usr/trimui/crossmix-version.txt 2>/dev/null)}" in
        1.3.9|1.3.10|1.3.11) return 1 ;;
    esac
    return 0
}

manual_update_message() {
    echo "This local build uses manual ZIP updates."
    echo "Copy a reviewed CrossMix release ZIP to the SD card to update."
    echo "OTA is disabled to preserve the local fixes."
}
