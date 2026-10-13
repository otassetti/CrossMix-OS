#!/usr/bin/env bash
set -euo pipefail
version=${1:-1.3.4}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Use a numeric X.Y.Z version.' >&2; exit 1; }
root=$(git rev-parse --show-toplevel)
output=${RELEASE_OUTPUT_DIR:-"$root/dist"}
mkdir -p "$output"
output=$(realpath "$output")
[[ -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit) ]] || { echo 'Output directory must be empty.' >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
stage="$work/sdcard"
mkdir -p "$stage"
for directory in Apps BIOS Backgrounds Best Data Emus Icons Imgs Pictures RetroArch Roms System Themes trimui; do
  [[ -d "$root/$directory" ]] || { echo "Missing $directory: use a full checkout." >&2; exit 1; }
  rsync -a "$root/$directory" "$stage/"
done
for file in .VolumeIcon.icns autorun.inf LICENSE; do
  cp "$root/$file" "$stage/"
done
find "$stage" -type f -name .gitkeep -delete
while IFS= read -r -d '' archive; do
  7zz x "$archive" "-o$(dirname "$archive")" -y
  rm "$archive"
done < <(find "$stage/RetroArch/.retroarch/cores" -type f -name '*.7z' -print0)
printf '%s\n' "$version" >"$stage/System/usr/trimui/crossmix-version.txt"
# TG5040 only; match the firmware bundled in main.
printf '1.1.1\n20251128\n' >"$stage/trimui/firmwares/MinFwVersion.txt"
[[ -f "$stage/trimui/firmwares/firmware_tsp_v1.1.1_20251128.7z.001" ]]
[[ -f "$stage/trimui/firmwares/firmware_tsp_v1.1.1_20251128.7z.002" ]]
7zz t "$stage/trimui/firmwares/firmware_tsp_v1.1.1_20251128.7z.001"
(
  cd "$stage"
  rm -f RetroArch/default_config.7z
  7zz a RetroArch/default_config.7z RetroArch/retroarch.cfg RetroArch/.retroarch/config
)
printf 'Repository: %s\nCommit: %s\nCrossMix package: %s\nDevice: TrimUI Smart Pro TG5040\nFirmware: 1.1.1 / 20251128\nUnofficial test build.\n' \
  "${GITHUB_REPOSITORY:-otassetti/CrossMix-OS}" "$(git -C "$root" rev-parse HEAD)" "$version" >"$stage/build-info.txt"
archive="CrossMix-OS_v$version.zip"
(
  cd "$stage"
  zip -q -9 -r "$output/$archive" .
)
unzip -tq "$output/$archive"
size=$(stat -c %s "$output/$archive")
(( size < 4294967296 )) || { echo 'Archive exceeds FAT32 single-file capacity.' >&2; exit 1; }
(
  cd "$output"
  sha256sum "$archive" >SHA256SUMS
  if (( size >= 2000000000 )); then
    split -b 1900M -d -a 2 "$archive" "$archive.part"
    sha256sum "$archive".part* >PART-SHA256SUMS
    rm "$archive"
  fi
)
cp "$root/docs/smart-pro-release.md" "$output/INSTALLATION.md"
cp "$stage/build-info.txt" "$output/build-info.txt"
echo "Verified release files: $output"
