# RGB Lighting and Fan Control with Prism

On Windows, Corsair hardware is driven by `iCUE`: one program for the case
fans, the AIO pump, the lighting, fan curves and profiles. There is no Linux
build of `iCUE`, and nothing on Linux does the whole job. `OpenRGB` reaches
almost every lighting controller, `liquidctl` reaches most Corsair and NZXT
coolers, and the kernel reads fan speeds, but each covers only part of it, and
they get in each other's way when you use them together.

This chapter covers why the obvious tools fall short, how to see exactly what
your hardware offers, and how to use
[Prism](https://github.com/VTech-Studios/Prism), a desktop app that brings
lighting effects, fan curves, profiles and automatic switching together in
one window.

A read-only script, `rgb-check`, shows what is connected and what is likely
to be fighting over it.

> **Note**
> The examples come from a desktop with a `Corsair Commander Pro` driving six
> RGB fans through a `Corsair RGB Fan LED Hub`, a `Corsair H115i Platinum` AIO,
> four sticks of `ENE` RGB RAM and an `ASUS ROG STRIX GTX 1080`. Prism drives
> the Commander Pro and the Hydro Platinum coolers directly, and anything else
> through `OpenRGB`. Your controllers, header numbers and LED counts will
> differ.

---

## 1. Why the Obvious Tools Fall Short

The first thing most people install is `OpenRGB`, and for RAM, GPUs and
motherboards it is excellent. Corsair's fan controllers are harder:

* **Opening OpenRGB resets your controllers.** Every time it starts, the
  GUI or the server, it detects every device and puts each one into its
  own `Direct` mode. Lighting that the controller had been playing by itself
  for months, stored in its memory by `iCUE` on Windows, is gone, and the
  fans go dark until something sends them a new effect.
* **On a Commander Pro it can only show a still frame.** OpenRGB's `Rainbow
  Wave` lights all six fans, but the rainbow does not move.
* **liquidctl animates in hardware, but only one fan.** `liquidctl set sync
  color rainbow` gives a real moving effect that keeps running with nothing
  installed, but on a hub of six fans only the first fan lights.

The last one has a specific cause. A Commander Pro channel has no idea how
many LEDs are wired to it. Every hardware effect is sent with a start LED and
an LED count, and the controller plays the effect across exactly that many.
Six fans with twelve LEDs each is 72 LEDs. If the effect only covers the
first twelve, only the first fan lights. Prism sends every effect across the
channel's full count, which you set once.

Fan control has its own gap. The Commander Pro can run fan curves by itself,
but only against its own temperature probes, and most people never plug
them in. Without probes, something has to read the CPU temperature and set
the fan speed, every second, for as long as the machine is on.

---

## 2. Seeing What You Have

Before installing anything, find out what is actually connected. Corsair's
USB vendor ID is `1b1c`:

```bash
lsusb -d 1b1c:
```

```
Bus 001 Device 008: ID 1b1c:0c10 Corsair Commander PRO
```

The kernel has drivers for several fan controllers that publish fan speeds
under `/sys/class/hwmon`. Only headers with a fan plugged in get a label:

```bash
for d in /sys/class/hwmon/hwmon*; do echo "$d $(cat $d/name)"; done
grep . /sys/class/hwmon/hwmon*/fan*_label
```

```
/sys/class/hwmon/hwmon2/fan1_label:fan1 4pin
/sys/class/hwmon/hwmon2/fan2_label:fan2 4pin
/sys/class/hwmon/hwmon2/fan3_label:fan3 4pin
/sys/class/hwmon/hwmon2/fan6_label:fan6 4pin
```

`4pin` means the header is in `PWM` mode, so its speed can be set. Headers 4
and 5 have nothing on them.

`rgb-check` does all of this in one go, plus permissions and conflicts:

```bash
install -Dm755 scripts/rgb-check ~/.local/bin/rgb-check
rgb-check
```

```
1. Controllers on the USB bus
  [ ok ] 1b1c:0c10 Corsair Commander PRO

2. Kernel fan drivers
  [ ok ] corsaircpro (/sys/class/hwmon/hwmon2)
         fan1 4pin: 1650 RPM
         ...

3. Device permissions
  [ ok ] /dev/hidraw0 (Corsair Commander PRO) is readable and writable

4. OpenRGB
         OpenRGB is not running
         OpenRGB detects: Corsair Commander Pro

5. Other things driving the hardware
  [warn] user service pump-temp-rgb.service is active
```

The AIO is missing from section 1 even though its pump is plainly running.
That is the Hydro Platinum's most common fault, covered in section 9.

---

## 3. Permissions

Talking to a USB controller means opening its `/dev/hidrawN` node, which is
root-only by default. You do not want a lighting app running as root. The
`openrgb` and `liquidctl` packages both ship `udev` rules that tag supported
devices with `uaccess`, which gives the logged-in user access:

```bash
sudo pacman -S openrgb liquidctl
```

```bash
pacman -Ql openrgb liquidctl | grep udev/rules
```

```
openrgb /usr/lib/udev/rules.d/60-openrgb.rules
liquidctl /usr/lib/udev/rules.d/71-liquidctl.rules
```

`uaccess` is applied when you log in, so log out and back in after
installing. `rgb-check` section 3 then shows `[ ok ]`. You do not need to
add yourself to the `i2c` group either; the same rules cover the RAM and
GPU's `i2c` buses.

---

## 4. Installing Prism

Prism is written in Python with Qt. Install its dependencies from the
official repositories, which keeps them updated with the rest of the system:

```bash
sudo pacman -S --needed pyside6 python-psutil python-hidapi liquidctl openrgb python-pipx
```

Then clone it and install it with `pipx`, which gives it its own
environment but, with `--system-site-packages`, reuses the packages above
instead of downloading a second copy of Qt:

```bash
git clone https://github.com/VTech-Studios/Prism.git ~/Projects/Prism
pipx install --system-site-packages --editable ~/Projects/Prism
```

`--editable` means a `git pull` in `~/Projects/Prism` updates the installed
app without reinstalling. To put Prism in the application menu with its
icon:

```bash
install -Dm644 ~/Projects/Prism/prism/ui/assets/prism.svg \
    ~/.local/share/icons/hicolor/scalable/apps/prism.svg
install -Dm644 ~/Projects/Prism/packaging/prism.desktop \
    ~/.local/share/applications/prism.desktop
```

> **Note**
> `pipx` puts the `prism` command in `~/.local/bin`. If `which prism` finds
> nothing, that directory is not on your `PATH`. `pipx ensurepath` adds it.

---

## 5. Before the First Run

Two programs driving the same controller undo each other's work many times
a second, so clear the field first.

**Stop anything else that drives the hardware.** If you wrote your own
script or service for the pump colour or fans, turn it off. `rgb-check`
section 5 lists anything that looks like one:

```bash
systemctl --user disable --now pump-temp-rgb.service
```

**Keep the OpenRGB window closed.** Prism starts a hidden OpenRGB server by
itself for the RAM, GPU and motherboard. Opening the OpenRGB GUI while Prism
runs reinitialises every controller.

**Stop OpenRGB detecting the Corsair devices.** Prism drives the Commander
Pro and the Hydro Platinum itself, and when OpenRGB detects them it resets
them. On a Hydro Platinum it can knock the cooler off USB altogether. In
Prism, *Settings > Hardware > Keep OpenRGB away from Corsair devices* turns
those detectors off in `~/.config/OpenRGB/OpenRGB.json` and keeps a backup
beside it. `rgb-check` section 4 then reports `OpenRGB will not detect` for
each one.

**Set the LED count.** *Settings > Hardware > Commander Pro channel 1* is how
many LEDs are on that channel: twelve for each Corsair RGB fan, so 72 for six.
Get this wrong and you are back to only some fans lighting.

---

## 6. Running It

```bash
prism            # open the window
prism --hidden   # start in the tray
prism --debug    # also log device traffic to the terminal
```

Closing the window hides Prism to the tray rather than quitting it, because
fan curves only work while it runs. Quit from the tray menu. Launching it a
second time just brings the existing window forward, since two copies would
fight over the same devices.

On the first run, Prism makes three profiles fitted to whatever is
connected: **Default**, **Quiet** and **Performance**. Expect two things in
the first half minute:

* The RAM and GPU show as offline on the dashboard. OpenRGB's server opens
  its port before it has finished detecting devices, so Prism waits and
  tries again every ten seconds. The fans are driven the whole time.
* If you have not hidden the Corsair devices from OpenRGB yet, the
  fan lighting may go dark briefly while OpenRGB detects them. Prism sends
  everything again once OpenRGB is ready.

---

## 7. Lighting

The *Lighting* page lists every lighting zone: one per Commander Pro
channel, the pump head, and one per OpenRGB device. Pick a zone, then an
effect: Static, Breathing, Spectrum Cycle, Rainbow Wave, Colour Wave,
Marquee, Blink or Temperature. Colours, speed, direction and brightness
appear when the effect uses them, and a live preview draws the zone as it
will look. A channel of whole fans is drawn as rings of twelve.

Each zone's badge says who is playing the effect:

* **Device** means the controller plays it by itself. It keeps running
  after Prism closes, the way `iCUE`'s hardware lighting does.
* **Prism** means Prism draws it, frame by frame. This allows effects the
  device has no hardware mode for, such as Temperature. Every zone Prism
  draws shares one clock, so a rainbow on the fans and the RAM stays in step.

*Settings > Lighting > Let devices play effects themselves* chooses between
the two where both are possible. Turn it off to have Prism draw everything,
in sync.

**Temperature** colours a zone by any sensor: green when cool, amber when
warm, red when hot. On the pump head, following the coolant, it is the
classic `iCUE` look. *Use on every zone* copies the selected zone's effect
to every zone that can show it.

---

## 8. Fan Curves and Keeping Fans Safe

The *Cooling* page shows every fan with its live speed. Each fan can be:

* **Fixed speed:** one duty, held.
* **Following a sensor:** a curve of temperature against duty. Drag the
  points, or start from *Quiet*, *Balanced* or *Performance*. The chart
  marks the current reading and the duty it gives.

Radiator fans on an AIO are best set to follow the coolant temperature
rather than the CPU. Coolant changes slowly, so the fans do not rev every
time the CPU spikes. The starter profiles already do this. The *AIO pump*
card sets the pump mode.

A program in charge of fans has to fail safely, so Prism holds a few rules
no profile can break:

| Rule | Why |
| --- | --- |
| No fan goes below the *Lowest fan speed* setting | A bad curve cannot stall a fan. |
| A fan whose sensor stops reporting runs at 80% | Running loud is better than running hot without anyone knowing. |
| Fans speed up at once but slow down a few percent per second | A brief dip in temperature does not make them hunt up and down. |
| A fan a profile does not mention follows a default Balanced curve | How a fan behaves never depends on which profile ran before. |
| On exit, every fan is left at *Speed when Prism closes* | Nothing adjusts them once Prism is gone, so it should be a speed that is safe under load. |
| After suspend, every device is reopened and set up again | Controllers wake in their power-on state. |

You can check the speeds Prism sets without opening it:

```bash
grep . /sys/class/hwmon/hwmon*/fan*_input
```

---

## 9. When the AIO Disappears

The Hydro Platinum coolers have a well-known fault: the USB side of the
pump stops responding while the pump itself keeps running on SATA power. The
pump light flashes red and blue, its firmware's "nothing is talking to me"
pattern, and the cooler vanishes from USB:

```bash
lsusb -d 1b1c:0c13     # H115i Platinum; empty when it has dropped off
liquidctl list         # only the other devices are listed
```

Prism shows it as offline on the dashboard and keeps trying every ten
seconds, so if it comes back, Prism picks it up again by itself. A plain
reboot often does not fix it, because the PSU keeps the pump powered. Shut
down fully, switch off at the PSU for a few seconds, and start again. If it
keeps happening, the usual trigger is something detecting the cooler, most
often OpenRGB, which is why section 5 hides it.

---

## 10. Profiles and Automatic Switching

A profile is a complete setup: an effect per zone, a setting per fan, and a
pump mode. The *Profiles* page creates, copies, renames and deletes them,
and exports them as `.json` files to back up or share. The profile picker at
the bottom of the sidebar, or the tray menu, switches between them.

The *Automation* page holds rules that switch profile by themselves:

* **A reading goes above** a threshold, such as `CPU load above 80` for
  a long render.
* **A program is running**, such as `wow.exe`. Games run through `Wine` or
  `Proton` are matched by the name of their `.exe`, which is the name you
  know them by.

Each rule has a *settle time*: how long the condition must hold before
switching, and how long it must stop before switching back. A ten-second
CPU spike does not throw the fans into Performance. Rules are checked top
to bottom and the first one that applies wins, so put the most important
first. When none applies, the profile you chose by hand shows. The tray menu
can pause automatic switching without opening the window.

---

## 11. Starting at Login

*Settings > General > Start at login* adds an `XDG` autostart entry,
`~/.config/autostart/prism.desktop`, that runs `prism --hidden`. Every
desktop environment honours that folder. Prism's own files live in the
usual places:

| File | Holds |
| --- | --- |
| `~/.config/prism/profiles.json` | Profiles |
| `~/.config/prism/rules.json` | Automation rules |
| `~/.config/prism/settings.json` | Settings |
| `~/.local/state/prism/prism.log` | The log |

If something is not doing what you expect, the log is the first place to
look, and `prism --debug` shows the same in the terminal as it happens.

---

## Why This Is Harder Than It Should Be

None of the tools here is broken. `OpenRGB` does exactly what it says:
detect every device and give you control of it. `liquidctl` does too. The
trouble is that the hardware was designed for one program, `iCUE`, that
owned everything, and Linux gives you several programs that each assume the
same thing. Two programs that each assume they own a controller will undo
each other's work all day, and neither will report an error, because from
each one's point of view nothing went wrong.

The single-fan rainbow is the same lesson in miniature. Nothing failed, and
the controller did exactly what it was told. It was just told about the
first twelve LEDs instead of all 72. When a device half works, the question
is not "what is broken" but "what was it actually told", and the answer is
usually one number short of the truth.

And anything that drives fans has to be judged by what happens when it goes
wrong, not by how it looks when it goes right. A pretty curve editor is
worth nothing if a crashed sensor leaves the fans idling under a full load.
Fail loud and fail fast is the right instinct for most software. For fans,
fail fast means fail at 80%.

| [← Previous](./21_slow_boot_and_login.md) | [Next →](./23_remote_access_while_away.md) |
|:--|--:|
