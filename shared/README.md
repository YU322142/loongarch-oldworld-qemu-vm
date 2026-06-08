# shared

Place test packages here before starting or using the VM.

This folder is exposed to the guest as an extra FAT/virtio disk by default.
Most folder contents are ignored by Git so user test payloads are not committed.

Tracked helper:

- `setup-loongnix-test-desktop.sh`: run inside the Loongnix guest as root to configure SSH, Chinese locale, LightDM, Openbox, tint2 tray, LXTerminal, Xfe file manager, audio tools, and notification support.

Example inside the guest after mounting the shared disk:

```bash
su -
mkdir -p /mnt/hostshare
mount -t vfat /dev/vdb1 /mnt/hostshare || mount -t vfat /dev/vdb /mnt/hostshare
ls /mnt/hostshare
sh /mnt/hostshare/setup-loongnix-test-desktop.sh
systemctl reboot
```

中文说明：

- 启动虚拟机后，本目录默认会作为额外 FAT/virtio 磁盘暴露给 Loongnix。
- 在虚拟机里推荐挂载到 `/mnt/hostshare`；实测通常是 `/dev/vdb1`，没有分区时再用 `/dev/vdb`。
- 虚拟机运行时从 Windows 新增的文件不一定会立刻刷新到 guest；最好在启动虚拟机前把脚本和测试包放好。
- `setup-loongnix-test-desktop.sh` 是一键配置脚本，需要在虚拟机内用 root 执行。
- 其它放进来的测试包、日志和临时文件默认不会提交到 Git。
