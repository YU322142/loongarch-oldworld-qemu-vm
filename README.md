# LoongArch 旧世界 ABI1.0 QEMU X11 测试环境

本仓库提供一套 Windows 主机上的可见 QEMU 虚拟机启动方案，用于测试 LoongArch 旧世界 ABI1.0 Linux/X11 软件，重点覆盖 .NET/Avalonia 应用的渲染、声音、网络、托盘图标、通知和基本桌面交互。

> 本 README 只作为项目入口和文档索引，不替代完整教程。首次搭建、桌面安装、SSH、共享盘、测试软件运行和故障排查，请按 [完整使用教程](docs/USAGE.zh-CN.md) 操作。

English documentation: [README.en.md](README.en.md)

## 项目定位

这个项目用于搭建一个可以人工观察的 LoongArch 旧世界测试环境：

- 启动可见 QEMU 窗口，不使用无头 QEMU。
- 默认提供用户态网络、SSH 端口转发、DirectSound + Intel HDA 声音和宿主机共享盘。
- 提供 Loongnix Desktop mini 镜像下载/校验、工作盘生成、快照和重置脚本。
- 提供 guest 端一键配置脚本，用于安装轻量 X11 测试桌面。
- 推荐测试桌面为 Loongnix X11 Test Desktop：`xfwm4` 合成器、Xfce panel StatusNotifier/systray 托盘、LXTerminal、Xfe 和 `xfce4-notifyd`。
- 面向 ClassIsland、OpenRemoteShouter 这类 LoongArch old-world .NET/Avalonia 应用的人工验收。

Loongnix Desktop mini 镜像可能首次停在 `tty1`。这不是脚本启动失败，而是 guest 内还没有完成图形桌面配置；请按 [完整使用教程](docs/USAGE.zh-CN.md) 中的首次配置流程继续。

## 已知注意事项

- QEMU 启动过程中，如果窗口暂时黑屏、白屏或没有稳定画面，请把鼠标指针移到 QEMU 窗口外。实测真正容易触发卡住的是无显示画面阶段鼠标停留在虚拟机窗口内，而不是“最大化”本身。
- 桌面环境运行过程中建议保持窗口大小稳定。窗口大小变化后可能出现鼠标点击位置偏移，影响按钮、菜单和托盘图标验收；如果需要调整窗口，先确认桌面已经完整显示，再重新检查鼠标点击位置。
- Loongnix X11 Test Desktop 是轻量测试会话。本仓库自带 `shared\pic.png`，一键配置脚本会默认通过 `xfdesktop4` 把它设为图片壁纸，`feh` 仅作为回退方案。更多说明见 [完整使用教程](docs/USAGE.zh-CN.md#55-可选设置测试桌面壁纸)。

## 重要边界

本仓库只开源脚本和文档。以下内容不属于本仓库，也不会被源码包或 Release 包打包：

- QEMU 二进制和 EDK2 固件。
- Loongnix 系统镜像。
- 虚拟机工作盘、快照和运行日志。
- 用户放入 `shared/` 的测试软件、Actions artifact、运行库或其它临时文件。

第三方组件来源和许可边界见 [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md)。

## 建议阅读顺序

1. 先读 [完整使用教程](docs/USAGE.zh-CN.md)，按顺序完成 QEMU、系统镜像、工作盘、首次启动、SSH、桌面环境和共享盘配置。
2. 再读 [测试检查清单](docs/TESTING.zh-CN.md)，确认渲染、透明窗口、托盘、声音、网络、通知和重启行为都经过人工验收。
3. 如果需要确认脚本职责，查看 [scripts/README.md](scripts/README.md)。
4. 如果需要向虚拟机传测试包，查看 [shared/README.md](shared/README.md)。
5. 如果需要了解哪些资产可以公开，查看 [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md)。

## 文档索引

| 文档 | 用途 |
| --- | --- |
| [docs/USAGE.zh-CN.md](docs/USAGE.zh-CN.md) | 中文完整使用教程：安装 QEMU、下载镜像、启动 VM、启用 SSH、安装桌面、挂载共享盘、运行测试软件、常见问题。 |
| [docs/USAGE.md](docs/USAGE.md) | English full usage guide. |
| [docs/TESTING.zh-CN.md](docs/TESTING.zh-CN.md) | 中文测试检查清单：X11、透明窗口、托盘、声音、网络、日志和人工验收项目。 |
| [docs/TESTING.md](docs/TESTING.md) | English testing checklist. |
| [docs/ASSETS.zh-CN.md](docs/ASSETS.zh-CN.md) | 中文资产来源和许可边界。 |
| [docs/ASSETS.md](docs/ASSETS.md) | English asset and license boundary notes. |
| [scripts/README.md](scripts/README.md) | 启动、下载、重置、停止、打包等脚本的作用说明。 |
| [shared/README.md](shared/README.md) | 宿主机共享目录用途，以及 guest 端一键配置脚本说明。 |

## 仓库目录

| 路径 | 作用 |
| --- | --- |
| `scripts/` | 启动、停止、下载镜像、重置磁盘、打包脚本。 |
| `shared/` | 宿主机和虚拟机之间交换文件；只提交 README 和一键配置脚本。 |
| `images/` | Loongnix 基础镜像和工作盘位置；生成物不提交。 |
| `firmware/` | 工作用 UEFI 变量文件位置；生成物不提交。 |
| `logs/` | 串口日志和最后一次 QEMU 参数；运行日志不提交。 |
| `tools/qemu/` | 本地 QEMU 副本目录；不提交，不打包。 |

## 在线打包

GitHub Actions 工作流位于 `.github/workflows/package.yml`。它只打包脚本和文档，不会打包 QEMU、Loongnix 镜像、虚拟机工作盘、测试软件或日志。

## 许可

本仓库脚本和文档使用 MIT 许可。第三方组件、系统镜像、运行库和用户测试软件分别遵循各自许可。
