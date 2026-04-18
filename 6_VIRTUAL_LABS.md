# Secure Virtual Machine Lab Setup on Arch Linux

## 1. What We Are Building

Goal: create a safe environment to run hacking labs or malware samples without risking the host system.

Key components:

* **KVM** – hardware virtualization built into the Linux kernel
* **QEMU** – emulator that actually runs virtual machines
* **libvirt** – service that manages virtual machines
* **virt-manager** – graphical interface to control VMs

Think of the layers like this:

Host OS → KVM → QEMU VM → Guest OS

Each VM behaves like a completely separate computer.

---

## 2. Check Hardware Virtualization

First confirm your CPU supports virtualization.

Run:

```
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

If nothing appears, virtualization may be disabled in BIOS/UEFI.

Question to consider: *Why would hardware virtualization be safer than pure software emulation?*

---

## 3. Check If Virtualization Tools Are Already Installed

Check installed packages:

```
pacman -Qs qemu
pacman -Qs libvirt
pacman -Qs virt-manager
```

If nothing is returned, they are not installed.

Also check whether the libvirt service exists:

```
systemctl status libvirtd
```

---

## 4. Install the Virtualization Stack

Install required packages:

```
sudo pacman -S qemu-full libvirt virt-manager dnsmasq bridge-utils
```

Purpose of each:

* **qemu-full** – virtualization engine
* **libvirt** – manages VMs and networking
* **virt-manager** – GUI to create and manage VMs
* **dnsmasq** – VM network services
* **bridge-utils** – networking tools

---

## 5. Enable the Virtualization Service

Start the service:

```
sudo systemctl enable --now libvirtd
```

Confirm it is running:

```
systemctl status libvirtd
```

---

## 6. Allow Your User to Manage Virtual Machines

Add your user to the libvirt group:

```
sudo usermod -aG libvirt $USER
```

Log out and back in for this change to apply.

Reflect: *Why would direct root access to virtualization tools be undesirable?*

---

## 7. Launch the Virtual Machine Manager

Start the GUI:

```
virt-manager
```

You should see a connection called:

```
QEMU/KVM
```

This indicates the virtualization stack is working.

---

## 8. Creating Your First Virtual Machine

Steps in virt-manager:

1. Click **Create New Virtual Machine**
2. Select **Local install media**
3. Choose an ISO file
4. Assign RAM and CPU
5. Create a disk image

Recommended starting values:

RAM: 4 GB
CPU: 2 cores
Disk: 40 GB (QCOW2 format)

---

## 9. Secure Networking for Lab Environments

By default libvirt uses **NAT networking**.

VM → Virtual router → Internet

For malware testing you should consider **isolated networks**.

To create one:

```
virsh net-edit default
```

Or create a new network inside virt-manager.

Concept question: *Why might unrestricted internet access be dangerous for malware experiments?*

---

## 10. Snapshots (Critical Safety Feature)

Before running suspicious software:

1. Shut down VM
2. Create snapshot

If the system becomes compromised:

```
Revert to snapshot
```

This returns the VM to a clean state.

---

## 11. Lab Workflow

Typical safe workflow:

1. Boot clean VM
2. Snapshot
3. Run experiment
4. Observe behaviour
5. Revert snapshot

This ensures the VM cannot persist changes.

---

## 12. What You Should Understand Now

You now have:

* hardware virtualization
* VM management
* isolated testing environment

But reflect on the architecture:

Host → Hypervisor → VM → Guest OS

Question: *Which layer must remain trusted for the entire system to stay secure?*
