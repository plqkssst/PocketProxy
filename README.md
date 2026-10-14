# PocketProxy

面向 iPhone 的代理客户端，基于 [sing-box](https://github.com/SagerNet/sing-box) 内核。

本仓库是 [SagerNet/sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple)（commit `e232aaf`，对应 sing-box `v1.14.3`）的衍生版本，按 GPL-3.0 授权。

## 为什么不用 FlClash 的内核

最初的需求是"类似 iOS Shadowsocks 的 App"。排查后确认 **FlClash 走不通 iOS**：

- FlClash 内核是 mihomo（`core/Clash.Meta`，`flclash/v0.8.99`）
- mihomo 的 Makefile 里**没有任何 Apple 构建目标**（无 `ios` / `apple` / `gomobile` / `xcframework`）
- FlClash 也没有 `ios/` 平台目录，`setup.dart` 的构建目标只有 android / linux / macos / windows

sing-box 是目前唯一有完整、可自建 iOS 客户端源码的开源代理内核，因此选它作为基座。

## 相对上游改了什么

| 改动 | 位置 |
|---|---|
| App 显示名改为 PocketProxy，包名改为 `io.github.plqkssst.pocketproxy` | `project.pbxproj` |
| 最低系统版本 15.0 → **16.0**（上游代码用了 iOS 16 才有的 `ToolbarContentBuilder.buildIf`） | `project.pbxproj` |
| **分享链接导入**：粘贴 `ss://` / `trojan://` 生成配置 | `Library/ShadowLink/`、`ImportShareLinkView.swift` |
| **运行诊断页**：显示签名实际带了哪些 entitlements | `SFI/DiagnosticsView.swift` |
| App Group 缺失时不再闪退，改为降级并在诊断页报明原因 | `Library/Shared/FilePath.swift` |
| 自绘 App 图标 | `scripts/generate-app-icon.py` |

## 分享链接导入

上游只能导入**完整的 sing-box 配置**或订阅 URL，**不认 `ss://` 分享链接**。这是相对 Shadowrocket 最大的体验缺口，所以补上了。

支持：

- `ss://` —— SIP002 格式（`ss://base64(method:password)@host:port/`）和旧版整体编码格式
- `trojan://`
- 一行一条，多条链接自动合成一个带 `selector` 的配置
- 节点名支持百分号编码、IPv6 字面量、`plugin` 参数
- 明确拒绝 sing-box 已移除的老式流加密（如 `aes-256-cfb`），而不是生成一个连不上的配置

生成的配置**自带 `tun` inbound**。这点很关键：App 会把 profile 文件原样交给隧道内核，而 `auto_route`、`mtu`、tun 地址、DNS 全都从配置里的 tun inbound 读取 —— 少了它，VPN 会"连上"但一条路由都没有。

解析逻辑有可执行测试（`Tools/ShadowLinkTests/`），CI 里用 `swiftc` 真跑，不是只做类型检查。

## 构建

iOS 只能在 macOS + Xcode 上编译，所以走 GitHub Actions 的 macOS runner（公开仓库免费不限量）。

```bash
# 在 macOS 上手动构建
bash scripts/build-local.sh
```

CI 产物：

| 产物 | 用途 |
|---|---|
| `PocketProxy-unsigned.ipa` | 未签名，需付费开发者账号签名后安装；免费 Apple ID 侧载可看界面但 VPN 用不了 |
| `PocketProxy-trollstore.ipa` | ldid 签名带完整 entitlements，仅 iOS 14.0–17.0 的 TrollStore 可装 |
| `xcodebuild-log` | 完整编译日志，排查失败用 |

**安装方式和账号要求见 [docs/install-ios.md](docs/install-ios.md)。**
**证书准备见 [docs/signing-setup.md](docs/signing-setup.md)。**

## 版本锁定

| 组件 | 版本 |
|---|---|
| sing-box 内核 | v1.14.3 |
| sing-box-for-apple | e232aaf（v1.14.3） |
| Runestone 子模块 | baeb3cbf |
| 最低 iOS | 16.0 |
| 构建 runner | `macos-latest`（macOS 26 / Xcode 26.6） |

## License

GPL-3.0-or-later，原始版权归 nekohasekai 所有，详见 [LICENSE](LICENSE)。
