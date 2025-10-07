# 🧭 Arch Linux Self-Reliance Study Guide

*A practical roadmap for mastering Arch Linux through reasoning, not rote.*

---

## 🎯 Objective

To become fully self-sufficient in maintaining, repairing, and improving an Arch Linux system — understanding *why* things work, not just *how* to run commands.

---

## 🧱 Core Principles

1. **Authority → Wiki first.**
   Always consult [the Arch Wiki](https://wiki.archlinux.org) before Reddit, forums, or YouTube.

2. **Composure over panic.**
   Breakage is an opportunity to learn. You built snapshots and fallbacks — use them.

3. **Observe → Interpret → Research → Test → Reflect.**
   Every issue is a cycle of observation and reasoning, not reaction.

4. **Documentation = retention.**
   Keep notes in Markdown. The system forgets nothing; neither should you.

5. **Prepare before failure.**
   LTS kernels, snapshots, and backups turn uncertainty into calm control.

---

## 🧩 Learning Roadmap

### 1. 📚 Foundations

* [Arch Wiki: Installation guide](https://wiki.archlinux.org/title/Installation_guide)
* [General recommendations](https://wiki.archlinux.org/title/General_recommendations)
* [System maintenance](https://wiki.archlinux.org/title/System_maintenance)
* `man bash`, `man pacman`, `man systemd`

**Practice:**

* Revisit each section of the Wiki and try explaining it to yourself in plain English.
* Learn what every file in `/etc` does.

---

### 2. ⚙️ System Management

* [Pacman](https://wiki.archlinux.org/title/Pacman) and [Package signing](https://wiki.archlinux.org/title/Pacman/Package_signing)
* [systemd](https://wiki.archlinux.org/title/Systemd)
* [Journald logging](https://wiki.archlinux.org/title/Systemd/Journal)
* [mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio)

**Practice:**

* Inspect your logs: `journalctl -p 3 -xb`
* Enable/disable a systemd service and note what changes.
* Read `/etc/mkinitcpio.conf` and identify every hook.

---

### 3. 🧰 Filesystems & Storage

* [Btrfs](https://wiki.archlinux.org/title/Btrfs)
* [Fstab](https://wiki.archlinux.org/title/Fstab)
* [Mount](https://wiki.archlinux.org/title/Mount)

**Practice:**

* Create and delete a manual snapshot.
* Mount subvolumes manually.
* Simulate restoring a snapshot (without rebooting) to understand the flow.

---

### 4. 🖥️ Kernel & Drivers

* [Kernel](https://wiki.archlinux.org/title/Kernel)
* [NVIDIA](https://wiki.archlinux.org/title/NVIDIA)
* [Kernel modules](https://wiki.archlinux.org/title/Kernel_module)

**Practice:**

* Identify your current kernel: `uname -r`
* Install and test the LTS kernel.
* Rebuild initramfs and read the output carefully.

---

### 5. 🛡️ Stability & Recovery

* [Snapper](https://wiki.archlinux.org/title/Snapper)
* [GRUB-btrfs](https://wiki.archlinux.org/title/GRUB-btrfs)
* [Arch News](https://archlinux.org/news/)

**Practice:**

* Create a snapshot before updates.
* Visit Arch News weekly or run `archnews`.
* Restore a snapshot in a VM for practice.

---

### 6. 🔧 Troubleshooting Method

1. **Observe:** Read logs and errors, not forums.
2. **Interpret:** What changed recently? (`pacman.log`, `uname -r`)
3. **Research:** Arch Wiki → man pages → forums.
4. **Test:** Apply one change at a time.
5. **Reflect:** Write down the cause and the fix.

**Tools to master:**

```bash
journalctl -xe
systemctl status <service>
dmesg | less
pacman -Qkk | grep MISSING
```

---

### 7. 🧩 Experimentation

* Learn in a safe environment using your Btrfs snapshots.
* Try breaking and fixing non-critical components.
* Compare different desktop environments or kernels without fear.

> Each failure you repair strengthens comprehension — not confidence in luck, but faith in reason.

---

## 🧰 Optional Toolchain

| Purpose               | Tool                    | Wiki Page                                                                  |
| --------------------- | ----------------------- | -------------------------------------------------------------------------- |
| News headlines        | custom `archnews` alias | —                                                                          |
| Snapshot automation   | Snapper                 | [Snapper](https://wiki.archlinux.org/title/Snapper)                        |
| GRUB snapshot entries | grub-btrfs              | [GRUB-btrfs](https://wiki.archlinux.org/title/GRUB-btrfs)                  |
| Mirror optimization   | reflector               | [Reflector](https://wiki.archlinux.org/title/Reflector)                    |
| Offline wiki          | arch-wiki-docs          | [Arch Wiki Docs](https://wiki.archlinux.org/title/Archwiki:Offline_access) |

---

## 🗒️ Journaling & Documentation

Keep a folder: `~/Notes/arch/` and log every problem you solve.

Example structure:

```
~/Notes/arch/
 ├─ networking.md
 ├─ kernel_and_drivers.md
 ├─ systemd_and_services.md
 ├─ btrfs_snapshots.md
 └─ troubleshooting.md
```

> The act of writing your reasoning cements knowledge. Documentation is philosophy applied to action.

---

## 🧘 Stoic Reflection

> “No man is more free than he who has mastered himself.” — Epictetus
> “And no system more stable than the one understood by its keeper.” — Anonymous Arch user

Arch Linux rewards discipline, observation, and courage.
You don’t memorise commands — you cultivate judgment.
Your goal isn’t uptime, but *understanding.*
