#!/usr/bin/env bash
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd)
script=$(tr -d '\r' < "$repo/System/usr/trimui/scripts/crossmix_update.sh")
preflight=$(printf '%s\n' "$script" | sed -n '/^# Verify the complete archive/,/^echo ".*Creating backup/{ /^echo /d; p; }')
extraction=$(printf '%s\n' "$script" | sed -n '/^if \/tmp\/7zz x/,/^echo ".*Restoring saves/{ /^echo /d; p; }')
[ -n "$preflight" ] && [ -n "$extraction" ]
preflight=${preflight//\/tmp\/7zz/fake7zz}
extraction=${extraction//\/tmp\/7zz/fake7zz}
fake7zz() { return "$archive_status"; }
# Mock device actions: tests must never move, remove or sync actual files.
rm() { :; }
mv() { :; }
sync() { :; }
UPDATE_FILE=test.zip
update_version=1.3.9
BCK_DIR=test-backup
RED= GREEN= NC=
check() {
    local code=0
    (archive_status=$2; eval "$1") >/dev/null 2>&1 || code=$?
    if [ "$code" -ne "$3" ]; then
        echo "FAIL: archive status $2 produced exit $code, expected $3" >&2
        exit 1
    fi
}
check "$preflight" 0 0
check "$preflight" 2 1
check "$extraction" 0 0
check "$extraction" 2 2
check "$extraction" 7 7
echo 'PASS: corrupt archive rejected; extraction failure preserved despite successful sync.'
