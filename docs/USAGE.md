# Using The VM To Test Applications

This guide follows the actual testing workflow. It is intended for first-time users on a Windows host who want to see a full Linux X11 desktop instead of headless QEMU.

## 1. Prepare The Project Directory

Clone the repository and enter it:

```powershell
git clone https://github.com/YU322142/loongarch-oldworld-qemu-vm.git
cd loongarch-oldworld-qemu-vm
```

Allow local scripts in the current PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This only affects the current PowerShell session.

## 2. Install QEMU

Use the repository script to install the tested Windows QEMU package:

```powershell
.\scripts\Install-Qemu-Windows.ps1
```

If QEMU is already installed, skip this step. The launcher searches:

- `tools\qemu`
- `C:\Program Files\qemu`
- `C:\Program Files (x86)\qemu`
- system `PATH`

If QEMU is somewhere else:

```powershell
.\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

You may also unpack or copy a portable QEMU build to:

```text
tools\qemu\qemu-system-loongarch64.exe
```

This repository and Release do not include QEMU binaries. If QEMU is not installed, not copied to `tools\qemu`, and not provided with `-QemuDir`, startup fails with:

```text
qemu-system-loongarch64.exe was not found
```

That means the Windows host has not provided a QEMU path yet; it is not a Loongnix image problem.

## 3. Download The System Image And Create A Work Disk

Run:

```powershell
.\scripts\Download-LoongnixImage.ps1
```

The script downloads the Loongnix Desktop mini qcow2 image, verifies MD5/SHA256, and creates:

```text
images\loongnix-abi1-work.qcow2
```

The work disk stores system settings, installed packages, and test state. Do not commit it to Git.

## 4. Start The Visible QEMU VM Window

If QEMU is installed in a location the script can find, double-click:

```bat
Launch-Loongnix-Desktop.cmd
```

`Launch-Loongnix-Desktop.cmd` is a CMD wrapper and forwards trailing arguments to the PowerShell script. If QEMU is not in a default location, start with:

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu
```

If you run the `.ps1` file directly, Windows may block script execution:

```text
running scripts is disabled on this system
```

Use either:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

or this one-shot form without changing the current window policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

To reuse a work disk and shared folder from another directory:

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu -DiskPath D:\Path\To\loongnix-abi1-work.qcow2 -SharePath D:\Path\To\shared
```

Common parameters:

| Parameter | Purpose |
| --- | --- |
| `-QemuDir` | Directory containing `qemu-system-loongarch64.exe`. |
| `-DiskPath` | qcow2 work disk to boot. |
| `-SharePath` | Host folder exposed to the guest. |
| `-SshPort` | Host SSH forwarding port, default `2222`. |
| `-Cores` / `-MemoryMB` | VM vCPU count and memory. |
| `-Snapshot` | Temporary run; disk changes are discarded on exit. |
| `-NoHostShare` | Disable the host shared disk. |
| `-NoAudio` | Disable virtual audio. |

Default features:

- Visible SDL window.
- User-mode networking.
- DirectSound + Intel HDA audio.
- Host `shared\` folder as a guest disk.
- SSH port forwarding `127.0.0.1:2222 -> guest:22`.

Log in to Loongnix:

| User | Password |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

Desktop testing does not depend on SSH, but when the first boot stops at `tty1`, SSH can only be enabled there by root first. After that, SSH is only an optional remote command entry point.

If the first boot stops at `tty1`, log in through the QEMU window as `root` / `Loongson20` and enable SSH from a root shell. This makes it easier to paste commands from the host, mount the shared disk, and collect logs:

```bash
systemctl enable ssh
systemctl start ssh
```

Then connect from the host as the normal user:

```powershell
ssh loongson@127.0.0.1 -p 2222
```

The normal `loongson` user cannot enable system services directly, and the mini image usually does not include `sudo`. If `ssh.service` does not exist, install it from the root shell:

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

Note: `root` is already the administrator account, so do not use `sudo` in a root shell. Some images disable root password login over SSH by default; use the `loongson` account for SSH testing.

## 4.1 Script Role Quick Reference

| Script | Purpose |
| --- | --- |
| `Launch-Loongnix-Desktop.cmd` | CMD launcher; calls `scripts\Start-Loongnix-Desktop.ps1` with `-ExecutionPolicy Bypass` and forwards parameters. |
| `scripts\Start-Loongnix-Desktop.ps1` | Starts the visible QEMU window and configures disk, UEFI, networking, audio, SSH forwarding, and host sharing. |
| `scripts\Install-Qemu-Windows.ps1` | Installs Windows QEMU with winget. |
| `scripts\Download-LoongnixImage.ps1` | Downloads/verifies the Loongnix image and creates `images\loongnix-abi1-work.qcow2`. |
| `scripts\Stop-Loongnix.ps1` | Stops matching QEMU processes. |
| `scripts\Reset-WorkDisk.ps1` | Recreates the work disk and clears guest test state. |
| `scripts\Package-Release.ps1` | Packages scripts and docs for Release; excludes QEMU, images, work disks, test software, and logs. |

## 5. If First Boot Stops At tty1, Enable SSH And Prepare The Desktop Environment

The public Loongnix Desktop mini qcow2 may boot into a text console instead of a graphical login manager:

```text
Loongnix GNU/Linux 20 Release 6 loongson-pc tty1
loongson-pc login:
```

This does not mean QEMU failed. Log in as `root` / `Loongson20`. Enabling SSH, installing packages, and enabling the display manager require root privileges. Do not use `sudo` in a root shell.

### 5.1 Enable SSH

SSH can only be enabled with root privileges. First log in through the QEMU `tty1` as `root` / `Loongson20`, then run:

```bash
systemctl enable ssh
systemctl start ssh
systemctl status ssh --no-pager
```

Connect from the host as the normal user:

```powershell
ssh loongson@127.0.0.1 -p 2222
```

If `ssh.service` does not exist, install OpenSSH from the root shell:

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

Some images disable root password login over SSH by default. Use the `loongson` account; run `su -` inside the guest when root privileges are needed.

### 5.2 Check Whether Desktop Components Are Installed

Run in a root shell:

```bash
systemctl get-default
systemctl list-unit-files | grep -E 'sddm|lightdm|gdm|display|xdm'
ls /usr/bin/Xorg /usr/bin/startplasma-x11 /usr/bin/kwin_x11 /usr/bin/startkde 2>/dev/null
```

How to read the result:

| Output | Meaning | Next Step |
| --- | --- | --- |
| `sddm.service`, `lightdm.service`, or another display manager appears | A graphical login manager is installed | Start that service |
| Xorg/KDE programs exist but no display manager appears | Some desktop components are installed | Install or enable a display manager |
| Almost no output | The mini image lacks a desktop environment | Install lightweight LightDM + Openbox |

In the public Loongnix mini image tested for this project, `ssh.service` can be enabled by root and `systemctl get-default` reports `graphical.target`, but there is no `sddm/lightdm` and no `/usr/bin/Xorg`, `startplasma-x11`, or `kwin_x11`. So the launcher opening a visible QEMU window does not mean the guest already has a desktop environment.

If `sddm` is installed:

```bash
systemctl start sddm
systemctl enable sddm
systemctl set-default graphical.target
```

If the display manager is `lightdm`, replace `sddm` with `lightdm`.

If installation is interrupted, first make sure no apt/dpkg process is still running and check the package database:

```bash
ps -ef | grep -E 'apt|dpkg' | grep -v grep
dpkg --audit
```

If `dpkg --audit` prints nothing, it is usually safe to continue. If it reports unpacked or unconfigured packages, run:

```bash
dpkg --configure -a
apt --fix-broken install
```

### 5.3 Install Lightweight LightDM + Openbox Test Desktop (Recommended)

All desktop installation commands below require root privileges. If you connected through SSH as the `loongson` user, run `su -` inside the guest first. Then check networking and apt repositories. The mini image may not include the `ip` command; use `ifconfig` until `iproute2` is installed:

```bash
ip route || ifconfig
ping -c 3 pkg.loongnix.cn
apt update
```

Install X11, D-Bus, audio tools, OpenSSH, LightDM, Openbox, LXTerminal, the tint2 panel/tray, the Xfe graphical file manager, notifications, and `iproute2`. This is much lighter than KDE/Plasma while still covering Avalonia/X11 rendering, windows, audio, notifications, tray icon acceptance, and graphical file browsing:

You can simulate the install first to confirm that dependencies resolve:

```bash
apt-get -s install lightdm openbox obconf lxterminal tint2 xfe notification-daemon
```

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm openbox obconf lxterminal tint2 xfe notification-daemon iproute2
```

Add an Openbox autostart file for the `loongson` user so login opens a panel, tray, and terminal immediately:

```bash
mkdir -p /home/loongson/.config/openbox
cat >/home/loongson/.config/openbox/autostart <<'EOF'
pulseaudio --start
notification-daemon &
tint2 &
lxterminal &
xfe &
EOF
chown -R loongson:loongson /home/loongson/.config
cat >/home/loongson/.dmrc <<'EOF'
[Desktop]
Session=openbox
EOF
chown loongson:loongson /home/loongson/.dmrc
mkdir -p /etc/xdg/lightdm/lightdm.conf.d
cat >/etc/xdg/lightdm/lightdm.conf.d/50-openbox-test.conf <<'EOF'
[Seat:*]
user-session=openbox
EOF
```

In the Loongnix repository, `/usr/share/xsessions/openbox.desktop` runs `Exec=/usr/bin/openbox-session`, which reads the `~/.config/openbox/autostart` file above. `.dmrc` and `50-openbox-test.conf` pin the default login session to Openbox so LightDM does not enter `lightdm-xsession` and then start Plasma. This LightDM build reads `/etc/xdg/lightdm/lightdm.conf.d`; do not place the custom snippets under `/etc/lightdm/lightdm.conf.d`.

If `sddm` was installed earlier, prefer LightDM for this lightweight setup so the display managers do not compete for the default entry point:

```bash
printf '/usr/sbin/lightdm\n' >/etc/X11/default-display-manager
systemctl disable sddm || true
systemctl enable lightdm
systemctl set-default graphical.target
```

In this Loongnix image, `lightdm.service` may report `static`; that does not necessarily mean the configuration failed. Check the default display-manager file, confirm `sddm` is disabled, and start LightDM:

```bash
cat /etc/X11/default-display-manager
systemctl is-enabled sddm || true
systemctl start lightdm
systemctl status lightdm --no-pager
```

If you had already logged into Plasma or another session before applying this configuration, restart LightDM:

```bash
systemctl restart lightdm
```

For faster repeated testing, you can also enable automatic login to Openbox for `loongson` in this local test VM:

```bash
cat >/etc/xdg/lightdm/lightdm.conf.d/60-autologin-openbox.conf <<'EOF'
[Seat:*]
autologin-user=loongson
autologin-user-timeout=0
user-session=openbox
autologin-session=openbox
EOF
systemctl restart lightdm
```

Autologin is recommended only for a local test VM. To keep the login screen, remove the file and restart LightDM:

```bash
rm -f /etc/xdg/lightdm/lightdm.conf.d/60-autologin-openbox.conf
systemctl restart lightdm
```

After confirming that the QEMU window shows a graphical login manager, reboot once to verify persistence:

```bash
systemctl reboot
```

The normal `loongson` user's PATH usually does not include `/usr/sbin`, so typing `reboot` directly may report command not found. From a root shell, prefer `systemctl reboot`. After reboot, the QEMU window should enter the LightDM graphical login manager. Log in as `loongson` / `Loongson20` and choose Openbox. After login, the tint2 panel/tray, LXTerminal, and Xfe file manager should appear.

When startup succeeds, `systemctl status lightdm --no-pager` should show `active (running)`, and the process list should include `/usr/sbin/lightdm` plus `/usr/lib/xorg/Xorg :0 ... vt7`.

If package names differ in your repository, search first:

```bash
apt-cache search lightdm
apt-cache search openbox
apt-cache search tint2
apt-cache search xfe
```

If one package download fails temporarily, retry with:

```bash
apt install --fix-missing xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm openbox obconf lxterminal tint2 xfe notification-daemon iproute2
```

In the tested Loongnix repositories, `pcmanfm` has no candidate version, the `xfce4` meta package fails because theme packages required by `xfce4-settings` are not installable, the `lxde` meta package references `lxpanel/pcmanfm` packages with no candidate version, and `caja` pulls a heavier MATE dependency set. The default path therefore uses Xfe. To re-check other file managers:

```bash
apt-cache policy lightdm lxde lxpanel openbox lxterminal pcmanfm
apt-cache policy xfe thunar caja dolphin xfce4-session xfce4-settings xfwm4 xfdesktop4
```

### 5.4 Optional: Install Full KDE/Plasma Desktop

If you want to test fuller KDE/Plasma desktop behavior, install `sddm`, `plasma-desktop`, `konsole`, and `dolphin`. It is more feature-complete, but the download and install size is much larger, so it is not the default recommendation for this test VM.

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio sddm plasma-desktop konsole dolphin iproute2
systemctl disable lightdm || true
systemctl enable sddm
systemctl set-default graphical.target
systemctl reboot
```

The tested Loongnix repositories provide these KDE packages, but a full KDE install downloads nearly 500 MB and is more likely to be interrupted on an unstable network.

### 5.5 Why tty Or SSH Is Not Enough

Avalonia/X11 applications such as ClassIsland and OpenRemoteShouter must be accepted in a real X11 desktop session. At minimum, check:

- Skia/Avalonia rendering.
- Tray icon and tray menus.
- D-Bus, desktop notifications, window hiding/restoring.
- Audible playback from the desktop session.
- Close, restart, and relaunch behavior.

SSH is useful for file transfer, mounting, and logs, but it does not replace final graphical acceptance.

## 6. Add The Application Under Test

Put the Actions artifact, Release package, or local build in:

```text
shared\
```

Examples:

```text
shared\ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz
shared\OpenRemoteShouter-linux-loongarch64-oldworld-abi1.0.tar.gz
```

If the VM is already running, the FAT shared disk usually sees new files. If not, remount inside the guest or restart the VM.

## 7. Mount The Shared Disk In The Guest

Open a Loongnix desktop terminal and inspect disks:

```bash
lsblk
```

If the shared disk is not mounted automatically:

```bash
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
```

Mounting requires root privileges. If you are currently the `loongson` user, run `su -` first.

If `/dev/vdb` is not the shared disk, choose the newly added disk shown by `lsblk`.

## 8. Copy To The Guest Local Disk

Do not run large applications directly from the shared FAT disk. Copy them to the guest local disk first:

```bash
mkdir -p ~/tests
cp /mnt/hostshare/ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz ~/tests/
cd ~/tests
tar -xf ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz
```

For zip packages:

```bash
unzip /mnt/hostshare/YourApp.zip -d ~/tests/YourApp
```

## 9. Start The Application

Start from the Loongnix desktop terminal rather than SSH. This keeps `DISPLAY`, D-Bus, tray, audio, and desktop session variables close to a real user environment.

Example:

```bash
cd ~/tests/ClassIsland-misha-alpha-ci-linux-loongarch64-net10/ClassIsland
chmod +x ./ClassIsland
./ClassIsland
```

If the application provides a launcher script, use it first:

```bash
bash run.sh
```

Keep the terminal open so native library load errors, GLIBC version errors, rendering backend errors, or audio command errors remain visible.

## 10. Manual Acceptance

Check at least:

| Item | What To Verify |
| --- | --- |
| Startup | The app opens and the terminal does not show obvious crash errors |
| Rendering | Main window, dialogs, settings pages, lists, fonts, and scaling look correct, with no black screen or abnormal blocks |
| Native libraries | Logs do not show SkiaSharp/HarfBuzzSharp load failures or `GLIBC` version mismatches |
| Networking | Network-dependent app features can reach remote services |
| Audio | Bells, TTS, test playback buttons, or app audio are audible |
| Tray | Tray icon appears; left-click/right-click menu, hide, restore, and exit work |
| Restart | Closing and launching again works; in-app restart works |
| Configuration | Settings can be changed, saved, and kept after restart |

For Avalonia desktop apps such as ClassIsland, also test:

- Initial setup flow.
- Schedule/time-related views.
- Settings and appearance pages.
- Notification or reminder windows.
- Tray menu and restore-from-tray.
- Speech or bell tests.
- Close, minimize, and restart behavior.

For remote/audio apps such as OpenRemoteShouter, also test:

- Network connection.
- Main window rendering.
- Audio playback.
- D-Bus or desktop activation behavior.
- Relaunch after close.

## 11. Record Results

Keep:

- Test artifact file name.
- GitHub Actions run link or Release link.
- VM launch arguments: `logs\last-qemu-args.txt`.
- Serial logs: `logs\serial-*.log`.
- Application logs.
- Screenshots of important UI states.
- Manual acceptance result, for example "rendering OK, tray works, audio audible".

## 12. Reset The Environment

If testing leaves the system in a bad state, shut down QEMU and run:

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars
```

By default, this creates a qcow2 backing work disk, which is faster and smaller. For a full-copy work disk:

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars -FullCopy
```

## 13. Common Issues

### QEMU Opens But Is Slow

This is expected. LoongArch on a Windows/x86 host uses TCG emulation. Copy the app to the guest local disk before running it and reduce host background load.

### No Audio

Make sure the VM was not started with `-NoAudio`, then test inside the guest:

```bash
speaker-test -t wav -c 2
```

If the app depends on `ffplay`:

```bash
which ffplay || apt install ffmpeg
```

Package installation requires root privileges; normal users should run `su -` first.

### Shared Disk Is Missing

Make sure the VM was not started with `-NoHostShare`, then run `lsblk` in the guest. Restart the VM if needed.

### SSH Does Not Connect

SSH is optional. If you need it, log in through the QEMU `tty1` as `root` / `Loongson20`, then run with root privileges:

```bash
systemctl enable ssh
systemctl start ssh
```

If `ssh.service` is missing, install it from the root shell:

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

Connect from the host as the normal user:

```powershell
ssh loongson@127.0.0.1 -p 2222
```

### Stuck At tty1 With No Desktop

This can happen with the Loongnix mini image. Follow section 5 to enable SSH as root, inspect the display manager, and install/enable an X11 desktop environment. Until the desktop is installed, only command-line diagnostics are possible; Avalonia/X11 graphical acceptance is not complete.
