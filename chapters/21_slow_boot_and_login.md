# A Slow Boot and a Login Screen That Never Arrived

This chapter starts with two problems from the same evening. The first boot
sat on a black console for over a minute, and the last line it printed was
`Finished CLI Netfilter Manager`. When it finally moved on, the login screen
never appeared. The monitors were on and the cursor was gone, but nothing
came up. A hard reboot got to the login screen, after the same minute of
waiting.

They look like one fault, and they come straight after each other, but they
are two separate problems with two separate causes. Neither one is the thing
named on screen. This chapter shows how to work that out from the journal
after the fact, fixes both, and finds a third problem along the way: a
config file that had been broken for months without anyone noticing.

A read-only script, `boot-check`, does the whole investigation in one go.

> **Note**
> The examples come from a desktop with an `NVIDIA GTX 1080` on the
> `nvidia-580xx` driver, `KDE Plasma` on `X11`, `SDDM` as the login manager,
> and a USB dock with a hub, a network adapter and some audio devices in it.
> Your port numbers, device names and timings will differ. The method is the
> same.

---

## 1. Reading a Boot That Already Happened

When a boot goes wrong you usually reboot first and ask questions later.
That is fine, because `systemd`'s journal keeps every boot separately. List
them:

```bash
journalctl --list-boots | tail -n 4
```

```
 -2 212d4dd0...  Mon 2026-10-05 20:44:36 BST  Mon 2026-10-05 22:53:11 BST
 -1 764ed77c...  Tue 2026-10-06 18:50:44 BST  Tue 2026-10-06 18:52:17 BST
  0 aee00205...  Tue 2026-10-06 18:54:02 BST  Tue 2026-10-06 18:56:26 BST
```

`0` is the boot you are in now and `-1` is the one before it. Boot `-1` lasted
93 seconds, which is the one that never reached a login screen. Everything
below uses `-b -1` to look at it.

Two options make the journal much easier to read for this kind of work:

```bash
journalctl -b -1 -p warning      # only warnings and worse
journalctl -b -1 -o short-precise   # timestamps to the microsecond
```

The second one matters more than it looks. Most of what follows comes from
noticing that two unrelated messages happened within a fraction of a second
of each other, and you cannot see that with timestamps rounded to the
second.

> **Note**
> If `journalctl --list-boots` only shows one boot, your journal is not
> persistent. Create `/var/log/journal` and restart `systemd-journald`, and
> future boots will be kept.

---

## 2. Where the Minute Went

`systemd` can tell you what the login screen was waiting for. This only works
for the current boot, so run it after a slow one:

```bash
systemd-analyze critical-chain sddm.service
```

```
sddm.service @1min 3.360s
└─plymouth-quit.service @1min 3.329s +28ms
  └─systemd-user-sessions.service @1min 3.307s +16ms
    └─network.target @1min 3.254s
      └─NetworkManager.service @1min 2.933s +320ms
        └─basic.target @1min 2.931s
          └─dbus-broker.service @1min 2.911s +20ms
            └─dbus.socket @1min 2.899s +35us
              └─sysinit.target @1min 2.896s
                └─ufw.service @4.493s +58.402s
                  └─systemd-sysctl.service @4.469s +21ms
```

Read it from the bottom up. Each line is a unit, `@` is when it became ready
and `+` is how long it took. Every unit here takes milliseconds except one:
`ufw.service`, which took 58 seconds. Almost everything else on the system
is ordered after `sysinit.target`, and `ufw` has to finish before
`sysinit.target` can, so the whole boot waited for it.

`ufw` is the firewall, and its unit's description is **CLI Netfilter
Manager**. `Netfilter` is the part of the kernel that filters network
traffic, and `ufw` is a command-line front end for it. That is the message
that was on screen.

The obvious conclusion is that the firewall is broken. It is not. Look at
what it logged:

```bash
journalctl -b 0 -u ufw -o short-precise
```

```
Oct 06 18:54:05.152006 ultron systemd[1]: Starting CLI Netfilter Manager...
Oct 06 18:55:03.554877 ultron systemd[1]: Finished CLI Netfilter Manager.
```

No errors and no warnings. It started, it waited, it finished. Something was
holding it up, and the way to find out what is to look at everything else
that happened while it waited.

```bash
journalctl -b 0 -k -o short-precise | grep -E 'usb|r8152'
```

```
18:54:02.937159 kernel: usb 2-6.1: new SuperSpeed USB device number 5 using xhci_hcd
18:54:02.938076 kernel: usb 2-6.1: Manufacturer: Realtek
18:54:02.958233 kernel: usb 1-6.3.2.3: new full-speed USB device number 18 using xhci_hcd
18:54:15.605059 kernel: usb 1-6.3.2.3: device descriptor read/64, error -110
18:54:31.488061 kernel: usb 1-6.3.2.3: device descriptor read/64, error -110
18:54:31.686057 kernel: usb 1-6.3.2.3: new full-speed USB device number 19 using xhci_hcd
18:54:47.349060 kernel: usb 1-6.3.2.3: device descriptor read/64, error -110
18:55:03.221059 kernel: usb 1-6.3.2.3: device descriptor read/64, error -110
18:55:03.390541 kernel: r8152-cfgselector 2-6.1: reset SuperSpeed USB device number 5 using xhci_hcd
```

Something is plugged into USB port `1-6.3.2.3`, and it is not answering.
When a USB device is plugged in, the first thing the kernel does is ask it
for its **device descriptor**, a short block of data saying what it is.
`error -110` is `ETIMEDOUT`: the question was asked and nothing came back.
The kernel waits about 16 seconds, tries again, then resets the port and
tries the whole thing again. Four timeouts at 16 seconds each is the
minute.

Now look at the last two lines. The kernel gives up on the silent device at
`18:55:03.22`. The `Realtek` network adapter, `r8152`, which lives in the
same dock, finishes its reset at `18:55:03.39`. `ufw` finishes at
`18:55:03.55`. Three events inside a third of a second, at the end of a
minute of nothing.

The journal does not say which lock the network adapter was waiting on, so
this is the part you have to reason through. The dock is one physical hub
with a USB 2 side (bus `1`) and a USB 3 side (bus `2`). The adapter could
not finish setting up until the hub was free, and the hub was busy retrying
the silent device. The firewall configures packet filtering, which touches
the networking code the adapter was half way through registering with, so
it waited too. Whatever the exact mechanism, the timing repeats to within a
fraction of a second on every slow boot, and that is enough evidence to act
on.

It also explains why the delay looked random. On one boot that week, `ufw`
finished in 0.2 seconds while the USB timeouts carried on regardless. The
order in which devices are probed varies a little from boot to boot. When
the adapter happened to come up before the hub got stuck, nothing waited on
it.

---

## 3. Finding the Device That Will Not Answer

A USB port path like `1-6.3.2.3` reads left to right as a route through the
hubs:

```
1-6.3.2.3
│ │ │ │ └── port 3 of hub 1-6.3.2   ◄── the silent device
│ │ │ └──── port 2 of hub 1-6.3     (another hub)
│ │ └────── port 3 of hub 1-6       (another hub)
│ └──────── port 6 on the computer  (the dock)
└────────── bus 1
```

`lsusb -t` draws the same tree. The silent device will not be in it, because
it never told the kernel what it is, but its neighbours will. `sysfs` is
quicker for a single hub:

```bash
for d in /sys/bus/usb/devices/1-6.3.2*; do
    [ -e "$d/product" ] && echo "${d##*/}: $(cat "$d/product")"
done
```

```
1-6.3.2: USB2.1 Hub
1-6.3.2.2: USB Audio
```

So the device is the one plugged in next to the USB audio device, on the
same small hub. That is usually enough to find it physically.

A device that powers up but never answers its descriptor request is nearly
always one of three things:

* **A bad cable or connector.** Try another cable first, it is the cheapest
  test.
* **A device that is not getting enough power.** Small unpowered hubs
  chained behind other hubs are the usual culprit. Move it to a port on the
  computer itself.
* **A dead or half-dead device.** Some cheap controllers (RGB hubs, fan
  controllers, card readers) start too slowly and miss the window every
  time.

Unplug it and boot. If the minute disappears, you have found it. Then decide
whether it needs a different port, a different cable or the bin.

---

## 4. The Login Screen That Crashed

Now the second problem. In the failed boot, `X` started, all three monitors
were detected, and `SDDM` started its login screen, which it calls the
**greeter**. Two seconds later:

```bash
journalctl -b -1 | grep -A6 'dumped core'
```

```
systemd-coredump[1144]: Process 917 (sddm-greeter-qt) of user 963 dumped core.

  Stack trace of thread 1095:
  #0  0x00007f4642755e95 n/a (libnvidia-glcore.so.580.178.04 + 0xb55e95)
  #1  0x00007f46423cb360 n/a (libnvidia-glcore.so.580.178.04 + 0x7cb360)
  ...
  #7  0x00007f464fc2d0a7 _ZN4QRhi8endFrameEP13QRhiSwapChain... (libQt6Gui.so.6)
```

The greeter crashed while finishing a frame (`QRhi::endFrame`), and the top
of the stack is inside the `NVIDIA` OpenGL library. It was drawing the login
screen on the GPU and the driver fell over.

```
sddm[820]: Auth: sddm-helper exited with 11
sddm[820]: Greeter stopped. SDDM::Auth::HelperExitStatus(11)
```

`11` is `SIGSEGV`, a segmentation fault. And then nothing. `SDDM` does not
start a new greeter when one crashes. The `X` server keeps running with
nothing on it, which is exactly what a black screen with no cursor looks
like.

You do not need to reboot to get out of this. The text consoles are still
there:

1. Press `Ctrl` + `Alt` + `F3`.
2. Log in with your username and password.
3. Run `sudo systemctl restart sddm`.

`SDDM` starts from scratch and the login screen comes back.

To check whether this is a one-off or a pattern, `coredumpctl` lists every
crash it has recorded. Give it the full path: the process name in the crash
record is cut short to `sddm-greeter-qt`, so the short name finds nothing.

```bash
coredumpctl list /usr/bin/sddm-greeter-qt6
```

Here it was one crash in a dozen boots, on a driver that runs the whole
desktop without trouble. That is not worth changing driver over. It is
worth making sure it cannot leave you with a black screen again.

---

## 5. Taking the GPU Out of the Login Screen

The greeter is a password box and a background picture. It does not need
the GPU. `Qt Quick`, the toolkit the greeter is built with, can draw
everything in software instead, and you choose that with one environment
variable: `QT_QUICK_BACKEND=software`.

`SDDM` has a setting for passing environment variables to the greeter.
Put it in its own drop-in file so it is easy to find and easy to remove:

```bash
sudo tee /etc/sddm.conf.d/50-greeter-software.conf >/dev/null <<'EOF'
# Draw the login screen in software, so a GPU driver fault cannot
# leave a black screen. The desktop session still uses the GPU.
[General]
GreeterEnvironment=QT_QUICK_BACKEND=software
EOF
```

This only affects the login screen. Once you log in, `Plasma` starts with
its own environment and uses the GPU as before.

There is a trade-off. Software rendering cannot do shader effects, so a
theme that blurs its background or uses a shader for a round avatar will
lose those touches. Check your theme for them:

```bash
grep -rlE 'GaussianBlur|ShaderEffect|MultiEffect' /usr/share/sddm/themes/<your-theme>/
```

You can preview the theme in software mode, in a window on your desktop,
before you reboot:

```bash
QT_QUICK_BACKEND=software sddm-greeter-qt6 --test-mode \
    --theme /usr/share/sddm/themes/<your-theme>
```

Close the window when you have seen enough. If it looks wrong enough to
bother you, try another theme rather than putting the GPU back.

---

## 6. A Config File That Never Worked

While reading the `SDDM` log for the crash, one more line stood out:

```
sddm[820]: Running display setup script  "/usr/share/sddm/scripts/"
```

That is a directory, not a script. `SDDM` runs a **display setup script**
as root just before showing the greeter, which is where people put `xrandr`
commands to arrange monitors on the login screen. The setting is
`DisplayCommand`, and here it came from a file written months earlier:

```bash
cat -A /etc/sddm.conf.d/99-display.conf
```

```
[X11]$
DisplayCommand=/usr/share/sddm/scripts/$
Xsetup$
```

`cat -A` shows line endings as `$`. The path has been split over two lines,
probably by a paste that wrapped. `SDDM` reads `DisplayCommand` as the
directory, ignores `Xsetup` as a line it does not understand, and tries to
run the directory every boot. That fails, and `SDDM` carries on without
saying anything. The script has never run.

The obvious fix is to join the line back together. Before doing that, read
the script it was meant to run:

```bash
cat /usr/share/sddm/scripts/Xsetup
```

```
/usr/bin/xrandr \
  --output DP-2 --primary --mode 3440x1440 --rotate normal \
  --output DP-0 --mode 3840x2160 --rotate right --right-of DP-2
```

It sets up a rotated monitor on `DP-0` that is no longer plugged in. Fixing
the line would have started running an out-of-date layout at every login.
The broken file was the only thing keeping it harmless.

Deleting `99-display.conf` is not enough on its own either. With no
`DisplayCommand` set, `SDDM` falls back to its default, which you can see in
`/usr/lib/sddm/sddm.conf.d/default.conf`:

```
DisplayCommand=/usr/share/sddm/scripts/Xsetup
```

That is the same out-of-date script. It has to go back to the stock version
too. `pacman` can tell you it was edited:

```bash
pacman -Qkk sddm
```

```
warning: sddm: /usr/share/sddm/scripts/Xsetup (Permissions mismatch)
backup file: sddm: /usr/share/sddm/scripts/Xsetup (SHA256 checksum mismatch)
```

The words **backup file** matter. `Xsetup` is marked in the package as a
config file, so reinstalling `sddm` will **not** overwrite your edited copy.
It will save the stock one beside it as `Xsetup.pacnew` and leave yours in
place. Take the stock file straight from the package in `pacman`'s cache
instead:

```bash
pkg=$(ls /var/cache/pacman/pkg/sddm-$(pacman -Q sddm | cut -d' ' -f2)-*.pkg.tar.zst | head -n1)
bsdtar -xOf "$pkg" usr/share/sddm/scripts/Xsetup
```

```
#!/bin/sh
# Xsetup - run as root before the login dialog appears

```

It does nothing, which is the right default. Keep the old files rather than
deleting them, then put the stock script back:

```bash
sudo mkdir -p /etc/sddm.conf.retired
sudo mv /etc/sddm.conf.d/99-display.conf /etc/sddm.conf.retired/
sudo cp -a /usr/share/sddm/scripts/Xsetup /etc/sddm.conf.retired/Xsetup.custom
bsdtar -xOf "$pkg" usr/share/sddm/scripts/Xsetup | sudo tee /usr/share/sddm/scripts/Xsetup >/dev/null
sudo chmod 755 /usr/share/sddm/scripts/Xsetup
```

`/etc/sddm.conf.retired` is outside `/etc/sddm.conf.d`, so `SDDM` will never
read anything you park there.

If you do want monitors arranged on the login screen, generate the `xrandr`
line from what is plugged in today (`xrandr --query`), and type the
`DisplayCommand` path on one line.

---

## 7. Checking It All with `boot-check`

`boot-check` runs every check in this chapter against one boot and prints
what it found. It changes nothing.

```bash
install -Dm755 scripts/boot-check ~/.local/bin/boot-check
boot-check -1        # the previous boot
boot-check           # this boot, including the critical chain
```

Against the failed boot from this chapter:

```
Boot -1, started 2026-10-06T18:50:44+01:00

1. Startup time
          27.842s (firmware) + 8.186s (loader) + 6.975s (kernel) + 1min 12.509s (userspace) = 1min 55.513s.
  [WARN]  userspace took over a minute: something waited on a timeout

2. USB devices that failed to enumerate
  [WARN]  port 1-6.3.2.3: 6 failed attempts, 18:50:59.633099 to 18:52:10.409071
          it is port 3 of hub 1-6.3.2 (USB2.1 Hub)
            1-6.3.2.2 is working: USB Audio (0020:0b21)
            1-6.3.2.3 is still not enumerated: unplug it, or try another port
  [WARN]  udev reported 4 device(s) taking a long time to set up

3. Login screen (sddm.service)
  [WARN]  Process 917 (sddm-greeter-qt) of user 963 dumped core.
          it crashed inside: libnvidia-glcore.so.580.178.04
          that is the graphics driver: see chapter 21, section 4
  [WARN]  sddm.service did not relaunch it: the screen stayed black

4. Display setup script
  [WARN]  DisplayCommand points at a directory: /usr/share/sddm/scripts/
          a path split over two lines in a conf file does this
```

All three problems, each pointing at the section that fixes it. Run it again
after the next boot: a clean result has `[ ok ]` in sections 2 to 4 and a
userspace time in seconds rather than minutes.

---

## Quick Reference

| Symptom | Likely cause |
|:--|:--|
| Boot pauses on `Finished CLI Netfilter Manager` | Not the firewall. Something earlier is holding it up. Check `systemd-analyze critical-chain` and the kernel log (section 2). |
| `device descriptor read/64, error -110` | A USB device that powers up but never answers. Cable, power or a dead device (section 3). |
| Pause is about 60 seconds on some boots, none on others | Same USB device. Probe order decides whether anything else waits on it. |
| Black screen, no cursor, monitors on | Greeter crashed and was not restarted. `Ctrl`+`Alt`+`F3`, then `sudo systemctl restart sddm` (section 4). |
| Greeter crash inside `libnvidia-*` or `mesa` | GPU driver fault. Set `QT_QUICK_BACKEND=software` for the greeter (section 5). |
| Login screen lost its blur after the fix | Expected. Software rendering skips shader effects. |
| `Running display setup script "/usr/share/sddm/scripts/"` | `DisplayCommand` split over two lines (section 6). |
| Reinstalling `sddm` did not restore `Xsetup` | It is a backup file. Look for `Xsetup.pacnew`, or extract it from the package cache. |
| `critical-chain` shows nothing useful | It only covers the current boot. Reboot into the slow state, then run it. |

---

## Why this is harder than it should be

Every message on screen that evening pointed the wrong way. The boot stopped
on a line about the firewall, and the firewall was fine. The login screen
failed to appear, and the monitors were fine. The obvious fixes were to pull
the firewall out of the boot order and to reinstall the graphics driver.
Both would have taken an hour, and neither would have changed anything. The
first would also have quietly left the machine without a firewall at boot.

The last line on a stalled screen is almost never the cause. It is the last
thing that managed to finish before everything queued up behind something
else. The useful question is not "what was on screen" but "what else
happened while it waited", and the only way to answer that is to put the
journal in timestamp order and look for things that line up. Here, a USB
reset and a firewall finishing within a fraction of a second of each other,
at the end of a minute of nothing, was the whole story.

The config file is the other lesson. A broken setting that fails silently is
not just dead code. It can be holding back something worse. The split
`DisplayCommand` line had been doing nothing for months, and the instinct on
finding it is to tidy it up. Tidying it would have switched on an
out-of-date monitor layout at every login. Before you fix something that
has been broken for a while, find out what it would do if it worked.

| [← Previous](./20_rocksmith.md) | [Next →](./22_rgb_and_fan_control.md) |
|:--|--:|
