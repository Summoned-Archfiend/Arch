# Voice and Guitar on One Browser Mic

This chapter is about a problem that shows up the first time you try to
take a music lesson over a video call. You have an audio interface with a
microphone in one input and a guitar in the other. The guitar goes through
an amp simulator in your `DAW`. You open the call site, go to pick your
microphone, and the list offers you input 1, or input 2, or inputs 3 and 4.
There is no "1 and 2", and none of the options is the guitar tone you
actually play with.

It is not a missing setting in the call site. A browser lets a page choose
exactly **one** input device, and none of the devices your system presents
is the thing you want to send. So you build the device you want.

This chapter explains why the list looks the way it does, how `PipeWire`
lets you create a virtual microphone and wire real sources into it, and how
to get the levels right so the person on the other end hears both your
voice and your guitar. A script at the end, `call-mic`, packages the whole
thing into two commands.

---

## 1. Why the Browser Offers the Wrong Choices

An interface like a `Focusrite Scarlett 2i2` has two physical inputs.
`PipeWire` presents them as separate sources, and adds any extra channels
the device exposes (loopback, for example) as more sources. Each one is a
complete, valid microphone as far as the browser is concerned.

The browser's model is simple: one page, one microphone. `WebRTC`, which
every browser call is built on, captures from a single device. There is no
UI for combining two of them, and no call site adds one, because on most
laptops there is only one microphone anyway.

The guitar is the second problem. Plugging it into input 1 does put it on a
source, but what arrives there is the **dry** signal: the raw pickup output,
before any amp, cab, or effects. If you play through an amp simulator
(`Neural Amp Modeler`, an `IR` loader, anything in a `DAW`), the tone you
hear exists only inside the `DAW`, after its plugins have run. It never
appears on any input device. It leaves the `DAW` on its outputs, heading for
your headphones.

So the thing you want to send is "input 2 plus the `DAW`'s output", and
that is not a device. It has to become one.

---

## 2. What a Virtual Source Is

`PipeWire` treats everything that makes or consumes audio as a **node** in a
graph, and connections between nodes as **links** between their ports. Your
interface's inputs are nodes. Your `DAW` is a node. Your headphones are a
node. The browser's capture stream is a node.

A **virtual source** is a node that behaves exactly like a microphone to
anything reading from it, but has no hardware behind it. Whatever you link
into its inputs comes out of it as mic signal. Link two things in, and they
are summed.

```
interface input 2 (voice) ──┐
                            ├──► Call_Mic ──► browser (picked as the mic)
DAW outputs 1 and 2 ────────┘

DAW outputs 1 and 2 ──► headphones      (unchanged)
interface inputs ──► DAW                (unchanged)
```

The important property is that **links are copies**. Linking your `DAW`'s
output into the virtual source does not take it away from your headphones.
Linking your voice mic into it does not take it away from anything else
reading it. Every existing connection keeps working, and nothing you record
changes. The merge only happens inside the virtual source, and removing the
virtual source removes the merge.

The other thing to know is what cannot be undone at the far end. Inside the
virtual source, voice and guitar are added together into one stream. The
person on the call cannot turn one up without the other. Any balancing
happens at your end, before the signals meet.

---

## 3. Building One by Hand

It is worth doing this once manually, because the script in section 5 only
automates these three steps.

First, create the virtual source. The standard way is a `null sink` whose
media class is set to be a source:

```bash
pactl load-module module-null-sink \
    media.class=Audio/Source/Virtual \
    sink_name=call_mic \
    channel_map=front-left,front-right \
    sink_properties=device.description=Call_Mic
```

It prints a module number. Keep it, because unloading that module is how
you remove the device again.

Second, find the ports. `pw-link -o` lists every output port on the system,
and `pw-link -i` every input port:

```bash
pw-link -i | grep call_mic
pw-link -o | grep -E 'Mic2|REAPER'
```

On the machine this chapter was written from, the relevant ports were:

```
call_mic:input_FL
call_mic:input_FR
alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic2__source:capture_MONO
REAPER:out1
REAPER:out2
```

Third, link them. Note that the microphone is **mono**, a single
`capture_MONO` port, so it is linked to both channels of the virtual source.
Link it to only one and the far end hears you in one ear, or not at all if
the call app keeps just the left channel.

```bash
MIC='alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic2__source:capture_MONO'
pw-link "$MIC"       call_mic:input_FL
pw-link "$MIC"       call_mic:input_FR
pw-link REAPER:out1  call_mic:input_FL
pw-link REAPER:out2  call_mic:input_FR
```

Reload the call page, and **Call_Mic** appears in its microphone list.

To remove it:

```bash
pactl unload-module <module number>
```

None of this is permanent. The virtual source disappears on reboot and
whenever `PipeWire` restarts. For a call you set up once per session, that
is exactly what you want: nothing to forget to undo.

---

## 4. Picking the Right Voice Source

The obvious shortcut is "use whatever the default microphone is". On a
laptop that is fine. On an audio interface it is frequently wrong.

```bash
pactl get-default-source
```

```
alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic1__source
```

That is input 1, the guitar. Using it as the voice source sends the dry
guitar alongside the processed guitar, and no voice at all. Nothing errors.
It just sounds wrong, and the other person is the first to notice.

So name the voice source explicitly. List what exists, ignoring monitors
(a monitor is a copy of some output, never a microphone):

```bash
pactl list short sources | awk '$2 !~ /\.monitor$/ {print $2}'
```

On a `Scarlett`, the source names end in `Mic1` and `Mic2` for the two
physical inputs, regardless of whether a mic or a guitar is plugged in.
Pick the one your microphone is actually in.

---

## 5. The Script

[`scripts/call-mic`](../scripts/call-mic) does sections 3 and 4 for you.

### Running it once, from the repository

A script is just a text file until it is marked executable. Then you can
run it by its path:

```bash
chmod +x scripts/call-mic
./scripts/call-mic status
```

The `./` is not decoration. When you type a bare command name, the shell
does **not** look in the current directory. It only searches the
directories listed in your `PATH` variable, in order, and runs the first
match. `./` means "this directory", which turns the name into an explicit
path and skips the search. Leaving the current directory out of `PATH` is
deliberate: otherwise anyone who can drop a file called `ls` into a folder
you `cd` into gets to run code as you.

### Making it a command

To type `call-mic activate` from anywhere, put the script in a directory
that is on your `PATH`. The conventional one for your own user is
`~/.local/bin`: it needs no root, and it is where the
[XDG spec](https://specifications.freedesktop.org/basedir-spec/latest/)
says user executables belong.

Check it is on your `PATH` first:

```bash
echo "$PATH" | tr ':' '\n' | grep -x "$HOME/.local/bin"
```

If that prints the directory, you are done. If it prints nothing, add it to
your shell's startup file and open a new terminal:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Then install the script there. `install` is a better tool than `cp` for
this: it creates the directory if it is missing (`-D`) and sets the
executable permission (`-m755`) in the same step.

```bash
install -Dm755 scripts/call-mic ~/.local/bin/call-mic
```

Confirm the shell finds it:

```bash
command -v call-mic
```

```
/home/<you>/.local/bin/call-mic
```

If it still says nothing in a terminal that was already open, run
`hash -r`. `bash` caches where it found each command, and that cache
predates the new file.

`install` copies the file, so editing the copy in the repository does not
change the installed command. Re-run the `install` line after an update.
If you would rather the command always track the repository, symlink it
instead:

```bash
ln -sf "$PWD/scripts/call-mic" ~/.local/bin/call-mic
```

The trade-off is that moving or deleting the repository breaks the
command.

### Configuring and using it

Tell it which source is your voice, and what your `DAW` calls itself as a
`JACK` client (`REAPER` by default):

```bash
call-mic sources
mkdir -p ~/.config/call-mic
cat > ~/.config/call-mic/config <<'EOF'
VOICE_SOURCE=alsa_input.usb-Focusrite_Scarlett_2i2_4th_Gen_<serial>-00.HiFi__Mic2__source
APP=REAPER
EOF
```

Without a config file it falls back to the default source, which section 4
explains is often the wrong one.

Then, with the `DAW` open:

```bash
call-mic activate
```

```
Call_Mic is active. Feeding it:
  call_mic:input_FL  <-  alsa_input...HiFi__Mic2__source:capture_MONO
  call_mic:input_FL  <-  REAPER:out1
  call_mic:input_FR  <-  alsa_input...HiFi__Mic2__source:capture_MONO
  call_mic:input_FR  <-  REAPER:out2
```

| Command | What it does |
| ------- | ------------ |
| `call-mic activate` | Creates `Call_Mic` if needed and links voice and `DAW` into it. Safe to repeat; it repairs missing links. |
| `call-mic disable` | Removes `Call_Mic`. |
| `call-mic status` | Shows whether it exists and exactly what is feeding it. |
| `call-mic sources` | Lists input sources, to choose a `VOICE_SOURCE`. |

Order matters in one place. If the `DAW` is not running, there are no `DAW`
ports to link, so `activate` links your voice only and tells you so. Open
the `DAW` and run `activate` again.

---

## 6. Getting the Levels Right

Because the two signals are summed before they leave your machine, the
balance is set at the sources:

* **Voice**: the interface's gain knob for the mic input.
* **Guitar**: the `DAW`'s master fader.

A **condenser** microphone needs **48V phantom power** from the interface,
and a lot more gain than an instrument. The failure mode is confusing: 48V
is on, the mic is plugged in, and the meter shows nothing. On the machine
this chapter was written from, the mic input was at **1 dB** of gain, left
over from an earlier setup. A condenser wants somewhere around 30 to
45 dB.

On a `4th Gen Scarlett` the gain is readable and settable from the
terminal, which makes the problem obvious:

```bash
amixer -c Gen sget 'Line In 2 Gain'
amixer -c Gen sset 'Line In 2 Gain' 40
```

Aim for speech peaks around -20 to -15 dBFS. Louder leaves no headroom for
a laugh or a shout; much quieter and the call's automatic gain control will
pump the noise floor up between phrases.

Also check the interface's **direct monitor** mix if you want to hear your
own voice in your headphones. On the `2i2` it lives in the mixer controls
(`Monitor 1 Mix A Input 02` and friends). If it sends the mic to one ear
only, or sends the dry guitar input to your ears underneath the amp
simulator, fix that there. It changes only what you hear, never what the
call receives.

---

## 7. Checking What the Far End Hears

Everything above gets a correct signal to the browser. The browser then
processes it before sending it, and that processing was designed for
speech.

**Noise suppression** treats a sustained note as background noise and fades
it out. **Echo cancellation** can clip the start of notes. **Automatic gain
control** squashes dynamics. If the call site has settings for any of these
(often under "audio" or "advanced"), turn them off for a music lesson. Wear
headphones, so there is no speaker sound for the mic to pick up and the
echo canceller has nothing to do.

The only reliable test is to listen from the other side. Join a free
`meet.jit.si` room from the browser you will use for the lesson, join the
same room from your phone, and play. What the phone plays back is what your
teacher will hear.

---

## 8. Quick Reference

| Symptom | Likely cause |
| ------- | ------------ |
| Call site offers inputs 1, 2, 3+4 only | Browsers pick one device. Use `Call_Mic`. |
| `Call_Mic` missing from the site's list | Created after the page loaded. Reload the page. |
| Far end hears voice only | `DAW` was not open at `activate`. Run it again. |
| Far end hears dry guitar | Voice source is set to the guitar input (section 4). |
| Voice in one ear only | Mono mic linked to one channel. `call-mic` links both. |
| Condenser mic silent | 48V off, or gain near 0 dB (section 6). |
| Sustained notes fade out | Browser noise suppression (section 7). |
| Short gaps of silence in everything | Not this chapter: the `DAW` is missing its audio deadline. Watch its `ERR` column in `pw-top`. |
| `Call_Mic` gone after a reboot | Expected. It is temporary by design. |

---

## Why this is harder than it should be

The frustrating part is that nothing is broken. Every component does
exactly what it was built to do. The browser offers one microphone because
its whole model is one microphone. `PipeWire` presents each input as a
separate source because they are separate inputs. The `DAW` sends its
output to your headphones because that is where you asked it to go. The
thing you want is simply a combination nobody anticipated, so nobody built
the menu item.

That is also why the fix feels unfamiliar. On most systems, audio devices
are things you are given. On `PipeWire` they are things you can make: a
node is a few lines of configuration, and a link is a single command. Once
that clicks, a whole category of "the app will not let me choose X" stops
being a limitation of the app and becomes ten seconds of wiring.

The trap to remember is the default source. It is the one assumption that
fails silently, sends the wrong signal, and sounds almost right. Name your
sources explicitly and it cannot bite you.

| [← Previous](./18_smaller_fixes.md) |
|:--|
