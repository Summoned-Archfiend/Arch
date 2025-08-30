# Linux Philosophy and Filesystem (Arch vs Ubuntu)

The **Linux philosophy** centres on simplicity, modularity, and the idea that *everything is a file*. Instead of one giant program doing everything, Linux uses many small, single-purpose tools that work together. The filesystem reflects this: it provides a **unified hierarchy** starting from the root directory `/`, where every file, device, and process can be accessed. Arch Linux, being minimalist, keeps the filesystem lean and close to the [Filesystem Hierarchy Standard (FHS)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html). Ubuntu follows the same standard but often adds more pre-configured directories and utilities for ease of use.

---

## Key Directories in Linux Filesystem

| Directory | Arch Linux Purpose                                      | Ubuntu/Unix Comparison                                                     |
| --------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| `/`       | Root of the filesystem; everything starts here.         | Same — the base of the entire tree.                                        |
| `/bin`    | Essential binaries (ls, cp, mv) for all users.          | Same, though some distros now merge into `/usr/bin`.                       |
| `/boot`   | Bootloader files, kernel, initramfs.                    | Same, but Ubuntu often includes multiple kernels by default.               |
| `/dev`    | Device files (e.g. `/dev/sda` for disks).               | Same — devices exposed as files.                                           |
| `/etc`    | System configuration files.                             | Same, but Ubuntu often pre-populates more defaults.                        |
| `/home`   | User directories (`/home/luke`).                        | Same — personal files and configs.                                         |
| `/lib`    | Essential shared libraries.                             | Ubuntu symlinks some libs to `/usr/lib`.                                   |
| `/mnt`    | Temporary mount point (used in Arch install).           | Same, but Ubuntu also provides `/media` for auto-mounting external drives. |
| `/opt`    | Optional third-party software.                          | Same — often used for proprietary apps (e.g. Chrome).                      |
| `/proc`   | Virtual FS exposing kernel/process info.                | Same — view processes, memory, etc.                                        |
| `/root`   | Home directory for the root user.                       | Same.                                                                      |
| `/run`    | Runtime data (PID files, sockets).                      | Same.                                                                      |
| `/sbin`   | System binaries (mount, shutdown).                      | Same; may be merged into `/usr/sbin` in modern distros.                    |
| `/srv`    | Data for services (web, FTP). Empty by default in Arch. | Often used more in server setups (e.g. Ubuntu Server).                     |
| `/sys`    | Virtual FS for devices and drivers.                     | Same — managed by sysfs.                                                   |
| `/tmp`    | Temporary files, cleared at reboot.                     | Same, Ubuntu sometimes mounts as tmpfs.                                    |
| `/usr`    | User programs, libraries, documentation.                | Same — Ubuntu preloads many more packages here.                            |
| `/var`    | Variable data (logs, caches, spool).                    | Same, but Ubuntu creates more logs/services by default.                    |

---

**Summary:** Arch keeps the filesystem minimal and lets you decide what goes in, while Ubuntu pre-fills many of these directories with tools and defaults to get you running quickly. The structure itself, however, is universal across Linux and Unix systems.
