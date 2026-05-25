# Snapshots and Restore

If you followed the installation chapter you already have a `Btrfs` filesystem with `@`, `@home`, and
`@snapshots` subvolumes. This chapter shows you how to actually use them: taking snapshots before
risky operations, and restoring from one when something goes wrong.

A snapshot is a near-instant, copy-on-write picture of a subvolume at a point in time. Taking one
costs almost nothing in disk space. Restoring from one takes minutes and beats reinstalling from
scratch every time.

---

## Taking Snapshots

The most useful habit is snapshotting before running `pacman -Syu`. Updates rarely break things, but
when they do you want a clean rollback path.

```bash
# Root (where pacman updates land)
sudo btrfs subvolume snapshot -r / /.snapshots/root-preupdate-$(date +%Y%m%d-%H%M)

# Optional: /var (service state, package cache, databases, logs)
sudo btrfs subvolume snapshot -r /var /.snapshots/var-preupdate-$(date +%Y%m%d-%H%M)

# Optional: /home (usually skip for routine system updates)
# sudo btrfs subvolume snapshot -r /home /.snapshots/home-preupdate-$(date +%Y%m%d-%H%M)
```

The `-r` flag makes the snapshot read-only. The timestamp suffix means you'll always know which
snapshot came from which update window.

> **Tip**
> Consider automating this with [Snapper](https://wiki.archlinux.org/title/Snapper) and
> [grub-btrfs](https://wiki.archlinux.org/title/GRUB-btrfs) once you're comfortable. The Study Guide
> covers this in more depth.

---

## Restoring from a Snapshot

If something has broken your install (a bad update, a broken kernel module, a misconfiguration you
can't easily undo), the following procedure rolls your system back. This assumes the standard layout
with `@` for root, `@home` for your home directory, and `@snapshots` for backups.

### Prerequisites

* An **existing Btrfs snapshot** inside your `@snapshots` subvolume.
* An **Arch Live USB** or other Linux rescue ISO available.

---

### Step 1: Boot into a Live Environment

1. Insert your Arch Linux Live USB.
2. Boot into it and open a terminal.
3. Switch to root if necessary:

   ```bash
   sudo -i
   ```

---

### Step 2: Identify Your Root Partition

List all available partitions:

```bash
lsblk -f
```

Find the partition that contains your `Btrfs` filesystem (commonly `/dev/nvme0n1p3` or `/dev/sda2`).

---

### Step 3: Mount the Top-Level Btrfs Volume

Mount the **top-level** subvolume (`subvolid=5`) so you can access all subvolumes:

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

### Step 4: Rename the Broken System

If your root system (`@`) is broken, rename it so it's preserved for later analysis:

```bash
mv /mnt/@ /mnt/@_broken_$(date +%F_%H%M)
```

You can delete it later once your system is restored:

```bash
btrfs subvolume delete /mnt/@_broken_YYYY-MM-DD_HHMM
```

---

### Step 5: Restore the Snapshot

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

### Step 6: Verify and Unmount

Check that the new root exists:

```bash
ls /mnt/@
```

Unmount the filesystem cleanly:

```bash
umount /mnt
```

---

### Step 7: Reboot

```bash
reboot
```

Your system will now boot from the restored snapshot.

---

## Optional: Post-Restore Cleanup

Once you confirm the restored system works, you can drop the broken subvolume:

```bash
mount -o subvolid=5 /dev/nvme0n1p3 /mnt
btrfs subvolume delete /mnt/@_broken_YYYY-MM-DD_HHMM
umount /mnt
```

---

## Summary

| Step | Action                                  |
| ---- | --------------------------------------- |
| 1    | Boot from Live USB                      |
| 2    | Identify root partition with `lsblk -f` |
| 3    | Mount top-level subvol (`subvolid=5`)   |
| 4    | Rename broken `@` subvolume             |
| 5    | Snapshot restore your chosen backup     |
| 6    | Unmount and reboot                      |

Restoring a snapshot isn't panic, it's procedure. If you have a recent snapshot, you almost certainly
have a way out. Take them often.

| [← Previous](./6_nvidia_dkms.md) | [Next →](./8_virtual_labs.md) |
|:--|--:|
