# LoongArch Old-World ABI1.0 QEMU X11 Test Environment

This repository provides a visible Windows-hosted QEMU VM launcher for testing LoongArch old-world ABI1.0 Linux/X11 applications, especially .NET/Avalonia rendering, audio, networking, tray icons, notifications, and basic desktop interaction.

> This README is the project entry point and documentation index only. It is not a replacement for the full setup guide. For first-time setup, desktop installation, SSH, shared disks, application testing, and troubleshooting, follow the [full usage guide](docs/USAGE.md).

中文说明: [README.md](README.md)

## Project Scope

This project is intended to provide a manually observable LoongArch old-world test environment:

- Start a visible QEMU window, not headless QEMU.
- Provide user-mode networking, SSH port forwarding, DirectSound + Intel HDA audio, and a host shared disk by default.
- Provide Loongnix Desktop mini image download/verification, work-disk creation, snapshot, and reset scripts.
- Provide a guest-side one-shot setup script for installing a lightweight X11 test desktop.
- Recommend Loongnix X11 Test Desktop: the `xfwm4` compositor, Xfce panel StatusNotifier/systray support, LXTerminal, Xfe, and `xfce4-notifyd`.
- Support manual acceptance for LoongArch old-world .NET/Avalonia applications such as ClassIsland and OpenRemoteShouter.

The Loongnix Desktop mini image may first stop at `tty1`. That does not mean the launcher failed; it means the guest still needs graphical desktop setup. Continue with the first-run workflow in the [full usage guide](docs/USAGE.md).

## Important Boundaries

This repository only contains open-source scripts and documentation. The following items are not part of this repository and are not included in source packages or Release packages:

- QEMU binaries or EDK2 firmware.
- Loongnix system images.
- VM work disks, snapshots, and runtime logs.
- User-provided test software, Actions artifacts, runtimes, or temporary files placed under `shared/`.

Third-party source and license boundaries are documented in [docs/ASSETS.md](docs/ASSETS.md).

## Recommended Reading Order

1. Start with the [full usage guide](docs/USAGE.md) and follow it in order for QEMU, the system image, the work disk, first boot, SSH, desktop setup, shared-disk mounting, and running test software.
2. Then use the [testing checklist](docs/TESTING.md) to verify rendering, transparent windows, tray behavior, audio, networking, notifications, and restart behavior through manual acceptance.
3. For script responsibilities, see [scripts/README.md](scripts/README.md).
4. For moving test packages into the VM, see [shared/README.md](shared/README.md).
5. For public asset boundaries, see [docs/ASSETS.md](docs/ASSETS.md).

## Documentation Index

| Document | Purpose |
| --- | --- |
| [docs/USAGE.zh-CN.md](docs/USAGE.zh-CN.md) | Chinese full usage guide: install QEMU, download the image, start the VM, enable SSH, install the desktop, mount the shared disk, run test software, and troubleshoot common issues. |
| [docs/USAGE.md](docs/USAGE.md) | English full usage guide. |
| [docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md) | Chinese testing checklist for X11, transparent windows, tray icons, audio, networking, logs, and manual acceptance. |
| [docs/TESTING.md](docs/TESTING.md) | English testing checklist. |
| [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md) | Chinese asset source and license boundary notes. |
| [docs/ASSETS.md](docs/ASSETS.md) | English asset and license boundary notes. |
| [scripts/README.md](scripts/README.md) | Role descriptions for start, download, reset, stop, and package scripts. |
| [shared/README.md](shared/README.md) | Host shared-folder usage and guest-side one-shot setup helper notes. |

## Repository Layout

| Path | Purpose |
| --- | --- |
| `scripts/` | Start, stop, download, reset, and package scripts. |
| `shared/` | Host/guest file exchange; only the README and one-shot setup script are tracked. |
| `images/` | Loongnix base image and work-disk location; generated files are ignored. |
| `firmware/` | Runtime UEFI variable file location; generated files are ignored. |
| `logs/` | Serial logs and last QEMU argument list; runtime logs are ignored. |
| `tools/qemu/` | Local QEMU copy directory; ignored and not packaged. |

## Online Packaging

The GitHub Actions workflow is `.github/workflows/package.yml`. It packages scripts and documentation only. It does not bundle QEMU, Loongnix images, VM work disks, test software, or logs.

## License

Repository scripts and documentation are licensed under MIT. Third-party components, system images, runtimes, and user test software remain under their own licenses.
