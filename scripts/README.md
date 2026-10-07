# Scripts

Helper scripts referenced by the chapters in this repository. They split
into four groups:

* **ISO verification** (Windows / PowerShell, used before install) for
  checking the integrity of the downloaded `Arch` ISO. See
  [chapter 2](../chapters/2_virtual_machine.md).
* **Wacom Cintiq automation** (Linux / Bash, used post-install) for
  keeping a `Wacom Cintiq 16 (2025)` mapped correctly under `KDE Plasma 6`
  on `X11`. See [chapter 10](../chapters/10_wacom_and_display.md).
* **System hardening** (Linux, used post-install) for tightening kernel,
  network, SSH, and AI-agent surfaces on a workstation. See
  [chapter 11](../chapters/11_hardening.md).
* **Bluetooth diagnosis** (Linux, used post-install) for working out why
  a Bluetooth adapter reports itself as disabled and refuses to power on.
  See [chapter 15](../chapters/15_bluetooth.md).
* **Battle.net launching** (Linux, used post-install) for starting a
  Proton-built Battle.net prefix when the `Lutris` installer leaves no
  launcher behind, and for the rendering faults in both the client and the
  game. See [chapter 16](../chapters/16_battlenet.md).
* **Game performance** (Linux, used post-install) for measuring whether a
  game is CPU or GPU limited rather than guessing at settings.
  See [chapter 17](../chapters/17_game_performance.md).
* **Call mic** (Linux, used post-install) for sending your voice and a
  `DAW`'s output to a browser call as one microphone, since a browser can
  only pick one input device. See [chapter 19](../chapters/19_call_mic.md).
* **Rotated camera** (Linux, used post-install) for showing a webcam that
  is lying on its side the right way up, through a virtual camera. See
  [chapter 19, section 8](../chapters/19_call_mic.md#8-a-camera-turned-on-its-side).
* **Rocksmith** (Linux, used post-install) for running `Rocksmith 2014` on
  `Proton` with a real audio interface instead of the Real Tone Cable,
  through `PipeASIO` and `RS_ASIO`. See [chapter 20](../chapters/20_rocksmith.md).
* **Boot diagnosis** (Linux, used post-install) for working out why a
  boot stalled for a minute or never reached the login screen, from the
  journal of that boot. See [chapter 21](../chapters/21_slow_boot_and_login.md).
* **RGB and fan check** (Linux, used post-install) for seeing which
  lighting and fan controllers are connected, whether your user can reach
  them, and what else is driving them. See [chapter 22](../chapters/22_rgb_and_fan_control.md).

## Files

| File                         | Group           | Purpose                                                                                                       |
| ---------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------- |
| `Compare-FileHash.ps1`       | ISO verification| PowerShell utility to compare a file's hash against an expected value. Supports `SHA256`, `SHA1`, `MD5`.       |
| `Compare-FileHash.cmd`       | ISO verification| Convenience wrapper so the `.ps1` can be launched without PowerShell execution-policy hurdles.                |
| `wacom-remap`                | Wacom           | One-shot. Re-applies the pen, eraser, and pad mapping to the Cintiq's current output. Goes in `~/.local/bin`. |
| `wacom-watch`                | Wacom           | Long-running supervisor. Listens to RandR events and polls the stylus matrix for resets. Goes in `~/.local/bin`. |
| `wacom-watch.service`        | Wacom           | `systemd` user unit that runs `wacom-watch` with `Restart=always`. Goes in `~/.config/systemd/user/`.         |
| `wacom-setup`                | Wacom           | Idempotent bootstrap. Rebuilds the entire pipeline from scratch and self-tests the watchdog at the end.       |
| `kded6rc.snippet`            | Wacom           | Config block to append to `~/.config/kded6rc` so `KDE`'s `wacomtablet` daemon stops fighting `xsetwacom`.     |
| `kwinrc.snippet`             | Wacom           | Config block to merge into `~/.config/kwinrc` so new windows open on the focused screen, not the pen screen.  |
| `sysctl-hardening.conf.snippet` | Hardening    | Drop-in for `/etc/sysctl.d/`. Tightens kernel info-leak, BPF, ICMP, and IPv6 settings while leaving Docker / Flatpak workflows intact. |
| `sshd-hardening.conf.snippet`   | Hardening    | Drop-in for `/etc/ssh/sshd_config.d/`. Key-only auth, modern crypto, `AllowUsers` lock-down. Edit `YOUR_USER` before installing. |
| `ufw-hardening.sh`              | Hardening    | Idempotent `UFW` rule set. Deny-incoming default with scoped allows for `SSH`, `RDP`, `KDE Connect`, `mDNS`, and Tailscale. Edit `LAN` before running. |
| `ufw-docker-after.rules.snippet`| Hardening    | `DOCKER-USER` chain block to merge into `/etc/ufw/after.rules` so `UFW` rules actually apply to container ingress. |
| `claude-settings-hardening.json.snippet` | Hardening | Reference deny-list for an AI coding assistant. Blocks reads of credential stores and writes to persistence surfaces. Adapt the *paths* to whichever agent's config syntax you use. |
| `bluetooth-check`             | Bluetooth       | Read-only. Walks the four layers that can each claim to be "enabled" and reports which one actually failed. No root needed. |
| `bluetooth-recover`          | Bluetooth       | Escalating reset for an adapter that will not power on. Four stages, least invasive first, stops at the first that works. Needs root. |
| `battlenet-launch`           | Battle.net      | Launches Battle.net from a Proton prefix without Lutris or Steam. Sets the `steamuser` profile and Proton's library paths, and refuses to start on top of a stale `wineserver`. Goes in `~/.local/bin`. |
| `mangohud.conf.snippet`      | Performance     | `MangoHud` overlay config for `~/.config/MangoHud/MangoHud.conf`. Tuned to answer whether you are CPU or GPU limited, not to look impressive. Per-core load and frame time graph enabled. |
| `call-mic`                   | Call mic        | Creates a `PipeWire` virtual source, `Call_Mic`, and links a voice mic and a `DAW`'s outputs into it. `activate`, `disable`, `status`, `sources`. Temporary by design; gone on reboot. Goes in `~/.local/bin`. |
| `cam-rotate`                 | Rotated camera  | Feeds a webcam through `ffmpeg`'s `transpose` filter into a `v4l2loopback` device, `Rotated Cam`. `start [cw\|ccw]`, `stop`, `status`. Holds the real camera while running. Goes in `~/.local/bin`. |
| `rocksmith-asio`             | Rocksmith       | Finds the game's library, prefix and Proton build itself. `status` checks every link from driver to game; `register` copies `PipeASIO` under `$HOME` and registers it through `umu-run`; `install-rsasio <zip>` installs `RS_ASIO` and edits its ini without breaking the `CRLF` endings. Goes in `~/.local/bin`. |
| `rgb-check`                  | RGB and fans    | Read-only. Lists Corsair controllers on USB, kernel fan drivers and which headers have fans, whether your user can open each controller, whether OpenRGB is running and set to detect the Corsair devices, and any user service that also drives them. Goes in `~/.local/bin`. |
| `boot-check`                 | Boot diagnosis  | Read-only. Reports startup time and what the display manager waited on, USB devices that never answered (and what shares their hub), greeter crashes and whether they were restarted, and a broken `SDDM` display setup script. Takes a `journalctl -b` offset. Goes in `~/.local/bin`. |

## ISO verification

Used from Windows or any host where you have PowerShell available. Run
against the downloaded `Arch` ISO and compare against the `SHA256` hash
listed on the Arch download mirror.

```powershell
.\Compare-FileHash.ps1 -FilePath "archlinux-x86_64.iso" -ExpectedHash "abc123..."
```

The `.cmd` wrapper exists so a double-click or a plain `cmd.exe` shell can
launch the script without you needing to fiddle with execution policies:

```cmd
Compare-FileHash.cmd archlinux-x86_64.iso abc123...
```

## Wacom quick install

If you trust everything in here and want the Wacom pipeline running in
one go:

```bash
install -Dm755 wacom-remap            ~/.local/bin/wacom-remap
install -Dm755 wacom-watch            ~/.local/bin/wacom-watch
install -Dm755 wacom-setup            ~/.local/bin/wacom-setup
install -Dm644 wacom-watch.service    ~/.config/systemd/user/wacom-watch.service
wacom-setup
```

`wacom-setup` will write the `kded6rc` and `systemd` pieces itself, then
self-test that the watchdog recovers from a forced reset.

## Customising the Wacom scripts for a different model

There is one constant to change at the top of `wacom-remap`,
`wacom-watch`, and `wacom-setup`:

```bash
PANEL_SIZE="345mm x 216mm"   # the physical-size column `xrandr --query` prints
```

`PANEL_SIZE` must match the physical-size column that `xrandr` prints
for your tablet.

The scripts no longer hardcode a device name. They resolve it from
`xsetwacom --list` by device type (`STYLUS`, `ERASER`, `PAD`), filtering
on the word `Cintiq` in the name. This matters because the name the
driver reports drifts across updates. I have seen the same tablet show
up as `Wacom Co.,Ltd. Wacom Cintiq 16 Stylus stylus` and later as
`Wacom Cintiq 16 Pen stylus`. A hardcoded string breaks the moment that
happens, and it fails quietly, with every `xsetwacom` call printing
`Cannot find device` into the log while the watcher keeps running. Matching
by type sidesteps that entirely.

If your tablet is not a Cintiq, change the `/Cintiq/` filter in the
`wacom_dev` and `stylus_name` functions to a word that appears in your
own device's name (run `xsetwacom --list` to see it).

## Hardening quick install

For the system-hardening files, install order matters; do not run them
all in a single `&&`-chain. Each one has a `# Apply:` header explaining
the steps, and chapter 11 walks through the safe order. The short
version:

```bash
# 1. Kernel sysctl values: safe, no service restart.
sudo install -Dm644 sysctl-hardening.conf.snippet /etc/sysctl.d/99-hardening.conf
sudo sysctl --system

# 2. SSH daemon: keep a second terminal logged in first.
sudoedit sshd-hardening.conf.snippet   # set AllowUsers to your username
sudo install -Dm644 sshd-hardening.conf.snippet /etc/ssh/sshd_config.d/99-hardening.conf
sudo sshd -t && sudo systemctl reload sshd

# 3. Firewall: edit LAN at the top of the script first.
sudo bash ufw-hardening.sh

# 4. Docker reconciliation: only if you run Docker.
#    Paste ufw-docker-after.rules.snippet into /etc/ufw/after.rules
#    before the final 'COMMIT', then:
sudo ufw reload
```

The AI-agent deny list (`claude-settings-hardening.json.snippet`) is a
reference, not a copy-paste install. Adapt it to whichever assistant
you use.

## Bluetooth diagnosis

Start with the read-only check. It needs no root and changes nothing:

```bash
./bluetooth-check
```

Layers one to three passing while layer four fails is the signature this
pair was written for. It means the daemon, the kill switch, and the kernel's
view of the hardware are all fine, and the radio itself is not answering.

If layer four fails, try the escalating reset:

```bash
sudo ./bluetooth-recover
```

It stops at the first stage that works and tells you which one that was,
which is useful information in itself. Recovering at stage 1 points at a
driver hiccup; needing stage 3 or 4 points closer to the hardware.

To keep them on `PATH`:

```bash
install -Dm755 bluetooth-check   ~/.local/bin/bluetooth-check
install -Dm755 bluetooth-recover ~/.local/bin/bluetooth-recover
```

Neither script hardcodes an adapter. They resolve the `USB` device by
walking up the `sysfs` tree from `/sys/class/bluetooth/hci0` to the first
ancestor carrying an `idVendor` file, so they work regardless of which port
your adapter sits on. Both take an optional adapter name as their first
argument if you have more than one:

```bash
./bluetooth-check hci1
```

If `bluetooth-recover` exhausts all four stages, the problem is below the
level software can reach and you need a cold boot. Chapter 15, section 8,
explains why a warm reboot specifically does not help.

## Call mic

Install it and tell it which source is your voice. The default source is
often the wrong input on an audio interface, so do not rely on it:

```bash
install -Dm755 call-mic ~/.local/bin/call-mic
call-mic sources
mkdir -p ~/.config/call-mic
echo 'VOICE_SOURCE=<your mic source from the list>' > ~/.config/call-mic/config
```

`~/.local/bin` must be on your `PATH` for the bare `call-mic` command to
work. [Chapter 19, section 5](../chapters/19_call_mic.md#5-the-script)
explains how to check and fix that, and why `./` is otherwise needed.

Open your `DAW` first (`REAPER` by default; set `APP=` in the config for
another `JACK` client), then:

```bash
call-mic activate
```

Reload the call page and pick **Call_Mic** as the microphone. `call-mic
status` shows exactly what is feeding it, and `call-mic disable` removes it.
Running `activate` again is safe and repairs any missing links, which is
also how you add the `DAW` if it was not open the first time.

## Rotated camera

Install the module and the script:

```bash
sudo pacman -S v4l2loopback-dkms
install -Dm755 cam-rotate ~/.local/bin/cam-rotate
```

Stop the camera in the call site first (only one program can stream from a
camera), then:

```bash
cam-rotate start          # or: cam-rotate start ccw
```

Pick **Rotated Cam** in the call site. If the picture is upside down, stop
and start again with the other direction. `cam-rotate stop` frees the real
camera. With several cameras, choose one by name with
`CAM_ROTATE_CAMERA=<part of its name>`. Chapter 19, section 8, explains the
module options, loading it at boot, and why a portrait picture often looks
smaller on the far end than you expect.

## Rocksmith

Set the game's Proton and launch options in Steam first, then launch it once
and quit, so the prefix exists. Chapter 20, section 5, has the exact launch
options. Then:

```bash
yay -S pipeasio
sudo pacman -S umu-launcher
install -Dm755 rocksmith-asio ~/.local/bin/rocksmith-asio
rocksmith-asio register
rocksmith-asio install-rsasio ~/Downloads/release-<version>.zip
rocksmith-asio status
```

`status` changes nothing and is safe to run at any time, including with the
game open, when it also shows what the game's input is linked to. Run
`register` again after every `pipeasio` update: the copy under `$HOME` does
not update itself. `~/.config/pipeasio/config.ini` should pin the driver to
your interface; chapter 20, section 4, explains why and how.

## Boot diagnosis

```bash
install -Dm755 boot-check ~/.local/bin/boot-check
boot-check -1     # the boot before this one
boot-check        # this boot, with the critical chain
```

Nothing needs root if your user can read the system journal (members of
`wheel` or `systemd-journal` can). The critical chain only exists for the
current boot, so after a slow boot, run it with no argument before you
reboot again. A clean result has `[ ok ]` in sections 2 to 4.

## RGB and fan check

```bash
install -Dm755 rgb-check ~/.local/bin/rgb-check
rgb-check
```

Nothing needs root. Run it before installing a lighting or fan program, and
again if lighting or fans stop responding. Any `[warn]` line names the
thing to fix. See [chapter 22](../chapters/22_rgb_and_fan_control.md).

## Notes

* The Wacom scripts assume `X11`. None of `xsetwacom`, `xinput`, or
  `xev` work under `Wayland`. On `Wayland (KDE 6+)` use *System Settings
  -> Tablet*.
* They assume the `NVIDIA` proprietary driver, which is why the mapping
  uses an explicit `WxH+X+Y` geometry rather than the connector name.
  On `Intel` or `AMD` you can usually pass the connector name directly,
  though the geometry form still works.
* The hardening scripts ship with placeholder values (`YOUR_USER`,
  `192.168.1.0/24`). They are deliberately wrong; the chapter explains
  how to find your own values before applying.
* The Bluetooth scripts assume a `USB` adapter, which covers dongles and
  most desktop motherboards. Built-in `PCIe` or `UART` adapters are seen by
  `bluetooth-check` but cannot be reset by `bluetooth-recover`, which will
  say so rather than guess.
* `call-mic` needs `pipewire-pulse` (for `pactl`) and, for the `DAW` side,
  `pipewire-jack`. It links the first two output ports of the `DAW`, which
  is the stereo master on `REAPER`.
* `cam-rotate` assumes the camera can send `MJPEG` at `1920x1440`. Most
  UVC webcams can; if yours cannot, set `CAM_ROTATE_SIZE` to a size from
  `v4l2-ctl --list-formats-ext`.
* `rocksmith-asio` assumes `Steam` installed natively under
  `~/.local/share/Steam`. The `Flatpak` keeps its files elsewhere and runs
  its own sandbox, which `PipeASIO` does not support. Set
  `ROCKSMITH_LIBRARY` to skip the library search.
