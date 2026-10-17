# Modding The Sims 4 on Arch

Mods are half the reason to play `The Sims 4` on a PC. Custom hair,
furniture, whole new gameplay systems, and the handful of script mods most
players consider essential. The good news is that `Proton` changes nothing
about how mods work. The game reads the same files from the same folder it
would on `Windows`, with the same rules.

What changes is everything around that folder. It is buried inside a
`Wine` prefix, your browser may not be allowed to see it, the downloads
arrive in archive formats your desktop may not open, and a script mod
running under `Wine` can reach far more of your machine than you might
expect. None of that is hard once you know it. This chapter sets up a
proper home for your mods, a shortcut so you never type the path again,
and a routine for installing, updating and fixing them.

A script, `sims4-mods`, does the repetitive parts: it installs mods to the
right depth, checks for anything the game will skip, and handles backups.

> **Note**
> This chapter follows on from [chapter 24](./24_sims4_on_steam.md), which
> gets the game itself running. The examples assume Steam's default library
> under `~/.local/share/Steam`. If your games live on another drive,
> substitute that library. The Sims 4's Steam app id is `1222670`.

---

## 1. Where the Game Looks

On `Windows` the game keeps your mods, saves and settings in
`Documents\Electronic Arts\The Sims 4`. Under `Proton` that folder exists
too, but inside the game's prefix, under the profile name `steamuser`:

```bash
S="$HOME/.local/share/Steam/steamapps/compatdata/1222670/pfx/drive_c/users/steamuser/Documents/Electronic Arts/The Sims 4"
ls "$S"
```

The parts you care about:

| Folder or file | What goes there |
| --- | --- |
| `Mods` | Custom content (`.package`) and script mods (`.ts4script`) |
| `Tray` | Downloaded households, lots and rooms |
| `saves` | Your save games |
| `Screenshots` | In-game screenshots |
| `Options.ini` | Game settings, including whether mods load |
| `localthumbcache.package` | Thumbnail cache, the first thing to clear when CC misbehaves |

The game writes a `Resource.cfg` into `Mods` the first time it starts, and
that file is the rulebook for what it loads:

```
Priority 500
PackedFile *.package
PackedFile */*.package
PackedFile */*/*.package
PackedFile */*/*/*.package
PackedFile */*/*/*/*.package
PackedFile */*/*/*/*/*.package
```

Each line is a pattern, one folder deeper than the last. Read the rules
off it:

* **`.package` files** load from `Mods` itself and up to five folders below
  it. Anything deeper is silently ignored.
* **`.ts4script` files** are not covered by that file at all. The game
  only looks for them in `Mods` and **one** folder below. A script mod two
  folders deep never loads, and the game does not tell you.
* **Archives** (`.zip`, `.7z`, `.rar`) are not read. A mod still in its zip
  does nothing.

Those three rules account for most "my mod isn't working" problems, on any
platform.

---

## 2. Turning Mods On

Mods are off in a fresh install. Two lines in `Options.ini` control them:

```bash
grep -E 'modsdisabled|scriptmodsenabled' "$S/Options.ini"
```

```
scriptmodsenabled = 0
modsdisabled = 0
```

`modsdisabled = 0` means custom content loads. `scriptmodsenabled = 0`
means script mods do not. Change both in the game rather than in the file,
under **Options**, **Game Options**, **Other**: tick **Enable Custom
Content and Mods** and **Script Mods Allowed**, then quit and restart the
game. The game rewrites `Options.ini` on exit, so an edit made while it is
running is thrown away.

Expect to do this again. After a game patch, the game switches mods off by
itself and tells you so on the main menu, because a patch is the most
likely moment for a mod to break. Section 6 covers what to do before you
switch them back on.

While you are in that menu, keep **Show Mods List at Startup** on. It
lists every mod the game actually loaded, which is the quickest proof that
a new mod is in the right place.

---

## 3. A Shortcut You Will Actually Use

That path is not something you want to type or click through every time
you download a new hair. Make a folder of symbolic links somewhere you can
reach:

```bash
G="$HOME/My Games/EA/Sims4"
mkdir -p "$G"
for d in Mods Tray saves Screenshots; do ln -sn "$S/$d" "$G/$d"; done
ln -sn "$S" "$G/User Folder"
```

`ln -s` makes a symbolic link, a small file that points at another path.
`-n` stops `ln` from following an existing link and creating a link inside
the folder it points at, which is what happens if you run the loop twice
without it. `sims4-mods link` does the same, in the same place unless you give it
another folder, and is safe to repeat.

Then make it one click away. In `Dolphin`, open `~/My Games/EA`,
right-click `Sims4` and choose **Add to Places**. It now sits in the sidebar of every
file dialog on the system, including your browser's save dialog.

If you would rather launch it from the application menu, write
`~/.local/share/applications/sims4-mods.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Sims 4 Mods
Comment=Open the Sims 4 mods folder
Exec=xdg-open "/home/YOUR_USER/My Games/EA/Sims4/Mods"
Icon=folder-games
Terminal=false
Categories=Game;
```

`Exec` needs the absolute path, because desktop entries do not expand
`~`. Validate it and refresh the menu:

```bash
desktop-file-validate ~/.local/share/applications/sims4-mods.desktop
update-desktop-database ~/.local/share/applications
```

### Links are not copies

Everything in `~/My Games/EA/Sims4` is a pointer into the prefix. The real
files still live under `compatdata`, and that matters more than it looks. Anything
that removes the prefix removes your mods, your saves and your downloaded
households with it, and uninstalling a game through Steam can remove its
prefix. The shortcut folder will still be there afterwards, full of links
pointing at nothing.

So do not treat the shortcut as a backup. Section 8 covers that.

---

## 4. Getting Mods Onto Disk

### Downloading

Download to `~/Downloads` and install from there. Do not point your
browser straight at the `Mods` folder.

There is a practical reason for this on `Arch`. If your browser is a
`Flatpak`, it runs in a sandbox that can only see the folders it has been
granted, usually `~/Downloads`. The prefix is outside that, so the save
dialog either cannot see the `Mods` folder or quietly saves somewhere else.
Downloading first also gives you a chance to look at what you got before
the game reads it.

### Unpacking

Mods arrive as `.zip`, `.7z` or `.rar`. The tools:

```bash
sudo pacman -S unzip 7zip
```

`7zip` opens `.7z` and most `.rar` files. If a `.rar` will not open, install
`unrar` as well. On `KDE`, `Ark` gives you right-click **Extract** in
`Dolphin` and uses the same tools underneath.

### Putting files in the right place

Once unpacked, a download usually contains a folder with the mod files, a
readme, and sometimes preview images or a second folder for a different
version of the game. Only two file types belong in `Mods`:

```bash
find ~/Downloads/SomeMod -iname '*.package' -o -iname '*.ts4script'
```

Make a folder for the mod inside `Mods` and put those files directly in it:

```
Mods/
├── Resource.cfg
├── SomeCreator_Hair/
│   └── SomeCreator_Hair.package
└── SomeScriptMod/
    ├── somescriptmod.ts4script
    └── somescriptmod_tuning.package
```

One folder per mod, files directly inside it, is always legal. It is one
folder deep, which satisfies the script rule and the package rule at once,
and it means updating or removing a mod is a single folder.

Households, lots and rooms are different. They come as `.trayitem`,
`.blueprint`, `.bpi`, `.householdbinary`, `.hhi`, `.sgi`, `.room` and
`.rmi` files, and they go in `Tray`, all together, with no subfolders.
Put them in `Mods` and the game ignores them.

`sims4-mods install` does all of this for you:

```bash
sims4-mods install ~/Downloads/SomeMod.zip ~/Downloads/AnotherMod.rar
```

It unpacks each file into an empty temporary folder, copies only the
`.package` and `.ts4script` files into `Mods/<name>/`, sends any Tray files
to `Tray`, and leaves the readmes behind. It refuses to install over a mod
that is already there, which is deliberate. Section 6 explains why.

---

## 5. Script Mods Run With Your Permissions

Custom content is data: meshes, textures and tuning that the game reads.
Script mods are different. A `.ts4script` file is a zip of compiled
`Python` that the game runs as part of itself, with full access to
whatever the game can reach.

On `Windows` that is already a reason to be careful. Under `Wine` there is
an extra detail worth knowing. Look at the prefix's drive letters:

```bash
ls -l "$HOME/.local/share/Steam/steamapps/compatdata/1222670/pfx/dosdevices/"
```

```
c: -> ../drive_c
z: -> /
```

`Z:` is your entire filesystem. Anything running inside the prefix,
including a script mod, can read and write anything your user can: your
home folder, your `SSH` keys, your browser profile. `Wine` is not a
sandbox, and nothing in it pretends to be one.

That is not a reason to avoid script mods. It is a reason to get them from
the creator's own page (their `Patreon`, `CurseForge` or site), not from
re-uploads, and to be suspicious of anything that arrives as an `.exe`
installer rather than a plain `.ts4script`. A legitimate Sims mod never
needs an installer.

---

## 6. When the Game Updates

EA patches the game regularly, and script mods are tied closely to the
game's code, so a patch is when they break. The routine:

1. **Let the game update and start it once with mods off.** It will have
   switched them off by itself anyway. This confirms the game works on its
   own before you add anything back.
2. **Check your script mods' pages for updates.** Creators usually post
   within a few days of a patch. Custom content almost never needs
   updating.
3. **Replace, do not overwrite.** Move the old version out of `Mods`
   before installing the new one:

   ```bash
   sims4-mods retire SomeScriptMod
   sims4-mods install ~/Downloads/SomeScriptMod_v2.zip
   ```

   `retire` moves the folder to `Mods-retired/`, next to `Mods`, with a
   date on the end. It has to go outside `Mods`, because anything inside
   `Mods` still loads, even in a folder called `old`. Copying a new version
   over the top of an old one is the classic way to end up with both: the
   new files plus any old file the new version renamed or dropped.
4. **Clear the thumbnail cache, then switch mods back on:**

   ```bash
   sims4-mods clear-cache
   ```

   This moves `localthumbcache.package` aside. The game rebuilds it on the
   next start, and a stale one is behind most cases of CC showing the wrong
   thumbnail or not appearing in build mode.

---

## 7. Finding the Mod That Broke Something

Start with the check, which catches the mechanical mistakes:

```bash
sims4-mods check
```

It reports whether mods are switched on, any archive left unpacked inside
`Mods`, any script mod more than one folder deep, any `.package` more than
five deep, Tray files in the wrong place, the same file name appearing
twice (usually an old version left behind), and any exception reports the
game has written.

Those reports are the game's own error logs. When something goes wrong in
game, it writes files called `lastException.txt` or
`lastUIException.txt` into the user folder:

```bash
ls -t "$S"/last*Exception*.txt
```

They are long and mostly unreadable, but they usually name the mod
involved somewhere in a file path. Search for your creators' names first.

If that does not point at anything, use the **50/50 method**. Move half
your mod folders out of `Mods`, start the game and see if the problem is
still there. If it is, the culprit is in the half you kept. If not, it is
in the half you moved. Keep halving the suspect group until one folder is
left. With a hundred mods that is about seven restarts, rather than a
hundred.

```bash
mkdir -p "$S/Mods-holding"
mv "$S/Mods/SomeMod" "$S/Mods/AnotherMod" "$S/Mods-holding/"
```

The holding folder sits next to `Mods`, not inside it, for the same reason
as `retire`. Clear the cache between rounds, so you are never chasing a
stale thumbnail.

---

## 8. Backups

The prefix is a single point of failure for everything in this chapter.
Back up the real folders, not the links:

```bash
sims4-mods backup ~/Backups/Sims4
```

That writes a dated `.tar.gz` of `Mods`, `Tray`, `saves`, `Screenshots`
and `Options.ini`. Run it with the game closed, and before every patch.
A backup taken after a patch is a backup of whatever the patch did to your
files.

To restore, unpack it into the documents folder:

```bash
tar -C "$S" -xzf ~/Backups/Sims4/sims4-<date>.tar.gz
```

Keep the backups somewhere other than the Steam library. A backup on the
same drive as the prefix does not survive the drive.

---

## 9. Quick Reference

| Action | Command |
| --- | --- |
| Make the shortcut folder | `sims4-mods link` |
| Install mods from downloads | `sims4-mods install ~/Downloads/<file>...` |
| Check for anything the game will skip | `sims4-mods check` |
| Take a mod out without deleting it | `sims4-mods retire <folder>` |
| Clear the thumbnail cache | `sims4-mods clear-cache` |
| Back up mods, Tray and saves | `sims4-mods backup <dir>` |
| Mod settings | `grep -E 'modsdisabled\|scriptmodsenabled' "$S/Options.ini"` |
| Find the mod files in a download | `find <dir> -iname '*.package' -o -iname '*.ts4script'` |
| Newest error report | `ls -t "$S"/last*Exception*.txt \| head -1` |
| What the prefix can reach | `ls -l <prefix>/dosdevices/` |

| Symptom | Meaning |
| --- | --- |
| Mod not in the startup mod list | Wrong folder, too deep, or still zipped. Run `sims4-mods check`. |
| Script mod does nothing, CC works | Script mods off, or the `.ts4script` is two folders deep. |
| All mods stopped after an update | The game switched them off. Update script mods, then switch back on. |
| CC missing or wrong thumbnails | Stale `localthumbcache.package`. Clear it. |
| Household download not in the gallery | Tray files went into `Mods`. Move them to `Tray`. |
| Old and new versions both loading | Updated by overwriting. Retire the folder and reinstall. |
| Browser cannot save into `Mods` | `Flatpak` sandbox. Download to `~/Downloads` and install from there. |
| `lastException.txt` keeps appearing | A mod is failing. Search the report for its name, then 50/50. |
| Shortcut folder full of broken links | The prefix was removed. Restore from backup. |

---

## Why this is harder than it should be

Strictly, it is not. Of everything in this guide, modding is the part that
`Linux` changes least. The rules in section 1 are the game's rules, and
they are the same on every platform.

What makes it feel harder is distance. On `Windows` the mods folder is in
your documents, one click from anywhere. Here it is six folders deep in a
directory named after a number, under a user that is not you, inside a
fake `C:` drive. Every step becomes a little harder than it should be: your
browser cannot see it, your file manager does not offer it, and it is easy
to forget that the folder you are looking after depends on a prefix that
Steam can remove. Most of this chapter is just closing that distance, with
a shortcut, a place in your sidebar and a script that knows the path so
you do not have to.

The other thing worth carrying away is section 5. It is easy to think of
`Wine` as a box that Windows programs run inside. It is not. It is a
translator, and the program it is translating runs as you, with your
files on `Z:`. That is exactly why so much `Windows` software works under
it, and it is also why a mod from a stranger deserves the same suspicion
under `Linux` as it would anywhere else. Being on `Arch` does not change
what a script mod can do to your files.

| [← Previous](./24_sims4_on_steam.md) |
|:--|
