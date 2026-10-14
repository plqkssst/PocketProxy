# 安装与测试指南

## 一、先看清楚：你的设备能装吗

| 安装方式 | 系统要求 | 账号要求 | 你的 iOS 26.6.2 |
|---|---|---|---|
| TrollStore | iOS 14.0 – 17.0 | 无 | ❌ 不支持 |
| 免费 Apple ID 侧载 | 任意 | 免费 Apple ID | ❌ **装得上但 VPN 用不了** |
| 付费开发者账号签名 | 任意 | $99/年 | ✅ 唯一可行 |
| TestFlight | 任意 | $99/年 | ✅ 推荐 |
| 越狱装 deb | 需越狱 | 无 | ❌ iOS 26 无公开越狱 |

### 为什么免费 Apple ID 不行

本 App 的 VPN 功能依赖这些 entitlements：

```
com.apple.developer.networking.networkextension  = packet-tunnel-provider   ← 决定性的
com.apple.security.application-groups            = group.<你的包名>
com.apple.developer.team-identifier
```

Apple 官方文档把"哪些能力免费账号能用"写得很清楚：
<https://developer.apple.com/help/account/reference/supported-capabilities-ios/>
（表格列依次为 ADP = 个人付费账号 / ADEP = 企业账号 / Apple Developer = 免费 Apple ID）

| 能力 | 付费账号 | 企业账号 | 免费 Apple ID |
|---|---|---|---|
| **Network extensions** | ✅ | ✅ | ❌ |
| **Personal VPN** | ✅ | ✅ | ❌ |
| Access WiFi information | ✅ | ✅ | ❌ |
| App groups | ✅ | ✅ | **✅** |

全部 57 项能力里，免费账号只有 9 项可用。

两点结论：

1. **`Network extensions` 免费账号拿不到 —— 这是决定性的。** 缺了它，`NETunnelProviderManager` 无法建立隧道，VPN 一定起不来。这不是能绕过的技术问题，是 Apple 的账号策略。
2. **`App groups` 免费账号可以用**，所以缺权限时 App 未必会闪退。但即使 App Group 容器建得起来，隧道扩展仍然起不来 —— 这两件事是独立的。

另外提醒：**别用网上买的"共享企业证书"。** 企业证书（ADEP）确实支持 Network extensions，但那些证书的 App ID 基本不会给你开这个能力，而且随时会被 Apple 吊销 —— 一吊销，所有用它签的 App 立刻无法启动。


---

## 二、付费账号方案（$99/年）

有两条路，**TestFlight 更省事**。

### 方案 A：TestFlight（推荐）

优点：不用碰证书和描述文件，有效期 90 天，到期重新上传即可。

需要准备：
1. Apple Developer Program 账号（$99/年）
2. App Store Connect 里的 **API 密钥**（`.p8` 文件 + Key ID + Issuer ID）
3. 在 App Store Connect 创建 App 记录，Bundle ID 用 `io.github.plqkssst.pocketproxy`

然后在 GitHub 仓库加 Secrets，CI 会自动归档并上传到 App Store Connect，你在手机上用 TestFlight App 安装。

### 方案 B：开发证书签名 + 侧载

优点：不经过 Apple 服务器，本地装。

需要准备：
1. 在 Apple Developer 后台创建 **App ID**，显式勾选 **Network Extensions** 能力
2. 创建 **development 证书**（导出 `.p12`）和 **provisioning profile**（含 Network Extensions）
3. 把它们 base64 后存进 GitHub Secrets

CI 签名后产出 IPA，用 Sideloadly / 3uTools / iMazing 直接安装（**不要**勾选 re-sign，包已经签好了）。

---

## 三、没有付费账号时的备选

如果暂时不想买账号，只能验证"能编译、能装、UI 正常"，**VPN 功能无法验证**：

- 用免费 Apple ID + Sideloadly 装 `PocketProxy-unsigned.ipa`，有效期 7 天
- App 能启动、能导入配置、能看到界面
- 点连接会失败 —— 这是预期行为，不是 bug

---

## 四、测试时请重点反馈

装好之后，这些是只有真机能验证的（我在 Windows 上无法验证）：

1. App 能否正常启动，界面是否完整
2. 导入 `ss://` 链接 / 订阅链接是否成功
3. 节点列表是否显示正常
4. **点击连接后 VPN 是否真的建立**（设置 → 通用 → VPN 与设备管理 里能看到描述文件）
5. 连接后实际能否访问外网
6. 崩溃、卡顿、内存被杀（Network Extension 有约 50MB 内存上限，超过会被系统杀掉）
