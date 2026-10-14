"""Verify the actual ZIP's script bytes, without normalizing the tested input."""
import pathlib
import subprocess
import sys
import tempfile
import zipfile

archive = pathlib.Path(sys.argv[1])
bash = r"C:\Program Files\Git\bin\bash.exe"
checked = 0
syntax = (
    "System/usr/trimui/scripts/update_common.sh",
    "System/usr/trimui/scripts/crossmix_update.sh",
    "System/usr/trimui/scripts/starttab_switcher.sh",
    "System/usr/trimui/scripts/restore_fw_settings.sh",
    "System/usr/trimui/scripts/backup_fw_settings.sh",
    "System/usr/trimui/scripts/sdcard_checks.sh",
    "System/usr/trimui/scripts/update_policy.sh",
    "System/usr/trimui/scripts/common_functions.sh",
    "System/usr/trimui/scripts/ota_update.sh",
    "System/usr/trimui/scripts/update_ota_release.sh",
    "System/usr/trimui/scripts/update_notification.sh",
    "Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh",
    "System/starts/_FirmwareCheck.sh",
    "System/starts/°customization.sh",
    "System/starts/°post_starts.sh",
    "System/starts/start_tab.sh",
    "Apps/SystemTools/launch.sh",
)
with zipfile.ZipFile(archive) as package:
    for entry in package.infolist():
        if entry.is_dir():
            continue
        with package.open(entry) as stream:
            prefix = stream.read(5)
        if not entry.filename.endswith(".sh") and not prefix.removeprefix(b"\xef\xbb\xbf").startswith(b"#!"):
            continue
        content = package.read(entry)
        assert b"\r" not in content, f"Windows line endings: {entry.filename}"
        assert not content.startswith(b"\xef\xbb\xbf"), f"BOM: {entry.filename}"
        checked += 1
    with tempfile.TemporaryDirectory(dir=archive.parent, prefix="syntax-") as directory:
        for index, name in enumerate(syntax):
            target = pathlib.Path(directory) / f"script-{index}.sh"
            target.write_bytes(package.read(name))
            result = subprocess.run([bash, "-n", str(target)], capture_output=True, text=True)
            assert result.returncode == 0, f"{name}: {result.stderr}"
print(f"PASS: {checked} scripts have LF and no BOM; {len(syntax)} critical scripts parse directly from ZIP")
