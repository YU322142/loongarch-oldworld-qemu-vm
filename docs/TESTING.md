# Testing Checklist

This checklist is for LoongArch old-world ABI1.0 Linux/X11 desktop applications, especially .NET/Avalonia apps.

## Before Boot

1. Install QEMU.
2. Download and verify the Loongnix qcow2 image.
3. Generate `images\loongnix-abi1-work.qcow2`.
4. Put the application under test in `shared\`.
5. Start the VM with the default audio, networking, and shared folder enabled.

## Basic Guest Checks

```bash
uname -m
getconf GNU_LIBC_VERSION
echo "$XDG_SESSION_TYPE"
echo "$DISPLAY"
ip route
ping -c 3 github.com
```

Expected:

- Architecture is `loongarch64`.
- The desktop session provides an X11 environment.
- Networking works.

## Desktop Environment Preflight

If the VM stops at `tty1`, the system has only reached a text console. That is not enough for ClassIsland graphical acceptance. First follow [USAGE.md section 5](USAGE.md#5-if-first-boot-stops-at-tty1-enable-ssh-and-prepare-the-desktop-environment) to enable SSH as root and install/enable an X11 desktop.

After entering the graphical desktop, verify from a desktop terminal:

```bash
echo "$DISPLAY"
echo "$XDG_SESSION_TYPE"
echo "$XDG_CURRENT_DESKTOP"
ps -ef | grep -E 'lightdm|Xorg|openbox|tint2|lxterminal|xfe|plasmashell|kwin' | grep -v grep
```

Expected:

- `DISPLAY` is set, for example `:0`.
- The session is X11, or can at least launch X11 applications.
- A visible desktop, panel/tray area, terminal, and graphical file manager are available. With the recommended lightweight setup, expect `lightdm`, `Xorg`, `openbox`, `tint2`, `lxterminal`, and `xfe`.

If SSH works but there is no visible X11 desktop, only command-line diagnostics are possible; Avalonia/X11 rendering, tray, and audio acceptance is not complete.

## SSH Checks (Optional)

Visible desktop testing does not depend on SSH. Enable SSH only when you want to run commands, copy files, or collect logs remotely from the host.

The QEMU launcher already configures:

```text
127.0.0.1:2222 -> guest:22
```

If SSH is not enabled inside the guest, log in through the QEMU `tty1` as `root` / `Loongson20`, then run the service commands with root privileges:

```bash
systemctl enable ssh
systemctl start ssh
```

The normal `loongson` user cannot enable system services directly, and the mini image usually does not include `sudo`. If `ssh.service` is missing, install it from the root shell:

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

Connect from the host:

```powershell
ssh loongson@127.0.0.1 -p 2222
```

Service enablement requires root. After the service starts, prefer connecting from the host as the `loongson` user. Some images disable root password login over SSH by default; that is normal.

## Shared Folder

If the shared disk is not auto-mounted:

```bash
lsblk
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb /mnt/hostshare
```

Mounting requires root privileges. If `sudo` is not available for a normal user, run `su -` first or log in through `tty1` as root.

Copy to the guest local disk before running:

```bash
mkdir -p ~/testapp
cp -r /mnt/hostshare/YourApp/* ~/testapp/
cd ~/testapp
```

## Avalonia/.NET Application Checks

Start the app from a desktop terminal and verify:

- Main windows render fully, without black screens, transparency errors, top-left black remnants, or obvious crashes.
- Fonts, scaling, dialogs, settings pages, and lists display correctly.
- Tray icon appears; left-click/right-click menus work; restoring from tray works.
- Audio is audible, including bells, TTS, or test playback buttons.
- Network features can reach remote services.
- Restarting the app and opening it again still works.
- Xfe can browse the local test directory and the mounted shared-disk directory.
- Logs do not show native library load failures, `GLIBC` version mismatches, or missing SkiaSharp/HarfBuzzSharp libraries.

## Audio Checks

The default launch profile uses DirectSound + Intel HDA. A basic guest-side audio test:

```bash
speaker-test -t wav -c 2
```

If the app relies on `ffmpeg`/`ffplay`:

```bash
which ffplay || apt install ffmpeg
ffplay /path/to/test.wav
```

Package installation requires root privileges.

## Tray Checks

For tray testing in the recommended Openbox lightweight environment, first check:

```bash
echo "$XDG_CURRENT_DESKTOP"
echo "$DESKTOP_SESSION"
ps -ef | grep -E 'tint2|openbox' | grep -v grep
```

Then test tray menu, hide-to-tray, restore-from-tray, and exit actions. Tray behavior should be manually accepted in this environment.

## What To Record

Keep:

- `logs\last-qemu-args.txt`
- `logs\serial-*.log`
- application logs
- screenshots of important UI states
- test artifact file name and source Actions run

## Known Limits

- LoongArch on a Windows/x86 host uses QEMU TCG emulation and will not match real hardware speed.
- The shared FAT disk is for file transfer, not for running large applications directly.
- The work disk may contain private or test state; avoid publishing it.
