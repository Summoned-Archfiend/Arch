# Smaller Fixes Worth Knowing

Not every problem deserves its own chapter. This one collects the small
ones, the fixes that take a single command once you know which command,
and that otherwise cost an evening because the symptom points somewhere
unhelpful.

They are independent. Read the one you need and ignore the rest.

The last section is the exception, and is the most useful thing here. It
is about a whole class of fault where the thing that appears broken is not
the thing that is broken.

---

## 1. Typing Accented Characters

On Windows you hold `Alt` and type a number on the numpad. `Alt` + `0237`
gives `í`. That mechanism does not exist on `Linux` at all, which is why
nothing happens when you try it, and why searching for "alt codes not
working" finds nothing useful.

The equivalent is the **Compose key**. You tap it, release it, then type a
short mnemonic sequence. Nothing is held down.

By default no compose key is assigned. Pick one you do not otherwise use:

```bash
setxkbmap -option compose:ralt      # right Alt
setxkbmap -option compose:menu      # the menu key, if your board has one
setxkbmap -option compose:caps      # caps lock
```

Right `Alt` is the usual choice on a `us` layout, where it does nothing.
Then:

| Sequence | Result |
| --- | --- |
| Compose `'` then a e i o u | á é í ó ú |
| Compose `'` then A E I O U | Á É Í Ó Ú |
| Compose `^` then a e i o u | â ê î ô û |
| Compose `"` then a e i o u | ä ë ï ö ü |
| Compose `` ` `` then a e i o u | à è ì ò ù |
| Compose `~` then n | ñ |
| Compose `/` then o | ø |
| Compose `a` then e | æ |

The accent comes first, then the letter, which is the opposite order to
how you say it aloud. That trips everyone up once.

The full table lives in `/usr/share/X11/locale/en_US.UTF-8/Compose` and is
worth grepping when you want something unusual:

```bash
grep -i "iacute" /usr/share/X11/locale/en_US.UTF-8/Compose
```

`setxkbmap` only lasts for the session. On `KDE`, make it stick by writing
it into `~/.config/kxkbrc`, or the desktop will reset it:

```ini
[Layout]
Options=compose:ralt
ResetOldOptions=true
LayoutList=us
Use=true
```

> **Note**
> You can define your own sequences in `~/.XCompose`, including numeric
> ones that imitate Windows alt codes. Start the file with `include "%L"`
> or you lose every default sequence. In practice the mnemonic form is
> easier to remember than four digit codes, and `~/.XCompose` is only read
> when an application starts, so changes need an app restart to take
> effect.

---

## 2. A Locale That Is Not Generated

Software that asks for a locale you have not generated behaves oddly
rather than failing cleanly. `Steam`'s container runtime, for example,
logs this on every launch and regenerates the locale itself each time:

```
setlocale "en_US.UTF-8": No such file or directory
pv-locale-gen: Missing locale en_US.UTF-8
pv-locale-gen: Generating locale en_US.UTF-8...
pv-adverb: W: Container startup will be faster if missing locales are created at OS level
```

Check what you actually have:

```bash
locale -a
```

A default `Arch` install generates only what you uncommented during
installation, which for a British setup is usually `en_GB.UTF-8` and
nothing else. Plenty of software, especially Windows software under
`Wine`, expects `en_US.UTF-8` to exist.

Generating it does not change your system language:

```bash
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
```

`/etc/locale.conf` still says `LANG=en_GB.UTF-8`, so your date and number
formatting are untouched. You have only made the other locale *available*
to software that asks for it.

Worth doing pre-emptively. It costs a few megabytes and removes a whole
category of vague misbehaviour.

---

## 3. A 4K Monitor Running the Wrong 4K

There are two resolutions called 4K:

| Name | Resolution | Aspect | Used by |
| --- | --- | --- | --- |
| UHD | 3840x2160 | 16:9 | Televisions, monitors, desktops |
| DCI 4K | 4096x2160 | 17:9 | Cinema projection |

A monitor that accepts both can end up on the cinema one, and desktop
software handles it badly. Games are the worst affected, because a UI laid
out for 16:9 lands wrong on a 17:9 canvas.

Check which mode is active, and which the display actually prefers:

```bash
xrandr --query | sed -n '/^HDMI-0 connected/,/^[A-Za-z]/p' | head -4
```

```
   3840x2160     60.00 +      <- EDID-preferred, marked +
   4096x2160     59.94*       <- currently active, marked *
```

When `*` and `+` are on different lines, you are not running the mode the
display asked for. On `KDE`, fix it through `KScreen` rather than
`xrandr`, for the reason in the next section.

---

## 4. Display Changes That Do Not Survive

This one wastes real time. On `KDE`, changing a display with `xrandr`
works immediately and then silently reverts, because `KScreen` holds its
own view of your layout and reapplies it on any display event. Worse, the
two drift out of sync in the meantime, and you end up debugging a
configuration that only one half of the system believes in.

Use `kscreen-doctor` instead. It applies the change *and* persists it:

```bash
kscreen-doctor -o                                   # list outputs and modes
kscreen-doctor output.HDMI-0.mode.3840x2160@60      # set a mode
kscreen-doctor output.DP-2.enable                   # enable an output
kscreen-doctor output.DP-2.priority.1               # make it primary
kscreen-doctor output.DP-2.position.0,545           # place it
```

Several settings can be given in one invocation, which is applied
atomically and is much safer than a sequence of separate changes:

```bash
kscreen-doctor output.DP-2.enable output.DP-2.priority.1 \
               output.HDMI-0.priority.2 output.HDMI-0.position.3440,0
```

Modes can be given as `3840x2160@60` or as the numeric id from
`kscreen-doctor -o`. The id is unambiguous when a display offers the same
resolution at several refresh rates. In that listing, `!` marks the
preferred mode and `*` marks the active one.

The rule is simple: **on a KDE system, `xrandr` is for reading and
`kscreen-doctor` is for writing.**

---

## 5. KDE Showing the Wrong Monitor

A confusing one. The display settings panel appears to have your monitors
muddled, showing one where you expect another.

The identities are almost certainly fine. What is wrong is which output
holds which *role*. `KScreen` stores its layout in
`~/.local/share/kscreen/`, one JSON file per configuration:

```bash
cd ~/.local/share/kscreen
python3 -c "
import json,pathlib
f=max(pathlib.Path('.').iterdir(), key=lambda p:p.stat().st_mtime)
for o in json.loads(f.read_text()):
    m=o.get('metadata',{})
    print(m.get('name'), m.get('fullname'), 'enabled=%s' % o.get('enabled'), 'priority=%s' % o.get('priority'))"
```

A broken layout looks like this:

```
HDMI-0  Mega System Technologies-MEC-R-4-HV   enabled=True   priority=1
DP-2    CU34G2XP                              enabled=False  priority=0
```

Every name is correct. The problem is that the wrong display holds
`priority 1`, which is the primary slot, while the one you think of as
your main screen is recorded as disabled. The panel is not mislabelling
anything, it is showing you a layout you did not intend.

`priority 1` is primary, and higher numbers are the rest in order. Fix it
with `kscreen-doctor` as in the previous section rather than by editing
the `JSON`, so the running session and the saved file agree.

---

## 6. Plasma Desktops Missing After a Layout Change

Symptom: after changing which monitor is primary, one screen has lost its
wallpaper and desktop icons, and does not appear in Edit Mode at all.

`Plasma` binds each desktop, called a containment, to a screen *index*
rather than to a display identity. Reordering priorities reindexes the
screens, and containments end up pointing at indices that no longer mean
what they did.

You can see the mismatch directly:

```bash
grep -A6 "^\[Containments\]" ~/.config/plasma-org.kde.plasma.desktop-appletsrc \
  | grep -E "lastScreen|plugin=org.kde.plasma.(folder|desktop)"
```

Four containments with `lastScreen` values of 0, 1, 2 and 3 on a three
monitor system means one is orphaned from an older layout.

The fix is to restart the shell so it re-evaluates screens:

```bash
systemctl --user restart plasma-plasmashell.service
```

Your panels and widgets disappear for a few seconds and come back. It is
safe, and it is the standard remedy for most `Plasma` display oddities, not
just this one. Nothing is lost, because the containments still exist and
are simply reassigned.

---

## 7. A Game Interface That Is Unusable at 4K

Symptom worth recognising, because it points straight at the cause: the
**loading screen looks perfectly normal** and the interface becomes
unusable the moment the game actually loads.

That split is the whole diagnosis. A loading screen is one image scaled to
fill the display, so it looks right at any resolution. The interface is
composed of elements positioned and scaled by the game's own UI scale
setting, and at 3840x2160 a default meant for far fewer pixels leaves
everything unreadably small.

In `World of Warcraft` the setting lives in
`_retail_/WTF/Config.wtf`:

```
SET useUiScale "1"
SET uiScale "1"
```

Set it to the maximum first. You can always make a usable interface
smaller, but you cannot navigate a settings menu you are unable to read.
Once in the game, adjust it properly under Settings, Advanced, UI Scale,
where there is a live preview.

Two cautions that apply to any game's configuration file. Edit it only
while the game is closed, because most rewrite their settings on exit and
will silently discard your change. And keep the line endings the file
already uses, which for a Windows game means `CRLF`:

```bash
tail -3 Config.wtf | cat -A        # lines should end ^M$
grep -c $'\r' Config.wtf           # should equal the line count
```

Appending with `printf 'SET uiScale "1"\r\n' >> Config.wtf` preserves
them. A plain `echo` does not.

---

## 8. When a Display Fault Looks Like a Rendering Fault

This is the one worth internalising, and it cost an entire evening to
learn.

An application was rendering incorrectly. Sometimes a black window,
sometimes a frozen copy of the desktop behind it, sometimes a blank white
page. A setting inside the application appeared to fix it, then appeared
to cause it the next day, then reversed again. Every plausible cause was
investigated: driver version consistency, compositing, the graphics `API`,
the translation layer, even the missing locale from section 2.

The actual fault was in section 5. The desktop layout had the wrong output
holding the primary slot, with another marked disabled. What the machine
was drawing and what the person was physically looking at were not the same
screen.

Once that is true, every downstream observation is unreliable. A window
that never paints, a stale image, a setting that seems to change meaning
between sessions: all of it is consistent, and none of it points at the
layout, because the layout is not where you are looking.

The habit to take from this is to **verify the display topology before
debugging anything visual.** It takes one command:

```bash
xrandr --listmonitors && kscreen-doctor -o | grep -E "^Output|enabled|priority"
```

Confirm that the output you believe is primary is the one marked primary,
that every display is enabled, and that the geometry matches the physical
arrangement on your desk. If those three are not true, fix them first and
retest, because until then you cannot trust what you are seeing.

More generally: when a symptom keeps changing its mind, stop looking for a
cleverer explanation of the symptom and start questioning whether the thing
you are observing is the thing you think you are observing.

---

## 9. Quick Reference

| Action | Command |
| --- | --- |
| Set a compose key for the session | `setxkbmap -option compose:ralt` |
| Find a compose sequence | `grep -i "<name>" /usr/share/X11/locale/en_US.UTF-8/Compose` |
| List generated locales | `locale -a` |
| Generate a missing locale | edit `/etc/locale.gen`, then `sudo locale-gen` |
| Active vs preferred display mode | `xrandr --query \| grep -E '\*\|\+'` |
| List outputs, modes, priorities | `kscreen-doctor -o` |
| Set a display mode, persistently | `kscreen-doctor output.HDMI-0.mode.3840x2160@60` |
| Make an output primary | `kscreen-doctor output.DP-2.priority.1` |
| Inspect the saved KDE layout | `ls -t ~/.local/share/kscreen/ \| head -1` |
| Rebuild Plasma desktops | `systemctl --user restart plasma-plasmashell.service` |
| Check a config's line endings | `tail -3 <file> \| cat -A` |
| Verify display topology | `xrandr --listmonitors` |

| Symptom | Likely cause |
| --- | --- |
| Windows alt codes do nothing | No such mechanism on Linux. Use a compose key. |
| Software misbehaves vaguely, logs mention locale | Locale not generated. |
| `*` and `+` on different xrandr mode lines | Running a non-preferred display mode. |
| Display change reverts by itself | Changed with `xrandr` on a `KDE` system. |
| Settings panel seems to swap monitors | Wrong output holds `priority 1`. |
| One screen loses wallpaper and icons | Plasma containment indices are stale. |
| Loading screen fine, interface tiny | UI scale, not resolution. |
| Config edit had no effect | Application rewrote the file on exit. |
| Rendering fault that changes its mind | Verify the display topology first. |

---

## Why these are harder than they should be

What links most of these is that the error message, when there is one,
describes the place the problem surfaced rather than the place it lives.

A game with an unusable interface reports nothing at all. A display running
a cinema resolution looks like a game compatibility problem. A `Plasma`
desktop that has lost its wallpaper looks like a `Plasma` bug rather than a
consequence of reordering monitors ten minutes earlier. Nothing lies to
you, but nothing volunteers the connection either, and the connection is
the entire answer.

The second thread is ownership. On a `KDE` system the desktop believes it
owns your display configuration, and it is right. `xrandr` still works,
still appears to succeed, and is still the first tool everyone reaches for,
so you get a change that holds until the next display event and then
quietly does not. The same shape appears with game configuration files
rewritten on exit. In both cases the fix is not a better command but
knowing which component is authoritative, and going through it.

Section 8 is the general form of both. Before you spend an evening on the
behaviour of a thing, check that you are actually looking at the thing.

| [← Previous](./17_game_performance.md) | [Next →](./19_call_mic.md) |
|:--|--:|
