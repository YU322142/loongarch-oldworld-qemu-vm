# Scripts / 脚本说明

## 中文

| 脚本 | 作用 |
| --- | --- |
| `Install-Qemu-Windows.ps1` | 用 winget 安装已测试过的 Windows QEMU，并默认复制到被 Git 忽略的 `tools\qemu`；仓库和 Release 不包含 QEMU。传 `-NoCopyToRepo` 可跳过复制。 |
| `Download-LoongnixImage.ps1` | 下载并校验 Loongnix qcow2 镜像，然后用 `qemu-img.exe` 创建可写工作盘；只下载镜像可传 `-SkipWorkDisk`。 |
| `Start-Loongnix-Desktop.ps1` | 启动可见 LoongArch 旧世界 X11 测试虚拟机，配置工作盘、UEFI、声音、网络、SSH 转发和共享盘。 |
| `Stop-Loongnix.ps1` | 停止匹配的 QEMU 进程。 |
| `Reset-WorkDisk.ps1` | 从干净基础镜像重建可写工作盘，会清空虚拟机内已安装软件和测试状态。 |
| `Package-Release.ps1` | 打包脚本和文档用于 Actions 或 Release，不包含 QEMU、镜像、工作盘、测试软件或日志。 |
| `..\shared\setup-loongnix-test-desktop.sh` | 在 Loongnix 虚拟机内以 root 运行；一键配置 SSH、中文 locale、LightDM、Loongnix X11 Test Desktop、`xfwm4` 合成器、Xfce panel 托盘、LXTerminal 和 Xfe。 |

如果 QEMU 不在 `tools\qemu`、`C:\Program Files\qemu`、`C:\Program Files (x86)\qemu` 或系统 `PATH` 中，启动时必须传入：

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu
```

`Launch-Loongnix-Desktop.cmd` 会把参数转交给 `Start-Loongnix-Desktop.ps1`。直接运行 `.ps1` 被执行策略拦截时，使用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

## English

| Script | Purpose |
| --- | --- |
| `Install-Qemu-Windows.ps1` | Install the tested Windows QEMU package with winget and copy it to ignored `tools\qemu` by default; QEMU is not included in this repository or Release. Pass `-NoCopyToRepo` to skip the copy. |
| `Download-LoongnixImage.ps1` | Download and verify the Loongnix qcow2 image, then create a writable work disk with `qemu-img.exe`; pass `-SkipWorkDisk` to download only. |
| `Start-Loongnix-Desktop.ps1` | Start the visible LoongArch old-world X11 test VM and configure the work disk, UEFI, audio, networking, SSH forwarding, and shared disk. |
| `Stop-Loongnix.ps1` | Stop matching QEMU processes. |
| `Reset-WorkDisk.ps1` | Recreate the writable work disk from the clean base image; this clears installed guest packages and test state. |
| `Package-Release.ps1` | Package scripts and docs for Actions or Release; QEMU, images, work disks, test software, and logs are excluded. |
| `..\shared\setup-loongnix-test-desktop.sh` | Run as root inside the Loongnix guest; configures SSH, Chinese locale, LightDM, Loongnix X11 Test Desktop, the `xfwm4` compositor, Xfce panel tray, LXTerminal, and Xfe in one pass. |

If QEMU is not in `tools\qemu`, `C:\Program Files\qemu`, `C:\Program Files (x86)\qemu`, or system `PATH`, pass:

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu
```

`Launch-Loongnix-Desktop.cmd` forwards arguments to `Start-Loongnix-Desktop.ps1`. If direct `.ps1` execution is blocked by policy, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```
