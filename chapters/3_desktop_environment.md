# Desktop Environment

In this section we will install not one, but two, desktop environments (DEs) side by side: **GNOME** and **KDE Plasma**. This will allow us to switch between them depending on preference or use-case. Both use the same underlying system, but they differ significantly in their UI, workflow, and customisation options.

---

## Update the system

First, update and synchronise all packages and repositories:

```bash
pacman -Syyu
```

* `-S` = install or sync
* `yy` = force refresh of all package databases, even if up to date
* `u` = upgrade all packages

This ensures you have the latest package lists and software versions.

---

## Network Setup (VMs)

If you are running this inside a Virtual Machine, ensure you have external connectivity:

* Shut down your VM
* Open **Network Settings** in VirtualBox
* Change **Attached to** → `Bridged Adapter`
* Choose your real adapter (wired: Intel/Realtek, wireless: Wi-Fi dongle)
* Avoid `Hyper-V` unless specifically required
* Restart your VM and confirm with:

```bash
ping -c 3 archlinux.org
```

If you see responses, your network is working.

---

## Display Manager

Both GNOME and KDE Plasma require a **display manager** (login screen). The two most common are:

* **GDM** (GNOME Display Manager)
* **SDDM** (Simple Desktop Display Manager, used by KDE)

You only need one active at a time. We’ll install both, but enable only one (SDDM in this guide).

```bash
pacman -S gdm sddm
```

Enable SDDM:

```bash
systemctl enable sddm
```

If you later want GDM instead:

```bash
systemctl disable sddm
systemctl enable gdm
```

---

## Install GNOME

```bash
pacman -S gnome gnome-extra
```

* `gnome` → Core GNOME environment (Shell, Settings, Files, etc.)
* `gnome-extra` → Additional apps (GNOME Tweaks, Games, Photos, etc.)

Enable GDM if you prefer GNOME’s display manager:

```bash
systemctl enable gdm
```

> **Wayland vs Xorg in GNOME**
>
> * GNOME defaults to **Wayland**.
> * On the login screen, click the gear icon to select **GNOME on Xorg** if you have issues (especially with NVIDIA).

---

## Install KDE Plasma

```bash
pacman -S plasma kde-applications
```

* `plasma` → KDE Plasma desktop
* `kde-applications` → KDE’s suite of apps (Dolphin file manager, Konsole terminal, Kdenlive video editor, etc.)

Enable SDDM:

```bash
systemctl enable sddm
```

---

## Wayland vs Xorg in KDE Plasma

KDE supports both **Wayland** and **Xorg** sessions.

* At the login screen (SDDM), click the **session menu** (usually a small icon or dropdown).
* Select either:

  * **Plasma (Wayland)** → modern, smoother, better for HiDPI, fractional scaling.
  * **Plasma (X11)** → fallback, generally safer with NVIDIA, some multi-monitor setups.

> **Switching sessions:**
>
> * If you experience screen tearing, crashes, or NVIDIA issues on Wayland, switch back to **Plasma (X11)** at login.
> * If Wayland works well, stick with it for better performance and modern features.

---

## NVIDIA Notes

* NVIDIA’s proprietary drivers work better with **Xorg**, though recent updates have improved Wayland.
* For stability with multiple monitors or heavy workloads (video editing, 3D, gaming), you may want to:

  * Use **Plasma (X11)** for KDE
  * Use **GNOME on Xorg** for GNOME

---

## Summary

You now have both **GNOME** and **KDE Plasma** installed. At boot:

1. Your display manager (SDDM or GDM) will appear.
2. Enter your username and password.
3. Before logging in, click the **gear/session menu** and choose:

   * **GNOME / GNOME on Xorg**
   * **Plasma (Wayland) / Plasma (X11)**

This allows you to test both environments and both session protocols (Wayland vs Xorg) depending on your hardware and workflow needs.

---

| Environment | Default | Alternatives     | Best for                                               |
| ----------- | ------- | ---------------- | ------------------------------------------------------ |
| GNOME       | Wayland | GNOME on Xorg    | Simplicity, modern UI, productivity                    |
| KDE Plasma  | Xorg    | Plasma (Wayland) | Customisation, multi-monitor setups, editing workflows |
