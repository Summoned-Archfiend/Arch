# Scripts

Helper scripts referenced by the chapters in this repository. They split
into three groups:

* **ISO verification** (Windows / PowerShell, used before install) for
  checking the integrity of the downloaded `Arch` ISO. See
  [chapter 2](../chapters/2_virtual_machine.md).
* **Wacom Cintiq automation** (Linux / Bash, used post-install) for
  keeping a `Wacom Cintiq 16 (2025)` mapped correctly under `KDE Plasma 6`
  on `X11`. See [chapter 10](../chapters/10_wacom_and_display.md).
* **System hardening** (Linux, used post-install) for tightening kernel,
  network, SSH, and AI-agent surfaces on a workstation. See
  [chapter 11](../chapters/11_hardening.md).

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
