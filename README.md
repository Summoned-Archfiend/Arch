# Arch Linux

So, you researched some alternative OS and came across `Arch`. Whilst there may be a bit of a learning
curve, have no fear, it isn't nearly as difficult as people make it out to be. Before you make the decision
to permanently switch your `OS`, here's what to expect.

## Why should I use Arch?

`Arch` provides a `DIY` operating system. Out of the box you get nothing but the absolute basics. It is then
up to you to `configure` and `install` everything. What this gives you is an `OS` specifically tailored to
your needs and your needs alone. You can have it as secure (or insecure) as you like, you can switch
`kernels`, have multiple `desktop environments` to switch between, and do everything you can do on any
other `OS`.

I will pre-warn, if you want to use this for gaming, I personally would not recommend it. Whilst you can
indeed get it working with an `NVIDIA` GPU it is a hassle, the third party switching tools don't get updated
often, `NVIDIA` are often behind the curve with updates rolled out by `Arch` on their rolling release model.
Overall, you end up gaming less and less because you are busy fixing your GPU drivers. `Arch` also has some
optimisation issues. Whilst you can run `Linux` compatible games and use `wine` to run windows programs,
there is a cost, and the cost is ease-of-use with other technologies (KVMs, multiple monitor setups,
wireless controllers etc.). There can also be imaging issues (flickering etc.) with some monitors, along
with a performance drop from `Windows` gaming if you are playing online multiplayer games where `FPS` and
smoothness are critical.

So, what can you do instead? If you only care for casual gaming, or none at all, and just want a daily
driver, then `Arch` is a great choice. I personally love the control `Arch` gives me, but also the amount
I get to learn by using `Arch`. If you didn't understand how your `OS` and `kernel` interact fully before,
spend a bit of time with `Arch` and you will soon understand more about `UNIX` systems than ever before.

## Recommendations

I know, you are probably eager to dive in. First though, if you have never installed `Arch` before do
yourself a favour and practice in a `Virtual machine` first. I know, this means you'll have to do it twice
or more, but the more practice you get the better you'll understand what you are doing exactly. In this
guide I will provide details on setting up a virtual environment to work in, don't worry it's all free.

By first setting up `Arch` in a `VM` you will learn the basics, and if you mess up it is far less of a
concern than it is on your live system. Whether you are going to be partitioning a dual-boot on your
existing drive, or simply installing it from scratch as your main `OS`, I'd recommend some practice first.

I'm not going to hold your hand too much. I will fill in the blanks where some of the docs are a bit hazy
for first-timers, but I presume you are a competent `Windows` or `Mac` user who understands basic `IT`
functions and terms such as installing programs. If not, then you are going to have a bad time with `Arch`
and I suggest you learn the basics via an `OS` like `Windows` or `Ubuntu` first.

> **Note**
> Your PC must be set up to enable Hardware Virtualization in the BIOS before you can attempt to follow
> this guide.

## Contents

1. [Linux Philosophy and Filesystem](./chapters/1_linux_philosophy_and_filesystem.md)
2. [Setting Up Your Virtual Machine](./chapters/2_virtual_machine.md)
3. [Wiping Drives](./chapters/3_wiping_drives.md)
4. [Installation](./chapters/4_installation.md)
5. [Desktop Environment](./chapters/5_desktop_environment.md)
6. [NVIDIA DKMS and Suspend Troubleshooting](./chapters/6_nvidia_dkms.md)
7. [Snapshots and Restore](./chapters/7_snapshots_and_restore.md)
8. [Virtual Labs](./chapters/8_virtual_labs.md)
9. [SSH Agent Setup](./chapters/9_ssh_agent_setup.md)
10. [Wacom Cintiq and Multi-Display Configuration](./chapters/10_wacom_and_display.md)
11. [Hardening Your Arch System](./chapters/11_hardening.md)
12. [Programming an Arduino from VSCode](./chapters/12_arduino.md)
13. [Disabling Android System SafetyCore from Arch](./chapters/13_safetycore.md)

See also: [Study Guide](./STUDY_GUIDE.md) for a wider learning roadmap, and
the [scripts](./scripts) folder for helper scripts referenced by the chapters.

## Resources

- [Arch Documentation](https://archlinux.org/)
- [Arch Wiki](https://wiki.archlinux.org/)
- [VirtualBox](https://www.virtualbox.org/)

| [Next →](./chapters/1_linux_philosophy_and_filesystem.md) |
|:--|
