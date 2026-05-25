# Arch Linux Study Guide

A practical roadmap for getting comfortable with `Arch` beyond just installing it. The chapters in this
repo will get you a working system. This guide is what comes after, the topics worth learning so that
when something breaks (and on `Arch`, sooner or later it does) you can actually fix it yourself.

## Objective

To become self-sufficient in maintaining, repairing, and improving an `Arch` system. Understanding *why*
things work matters more than memorising commands. Commands are a search away, judgment isn't.

## Core Principles

1. **Wiki first.** Always consult [the Arch Wiki](https://wiki.archlinux.org) before Reddit, forums, or
   YouTube. It is the authoritative source and is usually more up to date than anything else.

2. **Stay composed when something breaks.** Breakage is an opportunity to learn. You built snapshots
   and fallbacks for exactly this moment, use them.

3. **Observe, interpret, research, test, reflect.** Every issue is a cycle of reasoning, not reaction.
   Jumping to a "fix it" command without understanding what changed is how you make a small problem
   into a large one.

4. **Document what you learn.** Markdown notes you can grep through later are worth more than the
   tabs you closed yesterday.

5. **Prepare before failure.** LTS kernels, snapshots, and backups turn uncertainty into calm control.

## Learning Roadmap

### 1. Foundations

* [Arch Wiki: Installation guide](https://wiki.archlinux.org/title/Installation_guide)
* [General recommendations](https://wiki.archlinux.org/title/General_recommendations)
* [System maintenance](https://wiki.archlinux.org/title/System_maintenance)
* `man bash`, `man pacman`, `man systemd`

Practice:

* Revisit each section of the Wiki and try explaining it to yourself in plain English.
* Learn what every file in `/etc` does.

### 2. System Management

* [Pacman](https://wiki.archlinux.org/title/Pacman) and
  [Package signing](https://wiki.archlinux.org/title/Pacman/Package_signing)
* [systemd](https://wiki.archlinux.org/title/Systemd)
* [Journald logging](https://wiki.archlinux.org/title/Systemd/Journal)
* [mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio)

Practice:

* Inspect your logs: `journalctl -p 3 -xb`
* Enable / disable a systemd service and note what changes.
* Read `/etc/mkinitcpio.conf` and identify every hook.

### 3. Filesystems and Storage

* [Btrfs](https://wiki.archlinux.org/title/Btrfs)
* [Fstab](https://wiki.archlinux.org/title/Fstab)
* [Mount](https://wiki.archlinux.org/title/Mount)

Practice:

* Create and delete a manual snapshot.
* Mount subvolumes manually.
* Simulate restoring a snapshot in a VM to understand the flow without committing to it.

### 4. Kernel and Drivers

* [Kernel](https://wiki.archlinux.org/title/Kernel)
* [NVIDIA](https://wiki.archlinux.org/title/NVIDIA)
* [Kernel modules](https://wiki.archlinux.org/title/Kernel_module)

Practice:

* Identify your current kernel: `uname -r`
* Install and test the LTS kernel.
* Rebuild initramfs and read the output carefully.

### 5. Stability and Recovery

* [Snapper](https://wiki.archlinux.org/title/Snapper)
* [GRUB-btrfs](https://wiki.archlinux.org/title/GRUB-btrfs)
* [Arch News](https://archlinux.org/news/)

Practice:

* Create a snapshot before updates.
* Visit Arch News weekly, or run `archnews`.
* Restore a snapshot in a VM for practice.

### 6. Troubleshooting Method

1. **Observe** the logs and errors directly, not forum posts about similar errors.
2. **Interpret**: what changed recently? Check `pacman.log`, `uname -r`.
3. **Research**: Arch Wiki, then man pages, then forums (in that order).
4. **Test** one change at a time. Two simultaneous changes mean you can't tell which one worked.
5. **Reflect**: write down the cause and the fix. Future-you will thank you.

Tools worth knowing:

```bash
journalctl -xe
systemctl status <service>
dmesg | less
pacman -Qkk | grep MISSING
```

### 7. Security and Hardening

* [Security](https://wiki.archlinux.org/title/Security)
* [Sysctl](https://wiki.archlinux.org/title/Sysctl)
* [Uncomplicated Firewall](https://wiki.archlinux.org/title/Uncomplicated_Firewall)
* [OpenSSH](https://wiki.archlinux.org/title/OpenSSH#Server_usage)
* [Tailscale](https://wiki.archlinux.org/title/Tailscale)

Practice:

* Run `ss -tulpn` on your machine and explain every listening port to
  yourself.
* Disable one service you don't actually use (`avahi`, `bluetooth`,
  `cups`) and observe what changes.
* Walk through [chapter 11](./chapters/11_hardening.md) on a `VM` first,
  then on your real install.

The goal here isn't paranoia, it's awareness. Knowing what is exposed,
to whom, and what protects it is the difference between a workstation
you trust and one you hope works.

### 8. Experimentation

* Learn in a safe environment using your `Btrfs` snapshots.
* Try breaking and fixing non-critical components on purpose.
* Compare different desktop environments or kernels without fear.

Each failure you repair strengthens comprehension. Confidence on `Arch` isn't about luck, it's about
having actually fixed enough things to trust your reasoning.

## Optional Toolchain

| Purpose               | Tool                    | Wiki Page                                                                  |
| --------------------- | ----------------------- | -------------------------------------------------------------------------- |
| News headlines        | custom `archnews` alias | n/a                                                                        |
| Snapshot automation   | Snapper                 | [Snapper](https://wiki.archlinux.org/title/Snapper)                        |
| GRUB snapshot entries | grub-btrfs              | [GRUB-btrfs](https://wiki.archlinux.org/title/GRUB-btrfs)                  |
| Mirror optimization   | reflector               | [Reflector](https://wiki.archlinux.org/title/Reflector)                    |
| Offline wiki          | arch-wiki-docs          | [Arch Wiki Docs](https://wiki.archlinux.org/title/Archwiki:Offline_access) |

## Journaling and Documentation

Keep a folder like `~/Notes/arch/` and log every problem you solve. The act of writing your reasoning
down is what makes it stick.

Example structure:

```
~/Notes/arch/
 |- networking.md
 |- kernel_and_drivers.md
 |- systemd_and_services.md
 |- btrfs_snapshots.md
 `- troubleshooting.md
```

Your goal isn't uptime, it's understanding. The system that you understand is the one you can keep
running.
