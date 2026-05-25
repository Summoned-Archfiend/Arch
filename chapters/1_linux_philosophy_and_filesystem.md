# Linux Philosophy and Filesystem

Before we install anything, it's worth understanding how `Linux` thinks. If you've come from `Windows` or
`Mac`, the filesystem layout will feel alien at first. Once you understand the reasoning, navigating any
`Linux` distribution becomes far easier.

The `Linux` philosophy is rooted in three ideas: **simplicity**, **modularity**, and the notion that
**everything is a file**. Rather than one giant program doing everything, `Linux` favours many small,
single-purpose tools that can be combined. The filesystem reflects this: every file, device, and process
hangs off a single root directory `/`.

`Arch` keeps the filesystem lean and close to the
[Filesystem Hierarchy Standard (FHS)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html).
`Ubuntu` follows the same standard but tends to pre-populate more directories with utilities and defaults
out of the box. The structure itself is universal across `Unix`-like systems.

## Key Directories

| Directory | Purpose in Arch                                         | Notes vs. Ubuntu                                                |
| --------- | ------------------------------------------------------- | --------------------------------------------------------------- |
| `/`       | Root of the filesystem. Everything starts here.         | Same. The base of the entire tree.                              |
| `/bin`    | Essential binaries (ls, cp, mv) for all users.          | Often merged into `/usr/bin` on modern distros.                 |
| `/boot`   | Bootloader files, kernel, initramfs.                    | Ubuntu often ships with multiple kernels by default.            |
| `/dev`    | Device files (e.g. `/dev/sda` for disks).               | Same. Devices exposed as files.                                 |
| `/etc`    | System configuration files.                             | Ubuntu pre-populates more defaults here.                        |
| `/home`   | User home directories (e.g. `/home/<user>`).            | Same. Personal files and configs.                               |
| `/lib`    | Essential shared libraries.                             | Ubuntu symlinks some libs to `/usr/lib`.                        |
| `/mnt`    | Temporary mount point. Heavily used during install.     | Ubuntu also provides `/media` for auto-mounting external drives.|
| `/opt`    | Optional third-party software.                          | Often used for proprietary apps (e.g. Chrome).                  |
| `/proc`   | Virtual filesystem exposing kernel and process info.    | Same. View processes, memory, etc.                              |
| `/root`   | Home directory for the root user.                       | Same.                                                           |
| `/run`    | Runtime data (PID files, sockets).                      | Same.                                                           |
| `/sbin`   | System binaries (mount, shutdown).                      | May be merged into `/usr/sbin` on modern distros.               |
| `/srv`    | Data for services (web, FTP). Empty by default in Arch. | More commonly used on server setups like Ubuntu Server.         |
| `/sys`    | Virtual filesystem for devices and drivers.             | Managed by sysfs.                                               |
| `/tmp`    | Temporary files, cleared at reboot.                     | Ubuntu sometimes mounts this as tmpfs.                          |
| `/usr`    | User programs, libraries, documentation.                | Ubuntu preloads many more packages here.                        |
| `/var`    | Variable data (logs, caches, spool).                    | Ubuntu creates more logs and services by default.               |

## Why this matters

`Arch` keeps the filesystem minimal and lets you decide what goes in. `Ubuntu` pre-fills many of these
directories with tools and defaults to get you running quickly. Neither approach is wrong, they are just
different philosophies. With `Arch` you trade convenience for understanding, and that understanding pays
off the first time something breaks.

Keep this layout in mind as you progress through the install. Most of what we do later (partitioning,
mounting subvolumes, installing a bootloader) touches one or more of these directories directly.

| [← Previous](../README.md) | [Next →](./2_virtual_machine.md) |
|:--|--:|
