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

## 桌面环境预检

如果虚拟机停在 `tty1`，这只说明系统启动到了命令行，不代表已经具备 ClassIsland 图形验收环境。先按 [USAGE.zh-CN.md 第 5 节](USAGE.zh-CN.md#5-首次启动停在-tty1-时启用-ssh-并准备桌面环境) 用 root 运行 `shared\setup-loongnix-test-desktop.sh`，或按手动教程启用 SSH 并安装/启用 X11 桌面。

进入图形桌面后，在桌面终端中确认：

```bash
echo "$DISPLAY"
echo "$XDG_SESSION_TYPE"
echo "$XDG_CURRENT_DESKTOP"
ps -ef | grep -E 'lightdm|Xorg|loongnix-test-session|xfwm4|xfce4-panel|wrapper|lxterminal|xfe|plasmashell|kwin' | grep -v grep
```

期望：

- `DISPLAY` 有值，例如 `:0`。
- 会话类型是 X11，或至少能启动 X11 应用。
- 有可见桌面、面板/托盘区域、终端和图形文件管理器。按推荐轻量方案安装时，通常能看到 `lightdm`、`Xorg`、`loongnix-test-session`、`xfwm4`、`xfce4-panel`、`wrapper-2.0`、`lxterminal` 和 `xfe`。

只有 SSH 能连接、但没有可见 X11 桌面时，只能做命令行诊断；不能算完成 Avalonia/X11 渲染、托盘、声音验收。

## SSH 检查（可选）

可见桌面测试不依赖 SSH。只有需要从宿主机远程执行命令、复制文件或抓日志时，才需要启用虚拟机内的 SSH 服务。

QEMU 启动脚本默认已经配置：

```text
127.0.0.1:2222 -> guest:22
```

如果虚拟机内没有开启 SSH，只能先在 QEMU `tty1` 中用 `root` / `Loongson20` 登录，再用 root 权限执行：

```bash
systemctl enable ssh
systemctl start ssh
```

普通 `loongson` 用户不能直接启用系统服务；mini 镜像通常也没有 `sudo`。如果没有 `ssh.service`，仍然在 root shell 中安装：

```bash
apt update
apt install openssh-server
systemctl enable --now ssh
```

宿主机连接：

```powershell
ssh loongson@127.0.0.1 -p 2222
```

启用服务必须用 root；服务启动后，宿主机侧优先连接 `loongson` 用户。部分镜像默认禁止 root 通过 SSH 密码登录，这是正常现象。

## 共享目录

如果共享盘没有自动挂载：

```bash
lsblk
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
```

挂载命令需要 root 权限；普通用户如果没有 `sudo`，请先 `su -` 或用 root 登录 `tty1`。

复制到本地磁盘后运行：

```bash
mkdir -p ~/testapp
cp -r /mnt/hostshare/YourApp/* ~/testapp/
cd ~/testapp
```

## Avalonia/.NET 软件检查

从桌面终端启动应用，观察：

- ClassIsland 在虚拟机中渲染正常，不代表实机 GLX/EGL 路径一定正常。QEMU 推荐配置通常关闭硬件 OpenGL，Avalonia 会更容易落到软件渲染；Kylin/Loongnix 实机可能暴露 GLX/EGL，旧世界 ABI1.0 下可能出现大面积红色/白色色块。测试 ClassIsland LoongArch old-world 包时，请优先使用默认 `CLASSISLAND_X11_RENDERING=software` 的新包。
- 主窗口能完整渲染，没有黑屏、透明异常、左上角残留黑块或明显闪退。
- 字体、缩放、弹窗、设置页和列表能正常显示。
- 托盘图标出现，左键/右键菜单可用，托盘恢复窗口可用。
- 音频功能可听见声音，包括铃声、TTS 或测试播放按钮。
- 网络功能可访问远端服务。
- 应用重启、关闭再打开后仍正常。
- 能用 Xfe 图形文件管理器浏览本地测试目录和挂载后的共享盘目录。
- 日志中没有原生库加载失败、`GLIBC` 版本不匹配、SkiaSharp/HarfBuzzSharp 缺失等错误。

## 声音检查

虚拟机启动时默认使用 DirectSound + Intel HDA。虚拟机内可用下面方式做基础声音测试：

```bash
speaker-test -t wav -c 2
```

如果应用依赖 `ffmpeg`/`ffplay`：

```bash
which ffplay || apt install ffmpeg
ffplay /path/to/test.wav
```

安装软件包需要 root 权限。

## 托盘检查

在推荐的 Loongnix X11 Test Desktop 中测试托盘时，建议确认：

```bash
echo "$XDG_CURRENT_DESKTOP"
echo "$DESKTOP_SESSION"
ps -ef | grep -E 'xfwm4|xfce4-panel|wrapper-2.0|wrapper-1.0' | grep -v grep
dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply / org.freedesktop.DBus.ListNames | grep -E 'StatusNotifierWatcher|StatusNotifierItem'
```

`wrapper-2.0` 加载的是 Xfce panel 的 StatusNotifier 插件，负责 ClassIsland/Avalonia 这类应用常用的 `org.kde.StatusNotifierWatcher`；`wrapper-1.0` 是传统 systray 插件。然后在应用内执行托盘菜单、隐藏到托盘、从托盘恢复、退出等操作。托盘图标属于本环境必须人工验收的项目。

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
