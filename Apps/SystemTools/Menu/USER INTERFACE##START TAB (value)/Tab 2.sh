#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
sh /mnt/SDCARD/System/usr/trimui/scripts/starttab_switcher.sh "Tab 2" &&
/mnt/SDCARD/System/usr/trimui/scripts/mainui_state_update.sh "START TAB" "Tab 2"
