# 签名与安装准备（付费开发者账号）

本文档列出**你需要在自己账号里做的一次性配置**。做完之后告诉我，我把证书签名接进 CI，
你就能直接拿到一个用爱思助手装到手机上的 IPA。

## 为什么必须走这一步

你的 iPhone 是 **iOS 26.6.2**：

- TrollStore 只支持 iOS 14.0 – 17.0 → 不可用
- iOS 26 没有公开越狱 → 不可用
- 免费 Apple ID 的描述文件里**没有** NetworkExtension 权限 → 装上也是白装

所以只有付费开发者账号（$99/年，中国区 ¥688/年）这一条路。

## 一、购买账号

1. 打开 https://developer.apple.com/programs/ ，用你的 Apple ID 注册
2. 个人开发者选 **Individual**（不需要公司实体、不需要 D-U-N-S 编码）
3. 付费后等待审核通过（通常几分钟到 48 小时）
4. 记下你的 **Team ID**（10 位字符，在 Membership 页面）

## 二、注册两个 App ID

在 **Certificates, Identifiers & Profiles → Identifiers** 里新建：

### App ID 1（主 App）

| 项 | 值 |
|---|---|
| Bundle ID | `io.github.plqkssst.pocketproxy` |
| 需要勾选的能力 | **App Groups**、**Network Extensions** |

### App ID 2（隧道扩展）

| 项 | 值 |
|---|---|
| Bundle ID | `io.github.plqkssst.pocketproxy.extension` |
| 需要勾选的能力 | **App Groups**、**Network Extensions**（**必须勾上 packet-tunnel-provider**） |

> **Network Extensions 这一步是整件事的关键。** 不勾，VPN 一定起不来。
> 两个 App ID 要加入**同一个** App Group：`group.io.github.plqkssst.pocketproxy`

## 三、注册你的设备

**Devices → +** ，用爱思助手读取你 iPhone 的 **UDID** 填进去。
个人账号每年可注册 100 台设备。

## 四、创建证书和描述文件

### 证书

1. **Certificates → +** → 选 **Apple Development**
2. 按提示生成 CSR（在 Mac 上用钥匙串助手；**Windows 上可以用 OpenSSL 生成**，方法见下）
3. 下载 `.cer` 并导出成 **`.p12`**（设置一个密码）

Windows 上用 OpenSSL 生成 CSR：

```bash
openssl genrsa -out dev.key 2048
openssl req -new -key dev.key -out dev.certSigningRequest -subj "/emailAddress=你的邮箱/CN=你的名字/C=CN"
```

拿到 `.cer` 后转成 `.p12`：

```bash
openssl x509 -inform DER -in development.cer -out development.pem
openssl pkcs12 -export -inkey dev.key -in development.pem -out development.p12
```

### 描述文件

**Profiles → +** ，为**上面两个 App ID 各建一个** development 描述文件：

| 描述文件 | 对应 Bundle ID | 包含设备 |
|---|---|---|
| PocketProxy Dev | `io.github.plqkssst.pocketproxy` | 你的 iPhone |
| PocketProxy Ext Dev | `io.github.plqkssst.pocketproxy.extension` | 你的 iPhone |

下载得到两个 `.mobileprovision` 文件。

## 五、把这些交给我

需要 4 样东西（**不要直接贴在聊天里**，用下面任一方式）：

1. `development.p12`（证书）
2. `.p12` 的密码
3. 两个 `.mobileprovision` 文件
4. 你的 **Team ID**

推荐做法：直接用 `gh` 存进仓库 Secrets，我看不到明文：

```bash
gh secret set BUILD_CERTIFICATE_BASE64 --body "$(base64 -w0 development.p12)"
gh secret set P12_PASSWORD
gh secret set PROVISIONING_PROFILE_APP_BASE64 --body "$(base64 -w0 PocketProxy_Dev.mobileprovision)"
gh secret set PROVISIONING_PROFILE_EXT_BASE64 --body "$(base64 -w0 PocketProxy_Ext_Dev.mobileprovision)"
gh secret set DEVELOPMENT_TEAM --body "你的TeamID"
gh secret set KEYCHAIN_PASSWORD --body "$(openssl rand -hex 16)"
```

存好之后告诉我，我补上签名流水线，然后你从 Actions 下载签好名的 IPA，
用爱思助手直接安装（**不要勾"重新签名"**，包已经签好了）。

## 六、备选：TestFlight

如果不想折腾证书和 UDID，也可以走 TestFlight：

1. 在 **App Store Connect** 建一个 App 记录，Bundle ID 用 `io.github.plqkssst.pocketproxy`
2. 生成一个 **App Store Connect API 密钥**（Users and Access → Integrations）
3. 把 `.p8` 文件、Key ID、Issuer ID 存成 Secrets

CI 会自动归档并上传，你在手机上装 TestFlight 就能收包，90 天有效。**这条路省事得多，推荐。**
