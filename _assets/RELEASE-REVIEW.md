# Issue and PR review — October 13, 2026

Scope: the **17 open PRs** in upstream cizia64/CrossMix-OS, the 100 most recently updated open issues, and targeted searches for saves, boot problems, and updates. Relevant discussions and main's scripts were compared with local package 1.3.9. The initial review did not reproduce these incidents on a console.

**Update after fixes: both high-priority problems were addressed in local version 1.3.10 and are included in 1.3.11.** The firmware restoration helper was tested with a present or missing backup, an invalid name, and a restoration failure. The tab selector was tested with hidden tabs, absent/present Best collections, an unavailable old preference, return to System Tools, and invalid JSON. The sections below retain the initial review findings. PR 482 was adapted using firmware 1.1.1 language IDs 197/198 while preserving the “Tab 1” through “Tab 7” menus. These changes were uncommitted at review time. SwanStation 16:9, GitHub release publication, and individual ports remain outside the scope of these fixes.

## Priorities for this Smart Pro

### 1. Automatic restoration of firmware settings

At review time, the repository contained a second `if -f ...; then` in `System/starts/°customization.sh`, around line 156. This should have been `if [ -f ... ]; then`. It controlled Wi-Fi and calibration restoration after a firmware update. The earlier fix for the same problem in `_FirmwareCheck.sh` did not cover this file. This defect was confirmed by reading the code while expanding the review of migration paths.

A `bash -n` check does not detect this error: the shell can interpret `-f` as a command whose execution will fail.

Initial action: fix it, test with a present and missing backup, and include the correction in the ZIP. This is now handled by `restore_fw_settings.sh`.

### 2. Tabs and System Tools launch — PR 482

https://github.com/cizia64/CrossMix-OS/pull/482

The PR reports a MainUI crash caused by the old state.json on firmware 1.1.0. It modernizes startup tab selection, prevents selection of a disabled tab, and updates the return to System Tools. In the upstream main reviewed here, the new `starttab_switcher.sh` was absent and `GoTo_SystemTools_List.json` retained the affected old format. `°customization.sh` also called `Tab Game.sh`, while the available scripts were named `Tab 1.sh` through `Tab 7.sh`.

This was a high priority because we were moving from 1.0.4 to 1.1.1. The symptom reported in the PR concerns 1.1.0; its exact applicability to 1.1.1 needed device testing. The old PR should not be applied blindly: it replaces many files and retains a numeric title that now corresponds to different text in the 1.1.1 languages. The local fix adapts it to the current main. Detailed device checks should cover boot, opening/closing System Tools, and hidden tabs.

### 3. SwanStation 16:9 — PR 416 / issue 461

https://github.com/cizia64/CrossMix-OS/pull/416
https://github.com/cizia64/CrossMix-OS/issues/461

The current `Emus/PS/swanstation_wide.sh` launcher creates and deletes temporary overrides and reads `PS.opt`, while the bundled base file is `SwanStation.opt`. It also refuses to launch if an override already exists for the same game. The PR redesigns this logic and adds a high-resolution PCSX mode.

The source filename problem is confirmed; the full redesign still requires console validation. Address it if SwanStation 16:9 is used. For the initial migration test, prefer PCSX or normal SwanStation, and consider custom 16:9 settings unvalidated.

### 4. GitHub release size — PR 543

https://github.com/cizia64/CrossMix-OS/pull/543

The initial local ZIP measured 2,491,606,428 bytes, above the 2 GiB per-file limit reported in this PR. The PR proposes a split ZIP and publication of the .z01 volume. Local copying to FAT32 remains possible because the file is below 4 GiB. GitHub publication needs different packaging.

The current OTA downloader handles only a single ZIP: the whole chain would need to support volumes, rather than changing only the publication workflow. Without publication, this does not block installation from the SD card. For the revised 1.3.11 archive size, see [LOCAL-RELEASE.md](LOCAL-RELEASE.md).

## Other open PRs reviewed

| PR | Topic | Decision for our package |
|---|---|---|
| [331](https://github.com/cizia64/CrossMix-OS/pull/331) | Autosave at shutdown | Old fix largely superseded by the new kill_apps and cmd_to_run_killer: recursive termination and waiting already exist. Test actual autosave; keep the current scripts. |
| [418](https://github.com/cizia64/CrossMix-OS/pull/418) | Model recognition on FW 1.1 | Fixes a comparison of the mode name containing the refresh rate. Main now uses geometry dimensions 1280x720, so the specific case has already changed. |
| [481](https://github.com/cizia64/CrossMix-OS/pull/481) | Firmware 1.1.0 and Brick | Partially superseded by merged PR 548 and firmware 1.1.1. The inconsistent archive reference has already been fixed locally. |
| [466](https://github.com/cizia64/CrossMix-OS/pull/466) | PPSSPP remains silent | Reported symptom, but Cizia and the author could no longer reproduce it in the latest comments reviewed. The patch forces volume to 10 for all values 0–10. Preserve user volume; test headphones and switching from Dreamcast to PSP. |
| [475](https://github.com/cizia64/CrossMix-OS/pull/475) | Balatro libraries | Port-specific requirement; a comment advises against globally replacing libmodplug. Prefer a fix inside the port's directory if needed. |
| [505](https://github.com/cizia64/CrossMix-OS/pull/505) | PPSSPP 1.19.3 | Upgrade with additional dependencies and binaries, rather than an essential migration fix. |
| [506](https://github.com/cizia64/CrossMix-OS/pull/506) | PPSSPP 1.18.1 / 1.19.0 | Another PSP upgrade proposal, to evaluate separately from 505. |
| [542](https://github.com/cizia64/CrossMix-OS/pull/542) | Per-game PSP settings | Additional feature, first-boot hook, and synchronization from an external source. Not required for our card update. |
| [573](https://github.com/cizia64/CrossMix-OS/pull/573) | PPSSPP shortcut in Apps | Small convenience addition tested on stable 1.3.0, but optional and absent from main. |
| [369](https://github.com/cizia64/CrossMix-OS/pull/369) | PSP/Minis shortcuts | Optional improvement to PPSSPP mappings. |
| [269](https://github.com/cizia64/CrossMix-OS/pull/269) | PSP presets | Old proposal; paths and name resolution logic need review. Prefer a separate analysis alongside 542. |
| [320](https://github.com/cizia64/CrossMix-OS/pull/320) | Brick support | Not a priority for the original Smart Pro. |
| [405](https://github.com/cizia64/CrossMix-OS/pull/405) | Helix editor | Cizia wants to offer it as an extension to avoid adding more than 200 MB and thousands of files to the distribution. |
| [372](https://github.com/cizia64/CrossMix-OS/pull/372) | Orphaned cover removal | Optional cleanup feature, unnecessary for the initial migration. |

The other two PRs are 482 and 416; 543 is covered above.

## Open issues: already addressed or worth monitoring

- **Audio after upgrading to firmware 1.1.0:** [421](https://github.com/cizia64/CrossMix-OS/issues/421) and [511](https://github.com/cizia64/CrossMix-OS/issues/511) concern stable 1.3.0 in particular. Cizia points to [PR 490](https://github.com/cizia64/CrossMix-OS/pull/490), already merged into our main. Avoid forcing ALSA universally: he says this reduces performance. The audio problem after sleep in [536](https://github.com/cizia64/CrossMix-OS/issues/536) is separate, with no established fix in the material reviewed; test sleep/wake and relaunch the game if sound disappears.
- **Activities and themes:** in [530](https://github.com/cizia64/CrossMix-OS/issues/530), Cizia says the fix is in PR 529, already merged and present in our main.
- **Settings after updating:** [110](https://github.com/cizia64/CrossMix-OS/issues/110) notes that PPSSPP configurations from different versions should not be merged wholesale and that ppsspp.ini is replaced with optimized CrossMix settings. Migration already preserves Syncthing and RetroAchievements data, but services, credentials, and saves should be checked after installation.
- **In-game menu:** in [480](https://github.com/cizia64/CrossMix-OS/issues/480), Cizia suggests CONTROLS → POLLING RATE → 8 ms, followed by another update if necessary. This is a troubleshooting lead for an observed symptom, not a required change.
- **Resume at Boot:** [462](https://github.com/cizia64/CrossMix-OS/issues/462) reports an incorrect time in mGBA, and [390](https://github.com/cizia64/CrossMix-OS/issues/390) reports LEDs turning back on. Neither was reproduced here. Disabling Resume at Boot simplifies diagnosis during initial tests.
- **Specific ports:** [563 OpenMW](https://github.com/cizia64/CrossMix-OS/issues/563), [566 GemRB](https://github.com/cizia64/CrossMix-OS/issues/566), [568 Dusklight](https://github.com/cizia64/CrossMix-OS/issues/568), and [569 EDuke32](https://github.com/cizia64/CrossMix-OS/issues/569) offer port-specific solutions involving SDL sensor, gconv, SQLite, or memory/launcher changes. They are not automatically included in main. Avoid globally replacing system libraries to fix a single game.
- **SegaCD:** [491](https://github.com/cizia64/CrossMix-OS/issues/491) reports a BIOS path problem. The retroarch.cfg in our main already points to `/mnt/SDCARD/BIOS`. There is insufficient evidence to attribute the problem to our current core without testing.

## Current device status and follow-up

Firmware restoration and tab selection have been fixed and tested on the PC. Use revised archive **1.3.11** and its manifest/SHA256: it also fixes the Windows line endings present in package 1.3.10.

On October 14, 2026, the owner confirmed successful CrossMix installation and the firmware upgrade from 1.0.4 to 1.1.1 after copying the card contents to the PC, reformatting as FAT32, and restoring the data. Flashing had failed with the original non-FAT32 format (reported as “extfS”; the exact format was not verified). The console is reported to be running normally on 1.3.11 with firmware 1.1.1. See [the device test report](LOCAL-RELEASE.md).

Detailed results for System Tools, audio/sleep, saves, and the ports used still need to be recorded separately. Address SwanStation separately if that mode is used. Emulator additions and PSP settings PRs are not required at this stage.
