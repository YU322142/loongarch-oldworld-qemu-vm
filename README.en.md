# LoongArch Old-World ABI1.0 QEMU X11 Test Environment

This repository provides a visible Windows-hosted QEMU desktop VM setup for testing LoongArch old-world ABI1.0 Linux/X11 applications, especially .NET/Avalonia rendering, audio, networking, tray icons, and desktop interaction.

The repository only contains open-source launcher scripts, download/checksum scripts, packaging scripts, and documentation. QEMU, EDK2 firmware, Loongnix system images, runtimes, and user test packages are third-party or user-provided assets and are not covered by this repository's MIT license. See [docs/ASSETS.md](docs/ASSETS.md) for source and licensing boundaries.

中文说明: [README.md](README.md)

## What It Provides

- A visible desktop window, not headless QEMU, so rendering issues can be inspected manually.
- User-mode networking by default, forwarding host `127.0.0.1:2222` to guest SSH port `22`.
- DirectSound + Intel HDA audio by default for bell, TTS, and playback tests.
- A host shared folder by default for moving Actions artifacts or local builds into the VM.
- virtio disk, virtio network, virtio GPU, USB tablet, and raised QEMU process priority for better TCG performance.
- Snapshot mode and quick work-disk reset for repeated testing.

## Directory Layout

| Path | Purpose |
| --- | --- |
| `scripts/` | Start, stop, download, reset, and package scripts |
| `images/` | Loongnix base image and generated work disk; not committed |
| `shared/` | Host/guest exchange folder; contents are not committed |
| `firmware/` | Runtime UEFI variable file; generated file is not committed |
| `logs/` | Serial logs and last QEMU argument list |
| `tools/qemu/` | Optional portable QEMU directory; not committed |

## Quick Start

### 1. Install QEMU

Use winget to install the tested Windows QEMU package:

```powershell
.\scripts\Install-Qemu-Windows.ps1
```

The script installs `SoftwareFreedomConservancy.QEMU` version `11.0.50` by default. If QEMU is already installed, you can place it in `tools\qemu` or pass `-QemuDir` when starting the VM.

### 2. Download The Loongnix Image And Create A Work Disk

```powershell
.\scripts\Download-LoongnixImage.ps1
```

The script downloads:

```text
Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2
```

and verifies:

```text
MD5    3ca44ded43023602deafaad416756cf7
SHA256 c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c
```

It then creates `images\loongnix-abi1-work.qcow2` as the writable work disk.

### 3. Start The Visible Desktop

Double-click:

```bat
Launch-Loongnix-Desktop.cmd
```

or run:

```powershell
.\scripts\Start-Loongnix-Desktop.ps1
```

Default profile:

- visible SDL window
- 6 vCPU cores
- 6144 MB RAM
- TCG multi-thread, `tb-size=1024`
- virtio disk, network, GPU, and RNG
- USB keyboard and USB tablet
- DirectSound + Intel HDA audio
- SSH forwarding: `127.0.0.1:2222 -> guest:22`
- `shared\` exposed as an extra FAT/virtio disk

## Login

Loongnix Desktop mini qcow2 default credentials:

| User | Password |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

## Testing An Application

Put the LoongArch Linux test package in:

```text
shared\
```

If the shared disk is not auto-mounted in the guest:

```bash
lsblk
sudo mkdir -p /mnt/hostshare
sudo mount -t vfat /dev/vdb /mnt/hostshare
```

For better runtime speed, copy the app to the guest local disk before extracting or running it:

```bash
mkdir -p ~/testapp
cp -r /mnt/hostshare/YourApp/* ~/testapp/
cd ~/testapp
chmod +x ./YourApp
./YourApp
```

For Avalonia/X11 applications, start from a desktop terminal so `DISPLAY`, D-Bus, tray, and desktop session variables are already present.

See [docs/TESTING.md](docs/TESTING.md) for a fuller checklist.

## Common Commands

```powershell
# Try the GTK display backend.
.\scripts\Start-Loongnix-Desktop.ps1 -Display gtk

# Lower resource usage.
.\scripts\Start-Loongnix-Desktop.ps1 -Cores 4 -MemoryMB 4096

# Disposable test run; changes are discarded on exit.
.\scripts\Start-Loongnix-Desktop.ps1 -Snapshot

# Temporarily disable audio.
.\scripts\Start-Loongnix-Desktop.ps1 -NoAudio

# Disable the shared folder.
.\scripts\Start-Loongnix-Desktop.ps1 -NoHostShare

# Stop QEMU launched by this setup.
.\scripts\Stop-Loongnix.ps1

# Reset the work disk.
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars
```

## Performance Notes

- LoongArch on a Windows/x86 host uses QEMU TCG emulation, not hardware virtualization acceleration.
- The shared FAT disk is useful for file transfer but slow for running large apps; extract and run apps on the guest local disk.
- The default 6 vCPU setting is a practical starting point on a 24-logical-thread host; too many emulated vCPUs can reduce TCG performance.
- Use persistent mode for repeated testing and `-Snapshot` for one-off checks.

## Online Packaging

The repository includes a GitHub Actions workflow:

```text
.github/workflows/package.yml
```

It packages scripts and docs only. It does not bundle QEMU, Loongnix images, work disks, test software, or logs. Users can fill in a version in Actions to produce an artifact and optionally create a GitHub Release.

## License

Repository scripts and documentation are licensed under MIT. Third-party component sources and license boundaries are documented in [docs/ASSETS.md](docs/ASSETS.md).
