# Third-Party Assets, Sources, And License Boundaries

This repository licenses its scripts and documentation under MIT. The components listed below are not covered by this repository's MIT license.

## QEMU For Windows

- Purpose: provides `qemu-system-loongarch64.exe`, `qemu-img.exe`, LoongArch64 EDK2 firmware, and runtime dependencies.
- Recommended install: `winget install -e --id SoftwareFreedomConservancy.QEMU --version 11.0.50`
- Tested version: QEMU `11.0.50`; `qemu-system-loongarch64.exe --version` reports `v11.0.0-12631-g54e84cdc7a`.
- Official license note: QEMU is released under GNU GPL v2.
- Website: [https://www.qemu.org/](https://www.qemu.org/)
- License note: [https://www.qemu.org/docs/master/about/license.html](https://www.qemu.org/docs/master/about/license.html)

`scripts/Install-Qemu-Windows.ps1` tries to install QEMU into `tools/qemu/` by default, or copies an existing local QEMU directory there, so project scripts can find QEMU from the project directory first. The repository does not commit `tools/qemu/`, and Release packages do not include it. If you redistribute QEMU binaries in a Release, you must comply with QEMU and dependency licenses, including source-code availability requirements where applicable.

## Loongnix Desktop Mini qcow2

- Purpose: old-world LoongArch ABI1.0 Linux/X11 desktop test system.
- Default image: `Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2`
- Official directory: [https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/](https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/)
- Loongnix page: [https://www.loongnix.cn/zh/loongnix/](https://www.loongnix.cn/zh/loongnix/)
- Default credentials reference: [Loongnix KVM documentation](https://docs.loongnix.cn/kvm/kvm/loongarch-kvm/install-and-setup/%E5%85%A8%E6%96%B0%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2.html)

Recorded checksums for this setup:

```text
MD5    3ca44ded43023602deafaad416756cf7
SHA256 c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c
```

The repository does not commit `images/*.qcow2`. The Loongnix image, packages, system components, trademarks, and binary redistribution boundaries are governed by Loongnix and the relevant upstream licenses.

## Work Disk

`images\loongnix-abi1-work.qcow2` is the writable disk generated from the base image. It may contain user settings, test software, logs, caches, or private data. Do not commit it to Git, and avoid publishing it as a general source asset.

For reproducible testing, publish:

- This repository or its Actions package.
- The official Loongnix image URL and checksums.
- Test application Release artifacts.
- Guest-side installation and configuration steps.

## User Test Software

`shared/setup-loongnix-test-desktop.sh` is an MIT-licensed helper from this repository and is included in Git and Release packages. Other files placed under `shared/` are only for host/guest transfer and are ignored by default. Test packages such as ClassIsland, OpenRemoteShouter, and native library builds should be published under their own repository licenses and Release processes.
