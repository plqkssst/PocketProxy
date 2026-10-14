# PocketProxy

面向 iPhone 的代理客户端，基于 [sing-box](https://github.com/SagerNet/sing-box) 内核。

本仓库是 [SagerNet/sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple)（commit `e232aaf`，对应 sing-box `v1.14.3`）的衍生版本，按 GPL-3.0 授权。

## 为什么不用 FlClash 的内核

原始需求是"类似 iOS Shadowsocks 的 App"。排查后确认 **FlClash 走不通 iOS**：

- FlClash 内核是 mihomo（`core/Clash.Meta`，`flclash/v0.8.99`）
- mihomo 的 Makefile 里**没有任何 Apple/iOS 构建目标**（无 `ios` / `apple` / `gomobile` / `xcframework`）
- FlClash 也没有 `ios/` 平台目录，`setup.dart` 的构建目标只有 android / linux / macos / windows

sing-box 是目前唯一有完整、可自建 iOS 客户端源码的开源代理内核，因此选它作为基座。

## 架构

```
Extension/PacketTunnelProvider.swift   4 行，继承 Library 里的 ExtensionProvider
Library/                               10,601 行 — NetworkExtension 桥接 + 配置库（核心，必须保留）
ApplicationLibrary/                    28,343 行 — SwiftUI 界面（后续替换为自研精简 UI）
SFI/                                    1,067 行 — iOS App 外壳
Libbox.xcframework                     Go 内核产物，由 CI 从 sing-box 源码构建，不入库
```

## 构建

iOS 只能在 macOS + Xcode 上编译。本机是 Windows，所以构建走 GitHub Actions 的 macOS runner。

```bash
# 手动构建（在 macOS 上）
bash scripts/build-local.sh
```

CI 产物（每次 push 到 `main` 或手动触发）：

| 产物 | 用途 |
|---|---|
| `PocketProxy-unsigned.ipa` | 未签名，需要付费开发者账号重新签名后安装 |
| `PocketProxy-trollstore.ipa` | ldid 签名带完整 entitlements，仅 iOS 14.0–17.0 的 TrollStore 可装 |

**安装方式和账号要求见 [docs/install-ios.md](docs/install-ios.md)。**

## 版本锁定

| 组件 | 版本 |
|---|---|
| sing-box 内核 | v1.14.3 |
| sing-box-for-apple | e232aaf（v1.14.3） |
| Runestone 子模块 | baeb3cbf |
| iOS 最低版本 | 15.0 |

## License

GPL-3.0-or-later，原始版权归 nekohasekai 所有，详见 [LICENSE](LICENSE)。
