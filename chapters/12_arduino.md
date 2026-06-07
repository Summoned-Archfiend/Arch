# Programming an Arduino from VSCode

This chapter covers programming an `Arduino Nano R4` (Renesas `RA4M1` / `R7FA4M1AB`) from
`VSCode` on Arch, driven entirely by `arduino-cli`. No Arduino IDE, and no Arduino `VSCode`
extension. If you do not own an Arduino you can skip this chapter, although the `udev` and
serial-port sections are useful for anyone wiring up a USB device that needs non-root access.

Here is the board at a glance:

| | |
|---|---|
| Board | Arduino Nano R4 |
| FQBN | `arduino:renesas_uno:nanor4` |
| Core | `arduino:renesas_uno` |
| Port | `/dev/ttyACM0` |
| IntelliSense | clangd (system `/usr/bin/clangd`) |

## Why it is set up this way

I tried the obvious route first, the "Arduino Community Edition" `VSCode` extension, and it
would not install. Its hard dependency `ms-vscode.cpptools` is a roughly `100MB` download, and
the marketplace fetch aborted every single time on this machine. Small extensions installed
fine, only the big one failed, so it is a flaky large transfer and not a broken marketplace.

So I dropped the extension entirely and built the lab on `arduino-cli`, which has its own
resuming downloader and pulled the `95MB` ARM toolchain without complaint. The pieces are:

- **Build and upload:** `arduino-cli`, wired into `VSCode` as Tasks, no extension needed.
- **IntelliSense:** clangd, already on the system via `pacman`, not `cpptools`. clangd reads a
  generated `.clangd` config so autocomplete works in `.ino` files.
- **Debugging:** serial prints for the normal case. Real step debugging is possible but needs
  an external SWD probe, because the Nano R4 has no onboard debugger.

Everything below is enough to rebuild this from nothing.

## From-scratch setup

### 1. Install arduino-cli and a core

```bash
sudo pacman -S arduino-cli          # or: curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
arduino-cli config init
arduino-cli core update-index
arduino-cli core install arduino:renesas_uno
```

`arduino-cli core install` is the one big download. It grabs the Renesas/ARM toolchain
(`arm-none-eabi-gcc`), `bossac`, `dfu-util`, and `openocd`. This is also where the original
extension fell over, so doing it through `arduino-cli` is the whole trick.

Confirm the board is seen (plug it in first, genuine boards self-identify):

```bash
arduino-cli board list
# /dev/ttyACM0  serial  Arduino Nano R4  arduino:renesas_uno:nanor4  arduino:renesas_uno
```

### 2. Serial port access

The port `/dev/ttyACM0` is owned by `root:uucp`. Add yourself to `uucp` so you can read it (the
serial monitor), then log out and back in for it to take effect:

```bash
sudo usermod -aG uucp $USER
```

### 3. Upload permission (the udev rule)

Uploading is separate from the serial port, and this is the fiddly part. The Nano R4 flashes
over a **DFU USB bootloader**, a raw USB device that `uucp` does not cover, so without a rule
the upload dies with `LIBUSB_ERROR_ACCESS`.

The fix is a `udev` rule, and the file number matters. `uaccess` (which hands the device to
whoever is logged into the local session) is applied by systemd's `73-seat-late.rules`. A rule
numbered above `73` runs too late, the tag is not set when systemd checks, and nothing happens.
So the file has to sort **below 73**:

```bash
sudo tee /etc/udev/rules.d/70-arduino.rules >/dev/null <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="2341", TAG+="uaccess"
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", TAG+="uaccess"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add
```

Unplug and replug the board, then check:

```bash
getfacl /dev/ttyACM0      # want a line: user:<you>:rw-
```

If that line is missing (for example your login is not a local "seat"), skip `uaccess` and just
open the permissions, which has no session dependency:

```bash
printf 'SUBSYSTEM=="usb", ATTRS{idVendor}=="2341", MODE="0666"\nSUBSYSTEM=="tty", ATTRS{idVendor}=="2341", MODE="0666"\n' | sudo tee /etc/udev/rules.d/70-arduino.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --action=add
```

`MODE="0666"` lets any local user open the port, which is fine on a personal machine.

> **Note**
> If your shell is `ble.sh`, it drops into a MULTILINE buffer for heredocs. Press `Ctrl+J` to
> run it (plain Enter just adds a line), and `Ctrl+C` to cancel.

### 4. VSCode extensions

```bash
code --install-extension llvm-vs-code-extensions.vscode-clangd   # IntelliSense engine
code --install-extension ms-vscode.vscode-serial-monitor         # serial monitor UI
code --install-extension marus25.cortex-debug                    # SWD debugging (needs a probe)
```

`cpptools` is deliberately not used, it is the download that fails. clangd does the same job
here and is already installed system-wide via `pacman`.

### 5. Project files

These live in the project folder and are what tie the lab together:

- `.vscode/settings.json` points clangd at `/usr/bin/clangd` with a `--query-driver` allowlist
  covering every `.arduino15` toolchain, and maps `*.ino` to C++ for highlighting.
- `.vscode/tasks.json` holds Compile / Upload / Upload & Monitor / Serial Monitor /
  Refresh IntelliSense / List Boards. `FQBN` and `PORT` live at the top as env vars.
- `keybindings.json` (user level) binds the shortcuts below.
- `.clangd` is the generated IntelliSense config. Do not hand-edit it.
- `.vscode/gen-clangd.py` regenerates `.clangd`. It reads the real compiler and include paths
  out of `arduino-cli`'s compile database, so it works for any board, not just this one.
- `.vscode/launch.json` is the cortex-debug config for hardware debugging.

## Daily workflow

Open the **folder** (not a loose file), and keep the `.ino` you are working on as the focused
editor tab. The tasks act on whichever sketch is open.

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+B` | Compile the open sketch |
| `F6` | Upload & Monitor: compile, flash, then stream serial output |
| `F7` | Open the serial monitor only |

Prefer menus: `Terminal` then `Run Task...` lists every task. Output shows in the terminal panel
at the bottom. `Ctrl+C` in that panel stops the monitor.

## The `ard` helper script

`ard` is a small subcommand-based CLI that wraps the compile, upload, and monitor steps so I do
not have to retype the FQBN and port every time. It is symlinked onto my `PATH`, so I can run
`ard` from any sketch folder. It works for any board: pass the FQBN, or let it auto-detect a
connected one.

Install it from a fresh checkout:

```bash
chmod +x bin/ard
ln -sf "$PWD/bin/ard" ~/.local/bin/ard               # ~/.local/bin is on PATH
mkdir -p ~/.local/share/man/man1                     # man page
ln -sf "$PWD/man/ard.1" ~/.local/share/man/man1/ard.1
```

Use it:

```bash
ard upload                 # auto-detect board + port, build + flash current sketch
ard flash                  # ... then open the serial monitor
ard compile ~/sk/Blink     # compile a specific sketch, no flashing
ard up -b arduino:avr:uno  # force a board FQBN
ard monitor                # serial monitor only
ard list                   # what is plugged in
ard help                   # built-in help (with logo)
ard version                # version
man ard                    # full manual
```

| Command | Does | Aliases |
|---|---|---|
| `upload [sketch]` | Compile and flash | `up` |
| `compile [sketch]` | Compile only | `build` |
| `flash [sketch]` | Compile, flash, then monitor | `run` |
| `monitor` | Open the serial monitor | `mon` |
| `list` | List connected boards | `boards`, `ls` |
| `help` / `version` | Help (with logo) / version | |

| Option | Meaning |
|---|---|
| `-b, --fqbn FQBN` | Board, e.g. `arduino:renesas_uno:nanor4`. Omit to auto-detect. A bare `packager:arch:board` arg also works. |
| `-p, --port PORT` | Serial port. Defaults to auto-detected, then `/dev/ttyACM0`. |
| `-r, --baud RATE` | Monitor baud rate. Default `115200`. |
| `-h, --help` / `-V, --version` | Help / version. |

Auto-detect reads `arduino-cli board list`, so for a genuine board that self-identifies I can
run `ard upload` with no other arguments. Clones that do not report an FQBN need it passed
explicitly. Upload still depends on the `udev` rule from setup step 3, an upload fails with
`LIBUSB_ERROR_ACCESS` if that is not in place.

It also finds the sketch for me: run `ard` from anywhere in the project and if the current folder
is not a sketch (the project root, say) it looks one level down and uses the single sketch it
finds, or lists them if there is more than one.

There is only one copy of the tool, `bin/ard`, symlinked to `~/.local/bin/ard`. Nothing lives in
`.bashrc`, so the installed command and the project file can never drift apart.

### The script

If you ever need to recreate it, here is the whole thing:

```bash
#!/usr/bin/env bash
#
# ard - Arduino build/upload/monitor helper built on arduino-cli.
# Subcommand-based CLI. See `ard help` or `man ard`.
#
set -euo pipefail

ARD_VERSION="1.0.0"
DEFAULT_BAUD="115200"
PORT_FALLBACK="/dev/ttyACM0"

# ---- output helpers -------------------------------------------------------
if [[ -t 1 ]]; then C_INFO=$'\033[1;36m'; C_OK=$'\033[1;32m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else C_INFO=""; C_OK=""; C_DIM=""; C_OFF=""; fi
err()  { printf 'ard: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
info() { printf '%s==>%s %s\n' "$C_INFO" "$C_OFF" "$*"; }
ok()   { printf '%s[ok]%s %s\n' "$C_OK" "$C_OFF" "$*"; }

banner() {
cat <<'BANNER'
   __ _ _ __ __| |
  / _` | '__/ _` |
 | (_| | | | (_| |
  \__,_|_|  \__,_|
BANNER
}

usage() {
  banner
  cat <<EOF

${C_DIM}ard ${ARD_VERSION} - compile, upload and monitor Arduino sketches (wraps arduino-cli).${C_OFF}

USAGE
    ard <command> [sketch] [options]

COMMANDS
    upload   [sketch]   Compile and flash the board        (alias: up)
    compile  [sketch]   Compile only, do not flash          (alias: build)
    flash    [sketch]   Compile, flash, then open monitor   (alias: run)
    monitor             Open the serial monitor             (alias: mon)
    list                List connected boards               (alias: boards, ls)
    help                Show this help
    version             Show version

OPTIONS
    -b, --fqbn FQBN     Board FQBN (default: auto-detect, e.g. arduino:avr:uno)
    -p, --port PORT     Serial port (default: auto-detect, else ${PORT_FALLBACK})
    -r, --baud RATE     Monitor baud rate (default: ${DEFAULT_BAUD})
    -h, --help          Show this help
    -V, --version       Show version

ARGUMENTS
    sketch   Path to a sketch folder. Defaults to the current directory; if that is
             not a sketch, ard looks one level down and picks the sketch it finds.

EXAMPLES
    ard upload                 # auto-detect board, build + flash current sketch
    ard flash                  # ... then open the serial monitor
    ard compile ~/sk/Blink     # just compile a specific sketch
    ard up -b arduino:avr:uno  # force a board
    ard list                   # what is plugged in

See 'man ard' for the full manual.
EOF
}

command -v arduino-cli >/dev/null || die "arduino-cli not found on PATH"

# ---- subcommand -----------------------------------------------------------
[[ $# -eq 0 ]] && { usage; exit 0; }
CMD=""
case "$1" in
  upload|up)            CMD="upload";  shift ;;
  compile|build)        CMD="compile"; shift ;;
  flash|run)            CMD="flash";   shift ;;
  monitor|mon)          CMD="monitor"; shift ;;
  list|boards|ls)       CMD="list";    shift ;;
  help|-h|--help)       usage; exit 0 ;;
  version|-V|--version) printf 'ard %s\n' "$ARD_VERSION"; exit 0 ;;
  -*)                   die "unknown option '$1' (try 'ard help')" ;;
  *)                    die "unknown command '$1' (try 'ard help')" ;;
esac

# ---- options + positional sketch -----------------------------------------
FQBN=""; PORT=""; BAUD="$DEFAULT_BAUD"; DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--fqbn)    FQBN="${2:?--fqbn needs a value}"; shift 2 ;;
    -p|--port)    PORT="${2:?--port needs a value}"; shift 2 ;;
    -r|--baud)    BAUD="${2:?--baud needs a value}"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -V|--version) printf 'ard %s\n' "$ARD_VERSION"; exit 0 ;;
    -*)           die "unknown option '$1' (try 'ard help')" ;;
    *)            if [[ "$1" == *:*:* ]]; then FQBN="$1"; else DIR="$1"; fi; shift ;;
  esac
done
DIR="${DIR:-.}"

# ---- list needs nothing else ---------------------------------------------
if [[ "$CMD" == "list" ]]; then arduino-cli board list; exit $?; fi

# ---- auto-detect FQBN / port from the connected board --------------------
if [[ -z "$FQBN" || -z "$PORT" ]]; then
  read -r DET_PORT DET_FQBN < <(
    arduino-cli board list --format json 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for p in d.get("detected_ports", []):
    addr = p.get("port", {}).get("address", "")
    boards = p.get("matching_boards") or []
    fqbn = boards[0].get("fqbn", "") if boards else ""
    if addr:
        print(addr, fqbn)
        break
') || true
  [[ -z "$PORT" ]] && PORT="${DET_PORT:-$PORT_FALLBACK}"
  [[ -z "$FQBN" ]] && FQBN="${DET_FQBN:-}"
fi

# ---- monitor needs only a port -------------------------------------------
if [[ "$CMD" == "monitor" ]]; then
  info "monitoring ${PORT} @ ${BAUD} baud (Ctrl+C to stop)"
  exec arduino-cli monitor -p "$PORT" -c baudrate="$BAUD"
fi

# ---- resolve the sketch folder (build/flash/compile) ---------------------
[[ -n "$FQBN" ]] || die "no FQBN given and none auto-detected. Pass one (e.g. -b arduino:avr:uno) or run 'ard list'."
[[ -d "$DIR" ]] || die "directory not found: $DIR"
DIR="$(cd "$DIR" && pwd)"
is_sketch() { [[ -f "$1/$(basename "$1").ino" ]]; }
if ! is_sketch "$DIR"; then
  mapfile -t SKETCHES < <(shopt -s nullglob; for d in "$DIR"/*/; do d="${d%/}"; is_sketch "$d" && echo "$d"; done)
  if   [[ ${#SKETCHES[@]} -eq 1 ]]; then DIR="${SKETCHES[0]}"
  elif [[ ${#SKETCHES[@]} -gt 1 ]]; then
    err "multiple sketches under $(basename "$DIR"):"; printf '  %s\n' "${SKETCHES[@]##*/}" >&2
    die "pick one, e.g. 'ard ${CMD} ${SKETCHES[0]##*/}'"
  else
    die "no sketch here. A sketch is a folder with a matching .ino (e.g. Blink/Blink.ino). cd into one, or pass it."
  fi
fi

info "board=${FQBN}  port=${PORT}  sketch=${DIR}"

case "$CMD" in
  compile)
    arduino-cli compile -b "$FQBN" "$DIR"
    ok "compiled (not uploaded)"
    ;;
  upload)
    arduino-cli compile -b "$FQBN" -u -p "$PORT" "$DIR"
    ok "uploaded to ${PORT}"
    ;;
  flash)
    arduino-cli compile -b "$FQBN" -u -p "$PORT" "$DIR"
    ok "uploaded to ${PORT}"
    info "monitoring ${PORT} @ ${BAUD} baud (Ctrl+C to stop)"
    exec arduino-cli monitor -p "$PORT" -c baudrate="$BAUD"
    ;;
esac
```

## Compiling and uploading sketches by hand

The `ard` script above is the quick path. The raw commands it runs are below, in case you want
them directly or need to tweak flags.

> **Note**
> Sketch-folder rule: every sketch lives in its own folder, and the main `.ino` must share the
> folder's name (for example `Blink/Blink.ino`). The tools build the folder, not the file.

Create a new sketch:

```bash
arduino-cli sketch new ~/Projects/ArduinoWings/MySketch   # makes MySketch/MySketch.ino
```

Compile (build only, no flashing):

```bash
arduino-cli compile -b arduino:renesas_uno:nanor4 ~/Projects/ArduinoWings/MySketch
```

In `VSCode` that is just `Ctrl+Shift+B` with the `.ino` focused. Success prints memory usage
(`Sketch uses NNNN bytes ...`). Errors show in the terminal and the Problems panel.

Upload (compile then flash):

```bash
arduino-cli compile -b arduino:renesas_uno:nanor4 \
  --build-path ~/Projects/ArduinoWings/MySketch/build ~/Projects/ArduinoWings/MySketch
arduino-cli upload  -b arduino:renesas_uno:nanor4 -p /dev/ttyACM0 \
  --input-dir ~/Projects/ArduinoWings/MySketch/build ~/Projects/ArduinoWings/MySketch
```

In `VSCode`: `F6`. The board resets and runs the new program right away.

## Where to see Serial.println output

Your sketch needs `Serial.begin(115200);` (or another rate). Logs show in the bottom panel of
`VSCode`, two ways:

- **Task (simplest):** `F7` (or the "Arduino: Serial Monitor (115200)" task) runs
  `arduino-cli monitor` in a terminal tab. `F6` opens it automatically after uploading. `Ctrl+C`
  stops it.
- **Serial Monitor extension (richer):** click the SERIAL MONITOR tab next to Terminal, set Port
  `/dev/ttyACM0` and Baud `115200`, click Start Monitoring. The input box sends data back to the
  board.

> **Note**
> Only one program can hold the port. If it says busy, close the other monitor or terminal first,
> and likewise before uploading.

## Adding a new board (installing a core)

A core is the toolchain plus board definitions for a chip family. Install it once per family,
then every board in that family reuses it. The `udev` rule and `uucp` access already cover all
genuine Arduino boards, so you do not redo those.

1. Refresh the index and find the core:

   ```bash
   arduino-cli core update-index
   arduino-cli core search nano
   ```

2. Install it:

   ```bash
   arduino-cli core install <packager>:<arch>
   ```

   | Board | Core |
   |---|---|
   | Uno, Nano (classic), Mega (ATmega) | `arduino:avr` |
   | Nano R4, Uno R4 (Renesas, this project) | `arduino:renesas_uno` |
   | Nano 33 IoT, Zero (SAMD) | `arduino:samd` |
   | Nano 33 BLE, Nano RP2040 (mbed) | `arduino:mbed_nano` |

   Third-party cores (ESP32, ESP8266) need their board-manager URL added first:

   ```bash
   arduino-cli config add board_manager.additional_urls \
     https://espressif.github.io/arduino-esp32/package_esp32_index.json
   arduino-cli core update-index
   arduino-cli core install esp32:esp32
   ```

3. Find the FQBN (plug the board in, genuine ones self-identify):

   ```bash
   arduino-cli board list            # FQBN + port for connected boards
   arduino-cli board listall nano    # FQBNs available in an installed core
   ```

4. Point the lab at it: edit `FQBN` (and `PORT` if it changed) at the top of
   `.vscode/tasks.json`.

5. Refresh IntelliSense for the new board: run the "Arduino: Refresh IntelliSense" task, then
   `Ctrl+Shift+P` and "clangd: Restart language server". `gen-clangd.py` auto-detects the right
   compiler (avr, arm, xtensa), so no edits are needed.

> **Note**
> Non-Arduino USB vendors: the upload rule matches Arduino's vendor ID `2341`. A board from
> another vendor (many ESP32 boards use a CH340 `1a86` or CP2102 `10c4` chip) needs its
> `idVendor` added to `/etc/udev/rules.d/70-arduino.rules`. Plain serial boards usually just need
> `uucp` access, which you already have.

## IntelliSense notes

clangd reads `./.clangd` to resolve `Arduino.h`, `Serial`, `pinMode`, and so on, including in
`.ino` files. Two non-obvious things make `.ino` work, both handled by `gen-clangd.py`:

1. It force-includes `Arduino.h`. Sketches never include it themselves; the Arduino build
   prepends it silently, and clangd does not know that.
2. It expands the GCC response file to recover the FSP and CMSIS include paths that the Nano R4
   pulls in through `-iwithprefixbefore`.

After adding a library (`#include <SomeLib.h>`), run "Arduino: Refresh IntelliSense" and restart
the clangd server, or the new headers will not resolve.

### Generating `.clangd`

`.clangd` is generated, not written by hand. From a fresh checkout (or any time you want to
rebuild it) run the generator against a sketch:

```bash
python3 .vscode/gen-clangd.py Blink                          # uses the default FQBN
python3 .vscode/gen-clangd.py Blink arduino:renesas_uno:nanor4   # or pass the FQBN
```

The `VSCode` task "Arduino: Refresh IntelliSense" runs exactly this. It compiles a compilation
database, then reads the real compiler, defines, and include paths out of it (expanding any GCC
response file), and writes `.clangd` at the project root. Because it takes the compiler from the
database, it works for any board, not just this one.

### The generator (`gen-clangd.py`)

```python
#!/usr/bin/env python3
"""Regenerate ./.clangd so clangd gives full Arduino IntelliSense for .ino/.cpp/.h.

Usage: python3 .vscode/gen-clangd.py <sketch-dir> [fqbn]
Run via the VSCode task "Arduino: Refresh IntelliSense" (re-run after adding libraries).
"""
import json, shlex, os, sys, subprocess

sketch = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
fqbn = sys.argv[2] if len(sys.argv) > 2 else "arduino:renesas_uno:nanor4"
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # workspace root
build = os.path.join(sketch, "build")

# 1. (re)generate the compilation database
subprocess.run(["arduino-cli", "compile", "-b", fqbn,
                "--only-compilation-database", "--build-path", build, sketch], check=True)

db = json.load(open(os.path.join(build, "compile_commands.json")))
entry = next(e for e in db if e["file"].endswith(".ino.cpp"))
cmd = entry.get("command") or " ".join(entry["arguments"])

def expand(tokens):
    out = []
    for t in tokens:
        if t.startswith("@") and os.path.isfile(t[1:]):
            out += expand(shlex.split(open(t[1:]).read()))
        else:
            out.append(t)
    return out

toks = expand(shlex.split(cmd))
compiler = toks[0]  # the exact compiler arduino-cli used for THIS board (avr, arm, xtensa)
includes, defines, std, iprefix = [], [], None, None
i = 0
while i < len(toks):
    a = toks[i]; nxt = toks[i + 1] if i + 1 < len(toks) else None
    if a.startswith("-std="): std = a
    elif a == "-iprefix": iprefix = nxt; i += 1
    elif a.startswith("-iprefix"): iprefix = a[8:]
    elif a.startswith("-iwithprefixbefore"):
        v = nxt if a == "-iwithprefixbefore" else a[18:]
        if a == "-iwithprefixbefore": i += 1
        if iprefix: includes.append(os.path.normpath(iprefix + "/" + v.lstrip("/")))
    elif a == "-I": includes.append(nxt); i += 1
    elif a.startswith("-I"): includes.append(a[2:])
    elif a == "-isystem": includes.append(nxt); i += 1
    elif a.startswith("-isystem"): includes.append(a[8:])
    elif a == "-D": defines.append(nxt); i += 1
    elif a.startswith("-D"): defines.append(a[2:])
    i += 1

inc = list(dict.fromkeys(p for p in includes if os.path.isdir(p)))
defs = list(dict.fromkeys(defines))

L = ["# AUTO-GENERATED by .vscode/gen-clangd.py, do not hand-edit.",
     "# Gives clangd full Arduino IntelliSense (.ino/.cpp/.h). Re-run the",
     "# 'Arduino: Refresh IntelliSense' task after adding libraries.",
     "CompileFlags:",
     "  Compiler: " + compiler,
     "  Add:",
     "    - -include", "    - Arduino.h", "    - -xc++"]
if std: L.append("    - " + std)
for x in defs: L.append("    - -D" + x)
for x in inc: L.append("    - -I" + x)
# Strip arch-specific codegen flags clangd's parser may not understand
# (arm: -mcpu/-mthumb/-mfloat-abi/-mfpu/-mabi ; avr: -mmcu ; xtensa/esp: -mlongcalls/-mtext-section-literals).
L += ["  Remove:", "    - -mcpu=*", "    - -mthumb", "    - -mfloat-abi=*",
      "    - -mfpu=*", "    - -mabi=*", "    - -mmcu=*", "    - -mlongcalls",
      "    - -mtext-section-literals", "    - -mno-*", "    - --param=*"]
open(os.path.join(root, ".clangd"), "w").write("\n".join(L) + "\n")
print(f"Wrote {root}/.clangd  ({len(inc)} include dirs, {len(defs)} defines)")
```

## Debugging

- **Print debugging (no extra hardware):** `Serial.println()` plus the serial monitor. This is
  the normal workflow.
- **Step debugging (breakpoints):** the Nano R4 has no onboard debugger, so it needs an external
  SWD probe (CMSIS-DAP, J-Link, or ST-Link) wired to the SWD pads. With one attached, the Run and
  Debug panel has a "Debug Nano R4 (external SWD probe)" config (`.vscode/launch.json`) that gives
  breakpoints and register views. Without a probe it will not run.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `LIBUSB_ERROR_ACCESS` on upload | udev rule not applied. Re-check step 3, confirm the file sorts below 73, replug. |
| Upload cannot find the board | `arduino-cli board list` for the real port, update `PORT` in tasks.json. |
| Task builds the wrong sketch | Make sure the correct `.ino` tab is the focused editor. |
| Red squiggles on `Serial`, `pinMode` | Run "Arduino: Refresh IntelliSense", then restart clangd. |
| Serial monitor blank or garbled | Baud must match `Serial.begin(...)`, this project uses 115200. |
| Port busy | Close any other monitor or terminal holding `/dev/ttyACM0`. |

The full Arduino language cheatsheet (program structure, digital and analog I/O, timing, serial,
interrupts, the non-blocking timing pattern, and so on) lives in the `ArduinoWings` project README
rather than here, since it is general Arduino reference and not part of the Arch setup itself.

| [← Previous](./11_hardening.md) |
|:--|
