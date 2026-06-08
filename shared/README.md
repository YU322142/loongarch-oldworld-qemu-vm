# shared

Place test packages here before starting or using the VM.

This folder is exposed to the guest as an extra FAT/virtio disk by default.
Most folder contents are ignored by Git so user test payloads are not committed.

Tracked helper:

- `setup-loongnix-test-desktop.sh`: run inside the Loongnix guest as root to configure SSH, Chinese locale, LightDM, Loongnix X11 Test Desktop, `xfwm4` compositing, Xfce panel StatusNotifier/systray support, `xfdesktop4` wallpaper management, LXTerminal, Xfe file manager, audio tools, and notification support.
- `pic.png`: default wallpaper used by `setup-loongnix-test-desktop.sh`. Replace this file before starting QEMU if you want a different default wallpaper.

Recommended guest-side mount flow:

```bash
su -
lsblk
mkdir -p /mnt/hostshare
mountpoint /mnt/hostshare || echo not-mounted
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
mountpoint /mnt/hostshare
ls -la /mnt/hostshare
sh /mnt/hostshare/setup-loongnix-test-desktop.sh
systemctl reboot
```

If `/mnt/hostshare` exists but is empty, first run `mountpoint /mnt/hostshare`. It may only be a normal empty directory, not a mounted disk. QEMU `fat:rw` is also not a reliable live-refresh folder; put files into `shared\` before starting QEMU, or restart QEMU after changing host-side files.

中文说明：

- 启动虚拟机后，本目录默认会作为额外 FAT/virtio 磁盘暴露给 Loongnix。
- 在虚拟机里推荐挂载到 `/mnt/hostshare`；实测通常是 `/dev/vdb1`，没有分区时再用 `/dev/vdb`。
- 如果 `/mnt/hostshare` 目录存在但内容为空，先运行 `mountpoint /mnt/hostshare`；它很可能只是普通空目录，还没有真正挂载共享盘。
- 虚拟机运行时从 Windows 新增的文件不一定会立刻刷新到 guest；最好在启动虚拟机前把脚本和测试包放好，运行中改了文件但 guest 看不到时，关闭并重新启动 QEMU。
- `setup-loongnix-test-desktop.sh` 是一键配置脚本，需要在虚拟机内用 root 执行；它会配置带合成器、托盘宿主和 `xfdesktop4` 壁纸管理的 Loongnix X11 Test Desktop，并默认使用本目录的 `pic.png` 作为图片壁纸。
- 其它放进来的测试包、日志和临时文件默认不会提交到 Git。
