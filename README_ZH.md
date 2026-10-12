<h1 align="center">
  <img src="icon.png" height="64" width="64" />
  <br/>
  AVA
</h1>

<p align="center">
  <b>A</b>nother<b>V</b>apor<b>A</b>uth —— 用 <b>Flutter</b> 打造的现代化、轻量、跨平台 Steam 验证器。<br/>
  <sup>社区项目 —— 与 Steam / Valve 无任何关联。</sup>
</p>

<p align="center">
  单一代码库覆盖 <b>Windows · macOS · Linux · Android</b>（iOS 已规划）。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

<p align="center">
  <a href="https://github.com/freefrank/AnotherVaporAuth/releases/latest"><img alt="最新版本" src="https://img.shields.io/github/v/release/freefrank/AnotherVaporAuth?style=flat-square&color=34F1FF" /></a>
  <a href="https://play.google.com/store/apps/details?id=pro.dotslash.ava"><img alt="Google Play" src="https://img.shields.io/badge/Google%20Play-安装-34F1FF?style=flat-square&logo=googleplay&logoColor=white" /></a>
  <a href="LICENSE"><img alt="许可证" src="https://img.shields.io/github/license/freefrank/AnotherVaporAuth?style=flat-square&color=FF4D9D" /></a>
  <img alt="平台" src="https://img.shields.io/badge/平台-Windows%20%C2%B7%20macOS%20%C2%B7%20Linux%20%C2%B7%20Android-8A93B8?style=flat-square" />
</p>

---

## 关于本分支

这是 gooesman 基于 freefrank 的 AVA 维护的独立 Fork。本地功能和所有皮肤直接开放，
无需 Pro 验证或付费；保留原作者的 MIT 许可及署名。正式安装包见
[本分支发布页](https://github.com/gooesman/AnotherVaporAuth/releases/latest)，试用包来自
[本分支构建](https://github.com/gooesman/AnotherVaporAuth/actions/workflows/windows-preview.yml)，
下方下载链接仍属于原项目。电脑端名为 **AVA-pc**，可在设置里的“软件更新”中查询
本分支正式发布的版本、下载并打开安装程序；手机端也有同样入口，由系统确认安装。
更新默认通过 GH-Proxy 加速源直连下载，失败时回退 GitHub，也可手动选择官方源。
官方请求可复用已开启的代理；两种来源均支持并行下载、速度和剩余时间显示，
并按 GitHub 官方元数据进行整包 SHA-256 校验。

Android 试用包名为 **AVA Fork**（`pro.dotslash.ava.fork`），是使用固定 Fork
签名的 ARM64 release 优化构建，可与原版 AVA、此前的 **AVA dev** 同时安装并保留旧应用数据。
首次需导出各账号的 `.maFile` 后导入新应用；后续相同签名且版本号递增的 AVA Fork
可直接覆盖更新。详见[安装与迁移步骤](docs/windows-steam-switch.md#android-installation-and-migration)。

## 原项目下载

| | |
|---|---|
| **Android** | [Google Play](https://play.google.com/store/apps/details?id=pro.dotslash.ava) · [直发 APK](https://ava.dotslash.pro/#download)（国内可直连，不需要 Play 服务） |
| **Windows** | [安装版](https://github.com/freefrank/AnotherVaporAuth/releases/latest) · 同一个 release 里还有免安装的单文件便携版 |
| **macOS** | [DMG](https://github.com/freefrank/AnotherVaporAuth/releases/latest) —— 仅 Apple Silicon，首次打开见 [说明](#macosapple-silicon) |
| **Linux** | [AppImage](https://github.com/freefrank/AnotherVaporAuth/releases/latest) |

从 **Steam Desktop Authenticator** 过来？整个 `maFiles/` 文件夹都能导入，**包括加密的**——不用重新绑定，也没有 7 天交易冷却。有一份[图文指南](https://ava.dotslash.pro/zh/guide/move-steam-authenticator/)。

<p align="center">
  <img src="posts/zh/recruit/home-neon.png" width="30%" alt="令牌验证码" />
  <img src="posts/zh/recruit/confirmations.png" width="30%" alt="交易确认" />
  <img src="posts/zh/recruit/home-pixel.png" width="30%" alt="像素皮肤" />
</p>

---

> **安全提示：** 在电脑上做二次验证会削弱 2FA 的意义 —— 设备一旦被入侵，令牌也随之暴露。
> 能用 Steam 官方手机 App 就尽量用。务必备份你的 `maFiles` 和撤销码（revocation code）。
> 使用风险自负。

## 功能亮点

- **账户概览（本分支试用功能）** —— 电脑和 Android 共用钱包余额、待到账金额、
  在售/暂挂/待确认物品概览，可选择显示的卡片；新增好友列表、双向交易报价编辑
  和应用内短信验证获取备用登录码。设置中可关闭启动身份验证，账户文件仍保持加密。
  Android 试用包为独立的 **AVA Fork**，首次安装不覆盖旧应用；详见[试用说明](docs/windows-steam-switch.md)。
  手机首页在竖屏和横屏下都以令牌和账号列表为主：点按切换当前令牌，长按直接进入该账号概览；
  市场、好友和其他账号功能从概览进入，不再经过长按菜单。

- **可选 Steam 加速（本分支试用功能）** —— 导入 HTTP／HTTPS Clash 订阅（支持用户名和密码）并选择节点，
  用于 AVA 内的 Steam 请求，软件更新也可复用已经开启的线路。默认手动开启，可选自动启动；检测到外部代理或 VPN 时
  暂停内置组件，不修改系统代理或接管其他软件。首页小入口区分组件运行和登录接口/社区连接结果，
  不依赖系统 VPN 图标。见[范围与限制](docs/windows-steam-switch.md#optional-steam-connectivity)。

- **库存品质与查价（本分支试用功能）** —— 库存和交易选物图标增加淡品质色细边框。
  右键、长按或点击物品菜单可按需查看 Steam 市场参考价与币种，并打开对应市场页面，
  不改变物品勾选。Windows 账号切换页同时显示 Steam 是否运行；能核实本机活动进程时显示当前账号。
  市场和交易库存支持名称搜索、按 Steam 标签筛选类型与品质；切换筛选保留已选物品及数量。

- **Windows Steam 账号切换（本分支试用功能）** —— 从账户概览、设置页或账号右键菜单选择
  本机已记住登录信息的 Steam 账号，正常退出并重启 Steam；修改前备份设置，
  同页也可选择 AVA 账号，拖框识别电脑屏幕上的 Steam 登录二维码，核对后批准登录；
  截图只在本机内存解码。无 AVA 会话时可先重新登录。见[试用说明](docs/windows-steam-switch.md)。

- **maFile 兼容** —— 读写旧版 `.maFile` 格式（PBKDF2/SHA1 + AES-256-CBC），老账户零成本迁移，随时可导出。还能导入整个 Steam Desktop Authenticator 的 `maFiles/` 文件夹——**包括加密的**（把 `manifest.json` 和 `.maFile` 一起选中；salt 与 IV 存在 manifest 里，孤立的加密 maFile 谁也解不开）——以及其他工具的变体（Steam++ / Watt Toolkit），包括没有 SteamID 的导出（作为「仅验证码」账户导入，验证码离线可用）。
- **Steam Guard 验证码** —— 每账户列表 + 实时倒计时环、点按复制；点名称在 用户名 / 昵称 / ID 间切换。显示方式同时应用于首页账户列表和当前账户面板，在本机保存，电脑和手机重启应用后都会恢复上次选择。
- **应用内批准登录** —— 在 AVA 内弹窗批准/拒绝 Steam 登录（显示设备 + 位置），与官方 App 一致，基于轮询、无需推送。
- **待办中心** —— 一个带页签的界面（手机账户右滑、电脑账户右键进入），集中处理所有等你决定的事：
  **确认**（交易 / 市场，批量接受/拒绝，原生 JSON、无内嵌 WebView）、**报价**
  （收到 / 发出 / 历史，可展开卡片显示双方物品，赠送 / 只给不收 / 暂挂警示条，
  接受后自动衔接对应的 mobileconf 确认）。
- **Steam 家庭组** —— 从账户概览或桌面右键菜单进入的只读家庭组页（成员、角色、名额、冷却），
  收到的邀请也在这里：先做加入前预检，再长按加入。*（实验性）*
- **长按确认** —— 处理已有交易报价、单条确认、加入家庭组、删除账号时，
  用按住不放完成，带逐渐加速的震动；各道长按门槛与震动都有独立的设置开关。
  创建新报价则在审阅双方账号与物品后，点击发送。
- **库存与市场** —— 浏览账户的 Steam 库存（像 Steam 一样按游戏选择，相同物品堆叠），
  并把物品上架到社区市场：实时 Steam 费率、最高/最低成交走势、「你到手 ⇄ 买家支付」
  联动定价、批量上架、可选自动确认；「我的出售」页展示在售、暂挂和待确认记录。从账户概览或桌面右键菜单进入。
- **自动刷新登录** —— access token 按需用 refresh_token 刷新；refresh_token 失效时可用保存的密码 + 账户自身 TOTP 无界面全量重登。
- **登录方式** —— 密码 + **扫码**、会话刷新、添加验证器、扫描他人二维码批准其登录。
- **应用锁** —— 6 位 PIN 保护一个存于设备的**平台安全存储** 的随机 256 位密钥，由它加密本地存储（AES-256-GCM）。默认启动验证，其下可选指纹 / Windows Hello / 设备密码解锁；关闭启动验证会同时停用系统解锁，重新开启后需单独启用。关闭启动验证时，便利凭据仅保存在本机系统安全存储；更改 PIN 后重新开启验证。
- **加密同步**（可选）—— 把账户放到你自己掌控的 WebDAV 服务器上（Nextcloud、群晖，随便哪个）。所有内容在离开设备之前就已加密——服务器存到的是密文，永远看不到口令。冲突按账户而非按文件解决，所以两台设备各改各的账户时都不会丢。不配置就不启用。
- **动态头像** —— 拉取每个账户的 Steam 头像与头像框并播放（GIF 原生;APNG 自行解析并逐帧合成,正确处理每帧的偏移 / 混合 / dispose,带偏移的帧不再闪烁）。
- **外观与皮肤** —— 朴素的**浅色 / 深色 / 跟随系统**外观,以及独立的**皮肤**层(无 / 霓虹赛博朋克 / 像素复古),每套皮肤都是数据驱动的特效包,各有专属氛围；下拉刷新统一使用小巧圆环，颜色和边框随皮肤适配。
- **设备管理** —— 查看登录了某账户的所有设备与浏览器会话(平台、大致地点、
  最近活跃时间),可远程注销其中任意一台;本机会被标记且不能自注销。
- **兑换 Steam 密钥** —— 从账户概览或桌面右键菜单把产品密钥激活到该账户,Steam 的拒绝理由
  会写成人话(输错、已拥有、已被使用、地区不符、需要本体游戏、被限流)。
  激活不可撤销,因此提交前必定二次确认,失败也绝不自动重试。
- **桌面端窗口记得你放在哪** —— 位置、大小与最大化状态在两次启动之间保留；如果上次那台显示器已经拔了，窗口会被挪回你还看得见的屏幕，而不是恢复到一个不可见的位置。
- **首次启动手势教程**(触屏设备;桌面端改为账户行右键菜单)。
- **多语言**（English、简体中文、繁體中文、Deutsch、Français、Español、Русский）。
- **应用内调试日志**（设置 → 调试日志）—— 可复制的 Steam 流程网络追踪，便于诊断。

## 目录结构

```
app/        Flutter 应用（详见 app/README.md）
docs/       设计文档（docs/specs/）与实施计划（docs/plans/）
infra/      Cloudflare workers（权益/版本、反馈）
installer/  Windows 安装包打包
tool/       发布工具（Play 上传、R2 分发、文档 lint）
```

**`legacy`** 分支保留了启发本项目的那个 .NET WinForms 版 Steam Desktop
Authenticator —— 仅供参考存档，AVA 与它不共享任何代码。

## 构建

需要 Flutter SDK（3.44.x）。详见 `app/README.md`。

```sh
cd app
flutter pub get --enforce-lockfile
flutter test                       # 1376 项测试
flutter run -d linux               # 或 windows / macos

# Android 分 play / cn 两个 flavor，不带 --flavor 的构建会直接失败。
flutter build apk --release --split-per-abi --flavor cn --dart-define=AVA_CHANNEL=cn
```

每推送一个 `v*` 标签（或手动触发），GitHub Actions 会自动构建桌面版发布，
见 `.github/workflows/desktop-release.yml`：

- **Windows 安装包** —— scene 风格的单文件 `AVA-…-setup.exe`，由我们自研的
  Flutter 安装器（`installer/`）打包：无边框霓虹像素界面，装到用户目录免 UAC，
  自带开始菜单/桌面快捷方式与标准卸载项；卸载不会动账户数据。
- **Linux AppImage** —— 单文件 `AVA-…-linux-x86_64.AppImage`。

**便携版（Windows）**：由独立 workflow（`.github/workflows/windows-portable.yml`）
打包为**单文件** `AVA-…-portable.exe`（NSIS，`tool/portable.nsi`），免安装、放哪都能跑；
桌面端设置里有独立的**便携模式**开关：开启后新账号写入程序旁的 `maFiles`，
关闭后写入 AppData，两个目录中的账号仍会同时读取。开启、关闭时都可选择复制现有
账号，源数据保留，同 Steam ID 的账号跳过。便携库使用独立密码（至少 12 位），
将整个 `maFiles` 文件夹带到另一台电脑即可解锁；加密文件必须与 `manifest.json`
一起保留。程序设置不随 `maFiles` 携带，已有的 WebDAV 设置同步不变，便携账号
不参与账号同步。新电脑首次打开时，先同意隐私说明并设置本机 PIN，再用独立密码
解锁 `maFiles`。

## macOS（Apple Silicon）

自 v1.2.0 起，每个 tag 版本的 [Releases](https://github.com/freefrank/AnotherVaporAuth/releases)
都提供 DMG——**仅 arm64**（M1 及之后的机型；不出 Intel 版）。打开 DMG，把
**AVA** 拖进 **Applications** 即可。

应用带 ad-hoc 签名但**未经 Apple 公证**（公证需要 $99/年的开发者账号；这是个
免费的社区项目），所以首次启动会被 Gatekeeper 拦下。放行方法：

1. **右键**（或按住 Control 点击）`AVA.app` → **打开** → **打开**。较新的
   macOS 上这个按钮可能要第二次尝试才出现，或者去
   **系统设置 → 隐私与安全性 → 「仍要打开」**。
2. 如果 macOS 提示应用「已损坏，无法打开」——那是未公证下载被打上的隔离标记，
   不是真的损坏。清掉它：

   ```sh
   xattr -dr com.apple.quarantine /Applications/AVA.app
   ```

两种都只需一次，之后正常启动。只对来源可信的软件做这件事——对 AVA 来说，
可信来源就是本仓库的 Releases 页：每个 DMG 都由 GitHub Actions 从打了 tag
的提交公开构建。

## 字体

所有字体均**打包进构建**（运行时不下载），在 `app/pubspec.yaml` 中声明；
详见 `app/assets/fonts/README.md`。

| 字体 | 主题 | 用途 | 来源 / 许可 |
|---|---|---|---|
| [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) | 霓虹 | 标题 | OFL 1.1 |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) | 霓虹 | 验证码 | OFL 1.1 |
| [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | 霓虹 | 中文（CJK）回退 | OFL 1.1 |
| [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font) | 像素 | 标题 + 验证码（拉丁 + 完整 CJK 含简/繁、假名、谚文） | OFL 1.1 |

像素主题使用**完整** Fusion Pixel 字体，实现完整 CJK 覆盖（含昵称中的生僻字）。
Noto Sans SC 子集化到 CJK 汉字区块（简体 + 繁体）。拉丁字体覆盖 ASCII。

## 致谢

原版 AVA 由 freefrank 用 Flutter 从零编写，本仓库是该项目的 Fork。AVA 的灵感来自
老牌工具 **Steam Desktop Authenticator**（Jessecar96 及贡献者开发），并保持与其
`.maFile` 格式兼容，方便老用户迁移。Steam 认证协议参考：
[SteamAuth](https://github.com/geel9/SteamAuth)、
[node-steam-session](https://github.com/DoctorMcKay/node-steam-session)。

## 隐私

账户、密钥与验证码保存在设备上，Steam 请求发给 Valve，不经过本分支自营的后端。
启用可选加速后，连接经过所选节点或检测到的外部代理，并保持正常 TLS 证书校验。
本分支关闭 Pro 验证、支付和广告，默认不检查原版更新。反馈入口打开本分支的
GitHub Issues，不自动发送报告或日志。可选的 WebDAV 同步使用你指定的服务器。
详见[本分支隐私说明](docs/fork-privacy-zh.md)（[English](docs/fork-privacy.md)）；
仓库内的原版隐私政策保留供参考。

## 许可

见 [LICENSE](LICENSE)。打包字体各自保留其 OFL 1.1 许可。
