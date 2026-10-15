# Moonlight Next UI for CrossMix (experimental source port)

This App ports [Richie Szemeredi's Moonlight for NextUI v0.1.0](https://github.com/richieszemeredi/nextui-moonlight-pak/tree/v0.1.0) to CrossMix on the **original TrimUI Smart Pro** (`tsp`, TG5040). It uses the firmware's `moonlight` CLI for pairing, listing and streaming. Sunshine must be running on the PC and Wi-Fi enabled on the console.

## Build and install

**The repository does not yet contain a compiled CrossMix binary.** Copying this source App folder alone will display a missing-binary message. Do not substitute the upstream `.pakz` binary: it enables NextUI power handling and expects NextUI resources.

On a Linux host with Docker, make and zip installed, run from the repository root:

```sh
sh _assets/scripts/build-moonlight-next-ui.sh
```

The dedicated **Build Moonlight Next UI** GitHub Actions workflow performs the same build and uploads a ZIP artifact. It does not publish a release. Extract the resulting `MoonlightNextUI-CrossMix.zip` at the SD card root, then start **Moonlight Next UI** in Apps. The ZIP contains only `Apps/MoonlightNextUI/`.

The initial defaults are **1280x720, 60 FPS, 10 Mbps**. Use Servers > X to add your PC's IPv4 address, Pair to display the PIN to enter in Sunshine, then Stream to select an application. Start with 30 FPS or a lower bitrate if Wi-Fi struggles. The upstream UI also exposes Brick resolutions and 120 FPS; those do not establish Smart Pro hardware support. In-stream controls and exit shortcuts are provided by the firmware client (normally Select + Start).

## Data and diagnostics

- UI server list/settings: `Data/MoonlightNextUI/moonlight/config.txt`.
- Pairing cache: under `Data/MoonlightNextUI/` through HOME/XDG variables; confirm the exact location with the installed firmware client during device testing.
- Logs: `Data/MoonlightNextUI/logs/`.
- Font: the existing `Themes/CrossMix - OS/wqy-microhei.ttf`.

No firmware files, original Moonlight settings or existing pairing keys are deleted. This interface uses its own HOME; pair again rather than deleting the firmware UI's cache. To uninstall, remove `Apps/MoonlightNextUI`; retain the Data folder if you want to keep its settings.

## Validation status

Launcher failure paths and native CLI argument handling pass on GitHub Actions. The CrossMix port was successfully cross-compiled there on 2026-10-15: run [38753079087](https://github.com/otassetti/CrossMix-OS/actions/runs/38753079087). The resulting ZIP passed integrity checks; its executable is ELF64 AArch64 and references GLIBC_2.17. **Dynamic linking on the console, rendering, controls, pairing, streaming, sleep/wake and return to MainUI still require validation.** See the [integration study](../../_assets/sources/moonlight-next-ui/README.md) for dependencies, implementation decisions and the device acceptance checklist.

## Credits

Moonlight UI: Richie Szemeredi, MIT (`LICENSE`). Apostrophe: Kevin Vranken, MIT (`LICENSE-Apostrophe`). CrossMix adapter and port changes are maintained in this repository. Moonlight itself remains supplied by TrimUI firmware.
