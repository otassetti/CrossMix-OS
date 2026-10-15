#!/bin/sh
# CrossMix adapter: the firmware supplies Moonlight and owns power handling.
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
export PATH="/usr/trimui/apps/moonlight:/usr/trimui/bin:/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/usr/trimui/lib:/mnt/SDCARD/System/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

fail() {
    echo "$1" >&2
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "$1" -k "A B" -fs 22
    exit 1
}

device=$(cat /etc/trimui_device.txt 2>/dev/null)
[ "$device" = "tsp" ] || fail "Moonlight Next UI currently targets the original Smart Pro only."
[ -x "$APP_DIR/moonlight-pak" ] || fail "Moonlight Next UI binary missing. Install the compiled CrossMix app package; see README.md."
command -v moonlight >/dev/null 2>&1 || fail "Moonlight CLI missing from firmware. Check your TrimUI firmware installation."
export MOONLIGHT_CLIENT
MOONLIGHT_CLIENT=$(command -v moonlight)
export PATH="$APP_DIR:$PATH"

export SHARED_USERDATA_PATH="/mnt/SDCARD/Data/MoonlightNextUI"
export LOGS_PATH="$SHARED_USERDATA_PATH/logs"
mkdir -p "$LOGS_PATH" "$SHARED_USERDATA_PATH/moonlight" || fail "Cannot create Moonlight data directory on SD card."
# Keep client certificates separate from the firmware UI's pairing cache.
export HOME="$SHARED_USERDATA_PATH"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export MOONLIGHT_FONT="/mnt/SDCARD/Themes/CrossMix - OS/wqy-microhei.ttf"
[ -r "$MOONLIGHT_FONT" ] || fail "CrossMix font missing. Restore Themes/CrossMix - OS/wqy-microhei.ttf."

cd "$APP_DIR" || exit 1
# The port does not set NextUI's stay_awake marker or install a power handler.
# The firmware and input daemon continue managing the console normally.
./moonlight-pak >>"$LOGS_PATH/frontend.log" 2>&1
result=$?
[ "$result" -eq 0 ] || fail "Moonlight Next UI exited with error $result. See Data/MoonlightNextUI/logs/frontend.log."
exit "$result"
