# 使用虚拟机测试软件

这份文档按实际测试流程写，适合第一次拿到本项目的用户照着操作。它假设你在 Windows 主机上使用 PowerShell，并希望看到完整 Linux X11 桌面，而不是无头 QEMU。

## 1. 准备项目目录

克隆仓库后进入目录：

```powershell
git clone https://github.com/YU322142/loongarch-oldworld-qemu-vm.git
cd loongarch-oldworld-qemu-vm
```

确认 PowerShell 可以执行本地脚本：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

这只影响当前 PowerShell 窗口。

## 2. 安装 QEMU

推荐直接用仓库脚本安装已测试过的 Windows QEMU：

```powershell
.\scripts\Install-Qemu-Windows.ps1
```

如果你已经安装了 QEMU，可以跳过这一步。启动时脚本会尝试从下面位置寻找 QEMU：

- `tools\qemu`
- `C:\Program Files\qemu`
- `C:\Program Files (x86)\qemu`
- 系统 `PATH`

如果 QEMU 在其他目录，启动时传入：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

## 3. 下载系统镜像并生成工作盘

运行：

```powershell
.\scripts\Download-LoongnixImage.ps1
```

脚本会下载 Loongnix Desktop mini qcow2，校验 MD5/SHA256，并创建：

```text
images\loongnix-abi1-work.qcow2
```

这个工作盘会保存系统设置、安装的软件和测试状态。不要把它提交到 Git。

## 4. 启动可见桌面虚拟机

双击：

```bat
Launch-Loongnix-Desktop.cmd
```

或运行：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1
```

默认会开启：

- 可见 SDL 桌面窗口。
- 用户态网络。
- DirectSound + Intel HDA 声音。
- 宿主机 `shared\` 共享盘。
- SSH 端口转发 `127.0.0.1:2222 -> guest:22`。

登录 Loongnix：

| 用户 | 密码 |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

桌面测试不需要 SSH。SSH 只是可选的远程命令入口。

如果首次启动停在 `tty1`，必须先用 `root` / `Loongson20` 登录，并在 root shell 中启用 SSH，方便后续从宿主机复制命令、挂载共享盘和抓日志：

```bash
systemctl enable ssh
systemctl start ssh
```

然后在宿主机连接普通用户：

```powershell
ssh loongson@127.0.0.1 -p 2222
```

普通 `loongson` 用户不能直接启用系统服务；mini 镜像通常也没有 `sudo`。如果 `ssh.service` 不存在，仍然在 root shell 中安装：

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

注意：`root` 已经是管理员账号，在 root shell 里不需要 `sudo`；部分镜像默认禁止 root 通过 SSH 密码登录，请用 `loongson` 账号连接。

## 5. 首次启动停在 tty1 时启用 SSH 并准备桌面环境

公开下载的 Loongnix Desktop mini qcow2 可能不会直接进入图形登录器，而是停在控制台：

```text
Loongnix GNU/Linux 20 Release 6 loongson-pc tty1
loongson-pc login:
```

这不是 QEMU 启动失败。先用 `root` / `Loongson20` 登录。启用 SSH、安装软件包、启用显示管理器都需要 root 权限；root shell 中不需要 `sudo`。

### 5.1 启用 SSH

SSH 只能由 root 权限启用。先在 QEMU `tty1` 中用 `root` / `Loongson20` 登录，然后执行：

```bash
systemctl enable ssh
systemctl start ssh
systemctl status ssh --no-pager
```

宿主机连接普通用户：

```powershell
ssh loongson@127.0.0.1 -p 2222
```

如果系统提示没有 `ssh.service`，仍然在 root shell 中安装 OpenSSH：

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

部分镜像默认禁止 root 通过 SSH 密码登录，这是正常现象。用 `loongson` 账号 SSH 登录；需要 root 权限时在虚拟机内执行 `su -`。

### 5.2 诊断桌面组件是否已安装

在 root shell 中执行：

```bash
systemctl get-default
systemctl list-unit-files | grep -E 'sddm|lightdm|gdm|display|xdm'
ls /usr/bin/Xorg /usr/bin/startplasma-x11 /usr/bin/kwin_x11 /usr/bin/startkde 2>/dev/null
```

判断方法：

| 输出情况 | 含义 | 下一步 |
| --- | --- | --- |
| 有 `sddm.service`、`lightdm.service` 或其他 display manager | 图形登录器已安装 | 直接启动对应服务 |
| 有 Xorg/KDE 程序但没有 display manager | 已有部分桌面组件 | 安装或启用显示管理器 |
| 几乎没有输出 | mini 镜像缺少桌面环境 | 按下面步骤安装 |

如果已经安装了 `sddm`：

```bash
systemctl start sddm
systemctl enable sddm
systemctl set-default graphical.target
```

如果显示管理器是 `lightdm`，把命令中的 `sddm` 换成 `lightdm`。

### 5.3 安装 KDE/Plasma 桌面环境

下面安装桌面环境的命令都需要 root 权限。如果你是通过 SSH 连接进来的 `loongson` 用户，请先在虚拟机内执行 `su -` 切到 root。先确认网络和 apt 源可用：

```bash
ip route
ping -c 3 pkg.loongnix.cn
apt update
```

推荐先安装基础 X11、D-Bus、声音工具、SSH 和显示管理器：

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio sddm
```

再安装 KDE/Plasma 桌面组件：

```bash
apt install plasma-desktop konsole dolphin
```

如果软件源里包名不同，先搜索可用包：

```bash
apt-cache search plasma-desktop
apt-cache search kde | grep -E 'desktop|plasma'
apt-cache search sddm
```

安装完成后启用图形登录并重启：

```bash
systemctl enable sddm
systemctl set-default graphical.target
reboot
```

重启后 QEMU 窗口应进入图形登录器。使用 `loongson` / `Loongson20` 登录桌面。

### 5.4 KDE 不可用时安装轻量桌面备用方案

如果 Loongnix 源里没有 Plasma/KDE 组件，可以先安装 Xfce 作为测试壳。它足够用于 Avalonia/X11 渲染、窗口、声音和托盘验收：

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfce4 xfce4-terminal
systemctl enable lightdm
systemctl set-default graphical.target
reboot
```

重启后用 `loongson` 登录 Xfce 桌面，再继续运行 ClassIsland。若托盘区域默认不可见，请在面板中启用通知区域/状态托盘插件。

### 5.5 为什么不能只在 tty 或 SSH 中验收

ClassIsland、OpenRemoteShouter 这类 Avalonia/X11 软件必须在真实 X11 桌面会话里验收。至少需要检查：

- Skia/Avalonia 渲染是否正常。
- 托盘图标是否出现，菜单能否点击。
- D-Bus、桌面通知、窗口隐藏/恢复是否工作。
- 声音播放是否能在桌面会话中听见。
- 应用关闭、重启、再次启动是否正常。

SSH 可以用于传文件、挂载共享盘和抓日志，但不能替代最终图形验收。

## 6. 放入待测软件

把 Actions artifact、Release 包或本地构建包放到宿主机：

```text
shared\
```

示例：

```text
shared\ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz
shared\OpenRemoteShouter-linux-loongarch64-oldworld-abi1.0.tar.gz
```

如果虚拟机已经启动，FAT 共享盘通常仍能看到新文件；如果没有看到，可以在虚拟机里重新挂载或重启虚拟机。

## 7. 在虚拟机中挂载共享盘

打开 Loongnix 桌面终端，查看磁盘：

```bash
lsblk
```

如果共享盘没有自动挂载，通常可以这样挂载：

```bash
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
```

挂载命令需要 root 权限。如果你当前是 `loongson` 用户，先执行 `su -` 切到 root。

如果 `/dev/vdb` 不是共享盘，根据 `lsblk` 输出选择另一个新增磁盘。

## 8. 复制到虚拟机本地磁盘

不要直接在共享 FAT 盘上运行大型应用。先复制到虚拟机本地磁盘：

```bash
mkdir -p ~/tests
cp /mnt/hostshare/ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz ~/tests/
cd ~/tests
tar -xf ClassIsland-misha-alpha-ci-linux-loongarch64-net10.tar.gz
```

如果是 zip：

```bash
unzip /mnt/hostshare/YourApp.zip -d ~/tests/YourApp
```

## 9. 启动应用

建议从 Loongnix 桌面终端启动，而不是从 SSH 启动。这样 `DISPLAY`、D-Bus、托盘、声音和桌面会话变量更接近真实用户环境。

示例：

```bash
cd ~/tests/ClassIsland-misha-alpha-ci-linux-loongarch64-net10/ClassIsland
chmod +x ./ClassIsland
./ClassIsland
```

如果应用有启动脚本，优先使用项目提供的脚本：

```bash
bash run.sh
```

运行时保留终端窗口，方便看到原生库加载错误、GLIBC 版本错误、渲染后端错误或声音调用错误。

## 10. 人工验收项目

至少检查下面内容：

| 项目 | 怎么看 |
| --- | --- |
| 启动 | 应用能打开，终端没有明显崩溃错误 |
| 渲染 | 主窗口、弹窗、设置页、列表、字体、缩放正常，没有黑屏或异常色块 |
| 原生库 | 日志里没有 SkiaSharp/HarfBuzzSharp 加载失败，没有 `GLIBC` 版本不匹配 |
| 网络 | 应用需要联网的功能能访问远端 |
| 声音 | 铃声、TTS、测试播放按钮或音频功能能听见 |
| 托盘 | 托盘图标出现，左键/右键菜单、隐藏、恢复、退出可用 |
| 重启 | 应用关闭后再次启动正常，应用内重启功能正常 |
| 配置 | 修改设置、保存、重开后仍正常 |

ClassIsland 这类 Avalonia 桌面应用建议额外测试：

- 初始引导流程。
- 课程/时间相关界面。
- 设置页面和外观页面。
- 通知或提醒窗口。
- 托盘菜单和托盘恢复。
- 语音/铃声测试。
- 关闭、最小化、重启。

OpenRemoteShouter 这类远程/音频应用建议额外测试：

- 网络连接。
- 主窗口渲染。
- 音频播放。
- D-Bus/桌面唤起行为。
- 关闭后再次启动。

## 11. 记录测试结果

建议记录：

- 待测 artifact 文件名。
- GitHub Actions run 链接或 Release 链接。
- 虚拟机启动参数：`logs\last-qemu-args.txt`。
- 串口日志：`logs\serial-*.log`。
- 应用日志。
- 关键界面截图。
- 人工验收结论，例如“渲染正常，托盘可用，有声音”。

## 12. 重置环境

如果测试把系统改乱了，先关闭 QEMU，然后运行：

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars
```

默认会创建基于基础镜像的 qcow2 后备工作盘，速度快、体积小。如果你想生成完整复制的工作盘：

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars -FullCopy
```

## 13. 常见问题

### QEMU 窗口打开了，但很慢

这是正常的。Windows/x86 主机模拟 LoongArch 只能使用 TCG。建议把应用复制到虚拟机本地磁盘后运行，并减少后台程序。

### 没声音

确认启动时没有传 `-NoAudio`，并在虚拟机里测试：

```bash
speaker-test -t wav -c 2
```

如果应用依赖 `ffplay`：

```bash
which ffplay || apt install ffmpeg
```

安装软件包需要 root 权限；普通用户请先 `su -`。

### 看不到共享盘

确认启动时没有传 `-NoHostShare`，然后在虚拟机里执行 `lsblk`。必要时重启虚拟机。

### SSH 连不上

SSH 不是必须项。需要 SSH 时，先在 QEMU 窗口的 `tty1` 中用 `root` / `Loongson20` 登录，然后用 root 权限执行：

```bash
systemctl enable ssh
systemctl start ssh
```

如果没有 `ssh.service`，仍然在 root shell 中安装：

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

宿主机连接普通用户：

```powershell
ssh loongson@127.0.0.1 -p 2222
```

### 停在 tty1，没有桌面

这是 Loongnix mini 镜像可能出现的正常状态。按第 5 节用 root 启用 SSH、检查显示管理器，并安装/启用 X11 桌面环境。桌面安装完成前只能做命令行诊断，不能算完成 Avalonia/X11 图形验收。
