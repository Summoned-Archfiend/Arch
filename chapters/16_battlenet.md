# Battle.net and a Window That Will Not Paint

This chapter covers three problems that arrive together. The first is that
you install Battle.net through `Lutris`, it works, and then you discover
there is no way to start it again. No desktop entry, no Steam shortcut,
nothing in your application menu. The second is that once you have built
a launcher by hand, the client opens a window that never draws anything.
The third is that having fixed the client, the game you launch from it
does exactly the same thing, for an entirely unrelated reason.

None of these is really about Battle.net. The first is about what an
installer writes down and what it quietly forgets. The second is about a
rendering setting whose correct value is not fixed, and changes underneath
you when you reboot. The third is about a translation layer being asked to
do something your hardware gains nothing from.

All three are worth working through carefully, because the diagnostic
habits here apply to anything you run under `Wine`. This is also a good
chapter for learning to distrust your own test results. Two separate
mechanisms in this chapter will hand you a clean, confident, wrong answer,
one in section 6 and one in section 10, and neither announces itself.

> **Note**
> The paths in this chapter assume a prefix at `/mnt/modded/Battle.net`
> and `GE-Proton10-27` under `~/.local/share/Steam/compatibilitytools.d/`.
> Substitute your own.

---

## 1. The Installer That Forgets

The `Lutris` Battle.net installer does a lot of work. It builds a `Wine`
prefix, installs the client, runs the updater, and will happily install a
game through it. What it does not reliably do is finish its own paperwork.

When it goes wrong, it goes wrong silently and you only find out later,
when you try to launch the thing a second time. Check all four places a
launcher could live:

```bash
sqlite3 ~/.local/share/lutris/pga.db \
  "select name,runner,directory,configpath,installed from games;"
ls ~/.config/lutris/games/
ls ~/.local/share/applications/ | grep -i battle
strings ~/.local/share/Steam/userdata/*/config/shortcuts.vdf | grep -i battle
```

A half-finished install looks like this:

```
Battle.net||||0
```

Read that carefully. The row exists, so `Lutris` knows the game. But
`runner`, `directory` and `configpath` are all empty and `installed` is
`0`. There is a name and nothing behind it. If `~/.config/lutris` does not
exist at all, there is no game configuration either, which means the
`Lutris` entry cannot launch anything no matter what you click.

The "add to Steam" option in the installer is worth checking separately,
because ticking it is no guarantee. If `shortcuts.vdf` comes back empty,
it did not write.

The lesson is that a working prefix and a working launcher are two
different deliverables. You can have the first without the second, and the
installer will not tell you which one you got.

---

## 2. Finding What Was Actually Installed

The prefix is intact even when the bookkeeping is not, so find it directly:

```bash
find / -name "Battle.net Launcher.exe" 2>/dev/null
```

Then look at the top of the prefix, because it tells you how it was built:

```bash
ls -la /mnt/modded/Battle.net/
cat /mnt/modded/Battle.net/config_info
cat /mnt/modded/Battle.net/version
```

Two files matter here. `version` names the `Proton` build that created the
prefix, and `config_info` records the full path to it. Use the build named
there. A prefix carries assumptions about the `Wine` version that made it,
and running a different one can trigger a prefix update you did not ask
for.

One line in that listing looks like a mistake and is not:

```
pfx -> .
```

A self-symlink. `Proton` expects a compatibility data directory containing
a `pfx` subdirectory, while `Wine` expects a prefix containing `drive_c`.
Pointing `pfx` at its own parent means the same directory satisfies both,
so the path works whether a tool treats it as a `Proton` data directory or
a plain `Wine` prefix. It is a neat trick, and worth recognising so you do
not try to "fix" it.

You will also find `Wine`-generated entries inside the prefix:

```bash
ls /mnt/modded/Battle.net/drive_c/proton_shortcuts/
```

These look promising and are not directly useful. Their `Exec=` lines
point at Windows `.lnk` paths, which your desktop cannot execute. They do
however carry a full extracted icon set under `icons/`, which saves you
pulling one out of the `.exe` yourself.

---

## 3. The Profile Name Trap

Before writing a launcher, look at who owns the prefix:

```bash
ls /mnt/modded/Battle.net/drive_c/users/
```

```
lukemccann  Public  steamuser
```

`Proton` creates its prefixes under the profile name `steamuser`, not your
Linux username. Both directories exist, but only one has anything in it.
The client's settings, and its saved login, live here:

```bash
cat "/mnt/modded/Battle.net/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
```

This matters more than it looks. `Wine` picks the profile directory from
your username, so a launcher started as yourself will use the empty
`lukemccann` profile. Nothing errors. The client simply comes up as though
freshly installed, having silently lost your saved login and every
rendering setting you configured. You then spend an hour debugging a
rendering problem you already solved, because the setting that solved it
is sitting in a profile nobody is reading.

Set the username explicitly:

```bash
export USER=steamuser
```

To confirm it worked, count the config files after a launch:

```bash
find /mnt/modded/Battle.net/drive_c/users -name "Battle.net.config"
```

One result means you are reading the right profile. Two means a second
profile was created and you are now maintaining settings in both.

---

## 4. Running Proton's Wine on Its Own

`Proton` ships a normal `Wine` build at `files/bin/wine`, and you can call
it directly. It is not normally called that way. The `proton` script sets
up the environment first, and one part of that matters:

```bash
PROTON="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-27"
export WINEDLLPATH="$PROTON/files/lib/wine"
export LD_LIBRARY_PATH="$PROTON/files/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Without these, `Proton`'s `Wine` resolves against your host libraries
instead of its own bundled ones. Sometimes that is harmless. Sometimes it
is not, and the failure is a rendering fault rather than a missing library
error, which makes it hard to attribute.

Two further environment variables are worth carrying, both inherited from
the original working configuration on this machine:

```bash
export WINEDLLOVERRIDES="locationapi="
export WINE_SIMULATE_WRITECOPY=1
```

An empty value in `WINEDLLOVERRIDES` disables a library outright, and
disabling `locationapi` avoids a stall some builds hit on the login page.
Be honest with yourself about settings like these. They were arrived at as
a group, and which individual one mattered was never isolated. Carrying a
setting you cannot justify is a small cost. Removing one you never tested
and then debugging its absence months later is a much larger one.

The alternative is to use the `proton` script itself:

```bash
export STEAM_COMPAT_DATA_PATH=/mnt/modded/Battle.net
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
"$PROTON/proton" run "C:\\Program Files (x86)\\Battle.net\\Battle.net Launcher.exe"
```

This is closer to how `Lutris` and `Steam` start things, and it is the
better comparison to reach for when you are trying to work out whether
your hand-built environment is the problem. It is worth keeping both
invocations around while diagnosing. If a fault appears under one and not
the other, the environment is implicated. If it appears under both, as it
did here, the environment is cleared and you can stop looking at it.

The launcher script for all this is
[`battlenet-launch`](../scripts/battlenet-launch).

---

## 5. The Window That Will Not Paint

Now the interesting failure. The client starts, processes are healthy, and
a window appears containing nothing. Sometimes it is solid black. Sometimes
it shows a frozen copy of whatever was on screen behind it when it opened.

That second symptom is the diagnostic one, so learn to recognise it. A
window showing stale desktop content is not rendering black. It is not
rendering at all. Nothing has ever been painted into it, so you are looking
at whatever was in that region of the framebuffer beforehand. An
application that draws a black screen has a content problem. An application
that draws nothing has a presentation problem, and those are different
faults with different causes.

First confirm the client is genuinely running, because "no window" and
"empty window" look identical from the desktop:

```bash
pgrep -af "Battle.net.exe" | head
```

The client is a `Chromium` browser in a trenchcoat, so a healthy launch
shows a process tree, not a single process:

```
Battle.net.exe --from-launcher
Battle.net.exe --type=gpu-process ...
Battle.net.exe --type=renderer ...
Battle.net.exe --type=utility --utility-sub-type=network.mojom.NetworkService ...
```

If the renderers and the GPU process are there, the client is fine. The
problem is in how its output reaches your screen.

---

## 6. The Stale Wineserver That Ruins Your Testing

Before changing anything, there is a trap here that will waste an
afternoon, and it is worth learning as a general `Wine` habit rather than
a Battle.net one.

`wineserver` outlives the application. Kill every visible `.exe` and it
keeps running, waiting for the next process. That is normally a feature,
since it makes subsequent launches fast. While you are testing fixes it is
actively harmful, because the next launch attaches to the old server and
inherits decisions made by the previous environment.

You find out when a launch prints this:

```
err:fsync:fsync_init Server is running with WINEFSYNC but this process is
not, please enable WINEFSYNC or restart wineserver.
```

That is a process attaching to a server it disagrees with. Any test you
run in that state tells you nothing, because you are not testing the
environment you think you set.

Check for it explicitly:

```bash
pgrep -af wineserver
```

And clear it properly between tests. Note that `wineserver -k` acts on the
prefix in `WINEPREFIX`, so setting it is not optional:

```bash
pkill -f "Battle.net.exe"
WINEPREFIX=/mnt/modded/Battle.net \
  ~/.local/share/Steam/compatibilitytools.d/GE-Proton10-27/files/bin/wineserver -k
```

Then confirm you actually have a clean slate before drawing any conclusion:

```bash
pgrep -c wineserver
pgrep -c '\.exe'
```

Both should return `0`. A launch from a clean prefix logs
`fsync: up and running` instead of the mismatch error, and that line is
your signal that the test is trustworthy.

The general habit is worth stating plainly. When you are changing one
variable at a time, make sure nothing is carrying state between your
attempts. Two of the tests in this chapter's original diagnosis were
invalidated this way, and both produced a confident, wrong conclusion.

---

## 7. Ruling Out the Usual Suspects

With clean tests available, work outwards from the most likely cause. The
point of this section is the order, not the individual commands.

**Driver version mismatch.** On `Arch` with `NVIDIA`, a driver upgrade
without a reboot leaves the kernel module and the userspace libraries on
different versions, and graphics applications fail in exactly this vague
way. Covered in [chapter 6](./6_nvidia_dkms.md), and always worth checking
first because it is common and it is cheap to rule out:

```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader
cat /proc/driver/nvidia/version
pacman -Q nvidia-580xx-utils nvidia-580xx-dkms
```

All three must agree. If they do not, reboot before going any further.

**Compositing.** A compositor that has fallen over produces stale window
content across the board:

```bash
qdbus org.kde.KWin /Compositor org.kde.kwin.Compositing.active
```

**Recent package changes.** If it worked yesterday and not today,
something moved. Find out what:

```bash
grep "upgraded" /var/log/pacman.log | tail -30
uptime -s
```

Compare the last upgrade against the last boot. This is the step that
reframed the whole diagnosis here. Nothing had been upgraded since the
client last worked, but the machine had rebooted in between. That rules
out the software stack and points at runtime state, which is a much
smaller place to look.

**Graphics API.** The client renders through `D3D11`, which under `Wine`
usually means `DXVK` and therefore `Vulkan`. You can force the older
`OpenGL` path instead and see if presentation behaves differently:

```bash
WINEDLLOVERRIDES="d3d11=b;dxgi=b;d3d10core=b" ...
```

`b` means builtin, which is `Wine`'s own implementation rather than
`DXVK`. If the window paints under `OpenGL` and not under `Vulkan`, you
have found your culprit. Here it did not, which cleared the graphics API
and left one suspect.

---

## 8. Browser Hardware Acceleration, and Why It Flips

The client has its own rendering setting, under **Settings**, **App**,
**Browser Hardware Acceleration**. It lives here:

```bash
grep HardwareAcceleration \
  "/mnt/modded/Battle.net/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
```

This single toggle decides whether the embedded browser composites on the
GPU or on the CPU, and under `Wine` both settings have a well-known
failure. Accelerated, it can produce the unpainted window from section 5.
Unaccelerated, it can produce a plain white page where the login form
should be.

Here is the part that catches people out. **There is no permanently
correct value.** On this machine, turning acceleration *on* fixed a white
login screen one day, and turning it *off* fixed an unpainted window the
next, with no package upgrades in between. The only event separating the
two was a reboot.

So do not memorise a value. Memorise the pair of symptoms and which way to
move the toggle:

| Symptom | Move the toggle |
| --- | --- |
| Window never paints, black or stale desktop content | Turn acceleration **off** |
| Window paints, but the page is blank white | Turn acceleration **on** |

You can edit it without launching the client, which matters when the
client's own settings screen is inside the window you cannot see. Always
take a backup first, since the client rewrites this file on exit:

```bash
cfg="/mnt/modded/Battle.net/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
cp "$cfg" "$cfg.bak-$(date +%Y%m%d-%H%M%S)"
sed -i 's/"HardwareAcceleration": "true"/"HardwareAcceleration": "false"/' "$cfg"
```

Stop the client and clear the `wineserver` first, per section 6, or your
edit will be overwritten when the running client saves its own copy on the
way out.

Those timestamped backups are more useful than they look. A backup from
before a working login has no `SavedAccountNames` and a default region,
while one from after does. Diffing them tells you what a successful
session actually changed, which is a quick way to confirm which
configuration genuinely worked rather than relying on memory.

---

## 9. Building the Desktop Entry

With a launcher that works, give it a proper entry. Install the icons that
`Wine` already extracted:

```bash
src=/mnt/modded/Battle.net/drive_c/proton_shortcuts/icons
for s in 16x16 24x24 32x32 48x48 64x64 128x128 256x256; do
    d="$HOME/.local/share/icons/hicolor/$s/apps"
    mkdir -p "$d"
    cp "$src/$s/apps/"*"Battle.net Launcher"*.png "$d/battlenet.png" 2>/dev/null
done
```

Then write `~/.local/share/applications/battlenet.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Battle.net
Comment=Battle.net in the GE-Proton10-27 prefix
Exec=/home/YOUR_USER/.local/bin/battlenet-launch
Path=/mnt/modded/Battle.net/drive_c/Program Files (x86)/Battle.net
Icon=battlenet
Terminal=false
StartupNotify=true
StartupWMClass=battle.net.exe
Categories=Game;
```

`Exec` must be an absolute path. Desktop entries do not run through your
shell, so `~` is not expanded and your `PATH` is not necessarily what you
expect.

`StartupWMClass` is the line people leave out, and it is the one that
makes pinning behave. It tells your desktop which window belongs to this
entry. Without it you get a second, unpinnable taskbar item every launch
instead of the window attaching to the icon you pinned. If the window
still does not attach, read the class off the running window and correct
it:

```bash
for id in $(xprop -root _NET_CLIENT_LIST | sed 's/.*# //; s/,//g'); do
    xprop -id "$id" WM_CLASS
done
```

Register the entry, then validate it:

```bash
update-desktop-database ~/.local/share/applications
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
desktop-file-validate ~/.local/share/applications/battlenet.desktop
```

`desktop-file-validate` prints nothing when the file is correct. It will
catch a missing `Type` or a malformed `Categories` line, both of which
otherwise fail by the entry simply not appearing.

To pin it, launch it, right-click the taskbar item and choose **Pin to
Task Manager**. Pinning the running window rather than dragging the menu
entry is the more reliable route, because it pins the entry your desktop
has already matched to a real window.

---

## 10. The Game Is a Separate Problem

Getting the client to paint does not get the game to paint. They are
different applications with different renderers, and fixing one tells you
nothing about the other. Expect to do this twice.

The symptom here was a black screen with a green patch in the middle. The
music played perfectly throughout, which is the useful detail. Audio
running while the picture is dead means the process is alive and only the
graphics side has died, so you are looking for something that kills
rendering without killing the application.

Unlike the client, the game keeps a proper log:

```bash
cd "/mnt/modded/Battle.net/drive_c/Program Files (x86)/World of Warcraft/_retail_/Logs"
cat gx.log
```

It is worth reading in full, because it states the hardware it found, the
API it chose, and what went wrong, in that order. The relevant lines:

```
GpuInfo: sm:dx_5_0, rt:None, vrs:0, bary:0, mesh:0 pull:1
D3d12 Device Create
D3d12 Device Create Successful (430.4 ms)
...
Error WaitForSingleObjectEx Timeout: Unknown error 0x80070102
Device Removed Reason: GPU Hung. Timeout when waiting for queue: Direct
Device context was lost. Attempting recovery. Occurrence: 1
```

Read that top to bottom. The game chose `D3D12`, created the device
successfully, and then the GPU hung waiting on the direct queue. A
successful device creation is not a promise that rendering works, which is
why "it starts and then dies" is such a common shape for this failure.

Under `Wine`, `D3D12` is translated by `VKD3D-Proton` into `Vulkan`, and
that translation layer is considerably less mature than `DXVK` is for
`D3D11`. On older hardware it is a reasonable bet for this kind of hang.
The `GpuInfo` line tells you what you are giving up by avoiding it:
`rt:None` for raytracing, `vrs:0` for variable rate shading, `mesh:0` for
mesh shaders, and `sm:dx_5_0` for the shader model. A `Pascal` card such
as a `GTX 1080` supports none of the features that justify `D3D12` in the
first place, so switching to `D3D11` costs nothing real.

### The setting, and the trap around it

The API lives in `Config.wtf`:

```bash
grep gxApi "/mnt/modded/Battle.net/drive_c/Program Files (x86)/World of Warcraft/_retail_/WTF/Config.wtf"
```

Before trusting that a change took, confirm the client can honour it:

```bash
strings -n 4 Wow.exe | grep -xE "D3D1[12]"
```

If `D3D11` is not in the binary, no amount of configuration will select
it, and you need to look at the translation layer instead.

Now the trap, and it is the same lesson as section 6 wearing different
clothes. **The game rewrites `Config.wtf` from its own settings when it
exits cleanly.** Edit the file while the game is running and your change
is silently discarded on the way out. Worse, it is discarded without
error, so the next launch looks like the fix simply did not work, and you
go off investigating a fix that was never actually applied.

That happened during this diagnosis. A `Config.wtf` written while the game
was up was replaced wholesale by a full generated config containing
`SET gxApi "D3D12"`, and the next run looked like proof that forcing
`D3D11` had no effect. It was proof of nothing except that the file had
been overwritten.

So close the game first, confirm it, then edit:

```bash
pgrep -c '[W]ow.exe'
```

That must return `0`. The bracket around the first letter stops `pgrep`
matching its own command line, which otherwise reports a process that does
not exist and sends you looking for a phantom.

Then change the value in place rather than rewriting the file:

```bash
cfg=".../World of Warcraft/_retail_/WTF/Config.wtf"
cp "$cfg" "$cfg.bak-$(date +%Y%m%d-%H%M%S)"
sed -i 's/^SET gxApi "D3D12"/SET gxApi "D3D11"/' "$cfg"
```

Editing in place matters for two reasons. It preserves every other
setting, and it preserves the `CRLF` line endings the game writes. Check
that you have not converted them:

```bash
grep -a gxApi "$cfg" | xxd | tail -1
```

The line must still end `0d 0a`. A file rewritten by a Linux tool with
bare `0a` endings is a gamble you do not need to take with a Windows
application's parser.

### Confirming it took

Launch, then read the log rather than trusting your eyes:

```bash
grep -aE "Device Create|GPU Hung|Device Lost" gx.log
```

A working launch says:

```
Dx11 Device Create Successful (227.0 ms)
Using shader family dx_5_0
```

`Dx11` rather than `D3d12`, and no hang lines following it. Counting is a
good habit here, since a clean result is the absence of something:

```bash
grep -acE "GPU Hung|Device Removed|Device Lost" gx.log
```

Zero is the answer you want.

One consequence to remember. Because the game rewrites this file on exit,
setting the graphics API from the in-game menu will override what you put
there. That is fine, and it is the better place to change it once the game
is actually running well enough to reach its own settings screen.

---

## 11. Quick Reference

| Action | Command |
| --- | --- |
| Launch | `battlenet-launch` |
| Find the install | `find / -name "Battle.net Launcher.exe" 2>/dev/null` |
| Which Proton built the prefix | `cat <prefix>/version` |
| Full path to that build | `cat <prefix>/config_info` |
| Check Lutris bookkeeping | `sqlite3 ~/.local/share/lutris/pga.db "select * from games;"` |
| Confirm one profile only | `find <prefix>/drive_c/users -name "Battle.net.config"` |
| Is the client really running | `pgrep -af "Battle.net.exe"` |
| Find a stale wineserver | `pgrep -af wineserver` |
| Clear it | `WINEPREFIX=<prefix> <proton>/files/bin/wineserver -k` |
| Read the render setting | `grep HardwareAcceleration <prefix>/.../Battle.net.config` |
| Driver agreement | `nvidia-smi --query-gpu=driver_version --format=csv,noheader` |
| Loaded kernel module | `cat /proc/driver/nvidia/version` |
| Compositor alive | `qdbus org.kde.KWin /Compositor org.kde.kwin.Compositing.active` |
| Last upgrade vs last boot | `grep upgraded /var/log/pacman.log \| tail -5; uptime -s` |
| Force the OpenGL path | `WINEDLLOVERRIDES="d3d11=b;dxgi=b;d3d10core=b"` |
| Validate a desktop entry | `desktop-file-validate <file>.desktop` |
| Read a window's class | `xprop -id <id> WM_CLASS` |
| Which API the game chose | `grep -a "Device Create" <wow>/Logs/gx.log` |
| Count graphics failures | `grep -acE "GPU Hung\|Device Removed" <wow>/Logs/gx.log` |
| Read the game's API setting | `grep -a gxApi <wow>/WTF/Config.wtf` |
| Force the game to D3D11 | `sed -i 's/^SET gxApi "D3D12"/SET gxApi "D3D11"/' <wow>/WTF/Config.wtf` |
| Confirm the game is closed | `pgrep -c '[W]ow.exe'` |
| Which APIs the game supports | `strings -n 4 Wow.exe \| grep -xE "D3D1[12]"` |

| Symptom | Meaning |
| --- | --- |
| Lutris row with empty `runner` and `installed=0` | Prefix built, bookkeeping never finished. Launch it yourself. |
| Window shows stale desktop content | Never painted. Presentation fault, not a content fault. |
| Window is plain white | Painted, but nothing rendered into it. Try acceleration on. |
| `err:fsync:fsync_init Server is running with WINEFSYNC` | Stale `wineserver`. Your test result is invalid. |
| Client settings look factory fresh | Wrong profile. Set `USER=steamuser`. |
| Second taskbar item on launch | `StartupWMClass` missing or wrong. |
| `pfx -> .` in the prefix root | Deliberate. Serves as both prefix and Proton data directory. |
| Game black with green, music still playing | Graphics queue died, process alive. Read `gx.log`. |
| `GPU Hung. Timeout when waiting for queue: Direct` | `VKD3D` translating `D3D12`. Force `D3D11`. |
| Game config edit had no effect | It was rewritten on exit. Close the game first. |
| `D3d12 Device Create Successful` then a hang | Device creation succeeding proves nothing about rendering. |

---

## Why this is harder than it should be

Three things make this worse than the sum of its parts.

The first is that a successful install and a usable application are
treated as the same outcome, and they are not. The installer finished, the
prefix works, the game is on disk, and there is still no way to start it.
Nothing failed loudly enough to be noticed, so you only discover the gap
later, by which point you have no reason to suspect the installer and go
looking for your own mistake instead.

The second is that the failure has no content. A window that never paints
gives you nothing to search for. There is no error string, no dialog, no
log line, and the process tree looks perfectly healthy throughout. You are
reduced to reasoning about which layer between the application and the
screen could fail while leaving every other symptom untouched, and that is
a much harder starting position than any error message, however cryptic.
Learning to read the stale-content symptom as "never painted" rather than
"painted black" is most of the progress available here.

The third, and the one genuinely worth taking away, is that the correct
setting changed without anything being installed or configured. The same
toggle that fixed the problem one day caused it the next. If you approach
that expecting a fixed answer, you conclude you must have misremembered
what you did before, and you start undoing good work. The honest position
is that this toggle selects between two rendering paths that are each
fragile under `Wine` in different conditions, and which one is currently
broken depends on runtime state that a reboot is enough to disturb.

That is also why section 6 matters more than it first appears. When the
correct answer can change between attempts, your ability to trust a single
test result is the only thing keeping the diagnosis honest. A stale
`wineserver` quietly carrying state between two runs does not just cost
you a test. It produces a confident, clean-looking result that happens to
be wrong, and a wrong result you believe is far more expensive than no
result at all.

The game half of this chapter makes the same point from the other
direction. There the state was not carried by a running process but
written to disk by the application itself, on exit, over the top of the
change you had just made. The mechanism is completely different. The
result is identical: a test that appears to disprove a correct fix.

If there is one habit to take from all of this, it is to ask what else
could be writing to the thing you are changing, and what else could be
reading it. A `wineserver` that outlives its client, a game that saves its
configuration on shutdown, and a `Wine` profile chosen from your username
are three unrelated mechanisms, and every one of them will quietly discard
your work and let you believe you tested something you never tested.

| [← Previous](./15_bluetooth.md) |
|:--|
