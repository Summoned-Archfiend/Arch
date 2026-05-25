# Wiping Drives

If you are installing on real hardware, you almost certainly want to wipe the target drive before
partitioning. This chapter covers how to identify and wipe drives safely from inside the `Arch` ISO
environment.

This is destructive. All data on the selected drives will be irreversibly destroyed. Read each command
twice before pressing enter.

> **Note**
> If you are following along in a `VM` with an empty virtual disk, you can skip this chapter and move
> straight to [Installation](./4_installation.md). The disk is already empty.

## 1. Boot into the Arch ISO

Insert your USB medium and boot into the Arch ISO. You should arrive at a root shell.

Update the package databases (optional but good practice):

```bash
pacman -Sy
```

## 2. Identify Drives

List all block devices:

```bash
lsblk
```

Typical examples:

* `/dev/nvme0n1` is the main NVMe SSD
* `/dev/sda`, `/dev/sdb` are SATA SSDs or HDDs
* `/dev/sdc` is often the USB installer (do not wipe this)

Use `lsblk -o NAME,SIZE,TYPE,MOUNTPOINT` to confirm which drive is which. Sizes are usually the giveaway,
the USB installer will be much smaller than your install target.

## 3. Unmount Drives

If any partitions are mounted, unmount them:

```bash
umount -R /dev/sdX*
umount -R /dev/nvme0n1p*
```

Replace `sdX` / `nvme0n1` with the target device.

## 4. Wipe Filesystem Signatures

This removes existing filesystem and partition table signatures:

```bash
wipefs -a /dev/sdX
```

For NVMe drives:

```bash
wipefs -a /dev/nvme0n1
```

## 5. Optional: Full Zero-Fill

If you want to fully overwrite the drive (slower but more secure):

```bash
dd if=/dev/zero of=/dev/sdX bs=1M status=progress
```

This can take hours on large drives. Usually unnecessary unless security is a concern (you are
disposing of the drive, or it previously held sensitive data).

## 6. Create Fresh Partitions

Once wiped, create new partitions with `cfdisk` or `fdisk`:

```bash
cfdisk /dev/sdX
```

Recommended minimum layout:

* **EFI system partition** at 512M, type `EFI System`
* **Root** (`/`) taking the rest of the SSD (Btrfs, ext4, etc.)
* Optional **Home/Data** partitions on other drives

We will cover detailed partition sizing in the next chapter.

## 7. Format Partitions

Examples:

```bash
mkfs.fat -F32 /dev/sdX1       # EFI
mkfs.btrfs -L root /dev/sdX2  # Root
mkfs.btrfs -L home /dev/sdY1  # Home on second drive
```

## 8. Verify Clean Start

Recheck with:

```bash
lsblk -f
```

You should only see the new filesystems you just created.

## Notes

* **Do not wipe your USB installer drive.** Confirm with `lsblk` before wiping. The USB will usually be
  the smallest device and show a mountpoint.
* Wiping only needs to be done **once**. After this, you can focus on mounting and installing Arch.
* If using `Btrfs`, you can create subvolumes for `@`, `@home`, `@snapshots`, etc. after formatting.
  We do exactly this in the next chapter.

Take a moment before you press enter on a destructive command: *is this the correct drive?* The cost
of pausing is nothing. The cost of getting it wrong is everything on that disk.

| [← Previous](./2_virtual_machine.md) | [Next →](./4_installation.md) |
|:--|--:|
