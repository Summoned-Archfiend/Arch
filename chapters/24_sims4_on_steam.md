# The Sims 4 on Steam, and the EA App Hiding Inside It

`The Sims 4` is one of the easier games to buy for `Linux`, in the sense that
Steam sells it, Steam installs it, and `Proton` runs the game itself without
complaint. The trouble is that you are never only running the game. Every EA
title on Steam starts a copy of the **EA app** first, inside the game's own
`Wine` prefix, and that app is the part that breaks.

When I first pressed Play, the EA app opened, downloaded something, closed,
and Steam quietly marked the game as stopped. Nothing ever appeared. Once
that was fixed, the game sat on "Running" with no window. Once that was
fixed, the game loaded and then told me the EA app was not running, while
the EA app was very much running. Then my expansion packs showed as owned
but would not download.

Four problems, one after another, and none of them is really about the
game. They are about a launcher that assumes it is on `Windows`, and about
the ways `Proton` is not quite `Windows`. This chapter works through each
one and explains what the logs were actually saying. Mods are the easy
part, and they get their own chapter. A script, `ea-steam`, checks
everything here and does the repairs.

> **Note**
> The examples assume Steam's default library under `~/.local/share/Steam`
> and `GE-Proton10-27`. The Sims 4's Steam app id is `1222670`, which is the
> folder name under `compatdata`. Substitute your own library and Proton
> build. The same EA app sits inside every EA game on Steam, so most of
> this applies to them too with a different app id.

---

## 1. Where Everything Lives

Before touching anything, learn the four places this chapter keeps
returning to. With `C` as the game's compatibility folder:

```bash
C="$HOME/.local/share/Steam/steamapps/compatdata/1222670"
```

| What | Where |
| --- | --- |
| The game | `<library>/steamapps/common/The Sims 4` |
| The EA app | `$C/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop` |
| The EA app's logs | `$C/pfx/drive_c/ProgramData/EA Desktop/Logs` |
| Your saves, mods and settings | `$C/pfx/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 4` |

The last one catches people out. On `Windows` your saves live in your own
`Documents` folder. Here they live inside the prefix, under the profile name
`steamuser`, because that is the user `Proton` creates every prefix as.
[Chapter 16](./16_battlenet.md) covers why that name matters.

The logs folder is the one to remember. The EA app writes a plain text log
for every component it runs, and when it fails it nearly always says why,
in a file you would never think to open.

---

## 2. The Update That Never Installs

Here is the first failure. You press Play, the EA app's splash screen
appears, a progress bar runs, and then everything closes. Steam shows the
game as stopped. Press Play again and exactly the same thing happens.

Steam's own log only tells you that the processes ended:

```bash
grep 1222670 ~/.local/share/Steam/logs/gameprocess_log.txt | tail
```

```
AppID 1222670 no longer tracking PID 4182, exit code -1
...
Remove 1222670 from running list
```

The EA app's log tells you why. The component Steam starts is
`EASteamLauncher`, so read its log:

```bash
tail -20 "$C/pfx/drive_c/ProgramData/EA Desktop/Logs/EASteamLauncher.log"
```

```
Received update step completed: step=[Download] status=[UpdateDownloaded]
Received update step completed: step=[Stage] status=[UpdateStaged]
Received update step completed: step=[Destage] status=[UpdateRestarting]
Suite shutdown requested, source=[ClientUpdateDestaging] before game monitoring started, shutting down Steam launcher
```

Read those four lines in order, because they are the whole story. The app
found an update, downloaded it, unpacked it (**staging**), and then shut
itself down to swap the new version in (**destaging**). It shut down before
the game had started, so the game never started.

That alone would be a one-off annoyance. The giveaway that something is
stuck is the version number, which every component writes on startup:

```bash
grep -h 'Version:' "$C/pfx/drive_c/ProgramData/EA Desktop/Logs/"EA*.log | tail -5
```

If every line shows the same old version, launch after launch, the update
is never being installed. You are not watching one long update. You are
watching the same update fail every time you press Play.

### Why it never installs

The obvious theory is that Steam is to blame. The app closes to restart
itself, Steam sees the game's processes end, and Steam tears the prefix
down before the restart can happen. That is true as far as it goes, so the
natural test is to run the EA app outside Steam, where nothing is watching:

```bash
export STEAM_COMPAT_DATA_PATH="$C"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
PROTON=~/.local/share/Steam/compatibilitytools.d/GE-Proton10-27/proton
"$PROTON" runinprefix "$C/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"
```

Use `runinprefix` here, not `run`. `run` starts the program through
`Proton`'s own `steam.exe` wrapper, and when the program exits, that wrapper
ends every other process in the prefix with it, which is exactly the thing
you are trying to rule out.

On my machine the test failed in exactly the same way, which cleared Steam.
The answer turned up in the update itself. Inside the unpacked update is
the program that does the swap, `EADestager.exe`, and its strings show how
it expects to be started:

```bash
strings "<staged update>/Destager/EADestager.exe" | grep -- '-servicename'
```

```
-servicename={} -noupnp
```

The destager runs as a **Windows service**. `Wine`'s support for services
is limited, and this one never starts. The app shuts down, waits for a
service that never arrives, and the old version comes back up next time.
No amount of launching will get you past it.

---

## 3. Installing the Update by Hand

The good news is that the hard part has already been done. The update was
downloaded and its signature checked (the log says so: `Zip signature
verified successfully`), and it was unpacked next to the app:

```bash
ls "$C/pfx/drive_c/Program Files/Electronic Arts/EA Desktop/"
```

```
13.809.0.6322-1700000000
13.809.0.6322-1700000000.zip
13.809.0.6322-1700000000.zip.sig
EA Desktop
VC
```

The folder named after the new version holds a complete copy of the app in
its own `EA Desktop` folder. Compare the two before trusting it:

```bash
cd "$C/pfx/drive_c/Program Files/Electronic Arts/EA Desktop"
diff <(cd "EA Desktop" && find . -type f | sort) \
     <(cd "13.809.0.6322-1700000000/EA Desktop" && find . -type f | sort)
```

A handful of added or removed files is normal between versions. A staged
folder holding a fraction of the files would be a partial update, and you
should not use it.

Destaging is then just a swap. Close the game and the EA app completely
first, then move the old version aside rather than deleting it:

```bash
mv "EA Desktop" "EA Desktop.13.791-backup"
cp -a "13.809.0.6322-1700000000/EA Desktop" "EA Desktop"
```

Start the app once outside Steam and read the version back:

```bash
grep -h 'Version:' "$C/pfx/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log" | tail -1
```

It should now report the new version and carry on to its home screen
instead of closing. Once it has run successfully, the app deletes the
staged folder and zip on its own, which is also your sign that it accepts
the new version as installed.

`ea-steam destage` does all of this, refuses to run while anything is
running in the prefix, and keeps the old version as a backup.

This will happen again. Every time EA pushes a required update, the same
loop returns. If you have a separate, standalone EA app install for other
games, it gets stuck in exactly the same way, and the fix is the same swap
in that prefix.

---

## 4. "Running" With No Window

With the update in place, press Play again. Steam shows the game as
running, and nothing happens. No EA app, no game, no error.

Steam does not launch games with `proton run`. It uses a different verb:

```bash
pgrep -af 'proton waitforexitandrun'
```

`waitforexitandrun` does what it says. Before starting anything, it runs
`wineserver -w`, which waits until every process already running in the
prefix has exited. If anything is still running in that prefix, Steam will
wait for it forever, and "Running" is all you will ever see.

In my case it was my own test from section 3. The EA app I had started by
hand had minimised itself to the system tray, out of sight, and Steam was
patiently waiting for it to close. Find out what is in the prefix:

```bash
pgrep -af '\.exe' | grep -i 'electronic arts'
```

Close the EA app properly, including its tray icon, and the launch carries
on by itself within a few seconds. The lesson is short: **anything you run
in a game's prefix must be closed before you press Play.**

---

## 5. "The EA App Is Not Currently Running"

The game loads, and then shows this:

```
The EA app is not currently running. Please make sure that the EA app is
running before attempting to play.
```

The EA app is running. You can see it in the process list. The game simply
cannot find it, and it finds it through the registry.

The `Wine` registry is a set of plain text files in the prefix.
`system.reg` holds `HKEY_LOCAL_MACHINE`, so you can read it directly:

```bash
grep -A12 -E '^\[Software\\\\(Wow6432Node\\\\)?(Electronic Arts\\\\EA Desktop|Origin)\]' "$C/pfx/system.reg"
```

A broken prefix looks like this:

```
[Software\\Electronic Arts\\EA Desktop] 1700000000
"EaConnectLink2EAAppPath"="C:\\Program Files\\...\\Link2EA.exe"
"EaSteam2EAAppPath"="C:\\Program Files\\...\\EASteamLauncher.exe"
"IsUnavailable"=dword:00000000

[Software\\Wow6432Node\\Origin] 1690000000
```

Compare it with a prefix where the EA app was installed normally, and the
missing values stand out: `ClientPath`, `InstallLocation` and
`InstallSuccessful` under `EA Desktop`, and `ClientPath` under `Origin`.
`Origin` was EA's previous launcher, and games still look for the app
under its old name. The `Origin` key above exists but is empty. Its
timestamp dated from the day the game was first installed, so this had
been broken from the start, not by the manual update.

The fix is a `.reg` file with the values put back:

```ini
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Electronic Arts\EA Desktop]
"ClientPath"="C:\\Program Files\\Electronic Arts\\EA Desktop\\EA Desktop\\EADesktop.exe"
"DesktopAppPath"="C:\\Program Files\\Electronic Arts\\EA Desktop\\EA Desktop\\EADesktop.exe"
"LauncherAppPath"="C:\\Program Files\\Electronic Arts\\EA Desktop\\EA Desktop\\EALauncher.exe"
"InstallLocation"="C:\\Program Files\\Electronic Arts\\EA Desktop\\"
"InstallSuccessful"="true"

[HKEY_LOCAL_MACHINE\SOFTWARE\Origin]
"ClientPath"="C:\\Program Files\\Electronic Arts\\EA Desktop\\EA Desktop\\EADesktop.exe"
```

### The import that only half works

Importing it has two traps, and both fail silently.

The first is the path. Copy the file into the prefix's `C:` drive and
import it from there. Pointing `regedit` at a long `Z:\` path through
`/tmp` did nothing at all on my machine: no error, no values.

The second is that a 64-bit `Windows` keeps two registries. 32-bit programs
see a separate copy under `Wow6432Node`, and `Windows` quietly redirects
their writes there. `Proton`'s `regedit` is a 32-bit program, so this:

```bash
"$PROTON" runinprefix regedit /S 'C:\ea-keys.reg'
```

writes every value into `Wow6432Node` and leaves the 64-bit keys, the ones
a 64-bit game reads, exactly as they were. Import the same file a second
time with `reg.exe` and ask for the 64-bit view explicitly:

```bash
"$PROTON" runinprefix reg import 'C:\ea-keys.reg' /reg:64
```

Then check both copies, because a successful import looks the same whether
it worked or not:

```bash
grep -A3 -E '^\[Software\\\\(Wow6432Node\\\\)?Origin\]' "$C/pfx/system.reg"
```

Both blocks should now carry a `ClientPath`. `ea-steam registry` writes
the file, imports it both ways and checks both blocks.

---

## 6. Two EA Apps, One Port

With the registry fixed, the game might start and then complain:

```
The app couldn't connect to port 3216
```

The game talks to the EA app over local network ports, `3215` and `3216`.
Only one program on your machine can listen on a given port, and `Wine`
prefixes do not get their own network. A socket opened inside a prefix is
a real socket on your machine. So if you also have a standalone EA app
open, in a different prefix, for your non-Steam EA games, it takes those
ports first and the copy inside the Sims prefix cannot have them.

Ask who holds them:

```bash
ss -ltnp | grep -E ':321[56]'
```

```
LISTEN 0 50 127.0.0.1:3215 0.0.0.0:* users:(("wineserver",pid=5231,fd=334))
LISTEN 0 50 127.0.0.1:3216 0.0.0.0:* users:(("wineserver",pid=5231,fd=626))
```

It names `wineserver`, not the EA app, because `Wine` opens every socket
in a prefix through that prefix's `wineserver`. To find out which prefix,
read the process's environment:

```bash
tr '\0' '\n' < /proc/5231/environ | grep WINEPREFIX
```

If that is not the game's prefix, close that EA app and relaunch the game.
The rule is simply **one EA app at a time**. The game still started
alongside the error, but without its EA app it cannot check your packs or
connect online.

---

## 7. Packs: Owned, Not Installed

The last problem is the one you will meet most often. You buy a pack, it
shows as owned in the game, and the download button in the EA app is
greyed out with the message:

```
Some items are managed externally
```

Start by finding out what you already have and who installed it. Steam
installs packs bought on Steam as DLC, and records each one in the game's
manifest:

```bash
M="$HOME/.local/share/Steam/steamapps/appmanifest_1222670.acf"
grep -oE '"dlcappid"\s+"[0-9]+"' "$M" | sort -u | wc -l
ls "$HOME/.local/share/Steam/steamapps/common/The Sims 4" | grep -cE '^(EP|GP|SP|FP)[0-9]+$'
```

The second command counts the pack folders: `EP` for expansions, `GP` for
game packs, `SP` for stuff packs, `FP` for free packs. Their dates tell you
when each arrived:

```bash
ls -ld --time-style=+%F "$HOME/.local/share/Steam/steamapps/common/The Sims 4"/{EP,GP,SP,FP}[0-9]*
```

On my machine nearly everything arrived with the base game, and a single
expansion arrived a day later, on the first launch, which is the EA app
at work.

### Each store installs its own packs

The rule, which EA's own forum moderators repeat, is that each store only
downloads the packs bought through it:

* **Packs bought on Steam** come through Steam. If one has not appeared,
  restart Steam so it notices the purchase, then check the game's
  **Properties**, **DLC** tab and make sure it is ticked.
* **Packs bought from EA** come through the EA app, and it has to be the
  EA app inside the game's prefix, because that is the only copy that
  knows where the Steam install lives.

"Managed externally" means you are looking at a copy of the EA app that
cannot install into this game. There are two of those, and both are easy
to end up in by accident.

The first is a **standalone EA app** in its own prefix. It sees The Sims 4
as a Steam game installed somewhere it cannot reach, and greys everything
out.

The second is the window Steam opens when you press Play. Look at how
Steam starts the app:

```bash
grep -h 'Command line:' "$C/pfx/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log" | tail -3
```

```
EADesktop.exe -ls=BackgroundService -silent -mode=razor
```

`-mode=razor` is a cut-down mode whose job is to sign you in and hand over
to the game. It is not the full app, and it is not where you manage packs.

What you want is the full EA app, in the game's prefix, with nothing else
running. That is what `ea-steam open` starts. Go to **Library**, **The
Sims 4**, **Manage add-ons**, download the EA packs there, then close the
app completely before pressing Play in Steam (section 4 explains why).

> **Note**
> When I wrote this, the packs I had bought from EA were waiting on exactly
> this step, so treat this section as the route the evidence points to
> rather than one I have watched finish. If the button is still greyed out
> in the full app, read `EABackgroundService.log` in the logs folder for
> the pack's offer id before trying anything else.

---

## 8. Mods

With the game running, mods work exactly as they do on `Windows`, from a
`Mods` folder inside the prefix's documents folder (section 1). Finding
that folder, making it easy to reach, installing mods to the right depth
and keeping them safe through updates is its own subject, and it has its
own chapter: [chapter 25](./25_sims4_modding.md).

---

## 9. Quick Reference

| Action | Command |
| --- | --- |
| Check everything | `ea-steam status` |
| Open the full EA app in the game's prefix | `ea-steam open` |
| Install a stuck update | `ea-steam destage` |
| Restore the registry values | `ea-steam registry` |
| Why the last launch closed | `tail -20 <logs>/EASteamLauncher.log` |
| Which EA app version ran | `grep -h 'Version:' <logs>/EADesktop.log \| tail -1` |
| How the app was started | `grep -h 'Command line:' <logs>/EADesktop.log \| tail -3` |
| What is running in the prefix | `pgrep -af '\.exe'` |
| Who holds the EA ports | `ss -ltnp \| grep -E ':321[56]'` |
| Which prefix a wineserver serves | `tr '\0' '\n' < /proc/<pid>/environ \| grep WINEPREFIX` |
| Read a registry key | `grep -A12 '^\[Software\\\\Origin\]' <prefix>/system.reg` |
| Import a .reg into both views | `regedit /S` then `reg import <file> /reg:64` |
| Count Steam-installed packs | `grep -oE '"dlcappid"\s+"[0-9]+"' <manifest> \| sort -u \| wc -l` |

| Symptom | Meaning |
| --- | --- |
| EA app opens, downloads, closes, game stops | Self-update stuck. `ClientUpdateDestaging` in `EASteamLauncher.log`. Destage by hand. |
| Same EA app version in every log | The update has never been installed. |
| Steam says "Running", nothing appears | Something else is running in the prefix. Steam waits for it to exit. |
| "The EA app is not currently running" | Missing `ClientPath` in the registry. |
| Values imported but still missing | Only the 32-bit view was written. Import again with `/reg:64`. |
| "Couldn't connect to port 3216" | A second EA app holds the port. One EA app at a time. |
| Download greyed out, "managed externally" | Wrong EA app: standalone, or Steam's `-mode=razor` window. |
| Pack owned on Steam but missing | Restart Steam, check the DLC tab. |

---

## Why this is harder than it should be

Every problem in this chapter came from one design decision: an EA game
bought on Steam is two programs from two companies, sharing one prefix,
each assuming it is in charge.

Steam thinks it is launching a game. In fact it is launching a launcher,
which may decide to update itself, restart, or hand over to the game, and
Steam has no way to tell those apart. When the EA app closes to update,
Steam sees a game that has quit. When something is still running, Steam
waits for it without saying what it is waiting for. Neither program is
wrong by its own rules, and the result is a Play button that does nothing
useful while every part reports success.

The second theme is how quiet the failures are. The update that never
installs produces no error, just a progress bar and a closed window. The
registry import that only reaches the 32-bit view prints nothing either
way. The port clash still lets the game start. Each time, the program you
are looking at behaves as though everything is fine, and the real cause is
in a log file, a registry view or a socket table you had no reason to
check. This is the same lesson as [chapter 16](./16_battlenet.md): when a
`Windows` program misbehaves under `Wine`, the useful question is rarely
"what is broken?" It is "what else is involved that I cannot see?"

The last theme is the one I would most like you to take away. The fixes
here were small. Copying a folder, adding six registry values and closing a
tray icon is not a lot of work. What made it slow was that each fix
revealed the next problem, and each new symptom looked like the previous
fix had failed. When the game sat on "Running" after the manual update, it
looked like the update had broken something, and the real cause was an
app I had left open myself. Before you undo a fix, check whether you are
actually looking at a new problem. Here, every time, it was a new one.

| [← Previous](./23_remote_access_while_away.md) | [Next →](./25_sims4_modding.md) |
|:--|--:|
