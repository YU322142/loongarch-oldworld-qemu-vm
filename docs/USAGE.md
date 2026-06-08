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

Creating the work disk requires `qemu-img.exe` on the Windows host. If you see `Verified image` followed by `qemu-img.exe was not found`, the image has already been downloaded and verified; only the work disk is missing. Install QEMU as described in section 2, or pass the QEMU directory:

```powershell
.\scripts\Download-LoongnixImage.ps1 -QemuDir D:\Path\To\qemu
```

If you only want to download and verify the image without creating a work disk:

```powershell
.\scripts\Download-LoongnixImage.ps1 -SkipWorkDisk
```

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

### 5.2 Use The Shared One-Shot Setup Script (Recommended)

This repository provides a guest-side setup helper in `shared\`:

```text
shared\setup-loongnix-test-desktop.sh
```

Inside Loongnix, it performs these actions:

- Enables SSH.
- Installs X11, LightDM, the `xfwm4` compositing window manager, Xfce panel, StatusNotifier/systray tray plugins, LXTerminal, the Xfe graphical file manager, audio tools, and notification support.
- Generates the `zh_CN.UTF-8` locale, installs Chinese fonts, and sets the system language to Chinese where possible.
- Sets the time zone to `Asia/Shanghai`.
- Configures LightDM to use the `loongnix-test` session by default and creates the `display-manager.service` link so reboot does not stop at `tty1`.
- Enables `loongson` autologin by default for faster repeated testing.

If the VM stops at `tty1`, log in as `root` / `Loongson20`, mount the shared disk, and run:

```bash
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
sh /mnt/hostshare/setup-loongnix-test-desktop.sh
systemctl reboot
```

If neither `/dev/vdb1` nor `/dev/vdb` is the shared disk, run `lsblk` and replace it with the correct device. In testing, QEMU's `fat:rw` shared disk usually appears as a `vdb` disk with a `vdb1` partition, so mount `/dev/vdb1` first. The script on the FAT shared disk may not have executable permission, so use `sh path/to/script`.

Useful customizations:

```bash
# Keep the LightDM login screen instead of autologin.
AUTOLOGIN=0 sh /mnt/hostshare/setup-loongnix-test-desktop.sh

# Do not change the system language.
SET_CHINESE=0 sh /mnt/hostshare/setup-loongnix-test-desktop.sh

# Reboot automatically after configuration.
REBOOT_AFTER=1 sh /mnt/hostshare/setup-loongnix-test-desktop.sh
```

After the script completes and the VM reboots, the QEMU window should enter Loongnix X11 Test Desktop. By default, the Xfce panel tray, LXTerminal, and Xfe file manager should be visible. This session uses `xfwm4 --compositor=on` to cover Avalonia transparent windows, and the tray provides both StatusNotifier and traditional systray support. If the script fails or you want to customize the setup, continue with the manual path below.

### 5.3 Check Whether Desktop Components Are Installed

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
| Almost no output | The mini image lacks a desktop environment | Install lightweight LightDM + Loongnix X11 Test Desktop |

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

### 5.4 Manually Install Lightweight LightDM + Loongnix X11 Test Desktop

All desktop installation commands below require root privileges. If you connected through SSH as the `loongson` user, run `su -` inside the guest first. Then check networking and apt repositories. The mini image may not include the `ip` command; use `ifconfig` until `iproute2` is installed:

```bash
ip route || ifconfig
ping -c 3 pkg.loongnix.cn
apt update
```

Install X11, D-Bus, audio tools, OpenSSH, LightDM, `xfwm4`, Xfce panel, StatusNotifier/systray tray plugins, LXTerminal, the Xfe graphical file manager, notification support, Chinese fonts, locale tools, and `iproute2`. This is much lighter than KDE/Plasma while still covering Avalonia/X11 rendering, transparent window compositing, windows, audio, notifications, tray icon acceptance, and graphical file browsing:

You can simulate the install first to confirm that dependencies resolve:

```bash
apt-get -s install lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin lxterminal xfe xfce4-notifyd libnotify-bin fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin libayatana-appindicator3-1 libappindicator3-1 ayatana-indicator-application lxterminal xfe xfce4-notifyd libnotify-bin x11-xserver-utils iproute2 locales fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

Configure Chinese locale, Chinese font cache, and the China time zone:

```bash
sed -i 's/^[#[:space:]]*zh_CN.UTF-8[[:space:]]\+UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^zh_CN.UTF-8 UTF-8' /etc/locale.gen || echo 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen zh_CN.UTF-8 en_US.UTF-8
update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_MESSAGES=zh_CN.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo Asia/Shanghai >/etc/timezone
fc-cache -f
```

The Chinese language settings apply fully to new login sessions. Check with `locale` from the `loongson` desktop terminal or SSH session. A root shell entered from an already-open terminal with `su` may still show `POSIX`; that does not mean the desktop user's locale failed.

Create the `loongnix-test` session. It starts `xfwm4 --compositor=on` directly, then starts Xfce panel, LXTerminal, and Xfe, and forces the Xfce panel StatusNotifier and systray plugins during session startup. Tray testing depends on `org.kde.StatusNotifierWatcher`; do not omit the panel configuration function below:

```bash
cat >/usr/local/bin/loongnix-test-session <<'EOF'
#!/bin/sh
USER_ID="$(id -u)"
export LANG="${LANG:-zh_CN.UTF-8}"
export LANGUAGE="${LANGUAGE:-zh_CN:zh}"
export LC_MESSAGES="${LC_MESSAGES:-zh_CN.UTF-8}"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=loongnix-test
export XDG_SESSION_DESKTOP=loongnix-test
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "/run/user/$USER_ID/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
fi

set_panel_prop() {
    property="$1"
    type="$2"
    value="$3"
    xfconf-query -c xfce4-panel -p "$property" -n -t "$type" -s "$value" >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p "$property" -t "$type" -s "$value" >/dev/null 2>&1 || true
}

configure_panel() {
    command -v xfconf-query >/dev/null 2>&1 || return 0
    xfconf-query -c xfce4-panel -p /panels -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /plugins -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /configver -r >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /panels -n -a -t int -s 1 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels -a -t int -s 1 >/dev/null 2>&1 || true
    set_panel_prop /configver int 2
    set_panel_prop /panels/panel-1/position string 'p=10;x=0;y=0'
    set_panel_prop /panels/panel-1/length uint 100
    set_panel_prop /panels/panel-1/position-locked bool true
    set_panel_prop /panels/panel-1/size uint 30
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -n -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || true
    set_panel_prop /plugins/plugin-1 string applicationsmenu
    set_panel_prop /plugins/plugin-2 string tasklist
    set_panel_prop /plugins/plugin-3 string separator
    set_panel_prop /plugins/plugin-3/expand bool true
    set_panel_prop /plugins/plugin-3/style uint 0
    set_panel_prop /plugins/plugin-4 string statusnotifier
    set_panel_prop /plugins/plugin-5 string systray
    set_panel_prop /plugins/plugin-6 string clock
}

pkill -x xfce4-panel >/dev/null 2>&1 || true
pkill -x wrapper-1.0 >/dev/null 2>&1 || true
pkill -x wrapper-2.0 >/dev/null 2>&1 || true
pkill -x tint2 >/dev/null 2>&1 || true
pkill -x stalonetray >/dev/null 2>&1 || true
pkill -x xcompmgr >/dev/null 2>&1 || true

xsetroot -solid '#d8e0e5' || true
pulseaudio --start &
if [ -x /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd ]; then
    /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd &
fi
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true >/dev/null 2>&1 || true
xfwm4 --compositor=on &
wm_pid=$!
sleep 2
configure_panel
xfce4-panel --disable-wm-check &
sleep 1
lxterminal &
xfe &
wait "$wm_pid"
EOF
chmod 0755 /usr/local/bin/loongnix-test-session

cat >/usr/share/xsessions/loongnix-test.desktop <<'EOF'
[Desktop Entry]
Name=Loongnix X11 Test Desktop
Comment=Lightweight X11 session with compositor, panel, tray, notifications, terminal, and file manager
Exec=/usr/local/bin/loongnix-test-session
Type=Application
DesktopNames=XFCE
EOF

cat >/home/loongson/.dmrc <<'EOF'
[Desktop]
Session=loongnix-test
EOF
chown loongson:loongson /home/loongson/.dmrc
mkdir -p /etc/xdg/lightdm/lightdm.conf.d
cat >/etc/xdg/lightdm/lightdm.conf.d/50-loongnix-test.conf <<'EOF'
[Seat:*]
user-session=loongnix-test
EOF
```

This LightDM build reads `/etc/xdg/lightdm/lightdm.conf.d`; do not place custom snippets under `/etc/lightdm/lightdm.conf.d`. If older Openbox autologin snippets remain, disable them so they do not override `loongnix-test`:

```bash
for f in /etc/xdg/lightdm/lightdm.conf.d/*openbox*.conf; do
    [ -f "$f" ] && mv "$f" "$f.disabled"
done
```

To prevent KDE's notification service shim from claiming `org.freedesktop.Notifications` and then exiting in the lightweight session, pin notifications to `xfce4-notifyd`:

```bash
if [ -f /usr/share/dbus-1/services/org.kde.plasma.Notifications.service ]; then
    mv /usr/share/dbus-1/services/org.kde.plasma.Notifications.service /usr/share/dbus-1/services/org.kde.plasma.Notifications.service.disabled
fi
cat >/usr/share/dbus-1/services/org.freedesktop.Notifications.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd
EOF
```

If `sddm` was installed earlier, prefer LightDM for this lightweight setup so the display managers do not compete for the default entry point:

```bash
printf '/usr/sbin/lightdm\n' >/etc/X11/default-display-manager
systemctl disable sddm || true
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
systemctl daemon-reload
systemctl enable lightdm || true
systemctl set-default graphical.target
```

In this Loongnix image, `lightdm.service` may report `static`; that does not necessarily mean the configuration failed. When rebooting did not enter the graphical UI during testing, the key missing piece was `/etc/systemd/system/display-manager.service` pointing to `lightdm.service`; the `ln -sf` command above creates it. Check the default display-manager file, the display-manager link, confirm `sddm` is disabled, and start LightDM:

```bash
cat /etc/X11/default-display-manager
ls -l /etc/systemd/system/display-manager.service
systemctl is-enabled sddm || true
systemctl start lightdm
systemctl status lightdm --no-pager
```

If you had already logged into Plasma or another session before applying this configuration, restart LightDM:

```bash
systemctl restart lightdm
```

For faster repeated testing, you can also enable automatic login to `loongnix-test` for `loongson` in this local test VM:

```bash
cat >/etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf <<'EOF'
[Seat:*]
autologin-user=loongson
autologin-user-timeout=0
user-session=loongnix-test
autologin-session=loongnix-test
EOF
systemctl restart lightdm
```

Autologin is recommended only for a local test VM. To keep the login screen, remove the file and restart LightDM:

```bash
rm -f /etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf
systemctl restart lightdm
```

After confirming that the QEMU window shows a graphical login manager, reboot once to verify persistence:

```bash
systemctl reboot
```

The normal `loongson` user's PATH usually does not include `/usr/sbin`, so typing `reboot` directly may report command not found. From a root shell, prefer `systemctl reboot`. After reboot, the QEMU window should enter the LightDM graphical login manager or autologin to Loongnix X11 Test Desktop. After login, the Xfce panel, tray area, LXTerminal, and Xfe file manager should appear.

When startup succeeds, `systemctl status lightdm --no-pager` should show `active (running)`, and the process list should include `/usr/sbin/lightdm` plus `/usr/lib/xorg/Xorg :0 ... vt7`.

If package names differ in your repository, search first:

```bash
apt-cache search lightdm
apt-cache search xfwm4
apt-cache search xfce4-panel
apt-cache search statusnotifier
apt-cache search xfe
```

If one package download fails temporarily, retry with:

```bash
apt install --fix-missing xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin libayatana-appindicator3-1 libappindicator3-1 ayatana-indicator-application lxterminal xfe xfce4-notifyd libnotify-bin x11-xserver-utils iproute2 locales fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

In the tested Loongnix repositories, `pcmanfm` has no candidate version, the `xfce4` meta package fails because theme packages required by `xfce4-settings` are not installable, the `lxde` meta package references `lxpanel/pcmanfm` packages with no candidate version, and `caja` pulls a heavier MATE dependency set. The default path therefore uses Xfe. To re-check other file managers:

```bash
apt-cache policy lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin lxde lxpanel lxterminal pcmanfm
apt-cache policy xfe thunar caja dolphin xfce4-session xfce4-settings xfwm4 xfdesktop4
```

### 5.5 Optional: Install Full KDE/Plasma Desktop

If you want to test fuller KDE/Plasma desktop behavior, install `sddm`, `plasma-desktop`, `konsole`, and `dolphin`. It is more feature-complete, but the download and install size is much larger, so it is not the default recommendation for this test VM.

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio sddm plasma-desktop konsole dolphin iproute2
systemctl disable lightdm || true
systemctl enable sddm
systemctl set-default graphical.target
systemctl reboot
```

The tested Loongnix repositories provide these KDE packages, but a full KDE install downloads nearly 500 MB and is more likely to be interrupted on an unstable network.

### 5.6 Why tty Or SSH Is Not Enough

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
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
```

Mounting requires root privileges. If you are currently the `loongson` user, run `su -` first.

If neither `/dev/vdb1` nor `/dev/vdb` is the shared disk, choose the newly added disk shown by `lsblk`. The common tested output is a `vdb` disk containing a `vdb1` partition; in that case mount `/dev/vdb1`.

Note: QEMU's `fat:rw` shared disk is best used by placing files on the host before starting the VM. Files added from Windows while the VM is already running may not appear immediately in the guest; if `ls /mnt/hostshare` does not show a new file, reboot the VM or restart QEMU and check again.

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
