# Local release from main — TrimUI Smart Pro

**Revised local version: 1.3.11.** The two high-priority problems identified in the [issue and PR review](RELEASE-REVIEW.md) have been addressed: firmware settings restoration and MainUI/System Tools navigation. Isolated tests pass. On October 14, 2026, the owner confirmed successful installation and firmware flashing on the original Smart Pro after reformatting the SD card as FAT32. The device is reported to be running normally with CrossMix 1.3.11 and firmware 1.1.1. Use the `release-fixed` folder instead of the earlier 1.3.9 or 1.3.10 archives.

Prepared on October 13, 2026 for the original Smart Pro, firmware 1.0.4 (`tina.raymanfen.20240503.141812`), running CrossMix 1.3 with OTA hotfixes. The reported “1.3.3” may refer to hotfix 1.3.0.3. Check `System/usr/trimui/crossmix-version.txt` and `crossmix-hotfix-version.txt` on the card for the exact installed versions.

## Device test report — October 14, 2026

- Version 1.3.10 encountered Windows line-ending errors. The build normalization in 1.3.11 resolved them, and the CrossMix update completed successfully.
- The firmware upgrade from 1.0.4 to 1.1.1 initially failed with the SD card in a non-FAT32 format (reported as “extfS”; the exact original filesystem was not verified).
- The owner copied the card contents to the PC, reformatted the card as FAT32, and copied the data back. The firmware upgrade then completed smoothly.
- Current owner-reported state: **CrossMix 1.3.11 + firmware 1.1.1, device running normally**.

This records the owner's device test, not a directly observed automated test. Individual results for settings restoration, System Tools, audio after sleep, emulator saves, and ports have not been recorded separately.

## Follow-up source fixes — October 14, 2026

The next local build defaults to **1.3.12**. It includes four additional high-priority fixes:

- Firmware settings backups are created as temporary archives, checked with 7-Zip, and then published. The printed filename matches the archive created. The automatic backup marker changes only after a verified backup; previous archives are retained. Restoration errors reach the boot helper so customization can retry. Missing optional calibration files are skipped.
- Save and user-file migration stops on copy or move errors, preserves the backup and release ZIP, and cancels the completion message and automatic reboot. The installer loads its own checked helpers from the ZIP, so an older installed helper cannot bypass the new preflight.
- Local packages contain `System/etc/local-release.txt` and use manual ZIP updates. OTA bootstrap, release download, and background update checks stop before contacting upstream. The earlier personal versions 1.3.9, 1.3.10, and 1.3.11 are also protected when the new updater scripts are installed.
- Firmware preparation and CrossMix migration check the mounted card and its FAT32 boot-sector layout before proceeding. Filesystem checker errors stop the update and are never stamped as successful. Legacy date-only check stamps are ignored. Previous automatic FAT repair behavior is retained; a repair status of 1 is accepted only if a second read-only check succeeds. A failed final check requires checking the card on a PC before retrying.

`_assets/scripts/test-update-reliability.py` exercises archive and copy failures, marker preservation, FAT32/FAT16 and unsupported/read-only cards, failed filesystem checks, OTA guards, and loading packaged helpers. It also tests real 7-Zip backup and selective restoration when host 7-Zip is available. These checks and the existing archive safety tests pass on the PC. **No 1.3.12 release ZIP has been built or tested on the console yet.**

To upgrade the working 1.3.11 card, build the 1.3.12 ZIP, retain a full PC backup, check free space against the new manifest, and copy that single unextracted ZIP to the FAT32 card root. The installed 1.3.11 wizard extracts the new installer from the ZIP; it does not need the historical pre-reboot helper replacements described below. If migration stops, keep the ZIP, log, and `_Updates` backup for recovery on the PC. Automatic rollback is not provided.

The medium-priority version comparison, SwanStation widescreen, and GitHub release packaging findings remain separate work.

## What was checked

- Local commit `206d612fdef83972ed54a17de955125d0c0b3528` matched the latest upstream commit returned by GitHub during the review.
- The author describes main as the development branch and releases as the ready-to-use packages: https://github.com/cizia64/CrossMix-OS/issues/20#issuecomment-2156267130
- `.github/workflows/CrossMix Release.yml` extracts compressed RetroArch cores, removes development files, creates `RetroArch/default_config.7z`, and packages the SD card contents. Pushing a `v*` tag triggers a draft GitHub release. The workflow does not update the internal version, which remains 1.3.0 on main.
- Issue 513 reports a successful main installation using stock 1.1.0 assets. This is a user's report, not an instruction from Cizia: https://github.com/cizia64/CrossMix-OS/issues/513#issuecomment-3279130140
- Cizia's PR 548 adds firmware 1.1.1 and its upgrade wizard: https://github.com/cizia64/CrossMix-OS/pull/548
- The official guide describes updating with an unextracted ZIP at the card root and replacing the migration script beforehand: https://github.com/cizia64/CrossMix-OS/wiki/Installation
  Its firmware 1.0.4 instructions apply to the stable release. For main, the repository contents and PR 548 are more recent.

## Local fixes included

1. `MinFwVersion.txt` now references 1.1.1 / 20251128, whose two archive volumes are included. Previously it requested the missing 1.1.0 / 20250505 archive.
2. Fixed the file-presence check for the previous firmware backup.
3. Added a ZIP integrity check before moving the current installation. Preserved the actual extraction exit status, previously hidden by `sync`, and stopped migration on extraction failure. This does not provide automatic rollback.
4. Restored user themes from Themes and PICO-8 carts from the backup. Updated files in bundled themes take precedence.
5. Copied Dreamcast BIOS `.bin` files directly under `BIOS/dc` into `BIOS/dc/flycast`, without recursively copying that destination into itself.
6. Preserved `System/backups`, including firmware settings backups.
7. Fixed Wi-Fi and calibration restoration in `°customization.sh`. The helper `restore_fw_settings.sh` explicitly reads the device model, supports files without a final newline, and handles missing backups. Failed restoration leaves customization pending so it can retry at the next boot.
8. Adapted PR 482: Home/Navigation state uses the firmware 1.1.1 language IDs 197/198, tab indices follow the visible tabs, an unavailable old preference falls back to Games, and System Tools navigation is generated dynamically. Existing “Tab 1” through “Tab 7” choices are retained; unavailable choices are rejected without changing settings.

The existing migration already restores RetroArch, PSP, NDS, N64 and other emulator saves. RetroArch's old console subfolders are flattened into the per-core layout. Identical game names under the same core can collide. Save states may be incompatible with newer cores, so keep in-game saves too. Custom RetroArch configurations are not restored wholesale; RetroAchievements credentials are migrated. Check settings and services after installation. ScummVM ROMs are moved into the `GAMES` subfolder.

## Building locally

Run `_assets/scripts/build-local-release.ps1` with `-OutputDirectory` pointing to a PC folder with approximately 20 GB free. Git and 7-Zip are required; an ARM compiler is not needed.

The script exports HEAD, applies local changes to tracked files, normalizes runtime scripts to Linux line endings, preserves UTF-8 filenames, extracts cores, tests the firmware and ZIP, and produces a SHA256 checksum and manifest. Untracked files are excluded except for the explicitly listed runtime resources and helpers. The final ZIP is checked for scripts containing CRLF or a BOM. The build creates the local-release marker and records the manual OTA policy in the manifest.

The default local version is now **1.3.12**, a personal test build rather than an official release. Its numeric version allows the older wizard to detect an upgrade from 1.3.11. The internal version is changed only in the build staging directory. The script does not create tags, commits, or GitHub releases.

Previously built and tested **1.3.11** archive: **2,491,599,409 bytes** (approximately 2.5 GB). Unpacked contents: **4,936,344,676 bytes** (approximately 4.9 GB). Allow **10 GB free before copying that ZIP**; use the new manifest for 1.3.12 sizes. The historical accompanying folder `Avant-redemarrage/System/usr/trimui/scripts` contains the two 1.3.11 files used in installation step 4 below.

Isolated tests cover firmware restoration, tab selection, valid/corrupt archives, and extraction errors 2 and 7. Verification directly against the corrected ZIP confirms 656 scripts with LF and no BOM, and checks the syntax of nine critical scripts without normalizing their contents during testing. These checks do not replace testing on the console.

## Installation used for the validated 1.3.11 build

1. Turn off the console, remove the card, and back up **the entire card to your PC**. The `_Updates` backup on the same card does not replace this copy. If possible, also back up firmware settings (Wi-Fi, calibration and MainUI) before starting. Check the card's filesystem on the PC. Use **FAT32 for this firmware upgrade**: in the owner's test, flashing failed on the original non-FAT32 card and succeeded after copying the contents to the PC, reformatting as FAT32, and restoring the contents.
2. Allow at least the ZIP size **plus the unpacked size** listed in the manifest, with another 1–2 GB for firmware preparation and restored files. The stable guide mentions 7 GB, but main has grown: use the actual sizes. The updater requires 5000 MB free after copying the ZIP; the wizard also checks for at least 20 MB free in internal storage.
3. Copy **one** `CrossMix-OS_v1.3.11.zip`, unextracted, to the card root. Remove other `CrossMix-OS_v*.zip` files from that root before booting.
4. Copy these two files from the accompanying `Avant-redemarrage` folder or from the ZIP to the same locations on the card, replacing the existing files:
   - `System/usr/trimui/scripts/crossmix_update.sh`
   - `System/usr/trimui/scripts/update_common.sh`
   Preserve their Linux line endings. Do not overwrite the whole current installation with extracted release files. Do not replace `_FirmwareCheck.sh` with main's version beforehand: the new firmware resources are not installed yet.
5. Reinsert the card, connect power, and boot. Accept the proposed update and let migration finish. **“Testing archive” is the ZIP integrity check before the current installation is moved.** It can take several minutes. The old system is moved into `_Updates/Backup_CrossMix_v…`, with a log in `_Updates`.
6. After CrossMix installation, the new wizard detects firmware 1.0.4 and prepares the included Smart Pro firmware **1.1.1**. Follow the displayed instructions to shut down and boot with **VOL− + POWER** to flash it. Do not interrupt flashing. Firmware upgrades can reset internal settings; backups are retained in `System/backups`.
7. Check sound, controls, Wi-Fi, favorites, a RetroArch save, PSP/NDS saves if used, and PortMaster. Re-enable desired services and verify RetroAchievements credentials. Keep the PC backup and `_Updates` until several games have been validated. Avoid OTA on the original 1.3.11 package: it still uses the official repository and can replace the local scripts. The new 1.3.12 source disables OTA for local builds.

## Limitations

PC build checks do not validate firmware flashing or execution on the console. The owner has now reported successful installation, firmware flashing, and normal operation; detailed checks of individual features remain unrecorded. No direct access to the card or console was used to prepare this package. If extraction fails after the old installation has been moved, retain the ZIP, log and backup, and recover the card on the PC. Do not treat that installation as complete.

## Preventing line-ending errors

The 1.3.10 ZIP still contained CRLF scripts, including `update_common.sh`. Version 1.3.11 normalizes scripts in the temporary build directory. `.gitattributes` requires LF for `.sh` files on future changes. The build rejects a ZIP that still contains a script with CRLF or a BOM; files with a shebang but no `.sh` extension are checked too. Each release requires neither a manual rewrite of the source files nor a change to global Git settings.

To retry after the earlier error, replace the two scripts from `Avant-redemarrage`, remove the old ZIP from the card root, and copy only the unextracted 1.3.11 ZIP there.
