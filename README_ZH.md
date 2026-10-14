<p align="center">
  <img src="app/assets/icon/gooes_steamkit.png" width="128" height="128" alt="GooeSteamKit 大鹅与盾牌图标" />
</p>

<h1 align="center">GooeSteamKit</h1>

<p align="center">
  <b>令牌、账户、库存、市场，一个应用搞定。</b><br/>
  基于 Flutter 的 Steam 工具箱，支持 Windows 与 Android。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

<p align="center">
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/gooesman/AnotherVaporAuth?style=flat-square&color=4C7FFF" /></a>
  <img alt="Windows x64 与 Android ARM64" src="https://img.shields.io/badge/platforms-Windows%20x64%20%7C%20Android%20ARM64-58677D?style=flat-square" />
  <a href="LICENSE"><img alt="MIT 许可" src="https://img.shields.io/badge/license-MIT-58677D?style=flat-square" /></a>
</p>

<p align="center">
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases/latest">下载安装</a> ·
  <a href="https://github.com/gooesman/AnotherVaporAuth/releases">更新记录</a> ·
  <a href="https://github.com/gooesman/AnotherVaporAuth/issues">反馈问题</a>
</p>

GooeSteamKit 是 **gooesman 独立维护的 Fork**，基于 freefrank 开发的
[AVA / AnotherVaporAuth](https://github.com/freefrank/AnotherVaporAuth)。
在保留原有皮肤风格和 maFile 兼容性的基础上，扩展账户管理、库存与市场、可选加速和应用内更新。
本分支的本地功能与皮肤无需 Pro 验证，支付和广告已关闭。这是社区项目，与 Valve 或 Steam 无隶属关系。

## 下载与更新

| 平台 | 本分支下载入口 | 选择的文件 |
|---|---|---|
| **Windows x64** | [电脑安装包](https://github.com/gooesman/AnotherVaporAuth/releases/latest) | `AVA-pc-…-windows-x64-setup.exe` |
| **Android ARM64** | [手机 APK](https://github.com/gooesman/AnotherVaporAuth/releases/latest) | `AVA-Fork-…-android-arm64.apk` |

两端应用名称均为 **GooeSteamKit**。安装包保留旧文件名前缀，以兼容早期版本的应用内更新。
本分支目前发布 Windows 和 Android 安装包。

已安装用户可进入 **设置 → 软件更新**。两端均支持通过第三方 GH-Proxy 线路自动加速下载，
失败时回退 GitHub，也可选择仅使用 GitHub 官方源。下载过程中显示进度和速度，
按 GitHub 提供的文件大小与 SHA-256 校验后，由你确认安装；手机端交给系统安装器完成。

版本检查仍需访问 GitHub 官方元数据，加速源的可用性与速度取决于网络环境。
详见[安装包与更新说明][releases-guide]。

## 主要功能

| 功能 | 可以做什么 |
|---|---|
| **账户与 Steam 令牌** | 管理多个账户、离线生成验证码、倒计时与复制、导入导出 maFile，记住用户名／昵称／Steam ID 显示偏好。 |
| **账户概览** | 查看钱包余额、待到账金额和市场状态。电脑端展示概览卡片，手机首页保持令牌与账号列表的简洁布局。 |
| **电脑端 Steam 登录** | 选中已导入账户后，登录与切换按钮均可打开／切换 Steam 并批准本次已核实的本机登录窗口二维码；也支持手动拖框扫码。 |
| **好友与交易** | 查看好友、收到和发出的报价，选择双方库存物品、审阅报价并处理交易确认。 |
| **库存与出售** | 按游戏和库存上下文查看物品，搜索名称、筛选类型与品质，显示淡品质色边框和 Steam 提供的冷却说明；支持批量上架及在售／暂挂／待确认记录。 |
| **市场查价** | 按商品、游戏和币种搜索，收藏后直接查看所选币种的价格与物品详情，也可打开对应 Steam 市场页面。 |
| **备用登录码** | 在应用内请求短信、输入验证码并展示 Steam 一次性备用登录码。 |
| **可选 Steam 加速** | 优先跟随检测到的外部代理，支持用自己的 Clash 订阅作为内置备用线路，并显示当前线路状态。 |
| **应用锁与同步** | 可选启动 PIN 验证与系统解锁；通过 WebDAV 加密同步账户与设置，包含市场收藏、币种和加速订阅，可对比本地／远程后选择上传或拉取。 |
| **外观与其他工具** | 浅色／深色／跟随系统、皮肤、简洁刷新圆环，以及设备会话管理、Steam 密钥兑换和七种语言。 |

### 常用操作

- **手机端：** 点按账户切换首页当前令牌，长按直接进入该账户概览，再使用库存、市场、好友或备用码。
- **电脑端：** 从左侧列表选择账户，通过概览或右键菜单操作；账户行不使用左右滑动操作。
- **启动解锁：** 指纹／Windows Hello 等系统解锁是启动验证的子项；关闭启动验证会同时关闭系统解锁，账户文件仍保持加密。

### 市场价格与币种

选择游戏、币种，输入商品名称后点击 **搜索市场**，可见商品会自动查询**所选币种的最低在售价**，
无需逐个点刷新。切换币种后，可见商品会重新查价；物品详情将近期成交中位价与在售价分开展示。

点击结果旁的星标即可收藏。进入 **收藏** 后无需再次搜索，并记住所选币种。
只有当前可见的商品会加载报价，未显示的收藏不会在后台查价。

搜索按需发起、结果分页加载、近期报价使用缓存，不持续轮询价格，也不把未经确认的美元搜索价改标成人民币。
Steam 限流或暂时无法取得报价时，会显示相应状态并提供重试。报价仅供参考，实际交易以 Steam 为准。

库存与交易选物品页面也会显示 Steam 的限制说明。Steam 提供可识别的到期时间时，
详情按本地时间显示，并在打开时计算剩余时间；没有时间信息时不会按物品类型猜测冷却期。

### 对比与跨设备同步

进入 **设置 → 同步 → 对比本地与远程**，展开一行查看差异，再选择 **拉取远程 → 本地**
或 **上传本地 → 远程**。每次只处理所选行：一个账户是一行；已启用的应用设置、市场收藏／币种
及加速订阅共同组成一行设置文档。账户秘密与订阅凭据在对比中隐藏。

改动根据上次共同版本判断，显示的同步时间仅供参考。两端设置均有改动时，等待你明确选择；
对比过期后必须刷新才能应用。收藏与币种随 **同步应用设置** 开关同步，不同步缓存报价。
详见[同步设计与行为说明][sync-guide]。

### 可选 Steam 加速

添加自己的 **HTTP／HTTPS Clash 订阅**，选择支持的节点，再开启本次自动切换或设置随应用启动。
检测到外部 HTTP 代理或 VPN／TUN 时优先使用外部线路；外部关闭后，若已启用内置接管且能确认网络环境，
则切回内置线路。界面分别显示当前线路与 Steam 连接检查结果。

加速范围是 **GooeSteamKit 内的 Steam 请求**，不接管 Steam 电脑客户端、游戏或系统代理与 DNS。
这种应用内加速不会产生系统 VPN 图标。PAC、未知网络环境及部分订阅节点类型存在限制，
详见[加速范围与使用说明][connectivity]。

## 安装与迁移

| 你现在使用的版本 | 如何迁移到 GooeSteamKit |
|---|---|
| **电脑端 GooeSteamKit / AVA-pc** | 用新版安装包覆盖原安装，沿用现有数据目录。 |
| **手机端 GooeSteamKit / AVA Fork** | 安装包名和签名一致的本分支新版 APK，可覆盖更新并保留账户和设置。 |
| **手机端原版 AVA / 旧 AVA dev** | 保留旧应用，另装 GooeSteamKit，再导出／导入各账户的 `.maFile`；PIN 和本地设置独立。 |
| **Steam Desktop Authenticator** | 导入 `maFiles` 文件夹；加密账户需同时提供 `manifest.json` 与原密码。 |

请保留账户文件与撤销码的备份。导入“仅验证码”账户不代表已建立在线 Steam 会话，
登录、交易与市场功能仍取决于 Steam 的会话及账户条件。
详见[安装迁移步骤][migration]和[电脑端登录说明][switch-guide]。

## 隐私

账户和验证器密钥保存在本机，Steam 操作通过当前线路访问 Valve 服务。
可选 WebDAV 同步将加密后的账户数据及已启用的设置发送到你指定的服务器。
备用登录码与扫码截图只在内存中处理，不写入日志或同步；反馈入口打开本仓库 Issues，不自动上传报告。

关于网络线路、订阅、更新镜像与同步元数据，见[本分支隐私说明][privacy]。
仓库根目录的 `PRIVACY.md` 系列文档保留原版 AVA 政策供参考。

## 源码与开发

本分支的应用开发位于 [`feature/windows-steam-account-switch`][source]。
构建 GooeSteamKit 请使用该分支或正式版本标签，需要 **Flutter 3.44.4 / Dart 3.12.2** 及对应平台构建环境。

```sh
git clone --branch feature/windows-steam-account-switch https://github.com/gooesman/AnotherVaporAuth.git
cd AnotherVaporAuth/app
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d windows
```

Android 分为 `cn` / `play` 渠道；本分支发布的是 **CN ARM64** 构建，使用独立包名和固定签名。
具体配置见[构建说明][build-guide]与[发布流程][releases-guide]，自行签名的安装包无法直接覆盖本分支发布包。

## 致谢与许可

感谢 **freefrank** 开发 AVA，以及原项目的所有贡献者。AVA 的灵感来自 Steam Desktop Authenticator，
Steam 协议实现参考了 [SteamAuth](https://github.com/geel9/SteamAuth) 与
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session)。

应用源码保留原作者的 [MIT 许可](LICENSE)。[内置字体][fonts]遵循各自许可；
可选 Mihomo 组件的许可见[第三方声明][mihomo]，本分支 Release 附有匹配的组件源码与许可文件。
本地功能开放不代表获得原作者运营的付费在线服务权限。

[source]: https://github.com/gooesman/AnotherVaporAuth/tree/feature/windows-steam-account-switch
[build-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/app/README.md
[releases-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/fork-releases.md
[switch-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md
[sync-guide]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/specs/2026-08-12-config-sync-design.md
[connectivity]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md#optional-steam-connectivity
[migration]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/windows-steam-switch.md#android-installation-and-migration
[privacy]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/docs/fork-privacy-zh.md
[fonts]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/app/assets/fonts/README.md
[mihomo]: https://github.com/gooesman/AnotherVaporAuth/blob/feature/windows-steam-account-switch/third_party/mihomo/NOTICE
