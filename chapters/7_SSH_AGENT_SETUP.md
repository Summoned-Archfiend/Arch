# Stopping Git from Asking for My SSH Passphrase Every Time

This is how I solved the problem of Git constantly asking for my SSH key passphrase on every push — particularly annoying with tools like the Obsidian Git plugin, which auto-commits in the background and has no way to prompt for a passphrase.

The fix is to run a persistent SSH agent that keeps my unlocked key in memory for the whole login session, and to make sure every program I run can find that same agent.

## The pieces

There are three moving parts:

1. **An SSH agent that keeps running.** This is the daemon that holds my unlocked key in memory. On Arch (and most modern Linux distros) the OpenSSH package ships a ready-made systemd user unit for this — I don't have to write one.
2. **An environment variable that points at the agent.** Every SSH client looks at `SSH_AUTH_SOCK` to find the agent. If a program is started in a session where that variable isn't set, it can't talk to the agent and falls back to prompting. So I need to make sure `SSH_AUTH_SOCK` is exported into my whole desktop session, not just the terminal I happened to start the agent in.
3. **An SSH config that auto-adds my key on first use.** With `AddKeysToAgent yes`, the very first SSH operation of the session asks for my passphrase, then the agent caches the unlocked key. Every subsequent operation is silent.

## What I actually configured

### 1. The systemd user unit (already there)

Most distros ship `ssh-agent.service` and `ssh-agent.socket` as user units under `/usr/lib/systemd/user/`. I just enabled it:

```bash
systemctl --user enable --now ssh-agent.service
```

If your distro doesn't ship one, you can drop a minimal unit at `~/.config/systemd/user/ssh-agent.service`:

```ini
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
```

`%t` expands to `$XDG_RUNTIME_DIR` (typically `/run/user/<uid>`).

### 2. Export `SSH_AUTH_SOCK` for the whole session

I created `~/.config/environment.d/ssh-agent.conf`:

```
SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket
```

`environment.d` is read by systemd at login and the variables get pushed into every process my session spawns — terminals, GUI apps from the application menu, everything. This is the part most "I followed a tutorial and it still doesn't work" stories miss: setting the variable in `.bashrc` only helps terminals; GUI apps launched from the menu won't see it.

### 3. The SSH config

I created `~/.ssh/config` (must be mode `600`):

```
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
```

`AddKeysToAgent yes` means: when SSH needs the key and it isn't loaded, prompt for the passphrase, unlock it, and hand it to the running agent for caching. After that, every SSH operation in the session uses the cached key.

If your private key isn't `id_ed25519`, change the `IdentityFile` line accordingly (e.g. `id_rsa`).

### 4. Log out and back in

`environment.d` only applies to **new** sessions. The session that's already running was started without those variables, so my existing terminals and GUI apps don't see them yet. Easiest fix: log out, log back in.

## Verifying it works

In a fresh terminal after re-login:

```bash
echo $SSH_AUTH_SOCK
# should print the agent socket path, e.g. /run/user/1000/ssh-agent.socket

systemctl --user status ssh-agent.service
# should show: active (running)

ssh -T git@github.com
# prompts for passphrase ONCE, then greets me with my GitHub username
# subsequent runs in the same session are silent
```

To check that a GUI app sees the same agent, find its PID and inspect its environment:

```bash
pgrep -af <app-name>
cat /proc/<PID>/environ | tr '\0' '\n' | grep SSH_AUTH_SOCK
```

The path should match what `echo $SSH_AUTH_SOCK` prints in my terminal.

## The "first push of the session" gotcha

Because `AddKeysToAgent yes` prompts on first use, *something* needs to be able to display that prompt. From a terminal it's fine — SSH just asks. But a GUI app like Obsidian has no terminal attached, so if it happens to be the first thing to need the key after login, the prompt has nowhere to go and the operation fails silently.

Two ways around it:

- **Prime the agent from a terminal at the start of the day.** Either run `ssh-add` (which prompts and loads the key), or just trigger any SSH operation:
  ```bash
  ssh -T git@github.com
  ```
  After that the key is cached and any GUI app can use it without prompting.

- **Install a graphical askpass helper.** This gives processes without a terminal a popup window to ask for the passphrase:
  ```bash
  # Arch / KDE
  sudo pacman -S ksshaskpass

  # Other options:
  # x11-ssh-askpass, lxqt-openssh-askpass, seahorse (GNOME)
  ```
  With this installed, Obsidian's first push of the session will trigger a popup instead of failing silently.

## Common troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `$SSH_AUTH_SOCK` is empty in a new terminal | Haven't logged out since adding `environment.d` file | Full log out / log back in |
| GUI app still prompts every time | Was already running before re-login | Fully quit the app (check the system tray) and relaunch |
| `Permission denied (publickey)` from `ssh -T git@github.com` | Public key not on the right GitHub account | Add the contents of the `.pub` file at `github.com/settings/keys` |
| `Could not open a connection to your authentication agent` | Agent service not running | `systemctl --user start ssh-agent.service` |
| GUI app fails silently on first push | No askpass installed and key not yet loaded | Install askpass, or pre-load the key from a terminal |
| `Bad owner or permissions on ~/.ssh/config` | Permissions too open | `chmod 600 ~/.ssh/config` |

## When all of this is overkill

For a personal machine with full-disk encryption, an unencrypted key is a perfectly reasonable trade-off. Just remove the passphrase from the key and skip the agent dance entirely:

```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
# enter the old passphrase, leave the new one blank (twice)
```

I wouldn't do this on a work or shared machine, but for a single-user laptop where stealing the key requires already having full filesystem access, it's fine.

## Alternative: skip SSH altogether

If I'd rather avoid SSH and agents entirely, GitHub still supports HTTPS with a Personal Access Token. The flow:

```bash
# Generate a PAT at github.com/settings/tokens (classic, scope: repo)

cd /path/to/my/repo
git remote set-url origin https://<USERNAME>:<PAT>@github.com/<USER>/<REPO>.git
git config --global credential.helper store
git push   # one manual push to seed the credential cache
```

After this, the credential is cached on disk and every push (including Obsidian auto-commits) works silently. The downside: PATs have an expiry date and need refreshing periodically. The upside: nothing to do with agents, sockets, or sessions.

## Why this took so long to figure out

Most "fix Git asking for passphrase" guides only handle one piece — usually the SSH config — and assume the agent and the env var "just work". On Linux desktops they often don't, because:

- Starting `ssh-agent` from a shell only sets `SSH_AUTH_SOCK` in *that shell* and its children.
- GUI apps launched from the application menu inherit their environment from the desktop session, which started before any shell.
- So the agent is running, the variable is set in your terminal, but the GUI app has no idea any of that exists.

The `environment.d` file is what bridges the gap — it lets systemd push the variable into the desktop session itself, before any apps start.
