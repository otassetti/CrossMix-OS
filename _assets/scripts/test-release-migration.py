"""Run device helpers against an isolated tree using Git Bash and real jq."""
import json
import pathlib
import subprocess
import sys
import tempfile

repo = pathlib.Path(__file__).resolve().parents[2]
root = pathlib.Path(sys.argv[1]).resolve()
bash = r"C:\Program Files\Git\bin\bash.exe"

def posix(path):
    value = str(path).replace("\\", "/")
    return "/" + value[0].lower() + value[2:]

with tempfile.TemporaryDirectory(prefix="migration-", dir=root) as directory:
    workspace = pathlib.Path(directory)
    sd = workspace / "sdcard"
    internal = workspace / "internal"
    temporary = workspace / "tmp"
    for folder in (sd, internal, temporary):
        folder.mkdir()
    for name in ("System/etc", "System/resources", "System/bin", "Best", "Ports", "trimui/firmwares", "System/backups/firmware_settings/tsp", "Apps/SystemTools/Menu/TOOLS"):
        (sd / name).mkdir(parents=True, exist_ok=True)
    system = internal / "system.json"
    config = sd / "System/etc/crossmix.json"
    state = temporary / "state.json"
    (sd / "System/resources/default_state.json").write_bytes((repo / "System/resources/default_state.json").read_bytes())
    config.write_text(json.dumps({"START TAB": "Tab 4", "SSH": 1}))
    system.write_text(json.dumps({"retrogametab": 1, "favoritetab": 1, "recentplayedtab": 0, "appstab": 1, "portstab": 1, "beststab": 1, "netplaytab": 0}))

    def helper(name):
        source = (repo / "System/usr/trimui/scripts" / name).read_text(encoding="utf-8")
        source = source.replace("/mnt/SDCARD", posix(sd)).replace("/mnt/UDISK", posix(internal)).replace("/etc/trimui_device.txt", posix(internal / "device.txt")).replace("/tmp/", posix(temporary) + "/")
        source = source.replace('export PATH="', 'export PATH="' + posix(root) + ':', 1)
        target = workspace / name
        target.write_text(source, encoding="utf-8", newline="\n")
        return target

    tabs = helper("starttab_switcher.sh")
    restore = helper("restore_fw_settings.sh")

    def run(target, *args, expected=0):
        result = subprocess.run([bash, posix(target), *args], capture_output=True, text=True)
        assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)

    def current_index():
        data = json.loads(state.read_text())
        assert data["list"][0]["type"] == 48
        assert data["list"][0]["title"] == 197
        assert data["list"][1]["title"] == 198
        assert len(data["list"][1]["tabstate"]) == 3
        return data["list"][1]["tabidx"]

    run(tabs)  # Tab 4 is unavailable with only three visible tabs.
    assert current_index() == 0
    run(tabs, "Tab 3")
    assert json.loads(config.read_text())["START TAB"] == "Tab 3"
    run(tabs)
    assert current_index() == 2
    before = config.read_bytes(), state.read_bytes()
    run(tabs, "RecentPlayed", expected=1)
    assert before == (config.read_bytes(), state.read_bytes())
    run(tabs, "--system-tools")
    assert current_index() == 2
    assert json.loads(state.read_text())["list"][2]["type"] == 23
    assert config.read_bytes() == before[0]
    # Compact JSON and enabled Best collections must retain native ordering.
    (sd / "Best/Test").mkdir()
    (sd / "Best/Test/launch.sh").write_text("")
    run(tabs, "Bests")
    assert json.loads((sd / "System/resources/start_state.json").read_text())["list"][1]["tabidx"] == 3
    # Malformed device settings must not replace an existing navigation state.
    old_state = state.read_bytes()
    system.write_text("invalid JSON")
    run(tabs, expected=1)
    assert state.read_bytes() == old_state

    calls = workspace / "restore-calls.txt"
    stub = sd / "Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh"
    stub.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "' + posix(calls) + '"\n', newline="\n")
    run(restore)  # No marker: no restoration.
    assert not calls.exists()
    (internal / "device.txt").write_text("tsp")  # Device file has no final newline.
    marker = sd / "trimui/firmwares/Last_Automatic_Backup.txt"
    marker.write_text("backup.7z\n", newline="\n")
    run(restore)  # Missing archive: no restoration.
    assert not calls.exists()
    (sd / "System/backups/firmware_settings/tsp/backup.7z").write_text("fixture")
    run(restore)
    log = calls.read_text().splitlines()
    assert len(log) == 2 and log[0].endswith(" joystick") and log[1].endswith(" wifi")
    marker.write_text("../unsafe.7z\n", newline="\n")
    run(restore, expected=1)
    assert calls.read_text().splitlines() == log
    marker.write_text("backup.7z\n", newline="\n")
    stub.write_text("#!/bin/sh\nexit 2\n", newline="\n")
    run(restore, expected=1)

print("PASS: visible/hidden tabs, legacy selection, System Tools, malformed JSON, firmware restore and failure cases")
