"""Isolated launcher tests; native CLI argument tests when a host C compiler exists."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
shell = shutil.which("sh") or r"C:\Program Files\Git\bin\bash.exe"


def shell_path(path):
    value = str(path).replace("\\", "/")
    return "/" + value[0].lower() + value[2:] if os.name == "nt" else value


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    path.chmod(0o755)


with tempfile.TemporaryDirectory(prefix="moonlight-test-") as temp:
    root = Path(temp)
    sd = root / "sd card"
    firmware = root / "firmware"
    app = sd / "Apps/MoonlightNextUI"
    app.mkdir(parents=True)
    device = root / "device"
    write(device, "tsp\n")
    info = sd / "System/usr/trimui/scripts/infoscreen.sh"
    write(info, '#!/bin/sh\nprintf "%s\\n" "$@"\n')
    font = sd / "Themes/CrossMix - OS/wqy-microhei.ttf"
    write(font, "font placeholder")
    source = (repo / "Apps/MoonlightNextUI/launch.sh").read_text(encoding="utf-8")
    source = source.replace("/mnt/SDCARD", shell_path(sd))
    source = source.replace("/usr/trimui", shell_path(firmware))
    source = source.replace("/etc/trimui_device.txt", shell_path(device))
    launcher = app / "launch.sh"
    write(launcher, source)

    def run(expected, message=None):
        result = subprocess.run([shell, shell_path(launcher)], cwd=root,
                                capture_output=True, text=True)
        assert result.returncode == expected, (result.stdout, result.stderr)
        if message:
            assert message in result.stdout + result.stderr

    run(1, "binary missing")
    write(device, "brick\n")
    run(1, "original Smart Pro")
    write(device, "tsp\n")
    binary = app / "moonlight-pak"
    write(binary, '#!/bin/sh\nprintf "%s\\n" "$HOME" "$SHARED_USERDATA_PATH" "$MOONLIGHT_FONT"\nexit 0\n')
    run(1, "CLI missing")
    write(firmware / "bin/moonlight", "#!/bin/sh\nexit 0\n")
    font.unlink()
    run(1, "font missing")
    write(font, "font placeholder")
    run(0)
    log = sd / "Data/MoonlightNextUI/logs/frontend.log"
    content = log.read_text()
    assert content.count(shell_path(sd / "Data/MoonlightNextUI")) == 2, content
    assert shell_path(font) in content
    write(binary, "#!/bin/sh\nexit 7\n")
    run(1, "error 7")
    assert not (firmware / "apps").exists()
    print("PASS: launcher prerequisites, independent working directory, SD data, errors")

    # Exercise the real adapter against fake cpufreq files and a fake client.
    cpu = root / "cpu"
    write(cpu / "scaling_governor", "ondemand\n")
    write(cpu / "scaling_max_freq", "1200000\n")
    adapter = root / "adapter.sh"
    adapter_source = (repo / "Apps/MoonlightNextUI/moonlight").read_text()
    adapter_source = adapter_source.replace("CPU=/sys/devices/system/cpu/cpu0/cpufreq",
                                           'CPU="' + shell_path(cpu) + '"')
    write(adapter, adapter_source)
    client = root / "client.sh"
    write(client, '#!/bin/sh\nif [ "$1" = stream ]; then\n'
                  '[ "$(cat "' + shell_path(cpu) + '/scaling_governor")" = performance ] || exit 90\n'
                  '[ "$(cat "' + shell_path(cpu) + '/scaling_max_freq")" = 1608000 ] || exit 91\n'
                  'fi\nexit 7\n')
    for action in ("stream", "pair", "list"):
        result = subprocess.run([shell, shell_path(adapter), action],
                                env=dict(os.environ, MOONLIGHT_CLIENT=shell_path(client)),
                                capture_output=True, text=True)
        assert result.returncode == 7, (result.stdout, result.stderr)
        assert (cpu / "scaling_governor").read_text().strip() == "ondemand"
        assert (cpu / "scaling_max_freq").read_text().strip() == "1200000"
    print("PASS: stream performance policy, restoration on client failure, pair/list passthrough")

    # Compile the actual CLI implementation against a minimal logging declaration.
    # The fake client records arguments, including strings that a shell would expand.
    cc = shutil.which("cc") or shutil.which("gcc")
    if cc and os.name != "nt":
        source_dir = repo / "_assets/sources/moonlight-next-ui/src"
        write(root / "apostrophe.h", "#define ap_log(...) ((void)0)\n")
        harness = r'''
#include "moonlight.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
    ml_config defaults = load_config();
    assert(defaults.low_latency == 1);
    defaults.low_latency = 0;
    assert(save_config(&defaults) == 0);
    assert(load_config().low_latency == 0);
    ml_config cfg = {.active_server = 0, .server_count = 1,
        .width = 1280, .height = 720, .fps = 60, .bitrate = 10000,
        .servers = {{.host = "192.168.1.2"}}};
    assert(ml_stream(&cfg, "Game \"name\" $(touch INJECTED) ; x") == 7);
    cfg.low_latency = 1;
    assert(ml_stream(&cfg, "Game \"name\" $(touch INJECTED) ; x") == 7);
    assert(strcmp(getenv("SDL_RENDER_VSYNC"), "1") == 0);
    cfg.active_server = -1;
    assert(ml_stream(&cfg, "ignored") == -1);
    return 0;
}
'''
        write(root / "test.c", harness)
        write(root / "bin/moonlight", '#!/bin/sh\nprintf "%s\\n" "$@" > "$ARGS_FILE"\nprintf "%s\\n" "$SDL_RENDER_VSYNC" > "$VSYNC_FILE"\nexit 7\n')
        executable = root / "cli-test"
        subprocess.run([cc, "-std=gnu11", "-I" + str(root), "-I" + str(source_dir),
                        str(source_dir / "moonlight_cli.c"), str(source_dir / "stream_control.c"),
                        str(source_dir / "config.c"), str(root / "test.c"),
                        "-o", str(executable)], check=True)
        args_file = root / "args.txt"
        env = dict(os.environ, PATH=str(root / "bin") + ":" + os.environ["PATH"],
                   ARGS_FILE=str(args_file), VSYNC_FILE=str(root / "vsync.txt"),
                   SDL_RENDER_VSYNC="1", SHARED_USERDATA_PATH=str(root))
        subprocess.run([str(executable)], cwd=root, env=env, check=True)
        args = args_file.read_text().splitlines()
        assert args[:4] == ["stream", "192.168.1.2", "-app", 'Game "name" $(touch INJECTED) ; x'], args
        assert not (root / "INJECTED").exists()
        assert args[-3:] == ["-codec", "h264", "-verbose"], args
        assert (root / "vsync.txt").read_text().strip() == "0"
        print("PASS: actual CLI arguments, low-latency config persistence and child-only VSync override")

        guard_test = r'''
#include "stream_control.h"
#include <assert.h>
#include <linux/input.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
static int held;
int ioctl(int fd, unsigned long request, ...) {
    (void)fd; (void)request;
    va_list ap; va_start(ap, request);
    unsigned char *keys = va_arg(ap, unsigned char *); va_end(ap);
    memset(keys, 0, (KEY_MAX + 8) / 8);
    if (held) {
        keys[BTN_SELECT/8] |= 1u << (BTN_SELECT%8);
        keys[BTN_START/8] |= 1u << (BTN_START%8);
    }
    return 0;
}
int main(void) {
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) { usleep(1200000); _exit(9); }
    assert(ml_wait_stream(child, 42) == 9);
    held = 1;
    child = fork();
    assert(child >= 0);
    if (child == 0) { alarm(5); for (;;) pause(); }
    assert(ml_wait_stream(child, 42) == 0);
    return 0;
}
'''
        write(root / "guard-test.c", guard_test)
        subprocess.run([cc, "-std=gnu11", "-I" + str(source_dir),
                        str(source_dir / "stream_control.c"), str(root / "guard-test.c"),
                        "-o", str(root / "guard-test")], check=True)
        subprocess.run([str(root / "guard-test")], check=True, timeout=10)
        print("PASS: stream monitor preserves failures and stops its child on held exit chord")
    else:
        print("SKIP: native CLI test requires a POSIX host C compiler (runs in CI)")

config = json.loads((repo / "Apps/MoonlightNextUI/config.json").read_text())
assert (repo / "Apps/MoonlightNextUI" / config["launch"]).is_file()
assert (repo / "Apps/MoonlightNextUI" / config["icon"]).is_file()
