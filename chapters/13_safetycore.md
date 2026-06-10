# Disabling Android System SafetyCore from Arch

This chapter is a slight detour from configuring `Arch` itself. Your `Arch`
box is the tool, not the target. The target is the Android phone in your
pocket, and the job is removing a Google system service called **Android
System SafetyCore** that very likely turned up on your device without you
ever asking for it. The reason it lives in this repo is that the cleanest,
most trustworthy way to deal with it is over `adb` from a Linux machine,
and you already have one of those now.

This is not a piece of original research. The method circulated through
the Libreware community and elsewhere; I have tested it on my own device,
fact-checked the scarier claims, and rewritten it for `Arch` so you are
not pasting Windows `.\adb` incantations or downloading a zip from Google
when `pacman` already ships the tool. I have also tried to be honest about
what `SafetyCore` actually does, because the version of this guide doing
the rounds is heavy on alarm and light on accuracy.

---

## 1. What SafetyCore Actually Is

The hyperbolic take is "Google silently installed a thing that scans all
your photos and phones them home". That is not quite right, and getting it
wrong makes it easy to dismiss the parts that *are* a problem.

Here is the accurate version:

- **`SafetyCore` is an on-device classification toolkit, not a scanner that
  runs on its own.** It provides machine-learning models that *other* apps
  can call when they want to classify a piece of content, for example "is
  there nudity in this image". It does not crawl your gallery, it does not
  pre-scan your photos, and it is not running in the background 24/7. It
  activates only when a compatible app makes a request to it.
- **It runs locally and, per Google, does not send content off the device.**
  Independent write-ups (Kaspersky, gHacks) corroborate that the
  classification happens on-device and that `SafetyCore` is not reporting
  scanned content back to Google. It does, however, see content in
  decrypted form at the moment an app hands it something to classify, which
  is why it makes privacy-minded people twitchy.
- **The first real consumer is "Sensitive Content Warnings" in Google
  Messages** (introduced late 2024). With it on, an incoming image flagged
  as explicit gets blurred behind a tap-to-view warning, and sending one
  prompts a confirmation. That feature is opt-in. `SafetyCore` is the engine
  behind it.

So what is the actual objection? Three things, and they are all legitimate:

1. **Consent.** It arrives silently through a Google Play system update or
   OEM firmware push and simply appears as a system app you never installed.
   No prompt, no explanation, no choice.
2. **Trajectory.** An on-device content-classification engine that any app
   can query, installed without consent, is exactly the kind of capability
   whose scope creeps. Today it powers an opt-in blur in one messaging app.
   The mechanism does not care what it is pointed at next.
3. **Encryption, and the legal direction of travel.** At the moment an app
   hands `SafetyCore` something to classify, it sees that content in the
   clear. Nothing leaves the device today, but it is worth being precise
   about why that still matters. End-to-end encryption exists so that nobody
   but the sender and recipient can inspect a message; placing a
   classification engine on the endpoint does not *break* the encryption, it
   sidesteps the guarantee the encryption was meant to provide. This is the
   exact risk set out in the 2021 paper *Bugs in Our Pockets* (Abelson,
   Anderson, Schneier, et al.): client-side scanning leaves the cryptography
   intact while reintroducing the third-party inspection that cryptography
   was designed to prevent.

   What turns this from an abstract worry into a concrete one is the
   direction of UK law. The Online Safety Act 2023 (sections 121-122) already
   lets `Ofcom` compel a messaging provider to deploy "accredited technology"
   that scans content, including inside end-to-end-encrypted services, for
   illegal material. No such technology has been certified yet and the final
   guidance is still being settled, so this is being decided now rather than
   closed. Separately, under the Investigatory Powers Act 2016 the government
   served Apple a Technical Capability Notice over its encrypted iCloud
   backups; rather than build the access demanded, Apple withdrew Advanced
   Data Protection from UK users in 2025, and the tribunal let the order
   stand. The powers to compel scanning of private content exist, and they
   have already been used.

   Put those facts together and the concern is not hypothetical machinery, it
   is machinery that is already in place. The hardest part of any on-device
   surveillance scheme, getting a content classifier onto every phone, is
   already done. Turning a local classifier that reports to nobody into one
   that flags and forwards what it finds would not require a new app, a
   prompt, or anything you would see; it would require a policy change and a
   legal order, both of which the UK is actively building the framework for.
   That is the dangerous ground: not what `SafetyCore` does today, but how
   little would have to change for it to do something else, and how invisible
   that change would be.

> **Note**
> If you run `MicroG` or `GrapheneOS` and assumed you were exempt, reports
> say otherwise. People on de-Googled and hardened setups have found it
> too. Worth checking even if you think you are clean.

One myth worth killing while we are here: the viral posts claim `SafetyCore`
"uses up to `2GB` of RAM". It does not. That figure is the minimum device RAM
a phone must *have* to be eligible for the install, not the amount the service
consumes. The `APK` is on the order of `44MB`, and because it does nothing
until an app calls it, it has no persistent memory or background footprint to
speak of. Repeating the `2GB` figure is exactly the kind of easily-falsified
detail that lets the accurate objections get waved away as paranoia.

If, having read that, you are comfortable with an opt-in feature backed by
an on-device model, you can stop here and do nothing. The rest of this
chapter is for people who object to software they did not consent to
installing, on principle, and want it gone.

---

## 2. Why These Steps, and Why They Are Safe

There are three escalating levels of "make it go away", and the right one
depends on whether you have root.

| Approach | Needs root | Survives reboot | Survives Play update | Reversible |
|---|---|---|---|---|
| `pm disable-user` over `adb` | No | Yes | Usually | Yes (`pm enable`) |
| `pm disable` in `Termux` (`su`) | Yes | Yes | Yes | Yes |
| Signature-mismatch placeholder app | No | Yes | Yes | Yes (uninstall it) |

A few points on why none of this is dangerous:

- **`pm disable-user --user 0` is non-destructive and fully reversible.** It
  flips the app to a disabled state for your primary user; it does not
  delete anything, touch `/system`, or modify the bootloader. If something
  you use turns out to depend on it, one `pm enable` command brings it back.
  This is the same mechanism Android's own settings use to disable a system
  app, just reachable without the per-app UI that Google sometimes hides.
- **Uninstalling alone does not work**, which is the genuinely annoying
  part. `adb shell pm uninstall` (or the Play Store) removes it, and a later
  Play system update quietly reinstalls it. That is why the durable fixes
  *disable* rather than *delete*.
- **The placeholder app is the most permanent fix, and it is auditable.** It
  is open source ([daboynb/Safetycore-placeholder](https://github.com/daboynb/Safetycore-placeholder)),
  the release `APK` is roughly `35KB`, declares no sensitive permissions, and
  carries no application code of its own. It works by installing an app that
  claims the same package name,
  `com.google.android.safetycore`, but is signed with a different key. When
  Google's updater tries to push the real `SafetyCore` over the top, the
  signature does not match and the install is **rejected by Android itself**.
  No root, no running service, nothing clever, just Android's own package
  manager refusing to replace one signer's app with another's. The latest
  release also sets an absurdly high `versionCode` so app stores consider it
  already up to date.

**Proving it to yourself rather than trusting me.** Installing any third-party
`APK` that impersonates a Google package name deserves scepticism. That is
exactly the right instinct, so here is how to verify it instead of taking
it on faith. Because the project is open source and the artifact is tiny,
you can confirm what it is before you trust it, and you have `Arch` and
`android-tools` right here to do it:

```bash
# Inspect the placeholder APK before installing it. aapt2 and apksigner ship
# in android-sdk-build-tools (AUR). aapt2 is a native binary; apksigner is a
# Java wrapper, so it also needs a JRE (sudo pacman -S jre-openjdk).
aapt2 dump permissions Safetycore-placeholder.apk   # one AndroidX self-permission, no sensitive ones
aapt2 dump badging Safetycore-placeholder.apk | grep -E 'package|sdkVersion|launchable'

# Print the signing certificate. You want a self-signed key that is NOT the
# public debug key (CN=Android Debug), so forged updates cannot match it.
apksigner verify --print-certs Safetycore-placeholder.apk
```

Read that output carefully, because "no permissions at all" is a myth. A
modern AndroidX build always injects one **self-scoped** permission named
`<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. That is harmless
boilerplate guarding the app's own broadcast receivers, not a request for
any of your data. What matters is that you see **none of the dangerous
ones**: no `INTERNET`, storage, camera, SMS, or location. You should also
see a `package` of `com.google.android.safetycore`, a `versionCode` up in
the billions, no launchable activity, and a self-signed certificate that is
plainly not Google's (and not the forgeable `CN=Android Debug` key).

The `APK` does ship a `classes.dex`, which can look alarming for something
billed as "empty", but it is only the AndroidX and Kotlin library glue every
build pulls in. With no launchable activity, no services, and no networking
or `exec`-style calls anywhere in it, nothing actually runs. That whole
combination, no sensitive permissions, no components, no app code, a real
non-debug signature, is the trick, and the reason it is safe: an inert shell
whose only job is to occupy the package name so the real thing cannot land.

> **Note**
> If you do not want to install a JRE just to read a certificate, the
> signing block is parseable without `apksigner`. The cert is an X.509 `DER`
> blob inside the v2/v3 APK Signing Block, and `python3` plus `openssl
> x509 -inform DER -noout -text` will print it. The native `aapt2` covers
> the permission and manifest side without Java at all.

---

## 3. Prerequisites on Arch

You do **not** need Google's "SDK Platform-Tools for Linux" zip. `Arch`
ships `adb` and `fastboot` in the official repos:

```bash
sudo pacman -S android-tools android-udev
```

- **`android-tools`:** the native `Arch` build of `adb`, `fastboot`, and
  friends. It updates through your normal `yay -Syu`, no manual unzipping.
- **`android-udev`:** the `udev` rules that let your user talk to the phone
  without `root`.

Add yourself to the `adbusers` group so `adb` can claim the device, then
re-log (or reboot) for the group to take effect:

```bash
sudo usermod -aG adbusers "$USER"
```

> **Note**
> If you need the *exact* build Google ships from their download page (a
> brand-new Android release occasionally lands before `android-tools`
> catches up), it is in the `AUR` as `android-sdk-platform-tools`. For this
> job the repo `android-tools` is more than enough. Do not install both,
> they both provide `adb`.

---

## 4. Non-Root Method (adb over USB)

This is the path for a normal, unrooted phone. It survives reboots and, in
most cases, survives Play updates too.

1. **Enable USB debugging.** On the phone: `Settings > About phone`, tap
   *Build number* seven times to unlock `Developer options`, then
   `Settings > System > Developer options > USB debugging`.
2. **Plug the phone into your `Arch` box** with a data-capable USB cable.
3. **Authorise the connection.** Confirm the device is seen and that the
   RSA-key prompt on the phone has been accepted:

   ```bash
   adb devices
   ```

   You want a line ending in `device`. If it says `unauthorized`, unlock the
   phone and tap *Allow* on the debugging prompt. If it says `no
   permissions`, your `adbusers` group membership has not taken effect yet,
   so re-log.

4. **Disable `SafetyCore` for your primary user:**

   ```bash
   adb shell pm disable-user --user 0 com.google.android.safetycore
   ```

   Success looks like `Package com.google.android.safetycore new state:
   disabled-user`.

5. **Confirm it is disabled:**

   ```bash
   adb shell pm list packages -d | grep safetycore
   ```

   If it shows up in the disabled (`-d`) list, you are done.

**To reverse it** at any time:

```bash
adb shell pm enable com.google.android.safetycore
```

---

## 5. Root Method (Termux)

If your phone is rooted you can do it on-device, no PC required.

1. Install [`Termux`](https://termux.dev/) (use the F-Droid or GitHub build,
   not the abandoned Play Store one).
2. Grant `Termux` root when prompted and run:

   ```bash
   su -c 'pm disable com.google.android.safetycore'
   ```

Reverse it with `su -c 'pm enable com.google.android.safetycore'`.

---

## 6. The Permanent Fix (Placeholder App)

`disable-user` is enough for most people, but if Play keeps trying to bring
`SafetyCore` back, or you are on a setup where you want it gone for good,
the placeholder closes the door:

1. **Uninstall the real `SafetyCore`**, either from the Play Store listing
   or with:

   ```bash
   adb shell pm uninstall --user 0 com.google.android.safetycore
   ```

2. **Audit the placeholder `APK` first** using the `aapt2` / `apksigner`
   checks from [section 2](#2-why-these-steps-and-why-they-are-safe). Only
   install it once you have confirmed it declares no sensitive permissions
   and carries a real, non-debug signature. If you are not comfortable
   trusting a stranger's binary at all, skip to
   [section 7](#7-building-it-yourself-from-source-the-zero-trust-option)
   and build it from source instead.
3. **Side-load it** (you will need *Install unknown apps* enabled for your
   browser or file manager, and it must be installed *as the user*, not as a
   system app):

   ```bash
   adb install Safetycore-placeholder.apk
   ```

From then on, any attempt by Google Play to reinstall the real service fails
the signature check and is refused. To undo it, uninstall the placeholder
and `SafetyCore` is free to return.

---

## 7. Building It Yourself From Source (the zero-trust option)

Section 6 assumes you trust the prebuilt `APK` from the project's releases
page. In the interest of being straight with you, here is exactly what I
found when I audited that binary, and exactly where the audit stops.

What checked out clean:

- **No sensitive permissions.** Only the AndroidX self-guard from
  [section 2](#2-why-these-steps-and-why-they-are-safe), nothing that reaches
  your data. Confirmed with `aapt2 dump permissions`.
- **No code of its own.** The `classes.dex` is library glue only, with no
  launchable activity, no services, and no networking or `exec`-style calls
  found anywhere in it.
- **A real, non-debug signature.** When I checked, it was signed with a
  self-signed `RSA` 2048-bit key (subject `CN=taki`) valid into 2050, which
  is *not* the forgeable public `CN=Android Debug` key.

So as software it is inert and harmless. **Here is the part the audit cannot
prove, stated plainly:** that signing key belongs to an unverifiable
pseudonym, the binary is downloaded separately from the source you can read,
and there is no way to cryptographically tie the two together. The audit
shows the binary *does nothing dangerous*. It does not prove *who* built it
or that it was built from the source above. On a hardened machine that
residual is a fair reason to not install someone else's binary at all.

The fix is to build it yourself. Same inert app, but compiled from source
you have read and signed with a key only you hold, so the only thing on
earth that can ever replace it is you.

### Prerequisites

The repo ships a Gradle wrapper, so you do not need system Gradle. You do
need a `JDK` and the Android SDK pieces for API 34 (what the project
targets):

```bash
sudo pacman -S jdk17-openjdk
yay -S android-sdk-cmdline-tools-latest android-sdk-build-tools
```

The `AUR` SDK packages install under `/opt/android-sdk` owned by `root`, so
give your user write access through a group (the same group-membership
mechanism used elsewhere in this repo, and yes, you must re-log for it to
apply):

```bash
sudo groupadd -f android-sdk
sudo gpasswd -a "$USER" android-sdk
sudo setfacl -R -m g:android-sdk:rwx /opt/android-sdk
sudo setfacl -d -m g:android-sdk:rwx /opt/android-sdk   # default ACL for new files
```

Re-log, then accept the licences and pull the API 34 platform and
build-tools:

```bash
export ANDROID_HOME=/opt/android-sdk
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

### Build the unsigned APK

```bash
git clone https://github.com/daboynb/Safetycore-placeholder.git
cd Safetycore-placeholder
./gradlew assembleRelease
```

The project defines no signing config, so this deliberately produces an
*unsigned* release `APK` at:

```
app/build/outputs/apk/release/app-release-unsigned.apk
```

> **Note**
> The project does not pin a build-tools version, so the Android Gradle
> Plugin picks a default (`34.0.0` here). If a build fails complaining about
> a missing component, it names the exact `platforms;...` or
> `build-tools;...` string to feed `sdkmanager`. Install that and re-run.

### Sign it with your own key

```bash
# Create your keystore once. Guard it: it is your sole control over updates.
keytool -genkeypair -v -keystore ~/safetycore-placeholder.jks \
  -alias placeholder -keyalg RSA -keysize 2048 -validity 10000

cd app/build/outputs/apk/release
zipalign -p -f 4 app-release-unsigned.apk app-release-aligned.apk
apksigner sign --ks ~/safetycore-placeholder.jks \
  --out Safetycore-placeholder.apk app-release-aligned.apk
apksigner verify --print-certs Safetycore-placeholder.apk   # confirm it is YOUR cert
```

`zipalign` and `apksigner` come from `android-sdk-build-tools`; `keytool`
comes from the `JDK`. `apksigner` is a Java wrapper, which is why the `JDK`
above matters.

### Install your build

Any existing copy (the stranger's, or an older one of yours) signs
differently, so remove it first:

```bash
adb shell pm uninstall --user 0 com.google.android.safetycore   # if present
adb install Safetycore-placeholder.apk
```

Now the audited source *is* the running app, and your private key is the
only thing that can replace it. You have extended trust to no one.

---

## Quick Reference

| Action | Command |
| --- | --- |
| Install tooling | `sudo pacman -S android-tools android-udev` |
| Allow non-root `adb` | `sudo usermod -aG adbusers "$USER"` (then re-log) |
| Confirm device seen | `adb devices` |
| Disable (non-root) | `adb shell pm disable-user --user 0 com.google.android.safetycore` |
| Verify disabled | `adb shell pm list packages -d \| grep safetycore` |
| Re-enable | `adb shell pm enable com.google.android.safetycore` |
| Disable (root, on-device) | `su -c 'pm disable com.google.android.safetycore'` |
| Uninstall the real app | `adb shell pm uninstall --user 0 com.google.android.safetycore` |
| Audit placeholder perms | `aapt2 dump permissions Safetycore-placeholder.apk` |
| Check placeholder signer | `apksigner verify --print-certs Safetycore-placeholder.apk` |
| Install placeholder | `adb install Safetycore-placeholder.apk` |
| Build-from-source tooling | `sudo pacman -S jdk17-openjdk && yay -S android-sdk-cmdline-tools-latest android-sdk-build-tools` |
| Build unsigned APK | `./gradlew assembleRelease` |
| Make your signing key | `keytool -genkeypair -keystore ~/sc.jks -alias placeholder -keyalg RSA -keysize 2048 -validity 10000` |
| Sign your build | `apksigner sign --ks ~/sc.jks --out Safetycore-placeholder.apk app-release-aligned.apk` |

---

None of this is about hating a blur-the-rude-images feature. It is the same
principle that runs through the [hardening chapter](./11_hardening.md):
**you decide what runs on your hardware, not the vendor.** Software that
installs itself without asking has earned a closer look, and because you own
the box and the tools, you can give it one, then undo the decision just as
easily if you change your mind.

| [← Previous](./12_arduino.md) |
|:--|
