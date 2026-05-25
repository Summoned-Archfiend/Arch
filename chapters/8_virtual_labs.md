# Virtual Labs (KVM / QEMU)

This chapter is optional. If you want to run hacking labs, malware samples, or just disposable VMs on
your `Arch` host without risking the host system, this is how to set up a proper KVM-backed virtual
lab environment.

`VirtualBox` is fine for casual use, but `KVM` is hardware-accelerated through the kernel itself and
performs noticeably better, especially for running multiple VMs at once. It's also the standard tool
across most Linux security and infrastructure work.

## What We Are Building

Goal: create a safe environment to run hacking labs or malware samples without risking the host.

Key components:

* **KVM** is the hardware virtualization built into the Linux kernel.
* **QEMU** is the emulator that actually runs the virtual machines.
* **libvirt** is the service that manages those virtual machines.
* **virt-manager** is the graphical interface to control VMs.

The layers look like this:

```
Host OS -> KVM -> QEMU VM -> Guest OS
```

Each VM behaves like a completely separate computer.

---

## 1. Check Hardware Virtualization

First confirm your CPU supports virtualization.

Run:

```bash
lscpu | grep Virtualization
```

Expected result:

```
Virtualization: VT-x
```

or

```
Virtualization: AMD-V
```

If nothing appears, virtualization may be disabled in BIOS / UEFI. Enable it there and reboot.

Hardware virtualization is safer and faster than pure software emulation because the CPU performs
isolation directly rather than relying on a software layer.

---

## 2. Check If Virtualization Tools Are Already Installed

Check installed packages:

```bash
pacman -Qs qemu
pacman -Qs libvirt
pacman -Qs virt-manager
```

If nothing is returned, they are not installed.

Also check whether the libvirt service exists:

```bash
systemctl status libvirtd
```

---

## 3. Install the Virtualization Stack

Install the required packages:

```bash
sudo pacman -S qemu-full libvirt virt-manager dnsmasq bridge-utils
```

Purpose of each:

* **qemu-full** is the virtualization engine.
* **libvirt** manages VMs and networking.
* **virt-manager** is the GUI to create and manage VMs.
* **dnsmasq** provides VM network services.
* **bridge-utils** provides networking tools.

---

## 4. Enable the Virtualization Service

Start the service:

```bash
sudo systemctl enable --now libvirtd
```

Confirm it is running:

```bash
systemctl status libvirtd
```

---

## 5. Allow Your User to Manage Virtual Machines

Add your user to the libvirt group:

```bash
sudo usermod -aG libvirt $USER
```

Log out and back in for this change to apply.

Doing this means you don't need to `sudo` every libvirt operation. Running everything as root
unnecessarily widens the blast radius if a tool ever does something it shouldn't.

---

## 6. Launch the Virtual Machine Manager

Start the GUI:

```bash
virt-manager
```

You should see a connection called:

```
QEMU/KVM
```

This indicates the virtualization stack is working.

---

## 7. Creating Your First Virtual Machine

Steps in virt-manager:

1. Click **Create New Virtual Machine**.
2. Select **Local install media**.
3. Choose an ISO file.
4. Assign RAM and CPU.
5. Create a disk image.

Recommended starting values:

* RAM: 4 GB
* CPU: 2 cores
* Disk: 40 GB (QCOW2 format)

---

## 8. Secure Networking for Lab Environments

By default libvirt uses **NAT networking**:

```
VM -> Virtual router -> Internet
```

For malware testing you should consider **isolated networks** so a sample cannot phone home or
exfiltrate data.

To edit the default network:

```bash
virsh net-edit default
```

Or create a new network inside `virt-manager`. An isolated network has no outbound route, which is
exactly what you want when you don't trust what's running inside the guest.

---

## 9. Snapshots

Before running suspicious software:

1. Shut down the VM.
2. Create a snapshot.

If the system becomes compromised, revert to the snapshot and the VM returns to a clean state. This
is the single most important habit for lab work.

---

## 10. Lab Workflow

A typical safe workflow:

1. Boot clean VM.
2. Snapshot.
3. Run the experiment.
4. Observe behaviour.
5. Revert the snapshot.

This ensures the VM cannot persist changes between runs.

---

## 11. What You Now Have

You now have:

* hardware virtualization
* VM management via libvirt
* an isolated testing environment

The architecture remains:

```
Host -> Hypervisor -> VM -> Guest OS
```

The host (and the hypervisor running on it) must remain trusted for the entire system to stay secure.
If your host is compromised, no amount of VM isolation will save you. Keep the host updated, minimal,
and well-snapshotted.

| [← Previous](./7_snapshots_and_restore.md) | [Next →](./9_ssh_agent_setup.md) |
|:--|--:|
