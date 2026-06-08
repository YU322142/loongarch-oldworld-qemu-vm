# 测试检查清单

这份清单用于测试 LoongArch 旧世界 ABI1.0 Linux/X11 桌面软件，尤其是 .NET/Avalonia 应用。

## 启动前

1. 安装 QEMU。
2. 下载并校验 Loongnix qcow2。
3. 生成 `images\loongnix-abi1-work.qcow2`。
4. 把待测软件放到 `shared\`。
5. 启动虚拟机时保持默认声音、网络和共享目录开启。

## 虚拟机内基础检查

```bash
uname -m
getconf GNU_LIBC_VERSION
echo "$XDG_SESSION_TYPE"
echo "$DISPLAY"
ip route
ping -c 3 github.com
```

期望结果：

- 架构为 `loongarch64`。
- 桌面会话应能提供 X11 环境。
- 能访问网络。

## 共享目录

如果共享盘没有自动挂载：

```bash
lsblk
sudo mkdir -p /mnt/hostshare
sudo mount -t vfat /dev/vdb /mnt/hostshare
```

复制到本地磁盘后运行：

```bash
mkdir -p ~/testapp
cp -r /mnt/hostshare/YourApp/* ~/testapp/
cd ~/testapp
```

## Avalonia/.NET 软件检查

从桌面终端启动应用，观察：

- 主窗口能完整渲染，没有黑屏、透明异常、左上角残留黑块或明显闪退。
- 字体、缩放、弹窗、设置页和列表能正常显示。
- 托盘图标出现，左键/右键菜单可用，托盘恢复窗口可用。
- 音频功能可听见声音，包括铃声、TTS 或测试播放按钮。
- 网络功能可访问远端服务。
- 应用重启、关闭再打开后仍正常。
- 日志中没有原生库加载失败、`GLIBC` 版本不匹配、SkiaSharp/HarfBuzzSharp 缺失等错误。

## 声音检查

虚拟机启动时默认使用 DirectSound + Intel HDA。虚拟机内可用下面方式做基础声音测试：

```bash
speaker-test -t wav -c 2
```

如果应用依赖 `ffmpeg`/`ffplay`：

```bash
which ffplay || sudo apt install ffmpeg
ffplay /path/to/test.wav
```

## 托盘检查

在 KDE/X11 中测试托盘时，建议确认：

```bash
echo "$XDG_CURRENT_DESKTOP"
echo "$DESKTOP_SESSION"
```

然后在应用内执行托盘菜单、隐藏到托盘、从托盘恢复、退出等操作。托盘图标属于本环境必须人工验收的项目。

## 记录问题

建议保留：

- `logs\last-qemu-args.txt`
- `logs\serial-*.log`
- 应用日志
- 关键界面截图
- 待测 artifact 文件名和来源 Actions run

## 已知边界

- Windows/x86 主机上运行 LoongArch 只能使用 QEMU TCG 模拟，速度无法等同真机。
- 共享 FAT 盘适合传文件，不适合直接运行大型应用。
- 工作盘可能包含隐私和测试状态，不建议公开发布。
