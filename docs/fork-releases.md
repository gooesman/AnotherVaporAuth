# GooeSteamKit 安装包与应用内更新

GooeSteamKit 是基于原版 AVA 的独立 Fork。更新只读取 `gooesman/AnotherVaporAuth` 的公开、非预发布 GitHub Release。不会使用上游更新服务，也不会把工作流的临时 artifact 当成正式更新。Windows 与 Android 共用[盾牌大鹅设计](../app/assets/icon/gooes_steamkit.png)。Android 8 及以上采用原生 `VectorDrawable` 前景与纯色深背景，由桌面应用提供图标遮罩；两个启动别名均使用同款自适应图标。较旧 Android 系统使用新版盾牌图案 PNG。

## 版本与文件名

预览构建从 `app/pubspec.yaml` 读取三段版本号，例如 `1.5.0`。Windows 应用和 Android APK 使用相同的构建编号：`100000 + windows-preview.yml 的 GITHUB_RUN_NUMBER`。重新运行同一次构建不会增加编号；要发布新的更新，需要新的一次预览 run。

正式标签必须为 `v<SEMVER>+<BUILD>`，例如 `v1.5.0+100042`。同版本再次修复时必须增加 BUILD；不能发布低于已有稳定版本的版本号或构建编号。

正式 Release 包含：

- `AVA-pc-v1.5.0+100042-windows-x64-setup.exe`
- `AVA-Fork-v1.5.0+100042-android-arm64.apk`
- `SHA256SUMS.txt`
- `release-provenance.json`
- `mihomo-v1.19.32-source.tar.gz`、`mihomo-LICENSE.txt`、`mihomo-NOTICE.txt`

安装包文件名保留 `AVA-pc-`、`AVA-Fork-` 前缀，供旧版应用内更新器识别；文件名不随应用显示名称更改。

Windows 应用、安装器与快捷方式统一显示为 GooeSteamKit（此前为 AVA-pc）。内部仍使用 `ava.exe`、`%LOCALAPPDATA%\Programs\AVA`、AVA 存储标识和原有应用数据目录。安装包附带按内容哈希命名的独立 ICO，供桌面与开始菜单快捷方式引用，避免仅替换同一路径 EXE 后仍沿用旧图标缓存。更新会对指向当前安装的既有快捷方式改名并更新图标引用，保留指向其他安装的快捷方式。NSIS 的 `APPVER` 参数只使用三段版本号；完整版本和构建编号写入应用和预览元数据。

Android 应用名称与手机桌面标签统一为 GooeSteamKit。保持现有 AVA Fork 的包名 `pro.dotslash.ava.fork` 和固定私有签名，仍是 ARM64 / CN release 优化构建（AOT、不可调试）。递增版本号后，现有 AVA Fork 可直接覆盖更新，保留账号和设置，无需重新导入。原版 AVA 和旧 AVA dev 仍分开安装，只有从这些应用首次迁移才需要导出／导入，旧数据保留在原应用内。私钥只能由仓库 Secrets 提供，不得提交到 Git。

从旧 AVA Fork 调试预览升级到 release 优化包不改变包名或证书，递增构建号后可直接覆盖。
构建会检查 APK 内的 AOT 代码、不可调试标志及 R8 原始类名映射；广告／计费门禁不会仅凭混淆后的 dex 类名判断。

## 先构建，再手动发布

首次使用前，需要把发布工作流合入本 Fork 的默认分支，GitHub 才会提供该工作流的
手动运行入口。预览分支的构建成功不等于已经发布稳定版本。

1. 运行 **Windows and Android preview**，等待整个 run 成功。该流程会检查、构建两端，并生成 Windows 单文件安装器。现有 Windows 目录 artifact 和 Android APK artifact 保留；额外生成 `AVA-windows-installer-preview-<SHA>` 安装器 artifact。
2. 在 artifact 保留期（14 天）内检查安装包。两个安装包 artifact 分别包含 `windows-preview.json` / `android-preview.json`，记录仓库、源工作流、run ID、run number、attempt、提交、版本、构建号、文件名、大小和 SHA-256。Android 还记录已验证的包名与证书摘要。
3. 手动运行 **Promote GooeSteamKit preview**，填写成功预览的 run ID 和这次版本的更新说明。此操作会发布稳定版本并设为 Latest；只在确实准备发布时执行。

发布流程不会重新构建或执行下载的安装包。它核对 run 属于本仓库的指定预览工作流、整个 run 已成功、源提交的 pubspec 版本、元数据和构建号，并核对 GitHub artifact ZIP 摘要、安装包大小与 SHA-256。APK 在发布时仅改名，字节和签名保持原样。

Android 包内包含固定版本的可选 Mihomo 组件，构建时会核对组件原始字节的 SHA-256
和许可证。相同提交的 `AVA-steam-core-source-<SHA>` artifact 提供匹配源码和声明；
正式发布必须同时核对并附带这些文件。Windows 按需下载同版本组件，安装目录保留
其许可证和版本信息。向他人提供 APK 时，也应同时提供该组件源码包和声明。

流程先创建草稿，上传文件，再通过草稿的数字 ID 核对 GitHub Release API 返回的每个文件摘要，全部通过后才公开并核实 Latest。已有标签或公开 Release 一律拒绝覆盖；发布中途失败留下的草稿应先检查。确认草稿已完整上传后，可在重新运行发布工作流时填写其 `resume_draft_id`，同时提供原预览 run ID 和相同更新说明。恢复过程不会上传或覆盖文件，必须逐一匹配草稿 ID、版本、源提交、说明以及全部文件的大小和摘要。缺少文件或校验失败会继续保持草稿。只重跑失败 job 时，可以使用同一 run 的早先成功 artifact；提交、版本和构建号必须完全一致。

## 应用内安装

两端默认使用“自动加速”：安装包先从 GH-Proxy 的 `axisnow.gh-proxy.org` 直连下载，
失败时尝试 `v4.gh-proxy.org`，最后回退 GitHub 官方源；也可在下载前选择只使用官方源。
这些是适合国内访问的第三方加速入口，并非本 Fork 自有的大陆 CDN，不承诺固定速度。
节点来自[服务公开页面](https://gh-proxy.com/)，用法见[官方说明](https://gh-proxy.com/docs/github-accelerator)。
加速源只传输公开安装包，不接收 Steam 数据、订阅地址或代理凭据。连接严格校验 TLS，
只接受固定节点对当前官方安装包的精确路径，不跟随镜像重定向。版本、大小与 SHA-256
仍直接读取 GitHub 官方 API，不能采用镜像提供的校验值。官方 API 不可达时不能确认新版。

加速源不复用应用代理，也不启动代理组件；已有系统 VPN／TUN 仍可能承载其网络流量。
官方 API 和官方文件下载优先复用检测到的系统 HTTP 代理，没有外部代理时可以复用已运行
的内置加速。更新不会改系统网络设置。每次切源都会取消并等待前一源结束、清空本次文件
后重新下载，不混合不同来源的数据；界面同步更新实际来源、进度和速度。

8 MiB 及以上的安装包使用最多四路分段下载；官方源短暂断线时只重试当前分段，
加速源失败时清空本次文件并切源重下。服务端不支持
分段时自动使用普通下载。每段核对响应区间，整包仍按 GitHub 提供的 SHA-256 校验。
页面显示已下载大小、近期速度和预计剩余时间；下载完成后显示校验状态。取消或关闭页面
会中止本次下载并清理临时文件，下次下载重新开始，不宣称跨次断点续传。

用户先点击下载，应用按 GitHub Release asset 的 SHA-256 校验文件，再单独确认安装。Windows 打开安装器并保留手动安装界面。Android 打开系统安装确认页，权限不足时提供前往系统设置的独立按钮，并额外核对 APK 的包名、版本号和当前签名。打开系统安装页不等于已经完成安装。

工作流有新的构建产物，不代表已有正式更新；必须完成上述手动发布。APK 签名不匹配时，更新流程会拒绝安装，不会卸载原应用或清除账户数据。
