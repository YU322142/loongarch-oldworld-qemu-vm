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

## Shared Folder

If the shared disk is not auto-mounted:

```bash
lsblk
sudo mkdir -p /mnt/hostshare
sudo mount -t vfat /dev/vdb /mnt/hostshare
```

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
- Logs do not show native library load failures, `GLIBC` version mismatches, or missing SkiaSharp/HarfBuzzSharp libraries.

## Audio Checks

The default launch profile uses DirectSound + Intel HDA. A basic guest-side audio test:

```bash
speaker-test -t wav -c 2
```

If the app relies on `ffmpeg`/`ffplay`:

```bash
which ffplay || sudo apt install ffmpeg
ffplay /path/to/test.wav
```

## Tray Checks

For KDE/X11 tray testing, first check:

```bash
echo "$XDG_CURRENT_DESKTOP"
echo "$DESKTOP_SESSION"
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
