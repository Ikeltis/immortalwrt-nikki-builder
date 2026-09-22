# ImmortalWrt + Nikki 自动构建

为以下设备构建预装 Nikki 的 ImmortalWrt 固件：

- ImmortalWrt 25.12.x（自动选择最新稳定补丁版本）
- x86/64 generic
- EFI
- ext4
- 300 MiB 根分区

固件内置：

- `nikki`
- `luci-app-nikki`
- `luci-i18n-nikki-zh-cn`
- Nikki APK 软件源及其签名公钥

工作流每周检查一次更新，也可以从 GitHub Actions 手动运行并指定版本。构建过程会验证 ImmortalWrt 官方 ImageBuilder 的 SHA256 和 Nikki APK 仓库签名，Release 同时提供固件、manifest 与 SHA256。

## 刷写前

1. 给 VMware 虚拟机创建快照。
2. 下载 `generic-ext4-combined-efi.img.gz` 和 `sha256sums`。
3. 在路由器上核对 SHA256。
4. 执行 `sysupgrade -T firmware.img.gz`，确认兼容性检查通过。
5. 第一次构建建议通过 LuCI 手动升级并保留配置，确认无误后再配置自动刷写。

不要把订阅、密码或 `/etc/config/nikki` 提交到本仓库。固件只预装软件包，升级时由 sysupgrade 保留现有配置。
