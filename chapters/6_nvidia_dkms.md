# NVIDIA DKMS and Suspend / Wake Troubleshooting

This chapter records the steps required to ensure `NVIDIA` works correctly with multiple kernels and
that suspend / resume work reliably. If you don't have an `NVIDIA` GPU, you can skip ahead.

`DKMS` (Dynamic Kernel Module Support) rebuilds your `NVIDIA` driver module automatically whenever the
kernel is updated. Without it, every kernel upgrade leaves you with a broken display until you rebuild
manually.

---

## 1. System Update Procedure

`Arch` requires **full system upgrades**, not partial upgrades. Partial upgrades break dependencies
and are unsupported.

```bash
sudo pacman -Syu
```

If the kernel was updated, reinstall the mainline kernel headers:

```bash
sudo pacman -S linux linux-headers
```

---

## 2. Verify DKMS Built the NVIDIA Module

Check DKMS status:

```bash
dkms status
```

Expected output:

```
nvidia/xxx.xx, <kernel-version>, x86_64: installed
nvidia/xxx.xx, <kernel-version>-lts, x86_64: installed
```

If the main kernel is missing, rebuild:

```bash
sudo dkms autoinstall
```

---

## 3. Verify NVIDIA Kernel Modules Exist

Modules are compressed (`.ko.zst`).

Search for them:

```bash
find /usr/lib/modules -name "nvidia*.ko*"
```

Expected files:

```
nvidia.ko.zst
nvidia_modeset.ko.zst
nvidia_uvm.ko.zst
nvidia_drm.ko.zst
```

These should appear under each kernel directory:

```
/usr/lib/modules/<kernel-version>/updates/dkms/
```

---

## 4. Rebuild initramfs

Ensure `NVIDIA` modules are included in the initramfs.

```bash
sudo mkinitcpio -P
```

Verify:

```bash
lsinitcpio /boot/initramfs-linux.img | grep nvidia
```

---

## 5. Confirm Kernel Images Exist

```bash
ls /boot
```

Expected:

```
vmlinuz-linux
vmlinuz-linux-lts
initramfs-linux.img
initramfs-linux-lts.img
```

---

## 6. Enable NVIDIA DRM Modesetting

This improves display initialization and suspend reliability.

Check current state:

```bash
cat /sys/module/nvidia_drm/parameters/modeset
```

Expected output:

```
Y
```

If not enabled, add the kernel parameter:

```
nvidia_drm.modeset=1
```

Add it to the bootloader configuration.

---

## 7. Enable NVIDIA Suspend / Resume Hooks

These systemd services save and restore GPU state.

Check status:

```bash
systemctl status nvidia-suspend.service
systemctl status nvidia-resume.service
systemctl status nvidia-hibernate.service
```

Enable them if needed:

```bash
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-resume.service
sudo systemctl enable nvidia-hibernate.service
```

---

## 8. Fix USB Devices Not Returning After Sleep

Some systems fail to reinitialize USB devices after suspend.

Check autosuspend:

```bash
cat /sys/module/usbcore/parameters/autosuspend
```

Disable autosuspend permanently via the kernel parameter:

```
usbcore.autosuspend=-1
```

---

## 9. Fix Display / USB Failures After Resume

If both keyboard and monitor fail after wake, disable aggressive PCIe power management.

Add the kernel parameter:

```
pcie_aspm=off
```

---

## 10. Debugging Failed Resume

If the system wakes but the display does not work, SSH into the machine and inspect the logs (see the
[SSH Agent Setup](./9_ssh_agent_setup.md) chapter for remote access).

```bash
journalctl -b | grep resume
journalctl -b | grep nvidia
journalctl -b | grep usb
```

If the system rebooted, inspect the previous boot:

```bash
journalctl -b -1
```

---

## 11. SSH Access for Headless Recovery

Ensure SSH runs at boot:

```bash
sudo systemctl enable sshd
```

Connect via hostname (using mDNS):

```bash
ssh username@hostname.local
```

Replace `username` and `hostname` with your own login name and the
machine's hostname (`hostnamectl` will tell you both).

---

## 12. Quick Pre-Reboot Sanity Checklist

Before rebooting after updates:

```bash
uname -r
dkms status
pacman -Qs nvidia
ls /usr/lib/modules
```

Confirm:

* kernel installed
* dkms module built
* modules exist
* initramfs generated

If all checks pass, reboot should be safe.

| [← Previous](./5_desktop_environment.md) | [Next →](./7_snapshots_and_restore.md) |
|:--|--:|
