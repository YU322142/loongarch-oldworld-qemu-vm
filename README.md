# LoongArch 旧世界 ABI1.0 QEMU X11 测试环境

这是一个 Windows 主机上的可见 QEMU 虚拟机与 X11 测试环境方案，用于测试 LoongArch 旧世界 ABI1.0 Linux/X11 软件，重点覆盖 .NET/Avalonia 应用的渲染、声音、网络、托盘图标和基本桌面交互。

本仓库只开源启动脚本、下载/校验脚本、打包脚本和文档。QEMU、EDK2 固件、Loongnix 系统镜像、运行库和你放进虚拟机的测试软件都属于第三方或用户资产，不适用本仓库的 MIT 许可。来源和授权边界见 [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md)。

English documentation: [README.en.md](README.en.md)

## 能做什么

- 可见 QEMU SDL 窗口，不使用无头 QEMU，适合人工观察启动、安装和渲染问题。
- Loongnix Desktop mini 镜像可能首次停在 `tty1`；脚本负责启动可见窗口，X11 桌面环境需要在虚拟机内安装/启用后才会出现。
- 默认启用用户态网络，宿主机 `127.0.0.1:2222` 转发到虚拟机 SSH `22`。
- 默认启用 DirectSound + Intel HDA 声卡，适合测试铃声、TTS、音频播放。
- 默认启用宿主机共享目录，方便把 Actions artifact 或本地包放入虚拟机。
- 使用 virtio 磁盘、virtio 网络、virtio GPU、USB tablet，并调高 QEMU 进程优先级，尽量提高 TCG 模拟效率。
- 支持快照模式和快速重置工作盘，方便反复测试。

## 目录约定

| 路径 | 作用 |
| --- | --- |
| `scripts/` | 启动、停止、下载镜像、重置磁盘、打包脚本 |
| `images/` | 放置 Loongnix 基础镜像和生成的工作盘，不提交到 Git |
| `shared/` | 宿主机和虚拟机之间交换测试包的目录，不提交内容 |
| `firmware/` | 工作用 UEFI 变量文件，不提交生成物 |
| `logs/` | 串口日志和最后一次 QEMU 参数 |
| `tools/qemu/` | 可选的便携 QEMU 目录，不提交到 Git |

## 快速开始

完整操作流程见 [docs/USAGE.zh-CN.md](docs/USAGE.zh-CN.md)。第一次使用时建议按下面顺序走：

1. 安装 QEMU。
2. 下载并校验 Loongnix 镜像。
3. 启动可见 QEMU 虚拟机窗口。
4. 如果 Loongnix mini 停在 `tty1`，先用 `root` 启用 SSH，再安装/启用 LightDM + Openbox 轻量测试桌面，见 [docs/USAGE.zh-CN.md#5-首次启动停在-tty1-时启用-ssh-并准备桌面环境](docs/USAGE.zh-CN.md#5-首次启动停在-tty1-时启用-ssh-并准备桌面环境)。
5. 把待测软件放入 `shared\`。
6. 在虚拟机桌面中复制到本地磁盘并运行。
7. 按 [docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md) 检查渲染、声音、网络、托盘和重启。

### 1. 安装 QEMU

推荐使用 winget 安装已测试过的 Windows QEMU：

```powershell
.\scripts\Install-Qemu-Windows.ps1
```

脚本默认安装 `SoftwareFreedomConservancy.QEMU` 的 `11.0.50`。如果你已经有 QEMU，也可以把 QEMU 目录放到 `tools\qemu`，或启动时传入 `-QemuDir`。

### 2. 下载 Loongnix 镜像并创建工作盘

```powershell
.\scripts\Download-LoongnixImage.ps1
```

脚本会下载：

```text
Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2
```

并校验：

```text
MD5    3ca44ded43023602deafaad416756cf7
SHA256 c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c
```

随后会创建 `images\loongnix-abi1-work.qcow2` 作为可写工作盘。

### 3. 启动可见 QEMU 窗口

双击：

```bat
Launch-Loongnix-Desktop.cmd
```

或在 PowerShell 中运行：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1
```

默认配置：

- 可见 SDL 窗口
- 6 vCPU
- 6144 MB 内存
- TCG multi-thread，`tb-size=1024`
- virtio 磁盘、网络、GPU、随机数设备
- USB 键盘和 USB tablet
- DirectSound + Intel HDA 音频
- SSH 转发：`127.0.0.1:2222 -> guest:22`
- `shared\` 作为额外 FAT/virtio 磁盘暴露给虚拟机

## 登录

Loongnix Desktop mini qcow2 默认账号：

| 用户 | 密码 |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

## SSH 是否必须

不必须。这个方案的主要用途是可见 QEMU 窗口中的 X11 桌面测试。首次启动时如果 Loongnix mini 停在 `tty1`，需要先按文档安装/启用桌面环境；进入图形桌面后，用户可以直接在 QEMU 窗口中打开终端并运行软件。

脚本已经自动配置了宿主机到虚拟机的端口转发：

```text
127.0.0.1:2222 -> guest:22
```

这只是 QEMU 网络转发规则，不等于虚拟机内的 SSH 服务一定已经启用。Loongnix mini 镜像首次启动时可能停在 `tty1`，必须先在 QEMU 窗口中用 `root` / `Loongson20` 登录，再用 root 权限启用 SSH：

```bash
systemctl enable ssh
systemctl start ssh
```

普通 `loongson` 用户不能直接启用系统服务；mini 镜像通常也没有 `sudo`。如果系统提示 `ssh.service` 不存在，仍然在 root shell 中安装 OpenSSH 服务：

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

然后在宿主机连接普通用户：

```powershell
ssh loongson@127.0.0.1 -p 2222
```

部分镜像默认禁止 root 通过 SSH 密码登录；这是正常现象，不影响使用 `loongson` 账号测试。

如果 `2222` 被占用，启动虚拟机时可以改端口：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1 -SshPort 2223
```

## 测试软件

把 LoongArch Linux 测试包放入：

```text
shared\
```

虚拟机内如果没有自动挂载共享盘：

```bash
lsblk
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb /mnt/hostshare
```

上面两条挂载命令需要 root 权限。如果当前是普通用户且系统没有 `sudo`，请先在终端中执行 `su -`，或直接在 `tty1` 使用 `root` / `Loongson20` 登录。

为了运行效率，建议先复制到虚拟机本地磁盘再解压/运行：

```bash
mkdir -p ~/testapp
cp -r /mnt/hostshare/YourApp/* ~/testapp/
cd ~/testapp
chmod +x ./YourApp
./YourApp
```

Avalonia/X11 软件建议从桌面终端启动，确保 `DISPLAY`、D-Bus、托盘和桌面会话环境正确。

更完整的检查清单见 [docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md)。

## 常用命令

```powershell
# GTK 显示后端
.\scripts\Start-Loongnix-Desktop.ps1 -Display gtk

# 降低资源占用
.\scripts\Start-Loongnix-Desktop.ps1 -Cores 4 -MemoryMB 4096

# 临时测试，退出后丢弃改动
.\scripts\Start-Loongnix-Desktop.ps1 -Snapshot

# 临时关闭声音
.\scripts\Start-Loongnix-Desktop.ps1 -NoAudio

# 关闭共享目录，提高少量 I/O 稳定性
.\scripts\Start-Loongnix-Desktop.ps1 -NoHostShare

# 停止本方案启动的 QEMU
.\scripts\Stop-Loongnix.ps1

# 重置工作盘
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars
```

## 效率建议

- LoongArch 在 Windows/x86 主机上只能使用 TCG 模拟，无法使用硬件虚拟化加速。
- 共享 FAT 盘适合传文件，不适合直接运行大型应用；解压和运行请尽量放到虚拟机本地磁盘。
- 默认 6 vCPU 是在 24 逻辑线程主机上的折中值；太多 vCPU 可能降低 TCG 效率。
- 多次测试同一软件时，用普通持久模式；只做一次性验证时用 `-Snapshot`。

## 在线打包

仓库内置 GitHub Actions：

```text
.github/workflows/package.yml
```

它会打包脚本和文档，但不会把 QEMU、Loongnix 镜像、工作盘、测试软件或日志打进源码包。用户可以在 Actions 中手动填写版本号并生成 artifact，也可以选择创建 GitHub Release。

## 许可

本仓库脚本和文档使用 MIT 许可。第三方组件的许可和来源见 [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md)。
