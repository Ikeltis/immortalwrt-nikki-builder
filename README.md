# ImmortalWrt + Nikki 自动构建

为以下设备构建预装 Nikki 的 ImmortalWrt 固件：

- ImmortalWrt 25.12.x
- x86/64 generic
- EFI
- ext4
- 300 MiB 根分区

固件内置：

- `nikki`
- `luci-app-nikki`
- `luci-i18n-nikki-zh-cn`
- Nikki APK 软件源及其签名公钥

工作流每周构建一次，也可以从 GitHub Actions 手动运行并指定 25.12.x 版本。未指定版本时使用 ImmortalWrt 官方当前稳定版；若官方稳定版已切换到其他分支，构建会停止，需要先更新构建脚本和 Nikki 软件源。构建过程会校验 ImageBuilder 的 SHA256，并使用 Nikki 签名公钥验证软件包。Release 提供固件、manifest 与 SHA256。

`packages.txt` 沿用原路由器的软件包清单。用于其他设备前，请检查其中的软件包是否适用。本仓库只构建并发布固件，不执行自动刷写。

## 刷写前

1. 给 VMware 虚拟机创建快照。
2. 下载 `generic-ext4-combined-efi.img.gz` 和 `sha256sums`。
3. 在路由器上核对 SHA256。
4. 执行 `sysupgrade -T firmware.img.gz`，确认兼容性检查通过。
5. 第一次使用此固件时，建议通过 LuCI 手动升级并选择保留配置，确认运行正常后再考虑自动升级。

固件预装软件包、Nikki 软件源及签名公钥；选择保留配置进行 sysupgrade 时，现有配置会随升级保留。
