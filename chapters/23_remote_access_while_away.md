# Working on Your Home Machine While You Are Away

You are going away for a week and you want to keep working. Everything you
need is on your desktop at home: the projects, the toolchains, the
containers, the editor config you have spent months tuning. The laptop you
are taking has none of it, and copying it all across is a project in itself.

The alternative is to leave the desktop running and work on it from the
laptop over `SSH`, as if you were sitting in front of it. This chapter
covers how to choose between that and renting a server, how a laptop in a
hotel can find a machine behind a home router at all, how to set both ends
up step by step, and how to make sure the machine is still there to log
into on day six.

Two scripts go with it. `remote-access-setup` does the home machine's side,
and `remote-access-check` is a read-only check to run before you leave.

> **Note**
> The examples come from an `Arch` desktop running `KDE Plasma` with `UFW`
> enabled, reached from a `Windows 11` laptop. Addresses, names and output
> are illustrative. This chapter builds on [chapter 11](./11_hardening.md),
> sections 5 and 6, which cover hardening `sshd` and `Tailscale` in more
> depth.

---

## 1. Leave It On, or Rent a Server?

There are two sensible ways to work remotely for a week, and they fail in
different ways.

**Leave your own machine on**, and connect to it over a private network.
Everything is already set up, nothing has to be copied anywhere, and the
cost is the electricity. A desktop idling at around 100 W uses about
17 kWh in a week, which is a few pounds. The weakness is that nobody is
home to press the power button. A crash, a bad update or a power cut can
leave you locked out until you get back.

**Rent a cloud server** (a `VPS`) for the week, and set it up as a
development machine. Your home machine can be off, and if the server
breaks you can rebuild it from anywhere. The weakness is that it starts
empty: every tool, every project and every credential has to be put on it.

| | Your machine left on | A rented server |
| --- | --- | --- |
| Setup | Small: a private network and some checks | A new machine from scratch |
| Your tools and projects | Already there | Have to be copied or cloned |
| Hardware attached to it | Still reachable | Not available |
| If it stops responding | Locked out until you are home | Rebuild it from anywhere |
| Cost for a week | Electricity | A few pounds or euros |

If you do rent a server, the surprise charges come from what you leave
behind, not from hidden fees. Most cloud providers bill by the hour up to a
monthly cap, and keep billing while a resource exists:

* A server that is **powered off is still billed**. Delete it to stop paying.
* **Backups** are usually a percentage on top of the server price. You do
  not need them for a week.
* **Snapshots, volumes and reserved IP addresses** are billed on their own
  and can outlive the server. Delete them with it.
* Some providers bill a **full month up front** for their cheapest plans.
  Check before you pick a plan for a single week.

The rest of this chapter takes the first route: your own machine, left on.

---

## 2. How Your Laptop Finds a Machine Behind a Home Router

Your home machine has no public address of its own. Your router has one,
your internet provider may change it whenever it likes, and on many `UK`
connections it is shared with other customers through `CGNAT`, so it cannot
be reached from outside at all. Forwarding a port on the router, the old
answer, exposes `SSH` to every scanner on the internet and does not work
behind `CGNAT` anyway.

A mesh `VPN` solves both problems. [Chapter 11, section 6](./11_hardening.md#6-remote-access-via-tailscale)
explains why `Tailscale` is the one used here. What matters for this
chapter is how it actually connects two machines:

1. **Each device signs in.** `tailscaled` on the desktop and the Tailscale
   app on the laptop both log in to Tailscale's coordination server with
   the same account, and each reports where it can currently be reached.
2. **Each device gets a fixed private address and a name.** The desktop
   gets an address in `100.64.0.0/10` that never changes, wherever the
   laptop is, and a name through `MagicDNS`. That is why `ssh desktop`
   works without you ever knowing your home's public address.
3. **The two connect directly.** Both make an outgoing connection at the
   same moment, which most home routers, hotel networks and mobile networks
   allow. Nothing on your router needs configuring.
4. **If a direct path is impossible,** traffic goes through Tailscale's
   relay servers instead. It is slower but it still works, and it is
   encrypted end to end with `WireGuard`, so the relay cannot read it.

So yes, the laptop needs a `VPN` too: the Tailscale app, signed in to the
same account. It only carries traffic for your own devices. Everything else
the laptop does goes out over the hotel's network as normal.

---

## 3. Setting Up the Home Machine

`remote-access-setup` does the home side in one go. Install it and run it
as your normal user. It calls `sudo` itself where it needs to:

```bash
install -Dm755 scripts/remote-access-setup ~/.local/bin/remote-access-setup
remote-access-setup
```

It works through five steps:

1. Installs `openssh`, `tailscale` and `mosh`, skipping anything already there.
2. Starts `sshd` and `tailscaled`, now and at every boot.
3. Runs `tailscale up` if the machine is not on a tailnet yet. This prints a
   link. Open it and sign in. Google, Microsoft and GitHub accounts all
   work, and whichever you pick is the account every other device must use.
4. If `UFW` is active, allows `SSH` (`22/tcp`) and `mosh` (`60000:61000/udp`)
   on the `tailscale0` interface only. Nothing is opened to the internet.
5. Switches `SSH` to keys only, but only if `~/.ssh/authorized_keys` already
   has a key in it.

On a machine nobody has logged into remotely before, the end of the output
looks like this:

```
==> Joining this machine to your tailnet
    open the link below and sign in; use the same account on every device

To authenticate, visit:

        https://login.tailscale.com/a/1a2b3c4d5e6f

Success.
    tailnet address: 100.101.102.103
    tailnet name:    desktop

==> Firewall
Rule added
Rule added (v6)

==> SSH logins
    SKIPPED: /home/you/.ssh/authorized_keys is empty, so passwords stay on for now
```

That last line is deliberate. Turning passwords off before a key is in
place is the classic way to lock yourself out of a machine, so the script
refuses to. Note the tailnet name, then go to the laptop.

> **Note**
> A device's Tailscale login expires after 180 days by default, and an
> expired machine drops off the tailnet until someone signs it in again at
> the keyboard. For a home machine you rely on remotely, open the Tailscale
> admin console, find the machine under *Machines*, and choose
> *Disable key expiry*.

---

## 4. Setting Up a Windows Laptop

**Install Tailscale.** Download it from `tailscale.com/download`, install
it, and sign in with the **same account** as the desktop. A Tailscale icon
appears in the system tray. Click it, and the desktop should be listed by
name.

**Check you have an SSH client.** `Windows 11` ships with `OpenSSH`. Open
`Windows Terminal` (or `PowerShell`) and run:

```powershell
ssh -V
```

```
OpenSSH_for_Windows_9.5p1, LibreSSL 3.8.2
```

If that is an error, add it under *Settings > System > Optional features >
OpenSSH Client*.

**Make a key.** Press Enter to accept the default location. A passphrase is
optional, but sensible on a machine that travels:

```powershell
ssh-keygen -t ed25519
```

This creates two files in `C:\Users\<you>\.ssh\`: `id_ed25519`, the
private key, which never leaves the laptop, and `id_ed25519.pub`, the public
key, which you give to the desktop.

---

## 5. Giving the Laptop a Key

The desktop lets a key in if its public half is listed in
`~/.ssh/authorized_keys`. On `Linux` and `macOS`, `ssh-copy-id` puts it
there. `Windows` has no `ssh-copy-id`, so pipe the key over `SSH` instead.
This is the last time the desktop will ask for your password. Replace `you`
with your username on the desktop and `desktop` with its tailnet name:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh you@desktop "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

The `chmod` calls matter. `sshd` ignores an `authorized_keys` file that
other users could write to, and it does so silently, so a key that looks
right is refused without explanation.

Now log in again. It should not ask for a password:

```powershell
ssh you@desktop
```

To shorten that to `ssh desktop`, create a file called `config`, with no
extension, in `C:\Users\<you>\.ssh\`:

```
Host desktop
    HostName desktop
    User you
```

---

## 6. Turning Passwords Off

Back on the desktop, run the script again. With a key in place, it now
writes `/etc/ssh/sshd_config.d/10-remote-access.conf`:

```bash
remote-access-setup
```

```
==> SSH logins
    keys only: 1 key(s) in /home/you/.ssh/authorized_keys can log in, passwords cannot
```

The drop-in sets four things: `PasswordAuthentication no`,
`KbdInteractiveAuthentication no`, `PermitRootLogin no` and
`PubkeyAuthentication yes`. The script runs `sshd -t` before reloading, and
if `sshd` rejects the file it is moved aside rather than left to break the
next restart.

On `Arch`, `sshd_config` includes `/etc/ssh/sshd_config.d/*.conf` at the top
and the first value set wins, so `10-` overrides the package's own
`99-archlinux.conf`. If you already applied the fuller snippet from
[chapter 11, section 5](./11_hardening.md#5-hardening-sshd), this step changes
nothing you had not already done.

Log in from the laptop once more to prove the key still works. Do this
before you close the session you have open on the desktop.

---

## 7. A Session That Survives a Bad Connection

Hotel Wi-Fi drops. Trains go through tunnels. Over plain `SSH`, a dropped
connection kills whatever you were running in it: the build, the test run,
the editor with unsaved changes. Two tools fix that.

**`tmux` keeps your work running on the desktop.** It runs your shells
inside a session that belongs to the desktop, not to the connection. When
the connection drops, the session carries on. Start one when you log in:

```bash
tmux new -s work
```

After a dropout, log in again and pick it back up exactly where it was:

```bash
tmux attach -t work
```

**`mosh` keeps the connection itself alive.** It logs in over `SSH`, then
switches to `UDP`, survives the laptop changing networks or sleeping, and
shows your typing straight away instead of waiting for the round trip. It
does not replace `tmux`. `mosh` keeps one window alive, and `tmux` keeps the
work alive if the window goes anyway.

`mosh` has no real `Windows` client. If plain `SSH` with `tmux` is not
enough, install `WSL` on the laptop and use `mosh` from inside it:

```powershell
wsl --install
```

Then, in the `Ubuntu` terminal it gives you:

```bash
sudo apt install mosh
mosh you@desktop
```

`WSL` is a separate `Linux` system with its own `~/.ssh`. Either make a new
key inside it and add it as in section 5, or copy the `Windows` one across.

> **Note**
> If `mosh` fails with `mosh-server needs a UTF-8 native locale to run`,
> the desktop has no `UTF-8` locale generated, or the laptop sent a locale
> the desktop does not have. Check that `/etc/locale.conf` names a locale
> that `locale -a` lists on the desktop.

---

## 8. Making Sure It Is Still There on Day Six

Getting in once is easy. The real question is whether you can still get in
after the machine has had a week to go wrong with nobody watching.

**Have it power itself back on after a power cut.** By default, most
motherboards stay off when the power returns. The setting is in the BIOS,
usually under an *Advanced* or *Power* menu, named something like *Restore
AC Power Loss*, *AC Back* or *After Power Failure*. Set it to *Power On*.
`Linux` cannot read this setting, so check it by hand.

**Update before you leave, never while you are away.** On a rolling
release, an update can bring a new kernel or graphics driver that only
takes effect after a reboot, and a reboot you cannot watch is a gamble.
Update fully the day before you go, reboot, and check the machine comes
back properly. Then leave updates alone until you are home. If you update a
running `Arch` machine and do not reboot, the old kernel's modules are gone
from `/usr/lib/modules`, so anything that needs to load a module, a `USB`
device being plugged in or `Docker` starting a network, can fail.

**Do not let it sleep.** A suspended machine is unreachable, and nothing on
the tailnet can wake it. In `KDE`, open *System Settings > Power Management*
and set *When inactive* to *Do nothing* under *On AC Power*. To rule out
every other route to sleep as well, mask the sleep targets, and unmask them
when you get back:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

**Know what does not start without a login.** After a power cut the
machine boots to the login screen, and nobody logs in. System services such
as `sshd`, `tailscaled` and `Docker` start anyway. Your desktop session does
not, so neither do apps that start with it (anything in
`~/.config/autostart`), and neither does a remote desktop server that runs
inside that session. Your own `systemd` user services only start without a
login if lingering is on:

```bash
sudo loginctl enable-linger "$USER"
```

Decide whether anything you rely on runs only inside your session. If it
controls something that matters, such as fan curves, know what the
hardware does by itself when that program is not running.

---

## 9. Testing It Before You Go

Run the check as root, so it can read the effective `sshd` settings and the
firewall rules:

```bash
install -Dm755 scripts/remote-access-check ~/.local/bin/remote-access-check
sudo remote-access-check
```

```
1. Tailscale
  [ ok ] tailscaled.service is running and starts at boot
  [ ok ] signed in as desktop (100.101.102.103)
  [ ok ] 2 other device(s) on the tailnet

2. SSH
  [ ok ] sshd.service is running and starts at boot
  [ ok ] 1 line(s) in /home/you/.ssh/authorized_keys
  [ ok ] passwordauthentication no
  [ ok ] kbdinteractiveauthentication no
  [ ok ] permitrootlogin no

3. Firewall
  [ ok ] 22/tcp allowed on tailscale0
  [ ok ] 60000:61000/udp allowed on tailscale0

4. Staying up
  [ ok ] sleep, suspend and hibernate are masked; nothing can put the machine to sleep
  [ ok ] logind does nothing when the machine is idle
  [ ok ] KDE will not suspend on mains power when idle
  [ ok ] running kernel 6.17.2-arch1-1 matches the installed one
         lingering is off for you: systemd user services only start after a login
         the BIOS setting that powers the machine back on after a power cut cannot be read from here

5. Session tools
  [ ok ] tmux installed
  [ ok ] mosh-server installed
```

Every `[warn]` line names what to fix. Then test the way you will actually
work, from outside your own network, because a test over your home Wi-Fi
proves very little:

1. Turn off the laptop's Wi-Fi and tether it to your phone's mobile data.
2. Connect, start a session, and do some real work in it: open the project,
   run the build and the tests.

   ```powershell
   ssh desktop
   ```

   ```bash
   tmux new -s work
   ```

3. Close the terminal window without detaching. Connect again and run
   `tmux attach -t work`. Everything should be exactly where you left it.
4. Log out of the desktop at the keyboard so it sits at the login screen,
   and connect once more. That is the state it will be in after a power
   cut, so this is the test that matters most.

---

## 10. When You Get Back

None of this has to be undone. `Tailscale` with `SSH` scoped to the
tailnet is a sensible permanent setup, and it is how
[chapter 11](./11_hardening.md) recommends reaching a machine anyway. A few
things are worth reversing:

```bash
# let the machine sleep again, if you masked the targets
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target

# catch up on updates while you are at the keyboard to watch the reboot
sudo pacman -Syu
```

If you lose the laptop, or stop using it, remove it from the tailnet in the
Tailscale admin console and delete its line from
`~/.ssh/authorized_keys` on the desktop. Either one alone locks it out.
Doing both is better.

To remove the remote access setup completely, follow the `Reverse:` lines
at the top of `scripts/remote-access-setup`.

---

## Why This Is Harder Than It Should Be

The connection is the easy part. Ten years ago reaching a home machine
meant dynamic `DNS`, port forwarding and hoping your provider did not put
you behind `CGNAT`. A mesh `VPN` has turned all of that into signing in
twice. If the setup took an afternoon, almost none of that afternoon was the
network.

The hard part is that a machine you leave on is set up for someone sitting
in front of it. It goes to sleep because nobody is using it. It waits at
the login screen after a power cut, with half its software not started,
because it expects you to log in. Updates assume you will be there for the
reboot. Every one of those is the right default for a desktop, and the
wrong one for a machine you will not see for a week. None of them shows up
until the day it matters, which is why the test in section 9 is done at the
login screen, over mobile data, before you go.

And with every remote setup, the question is not whether you can get in
today. It is how many things have to go right for you to get in next
Thursday, and what happens to each of them when nobody is there.

| [← Previous](./22_rgb_and_fan_control.md) | [Next →](./24_sims4_on_steam.md) |
|:--|--:|
