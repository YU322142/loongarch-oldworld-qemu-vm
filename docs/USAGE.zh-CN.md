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

这个脚本会先通过 winget 安装 QEMU，并默认尝试直接安装到本仓库的 `tools\qemu`。如果 QEMU installer 不支持 `--location`，脚本会退回系统安装，再把安装目录复制到 `tools\qemu`。这样后续 `Download-LoongnixImage.ps1`、`Start-Loongnix-Desktop.ps1` 和 `Reset-WorkDisk.ps1` 都能优先从项目目录找到 `qemu-img.exe` 和 `qemu-system-loongarch64.exe`。

`tools\qemu` 会被 Git 忽略，也不会打进本项目 Release。不要把 QEMU 二进制提交到仓库；如果要再分发 QEMU，需要遵守 QEMU 及其依赖库的许可证要求。

如果你只想安装到系统位置，不想复制到 `tools\qemu`：

```powershell
.\scripts\Install-Qemu-Windows.ps1 -NoCopyToRepo
```

如果你已经安装了 QEMU，也可以重新运行上面的脚本把当前 QEMU 复制到 `tools\qemu`。如果 QEMU 装在脚本找不到的位置，把 QEMU 目录传给安装脚本：

```powershell
.\scripts\Install-Qemu-Windows.ps1 -QemuDir D:\Path\To\qemu
```

启动时脚本会尝试从下面位置寻找 QEMU：

- `tools\qemu`
- `C:\Program Files\qemu`
- `C:\Program Files (x86)\qemu`
- 系统 `PATH`

如果 QEMU 在其他目录，启动时也可以传入：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

也可以把便携 QEMU 解压或复制到：

```text
tools\qemu\qemu-system-loongarch64.exe
```

本仓库和 Release 不包含 QEMU 二进制。如果没有安装 QEMU、没有把 QEMU 放到 `tools\qemu`，也没有传 `-QemuDir`，启动脚本会报：

```text
qemu-system-loongarch64.exe was not found
```

这不是 Loongnix 镜像问题，而是 Windows 主机上还没有给脚本提供 QEMU 路径。

## 3. 下载系统镜像并生成工作盘

运行：

```powershell
.\scripts\Download-LoongnixImage.ps1
```

脚本会默认使用 64 路 HTTP Range 并发下载 Loongnix Desktop mini qcow2，校验 MD5/SHA256，并创建：

```text
images\loongnix-abi1-work.qcow2
```

下载线程数可以按网络情况修改，取值范围是 `1` 到 `64`。如果某个分段连接中途断开，脚本会从该分段已写入的位置继续请求剩余 byte range；如果网络或代理仍然不稳定，可以降到 `16` 或 `8`。如果服务器不支持 HTTP Range，脚本会自动退回单连接下载：

```powershell
.\scripts\Download-LoongnixImage.ps1 -Connections 16
.\scripts\Download-LoongnixImage.ps1 -Connections 8 -DownloadRetries 5
.\scripts\Download-LoongnixImage.ps1 -Connections 1
```

这个工作盘会保存系统设置、安装的软件和测试状态。不要把它提交到 Git。

创建工作盘需要 Windows 主机上能找到 `qemu-img.exe`。如果你看到 `Verified image` 后又出现 `qemu-img.exe was not found`，说明镜像已经下载并校验成功，只是还没有创建工作盘。先按第 2 节安装 QEMU，或把 QEMU 目录传给脚本：

```powershell
.\scripts\Download-LoongnixImage.ps1 -QemuDir D:\Path\To\qemu
```

如果只想先下载和校验镜像，不创建工作盘：

```powershell
.\scripts\Download-LoongnixImage.ps1 -SkipWorkDisk
```

## 4. 启动可见 QEMU 虚拟机窗口

如果 QEMU 已经安装在脚本能找到的位置，可以双击：

```bat
Launch-Loongnix-Desktop.cmd
```

`Launch-Loongnix-Desktop.cmd` 是 CMD 包装入口，会把后面的参数转交给 PowerShell 脚本。QEMU 不在默认位置时，用下面的方式启动：

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu
```

直接运行 `.ps1` 时，Windows 可能因执行策略拒绝脚本：

```text
因为在此系统上禁止运行脚本
```

这种情况下，任选一种方式：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

或不改变当前窗口策略，直接用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-Loongnix-Desktop.ps1 -QemuDir D:\Path\To\qemu
```

如果要复用其它目录中的工作盘和共享目录：

```powershell
.\Launch-Loongnix-Desktop.cmd -QemuDir D:\Path\To\qemu -DiskPath D:\Path\To\loongnix-abi1-work.qcow2 -SharePath D:\Path\To\shared
```

常用参数：

| 参数 | 作用 |
| --- | --- |
| `-QemuDir` | 指定包含 `qemu-system-loongarch64.exe` 的 QEMU 目录。 |
| `-DiskPath` | 指定要启动的 qcow2 工作盘。 |
| `-SharePath` | 指定暴露给虚拟机的宿主机共享目录。 |
| `-SshPort` | 指定宿主机 SSH 转发端口，默认 `2222`。 |
| `-Cores` / `-MemoryMB` | 调整虚拟机 vCPU 数和内存。 |
| `-Snapshot` | 临时运行，退出后丢弃磁盘改动。 |
| `-NoHostShare` | 禁用宿主机共享盘。 |
| `-NoAudio` | 禁用虚拟声卡。 |
| `-NoWait` | 启动 QEMU 后让 PowerShell 立即返回；默认会等待 QEMU 窗口关闭。 |

默认会开启：

- 可见 SDL 窗口。
- 用户态网络。
- DirectSound + Intel HDA 声音。
- 宿主机 `shared\` 共享盘。
- SSH 端口转发 `127.0.0.1:2222 -> guest:22`。

启动过程中如果 QEMU 窗口暂时黑屏、白屏或没有稳定 guest 画面，请把鼠标指针移到 QEMU 窗口外。实测真正容易触发卡住的是无显示画面阶段鼠标停留在虚拟机窗口内，而不是“最大化”本身。等进入 LightDM 登录器或 Loongnix X11 Test Desktop 并稳定显示后，再进行鼠标操作。如果已经卡住或 QEMU 退出，关闭 QEMU 窗口后重新启动；必要时用 `-Snapshot` 做临时测试，避免启动阶段误操作影响工作盘状态。

桌面环境稳定显示后可以按需调整窗口，但建议在验收过程中保持窗口大小稳定。实测 SDL 窗口大小变化后可能导致鼠标点击位置偏移，表现为光标看起来在按钮、菜单或托盘图标上，但实际点击落在其它位置。进行托盘、菜单、按钮和窗口拖拽验收时，请先确认鼠标点击位置正常；如果已经出现偏移，先尝试把窗口恢复到原大小，仍不正常就关闭 QEMU 后重新启动。

启动后 PowerShell 没有立刻返回是正常行为：默认脚本会一直等待 QEMU 窗口关闭。需要启动后立即回到 PowerShell 时使用：

```powershell
.\scripts\Start-Loongnix-Desktop.ps1 -NoWait
```

串口日志可能停在 `Loading Linux ...` 或 `Loading initial ramdisk ...` 附近，因为 GRUB 已经把控制权交给 Linux；此时继续看可见 QEMU 窗口，不要只按串口日志判断是否卡住。

如果串口日志停在 `Loading initial ramdisk ...`，同时 QEMU 进程已经退出、SSH 端口也没有打开，则表示这次启动已经失败；重新启动前请确认鼠标不在黑屏/无画面的 QEMU 窗口内。

登录 Loongnix：

| 用户 | 密码 |
| --- | --- |
| `loongson` | `Loongson20` |
| `root` | `Loongson20` |

桌面测试不依赖 SSH，但首次停在 `tty1` 时，SSH 只能先在 `tty1` 里由 root 启用。启用后，SSH 只是可选的远程命令入口。

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

## 4.1 脚本作用速查

| 脚本 | 作用 |
| --- | --- |
| `Launch-Loongnix-Desktop.cmd` | CMD 启动入口；用 `-ExecutionPolicy Bypass` 调用 `scripts\Start-Loongnix-Desktop.ps1`，并转发参数。 |
| `scripts\Start-Loongnix-Desktop.ps1` | 启动可见 QEMU 窗口，配置磁盘、UEFI、网络、声音、SSH 转发和共享盘。 |
| `scripts\Install-Qemu-Windows.ps1` | 用 winget 安装 Windows QEMU，并默认复制到 `tools\qemu`。 |
| `scripts\Download-LoongnixImage.ps1` | 下载/校验 Loongnix 镜像，并创建 `images\loongnix-abi1-work.qcow2`。 |
| `scripts\Stop-Loongnix.ps1` | 停止匹配的 QEMU 进程。 |
| `scripts\Reset-WorkDisk.ps1` | 重建工作盘，会清空虚拟机内测试状态。 |
| `scripts\Package-Release.ps1` | 打包脚本和文档用于 Release，不包含 QEMU、镜像、工作盘、测试软件或日志。 |

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

### 5.2 使用共享目录脚本一键配置（推荐）

本仓库在 `shared\` 中提供 guest 端一键配置脚本：

```text
shared\setup-loongnix-test-desktop.sh
```

它会在 Loongnix 内完成下面这些操作：

- 启用 SSH 服务。
- 安装 X11、LightDM、`xfwm4` 合成窗口管理器、Xfce panel、StatusNotifier/systray 托盘插件、`xfdesktop4` 壁纸/桌面背景管理器、LXTerminal、Xfe 图形文件管理器、`feh` 壁纸回退工具、声音工具和通知支持。
- 生成 `zh_CN.UTF-8` locale，安装中文字体，并把系统默认语言尽量切到中文。
- 把时区设置为 `Asia/Shanghai`。
- 配置 LightDM 默认进入 `loongnix-test` 会话，并建立 `display-manager.service` 链接，避免重启后只停在 `tty1`。
- 默认启用 `loongson` 自动登录，方便反复测试。
- 默认把共享目录中的 `pic.png` 复制为 `loongson` 用户壁纸，并在会话启动时优先交给 `xfdesktop4` 管理；如果 `xfdesktop4` 不可用，则用 `feh` 回退设置；如果没有 `pic.png`，则回退到纯色背景。

如果虚拟机停在 `tty1`，先用 `root` / `Loongson20` 登录，然后挂载共享盘并运行脚本：

```bash
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
mountpoint /mnt/hostshare
ls /mnt/hostshare
sh /mnt/hostshare/setup-loongnix-test-desktop.sh
systemctl reboot
```

如果 `mountpoint /mnt/hostshare` 提示 `not a mountpoint`，说明 `/mnt/hostshare` 只是普通空目录，还没有挂载成功。先用 `lsblk` 找到共享盘，再重新挂载。实测 QEMU 的 `fat:rw` 共享盘通常显示为 `vdb` 磁盘和 `vdb1` 分区，优先挂载 `/dev/vdb1`。FAT 共享盘上的脚本不一定有可执行权限，所以推荐用 `sh 脚本路径` 运行。

常用自定义方式：

```bash
# 保留 LightDM 登录界面，不自动登录
AUTOLOGIN=0 sh /mnt/hostshare/setup-loongnix-test-desktop.sh

# 不修改系统语言
SET_CHINESE=0 sh /mnt/hostshare/setup-loongnix-test-desktop.sh

# 使用其它壁纸文件
WALLPAPER_SOURCE=/mnt/hostshare/other.png sh /mnt/hostshare/setup-loongnix-test-desktop.sh

# 配置完成后自动重启
REBOOT_AFTER=1 sh /mnt/hostshare/setup-loongnix-test-desktop.sh
```

脚本执行完并重启后，QEMU 窗口应进入 Loongnix X11 Test Desktop；默认能看到 Xfce panel 托盘、LXTerminal 和 Xfe 文件管理器。这个会话使用 `xfwm4 --compositor=on`，用于覆盖 ClassIsland 这类 Avalonia 透明窗口；托盘同时提供 StatusNotifier 和传统 systray；壁纸默认由 `xfdesktop4` 管理，避免启动时先显示图片、随后又被覆盖成灰色。脚本执行失败或你想调整安装内容时，继续按下面的手动教程操作。

### 5.3 诊断桌面组件是否已安装

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
| 几乎没有输出 | mini 镜像缺少桌面环境 | 安装 LightDM + Loongnix X11 Test Desktop 轻量测试桌面 |

本项目实测的公开 Loongnix mini 镜像初始状态是：`ssh.service` 已可由 root 启用，`systemctl get-default` 为 `graphical.target`，但没有 `sddm/lightdm`，也没有 `/usr/bin/Xorg`、`startplasma-x11`、`kwin_x11` 等桌面组件。因此即使启动脚本打开了可见 QEMU 窗口，也仍然需要安装桌面环境。

如果已经安装了 `sddm`：

```bash
systemctl start sddm
systemctl enable sddm
systemctl set-default graphical.target
```

如果显示管理器是 `lightdm`，把命令中的 `sddm` 换成 `lightdm`。

如果安装过程被中断，先确认没有 apt/dpkg 进程正在运行，并检查包数据库状态：

```bash
ps -ef | grep -E 'apt|dpkg' | grep -v grep
dpkg --audit
```

`dpkg --audit` 没有输出时，通常可以继续安装。若它提示有未配置的软件包，先执行：

```bash
dpkg --configure -a
apt --fix-broken install
```

### 5.4 手动安装 LightDM + Loongnix X11 Test Desktop

下面安装桌面环境的命令都需要 root 权限。如果你是通过 SSH 连接进来的 `loongson` 用户，请先在虚拟机内执行 `su -` 切到 root。先确认网络和 apt 源可用。mini 镜像可能没有 `ip` 命令，可以用 `ifconfig` 代替；安装 `iproute2` 后才会有 `ip`：

```bash
ip route || ifconfig
ping -c 3 pkg.loongnix.cn
apt update
```

推荐安装 X11、D-Bus、声音工具、OpenSSH、LightDM、`xfwm4`、Xfce panel、StatusNotifier/systray 托盘插件、`xfdesktop4` 壁纸/桌面背景管理器、LXTerminal、Xfe 图形文件管理器、`feh` 壁纸回退工具、通知支持、中文字体、locale 工具和 `iproute2`。这个组合比 KDE/Plasma 轻得多，但仍能覆盖 Avalonia/X11 渲染、透明窗口合成、声音、通知、托盘图标、稳定壁纸和图形文件浏览验收：

可以先模拟安装，确认依赖能解析：

```bash
apt-get -s install lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin xfdesktop4 lxterminal xfe feh xfce4-notifyd libnotify-bin fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin libayatana-appindicator3-1 libappindicator3-1 ayatana-indicator-application xfdesktop4 lxterminal xfe feh xfce4-notifyd libnotify-bin x11-xserver-utils iproute2 locales fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

配置中文系统语言、中文字体缓存和中国时区：

```bash
sed -i 's/^[#[:space:]]*zh_CN.UTF-8[[:space:]]\+UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^zh_CN.UTF-8 UTF-8' /etc/locale.gen || echo 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen zh_CN.UTF-8 en_US.UTF-8
update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_MESSAGES=zh_CN.UTF-8
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo Asia/Shanghai >/etc/timezone
fc-cache -f
```

中文设置应用到新的登录会话后才完整生效。建议在 `loongson` 桌面终端或 SSH 会话中运行 `locale` 检查；从已有终端里切到 root 的 `su` shell 可能仍显示 `POSIX`，这不代表桌面用户语言配置失败。

创建 `loongnix-test` 会话。它直接启动 `xfwm4 --compositor=on`，再启动 Xfce panel、LXTerminal 和 Xfe，并在会话启动时强制配置 Xfce panel 的 StatusNotifier 和 systray 插件。托盘测试依赖 `org.kde.StatusNotifierWatcher`，不要省略下面的面板配置函数：

```bash
cat >/usr/local/bin/loongnix-test-session <<'EOF'
#!/bin/sh
USER_ID="$(id -u)"
export LANG="${LANG:-zh_CN.UTF-8}"
export LANGUAGE="${LANGUAGE:-zh_CN:zh}"
export LC_MESSAGES="${LC_MESSAGES:-zh_CN.UTF-8}"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=loongnix-test
export XDG_SESSION_DESKTOP=loongnix-test
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "/run/user/$USER_ID/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
fi

set_panel_prop() {
    property="$1"
    type="$2"
    value="$3"
    xfconf-query -c xfce4-panel -p "$property" -n -t "$type" -s "$value" >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p "$property" -t "$type" -s "$value" >/dev/null 2>&1 || true
}

configure_panel() {
    command -v xfconf-query >/dev/null 2>&1 || return 0
    xfconf-query -c xfce4-panel -p /panels -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /plugins -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /configver -r >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /panels -n -a -t int -s 1 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels -a -t int -s 1 >/dev/null 2>&1 || true
    set_panel_prop /configver int 2
    set_panel_prop /panels/panel-1/position string 'p=10;x=0;y=0'
    set_panel_prop /panels/panel-1/length uint 100
    set_panel_prop /panels/panel-1/position-locked bool true
    set_panel_prop /panels/panel-1/size uint 30
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -n -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || true
    set_panel_prop /plugins/plugin-1 string applicationsmenu
    set_panel_prop /plugins/plugin-2 string tasklist
    set_panel_prop /plugins/plugin-3 string separator
    set_panel_prop /plugins/plugin-3/expand bool true
    set_panel_prop /plugins/plugin-3/style uint 0
    set_panel_prop /plugins/plugin-4 string statusnotifier
    set_panel_prop /plugins/plugin-5 string systray
    set_panel_prop /plugins/plugin-6 string clock
}

pkill -x xfce4-panel >/dev/null 2>&1 || true
pkill -x wrapper-1.0 >/dev/null 2>&1 || true
pkill -x wrapper-2.0 >/dev/null 2>&1 || true
pkill -x tint2 >/dev/null 2>&1 || true
pkill -x stalonetray >/dev/null 2>&1 || true
pkill -x xcompmgr >/dev/null 2>&1 || true

set_solid_background() {
    xsetroot -solid '#d8e0e5' || true
}

if command -v feh >/dev/null 2>&1 && [ -f "$HOME/Pictures/loongnix-test-wallpaper.png" ]; then
    feh --bg-fill "$HOME/Pictures/loongnix-test-wallpaper.png" || set_solid_background
else
    set_solid_background
fi
xrefresh >/dev/null 2>&1 || true
pulseaudio --start &
if [ -x /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd ]; then
    /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd &
fi
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true >/dev/null 2>&1 || true
xfwm4 --compositor=on &
wm_pid=$!
sleep 2
configure_panel
xfce4-panel --disable-wm-check &
sleep 1
lxterminal &
xfe &
wait "$wm_pid"
EOF
chmod 0755 /usr/local/bin/loongnix-test-session

cat >/usr/share/xsessions/loongnix-test.desktop <<'EOF'
[Desktop Entry]
Name=Loongnix X11 Test Desktop
Comment=Lightweight X11 session with compositor, panel, tray, notifications, terminal, and file manager
Exec=/usr/local/bin/loongnix-test-session
Type=Application
DesktopNames=XFCE
EOF

cat >/home/loongson/.dmrc <<'EOF'
[Desktop]
Session=loongnix-test
EOF
chown loongson:loongson /home/loongson/.dmrc
mkdir -p /etc/xdg/lightdm/lightdm.conf.d
cat >/etc/xdg/lightdm/lightdm.conf.d/50-loongnix-test.conf <<'EOF'
[Seat:*]
user-session=loongnix-test
EOF
```

实测这版 LightDM 会读取 `/etc/xdg/lightdm/lightdm.conf.d`，不要把自定义配置写到 `/etc/lightdm/lightdm.conf.d`。如果系统里还残留旧的 Openbox 自动登录片段，建议禁用，避免它覆盖 `loongnix-test`：

```bash
for f in /etc/xdg/lightdm/lightdm.conf.d/*openbox*.conf; do
    [ -f "$f" ] && mv "$f" "$f.disabled"
done
```

为避免 KDE 的通知服务占用 `org.freedesktop.Notifications` 后在轻量会话中退出，推荐把通知服务固定到 `xfce4-notifyd`：

```bash
if [ -f /usr/share/dbus-1/services/org.kde.plasma.Notifications.service ]; then
    mv /usr/share/dbus-1/services/org.kde.plasma.Notifications.service /usr/share/dbus-1/services/org.kde.plasma.Notifications.service.disabled
fi
cat >/usr/share/dbus-1/services/org.freedesktop.Notifications.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd
EOF
```

如果之前装过 `sddm`，建议改用 LightDM，避免两个显示管理器抢默认入口：

```bash
printf '/usr/sbin/lightdm\n' >/etc/X11/default-display-manager
systemctl disable sddm || true
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
systemctl daemon-reload
systemctl enable lightdm || true
systemctl set-default graphical.target
```

在这份 Loongnix 镜像中，`lightdm.service` 可能显示为 `static`，这不一定代表配置失败。实测重启后没有进入图形界面时，关键原因可能是缺少 `/etc/systemd/system/display-manager.service` 到 `lightdm.service` 的链接；上面的 `ln -sf` 会补上它。重点检查默认显示管理器文件、display-manager 链接、`sddm` 是否已禁用，以及能否实际启动 LightDM：

```bash
cat /etc/X11/default-display-manager
ls -l /etc/systemd/system/display-manager.service
systemctl is-enabled sddm || true
systemctl start lightdm
systemctl status lightdm --no-pager
```

如果此前已经登录进了 Plasma 或其它会话，应用配置后重启 LightDM：

```bash
systemctl restart lightdm
```

为了反复测试更快，也可以在这个测试虚拟机里启用 `loongson` 自动登录 `loongnix-test`：

```bash
cat >/etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf <<'EOF'
[Seat:*]
autologin-user=loongson
autologin-user-timeout=0
user-session=loongnix-test
autologin-session=loongnix-test
EOF
systemctl restart lightdm
```

自动登录只建议用于本地测试虚拟机；如果要保留登录界面，删除这个文件后重启 LightDM：

```bash
rm -f /etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf
systemctl restart lightdm
```

确认 QEMU 窗口出现图形登录器后，可以重启验证持久化：

```bash
systemctl reboot
```

普通 `loongson` 用户的 PATH 里通常没有 `/usr/sbin`，所以直接敲 `reboot` 可能提示命令不存在；在 root shell 中优先使用 `systemctl reboot`。重启后 QEMU 窗口应进入 LightDM 图形登录器或自动进入 Loongnix X11 Test Desktop。登录后应出现 Xfce panel、托盘区域、LXTerminal 和 Xfe 文件管理器。

实测启动成功时，`systemctl status lightdm --no-pager` 会显示 `active (running)`，进程列表里应能看到 `/usr/sbin/lightdm` 和 `/usr/lib/xorg/Xorg :0 ... vt7`。

如果软件源里包名不同，先搜索可用包：

```bash
apt-cache search lightdm
apt-cache search xfwm4
apt-cache search xfce4-panel
apt-cache search statusnotifier
apt-cache search xfe
```

如果下载过程中遇到单个包临时失败，可以先重试：

```bash
apt install --fix-missing xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin xfce4-indicator-plugin libayatana-appindicator3-1 libappindicator3-1 ayatana-indicator-application lxterminal xfe feh xfce4-notifyd libnotify-bin x11-xserver-utils iproute2 locales fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
```

实测当前 Loongnix 源中，`pcmanfm` 没有候选版本，`xfce4` 元包会因为 `xfce4-settings` 依赖的主题包不可安装而失败，`lxde` 元包会引用没有候选版本的 `lxpanel/pcmanfm`，`caja` 会拉入较重的 MATE 依赖。因此默认使用 Xfe；如果要复查其它文件管理器可用性：

```bash
apt-cache policy lightdm xfwm4 xfce4-panel xfce4-statusnotifier-plugin lxde lxpanel lxterminal pcmanfm
apt-cache policy xfe feh thunar caja dolphin xfce4-session xfce4-settings xfwm4 xfdesktop4
```

### 5.5 可选：设置测试桌面壁纸

Loongnix X11 Test Desktop 是轻量测试会话，默认启动 `xfdesktop4` 来稳定管理桌面背景，但不安装完整 Xfce 元包。本仓库默认提交 `shared\pic.png`，一键配置脚本会在 guest 中把它复制到：

```text
/home/loongson/Pictures/loongnix-test-wallpaper.png
```

并在 Loongnix X11 Test Desktop 启动时执行：

```bash
loongnix-apply-wallpaper
```

`loongnix-apply-wallpaper` 是一键配置脚本写入 guest 的辅助命令。它会优先通过 `xfdesktop4`/`xfconf-query` 设置图片壁纸；如果 `xfdesktop4` 不可用，才回退到 `feh --bg-fill`；只有在没有图片、没有 `xfdesktop4` 且没有 `feh` 时才回退到灰色纯色背景。会话会等窗口管理器、面板和文件管理器启动后再应用壁纸，并在稍后补跑几次，避免壁纸先显示、随后又被后续 X11 组件覆盖成灰色。

如果要换默认壁纸，在 Windows 宿主机启动虚拟机或重新挂载共享盘前，把新图片覆盖为：

```text
shared\pic.png
```

然后重新运行一键配置脚本，或手动在 guest 中复制：

```bash
su -
mkdir -p /home/loongson/Pictures
cp /mnt/hostshare/pic.png /home/loongson/Pictures/loongnix-test-wallpaper.png
chown loongson:loongson /home/loongson/Pictures/loongnix-test-wallpaper.png
exit
```

回到 `loongson` 桌面终端后临时应用图片壁纸：

```bash
loongnix-apply-wallpaper
```

也可以显式指定图片：

```bash
loongnix-apply-wallpaper ~/Pictures/loongnix-test-wallpaper.png
```

临时改成纯色背景，在桌面终端中运行：

```bash
xsetroot -solid '#2f343f'
```

如果壁纸先显示、几秒后又变成灰色，说明图片和 `feh` 本身通常是正常的，重新运行新版一键配置脚本后重启即可让会话在后续启动阶段补设壁纸。临时处理时，先在 `loongson` 桌面终端运行 `loongnix-apply-wallpaper`。如果仍然是灰色，检查 `feh` 和图片是否存在：

```bash
command -v xfdesktop || command -v feh
ls -l ~/Pictures/loongnix-test-wallpaper.png
```

两者都正常时，把 LXTerminal 或 Xfe 窗口完整拖过桌面区域一次，触发 X11 根窗口重绘后通常就会显示。这个现象是当前轻量会话的已知行为，不代表 `pic.png` 没有复制成功。

如果只是为了观察 Avalonia 透明窗口、阴影和边缘，纯色背景更容易定位边缘问题；图片壁纸适合复查透明区域、合成效果和桌面背景重绘。

### 5.6 可选：安装 KDE/Plasma 完整桌面

如果你想测试更完整的 KDE/Plasma 桌面行为，可以安装 `sddm`、`plasma-desktop`、`konsole`、`dolphin`。它功能更完整，但下载和安装量明显更大，不作为本方案的默认推荐。

```bash
apt install xorg dbus-x11 openssh-server ffmpeg alsa-utils pulseaudio sddm plasma-desktop konsole dolphin iproute2
systemctl disable lightdm || true
systemctl enable sddm
systemctl set-default graphical.target
systemctl reboot
```

实测 Loongnix 源中这些 KDE 包存在；但一次完整 KDE 安装下载量接近 500 MB，网络不稳定时更容易中断。

### 5.7 为什么不能只在 tty 或 SSH 中验收

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

## 7. 在虚拟机中挂载共享硬盘

共享硬盘由启动脚本通过 QEMU `fat:rw` 暴露给 guest。默认情况下，宿主机目录是项目根目录下的：

```text
shared\
```

如果启动时传了 `-SharePath`，则以 `-SharePath` 指定的目录为准。可以在 Windows 宿主机查看当前 QEMU 启动命令，确认实际挂载的是哪个目录：

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -like 'qemu-system-loongarch64*' } |
  Select-Object -ExpandProperty CommandLine
```

命令里会出现类似下面的片段：

```text
file=fat:rw:D:/Down/loongarch-oldworld-qemu-vm-20260608/shared
```

先把待传入 guest 的文件放进这个 Windows 目录，再启动 QEMU。打开 Loongnix 桌面终端或 SSH，切到 root：

```bash
su -
```

查看 guest 里的磁盘：

```bash
lsblk
```

常见输出中，系统盘是 `vda`，共享硬盘是额外出现的 `vdb`，通常带一个 `vdb1` 分区。挂载前先确认 `/mnt/hostshare` 当前是不是挂载点：

```bash
mkdir -p /mnt/hostshare
mountpoint /mnt/hostshare || echo not-mounted
```

如果显示 `not-mounted`，执行挂载：

```bash
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
mountpoint /mnt/hostshare
ls /mnt/hostshare
```

看到 `setup-loongnix-test-desktop.sh`、`README.md`、`pic.png` 或你放进去的测试包，才表示共享硬盘已经挂载到正确目录。

如果 `/dev/vdb1` 和 `/dev/vdb` 都不是共享硬盘，根据 `lsblk` 输出选择另一个新增磁盘。可以先看文件系统类型辅助判断：

```bash
blkid /dev/vdb1 /dev/vdb 2>/dev/null || true
```

如果 `/mnt/hostshare` 目录存在但 `ls /mnt/hostshare` 是空的，不要直接认为共享盘为空。先运行：

```bash
mountpoint /mnt/hostshare
mount | grep hostshare || true
```

如果不是挂载点，重新执行上面的 `mount -t vfat ...`。如果已经是挂载点但仍看不到 Windows 侧刚放进去的新文件，关闭 QEMU，确认文件已经在 Windows 的 `shared\` 目录里，再重新启动 QEMU 后挂载。QEMU 的 `fat:rw` 共享硬盘不适合依赖运行中热刷新。

不建议直接从共享 FAT 盘运行大型应用；共享盘主要用于传文件，运行测试前先复制到 guest 本地磁盘。

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

### 启动过程中黑屏或无显示画面时卡住

如果固件、GRUB、内核加载或桌面初始化阶段窗口暂时黑屏、白屏或没有稳定 guest 画面，请把鼠标指针移到 QEMU 窗口外。实测真正触发卡住的是无显示画面阶段鼠标停留在虚拟机窗口内，而不是“最大化”本身。等进入 LightDM 或 Loongnix X11 Test Desktop 后再进行鼠标操作；如果已经卡住或 QEMU 已退出，关闭 QEMU 窗口并重新启动。

### 鼠标点击位置和光标位置不一致

如果在桌面运行过程中调整 QEMU 窗口大小，可能出现鼠标点击位置偏移。表现为光标指向按钮、菜单项或托盘图标，但实际点击落点不在光标位置。验收 ClassIsland/OpenRemoteShouter 这类桌面应用时，建议保持窗口大小稳定；已经偏移时，先恢复原窗口大小，仍不正常就关闭 QEMU 并重新启动后再测试鼠标交互。

### 设置了图片壁纸但桌面仍是纯色

当前轻量会话不启动完整桌面管理器，图片壁纸可能不会立刻触发整屏重绘。先在 `loongson` 桌面终端运行：

```bash
loongnix-apply-wallpaper
```

如果是先显示壁纸、几秒后又变成灰色，重新运行新版 `shared/setup-loongnix-test-desktop.sh` 后重启；新版会话会用 `xfdesktop4` 接管壁纸并在桌面组件启动完成后补设。如果仍然是灰色，确认 `/home/loongson/Pictures/loongnix-test-wallpaper.png` 和 `xfdesktop` 或 `feh` 存在后，再运行 `loongnix-apply-wallpaper`。

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
