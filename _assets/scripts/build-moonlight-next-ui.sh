#!/bin/sh
# Run on a Linux host with Docker. Output is a standalone SD-card overlay.
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SOURCE="$REPO/_assets/sources/moonlight-next-ui"
OUTPUT="$SOURCE/build/package"
IMAGE=${MOONLIGHT_TOOLCHAIN_IMAGE:-ghcr.io/loveretro/tg5040-toolchain@sha256:f131c6af64029a8723d0ce8d3c2682642f5f091b04714f6beedda9bec18477ab}
docker run --rm --user "$(id -u):$(id -g)" \
    -v "$SOURCE:/workspace" -w /workspace "$IMAGE" make
mkdir -p "$OUTPUT/Apps/MoonlightNextUI"
cp "$REPO/Apps/MoonlightNextUI/"* "$OUTPUT/Apps/MoonlightNextUI/"
cp "$SOURCE/build/moonlight-pak" "$OUTPUT/Apps/MoonlightNextUI/"
chmod +x "$OUTPUT/Apps/MoonlightNextUI/launch.sh" "$OUTPUT/Apps/MoonlightNextUI/moonlight-pak" "$OUTPUT/Apps/MoonlightNextUI/moonlight"
cd "$OUTPUT"
zip -r ../MoonlightNextUI-CrossMix.zip Apps
sha256sum ../MoonlightNextUI-CrossMix.zip
