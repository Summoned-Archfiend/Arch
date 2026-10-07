# Rocksmith 2014 Through a Real Audio Interface

`Rocksmith 2014` was built around one piece of hardware: the **Real Tone
Cable**, a jack-to-USB lead that shows up as a tiny sound card. Plug a guitar
into it and the game hears you. Plug a guitar into anything else, such as a
proper audio interface with a real preamp, and the game ignores it. It does
not offer a list of inputs. It looks for its cable, and if the cable is not
there, there is no guitar.

On `Windows` the community answer is `RS_ASIO`, a small mod that makes any
`ASIO` audio device look like the cable. On `Linux` the same mod works, but
it sits at the top of a chain of five layers, and every one of them has to
agree before you hear a note. The game also has a habit of failing in the
least helpful way possible: everything is connected, nothing reports an
error, and the tuner shows a flat line.

This chapter builds that chain one link at a time, explains why each link
exists, and then walks through the silent failure that remained once it was
all in place. A script, `rocksmith-asio`, checks every link for you and does
the fiddly parts.

> **Note**
> The examples use a `Focusrite Scarlett 2i2 4th Gen`, `Steam` installed
> natively (not the `Flatpak`), and `GE-Proton11-7`. Rocksmith's Steam app
> id is `221680`, which is the folder name you will see under
> `compatdata`. Substitute your own interface and Proton build.

---

## 1. The Chain, and Why Each Link Exists

Here is the whole path, from the guitar to the game and back out to your
headphones:

```
guitar ──► interface input 1 ──► PipeWire ──► PipeASIO ──► RS_ASIO ──► Rocksmith
                                                                          │
headphones ◄── interface outputs ◄── PipeWire ◄── PipeASIO ◄── RS_ASIO ◄──┘
```

Read it from the right, because that is the order of the problems.

**`Rocksmith`** asks `Windows` for its cable using `WASAPI`, the normal
Windows audio interface. It wants exactly one specific device, at 48 kHz.

**`RS_ASIO`** intercepts that request. It answers with a fake `WASAPI` device
that pretends to be the cable, and behind the fake it feeds the game from an
`ASIO` driver of your choosing. `ASIO` is the low-latency driver standard
Windows music software uses. The game never knows the difference.

**`PipeASIO`** is that `ASIO` driver. It runs inside `Wine` and hands audio
straight to `PipeWire`. To anything in the `Wine` prefix it looks like a
normal Windows sound card driver. To `PipeWire` it looks like a normal audio
application, with input and output ports you can see and route.

**`PipeWire`** connects those ports to your interface.

**The interface** turns the guitar into a digital signal at the bottom of
the chain, and turns the game's output back into sound at the top.

You may come across `WineASIO` in older guides. It does the same job as
`PipeASIO`, but it was built around `JACK` and the older way `Wine` ran
32-bit programs, and that second point is the one that matters for a game
from 2014. Section 2 explains why.

---

## 2. A 32-bit Game on a 64-bit System

`Rocksmith 2014` is a **32-bit** Windows program. That used to mean `Wine`
needed a complete 32-bit copy of itself and of every Linux library it
touched, which is why `Arch` has a whole `multilib` repository of `lib32-`
packages.

Newer `Wine` has a different mode, called **new WoW64**, after the
mechanism 64-bit `Windows` uses to run 32-bit programs. The 32-bit Windows
code still runs as 32-bit, but every time it needs to talk to Linux it is
translated into calls to ordinary 64-bit Linux libraries. No 32-bit Linux
userspace is involved.

You can see this in how `PipeASIO` is packaged:

```bash
pacman -Ql pipeasio | grep -E '\.(dll|so)$'
```

```
pipeasio /usr/lib/wine/i386-windows/pipeasio32.dll
pipeasio /usr/lib/wine/x86_64-unix/pipeasio32.so
pipeasio /usr/lib/wine/x86_64-unix/pipeasio64.so
pipeasio /usr/lib/wine/x86_64-windows/pipeasio64.dll
```

Look at the second line. The Linux half of the **32-bit** driver,
`pipeasio32.so`, lives in `x86_64-unix`. It is a 64-bit library. That only
works under new WoW64, and `Proton` does not use new WoW64 for 32-bit games
unless you ask it to:

```
PROTON_USE_WOW64=1
```

Without that variable the game runs, the driver is registered, and the
driver simply fails to load. Nothing tells you why.

---

## 3. The Container You Cannot See

The next trap is where `Proton` looks for files.

Steam does not run `Proton` directly on your system. It runs it inside a
container, `pressure-vessel`, part of the **Steam Linux Runtime**. The point
is consistency: every player's `Proton` sees the same libraries, regardless
of distribution. The cost is that the container does **not** show `Proton`
your `/usr/lib/wine`. A driver installed system-wide by `pacman` is, as far
as the game is concerned, not installed.

The container does show your home directory. So the fix is to copy the
driver under `$HOME` and tell `Proton` where it is:

```bash
for f in i386-windows/pipeasio32.dll x86_64-windows/pipeasio64.dll \
         x86_64-unix/pipeasio32.so x86_64-unix/pipeasio64.so; do
    install -Dm644 "/usr/lib/wine/$f" "$HOME/.local/lib/wine/$f"
done
```

```
WINEDLLPATH=/home/<you>/.local/lib/wine
```

`WINEDLLPATH` is a list of extra places `Wine` searches for its libraries.
Use the full path. Steam launch options are not run through your shell, so
`~` and `$HOME` are not expanded.

The copy has a cost you need to remember. When `pipeasio` is updated by
`yay`, the files in `/usr/lib/wine` change and your copy does not. The game
keeps loading the old version. Re-copy after every `pipeasio` update.
`rocksmith-asio status` (section 9) compares the two and tells you when they
have drifted apart.

---

## 4. Installing and Pinning PipeASIO

`PipeASIO` is in the `AUR`:

```bash
yay -S pipeasio
```

Before you configure it, find out what `PipeWire` calls your interface.
Sources are inputs and sinks are outputs:

```bash
pactl list short sources | awk '$2 !~ /\.monitor$/ {print $2}'
pactl list short sinks   | awk '{print $2}'
```

```
alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic1__source
alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic2__source
...
alsa_output.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Line1__sink
bluez_output.<address>.1
```

On a `Scarlett`, `Mic1` and `Mic2` are the two physical inputs, whatever is
plugged into them. The guitar was in input 1, so `Mic1`.

Now the important part. Left alone, `PipeASIO` connects to whatever your
**default** input and output are. On the machine this chapter was written
from, the default output was a Bluetooth speaker. Bluetooth audio adds a
delay you can easily hear, often well over 100 ms, which makes a rhythm game
unplayable, and the cause would be invisible from inside the game. So pin
the driver to the interface in `~/.config/pipeasio/config.ini`:

```ini
[pipeasio]
; Rocksmith uses one guitar input and a stereo output.
inputs=1
outputs=2
; Pinned so the driver never follows the desktop default.
input_device=alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic1__source
output_device=alsa_output.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Line1__sink
; 0 lets the game ask for the 48 kHz it requires.
sample_rate=0
; Let the game set the buffer size, starting from 256.
fixed_buffer_size=0
buffer_size=256
```

The driver reads this file every time it starts, and again while it is
running, so you can change the buffer size without restarting the game.

---

## 5. A Clean Prefix and the Launch Options

In Steam, open Rocksmith's **Properties**:

1. **Compatibility**: force a `Proton` 11 or newer build. `GE-Proton11-7`
   was used here.
2. **General**, **Launch Options**:

```
PROTON_USE_WOW64=1 WINEDLLPATH=/home/<you>/.local/lib/wine %command%
```

`%command%` stands for the game itself. Everything before it becomes an
environment variable for the game. Leave it out and Steam treats the whole
line as arguments to pass to the game, so the variables never become
environment variables at all.

If you have tried to get Rocksmith working before, with `WineASIO` or with
an older `Proton`, start from a clean prefix rather than fixing the old one.
Rename it, so you can go back if you need to:

```bash
cd <library>/steamapps/compatdata
mv 221680 221680.old-$(date +%F)
```

Do the same with `Rocksmith.ini` in the game folder, for the same reason:
the game writes a fresh one on its next start.

Now launch the game once, let it reach its menu, and quit. That first launch
is what creates the new prefix, and the next step needs it to exist.

---

## 6. Registering the Driver Through the Game's Own Proton

A Windows program finds `ASIO` drivers through the **registry**. Copying the
files is not enough. The driver has to be registered inside the game's
prefix, and `PipeASIO` ships a tool for that, `pipeasio-register`.

By default it uses whatever `wine` is on your `PATH`. That is the system
`Wine` from `pacman`, which is a different version from the `Proton` that
built the prefix. As [chapter 16](./16_battlenet.md) explains, a prefix
carries assumptions about the `Wine` that made it, and running a different
one can "update" the prefix underneath the game. The tool knows this. It
refuses to touch a `Proton` prefix (anything containing a `tracked_files`
file) unless you tell it which runner to use.

The tool to run it with is `umu-run`, from `umu-launcher` in `multilib`.
It starts a program inside the same `Proton` and the same container a game
would use:

```bash
sudo pacman -S umu-launcher
```

Find the `Proton` that built the prefix. The prefix records it:

```bash
cat <library>/steamapps/compatdata/221680/version
sed -n 2p <library>/steamapps/compatdata/221680/config_info
```

```
GE-Proton11-7
/home/<you>/.local/share/Steam/compatibilitytools.d/GE-Proton11-7-x86_64/files/share/fonts/
```

Note that the two do not match. The version is `GE-Proton11-7`, but the
directory is `GE-Proton11-7-x86_64`. `umu-run` wants the full directory
path, so take it from `config_info` and strip the `/files/...` part. Then,
with the game closed:

```bash
env WINEPREFIX=<library>/steamapps/compatdata/221680/pfx \
    WINE=umu-run \
    PROTONPATH=/home/<you>/.local/share/Steam/compatibilitytools.d/GE-Proton11-7-x86_64 \
    GAMEID=umu-221680 \
    PROTON_USE_WOW64=1 \
    WINEDLLPATH=/home/<you>/.local/lib/wine \
    pipeasio-register
```

Check that it worked by reading the registry directly. It is a text file:

```bash
grep -F 'ASIO\\PipeASIO]' <library>/steamapps/compatdata/221680/pfx/system.reg
```

```
[Software\\ASIO\\PipeASIO] 1791022770
[Software\\Wow6432Node\\ASIO\\PipeASIO] 1791022786
```

Two entries. The first is for 64-bit programs. The second, under
`Wow6432Node`, is the 32-bit registry view, and it is the one Rocksmith
reads. If only the first is there, the game will not find the driver.

---

## 7. Installing RS_ASIO

Download the latest release zip from the
[`RS_ASIO` releases page](https://github.com/mdias/rs_asio/releases). This
chapter used `v0.7.5`. It contains three files:

```
avrt.dll
RS_ASIO.dll
RS_ASIO.ini
```

All three go in the game folder, next to `Rocksmith2014.exe`.

`avrt.dll` is the clever part. It is the name of a real Windows system
library that the game loads for its audio thread. A program looks in its
own folder before the system folders, so the game picks up this copy
instead, and this copy loads `RS_ASIO.dll`. No files in the game are
modified, and deleting the three files undoes the whole mod.

Then tell `RS_ASIO` which driver to use. In `RS_ASIO.ini`, set the output
and the first input to `PipeASIO`, and point the input at channel 0, the
first (and here only) input `PipeASIO` offers:

```ini
[Asio.Output]
Driver=PipeASIO

[Asio.Input.0]
Driver=PipeASIO
Channel=0
```

Leave `[Asio.Input.1]` and `[Asio.Input.Mic]` blank. They are for a second
player and a microphone.

### The line endings

`RS_ASIO.ini` is a Windows file with `CRLF` line endings, the same trap as
`Config.wtf` in [chapter 16](./16_battlenet.md). If you edit it with `sed`,
a pattern like this matches **nothing**:

```bash
sed -i 's/^Driver=$/Driver=PipeASIO/' RS_ASIO.ini
```

The line is not `Driver=`. It is `Driver=` followed by an invisible carriage
return, so `$` never lines up. `sed` reports no error, the file is
unchanged, and you only notice because the game still does not hear you.
Check what you are dealing with first:

```bash
file RS_ASIO.ini
```

```
RS_ASIO.ini: ASCII text, with CRLF line terminators
```

Then either edit it in a text editor, or match the carriage return and put
it back:

```bash
sed -i '/^\[Asio.Output\]/,/^\[Asio.Input.0\]/ s/^Driver=\r$/Driver=PipeASIO\r/' RS_ASIO.ini
```

### Rocksmith.ini

`RS_ASIO` also expects two settings in the game's own `Rocksmith.ini`,
under `[Audio]`:

```ini
ExclusiveMode=1
Win32UltraLowLatencyMode=1
```

A freshly generated `Rocksmith.ini` already has both. Check them anyway if
you carried an old file over.

---

## 8. Connected, and Still Silent

With everything above in place, the game started, showed no cable warning,
and then reported **no signal** on the screen that checks your input. The
interface's gain light flickered with every strum. The guitar was clearly
reaching the interface. Somewhere between there and the game, it vanished.

The useful habit here is the same one as in chapter 16: do not guess at
fixes, walk the chain and find out which link is broken. There are three
places to look, and each one answers a different question.

### Did RS_ASIO load and open the input?

`RS_ASIO` writes a log next to the game, `RS_ASIO-log.txt`. If the file
does not exist at all, `RS_ASIO` never loaded, and the problem is `avrt.dll`
(see the note at the end of this section). If it exists, look for the input:

```bash
grep -E 'ASIO IN 0|SetMasterVolume' RS_ASIO-log.txt | head
```

```
26.673 [INFO]  {ASIO IN 0} DebugWrapperDevice::Activate - Activate iid: IID_IAudioClient dwClsCtx: 17
26.673 [INFO]  {ASIO IN 0} RSAsioAudioClient::Initialize - actual buffer duration: 5ms (256 frames)
26.674 [INFO]  {ASIO IN 0} DebugWrapperAudioEndpointVolume::SetMasterVolumeLevelScalar fLevel: 0.17
```

The first two lines mean the game asked for its cable, `RS_ASIO` handed it
input 0, and audio started flowing. That clears `RS_ASIO`, `PipeASIO` and
the registration in one go. Keep the third line in mind.

### Is PipeWire wired correctly?

With the game running, list its links:

```bash
pw-link -l | grep -A2 '^Rocksmith2014'
```

```
Rocksmith2014:out_1
  |-> alsa_output.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Line1__sink:playback_FL
Rocksmith2014:out_2
  |-> alsa_output.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Line1__sink:playback_FR
Rocksmith2014:in_1
  |<- alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic1__source:capture_MONO
```

Input 1 of the interface feeds the game, and the game feeds the
interface's outputs. The pinning from section 4 did its job. That clears
the routing.

### How loud is the signal, really?

Everything is connected, so the remaining question is not "is it there" but
"how much of it is there". Record a few seconds from the interface input
while strumming hard, and measure it:

```bash
timeout 4 pw-record --target <your Mic1 source> --channels 1 /tmp/guitar.wav
sox /tmp/guitar.wav -n stat 2>&1 | grep 'Maximum amplitude'
```

```
Maximum amplitude:     0.036469
```

Amplitude here runs from 0 to 1, where 1 is the loudest a digital signal can
be. A peak of `0.036` is about **-29 dB** below that. Quiet, but a guitar at
that level is still plenty for a tuner to work with.

Now go back to the third log line. `fLevel: 0.17` is the game setting the
volume of its input to 17%. The game believes it is adjusting its own cable.
Through `RS_ASIO`, with
`EnableSoftwareEndpointVolumeControl=1` (the default), that volume is
applied in software to your signal. 17% is about **-15 dB**. Add the two
together and the game receives a guitar peaking around **-44 dB**, which is
close to the noise floor. As far as the input check is concerned, that is
no signal.

Two changes fix it, one at each end.

**Stop the game turning the input down.** In `RS_ASIO.ini`, under the input
only:

```ini
[Asio.Input.0]
EnableSoftwareEndpointVolumeControl=0
```

The game can still call its volume function. `RS_ASIO` now ignores it.
Restart the game afterwards, since `RS_ASIO` reads its ini once at startup.

**Give the interface more to work with.** A guitar pickup is a weak,
high-impedance signal, which is a different thing from a microphone. On a
`Scarlett`, press the **INST** button for the guitar's input so the preamp
expects an instrument. Then raise the gain until the ring around the knob
shows green when you strum hard. An occasional amber flash is fine. Red
means clipping, and clipping cannot be fixed later.

> **Note**
> If `RS_ASIO-log.txt` never appears, the game loaded the system's
> `avrt.dll` instead of the one in its folder. Add
> `WINEDLLOVERRIDES="avrt=n,b"` before `%command%` in the launch options.
> `n,b` means "native first, then builtin": the file in the game folder,
> before `Wine`'s own version.

### Latency

The log also tells you the buffer you are getting. The game asked for
3 ms, and `PipeASIO` gave it 256 frames, about 5 ms at 48 kHz, because
`RS_ASIO` defaults to the buffer size the driver prefers. Every buffer in
the path adds its length to the delay between playing a note and hearing
it, so this is the main number to tune.

If that feels late, lower `buffer_size` to `128` in the `PipeASIO` config
from section 4. It applies within a second. If you then hear crackles or
short dropouts, the CPU is missing its deadline: go back to `256`. On the
machine this chapter was written from, small buffers in a `DAW` also needed
the CPU's energy preference set to `performance`, since the default
`balance_performance` lets the cores slow down between audio callbacks:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

---

## 9. The Script

[`scripts/rocksmith-asio`](../scripts/rocksmith-asio) does the parts of
this chapter that are easy to get subtly wrong, and checks the rest.

```bash
install -Dm755 scripts/rocksmith-asio ~/.local/bin/rocksmith-asio
```

See [chapter 19, section 5](./19_call_mic.md#5-the-script) if
`~/.local/bin` is not on your `PATH` yet.

| Command | What it does |
| ------- | ------------ |
| `rocksmith-asio status` | Checks every link in sections 3 to 8 and changes nothing. Read-only and safe to run while the game is open. |
| `rocksmith-asio register` | Copies the driver under `$HOME` if it is missing or out of date, finds the `Proton` that built the prefix, and registers `PipeASIO` through `umu-run`. Run it again after every `pipeasio` update. |
| `rocksmith-asio install-rsasio <zip>` | Installs `RS_ASIO` from a release zip and sets the four ini values from sections 7 and 8, keeping the `CRLF` endings. An existing `RS_ASIO.ini` is backed up and kept. |

It finds everything itself. The game's library comes from Steam's
`libraryfolders.vdf`, the `Proton` build from the prefix's `config_info`,
and the launch options from Steam's `localconfig.vdf`. It never writes the
launch options, because Steam rewrites that file while it is running and
would undo the change. Set those by hand, as in section 5.

A healthy system looks like this, shortened:

```
PipeASIO under $HOME (visible inside Proton's container)
  [ ok ]  i386-windows/pipeasio32.dll
  ...
Prefix
  [ ok ]  built by GE-Proton11-7-x86_64
  [ ok ]  PipeASIO registered (64-bit)
  [ ok ]  PipeASIO registered (32-bit, the one Rocksmith uses)
Steam launch options
          PROTON_USE_WOW64=1 WINEDLLPATH=/home/<you>/.local/lib/wine %command%
  [ ok ]  PROTON_USE_WOW64=1
  ...
RS_ASIO in the game folder
  [ ok ]  [Asio.Input.0] game cannot turn the input down
  ...
Everything checked is in place.
```

What the script cannot check is the interface's gain knob. That one is on
you.

---

## 10. Quick Reference

| Action | Command |
| --- | --- |
| Check everything | `rocksmith-asio status` |
| Register the driver | `rocksmith-asio register` |
| Install RS_ASIO | `rocksmith-asio install-rsasio <zip>` |
| Launch options | `PROTON_USE_WOW64=1 WINEDLLPATH=/home/<you>/.local/lib/wine %command%` |
| Find your interface's names | `pactl list short sources`, `pactl list short sinks` |
| Which Proton built the prefix | `sed -n 2p <compatdata>/221680/config_info` |
| Is the driver registered | `grep -F 'ASIO\\PipeASIO]' <prefix>/system.reg` |
| Check line endings | `file RS_ASIO.ini` |
| Did RS_ASIO open the input | `grep 'ASIO IN 0' RS_ASIO-log.txt` |
| What is the game linked to | `pw-link -l \| grep -A2 '^Rocksmith2014'` |
| How loud is the guitar | `pw-record --target <source>` then `sox <file> -n stat` |

| Symptom | Likely cause |
| --- | --- |
| No `RS_ASIO-log.txt` after launching | `avrt.dll` not loaded. Add `WINEDLLOVERRIDES="avrt=n,b"`. |
| Log exists, game says no cable | Driver not registered in the 32-bit view, or `PROTON_USE_WOW64=1` missing. |
| Worked, stopped after a `yay -Syu` | `pipeasio` updated, the copy under `$HOME` is stale. Run `register` again. |
| `pipeasio-register` refuses the prefix | It is a `Proton` prefix. Run it through `umu-run` (section 6). |
| Everything linked, no signal in the game | Game set its input volume to 17% (section 8). |
| Very quiet signal at the source | **INST** off, or gain too low on the interface. |
| `sed` edit to `RS_ASIO.ini` did nothing | `CRLF` line endings. |
| Game audio delayed by a fraction of a second | `PipeASIO` following a Bluetooth default. Pin the devices. |
| Crackles or dropouts | Buffer too small for the CPU. Raise `buffer_size`. |

---

## Why this is harder than it should be

Every layer in this chapter exists to undo an assumption made by the layer
next to it. The game assumes there is only one cable in the world.
`RS_ASIO` undoes that by impersonating the cable. `Proton` assumes nothing
outside its container matters, and `WINEDLLPATH` undoes that. A 32-bit game
assumes a 32-bit world, and new WoW64 undoes that. Each fix is small and
sensible. The trouble is that there are five of them, they live in five
different places, and a mistake in any one looks the same from inside the
game: no guitar.

That is why the diagnosis in section 8 is worth more than any single fix.
The most tempting move, when a game cannot hear you, is to change
something: a different driver, a different `Proton`, a different setting
from a forum post. Every one of those changes would have been wrong here,
because nothing was broken. The driver loaded, the links were right, and
the signal arrived. It just arrived 15 dB quieter than it left, because a
volume setting designed for one specific USB cable was being applied to an
entirely different device. You only find that by looking at each link in
turn and asking a narrower question at each one: did it load, is it
connected, how loud is it.

The other lesson is about things that fail without saying so. The `CRLF`
endings in `RS_ASIO.ini` let `sed` succeed while changing nothing. The
missing `PROTON_USE_WOW64=1` lets the driver register and then quietly not
load. The copy under `$HOME` keeps working after an update, just as the old
version. None of these produce an error, so your own tools have to tell
you, which is the whole reason `rocksmith-asio status` exists. When a
system fails silently, the cheapest thing you can build is something that
checks it out loud.

| [← Previous](./19_call_mic.md) | [Next →](./21_slow_boot_and_login.md) |
|:--|--:|
