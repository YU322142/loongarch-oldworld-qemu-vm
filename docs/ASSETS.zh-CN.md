# 第三方资产、来源与授权边界

本仓库使用 MIT 许可开源脚本和文档。下面列出的组件不属于本仓库的 MIT 授权范围。

## QEMU for Windows

- 用途：提供 `qemu-system-loongarch64.exe`、`qemu-img.exe`、EDK2 LoongArch64 固件和运行依赖。
- 推荐安装：`winget install -e --id SoftwareFreedomConservancy.QEMU --version 11.0.50`
- 本方案测试版本：QEMU `11.0.50`，`qemu-system-loongarch64.exe --version` 显示 `v11.0.0-12631-g54e84cdc7a`。
- 官方许可说明：QEMU 使用 GNU GPL v2。
- 官网：[https://www.qemu.org/](https://www.qemu.org/)
- 许可说明：[https://www.qemu.org/docs/master/about/license.html](https://www.qemu.org/docs/master/about/license.html)

仓库不会提交 `tools/qemu/`。如果你选择在 Release 中再分发 QEMU 二进制，需要同时满足 QEMU 及其依赖库的许可证要求，并提供相应源码或源码获取方式。

## Loongnix Desktop mini qcow2

- 用途：作为旧世界 LoongArch ABI1.0 Linux/X11 桌面测试系统。
- 默认镜像：`Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2`
- 官方目录：[https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/](https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/)
- Loongnix 页面：[https://www.loongnix.cn/zh/loongnix/](https://www.loongnix.cn/zh/loongnix/)
- 默认账号参考：[Loongnix KVM 文档](https://docs.loongnix.cn/kvm/kvm/loongarch-kvm/install-and-setup/%E5%85%A8%E6%96%B0%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2.html)

本方案记录的校验值：

```text
MD5    3ca44ded43023602deafaad416756cf7
SHA256 c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c
```

仓库不会提交 `images/*.qcow2`。Loongnix 镜像、其中的软件包、系统组件、商标和二进制分发边界由 Loongnix 及各上游项目许可决定。

## 工作盘

`images\loongnix-abi1-work.qcow2` 是从基础镜像生成的可写工作盘。它可能包含用户配置、测试软件、日志、缓存或隐私数据，因此不应提交到 Git，也不建议作为通用源码资产发布。

如果需要给别人复现实测环境，推荐发布：

- 本仓库源码或 Actions 打包产物。
- Loongnix 官方镜像下载地址和校验值。
- 测试软件自己的 Release artifact。
- 虚拟机内安装/配置步骤。

## 用户测试软件

`shared/` 中的 `setup-loongnix-test-desktop.sh` 是本仓库 MIT 许可下的开源配置脚本，会提交并进入 Release。其它放入 `shared/` 的内容只用于宿主机和虚拟机交换文件，默认不提交。ClassIsland、OpenRemoteShouter、原生库构建产物等测试包应按它们各自仓库的许可证和 Release 方式发布。
