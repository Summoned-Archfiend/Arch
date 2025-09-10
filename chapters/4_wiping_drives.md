Here’s a clean, step-by-step **Markdown guide** you can keep alongside your Arch notes. It focuses only on **wiping drives safely** during Arch installation.

---

# 🔥 Wiping Drives in Arch Linux Installer

This guide explains how to identify and wipe drives before partitioning in the Arch Linux installation environment. Use with caution — all data on the selected drives will be **irreversibly destroyed**.

---

## 1. Boot into the Arch ISO

Insert your USB medium and boot into the Arch ISO. You should arrive at a root shell.

Update package databases (optional but good practice):

```bash
pacman -Sy
```

---

## 2. Identify Drives

List all block devices:

```bash
lsblk
```

Typical examples:

* `/dev/nvme0n1` → Main NVMe SSD
* `/dev/sda`, `/dev/sdb` → SATA SSDs or HDDs
* `/dev/sdc` → USB installer (⚠️ **do not wipe this**)

Use `lsblk -o NAME,SIZE,TYPE,MOUNTPOINT` to confirm which drive is which.

---

## 3. Unmount Drives

If any partitions are mounted, unmount them:

```bash
umount -R /dev/sdX*
umount -R /dev/nvme0n1p*
```

Replace `sdX` / `nvme0n1` with the target device.

---

## 4. Wipe Filesystem Signatures

This removes existing filesystem and partition table signatures:

```bash
wipefs -a /dev/sdX
```

For NVMe drives:

```bash
wipefs -a /dev/nvme0n1
```

---

## 5. Optional: Full Zero-Fill (Secure Wipe)

If you want to fully overwrite the drive (slower but more secure):

```bash
dd if=/dev/zero of=/dev/sdX bs=1M status=progress
```

⚠️ This can take hours on large drives. Usually unnecessary unless security is a concern.

---

## 6. Create Fresh Partitions

Once wiped, create new partitions with `cfdisk` or `fdisk`:

```bash
cfdisk /dev/sdX
```

Recommended minimum layout:

* **EFI system partition** → 512M, type `EFI System`
* **Root** (`/`) → rest of the SSD (Btrfs, ext4, etc.)
* **Optional Home/Data partitions** on other drives

---

## 7. Format Partitions

Examples:

```bash
mkfs.fat -F32 /dev/sdX1       # EFI
mkfs.btrfs -L root /dev/sdX2  # Root
mkfs.btrfs -L home /dev/sdY1  # Home on second drive
```

---

## 8. Verify Clean Start

Recheck with:

```bash
lsblk -f
```

You should only see the new filesystems you just created.

---

## Notes

* **Do not wipe your USB installer drive.** Confirm with `lsblk` before wiping.
* Wiping only needs to be done **once** — after this, you can focus on mounting and installing Arch.
* If using Btrfs, you can create subvolumes for `@`, `@home`, `@snapshots`, etc. after formatting.

---

⚖️ *Reminder:* Wiping is destructive. Take a moment before you press enter: *“Is this the correct drive?”* A Stoic accepts consequences calmly, but a wise Stoic avoids unnecessary mistakes.

---

Would you like me to extend this into a **full Arch install guide** with Btrfs subvolumes (root, home, snapshots) and EFI setup, so you can go from wiped drive straight into a working Arch in one pass?
