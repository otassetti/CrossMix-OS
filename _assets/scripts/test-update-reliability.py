"""Exercise update failures in an isolated tree; never access a console or disk device."""
import os
import pathlib
import shutil
import subprocess
import tempfile

REPO = pathlib.Path(__file__).resolve().parents[2]
BASH = shutil.which("bash") or r"C:\Program Files\Git\bin\bash.exe"


def shell_path(path):
    value = str(path).replace("\\", "/")
    if len(value) > 1 and value[1] == ":":
        return "/" + value[0].lower() + value[2:]
    return value


with tempfile.TemporaryDirectory(prefix=".update-tests-", dir=REPO) as directory:
    root = pathlib.Path(directory)
    sd = root / "sdcard"
    internal = root / "internal"
    temporary = root / "temporary"
    scripts = sd / "System/usr/trimui/scripts"
    tool_path = sd / "Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh"
    backups = sd / "System/backups/firmware_settings/tsp"
    marker = sd / "trimui/firmwares/Last_Automatic_Backup.txt"
    mounts = root / "mounts"
    device = root / "card.img"
    calls = root / "calls.txt"
    for folder in (scripts, tool_path.parent, backups, marker.parent, internal,
                   temporary, sd / "System/etc", sd / "System/bin", sd / "Roms/GB",
                   root / "etc/wifi"):
        folder.mkdir(parents=True, exist_ok=True)
    (root / "etc/trimui_device.txt").write_text("tsp\n", newline="\n")
    (root / "etc/wifi/wpa_supplicant.conf").write_text("fixture")
    (internal / "system.json").write_text("{}")
    (internal / "joypad.config").write_text("fixture")
    version = sd / "System/usr/trimui/crossmix-version.txt"
    version.write_text("1.3.12\n", newline="\n")
    local_marker = sd / "System/etc/local-release.txt"
    local_marker.write_text("1.3.12\n", newline="\n")
    previous = backups / "backup_previous.7z"
    previous.write_text("previous backup")
    marker.write_text(previous.name + "\n", newline="\n")

    def adapt(source):
        for old, new in (("/mnt/SDCARD", sd), ("/mnt/UDISK", internal),
                         ("/etc/trimui_device.txt", root / "etc/trimui_device.txt"),
                         ("/etc/wifi", root / "etc/wifi"), ("/proc/mounts", mounts)):
            source = source.replace(old, shell_path(new))
        source = source.replace("/tmp/", shell_path(temporary) + "/")
        source = source.replace(" mnt/UDISK/", " internal/")
        source = source.replace("cd / ||", 'cd "' + shell_path(root) + '" ||')
        return source

    stubs = """sync() { return "${SYNC_STATUS:-0}"; }
chmod() { return "${CHMOD_STATUS:-0}"; }
chown() { return "${CHOWN_STATUS:-0}"; }
"""

    def write_script(path, source, mock_permissions=False):
        source = adapt(source)
        if mock_permissions:
            source = source.replace("#!/bin/sh\n", "#!/bin/sh\n" + stubs, 1)
        path.write_text(source, encoding="utf-8", newline="\n")
        path.chmod(0o755)
        return path

    for name in ("update_common.sh", "common_functions.sh", "sdcard_checks.sh",
                 "update_policy.sh", "backup_fw_settings.sh", "restore_fw_settings.sh"):
        write_script(scripts / name, (REPO / "System/usr/trimui/scripts" / name).read_text(encoding="utf-8"), True)
    tool_source = (REPO / "Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh").read_text(encoding="utf-8")
    write_script(tool_path, tool_source, True)
    fake7z = """#!/bin/sh
printf '7zz %s\\n' "$1" >> "$TEST_CALLS"
op="$1"; shift
case "$op" in
    a) shift; archive="$1"; [ "${CREATE_STATUS:-0}" -eq 0 ] || exit "$CREATE_STATUS"
       printf 'new backup' > "$archive" ;;
    t) exit "${TEST_STATUS:-0}" ;;
    l) [ "${LIST_STATUS:-0}" -eq 0 ] || exit "$LIST_STATUS"
       for last in "$@"; do :; done
       [ "${MISSING_MEMBER:-0}" -eq 1 ] || printf 'Path = %s\\n' "$last" ;;
    x) exit "${EXTRACT_STATUS:-0}" ;;
    e) [ "${HELPER_STATUS:-0}" -eq 0 ] || exit "$HELPER_STATUS"
       for arg in "$@"; do case "$arg" in -o*) out="${arg#-o}" ;; esac; done
       for name in update_common.sh sdcard_checks.sh update_policy.sh; do
           cp "$TEST_HELPERS/$name" "$out/$name" || exit 2
       done ;;
    *) exit 2 ;;
esac
"""
    write_script(sd / "System/bin/7zz", fake7z)
    write_script(sd / "System/bin/rsync", '#!/bin/sh\nprintf "rsync\\n" >> "$TEST_CALLS"\nexit "${COPY_STATUS:-0}"\n')
    write_script(sd / "System/bin/fsck.fat", '#!/bin/sh\nprintf "fsck\\n" >> "$TEST_CALLS"\nif [ "$1" = -n ]; then exit "${FSCK_VERIFY_STATUS:-${FSCK_STATUS:-0}}"; fi\nexit "${FSCK_STATUS:-0}"\n')
    write_script(scripts / "busybox", '#!/bin/sh\n[ "$1" = od ] || exit 2\nshift\nexec od "$@"\n')

    def run(path, *args, expected=0, env=None):
        environment = dict(os.environ, TEST_CALLS=shell_path(calls),
                           TEST_HELPERS=shell_path(scripts), TMPDIR=shell_path(temporary))
        environment.update(env or {})
        result = subprocess.run([BASH, shell_path(path), *args], input="", text=True,
                                capture_output=True, env=environment, timeout=30)
        assert result.returncode == expected, (path.name, args, result.returncode, result.stdout, result.stderr)
        return result

    def snippet(name, source):
        return write_script(root / name, "#!/bin/sh\n" + stubs + source)

    # The real settings tool must preserve failures from creation, integrity checks,
    # extraction, ownership changes, and sync. Printed filenames must exist.
    for env in ({"CREATE_STATUS": "2"}, {"TEST_STATUS": "2"}, {"CREATE_STATUS": "1"}):
        run(tool_path, "--backup", expected=1, env=env)
        assert previous.read_text() == "previous backup"
        assert not list(backups.glob("*.partial"))
    result = run(tool_path, "--backup")
    new_name = result.stdout.splitlines()[-1]
    assert (backups / new_name).is_file(), (result.stdout, result.stderr, list(backups.iterdir()))
    assert new_name.startswith("backup_") and new_name.endswith(".7z")
    for restore_type in ("all", "wifi", "joystick", "mainui"):
        run(tool_path, "--restore", shell_path(previous), restore_type, expected=1, env={"EXTRACT_STATUS": "2"})
        run(tool_path, "--restore", shell_path(previous), restore_type, expected=1, env={"TEST_STATUS": "2"})
    run(tool_path, "--restore", shell_path(previous), "wifi", expected=1, env={"LIST_STATUS": "2"})
    run(tool_path, "--restore", shell_path(previous), "wifi", expected=1, env={"CHOWN_STATUS": "1"})
    run(tool_path, "--restore", shell_path(previous), "wifi", expected=1, env={"SYNC_STATUS": "1"})
    run(tool_path, "--restore", shell_path(previous), "wifi")
    run(tool_path, "--restore", shell_path(previous), "joystick", env={"MISSING_MEMBER": "1"})

    # Exercise the automatic marker helper with the real settings tool, not a
    # successful stub. A failed backup must retain both the old archive and marker.
    before = marker.read_bytes()
    for env in ({"CREATE_STATUS": "2"}, {"TEST_STATUS": "2"}):
        run(scripts / "backup_fw_settings.sh", expected=1, env=env)
        assert marker.read_bytes() == before and previous.is_file()
    result = run(scripts / "backup_fw_settings.sh")
    assert marker.read_text().strip() == result.stdout.strip()
    assert (backups / result.stdout.strip()).is_file() and previous.is_file()
    # Failed actual restoration must propagate through the boot restoration helper.
    run(scripts / "restore_fw_settings.sh", expected=1, env={"EXTRACT_STATUS": "2"})

    # Use a synthetic BPB and mount table; no actual disk is opened.
    device.write_bytes(bytes(512))
    def mount(fs="vfat", mode="rw"):
        mounts.write_text(f"{shell_path(device)} {shell_path(sd)} {fs} {mode} 0 0\n", newline="\n")
    mount()
    check = snippet("check.sh", '. "' + shell_path(scripts / "sdcard_checks.sh") + '"\ncheck_filesystem "$@"\n')
    stamp = sd / "System/updates/last_fsck.txt"
    for status in (1, 2, 8):
        run(check, "--force", expected=status, env={"FSCK_STATUS": str(status)})
        assert not stamp.exists()
    run(check, "--force", env={"FSCK_STATUS": "1", "FSCK_VERIFY_STATUS": "0"})
    assert stamp.exists()
    run(check, "--force", expected=8, env={"FSCK_STATUS": "1", "FSCK_VERIFY_STATUS": "8"})
    assert not stamp.exists()
    run(check, "--force")
    assert stamp.exists()
    run(check, env={"FSCK_STATUS": "8"})  # Successful daily cache.
    run(check, "--force", expected=8, env={"FSCK_STATUS": "8"})
    assert not stamp.exists()
    # A legacy date-only stamp must not bypass the newly checked implementation.
    old_stamp = snippet("legacy-stamp.sh", 'date +%Y-%m-%d > "' + shell_path(stamp) + '"\n')
    run(old_stamp)
    run(check, expected=8, env={"FSCK_STATUS": "8"})
    assert not stamp.exists()
    for fs, mode in (("exfat", "rw"), ("ext4", "rw"), ("vfat", "ro")):
        mount(fs, mode)
        calls.write_text("")
        run(check, expected=1)
        assert "fsck" not in calls.read_text() and not stamp.exists()
    mount()
    bpb = bytearray(512); bpb[17] = 1  # FAT12/16 root-entry field.
    device.write_bytes(bpb)
    run(check, expected=1)
    bpb[17] = 0; bpb[22] = 1  # FAT16 size field also excludes FAT32.
    device.write_bytes(bpb)
    run(check, expected=1)
    device.write_bytes(bytes(512))

    # All OTA entry points must stop before invoking any network/bootstrap tools.
    for relative in ("System/usr/trimui/scripts/ota_update.sh",
                     "System/usr/trimui/scripts/update_ota_release.sh",
                     "System/usr/trimui/scripts/update_notification.sh", "_assets/scripts/ota_bootstrap.sh"):
        source = (REPO / relative).read_text(encoding="utf-8")
        deny_network = 'curl() { echo network >> "$TEST_CALLS"; return 99; }\nwget() { echo network >> "$TEST_CALLS"; return 99; }\nip() { echo network >> "$TEST_CALLS"; return 99; }\n'
        source = source.replace("#!/bin/sh\n", "#!/bin/sh\n" + deny_network, 1)
        entry = write_script(root / pathlib.Path(relative).name, source)
        calls.write_text("")
        run(entry)
        assert "network" not in calls.read_text(), relative
    policy = snippet("policy.sh", '. "' + shell_path(scripts / "update_policy.sh") + '"\nota_updates_allowed\n')
    run(policy, expected=1)
    local_marker.unlink()
    for legacy in ("1.3.9", "1.3.10", "1.3.11"):
        version.write_text(legacy)
        run(policy, expected=1)
    version.write_text("1.3.0\n", newline="\n")
    run(policy)

    # Verify that the new installer loads its own helpers from the ZIP, rather
    # than the old helpers installed on a 1.3.11 card.
    installer = (REPO / "System/usr/trimui/scripts/crossmix_update.sh").read_text(encoding="utf-8")
    header = installer[:installer.index("echo performance >")]
    (sd / "CrossMix-OS_v1.3.12.zip").write_text("fixture")
    live_common = scripts / "update_common.sh"
    packaged = root / "package-helpers"
    packaged.mkdir()
    for name in ("update_common.sh", "sdcard_checks.sh", "update_policy.sh"):
        shutil.copyfile(scripts / name, packaged / name)
    live_common.write_text("exit 88\n")
    entry = write_script(root / "installer-header.sh", header)
    run(entry, env={"TEST_HELPERS": shell_path(packaged)})
    run(entry, expected=1, env={"HELPER_STATUS": "2", "TEST_HELPERS": shell_path(packaged)})

    # Migration must stop before the completion/reboot path when copying fails.
    functions = installer[installer.index("migration_failed() {"):installer.index("# Function to copy specified keys")]
    source = root / "old-saves"
    source.mkdir()
    (source / "game.srm").write_text("save fixture")
    backup_zip = sd / "CrossMix-OS_v1.3.12.zip"
    def migration_call(command, expected, env):
        completed = root / "completed"
        completed.unlink(missing_ok=True)
        prefix = f'BCK_DIR="{shell_path(source)}"\nUPDATE_FILE="{shell_path(backup_zip)}"\n'
        entry = snippet("migration.sh", prefix + functions + "\n" + command + '\nprintf complete > "' + shell_path(completed) + '"\n')
        run(entry, expected=expected, env=env)
        assert completed.exists() == (expected == 0)
        assert backup_zip.exists() and (source / "game.srm").read_text() == "save fixture"
    destination = shell_path(root / "new-saves")
    for status in (23, 28):
        migration_call(f'restore_files Saves "{shell_path(source)}" "{destination}" "*"\n', status, {"COPY_STATUS": str(status)})
        migration_call(f'migrate_ra_flat Saves "{shell_path(source)}" "{destination}"\n', status, {"COPY_STATUS": str(status)})
    migration_call(f'restore_files Saves "{shell_path(source)}" "{destination}" "*"\n', 0, {})
    (source / "GB/core").mkdir(parents=True)
    (source / "GB/core/other.srm").write_text("fixture")
    migration_call(f'migrate_ra_flat Saves "{shell_path(source)}" "{destination}"\n', 23, {"COPY_STATUS": "23"})

    # When a host 7-Zip is installed, also verify actual archive members and
    # extraction through the settings tool. All output paths remain in this fixture.
    sevenzip = shutil.which("7zz") or shutil.which("7z")
    if not sevenzip and pathlib.Path(r"C:\Program Files\7-Zip\7z.exe").is_file():
        sevenzip = r"C:\Program Files\7-Zip\7z.exe"
    if sevenzip:
        executable = '"' + shell_path(sevenzip) + '"'
        # Windows 7-Zip prints member paths with backslashes; the device's Linux
        # 7zz prints slashes. Preserve the exit status while matching that output.
        wrapper = '#!/bin/sh\nif [ "$1" = l ]; then\nlisting=$(' + executable + ' "$@"); status=$?\nprintf "%s\\n" "$listing" | ' + r"tr '\134' '/'" + '\nexit "$status"\nfi\nexec ' + executable + ' "$@"\n'
        write_script(sd / "System/bin/7zz", wrapper)
        real_source = tool_source.replace('relative_path="${path#/}"', 'relative_path="${path#' + shell_path(root) + '/}"')
        # 7-Zip's -o/ argument must never extract to the host root.
        real_source = real_source.replace('-o/', '-o"' + shell_path(root) + '"')
        write_script(tool_path, real_source, True)
        result = run(tool_path, "--backup")
        real_archive = backups / result.stdout.splitlines()[-1]
        wifi = root / "etc/wifi/wpa_supplicant.conf"
        wifi.write_text("changed")
        result = run(tool_path, "--restore", shell_path(real_archive), "wifi")
        assert wifi.read_text() == "fixture", (result.stdout, result.stderr)
        run(tool_path, "--restore", shell_path(real_archive), "joystick")
        assert not (internal / "joypad_right.config").exists()
        result = run(scripts / "backup_fw_settings.sh")
        assert marker.read_text().strip() == result.stdout.strip()
        print("PASS: real 7-Zip backup, selective restore, optional calibration, and automatic marker")

print("PASS: firmware backup/restore and marker preservation; FAT32 and filesystem errors; OTA guards; packaged updater helpers; migration failures")
