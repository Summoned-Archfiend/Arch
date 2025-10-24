# Root (where pacman updates land)
sudo btrfs subvolume snapshot -r / /.snapshots/root-preupdate-$(date +%Y%m%d-%H%M)

# Optional: /var (service state, pkg cache, DBs, logs, etc.)
sudo btrfs subvolume snapshot -r /var /.snapshots/var-preupdate-$(date +%Y%m%d-%H%M)

# Optional: /home (usually skip for routine system updates)
# sudo btrfs subvolume snapshot -r /home /.snapshots/home-preupdate-$(date +%Y%m%d-%H%M)
