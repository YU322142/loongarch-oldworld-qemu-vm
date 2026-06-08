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

## 4. Start The Visible Desktop VM

Double-click:

```bat
Launch-Loongnix-Desktop.cmd
```

or run:

```powershell
.\scripts\Start-Loongnix-Desktop.ps1
```

Default features:

- Visible SDL desktop window.
- User-mode networking.
- DirectSound + Intel HDA audio.
- Host `shared\` folder as a guest disk.
- SSH port forwarding `127.0.0.1:2222 -> guest:22`.

Log in to Loongnix:

| User | Password |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

Desktop testing does not require SSH. SSH is only an optional remote command entry point.

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
| Almost no output | The mini image lacks a desktop environment | Install one below |

If `sddm` is installed:

```bash
systemctl start sddm
systemctl enable sddm
systemctl set-default graphical.target
```

If the display manager is `lightdm`, replace `sddm` with `lightdm`.

### 5.3 Install KDE/Plasma

All desktop installation commands below require root privileges. If you connected through SSH as the `loongson` user, run `su -` inside the guest first. Then check networking and apt repositories:

```bash
ip route
ping -c 3 pkg.loongnix.cn
apt update
```

Install base X11, D-Bus, audio tools, SSH, and a display manager:

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio sddm
```

Then install KDE/Plasma components:

```bash
apt install plasma-desktop konsole dolphin
```

If package names differ in your repository, search first:

```bash
apt-cache search plasma-desktop
apt-cache search kde | grep -E 'desktop|plasma'
apt-cache search sddm
```

Enable graphical login and reboot:

```bash
systemctl enable sddm
systemctl set-default graphical.target
reboot
```

After reboot, the QEMU window should enter a graphical login manager. Log in as `loongson` / `Loongson20`.

### 5.4 Fallback: Install A Lightweight Desktop

If Plasma/KDE packages are unavailable, install Xfce as a test shell. It is enough for Avalonia/X11 rendering, window, audio, and tray acceptance:

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfce4 xfce4-terminal
systemctl enable lightdm
systemctl set-default graphical.target
reboot
```

After reboot, log in as `loongson` in Xfce and continue with ClassIsland testing. If the tray area is not visible by default, enable the notification/status tray plugin in the panel.

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
