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

## 5. 放入待测软件

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

## 6. 在虚拟机中挂载共享盘

打开 Loongnix 桌面终端，查看磁盘：

```bash
lsblk
```

如果共享盘没有自动挂载，通常可以这样挂载：

```bash
sudo mkdir -p /mnt/hostshare
sudo mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
```

如果 `/dev/vdb` 不是共享盘，根据 `lsblk` 输出选择另一个新增磁盘。

## 7. 复制到虚拟机本地磁盘

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

## 8. 启动应用

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

## 9. 人工验收项目

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

## 10. 记录测试结果

建议记录：

- 待测 artifact 文件名。
- GitHub Actions run 链接或 Release 链接。
- 虚拟机启动参数：`logs\last-qemu-args.txt`。
- 串口日志：`logs\serial-*.log`。
- 应用日志。
- 关键界面截图。
- 人工验收结论，例如“渲染正常，托盘可用，有声音”。

## 11. 重置环境

如果测试把系统改乱了，先关闭 QEMU，然后运行：

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars
```

默认会创建基于基础镜像的 qcow2 后备工作盘，速度快、体积小。如果你想生成完整复制的工作盘：

```powershell
.\scripts\Reset-WorkDisk.ps1 -Force -ResetFirmwareVars -FullCopy
```

## 12. 常见问题

### QEMU 窗口打开了，但很慢

这是正常的。Windows/x86 主机模拟 LoongArch 只能使用 TCG。建议把应用复制到虚拟机本地磁盘后运行，并减少后台程序。

### 没声音

确认启动时没有传 `-NoAudio`，并在虚拟机里测试：

```bash
speaker-test -t wav -c 2
```

如果应用依赖 `ffplay`：

```bash
which ffplay || sudo apt install ffmpeg
```

### 看不到共享盘

确认启动时没有传 `-NoHostShare`，然后在虚拟机里执行 `lsblk`。必要时重启虚拟机。

### SSH 连不上

SSH 不是必须项。需要 SSH 时，先在虚拟机内安装并启动 `openssh-server`，再从宿主机连接 `127.0.0.1:2222`。
