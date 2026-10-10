# Fork 安装包与应用内更新

本 Fork 的更新只读取 `gooesman/AnotherVaporAuth` 的公开、非预发布 GitHub Release。不会使用上游更新服务，也不会把工作流的临时 artifact 当成正式更新。

## 版本与文件名

预览构建从 `app/pubspec.yaml` 读取三段版本号，例如 `1.5.0`。Windows 应用和 Android APK 使用相同的构建编号：`100000 + windows-preview.yml 的 GITHUB_RUN_NUMBER`。重新运行同一次构建不会增加编号；要发布新的更新，需要新的一次预览 run。

正式标签必须为 `v<SEMVER>+<BUILD>`，例如 `v1.5.0+100042`。同版本再次修复时必须增加 BUILD；不能发布低于已有稳定版本的版本号或构建编号。

正式 Release 包含：

- `AVA-pc-v1.5.0+100042-windows-x64-setup.exe`
- `AVA-Fork-v1.5.0+100042-android-arm64.apk`
- `SHA256SUMS.txt`
- `release-provenance.json`
- `mihomo-v1.19.32-source.tar.gz`、`mihomo-LICENSE.txt`、`mihomo-NOTICE.txt`

Windows 安装器显示为 AVA-pc。内部仍使用 `ava.exe`、`%LOCALAPPDATA%\Programs\AVA` 和原有应用数据目录。NSIS 的 `APPVER` 参数只使用三段版本号；完整版本和构建编号写入应用和预览元数据。

Android 目前使用独立包名 `pro.dotslash.ava.fork`、显示名称 AVA Fork、固定私有签名，ARM64 / CN debug 预览。原 AVA dev 的数据保留在原应用内；首次迁移使用导出／导入，此后的同包名、同签名新版可以覆盖更新。私钥只能由仓库 Secrets 提供，不得提交到 Git。

## 先构建，再手动发布

首次使用前，需要把发布工作流合入本 Fork 的默认分支，GitHub 才会提供该工作流的
手动运行入口。预览分支的构建成功不等于已经发布稳定版本。

1. 运行 **Windows and Android preview**，等待整个 run 成功。该流程会检查、构建两端，并生成 Windows 单文件安装器。现有 Windows 目录 artifact 和 Android APK artifact 保留；额外生成 `AVA-windows-installer-preview-<SHA>` 安装器 artifact。
2. 在 artifact 保留期（14 天）内检查安装包。两个安装包 artifact 分别包含 `windows-preview.json` / `android-preview.json`，记录仓库、源工作流、run ID、run number、attempt、提交、版本、构建号、文件名、大小和 SHA-256。Android 还记录已验证的包名与证书摘要。
3. 手动运行 **Promote AVA Fork preview**，填写成功预览的 run ID 和这次版本的更新说明。此操作会发布稳定版本并设为 Latest；只在确实准备发布时执行。

发布流程不会重新构建或执行下载的安装包。它核对 run 属于本仓库的指定预览工作流、整个 run 已成功、源提交的 pubspec 版本、元数据和构建号，并核对 GitHub artifact ZIP 摘要、安装包大小与 SHA-256。APK 在发布时仅改名，字节和签名保持原样。

Android 包内包含固定版本的可选 Mihomo 组件，构建时会核对组件原始字节的 SHA-256
和许可证。相同提交的 `AVA-steam-core-source-<SHA>` artifact 提供匹配源码和声明；
正式发布必须同时核对并附带这些文件。Windows 按需下载同版本组件，安装目录保留
其许可证和版本信息。向他人提供 APK 时，也应同时提供该组件源码包和声明。

流程先创建草稿，上传文件，再核对 GitHub Release API 返回的每个文件摘要，全部通过后才公开。已有标签或 Release 一律拒绝覆盖；发布中途失败留下的草稿应先人工检查。只重跑失败 job 时，可以使用同一 run 的早先成功 artifact；提交、版本和构建号必须完全一致。

## 应用内安装

用户先点击下载，应用按 GitHub Release asset 的 SHA-256 校验文件，再单独确认安装。Windows 打开安装器并保留手动安装界面。Android 打开系统安装确认页，权限不足时提供前往系统设置的独立按钮，并额外核对 APK 的包名、版本号和当前签名。打开系统安装页不等于已经完成安装。

工作流有新的构建产物，不代表已有正式更新；必须完成上述手动发布。APK 签名不匹配时，更新流程会拒绝安装，不会卸载原应用或清除账户数据。
