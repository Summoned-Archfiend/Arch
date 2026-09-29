# Knowing What Your Hardware Can Actually Do

"What settings can my machine handle?" is one of those questions that
sounds like it has a lookup answer and does not. You can read every
specification of your `GPU` and still not know, because the answer depends
on your resolution, on the game, on which part of the game you are in, and
under `Linux` on a translation layer sitting between the game and your
driver that the specification sheet knows nothing about.

The useful version of the question is narrower. Not "is my card good
enough", but "which component runs out first, and at which setting". That
one has a real answer, it changes as you walk from an empty field into a
capital city, and you can measure it in about five minutes.

This chapter is about replacing guesswork with measurement. The worked
example is `World of Warcraft` running under `Wine`, continuing from
[chapter 16](./16_battlenet.md), but nothing here is specific to that game.
The habits transfer to anything you run.

---

## 1. There Is No Single Answer, and That Is the Point

Every frame your machine produces needs work from two places. The `CPU`
decides what exists, where it is, and what it is doing. The `GPU` draws it.
They work in parallel, and the slower of the two sets your frame rate.

This is why a single number for "what my rig can handle" does not exist.
The two run out at different times:

| Situation | Usually limited by | Why |
| --- | --- | --- |
| Empty terrain, high resolution | `GPU` | Lots of pixels, few objects to track |
| Capital city, crowd of players | `CPU` | Hundreds of entities, little to draw per one |
| Raid encounter with heavy effects | `CPU` | Spell and particle logic, many actors |
| Standing still admiring the view | `GPU` | Draw distance and shadows dominate |

The practical consequence is that lowering the wrong setting does nothing.
If your frame rate collapses in a city and you respond by dropping shadow
quality, you will change the picture and not the number, because shadows
are `GPU` work and your `CPU` was the problem. People conclude their card
is failing when it was idle the whole time.

So the real question is not "how high can I go". It is "which of the two
is the bottleneck, right now, in the situation I actually care about".

---

## 2. What the Game Has Already Told You

Before installing anything, read what you already have. Many games write a
graphics log at startup, and it is usually more honest than the settings
menu. `WoW` keeps one:

```bash
cd "/mnt/modded/Battle.net/drive_c/Program Files (x86)/World of Warcraft/_retail_/Logs"
grep -aE "GpuInfo|Adapter|Detected Graphics|Mem Budget" gx.log
```

Two lines are worth understanding properly.

The first is the capability line:

```
GpuInfo: sm:dx_5_0, rt:None, vrs:0, bary:0, mesh:0 pull:1
```

Read that as a list of things your hardware cannot do. `rt:None` is no
raytracing, `vrs:0` no variable rate shading, `mesh:0` no mesh shaders, and
`sm:dx_5_0` caps you at shader model 5.0. On a `Pascal` card such as a
`GTX 1080` this is expected, and it is genuinely useful information: those
are the features that justify a modern graphics `API`, so their absence
tells you that the newer `API` has nothing to offer you. That is not a
consolation prize. It is the difference between a compromise and a free
choice, which matters when a compatibility problem pushes you onto the
older path anyway.

The second is memory:

```
Periodic Gpu Status Report: Mem Budget: 1.7GB / 7.2GB (24.0%)
```

Remember this one. It is about to hand you something for nothing.

---

## 3. The Setting That Is Free

Texture resolution is the setting people lower first and should usually
lower last. Textures mostly consume video memory rather than processing
work. If the memory is there and unused, higher textures are close to free,
and they change the picture more than almost anything else per unit of
cost.

So check before you economise:

```bash
grep -a "Mem Budget" gx.log | tail -3
```

At `1.7GB` used of a `7.2GB` budget, roughly a quarter, there is no case
for running reduced textures. That card has headroom sitting idle.

The general habit is worth more than the specific setting. Before lowering
anything, find out whether the resource it consumes is actually scarce on
your machine. Advice written for a `4GB` card is everywhere on the
internet and is simply wrong for an `8GB` one, and following it costs you
picture quality in exchange for nothing at all.

---

## 4. Installing MangoHud

`MangoHud` is an overlay that reports what is happening while the game
runs. It works by inserting itself as a `Vulkan` layer, which is exactly
why it works under `Wine`: `DXVK` and `VKD3D` translate the game's
graphics calls into `Vulkan`, so from `MangoHud`'s side a Windows game
running through a translation layer looks like any other `Vulkan`
application.

Both packages are in the official repositories:

```bash
sudo pacman -S --needed mangohud lib32-mangohud
```

The 32 bit package matters more than it looks. Plenty of Windows games,
and launchers such as Battle.net, are still 32 bit even when the game they
launch is not. Without `lib32-mangohud` the overlay simply fails to appear
for those, with no error to explain why.

> **Note**
> Installing a single package with `pacman -S` on a system that has not
> synchronised recently risks a partial upgrade, which `Arch` handles
> badly. If it has been a while, either accept a full `yay -Syu` and the
> reboot that a kernel or driver update implies, or install now and
> upgrade properly at a moment that suits you. Do not silently mix the two
> approaches.

Drop in the configuration from
[`mangohud.conf.snippet`](../scripts/mangohud.conf.snippet):

```bash
mkdir -p ~/.config/MangoHud
cp mangohud.conf.snippet ~/.config/MangoHud/MangoHud.conf
```

Then enable it per launch rather than globally, because an overlay you
cannot turn off becomes an overlay you stop reading:

```bash
MANGOHUD=1 battlenet-launch
```

Environment variables pass straight through the launcher from chapter 16
to the game, so nothing needs changing there.

---

## 5. Reading It Properly

Most people look at the frame rate. The frame rate is the least useful
number on the overlay.

**Frame times are what you feel.** A frame rate is an average over a
second, and averages hide exactly the thing that makes a game feel bad.
Sixty frames delivered evenly at 16.7 milliseconds apart is smooth. Sixty
frames delivered as a burst of fast ones and a few slow ones is visibly
stuttery, and both report "60 FPS". The frame time graph shows the
difference immediately: flat is good, spiky is not, and a single tall
spike is a hitch you will have felt.

**The two load figures answer the actual question.** This is the reason to
run the overlay at all:

| `GPU` load | `CPU` load | You are | So change |
| --- | --- | --- | --- |
| ~100% | well under | `GPU` bound | Shadows, resolution, view distance, effects |
| well under | one core ~100% | `CPU` bound | Particle and spell density, draw distance, crowd |
| both high | both high | Genuinely balanced | Either, a little at a time |
| both low | both low | Capped | See section 7, you are waiting on the display |

That last row catches people out, and section 7 is about it.

**Watch per core, not the average.** A game bottlenecked on a single
thread shows maybe 20% average `CPU` usage on a six core part while one
core sits pinned at 100%. The average says you have plenty of headroom.
You do not. This is why the configuration snippet enables `core_load`.

**Measure where it actually hurts.** Testing in an empty field tells you
nothing useful, because that is the easy case and you were never going to
have a problem there. Go to the busiest place you genuinely play, in a
crowded city or a raid, and read the overlay there. That number is your
real answer. Everything else is a best case you will rarely see.

---

## 6. Two Profiles, and Why Yours Are Probably Identical

Some games keep separate graphics profiles for different situations, and
`WoW` is one of them. It maintains a full second set of settings prefixed
`RAID`, used in raids and other crowded instances:

```bash
grep -a "^SET RAID\|^SET raid" "/mnt/modded/.../WTF/Config.wtf" | head
```

If you have never touched it, that profile is an exact copy of your normal
one, which wastes the entire mechanism. The point of it is that the
crowded case is limited by something different from the quiet case. From
section 1, raids are where you are `CPU` bound, so the raid profile is
where particle density, spell density and draw distance should come down,
and where shadow quality matters least because your `GPU` was not the
problem there in the first place.

This is the single most under-used performance lever in that game, and the
general shape applies elsewhere. If an application offers per-situation
settings, it is telling you that its own load varies by situation. Take
the hint and tune them differently, or you have gained nothing from the
feature existing.

---

## 7. When Both Loads Are Low

If the overlay shows a frame rate that will not rise while neither the
`CPU` nor the `GPU` is working hard, nothing is bottlenecked. You are
waiting on the display, and the setting responsible is vertical sync.

```bash
grep -a "vsync" "/mnt/modded/.../WTF/Config.wtf"
```

With vsync on, frames are held back to align with your monitor's refresh.
On a fixed refresh display this is all or nothing: if you cannot sustain
the full rate, the game drops to a clean fraction of it, and the jump from
one to the other is the judder you feel when a busy scene appears.

High refresh panels make this worse rather than better. A 180Hz ultrawide
at 3440x1440 is roughly two and a half times the pixels of 1080p, and
sustaining 180 frames of a modern game at that resolution on a card of the
`GTX 1080` generation is not a realistic target at any settings worth
using. Chasing it means stripping the picture bare and still missing.

There are two sensible responses.

**Cap the frame rate somewhere you can genuinely hold.** A steady, lower
number feels better than an unsteady higher one, for the frame time reason
in section 5. Pick a figure you can sustain in the crowded case, not the
quiet one.

**Or use variable refresh**, which is the better answer where the hardware
supports it. Rather than forcing frames to match the display, the display
matches the frames, and the judder stops being a thing that exists. Most
`FreeSync` monitors work with `NVIDIA` cards as G-Sync Compatible. On
`X11` this needs an `Xorg` option rather than a checkbox, which makes it a
larger change than it sounds, and it takes a session restart. It is worth
doing once rather than fighting vsync forever.

---

## 8. The Cost of a Compatibility Fix

One thing specific to running games this way deserves stating plainly,
because it interacts with everything above.

In [chapter 16](./16_battlenet.md) the fix for a hung `GPU` was to move
the game from `D3D12` onto `D3D11`, avoiding the `VKD3D` translation
layer. That fix is correct and the game runs. It is not free. The newer
`API` exists largely to spread graphics work across more `CPU` threads,
so giving it up costs `CPU` overhead, in exactly the crowded scenes where
you were already `CPU` limited.

This is the honest shape of the trade. You are not choosing between a fast
configuration and a slow one. You are choosing between a configuration
that runs and one that hangs, and then living with the bill. Knowing that
the bill lands on the `CPU` side is what stops you from spending an
evening lowering shadow quality to fix it.

It also tells you where to look if the hardware ever changes. The reason
for avoiding the newer `API` was a `Pascal` card whose capability line in
section 2 showed it gaining nothing from it. On hardware where that line
reads differently, the trade is worth revisiting rather than inherited
out of habit.

---

## 9. Quick Reference

| Action | Command |
| --- | --- |
| Install the overlay | `sudo pacman -S --needed mangohud lib32-mangohud` |
| Run a game with it | `MANGOHUD=1 battlenet-launch` |
| Toggle it while playing | `Shift_R` + `F12` |
| Hardware capability line | `grep -a GpuInfo <game>/Logs/gx.log` |
| Video memory in use | `grep -a "Mem Budget" <game>/Logs/gx.log \| tail -3` |
| Which API is active | `grep -a "Device Create" <game>/Logs/gx.log` |
| Monitor refresh and modes | `xrandr --query \| grep -A3 "connected primary"` |
| Active mode only | `xrandr --query \| grep '\*'` |
| Check vsync setting | `grep -a vsync <game>/WTF/Config.wtf` |
| Compare the two profiles | `grep -a "^SET raid" <game>/WTF/Config.wtf` |

| Reading | Meaning |
| --- | --- |
| `GPU` near 100%, `CPU` low | `GPU` bound. Resolution, shadows, view distance. |
| One core near 100%, `GPU` low | `CPU` bound. Entity counts and effect density. |
| Both low, frame rate flat | Not bottlenecked. Vsync or a frame cap. |
| Flat frame time graph | Smooth, whatever the average says. |
| Spiky graph at a good average | Stutter. The average is lying to you. |
| `Mem Budget` far below total | Texture resolution is close to free. |
| `rt:None`, `vrs:0`, `mesh:0` | Old enough that the newer `API` offers nothing. |

---

## Why this is harder than it should be

The difficulty here is not technical. It is that the question is asked in
a form that has no answer, and the form is so natural that nobody notices.

"Can my computer run this at high settings" presumes a single threshold
that either is or is not crossed. There is no such threshold. There are
two separate resources that run out under different conditions, in
different parts of the same game, ten seconds apart. Someone who tells you
a `GTX 1080` handles a given game at given settings has answered a
question about a place they happened to stand.

The second problem is that the numbers most visible are the least useful.
Frame rate is displayed everywhere, quoted in every comparison, and tells
you almost nothing about whether a game feels good or what to change. The
figures that do answer those questions, frame time consistency and which
component is saturated, are not shown by default anywhere, which is why
installing an overlay changes the conversation so completely. It is not
that the information was hard to obtain. It was simply never put in front
of you.

The third is that this invites you to fix the wrong thing, convincingly.
Lowering settings when you are `CPU` bound produces a visibly worse game
and an unchanged frame rate, and the natural conclusion is that the
hardware is past it. That conclusion gets acted on with money. Five
minutes with a load reading would have shown the card idling while one
`CPU` core did all the work, and pointed at settings that would actually
have helped.

Measure first. It is a shorter job than the guessing it replaces, and
unlike the guessing, it ends.

| [← Previous](./16_battlenet.md) | [Next →](./18_smaller_fixes.md) |
|:--|--:|
