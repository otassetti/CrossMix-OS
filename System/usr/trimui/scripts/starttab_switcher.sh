#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
config="/mnt/SDCARD/System/etc/crossmix.json"
system="/mnt/UDISK/system.json"
template="/mnt/SDCARD/System/resources/default_state.json"
mode="boot"
selection="$1"
if [ "$selection" = "--system-tools" ]; then
    mode="tools"
    selection="Apps"
elif [ -n "$selection" ]; then
    mode="select"
else
    selection=$(jq -r '.["START TAB"] // "RetroGame"' "$config")
fi

# Preserve MainUI's tab order. Empty native Ports/Best tabs are not displayed.
ports=0
bests=0
[ -n "$(find /mnt/SDCARD/Ports -maxdepth 2 -name launch.sh -type f -print -quit 2>/dev/null)" ] && ports=1
[ -n "$(find /mnt/SDCARD/Best -maxdepth 2 -name launch.sh -type f -print -quit 2>/dev/null)" ] && bests=1
tabs=$(jq -r --argjson ports "$ports" --argjson bests "$bests" '
    to_entries[] | select(.key | test("tab$"; "i")) |
    select(.key | test("focuson"; "i") | not) |
    select(.value == 1 or .value == true) |
    select(($ports == 1) or (.key | ascii_downcase) != "portstab") |
    select(($bests == 1) or (.key | ascii_downcase) != "beststab") | .key
' "$system") || exit 1
[ -n "$tabs" ] || { echo "No visible MainUI tabs found."; exit 1; }
count=$(printf '%s\n' "$tabs" | wc -l)
index=$(printf '%s\n' "$tabs" | awk -v requested="$selection" '
    BEGIN { requested=tolower(requested); sub(/tab$/, "", requested) }
    { name=tolower($0); sub(/tab$/, "", name) }
    name == requested { print NR-1; exit }
    requested ~ /^tab [1-7]$/ && NR == substr(requested, 5)+0 { print NR-1; exit }
')
if [ -z "$index" ]; then
    if [ "$mode" != "boot" ]; then
        echo "Requested start tab is disabled or unavailable: $selection"
        exit 1
    fi
    # Old ordinal preferences can outlive changes in the visible tabs.
    index=$(printf '%s\n' "$tabs" | awk 'tolower($0) == "retrogametab" { print NR-1; exit }')
    index=${index:-0}
fi
start=0
[ "$index" -gt 2 ] && start=$((index - 2))
temporary=$(mktemp /tmp/start-state.XXXXXX) || exit 1
if ! jq --argjson index "$index" --argjson start "$start" --argjson count "$count" --arg mode "$mode" '
    .list[1].tabidx = $index | .list[1].tabstartidx = $start |
    .list[1].tabstate = [range(0; $count) | {currpos: 0, pagestart: 0, pageend: 0}] |
    if $mode == "tools" then .list += [{title: -1, type: 23, currpos: 0,
        pagestart: 0, pageend: 7, emulaunch: "/mnt/SDCARD/Emus/_SystemTools/launch.sh"}]
    else . end
' "$template" > "$temporary"; then
    rm -f "$temporary"
    exit 1
fi
if [ "$mode" = "select" ]; then
    settings=$(mktemp /tmp/start-settings.XXXXXX) || { rm -f "$temporary"; exit 1; }
    if ! jq --arg selection "$selection" '.["START TAB"] = $selection' "$config" > "$settings"; then
        rm -f "$temporary" "$settings"
        exit 1
    fi
    mv "$settings" "$config"
    # Keep the current System Tools navigation while choosing the next boot tab.
    mv "$temporary" /mnt/SDCARD/System/resources/start_state.json
else
    mv "$temporary" /tmp/state.json
fi
