# Bluetooth Will Not Enable

This chapter is about a specific and very annoying failure: your desktop
says Bluetooth is disabled, you click the toggle to enable it, and nothing
happens. The switch greys out, or it flicks on and immediately snaps back
to off. No error dialog, no explanation.

The instinct is to go looking for a broken service. That instinct is
usually wrong, and chasing it wastes a lot of time, because in most cases
`bluetooth.service` is running perfectly and reporting exactly what it has
been told by the hardware.

The real problem is that four separate things on your system are all
entitled to call themselves "Bluetooth enabled", and your desktop only
shows you the summary. When three of them are healthy and the fourth is
not, the summary says "disabled" and gives you no way to find out which
layer failed.

This chapter teaches you to read all four layers directly, decode the
kernel errors underneath them, and work out whether you are looking at a
configuration problem, a firmware problem, or hardware that has stopped
answering.

---

## 1. The Four Layers

Every one of these can be true or false independently:

| Layer | What it means | How to check |
| ----- | ------------- | ------------ |
| **Daemon** | `bluetoothd` is running and set to start at boot | `systemctl is-active bluetooth` |
| **Kill switch** | No software or hardware block on the radio | `rfkill list bluetooth` |
| **Adapter** | The kernel can see physical hardware | `ls /sys/class/bluetooth/` |
| **Powered** | The radio is actually up and usable | `bluetoothctl show` |

The important insight is that **only the last one determines whether
Bluetooth works.** The first three are necessary but not sufficient. They
are also the three that most guides tell you to check, which is why people
get stuck: all three come back clean and the guide runs out of advice.

Check the one that matters:

```bash
bluetoothctl show | grep -E "Powered|PowerState"
```

There are three outcomes worth knowing.

```
Powered: yes
```

The radio is up. Whatever is wrong is not at this level; go and look at
pairing, `PipeWire`, or the specific device instead.

```
Powered: no
PowerState: off
```

Nothing has tried to turn the radio on. This is the benign case, and it
generally means a config or permissions problem. Try `bluetoothctl power on`
and read the error it gives you.

```
Powered: no
PowerState: on
```

This is the interesting one, and it is the case this chapter exists for.
These two lines contradict each other on purpose. `PowerState: on` means
something asked the radio to come up. `Powered: no` means it never
confirmed that it did. The request went out and no answer came back.

That is not a configuration problem. Configuration problems fail fast and
loudly. This is hardware that has stopped responding.

---

## 2. Why the Error Message Lies to You

If you watch the journal while clicking the toggle, you will see
`bluetoothd` report this:

```bash
journalctl -u bluetooth -f
```

```
bluetoothd[716]: Failed to set mode: Authentication Failed (0x05)
```

"Authentication Failed" is a red herring and it sends people hunting
through pairing keys and `/var/lib/bluetooth` for hours. Nothing is being
authenticated here. You are not connecting to a device, you are trying to
switch a radio on.

What has actually happened is that `bluetoothd` sent a **set-mode** command
over the kernel's management socket, the command failed, and the generic
management error code it got back is `0x05`. `BlueZ` prints the human name
for that code without knowing the context. The name is meaningless for this
operation.

The lesson generalises: when a `BlueZ` error makes no sense for the thing
you were doing, stop reading `BlueZ` and go one layer down to the kernel.

---

## 3. Reading the Kernel's Version of Events

The kernel is far more specific:

```bash
journalctl -k -b | grep hci0
```

On the machine this chapter was written from:

```
Bluetooth: hci0: Opcode 0x0c03 failed: -110
```

Two numbers, and both matter.

**`0x0c03` is `HCI_Reset`.** In the Bluetooth `HCI` specification an opcode
splits into an Opcode Group Field and an Opcode Command Field. Group `0x03`
is Controller and Baseband, command `0x0003` within it is Reset. It is the
first command sent to an adapter during bring-up and the simplest operation
the protocol has. It takes no parameters and does nothing but tell the
controller to reinitialise itself.

**`-110` is `ETIMEDOUT`.** Not "refused", not "rejected", not "invalid".
The kernel sent the command and gave up waiting for a reply.

Put them together and the meaning is unambiguous: the adapter is not
answering the simplest possible command. It is not misconfigured. It is not
responding at all.

A useful habit, since these numbers appear constantly in kernel logs:

```bash
errno 110
```

`errno` comes from `moreutils` and turns a bare number into a name. Well
worth installing.

---

## 4. Ruling Out Firmware First

Most `USB` Bluetooth adapters have no permanent firmware. They arrive on
your system as an inert lump of silicon and the kernel uploads firmware to
them at boot. If that upload fails, the adapter never becomes functional,
and the symptom looks identical to the hardware fault above.

This is worth checking early because it is common, it is very easy to
confirm, and unlike a hardware fault it has a trivial fix.

```bash
journalctl -k -b | grep -iE "rtl_bt|btusb|firmware"
```

A healthy `Realtek` adapter looks like this:

```
Bluetooth: hci0: RTL: examining hci_ver=0a hci_rev=000b lmp_subver=8761
Bluetooth: hci0: RTL: loading rtl_bt/rtl8761bu_fw.bin
Bluetooth: hci0: RTL: loading rtl_bt/rtl8761bu_config.bin
Bluetooth: hci0: RTL: fw version 0xdfc6d922
```

Both files load and a version is reported. A failure instead looks like
`Direct firmware load for rtl_bt/... failed with error -2`, where `-2` is
`ENOENT`, meaning the file is simply not there.

### The `linux-firmware` split

There is an `Arch`-specific trap here that catches people out. `linux-firmware`
used to be one enormous package containing firmware for every device in
existence. It has since been split into per-vendor subpackages, so a system
that upgraded across that change, or a fresh install where the vendor
package was never pulled in, can end up without the firmware its adapter
needs.

Check what you have:

```bash
pacman -Qs linux-firmware
```

You want the subpackage matching your adapter's manufacturer. Identify the
manufacturer first:

```bash
lsusb | grep -i blue
```

```
Bus 001 Device 002: ID 0bda:a728 Realtek Semiconductor Corp. Bluetooth 5.4 Radio
```

`0bda` is `Realtek`, so `linux-firmware-realtek` is the package required.
`Intel` adapters need `linux-firmware-intel`, `Qualcomm` and `Atheros` need
`linux-firmware-atheros`, `Broadcom` needs `linux-firmware-broadcom`, and
`MediaTek` needs `linux-firmware-mediatek`.

Install whichever you are missing and reboot:

```bash
sudo pacman -S linux-firmware-realtek
```

Keep the versions aligned. All the `linux-firmware-*` packages should be on
the same version, and a mismatch after a partial upgrade is its own source
of strange behaviour. This is one of many reasons `Arch` requires full
system upgrades, as covered in [chapter 6](./6_nvidia_dkms.md).

If your firmware loads cleanly and the adapter still refuses to power on,
firmware is not your problem. Move on.

---

## 5. The Layer Almost Nobody Checks

Here is where the diagnosis gets genuinely interesting, and where the
answer often turns out to have nothing to do with Bluetooth.

A `USB` Bluetooth adapter is a `USB` device. Every `HCI` command it receives
travels through a `USB` host controller, and on any modern machine that
controller is `xHCI`. If the controller is in trouble, commands to
everything downstream of it fail, and `HCI_Reset` is just one more casualty.

Look for controller-level errors rather than Bluetooth ones:

```bash
journalctl -k -b | grep -i "xhci_hcd"
```

On the machine this chapter documents, that produced the following once the
timestamps were lined up against the Bluetooth failures:

```
11:05:42  Bluetooth: hci0: Opcode 0x0c03 failed: -110
11:05:46  xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command
11:05:51  xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command
11:05:57  xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command
11:06:00  Bluetooth: hci0: Opcode 0x0c03 failed: -110
```

The Bluetooth failures are interleaved with controller failures on
`0000:00:14.0`. Confirm the adapter is actually on that controller rather
than assuming it:

```bash
readlink -f /sys/class/bluetooth/hci0
```

```
/sys/devices/pci0000:00/0000:00:14.0/usb1/1-3/1-3:1.0/bluetooth/hci0
```

The path reads left to right as a hardware tree. `0000:00:14.0` is the
`PCI` address of the `xHCI` controller, `usb1` is its root hub, and `1-3` is
the adapter on port 3. The controller throwing timeouts is the same one the
adapter depends on, so this is not a coincidence.

### Finding the actual culprit

A controller in this state has usually been pushed there by a single
misbehaving device. The signature is a device that enumerates over and over
without ever succeeding:

```bash
journalctl -k -b | grep "new .* USB device number"
```

Watch for the same port appearing repeatedly with an incrementing device
number:

```
usb 1-6.3.2.3: new full-speed USB device number 18 using xhci_hcd
usb 1-6.3.2.3: new full-speed USB device number 19 using xhci_hcd
usb 1-6.3.2.3: new full-speed USB device number 20 using xhci_hcd
usb 1-6.3.2.3: new full-speed USB device number 21 using xhci_hcd
```

The same port, four attempts, four new device numbers, and no successful
enumeration. That device is failing to come up and is consuming controller
resources while it retries. Everything else on that controller suffers, and
Bluetooth happens to be the visible casualty.

Read the port number as a topology path. `1-6.3.2.3` means bus 1, port 6,
then hub port 3, then hub port 2, then port 3. That is four levels of
hubs stacked on each other. See the whole tree with:

```bash
lsusb -t
```

Deep hub chains are a frequent cause of this. Every level adds latency and
divides available power, and cheap unpowered hubs are much worse than the
spec allows. If the failing port sits at the end of a chain like that, the
hub arrangement is the thing to fix, not Bluetooth.

---

## 6. Recovering Without a Reboot

If you have established the adapter is not answering, you can try to reset
it from the host side. This is what `scripts/bluetooth-recover` does, and it
escalates through four stages, stopping at the first that works.

```bash
sudo ./scripts/bluetooth-recover
```

The stages, and why they are in this order:

**Stage 1, rebind the driver.** Detach `btusb` from the adapter and
reattach it, forcing a fresh initialisation and firmware upload. Nothing
else on the system is affected. Note that `btusb` binds per *interface*
(`1-3:1.0` and `1-3:1.1`), not per device, so both must be handled.

**Stage 2, deauthorise the device.** Writing `0` then `1` to the device's
`authorized` file in `sysfs` makes the kernel drop and re-accept it. This
reaches slightly deeper than a driver rebind.

**Stage 3, force re-enumeration.** Unbinding at the `usb` driver level makes
the kernel forget the device entirely and rediscover it from scratch, which
is as close to physically unplugging it as software can get.

**Stage 4, reload the module stack.** Remove `btusb` along with its vendor
helper modules and load them again. The helpers matter: leaving `btrtl` or
`btintel` resident while reloading `btusb` can rebind against stale state.

The script re-checks `Powered:` after each stage and tells you which one
worked, which is diagnostically useful on its own. Recovering at stage 1
suggests a driver-level hiccup. Needing stage 3 or 4 suggests something
closer to the hardware.

---

## 7. The Adapter Comes Back With a New Name

There is a trap immediately after a successful recovery, and it is worth
knowing before it catches you.

When the kernel re-enumerates a Bluetooth adapter, it does not necessarily
reuse the index the adapter had before. The old `hci0` is torn down and the
device that reappears is registered as `hci1`, on the same `USB` port, with
the same `MAC` address:

```
Bluetooth: hci1: RTL: examining hci_ver=0a hci_rev=000b lmp_subver=8761
Bluetooth: hci1: RTL: loading rtl_bt/rtl8761bu_fw.bin
Bluetooth: hci1: RTL: fw version 0xdfc6d922
```

```bash
ls -l /sys/class/bluetooth/
```

```
hci1 -> ../../devices/pci0000:00/0000:00:14.0/usb1/1-3/1-3:1.0/bluetooth/hci1
```

`hci0` is gone. Anything that hardcoded it now reports no adapter, while
`bluetoothctl` carries on working perfectly, because `bluetoothctl show`
addresses the default controller by identity rather than by index.

This produces genuinely contradictory output if you are not expecting it.
The first version of `bluetooth-check` in this repository defaulted to
`hci0` and printed exactly that contradiction on a working system:

```
3. Adapter -- does the kernel see hardware?
  |-| no hci0 -- kernel sees no adapter
4. Radio powered -- THE ONE THAT MATTERS
  |+| Powered: yes -- Bluetooth is working
```

Both lines were accurate. There genuinely was no `hci0`, and Bluetooth
genuinely was working, on `hci1`. The script was asking about a device that
no longer existed.

The fix is never to assume the index. Resolve it:

```bash
ls /sys/class/bluetooth/
```

Both scripts here now do this automatically, taking the first real adapter
they find and ignoring the `hciX:Y` child nodes, which are not adapters.
The general lesson applies well beyond Bluetooth: kernel device indices are
allocation order, not identity. Anywhere you find yourself typing `hci0`,
`eth0`, or `sdb` into something you intend to keep, you are writing down a
number that is free to change underneath you. This is the same reasoning
behind addressing disks by `UUID` in `/etc/fstab`, covered in
[chapter 4](./4_installation.md).

---

## 8. When Software Cannot Fix It

If all four stages fail, stop trying. Every one of them resets the device
from the host side, and none can reset the host controller itself. If the
`xHCI` controller is wedged, no amount of driver poking will help, because
the commands are dying before they reach the adapter.

**Do a cold boot, not a reboot.**

```
shut down fully, wait about ten seconds, power back on
```

This distinction is real and it is the single most common reason people
conclude "rebooting doesn't fix it". A warm reboot restarts the kernel but
leaves the `xHCI` controller powered throughout. Its internal state, and
therefore the wedged condition, survives into the new boot. Only removing
power actually resets it.

The same principle appears elsewhere in this repository, in
[chapter 7](./7_snapshots_and_restore.md) and in the shutdown-hang notes:
if a fault survives a reboot but clears on a power cycle, you are looking
at hardware state rather than kernel state.

A quick way to confirm you are in this situation:

```bash
uptime -p
journalctl -k -b | grep -m1 "Opcode 0x0c03 failed"
```

If uptime is short and the first failure landed seconds after boot, then
Bluetooth never worked this session. It came up broken. Rebooting again is
not going to change anything, and only a cold boot is worth trying.

---

## 9. Making the Diagnosis Repeatable

Working through all of this by hand every time is tedious, so
`scripts/bluetooth-check` walks the whole ladder in one read-only pass. It
needs no root and changes nothing.

```bash
./scripts/bluetooth-check
```

```
1. Daemon -- is bluetoothd alive?
  |+| bluetooth.service is running
  |+| starts at boot
2. Kill switch -- has something blocked the radio?
  |+| not soft blocked
  |+| not hard blocked
3. Adapter -- does the kernel see hardware?
  |+| hci0 present on USB 1-3  (0bda:a728)
4. Radio powered -- THE ONE THAT MATTERS
  |-| Powered: no   (PowerState: on)
      the radio was asked to power on and never answered.
      this is a HARDWARE-level failure, not a config problem.
5. Kernel errors this boot
  |-| 6 x HCI_Reset timeout (opcode 0x0c03, errno -110)
  |-| 4 x xHCI controller timeout
```

That output is the entire diagnosis on one screen. Layers one to three
pass, which is exactly why the desktop toggle offers no useful information,
and layer four fails for a reason the kernel spells out underneath.

Install both scripts if you want them on `PATH`:

```bash
install -Dm755 scripts/bluetooth-check   ~/.local/bin/bluetooth-check
install -Dm755 scripts/bluetooth-recover ~/.local/bin/bluetooth-recover
```

### If you need to recover after every boot

A recovery script you run daily is a workaround, not a fix. Narrow it down.

If a **cold boot** fixes it but the fault returns, suspect a flaky device on
the controller. Use section 5 to find the port that fails to enumerate,
unplug it, and see whether the problem goes away.

If a cold boot does **not** fix it, suspect the kernel. This is where
keeping `linux-lts` installed alongside `linux` pays off, as recommended in
[chapter 6](./6_nvidia_dkms.md). Reboot and select the `LTS` kernel from
your boot menu, then run `bluetooth-check` again. The hardware, firmware,
cabling, and hub topology are all identical between the two boots, so the
kernel version is the only variable. If `LTS` works and mainline does not,
you have found a regression worth reporting, and you have a usable machine
in the meantime.

If both kernels fail after a cold boot, and the firmware checks in section
4 are clean, the adapter itself is the most likely explanation. A five
pound `USB` dongle is a quick way to confirm that before replacing anything
expensive.

---

## 10. Quick Reference

| Action | Command |
| --- | --- |
| Full status ladder | `bluetooth-check` |
| Escalating recovery | `sudo bluetooth-recover` |
| The one check that matters | `bluetoothctl show \| grep -E "Powered\|PowerState"` |
| Find the real adapter name | `ls /sys/class/bluetooth/` |
| Daemon state | `systemctl status bluetooth` |
| Kill switch state | `rfkill list bluetooth` |
| Clear a soft block | `rfkill unblock bluetooth` |
| Kernel errors this boot | `journalctl -k -b \| grep hci` |
| Controller errors | `journalctl -k -b \| grep xhci_hcd` |
| Decode an errno | `errno 110` (from `moreutils`) |
| Which controller hosts it | `readlink -f /sys/class/bluetooth/hci0` |
| USB tree and hub depth | `lsusb -t` |
| Identify the adapter vendor | `lsusb \| grep -i blue` |
| Firmware packages installed | `pacman -Qs linux-firmware` |
| Devices failing to enumerate | `journalctl -k -b \| grep "new .* USB device number"` |

| Symptom | Meaning |
| --- | --- |
| `Powered: no` / `PowerState: off` | Nothing tried to power it on. Config problem. |
| `Powered: no` / `PowerState: on` | Asked to power on, never answered. Hardware. |
| `Opcode 0x0c03 failed: -110` | `HCI_Reset` timed out. The adapter is not responding. |
| `Failed to set mode: Authentication Failed` | Misleading. Nothing is authenticating. Read the kernel log. |
| `Direct firmware load ... failed with error -2` | Firmware file missing. Install `linux-firmware-<vendor>`. |
| `xhci_hcd ...: Timeout while waiting` | The USB controller is struggling, not Bluetooth. |
| Same port, incrementing device number | A device is failing to enumerate. Unplug it. |

---

## Why this is harder than it should be

Three things conspire here.

The first is that "enabled" is used for four different states that are only
loosely related. Your desktop collapses them into one switch, and when that
switch fails there is no way from the graphical interface to learn which of
the four is at fault. The toggle is not broken and it is not lying; it
simply has one bit of output for a four-bit problem.

The second is that the error message you are given actively misleads.
"Authentication Failed" invites you to investigate pairing, which has
nothing to do with powering on a radio. That single misleading string is
responsible for an enormous amount of wasted effort, and the only defence
is knowing to drop down to the kernel log when `BlueZ` says something
that makes no sense for the operation you attempted.

The third is that the fault frequently is not in Bluetooth at all. When a
shared `USB` controller is struggling, the Bluetooth adapter is often the
first thing you notice, because a mouse dropping a packet is invisible
while a radio failing to power on is not. Treating Bluetooth as the
patient, when it is really the symptom, means you can spend a long time
fixing something that was never broken.

Once you separate the layers, which daemon is running, which switch is set,
which hardware is present, and whether the radio actually answered, each
one is individually simple to check. As with `Git` identity in
[chapter 14](./14_git_identity_and_credentials.md), it is only the overlap
that makes it hard.

| [← Previous](./14_git_identity_and_credentials.md) | [Next →](./16_battlenet.md) |
|:--|--:|
