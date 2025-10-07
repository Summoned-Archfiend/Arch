# 🧭 Arch Linux Btrfs Snapshot Restoration Tutorial

This guide explains exactly how to restore your Arch Linux system from a Btrfs snapshot. It assumes you use the common layout with `@` for root, `@home` for your home directory, and `@snapshots` for backups.

---

## ⚙️ Prerequisites

Before restoring, ensure:

* You have an **existing Btrfs snapshot** inside your `@snapshots` subvolume.
* You have an **Arch Live USB** or other Linux rescue ISO available.

---

## 🧩 Step 1: Boot into a Live Environment

1. Insert your **Arch Linux Live USB**.
2. Boot into it and open a terminal.
3. Switch to root if necessary:

   ```bash
   sudo -i
   ```

---

## 🧭 Step 2: Identify Your Root Partition

List all available partitions:

```bash
lsblk -f
```

Find the partition that contains your Btrfs filesystem (commonly `/dev/nvme0n1p3` or `/dev/sda2`).

---

## 📂 Step 3: Mount the Top-Level Btrfs Volume

Mount the **top-level** subvolume (subvolid=5) so you can access all subvolumes:

```bash
mount -o subvolid=5 /dev/nvme0n1p3 /mnt
```

Confirm your subvolumes exist:

```bash
ls /mnt
```

You should see something like:

```
@  @home  @snapshots  @var
```

---

## 🔄 Step 4: Rename the Broken System

If your root system (`@`) is broken, rename it so it’s preserved for later analysis:

```bash
mv /mnt/@ /mnt/@_broken_$(date +%F_%H%M)
```

(Optional) You can delete it later once your system is restored:

```bash
btrfs subvolume delete /mnt/@_broken_YYYY-MM-DD_HHMM
```

---

## 💾 Step 5: Restore the Snapshot

List available snapshots:

```bash
btrfs subvolume list /mnt
```

Pick the one you want to restore (for example, `@snapshots/initial_root_backup`).

Create a new writable snapshot from it to become your new root:

```bash
btrfs subvolume snapshot /mnt/@snapshots/initial_root_backup /mnt/@
```

If you also want to restore `/home`:

```bash
mv /mnt/@home /mnt/@home_old_$(date +%F_%H%M)

btrfs subvolume snapshot /mnt/@snapshots/initial_home_backup /mnt/@home
```

---

## 🧹 Step 6: Verify and Unmount

Check that the new root exists:

```bash
ls /mnt/@
```

Unmount the filesystem cleanly:

```bash
umount /mnt
```

---

## 🚀 Step 7: Reboot

Simply reboot into your restored system:

```bash
reboot
```

Your system will now boot from the restored snapshot.

---

## 🧰 Optional: Post-Restore Cleanup

Once you confirm the restored system works:

```bash
mount -o subvolid=5 /dev/nvme0n1p3 /mnt
btrfs subvolume delete /mnt/@_broken_YYYY-MM-DD_HHMM
umount /mnt
```

---

## ✅ Summary

| Step | Action                                  |
| ---- | --------------------------------------- |
| 1    | Boot from Live USB                      |
| 2    | Identify root partition with `lsblk -f` |
| 3    | Mount top-level subvol (`subvolid=5`)   |
| 4    | Rename broken `@` subvolume             |
| 5    | Snapshot restore your chosen backup     |
| 6    | Unmount and reboot                      |

---

## 💭 Stoic Reminder

> “Calmness is mastery. Preparation removes fear.”
> — Adapted from Seneca

Restoring a snapshot isn’t panic — it’s procedure.
Follow this guide, act with composure, and your Arch system will always return to order.
