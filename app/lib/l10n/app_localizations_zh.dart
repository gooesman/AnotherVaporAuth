// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get steamSwitchTitle => '切换 Steam 账号';

  @override
  String get steamSwitchUnifiedHelp =>
      '选中账号后点击切换，即可打开 Steam 并登录。已导入的账号优先使用 Steam 记住的登录信息，需要验证时，有在线会话即可自动批准本次本机登录二维码。未导入的账号仍可使用 Steam 已记住的登录信息。请先退出正在运行的游戏。';

  @override
  String get steamSwitchHelp =>
      '可切换已在本机 Steam 登录过并记住登录信息的账号。将令牌导入 GooeSteamKit 不代表该账号已在 Steam 客户端登录。';

  @override
  String get steamSwitchPath => 'Steam 安装目录';

  @override
  String get steamSwitchNotFound => '未找到 Steam，请选择 steam.exe 以定位安装目录。';

  @override
  String get steamSwitchBrowse => '选择 steam.exe';

  @override
  String get steamSwitchNoAccounts =>
      '本机尚无 Steam 登录记录。请先在 Steam 登录并记住登录信息，再刷新列表。';

  @override
  String get steamSwitchNoMatch =>
      '所选账号尚无本机登录记录。可使用上方的一键登录；登录并记住登录信息后，刷新即可从下方列表切换。';

  @override
  String get steamSwitchNeedsLogin => '请先在 Steam 登录此账号并记住登录信息，再刷新列表。';

  @override
  String get steamSwitchButton => '切换账号';

  @override
  String steamSwitchConfirm(String account) {
    return 'Steam 将关闭并重新启动，以登录 $account。请先结束游戏，并等待 Steam 云存档同步完成。是否继续？';
  }

  @override
  String get steamSwitchStopping => '正在等待 Steam 退出…';

  @override
  String get steamSwitchBackingUp => '正在备份 Steam 设置…';

  @override
  String get steamSwitchConfiguring => '正在设置 Steam 登录账号…';

  @override
  String get steamSwitchStarting => '正在启动 Steam…';

  @override
  String get steamSwitchRestoring => '正在恢复 Steam 设置…';

  @override
  String get steamSwitchLaunched => '已启动 Steam，请在客户端确认登录账号。若出现提示，请重新登录。';

  @override
  String get steamSwitchBackup => '设置备份位置';

  @override
  String get steamSwitchInvalidPath =>
      '无法读取此 Steam 安装目录或设置。请选择正确的 steam.exe 后重试。';

  @override
  String get steamSwitchCloseFailed => 'Steam 未能正常退出。请手动退出 Steam 后重试。';

  @override
  String get steamSwitchBusy => '另一个账号切换操作正在进行，请稍后重试。';

  @override
  String get steamSwitchChanged => '切换期间 Steam 设置发生了变化。请退出 Steam，刷新列表后重试。';

  @override
  String get steamSwitchFailed => '未能完成账号切换。请检查 Steam 后重试。';

  @override
  String get steamSwitchRecoveryNeeded => '切换失败，部分设置未能恢复。请保留下方备份，恢复设置后再重试。';

  @override
  String get appTitle => 'GooeSteamKit';

  @override
  String get navAccounts => '账户';

  @override
  String get navSettings => '设置';

  @override
  String get unlockTitle => '解锁';

  @override
  String get unlockPrompt => '请输入加密口令';

  @override
  String get unlockButton => '解锁';

  @override
  String get unlockInvalid => '口令无效。';

  @override
  String get unlockWithBiometric => '用指纹 / 设备密码解锁';

  @override
  String get unlockLoading => '正在解锁…';

  @override
  String get unlockCantUnlock => '无法解锁？';

  @override
  String get resetVaultTitle => '重置加密数据';

  @override
  String get resetVaultBody =>
      '将删除本机存储的全部账户条目与加密密钥，之后需要重新导入你的 maFile 备份。你的 Steam 账户和已绑定的验证器不受影响。\n\n适用于正确 PIN 一直被拒的情况——通常发生在备份恢复或换机迁移之后：硬件密钥不会离开原设备，恢复出来的数据永远无法解密。\n\n此操作无法撤销。';

  @override
  String get resetVaultConfirm => '全部删除并重置';

  @override
  String get storeErrorTitle => '本地数据无法读取';

  @override
  String get storeErrorBody =>
      'GooeSteamKit 的本地账户数据库（manifest.json）缺失或损坏。写入被中断或恢复不完整都可能导致此问题。请先重试；若持续失败，可重置后重新导入你的 maFile 备份。';

  @override
  String get storeRepair => '尝试修复';

  @override
  String storeActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get pinSetupTitle => '设置解锁 PIN';

  @override
  String get pinSetupPrompt => '用 6 位 PIN 保护 GooeSteamKit。解锁时输入它（或用指纹）。';

  @override
  String get pinLabel => '6 位 PIN';

  @override
  String get pinConfirmLabel => '确认 PIN';

  @override
  String get pinSetButton => '设置 PIN';

  @override
  String get settingsSet => '设置';

  @override
  String get pinChangeTitle => '修改 PIN';

  @override
  String get pinCurrentLabel => '当前 PIN';

  @override
  String get pinNewLabel => '新 PIN';

  @override
  String get pinSixDigits => '请输入 6 位 PIN。';

  @override
  String get pinMismatch => '两次 PIN 不一致。';

  @override
  String get unlockBiometricReason => '解锁 GooeSteamKit';

  @override
  String get settingsBiometric => '使用系统解锁';

  @override
  String get settingsBiometricDesc =>
      '启动验证开启时，可用指纹、Windows Hello 或设备密码代替 GooeSteamKit PIN。关闭启动验证会同时停用此项；重新开启后需单独启用。';

  @override
  String get settingsBiometricNeedPasskey => '请先设置加密口令。';

  @override
  String get settingsBiometricUnavailable => '此设备未设置生物识别或屏幕锁。';

  @override
  String get settingsBiometricEnabled => '已启用系统解锁';

  @override
  String get settingsHoldConfirm => '长按确认';

  @override
  String get settingsHoldConfirmDesc =>
      '不可逆的接受类操作（交易、确认）需长按生效；关闭后单击立即生效，批量操作仍会弹窗确认。';

  @override
  String get settingsDeleteHold => '删除需长按确认';

  @override
  String get settingsDeleteHoldDesc => '删除账号的确认按钮需按住蓄满才生效，误触点一下不会删号。';

  @override
  String get accountSessionInvalid => '登录已失效——点按重新登录';

  @override
  String get settingsHaptics => '震动反馈';

  @override
  String get settingsHapticsDesc => '长按确认过程中与完成时的触觉反馈。';

  @override
  String get settingsBlockScreenshots => '禁止截屏';

  @override
  String get settingsBlockScreenshotsDesc =>
      '让 GooeSteamKit 不出现在截屏、录屏和最近任务预览里。代价是投屏时窗口会变黑，也没法再截图附到反馈里。';

  @override
  String get passkeyLabel => '口令';

  @override
  String get accountsEmpty => '暂无账户。导入 maFile 或登录以添加。';

  @override
  String get emptyAddAccount => '添加账户';

  @override
  String get accountReady => '已就绪';

  @override
  String get tutCodeTitle => '实时令牌';

  @override
  String get tutCodeBody => '点击大号令牌即可复制;点击账户名可在用户名 / 昵称 / SteamID 间切换。';

  @override
  String get tutSwipeRightTitle => '右滑 → 交易确认';

  @override
  String get tutSwipeRightBody => '在账户条目上向右滑动,直接打开它的交易确认列表。';

  @override
  String get tutSwipeLeftTitle => '左滑 → 更多操作';

  @override
  String get tutSwipeLeftBody => '向左滑动可刷新会话、导出 maFile 或删除账户。';

  @override
  String get tutLongPressTitle => '长按 → 库存与市场';

  @override
  String get tutLongPressBody => '长按账户可浏览库存,并把物品上架到社区市场。';

  @override
  String get tutPullTitle => '下拉刷新';

  @override
  String get tutPullBody => '下拉账户列表可刷新头像并检查待处理的登录请求。';

  @override
  String get tutSkip => '跳过';

  @override
  String get tutNext => '下一步';

  @override
  String get tutDone => '知道了';

  @override
  String get settingsTutorial => '手势教程';

  @override
  String get settingsTutorialDesc => '重新播放主屏手势引导(滑动、长按、下拉刷新)。';

  @override
  String get settingsTutorialReplay => '重新播放';

  @override
  String get welcomeTitle => '欢迎使用 GooeSteamKit';

  @override
  String get welcomeSubtitle => '本机加密保存你的验证器。开始前请选择一种方式。';

  @override
  String get welcomeLoginCta => '登录 Steam 账户';

  @override
  String get welcomeLoginSub => '新建一个验证器';

  @override
  String get welcomeImportCta => '导入 .maFile';

  @override
  String get welcomeImportSub => '迁移已有账户';

  @override
  String get welcomeSyncCta => '从同步恢复';

  @override
  String get welcomeSyncSub => '从已有的同步库拉取你的账户';

  @override
  String get copyCode => '复制验证码';

  @override
  String get codeCopied => '验证码已复制到剪贴板';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get copySteamId => '复制 SteamID';

  @override
  String get pendingTitle => '待办';

  @override
  String get pendingTabConfirmations => '确认';

  @override
  String get pendingTabOffers => '报价';

  @override
  String get confirmationsTitle => '确认';

  @override
  String get confirmationsEmpty => '没有待处理的确认。';

  @override
  String get confirmationsRefresh => '刷新';

  @override
  String get confAccept => '接受';

  @override
  String get confDecline => '拒绝';

  @override
  String get confSelectAll => '全选';

  @override
  String get confAcceptSelected => '批量接受';

  @override
  String get confDeclineSelected => '批量拒绝';

  @override
  String get confAcceptAll => '全部接受';

  @override
  String get confRejectAll => '全部拒绝';

  @override
  String confAcceptAllConfirm(int count) {
    return '接受全部 $count 项确认?';
  }

  @override
  String confRejectAllConfirm(int count) {
    return '拒绝全部 $count 项确认?';
  }

  @override
  String get confAcceptAllWarn => '将一次性批准所有待处理的交易与市场上架,请确认你认识其中每一项。';

  @override
  String get confRejectAllWarn => '将一次性取消所有待处理的确认。';

  @override
  String confPending(int count) {
    return '$count 项待确认';
  }

  @override
  String get confAllProcessed => '已全部处理';

  @override
  String get confTypeTrade => '交易';

  @override
  String get confTypeMarket => '市场上架';

  @override
  String get confTypeOther => '确认';

  @override
  String get confTypeFamilyJoin => '家庭组邀请';

  @override
  String get confTypeApiKey => 'API 密钥';

  @override
  String get confTypePhoneChange => '更换手机号';

  @override
  String get confTypeAccountRecovery => '账户恢复';

  @override
  String get confTypeFeatureOptOut => '功能退出';

  @override
  String confProcessing(int count) {
    return '正在处理 $count 条确认…';
  }

  @override
  String confResult(int ok, int fail) {
    return '成功 $ok 条，失败 $fail 条';
  }

  @override
  String get confNeedsLogin => '会话已失效 —— 请重新登录该账户以刷新。';

  @override
  String get confRejected =>
      'Steam 拒绝了确认请求。这通常说明 maFile 与账户当前的验证器不匹配（购入账户较常见）——请移除验证器后重新绑定，或导入正确的 maFile；设备时间偏差过大也会导致此问题。';

  @override
  String get offersSegReceived => '收到';

  @override
  String get offersSegSent => '发出';

  @override
  String get offersSegHistory => '历史';

  @override
  String get offersEmpty => '没有交易报价。';

  @override
  String get offerGift => '赠送 — 你无需给出物品';

  @override
  String get offerOneSided => '你给出物品但一无所获';

  @override
  String get offerEscrow => '物品将被 Steam 暂挂后交付';

  @override
  String get offerAcceptHold => '长按接受';

  @override
  String get offerDecline => '拒绝';

  @override
  String get offerCancel => '取消报价';

  @override
  String get offerReceiveLabel => '你收到';

  @override
  String get offerGiveLabel => '你给出';

  @override
  String get offerAccepted => '已接受报价 — 请到「确认」页签完成确认';

  @override
  String get offerAcceptedNoConf => '已接受报价。';

  @override
  String offerActionFailed(String msg) {
    return '操作失败：$msg';
  }

  @override
  String get offerDeclined => '已拒绝报价。';

  @override
  String get offerCanceled => '已取消报价。';

  @override
  String get pendingTabInvites => '邀请';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」邀请你加入家庭组';
  }

  @override
  String get famInviteTitleGeneric => '家庭组邀请';

  @override
  String famInviteFrom(String inviter) {
    return '邀请人：$inviter';
  }

  @override
  String famInviteRole(String role) {
    return '角色：$role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return '成员 $used/$total';
  }

  @override
  String get famRoleAdult => '成人';

  @override
  String get famRoleChild => '儿童';

  @override
  String famRoleUnknown(int n) {
    return '角色 #$n';
  }

  @override
  String get famPreflightTitle => '加入前预检';

  @override
  String get famCheckWalletMatch => '钱包地区一致';

  @override
  String get famCheckWalletMismatch => '钱包地区不一致 —— Steam 限制加入';

  @override
  String get famCheckIpMatch => '常用 IP 匹配';

  @override
  String get famCheckIpMismatch => 'IP 与常用地点不符';

  @override
  String get famCheckCooldown => '加入后 1 年内不能更换家庭组（官方冷却）';

  @override
  String famJoinRestricted(int code) {
    return 'Steam 阻止了此次加入（限制码 $code）';
  }

  @override
  String get famInviteJoinHold => '加入（长按）';

  @override
  String get famInviteAwaiting2fa => '等待确认 —— 请到「确认」页签处理';

  @override
  String get famInviteJoined => '已加入 ✓';

  @override
  String get famInviteViewGroup => '查看家庭组 ›';

  @override
  String get famJoinSent => '已发起加入 —— 请到「确认」页签完成确认';

  @override
  String get famJoinDone => '已加入家庭组。';

  @override
  String famJoinFailed(String msg) {
    return '加入失败：$msg';
  }

  @override
  String get famInvitesEmpty => '没有待处理的家庭组邀请。';

  @override
  String get famAccountAction => '家庭组';

  @override
  String get famNotInGroup => '该账户不在任何家庭组中。';

  @override
  String famSummaryMembers(int used, int total) {
    return '成员 $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return '冷却 $days 天';
  }

  @override
  String get famInvitesSection => '邀请';

  @override
  String get famSectionMembers => '成员';

  @override
  String get famMemberYou => '（你）';

  @override
  String get famSectionPending => '待处理';

  @override
  String get famPendingComingSoon => '购买审批将在后续版本推出。';

  @override
  String get deviceSessionsAction => '登录设备';

  @override
  String get deviceSessionsTitle => '已登录的设备';

  @override
  String get deviceSessionsEmpty => '该账户没有已登录的设备。';

  @override
  String get deviceRevokeAction => '注销';

  @override
  String deviceRevokeConfirm(String name) {
    return '将「$name」从你的 Steam 账户注销?该设备需要重新登录。';
  }

  @override
  String deviceRevokeDone(String name) {
    return '已注销「$name」。';
  }

  @override
  String deviceRevokeFailed(String error) {
    return '注销设备失败:$error';
  }

  @override
  String get deviceCurrent => '(本机)';

  @override
  String get deviceSignedOut => '已登出';

  @override
  String get deviceUnnamed => '未知设备';

  @override
  String deviceLastSeen(String age) {
    return '$age前活跃';
  }

  @override
  String get devicePlatformSteam => 'Steam 客户端';

  @override
  String get devicePlatformWeb => '网页浏览器';

  @override
  String get devicePlatformMobile => '手机 App';

  @override
  String get devicePlatformUnknown => '未知';

  @override
  String deviceAgeDays(int n) {
    return '$n 天';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n 小时';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n 分钟';
  }

  @override
  String get deviceAgeNow => '刚刚';

  @override
  String get keyRedeemAction => '兑换密钥';

  @override
  String get keyRedeemTitle => '兑换 Steam 密钥';

  @override
  String keyRedeemFor(String account) {
    return '激活到 $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => '粘贴';

  @override
  String get keyRedeemSubmit => '兑换';

  @override
  String get keyRedeemNote =>
      '激活不可撤销，产品会直接加进这个账户。连续几个密钥被拒后 Steam 会封锁激活约一小时，提交前请先核对。';

  @override
  String keyRedeemConfirm(String account) {
    return '把这个密钥激活到 $account？之后无法撤销，也无法转到别的账户。';
  }

  @override
  String get keyRedeemDone => '密钥已激活。';

  @override
  String get keyRedeemGranted => '已加入库：';

  @override
  String get keyRedeemNoProducts => 'Steam 接受了密钥但没有返回产品名，请到该账户的库里确认。';

  @override
  String get keyRedeemNetworkError =>
      '连不上 Steam。如果是请求超时，Steam 可能已经处理过了——再试这枚密钥前，请先到该账户的库里确认。';

  @override
  String get keyErrInvalid => 'Steam 不认识这个密钥。请检查是否输错——0 与 O、1 与 I 很容易看混。';

  @override
  String get keyErrAlreadyOwned => '该账户已拥有这个产品。';

  @override
  String get keyErrAlreadyActivated => '这个密钥已被使用过——可能是本账户，也可能是别的账户。';

  @override
  String get keyErrRegionLocked => '该产品无法在此账户所在的国家/地区激活。';

  @override
  String get keyErrNeedsBaseProduct => '这是 DLC 或资料片，需要该账户先拥有本体游戏。';

  @override
  String get keyErrNeedsPs3Login => '该产品需要先在 PlayStation®3 主机上游玩过才能激活。';

  @override
  String get keyErrRateLimited => '最近被拒的密钥太多，Steam 会封锁激活约一小时，请稍后再试。';

  @override
  String keyErrUnknown(int code) {
    return 'Steam 拒绝了这个密钥（代码 $code）。';
  }

  @override
  String get loginOrApprove => '…或直接在 Steam 手机 App 点「允许」。';

  @override
  String get addErrPresent => '该账户已有验证器。';

  @override
  String get addErrConfirmEmail => '请先确认 Steam 发送的邮件，然后重试。';

  @override
  String get addErrLocked =>
      '该账户已被 Steam 锁定/限制 —— 请先到 help.steampowered.com 恢复后再添加验证器。';

  @override
  String get addErrRateLimited => '尝试次数过多，请稍后再试。';

  @override
  String get addErrFailed => '添加验证器失败。';

  @override
  String addErrSaveFailed(String code) {
    return '无法把验证器保存到本机，已在生效前停止设置。请记下这个撤销码,并从你的账户移除这个待处理的验证器,然后重试:$code';
  }

  @override
  String get addErrBadSms => '短信验证码错误，请重试。';

  @override
  String get debugLog => '调试日志';

  @override
  String get debugLogDesc => '用于诊断登录 / 确认的网络追踪';

  @override
  String get feedbackTitle => '反馈';

  @override
  String get feedbackDesc => '发现 bug 或有想法？直接发给开发者；想公开讨论也可以去 GitHub 提 issue。';

  @override
  String get feedbackSend => '发送反馈';

  @override
  String get feedbackMessageLabel => '反馈内容';

  @override
  String get feedbackMessageHint => '遇到了什么问题 / 想要什么功能？';

  @override
  String get feedbackContactLabel => '联系方式（选填）';

  @override
  String get feedbackContactHint => '邮箱或用户名，需要回复才填';

  @override
  String feedbackAttachNote(String meta) {
    return '将随反馈一并发送：$meta';
  }

  @override
  String get feedbackSent => '已发送，感谢反馈！';

  @override
  String get feedbackFailed => '发送失败，请检查网络后重试。';

  @override
  String feedbackRefused(String reason) {
    return '中转服务拒绝了这条反馈:$reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return '反馈服务自身出了故障($reason)。你的网络没问题,请稍后再试。';
  }

  @override
  String get feedbackAttachLog => '附加调试日志';

  @override
  String get feedbackAttachLogHint => '最近的网络跟踪记录，可能包含账户名 / SteamID';

  @override
  String get feedbackLogConsentBody =>
      '调试日志是本次会话中最近的网络跟踪记录，可能包含你的账户名与 SteamID——绝不含密钥、令牌或密码。它只会随本条反馈一并发送，详见隐私政策。';

  @override
  String get feedbackLogConsentAgree => '同意';

  @override
  String get backupReminderTitle => '记得备份';

  @override
  String get backupReminderBody =>
      'GooeSteamKit 的令牌数据只保存在本机。请将 maFile 备份到安全的地方。撤销码（R 码）仅在你首次添加令牌时显示一次——请当场抄下并妥善保管；设备丢失时，它是移除令牌的最后手段。';

  @override
  String get backupReminderOk => '知道了';

  @override
  String get debugCopyAll => '全部复制';

  @override
  String get debugCopied => '日志已复制';

  @override
  String get debugEmpty => '暂无日志。';

  @override
  String get commonOpen => '打开';

  @override
  String get commonClear => '清空';

  @override
  String addErrFinalize(String detail) {
    return '完成失败：$detail';
  }

  @override
  String get loginTitle => '登录 Steam';

  @override
  String get loginUsername => '用户名';

  @override
  String get loginPassword => '密码';

  @override
  String get loginShowPassword => '显示密码';

  @override
  String get loginHidePassword => '隐藏密码';

  @override
  String get loginSavePassword => '保存密码';

  @override
  String get loginSavePasswordHint =>
      '存在该账户的 maFile 中用于自动刷新登录；导出的未加密 maFile 会包含它。';

  @override
  String get loginButton => '登录';

  @override
  String get loginErrInvalidPassword => '账户名或密码错误。';

  @override
  String get loginErrRateLimited => '尝试太频繁，请稍候片刻再试。';

  @override
  String get loginErrCodeMismatch => '验证码不正确，请检查后重试。';

  @override
  String get loginViaQr => '扫码登录';

  @override
  String get loginViaCredentials => '密码登录';

  @override
  String get loginScanWithApp => '用 Steam 手机 App 扫描此二维码';

  @override
  String get loginNeedGuardCode => '请输入 Steam 令牌验证码';

  @override
  String get loginNeedEmailCode => '请输入邮箱收到的验证码';

  @override
  String get loginSubmitCode => '提交';

  @override
  String get loginWaiting => '等待确认…';

  @override
  String get loginStepCredentials => '凭据';

  @override
  String get loginStepConfirm => '确认';

  @override
  String get loginStepDone => '完成';

  @override
  String get loginWaitingDesc => '请在 Steam 手机 App 上批准这次登录。也可改用邮箱验证码或扫码登录。';

  @override
  String loginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get approveTitle => '批准登录';

  @override
  String get approveScanPrompt => '扫描你想登录的设备上显示的二维码。';

  @override
  String get approvePastePrompt => '或在此粘贴二维码链接';

  @override
  String get approveButton => '批准';

  @override
  String get approveReject => '拒绝';

  @override
  String get approveSuccess => '登录已批准。';

  @override
  String get approveRejected => '登录已拒绝。';

  @override
  String get approveBadCode => '这不是 Steam 登录二维码。';

  @override
  String get approveLocation => '位置';

  @override
  String get approveDevice => '设备';

  @override
  String get approveWarnStranger => '不是你本人发起的登录？请拒绝。';

  @override
  String get importTitle => '导入账户';

  @override
  String get importPickFile => '选择 .maFile 文件';

  @override
  String get importSuccess => '账户已导入。';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get importDuplicateTitle => '账户已存在';

  @override
  String importDuplicateBody(String name) {
    return '该 maFile 对应的账户 $name 已在本设备上。要用导入的文件覆盖现有账户吗？文件中未包含的缓存头像、已存密码与现有会话会被保留。';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return '该 maFile 对应的账户 $name 已在本设备上，但其本地数据已无法读取。导入将完全替换它。';
  }

  @override
  String get importDuplicateOverwrite => '覆盖';

  @override
  String get importSessionDeadTitle => '激活该账户的会话？';

  @override
  String get importSessionDeadBody =>
      '该 maFile 中的 Steam 会话已失效。现在登录即可使用交易确认与登录批准——令牌验证码会自动填写。';

  @override
  String get importSessionLater => '稍后';

  @override
  String get sdaImportAction => '导入 SDA 文件夹';

  @override
  String get sdaImportHint =>
      '选择多个 .maFile 文件批量导入。未加密文件不需要 manifest.json；SDA 加密文件需同时选中 manifest.json，其中包含解密参数。';

  @override
  String get sdaImportNoManifest => '所选文件里没有 manifest.json。请把它和 .maFile 一起选中。';

  @override
  String sdaImportBadManifest(String error) {
    return '这个 manifest.json 读不了：$error';
  }

  @override
  String get sdaImportPassTitle => 'SDA 加密口令';

  @override
  String get sdaImportPassBody =>
      '这些 maFile 是加密的。请输入你当初在 Steam Desktop Authenticator 里设置的口令。';

  @override
  String get sdaImportWrongPass => '这个口令解不开任何一个文件。';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个账户。',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '跳过了 $count 个账户：$names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => '没有导入任何账户。';

  @override
  String updateAvailable(String version) {
    return '新版本 $version 已发布';
  }

  @override
  String get updateView => '查看';

  @override
  String get updateDismiss => '跳过';

  @override
  String get settingsUpdateCheck => '启动时检查更新';

  @override
  String get settingsUpdateCheckDesc => '每次启动向版本端点查询一次。不带账户数据，端点不留日志。';

  @override
  String get importSessionLoginNow => '立即登录';

  @override
  String get actionExport => '导出 maFile';

  @override
  String get actionLoginRequests => '登录请求';

  @override
  String get loginRequestTitle => '批准登录？';

  @override
  String loginRequestBody(String device, String location) {
    return '$device 正在从 $location 登录你的 Steam 账户。';
  }

  @override
  String get loginRequestApprove => '允许';

  @override
  String get loginRequestDeny => '拒绝';

  @override
  String get loginNoPending => '没有待批准的登录请求。';

  @override
  String get loginNeedSession => '请先登录刷新该账户的会话。';

  @override
  String get loginApproved => '已允许登录。';

  @override
  String get loginDenied => '已拒绝登录。';

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get exportWarnTitle => '导出未加密的 maFile？';

  @override
  String get exportWarnBody =>
      '导出的 .maFile 是未加密的。它包含该账户的 Steam 令牌密钥与撤销码——任何拿到文件的人都能接管你的验证器。请妥善保存，用完及时删除。';

  @override
  String get exportIncludePassword => '同时导出已保存的 Steam 密码（不建议）';

  @override
  String get addAuthTitle => '添加验证器';

  @override
  String get addAuthPhonePrompt => '请输入手机号（含国家区号）';

  @override
  String get addAuthSmsPrompt => '请输入手机收到的短信验证码';

  @override
  String get addAuthEmailPrompt => '请输入 Steam 发到邮箱的激活码';

  @override
  String addAuthRevocationWarn(String code) {
    return '请记下你的撤销码：$code';
  }

  @override
  String get addAuthConfirmRevocation => '请再次输入撤销码以确认你已保存';

  @override
  String get addAuthLinked => '验证器绑定成功。';

  @override
  String get addAuthStepPhone => '手机';

  @override
  String get addAuthStepSms => '激活';

  @override
  String get addAuthStepRevocation => '撤销码';

  @override
  String get addPresentTitle => '该账户已有验证器';

  @override
  String get addPresentIntro => 'Steam 同一账户只允许一个手机验证器。请先移除现有验证器，再点「重试」。';

  @override
  String get addPresentStep1 => '仍有旧手机或 Steam App？打开它 → Steam 令牌 → 移除验证器。';

  @override
  String get addPresentStep2 => '有撤销代码（Rxxxxx）？打开下方页面，选择「移除验证器」。';

  @override
  String get addPresentStep3 => '两者都无法访问？通过 Steam 客服 → 帮助 → Steam 令牌手机验证器。';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => '链接已复制';

  @override
  String get addPresentFallbackTitle => '收不到邮件？';

  @override
  String get addMoveInButton => '把验证器移到本设备';

  @override
  String get addMoveInBlurb => 'Steam 会向该账户邮箱发送验证码，无需 15 天交易冷却。';

  @override
  String get addMoveInSending => '正在发送验证码…';

  @override
  String get addMoveInCodePrompt => '请输入 Steam 发到你邮箱的验证码';

  @override
  String get addMoveInWarn =>
      '确认后：旧手机上的验证器会立即失效，旧的撤销代码（Rxxxxx）作废并换发新的。此操作不可撤销。';

  @override
  String get addMoveInConfirm => '移到本设备';

  @override
  String get addMoveInDone => '验证器已移到本设备。';

  @override
  String get addMoveInPopBlocked => '正在迁移令牌，请稍候。';

  @override
  String get addErrBadChallengeCode => '验证码不正确，请核对邮件后重试。';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return '验证器已迁移成功，但 GooeSteamKit 未能把它保存到本设备。旧验证器已失效，以下是仅有的副本——关闭本页前请立即抄写。\n\n撤销代码：$code\n\n密钥：$secret';
  }

  @override
  String get addMoveInCopySecrets => '复制';

  @override
  String get addMoveInCopied => '已复制';

  @override
  String get moveInRescueDismiss => '我已保存——关闭';

  @override
  String get moveInRescueDismissTitle => '丢弃这些密钥？';

  @override
  String get moveInRescueDismissBody =>
      'GooeSteamKit 没有其他副本。若尚未抄下撤销代码与密钥，你将永久失去这个验证器。';

  @override
  String get moveInRescueDismissConfirm => '我已保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonCopy => '复制链接';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonExport => '导出';

  @override
  String get commonDelete => '删除';

  @override
  String get settingsEncryption => '加密';

  @override
  String get settingsEncryptionDesc =>
      '本机 maFiles 由存于设备 Keystore 的随机 256 位密钥加密（AES-256-GCM），6 位 PIN 用于解锁。';

  @override
  String get settingsThemeDesc => '切换整体界面风格。';

  @override
  String get settingsAppearance => '明暗';

  @override
  String get settingsAppearanceDesc => '标准外观的亮暗模式；启用皮肤时以皮肤为准。';

  @override
  String get settingsTextSize => '字号';

  @override
  String get settingsTextSizeDesc => '在系统字体大小基础上叠加。';

  @override
  String get textSizeSmall => '小';

  @override
  String get textSizeMedium => '中';

  @override
  String get textSizeLarge => '大';

  @override
  String get settingsSkin => '皮肤';

  @override
  String get settingsSkinDesc => '带专属字体与特效的完整风格外观。';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get skinNone => '无';

  @override
  String get settingsChange => '修改';

  @override
  String get settingsSetPasskey => '设置 / 修改加密口令';

  @override
  String get settingsAutoConfirmMarket => '自动确认市场交易';

  @override
  String get settingsAutoConfirmMarketDesc =>
      '上架物品时预先勾选确认框,让新上架在创建后立即被确认。它不会在后台确认任何东西。';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeNeon => '霓虹';

  @override
  String get themePixel => '像素';

  @override
  String get themeDark => '暗色';

  @override
  String get themeLight => '亮色';

  @override
  String get settingsAbout => '关于';

  @override
  String get aboutTagline => '开源的 Steam 令牌验证器，用 Flutter 打造。';

  @override
  String get aboutSourceCode => '源代码';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutLicense => '许可证';

  @override
  String get aboutPrivacy => '隐私政策';

  @override
  String get privacyConsentTitle => '你的隐私';

  @override
  String get privacyConsentBody =>
      'AVA 把你的 Steam 账户与密钥保存在本设备上——绝不上传;除非你启用可选的同步功能并指定自己的服务器,而那也是先在本机加密后才离开设备。无需注册任何账户。Steam 请求直连 Valve。开发者自己的两个服务只在需要时才被连接:Pro 权益校验,以及反馈(仅当你按下发送)。Play 版免费档还会显示广告。没有任何跟踪或统计。这一切都写在隐私政策里——继续即表示你接受它。';

  @override
  String get privacyUpdateTitle => '隐私政策已更新';

  @override
  String get privacyUpdateBody =>
      '隐私说明在你同意之后有了变更。新增:GooeSteamKit 现在可以通过你自己指定的服务器,在多台设备间同步账户库——默认关闭,所有数据先在本机加密再上传,开发者不运营任何同步服务器。请阅读下方最新的说明。';

  @override
  String get privacyConsentScrollHint => '请滑到底部后继续';

  @override
  String get privacyConsentRead => '阅读完整隐私政策';

  @override
  String get privacyConsentAgree => '同意并继续';

  @override
  String get privacyConsentExit => '退出';

  @override
  String get actionMarket => '库存 / 市场';

  @override
  String get marketTabInventory => '库存';

  @override
  String get marketTabListings => '我的出售';

  @override
  String get marketSelectGame => '选择游戏';

  @override
  String get marketNoItems => '该库存没有物品。';

  @override
  String get marketNotMarketable => '不可上架';

  @override
  String get marketSellTitle => '上架出售';

  @override
  String get marketYouReceive => '你到手';

  @override
  String get marketBuyerPays => '买家支付';

  @override
  String get marketLowest => '最低在售';

  @override
  String get marketMedian => '中位成交';

  @override
  String get marketHigh => '最高';

  @override
  String get marketLow => '最低';

  @override
  String get marketPriceUnavailable => '市场价暂不可用';

  @override
  String get marketListButton => '确认上架';

  @override
  String get marketListed => '已上架，去确认完成。';

  @override
  String get marketListedDone => '已上架并确认。';

  @override
  String marketListedPartial(int listed, int total) {
    return '已上架 $listed/$total 件（其余失败）——如有待确认项请在确认页完成。';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '已上架 $listed/$total 件后会话过期——请重新登录并完成确认。';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return '已上架——已确认 $ok/$total，其余请在确认页完成。';
  }

  @override
  String get marketAutoConfirm => '上架后自动确认';

  @override
  String get marketQuantity => '数量';

  @override
  String get marketMax => '最大';

  @override
  String marketListFailed(String error) {
    return '上架失败：$error';
  }

  @override
  String get marketInvalidPrice => '请输入有效价格。';

  @override
  String get marketCancel => '撤销在售';

  @override
  String get marketCancelled => '已撤销在售。';

  @override
  String get marketNoListings => '暂无在售。';

  @override
  String get marketFeeNote => 'Steam + 游戏手续费会在你到手价基础上叠加给买家。';

  @override
  String get aboutLicenses => '开源许可证';

  @override
  String get aboutCredits => '致谢';

  @override
  String get aboutCreditsBody =>
      '灵感来自 Steam Desktop Authenticator，兼容其 maFile 格式。基于 Flutter、Riverpod、Dio、PointyCastle、mobile_scanner、image 等开源库独立构建。';

  @override
  String get actionLogin => '登录 / 刷新会话';

  @override
  String get actionConfirmations => '待办';

  @override
  String get actionRemove => '移除账户';

  @override
  String get actionImport => '导入';

  @override
  String get actionAddAuthenticator => '添加验证器';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '确定';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonClose => '关闭';

  @override
  String get commonError => '错误';

  @override
  String get sessionExpired => '你的 Steam 会话已过期，请重新登录。';

  @override
  String get removeConfirm => '从本设备移除该账户？请确保已备份 maFile。';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => '查看 AVA Pro';

  @override
  String get proStatusFree => '免费版';

  @override
  String proStatusPro(Object date) {
    return 'Pro · 有效至 $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · 有效至 $date';
  }

  @override
  String get proStatusLifetime => 'Pro · 终身';

  @override
  String proStatusActivations(Object classes) {
    return '已激活：$classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name（本机）';
  }

  @override
  String get proDeviceClassAndroid => 'Android';

  @override
  String get proDeviceClassWindows => 'Windows';

  @override
  String get proDeviceClassLinux => 'Linux';

  @override
  String get proDeviceClassMacos => 'macOS';

  @override
  String get paywallTitle => 'AVA Pro';

  @override
  String get paywallPerksTitle => 'Pro 权益——核心安全功能永久免费。';

  @override
  String get paywallPerkSkins => '主题包：Neon 与 Pixel 皮肤';

  @override
  String get paywallPerkNoAds => '去横幅广告';

  @override
  String get paywallPerkFuture => '后续：云同步、交易通知';

  @override
  String get paywallPlayTitle => '通过 Google Play 解锁';

  @override
  String get paywallSubscribe => '订阅 · \$0.99/月';

  @override
  String get paywallWatchAd => '看广告 · 得 3 天 VIP';

  @override
  String get paywallRestore => '恢复购买';

  @override
  String get paywallCnTitle => '通过爱发电解锁';

  @override
  String get paywallAfdianIntro => '在爱发电以 ¥5/月赞助，然后在此输入订单号解锁。';

  @override
  String get paywallOpenAfdian => '打开爱发电';

  @override
  String get paywallOrderHint => '爱发电订单号';

  @override
  String get paywallRedeem => '解锁';

  @override
  String get paywallBetaTitle => '内测回礼';

  @override
  String get paywallBetaIntro => '内测用户享终身 Pro——输入你的兑换码。';

  @override
  String get paywallBetaHint => '终身兑换码';

  @override
  String get paywallBetaRedeem => '兑换';

  @override
  String get proResultSuccess => '已解锁，感谢支持！';

  @override
  String get proErrCanceled => '已取消。';

  @override
  String get proErrNetwork => '网络错误，稍后再试。';

  @override
  String get proErrNotConfigured => '当前构建尚未开通此功能。';

  @override
  String get proErrNoSubscription =>
      'Play 商店当前账户名下没有有效订阅。如果是用另一个 Google 账户订的：在 Play 商店里（右上角头像）切换到那个账户，再回来重试。';

  @override
  String get proErrAlreadyOwned => 'Play 商店当前账户已持有该订阅——点「恢复购买」即可。';

  @override
  String get proErrOrderBound => '该订单已被其他用户绑定。';

  @override
  String get proErrOrderNotFound => '订单不存在或方案不符。';

  @override
  String get proErrDeviceRevoked => '本设备名额已被新设备占用。';

  @override
  String get proErrNoVip => '奖励尚未到账，请稍后重试。';

  @override
  String get proErrPurchaseBound =>
      '该订阅绑定在另一个 Google 账户上。请重试，并在账户选择器里选 Play 商店正在用的那个账户。';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return '该订阅绑定在 $account。请重试，并在选择器里选这个账户。';
  }

  @override
  String proErrGeneric(Object code) {
    return '失败：$code';
  }

  @override
  String get proErrCodeInvalid => '激活码无效，请检查是否输错。';

  @override
  String get proErrCodeRedeemed =>
      '该激活码已在另一台设备上激活。如需换机使用，请发邮件至 hi@dotslash.pro。';

  @override
  String get proErrCodeActivationLimit =>
      '该激活码近期更换设备过于频繁，请稍后再试，或联系 hi@dotslash.pro。';

  @override
  String get proErrRateLimited => '尝试次数过多，请稍等一分钟再试。';

  @override
  String proErrSlotOccupied(Object slots) {
    return '占用中：$slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name（$time）';
  }

  @override
  String get proSlotToday => '今天';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 天前',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked => '该权益已不再有效。如有疑问，请联系 hi@dotslash.pro。';

  @override
  String get privacyOptions => '隐私选项';

  @override
  String get skinProNotice => 'Neon 与 Pixel 皮肤现为 Pro 权益；你的选择已保留，解锁 Pro 即恢复。';

  @override
  String get skinProNoticeDismiss => '知道了';

  @override
  String get syncTitle => '同步';

  @override
  String get syncSetupTitle => '设置同步';

  @override
  String get syncSettingsDesc => '通过你自己掌控的服务器在多台设备间同步账户。所有数据离开本机前都已加密。';

  @override
  String get syncSetUp => '设置同步…';

  @override
  String get syncStatusOk => '已是最新';

  @override
  String get syncStatusSyncing => '正在同步…';

  @override
  String get syncStatusErrorShort => '上次同步失败——打开查看详情。';

  @override
  String syncStatusConflicts(int count) {
    return '$count 个冲突等待你决定';
  }

  @override
  String syncLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get syncNever => '从未';

  @override
  String get syncBackendTitle => '数据放在哪里？';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc => 'Nextcloud、坚果云、NAS——任何一个你掌控的 WebDAV 文件夹。';

  @override
  String get syncBackendGdrive => 'Google Drive';

  @override
  String get syncBackendGdriveSoon => 'Pro · 稍后推出';

  @override
  String get syncServerTitle => '服务器';

  @override
  String get syncServerHint =>
      '坚果云需要「应用密码」（安全选项 → 添加应用密码），不是登录密码。Nextcloud 的文件夹 URL 形如 https://cloud.example.com/remote.php/dav/files/用户名/ava/。';

  @override
  String get syncServerUrlLabel => 'WebDAV 文件夹 URL';

  @override
  String get syncServerFolderLabel => '文件夹（可选）';

  @override
  String get syncServerFolderHint => '留空则直接使用上面的 URL；填写则放入该子文件夹，不存在会自动创建。';

  @override
  String get syncServerUserLabel => '用户名';

  @override
  String get syncServerPasswordLabel => '密码 / 应用密码';

  @override
  String get syncTestConnection => '测试连接';

  @override
  String get syncErrUrl => '请输入有效的 http(s) 文件夹 URL。';

  @override
  String get syncErrAuth => '服务器拒绝了用户名或密码。';

  @override
  String syncErrNetwork(String detail) {
    return '无法连接服务器：$detail';
  }

  @override
  String syncErrServer(String detail) {
    return '服务器返回错误：$detail';
  }

  @override
  String get syncErrTls => '服务器证书不受信任。';

  @override
  String get syncTlsTitle => '未知的服务器证书';

  @override
  String syncTlsBody(String fp) {
    return '系统不信任该服务器的证书。如果这是你自己的服务器（自签名证书），请把下面的指纹与服务器上显示的逐字比对，完全一致才信任。\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => '信任该证书';

  @override
  String get syncHttpPrivateTitle => '未加密连接';

  @override
  String get syncHttpPrivateBody =>
      '这是内网的明文 HTTP 地址。账户数据本身是端到端加密的，但服务器密码会在你的局域网内明文传输。';

  @override
  String get syncHttpPublicTitle => '公网明文 HTTP';

  @override
  String get syncHttpPublicBody =>
      '该地址位于公网且连接不加密：你与服务器之间的任何中间节点都能读到服务器密码并登录你的服务器。账户数据本身仍是加密的。强烈建议改用 HTTPS 或内网地址——确认风险自担才继续。';

  @override
  String get syncHttpPublicHold => '长按仍然允许';

  @override
  String get syncContinue => '继续';

  @override
  String get syncPassphraseNewTitle => '设置同步口令';

  @override
  String get syncPassphraseNewBody =>
      '所有数据上传前都会用这个口令加密；口令本身绝不离开你的设备。\n\n口令一旦丢失，同步数据任何人都无法找回——没有重置这回事。至少 8 个字符；长度比符号更重要。';

  @override
  String get syncPassphraseExistingTitle => '输入同步口令';

  @override
  String syncPassphraseExistingBody(int count) {
    return '这个文件夹里已有一个包含 $count 个账户的同步库。请输入创建它时设置的口令。';
  }

  @override
  String get syncPassphraseLabel => '同步口令';

  @override
  String get syncPassphraseConfirmLabel => '确认口令';

  @override
  String get syncPassphraseTooShort => '至少 8 个字符。';

  @override
  String get syncPassphraseMismatch => '两次输入的口令不一致。';

  @override
  String get syncPassphraseWrong => '这个口令打不开该同步库。';

  @override
  String get syncPreviewTitle => '首次同步';

  @override
  String get syncPreviewEmpty => '暂时没有要传输的内容——之后的账户变动会自动同步。';

  @override
  String syncPreviewPull(int count) {
    return '下载到本机：$count 个账户';
  }

  @override
  String syncPreviewPush(int count) {
    return '从本机上传：$count 个账户';
  }

  @override
  String syncPreviewConflict(int count) {
    return '两侧内容不同：$count 个——连接后逐个选择';
  }

  @override
  String get syncStart => '开始同步';

  @override
  String get syncDoneTitle => '同步已开启';

  @override
  String get syncDoneBody =>
      '账户现在会自动同步。新设备上每个账户首次使用时会重新登录——存过密码的自动完成，其余的会提示输一次。';

  @override
  String get syncDone => '完成';

  @override
  String get syncNeedsPassphrase => '存储的口令与远端同步库不再匹配——请重新输入。';

  @override
  String get syncEnterPassphrase => '输入口令';

  @override
  String get syncConditionalWarn =>
      '该服务器忽略条件写入，两台设备同时同步可能互相覆盖。同步仍可用；避免在两台设备上同时改动。';

  @override
  String get syncConflictsTitle => '冲突';

  @override
  String get syncConflictTrashNote => '被舍弃的一侧会在同步回收站保留 30 天。';

  @override
  String get syncConflictEditEdit => '两台设备都改过';

  @override
  String get syncConflictEditDelete => '本机改过，另一台设备已删除';

  @override
  String get syncConflictDeleteEdit => '本机已删除，另一台设备改过';

  @override
  String get syncConflictKeepLocal => '保留本机版本';

  @override
  String get syncConflictKeepRemote => '保留对方版本';

  @override
  String get syncConflictLocalSide => '本机';

  @override
  String get syncConflictRemoteSide => '另一台设备';

  @override
  String get syncDeleted => '已删除';

  @override
  String get syncConflictHasPassword => '已存密码';

  @override
  String get syncConflictNoPassword => '未存密码';

  @override
  String get syncAutoTitle => '自动同步';

  @override
  String get syncAutoDesc => '启动时和每次改动后同步。关闭后只有下面的按钮会同步。';

  @override
  String get syncPasswordsTitle => '同步账户密码';

  @override
  String get syncPasswordsDesc => '有密码，新设备才能自行登录。改动此项会重新上传全部账户。';

  @override
  String get syncAppSettingsTitle => '同步应用设置';

  @override
  String get syncAppSettingsDesc =>
      '同步外观与行为偏好，以及加密保存的 Steam 加速订阅、节点和所选节点。语言、字号和加速自动启动开关保持各设备独立。';

  @override
  String get syncNowButton => '立即同步';

  @override
  String get syncViewRemote => '查看远端同步库';

  @override
  String get syncRemoteEmpty => '远端同步库是空的。';

  @override
  String get syncRemoteDevices => '设备';

  @override
  String get syncTrashTitle => '同步回收站';

  @override
  String get syncTrashEmpty => '空的。被同步删除或替换的账户会在这里保留 30 天。';

  @override
  String get syncTrashRestore => '恢复';

  @override
  String get syncTrashRestored => '账户已恢复。';

  @override
  String get syncTrashRestoreFailed => '当前口令解不开这条记录。';

  @override
  String get syncTrashReasonRemoteDelete => '被另一台设备删除';

  @override
  String get syncTrashReasonConflict => '在冲突中被替换';

  @override
  String get syncChangePassphrase => '更改同步口令';

  @override
  String get syncPassphraseChanged => '口令已更改，数据已全部重新加密。其他设备会要求输入新口令。';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return '口令未更改：$reason';
  }

  @override
  String get syncDisconnect => '断开同步';

  @override
  String get syncDisconnectBody => '本机停止同步。远端同步库可以留给其他设备继续用——也可以从服务器上彻底删除。';

  @override
  String get syncDisconnectKeep => '保留远端数据';

  @override
  String get syncDisconnectDeleteHold => '长按删除远端数据';

  @override
  String get netErrTls =>
      '无法与 Steam 建立安全连接。连接在 TLS 握手阶段被切断，通常是网络对它做了拦截，或者网络本身不稳定。换一个网络（或使用代理）后重试。';

  @override
  String get netErrUnreachable => '连不上 Steam。检查网络连接后重试。';

  @override
  String get netErrTimeout => 'Steam 没有在规定时间内响应。网络可能很慢，或者被拦截了。';

  @override
  String get netErrCert =>
      'Steam 的证书未通过验证，GooeSteamKit 已中断这次连接。当前网络里可能有东西在监听流量。';

  @override
  String netErrServer(int code) {
    return 'Steam 返回了一个错误（$code）。这通常是暂时的，稍后再试。';
  }

  @override
  String exportSaved(String path) {
    return '已保存到 $path';
  }

  @override
  String get accountSearchHint => '搜索账号';

  @override
  String get accountSearchEmpty => '没有匹配的账号';

  @override
  String get accountSearchClear => '清除搜索';

  @override
  String get portableMode => '便携模式';

  @override
  String get portableEnable => '开启便携模式';

  @override
  String get portableDisable => '关闭便携模式';

  @override
  String get portableOnHelp => '新账号保存到程序旁的 maFiles。同时读取两个库，同号优先使用便携库。';

  @override
  String get portableOffHelp => '新账号保存到 AppData。同时读取两个已解锁的库，同号优先使用本机库。';

  @override
  String get portableCopyToUsb => '是否同时把现有本机账号复制到程序旁的 maFiles？';

  @override
  String get portableCopyToLocal => '是否同时把便携账号复制回 AppData？';

  @override
  String get portableCopyHelp =>
      '复制后会校验，原库保留作备份。目标库已有的账号会跳过，不覆盖。便携账号不参与本机的 WebDAV 同步。';

  @override
  String get portableNoCopy => '仅切换';

  @override
  String get portableCopy => '复制并切换';

  @override
  String get portableSetPassword => '设置便携密码';

  @override
  String get portableUnlock => '解锁 maFiles';

  @override
  String get portablePasswordHelp => '请使用至少 12 个字符的独立密码并妥善保管。换电脑仍需此密码，无法重置。';

  @override
  String get portableUnlockHelp => '请输入这个账号库的密码。若是 SDA 加密文件夹，请使用原 SDA 密码。';

  @override
  String get portableConfirmPassword => '确认密码';

  @override
  String get portablePasswordMismatch => '两次密码不一致。';

  @override
  String get portableWrongPassword => '密码错误，或此账号库无法解锁。';

  @override
  String get portableFailed => '操作未完成，原账号库已保留。';

  @override
  String get portableDone => '模式已更新，原账号已保留。';

  @override
  String get portableSkipped => '跳过已有账号';

  @override
  String get portableUnreadable =>
      '账号库损坏，或仍依赖原 Windows 的密钥。请从导出的 maFile 恢复，源文件未改动。';

  @override
  String get friendsTitle => '好友与交易';

  @override
  String get friendsSearch => '搜索昵称或 SteamID';

  @override
  String get friendsEmpty => '没有可显示的好友';

  @override
  String get friendsProfile => '查看 Steam 资料';

  @override
  String get friendsTrade => '发起交易';

  @override
  String get friendsOnline => '在线';

  @override
  String get friendsOffline => '离线';

  @override
  String get friendsPlaying => '游戏中';

  @override
  String get tradeNewTitle => '新交易报价';

  @override
  String get tradeYourItems => '我送出的物品';

  @override
  String get tradeTheirItems => '我收到的物品';

  @override
  String get tradeSelectItems => '选择物品';

  @override
  String get tradeNote => '附言（可选）';

  @override
  String get tradeReview => '检查报价';

  @override
  String get tradeSend => '确认发送';

  @override
  String get tradeReviewBody => '请核对对方 SteamID、双方物品和数量。Steam 可能要求进一步确认或暂挂。';

  @override
  String get tradeGiftWarning => '此报价只送出物品，你不会收到任何物品。';

  @override
  String get tradeNoItems => '当前没有可选的可交易物品。';

  @override
  String get tradeMore => '加载更多';

  @override
  String get tradeSent => '报价已发送。';

  @override
  String get tradeNeedsMobile => '报价已创建，请到待办中完成手机令牌确认。';

  @override
  String get tradeNeedsEmail => '报价已创建，请按 Steam 邮件完成确认。';

  @override
  String get tradeOpenPending => '查看待办与报价';

  @override
  String get tradeUnknownResult => '未能确认发送结果。请先查看已发出的报价，确认未发送后再重试，避免重复报价。';

  @override
  String get tradeChooseGame => '选择库存';

  @override
  String get tradeQuantity => '数量';

  @override
  String get tradeLoadFailed => '无法读取 Steam 好友或库存，请刷新重试。';

  @override
  String get tradeSendFailed => 'Steam 未确认发送成功，请查看报价记录后再试。';

  @override
  String get marketListingActive => '在售';

  @override
  String get marketListingOnHold => '暂挂中';

  @override
  String get marketListingPending => '等待确认';

  @override
  String get marketListingInactive => '未在售';

  @override
  String marketHoldUntil(String date) {
    return '暂挂至 $date';
  }

  @override
  String get marketListingsAll => '全部';

  @override
  String get marketCancelConfirm => '确定取消这件物品的市场上架？';

  @override
  String get settingsStartupVerification => '启动时验证身份';

  @override
  String get settingsStartupVerificationDesc =>
      '开启时需输入 GooeSteamKit PIN 或使用系统验证。关闭后，任何能使用此设备的人都可打开 GooeSteamKit；账户文件仍加密保存在本机。';

  @override
  String get settingsStartupVerificationError => '无法保存启动验证设置，请检查系统安全存储后重试。';

  @override
  String get settingsLockNow => '立即锁定';

  @override
  String get settingsStartupVerificationPinChanged => '更改 PIN 后会重新开启启动验证。';

  @override
  String get settingsStartupVerificationDisable => '关闭启动验证？';

  @override
  String get dashboardTitle => '账户概览';

  @override
  String get dashboardWallet => '钱包余额';

  @override
  String get dashboardPendingBalance => '待到账余额';

  @override
  String get dashboardUnavailable => '暂未获取';

  @override
  String get dashboardMarket => '库存与市场';

  @override
  String get dashboardTools => '账户工具';

  @override
  String get dashboardCustomize => '选择概览卡片';

  @override
  String get dashboardViewAll => '查看全部';

  @override
  String get dashboardNoListings => '目前没有出售记录。';

  @override
  String get dashboardFetchFailed => '暂时无法读取，请刷新重试。';

  @override
  String get dashboardSaveFailed => '无法保存显示偏好。';

  @override
  String get backupCodesTitle => '备用登录码';

  @override
  String get backupCodesAccountCheck =>
      '浏览器可能登录着另一个 Steam 账号。生成备用码前，请核对网页中的账号是否与上方一致。';

  @override
  String get backupCodesHow => '通过 Steam 获取备用码';

  @override
  String get backupCodesSteps =>
      '1. 点击下方按钮，打开 Steam 令牌管理页。\n2. 登录上方显示的目标账号。\n3. 选择“获取备用 Steam 令牌验证码”。\n4. 按 Steam 提示完成验证，并妥善保存生成的备用码。';

  @override
  String get backupCodesExplanation =>
      '这是一次性备用登录码，与移除令牌的恢复码不同。备用码由 Steam 签发和管理；GooeSteamKit 提供官方流程入口，不在本地生成或保存这些码。';

  @override
  String get backupCodesOpenSteam => '前往 Steam 获取备用码';

  @override
  String get backupCodesCopyLink => '复制官方链接';

  @override
  String get backupCodesOpenFailed => '未能打开浏览器，请复制链接后手动打开。';

  @override
  String get loginAccountMismatch => '登录的是其他 Steam 账号。请使用当前账户完成验证，原账户未被修改。';

  @override
  String get tradeFromAccount => '发起账户';

  @override
  String get tradeToAccount => '交易对象';

  @override
  String get tradeValidationFailed => '报价尚未发送。请检查所选物品和数量；每方最多选择 256 项。';

  @override
  String get friendsProfileOpenFailed => '无法打开浏览器，可复制下方 Steam 官方链接。';

  @override
  String get steamSwitchQrTitle => '用 GooeSteamKit 账号扫码登录';

  @override
  String get steamSwitchQrHelp =>
      '选择 GooeSteamKit 账号，在 Steam 显示登录二维码，再扫码并确认登录请求。';

  @override
  String get steamSwitchQrAccount => 'GooeSteamKit 账号';

  @override
  String get steamSwitchQrNeedsSession =>
      '请先在 GooeSteamKit 中重新登录此账号。仅有离线令牌码无法批准二维码登录。';

  @override
  String get steamSwitchQrNoAccounts => '请先向 GooeSteamKit 添加账号，再使用扫码登录。';

  @override
  String get approveScreenSelect => '拖框扫描屏幕二维码';

  @override
  String get approveScreenHelp =>
      '点击后 GooeSteamKit 会暂时隐藏。拖动框选 Steam 登录二维码，再核对账号与登录设备并确认。';

  @override
  String get approveScreenInstruction => '拖动框选一个 Steam 登录二维码 · Esc / 右键取消';

  @override
  String get approveScreenNoCode => '未识别到二维码。请框选完整二维码，保留少许周围空白后重试。';

  @override
  String get approveScreenFailed => '无法截取屏幕，请重试或粘贴二维码链接。';

  @override
  String get approveSessionUnavailable => '此二维码已过期或无法核实登录信息，请在 Steam 刷新二维码后重试。';

  @override
  String get itemMarketActions => '物品市场选项';

  @override
  String get itemMarketViewPrice => '查看市场价格';

  @override
  String get itemMarketOpen => '在 Steam 市场查看';

  @override
  String get itemMarketVolume => '近期成交量';

  @override
  String get itemMarketReferenceNote => 'Steam 市场单件参考价，非卖出实收；价格会变动。';

  @override
  String itemMarketCurrency(String currency) {
    return '币种：$currency';
  }

  @override
  String get itemMarketNoIdentity => '此物品没有可用于查价的市场名称。';

  @override
  String get itemMarketOpenFailed => '无法打开 Steam 市场页面。';

  @override
  String get steamClientRunning => 'Steam 已启动';

  @override
  String get steamClientStopped => 'Steam 未启动';

  @override
  String get steamClientStatusLoading => '正在读取 Steam 状态…';

  @override
  String get steamClientStatusUnavailable => '暂时无法读取 Steam 状态';

  @override
  String steamClientCurrentAccount(String account) {
    return '当前登录：$account';
  }

  @override
  String get steamClientAccountUnknown => '当前登录账户尚未识别';

  @override
  String get steamClientCurrentBadge => '当前登录';

  @override
  String get forkLocalFeaturesTitle => '本地功能已开放';

  @override
  String get forkLocalFeaturesBody =>
      '此独立分支无需 Pro 验证即可使用全部本地功能。原作者的在线服务和订阅不包含在内。';

  @override
  String get forkPrivacyConsentBody =>
      '此 AVA 独立分支将 Steam 账户与验证器密钥保存在本设备上，Steam 请求直连 Valve。可选同步只有在你配置自己的服务器后才启用，账户数据在本机加密后再同步。本地功能无需 Pro 验证；此构建不使用广告、支付服务或原版更新检查。反馈只打开本分支的 GitHub Issues，不会自动发送报告或日志。没有跟踪或统计。请阅读下方本分支的隐私说明，继续即表示接受。';

  @override
  String get forkUpdateTitle => '软件更新';

  @override
  String forkUpdateCurrentVersion(String version) {
    return '当前版本 $version';
  }

  @override
  String get forkUpdateCheck => '检查更新';

  @override
  String get forkUpdateChecking => '正在检查更新…';

  @override
  String get forkUpdateNoRelease => '暂时没有可用的发布版本';

  @override
  String get forkUpdateUpToDate => '当前已是最新版本';

  @override
  String forkUpdateAvailable(String version) {
    return '发现新版本 $version';
  }

  @override
  String get forkUpdateReleaseNotes => '更新说明';

  @override
  String get forkUpdateNoNotes => '此版本没有附带更新说明';

  @override
  String get forkUpdateDownload => '下载更新';

  @override
  String forkUpdateDownloading(String progress) {
    return '正在下载 $progress';
  }

  @override
  String get forkUpdateCancelDownload => '取消下载';

  @override
  String get forkUpdateReady => '安装包已下载并通过校验';

  @override
  String get forkUpdateInstall => '安装更新';

  @override
  String get forkUpdateInstallTitle => '安装此更新？';

  @override
  String get forkUpdateInstallAndroid =>
      '将打开系统安装页面。若提示，请允许 GooeSteamKit 安装应用，然后按系统提示完成更新。';

  @override
  String get forkUpdateInstallWindows =>
      '确认后将启动安装程序并关闭 GooeSteamKit。请先完成当前操作，再按安装程序提示更新。';

  @override
  String get forkUpdateInstallConfirm => '继续安装';

  @override
  String get forkUpdateInstallStarted => '已打开系统安装程序，请按提示完成更新';

  @override
  String get forkUpdateCheckFailed => '检查更新失败，请稍后重试';

  @override
  String get forkUpdateDownloadFailed => '下载失败，请重试';

  @override
  String get forkUpdateHashFailed => '安装包校验失败，已阻止安装，请重新下载';

  @override
  String get forkUpdateInstallFailed => '无法启动安装程序，请重试';

  @override
  String get forkUpdateNoCompatibleAsset => '此版本没有适用于本设备的安装包';

  @override
  String get forkUpdateUnverifiable => '此安装包缺少可信校验信息，无法下载或安装';

  @override
  String get forkUpdateInvalidMetadata => '发布信息不完整或无效，请稍后重试';

  @override
  String get forkUpdateUnsupported => '此设备暂不支持应用内更新';

  @override
  String get forkUpdateCancelled => '下载已取消';

  @override
  String get forkUpdatePermissionRequired => '请先允许 GooeSteamKit 安装应用，再返回此页面安装';

  @override
  String get forkUpdateOpenPermissionSettings => '允许安装应用';

  @override
  String get forkUpdateWrongPackage => '安装包不属于此应用，已阻止安装';

  @override
  String get forkUpdateSignatureMismatch => '安装包签名与当前应用不一致，已阻止安装';

  @override
  String get backupCodesNativeIntro =>
      '在这里生成 Steam 一次性备用登录码。Steam 需要验证此账户绑定手机号收到的短信。生成新的一组可能替换原有备用码。';

  @override
  String get backupCodesSendSms => '发送验证短信';

  @override
  String get backupCodesSmsPrompt => '输入 Steam 短信中的验证码。';

  @override
  String get backupCodesSmsLabel => '短信验证码';

  @override
  String get backupCodesGenerate => '验证并生成备用码';

  @override
  String get backupCodesReady => '你的一次性备用登录码';

  @override
  String get backupCodesKeepSafe =>
      '每个备用码只能使用一次。请打印并妥善保存。GooeSteamKit 不会保存这些码；离开此页或切换应用后会清除显示。生成或使用备用码时，Steam 会发送邮件通知。';

  @override
  String get backupCodesClear => '清除备用码';

  @override
  String get backupCodesRequestFailed => 'Steam 未能完成请求。程序没有自动重试。请检查网络后手动重试。';

  @override
  String get backupCodesUnexpectedResponse =>
      'Steam 返回了未识别的响应，无法确认结果；程序没有重试请求。';

  @override
  String get backupCodesInvalidSms => 'Steam 未接受验证码，请核对短信后重试。';

  @override
  String get backupCodesRateLimited => 'Steam 限制了请求次数，请稍后再试。';

  @override
  String get backupCodesPhoneRequired => 'Steam 要求此账户已绑定并验证手机号。';

  @override
  String get backupCodesManualHelp => 'Steam 官方网页（备用方式）';

  @override
  String get steamAccelerationTitle => 'Steam 加速';

  @override
  String get steamAccelerationDesc =>
      '优先使用外部代理，外部关闭后接续内置加速。内置线路仅用于 GooeSteamKit 的 Steam 访问。';

  @override
  String get steamAccelerationOff => '未启用';

  @override
  String get steamAccelerationLoading => '正在同步订阅…';

  @override
  String get steamAccelerationStarting => '正在启动…';

  @override
  String get steamAccelerationRunning => '运行中';

  @override
  String get steamAccelerationPaused => '内置加速待命';

  @override
  String get steamAccelerationFailed => '加速不可用';

  @override
  String get steamAccelerationUnsupported => '目前仅支持 Windows 和 Android。';

  @override
  String get steamAccelerationConfigured => '订阅已保存在此设备';

  @override
  String get steamAccelerationUnconfigured => '尚未配置订阅';

  @override
  String get steamAccelerationConfigure => '添加订阅';

  @override
  String get steamAccelerationReplace => '更换订阅';

  @override
  String get steamAccelerationSubscription => '订阅地址';

  @override
  String get steamAccelerationSubscriptionHelp =>
      '链接可能包含私人凭据，会安全保存在设备上。开启“同步应用设置”后，订阅和节点也会通过同步口令加密同步。保存后点击“更新节点”加载节点。';

  @override
  String get steamAccelerationClear => '清除订阅';

  @override
  String get steamAccelerationClearConfirm =>
      '停止内置加速并删除已保存的订阅和节点？开启设置同步时，这项删除也会同步到其他设备。';

  @override
  String get steamAccelerationSync => '更新节点';

  @override
  String get steamAccelerationDownloadingCore => '正在下载加速组件…';

  @override
  String get steamAccelerationCoreDownload => '加速组件下载失败，已尝试镜像和官方源，请稍后重试。';

  @override
  String get steamAccelerationExternalActiveHelp =>
      '当前使用外部连接。开启自动切换后，外部关闭时会接上内置线路，无需手动切换。';

  @override
  String get steamAccelerationNodes => '节点';

  @override
  String get steamAccelerationNoNodes => '请同步订阅获取可用节点。';

  @override
  String get steamAccelerationNode => '使用节点';

  @override
  String get steamAccelerationStart => '开启自动切换';

  @override
  String get steamAccelerationStop => '暂停自动切换';

  @override
  String get steamAccelerationAuto => '启动时自动开启';

  @override
  String get steamAccelerationAutoDesc =>
      '优先使用外部代理或 VPN，关闭后恢复内置线路。手动暂停仅在本次运行期间生效。';

  @override
  String get steamAccelerationEnvironment => '外部代理检测';

  @override
  String get steamAccelerationExternalProxy => '检测到系统代理或 PAC';

  @override
  String get steamAccelerationExternalVpn => '检测到 VPN 或隧道';

  @override
  String get steamAccelerationNoExternal => '未检测到外部代理';

  @override
  String get steamAccelerationDetectionUnavailable =>
      '无法确认外部代理，内置线路暂不启动。请检查系统代理设置后重新检测。';

  @override
  String get steamAccelerationEnvironmentHelp =>
      '应用可见时自动检查本机连接设置，不修改系统代理或 VPN。';

  @override
  String steamAccelerationSkipped(int count) {
    return '已跳过 $count 个不支持的节点。';
  }

  @override
  String get steamAccelerationInvalidSubscription =>
      '请输入有效的 HTTP 或 HTTPS 订阅地址。';

  @override
  String get steamAccelerationNetworkError => '无法获取订阅，请检查网络后重试。';

  @override
  String get steamAccelerationUnsupportedSubscription =>
      '订阅中没有支持的节点，请使用兼容的 Clash 订阅。';

  @override
  String get steamAccelerationStorageError => '系统安全存储不可用，无法保存设置。';

  @override
  String get steamAccelerationCoreUnavailable => '缺少加速组件，请安装更新的应用包。';

  @override
  String get steamAccelerationCoreIntegrity => '加速组件校验失败，已阻止启动。';

  @override
  String get steamAccelerationStartFailed => '无法启动加速，请刷新环境检测后重试。';

  @override
  String get inventorySearch => '搜索物品';

  @override
  String get inventoryFilterType => '类型';

  @override
  String get inventoryFilterRarity => '品质';

  @override
  String get inventoryFilterOther => '其他／未分类';

  @override
  String get inventoryFilterNoMatches => '没有符合筛选条件的物品';

  @override
  String get inventoryFilterLoaded => '筛选当前已加载的物品；加载更多后会包含剩余物品。';

  @override
  String get steamConnectionTitle => '连接检查';

  @override
  String get steamConnectionNotChecked => '尚未检查连接';

  @override
  String get steamConnectionChecking => '正在检查连接…';

  @override
  String get steamConnectionAvailable => '连接可用';

  @override
  String get steamConnectionPartial => '部分 Steam 服务无法连接';

  @override
  String get steamConnectionUnavailable => '无法连接 Steam';

  @override
  String get steamConnectionCheck => '检查连接';

  @override
  String get steamConnectionApi => 'Steam 登录接口';

  @override
  String get steamConnectionCommunity => 'Steam 社区与市场';

  @override
  String get steamConnectionReachable => '可连接';

  @override
  String get steamConnectionFailed => '连接失败';

  @override
  String get steamConnectionInternal => '内置线路';

  @override
  String get steamConnectionExternal => '外部 HTTP 代理';

  @override
  String get steamConnectionSystem => '外部 VPN／隧道';

  @override
  String get steamConnectionDirect => '直接连接';

  @override
  String steamConnectionCheckedAt(String time) {
    return '上次检查：$time';
  }

  @override
  String get steamConnectionNoVpnIcon =>
      '仅代理 GooeSteamKit 内部的 Steam 请求，因此 Android 不显示系统 VPN 图标；Steam 客户端和其他应用不会被加速。';

  @override
  String get steamConnectionScope =>
      '通过 GooeSteamKit 当前线路检查 Steam 接口和社区，不发送账户凭据。结果仅代表本次检查，不会持续检测。';

  @override
  String tradeSendNotSent(String reason) {
    return '报价未发出。$reason';
  }

  @override
  String get tradeCheckSendResult => '核对发送结果';

  @override
  String get tradeSendNotFound =>
      '暂未查到对应的新报价，Steam 可能尚未更新。请先检查待确认和已发送报价，避免重复发送。';

  @override
  String tradeSendCheckFailed(String reason) {
    return '暂时无法核对发送结果。$reason';
  }

  @override
  String get tradeSendRejected => 'Steam 拒绝了这笔报价，但未提供详细原因。请检查所选物品和交易限制。';

  @override
  String get tradeSendUnreadableResponse => 'Steam 未返回完整的发送回执。';

  @override
  String get steamConnectionPacHelp =>
      '检测到了系统代理设置，但没有可用的 HTTP 端口或 VPN 线路。本程序不解析 PAC 脚本，请开启外部代理的 HTTP 代理或 VPN 模式。';

  @override
  String forkUpdateTransferSize(String received, String total) {
    return '$received / $total MiB';
  }

  @override
  String forkUpdateTransferSpeed(String speed, String unit) {
    return '$speed $unit/秒';
  }

  @override
  String forkUpdateRemainingSeconds(int seconds) {
    return '预计还需 $seconds 秒';
  }

  @override
  String forkUpdateRemainingMinutes(int minutes) {
    return '预计还需 $minutes 分钟';
  }

  @override
  String get forkUpdateWaitingForData => '等待数据…';

  @override
  String get forkUpdateVerifying => '正在校验安装包…';

  @override
  String get forkUpdateConnectionHint =>
      '自动模式通过 GH-Proxy 直连下载，无需开启代理；失败时切回 GitHub。安装包始终按 GitHub 的 SHA-256 校验。';

  @override
  String get forkUpdateSourceLabel => '下载来源';

  @override
  String get forkUpdateSourceAutomatic => '自动加速（推荐）';

  @override
  String get forkUpdateSourceOfficial => 'GitHub 官方';

  @override
  String forkUpdateSourceAccelerated(String provider) {
    return '加速源直连 · $provider';
  }

  @override
  String get marketTabSearch => '市场';

  @override
  String get marketSearchHint => '搜索商品名称，例如 AK-47';

  @override
  String get marketSearchEmpty => '选择游戏和币种，输入商品名后搜索。仅在搜索时加载。';

  @override
  String get marketSearchButton => '搜索市场';

  @override
  String get marketSearchAllGames => '全部游戏';

  @override
  String get marketSearchGame => '游戏';

  @override
  String get marketSearchCurrency => '币种';

  @override
  String get marketSearchNoResults => '没有找到相关商品，试试其他关键词。';

  @override
  String get marketSearchMore => '加载更多';

  @override
  String marketSearchListings(int count) {
    return '在售数量：$count';
  }

  @override
  String get marketSearchPriceUnavailable => '暂无价格';

  @override
  String get marketSearchPriceNote => '仅为可见商品按所选币种加载参考价格；价格可能变化。';

  @override
  String get marketSearchRefreshPrice => '刷新价格';

  @override
  String get marketSearchRateLimited => 'Steam 请求过多，请稍后重试。';

  @override
  String get marketSearchUnavailable => '暂时无法获取市场商品，请稍后重试。';

  @override
  String marketSearchRequestedCurrency(String currency) {
    return '请求币种：$currency';
  }

  @override
  String get steamConnectionUnresolvedProxy => '系统代理不可用';

  @override
  String get steamDesktopLoginButton => '打开 Steam 并登录';

  @override
  String get steamDesktopLoginHelp =>
      '使用所选账号打开或切换 Steam，并自动批准本次本机登录窗口的二维码。请先退出正在运行的游戏。';

  @override
  String get steamDesktopLoginPreparing => '正在准备所选账号…';

  @override
  String get steamDesktopLoginWaitingQr => '正在等待本机 Steam 登录二维码…';

  @override
  String get steamDesktopLoginApproving => '正在批准本机登录…';

  @override
  String get steamDesktopLoginWaitingAccount => '正在确认 Steam 登录状态…';

  @override
  String get steamDesktopLoginComplete => '已核验 Steam 客户端当前账号为所选账号。';

  @override
  String get steamDesktopLoginManual => 'Steam 已打开，但未能确认本机登录二维码。可使用下方扫码入口继续。';

  @override
  String get steamDesktopLoginUnconfirmed =>
      '已提交登录批准请求，但尚未确认 Steam 已登录。请查看 Steam 窗口后刷新状态。';

  @override
  String get steamDesktopLoginCancelled => '已停止自动登录';

  @override
  String get steamDesktopLoginCancel => '停止自动批准';

  @override
  String get steamDesktopLoginWrongAccount => 'Steam 当前登录了其他账号，已停止自动批准。';

  @override
  String get steamClientOpen => '打开 Steam';

  @override
  String get steamSwitchLaunchFailed => 'Steam 未能启动。请检查安装路径，并确认 Steam 可以正常运行。';

  @override
  String get steamSwitchFileAccessFailed => '无法备份或修改 Steam 设置，请检查安装目录的读写权限。';

  @override
  String get steamDesktopLoginSession => 'Steam 已打开，正在连接所选账户…';

  @override
  String get steamSwitchInspecting => '检查本机 Steam';

  @override
  String steamSwitchErrorDetails(
    String stage,
    String code,
    String systemError,
  ) {
    return '阶段：$stage；错误码：$code；Windows：$systemError。';
  }

  @override
  String get approveScreenBusy => '另一个截图正在进行，请先完成或取消。';

  @override
  String get approveScreenDisplayChanged => '屏幕布局已变化，请重新框选。';

  @override
  String get approveScreenRegionTooLarge => '框选范围过大，请只选择二维码区域。';

  @override
  String approveScreenFailedDetail(String detail) {
    return '无法截取屏幕，请重试。错误信息：$detail。';
  }

  @override
  String get marketFavoriteTitle => '收藏';

  @override
  String get marketFavoriteAdd => '收藏商品';

  @override
  String get marketFavoriteRemove => '取消收藏';

  @override
  String get marketFavoriteEmpty => '在市场搜索结果中收藏商品，下次可在这里直接查看价格。';

  @override
  String get marketFavoriteSaveFailed => '无法读取或保存市场收藏，请重试。';

  @override
  String get syncCompareTitle => '对比本地与远程';

  @override
  String get syncCompareRefresh => '刷新对比';

  @override
  String get syncCompareHelp =>
      '先查看每项差异，再选择方向。“较新”根据上次共同版本后的改动判断；下方时间为最近同步时间，仅供参考。拉取或上传只处理选中的这一项。';

  @override
  String get syncCompareStale => '本地或远程内容已发生变化，请刷新对比后重试。';

  @override
  String get syncCompareFailed => '对比或传输失败，请检查连接与同步密码后刷新；尚未确认传输成功。';

  @override
  String get syncCompareSame => '内容一致';

  @override
  String get syncCompareLocalOnly => '仅本地有';

  @override
  String get syncCompareRemoteOnly => '仅远程有';

  @override
  String get syncCompareLocalNewer => '本地有较新改动';

  @override
  String get syncCompareRemoteNewer => '远程有较新改动';

  @override
  String get syncCompareBothChanged => '两端内容不同，请选择保留哪一端';

  @override
  String get syncCompareRemoteDeleted => '远程已删除；上传将恢复此账户';

  @override
  String get syncCompareSettings => '设置、市场收藏与加速订阅';

  @override
  String get syncCompareSettingsConflict => '两端设置均有改动，请先对比再选择上传或拉取。';

  @override
  String get syncComparePull => '拉取远程 → 本地';

  @override
  String get syncCompareUpload => '上传本地 → 远程';

  @override
  String get syncCompareHidden => '敏感内容不同（已隐藏）';

  @override
  String get syncCompareCurrency => '市场币种';

  @override
  String get syncCompareFavorites => '市场收藏';

  @override
  String get syncCompareSubscription => '加速订阅地址';

  @override
  String get syncCompareNodes => '加速节点配置';

  @override
  String get syncCompareSelectedNode => '选中的加速节点';

  @override
  String get marketFavoriteSearch => '搜索';

  @override
  String get inventoryCooldownDetails => '交易与市场限制';

  @override
  String inventoryCooldownUntil(String time) {
    return '冷却至 $time';
  }

  @override
  String get inventoryCooldownTradable => '可交易';

  @override
  String get inventoryCooldownNotTradable => '不可交易';

  @override
  String get inventoryCooldownMarketable => '可上架';

  @override
  String get inventoryCooldownLocalTime => '时间已转换为本机时区。';

  @override
  String get inventoryCooldownUnknown => 'Steam 未提供可识别的解锁时间，不估算日期。';

  @override
  String get inventoryCooldownElapsed => '该日期已到，请刷新库存，以 Steam 返回的最新限制状态为准。';

  @override
  String inventoryCooldownRemaining(int days, int hours, int minutes) {
    return '剩余：$days 天 $hours 小时 $minutes 分钟';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get steamSwitchTitle => '切換 Steam 帳號';

  @override
  String get steamSwitchUnifiedHelp =>
      '選取帳號後點擊切換，即可開啟 Steam 並登入。已匯入的帳號優先使用 Steam 記住的登入資訊，需要驗證時，有線上工作階段即可自動批准本次本機登入 QR 碼。未匯入的帳號仍可使用 Steam 已記住的登入資訊。請先退出正在執行的遊戲。';

  @override
  String get steamSwitchHelp =>
      '可切換已在這台電腦的 Steam 登入過並記住登入資訊的帳號。將驗證器匯入 GooeSteamKit 不代表該帳號已登入 Steam 用戶端。';

  @override
  String get steamSwitchPath => 'Steam 安裝資料夾';

  @override
  String get steamSwitchNotFound => '找不到 Steam，請選擇 steam.exe 以指定安裝位置。';

  @override
  String get steamSwitchBrowse => '選擇 steam.exe';

  @override
  String get steamSwitchNoAccounts =>
      '這台電腦尚無 Steam 登入紀錄。請先在 Steam 登入並記住登入資訊，再重新整理清單。';

  @override
  String get steamSwitchNoMatch =>
      '所選帳號尚無本機登入紀錄。可使用上方的一鍵登入；登入並記住登入資訊後，重新整理即可從下方清單切換。';

  @override
  String get steamSwitchNeedsLogin => '請先在 Steam 登入此帳號並記住登入資訊，再重新整理清單。';

  @override
  String get steamSwitchButton => '切換帳號';

  @override
  String steamSwitchConfirm(String account) {
    return 'Steam 將關閉並重新啟動，以登入 $account。請先結束遊戲，並等待 Steam 雲端存檔同步完成。是否繼續？';
  }

  @override
  String get steamSwitchStopping => '正在等待 Steam 結束…';

  @override
  String get steamSwitchBackingUp => '正在備份 Steam 設定…';

  @override
  String get steamSwitchConfiguring => '正在設定 Steam 登入帳號…';

  @override
  String get steamSwitchStarting => '正在啟動 Steam…';

  @override
  String get steamSwitchRestoring => '正在還原 Steam 設定…';

  @override
  String get steamSwitchLaunched => '已啟動 Steam，請在用戶端確認登入帳號。若出現提示，請重新登入。';

  @override
  String get steamSwitchBackup => '設定備份位置';

  @override
  String get steamSwitchInvalidPath =>
      '無法讀取此 Steam 安裝資料夾或設定。請選擇正確的 steam.exe 後再試。';

  @override
  String get steamSwitchCloseFailed => 'Steam 未能正常結束。請手動結束 Steam 後再試。';

  @override
  String get steamSwitchBusy => '另一個帳號切換作業正在進行，請稍後再試。';

  @override
  String get steamSwitchChanged => '切換期間 Steam 設定有所變更。請結束 Steam，重新整理清單後再試。';

  @override
  String get steamSwitchFailed => '無法完成帳號切換。請檢查 Steam 後再試。';

  @override
  String get steamSwitchRecoveryNeeded => '切換失敗，部分設定無法還原。請保留下方備份，還原設定後再試。';

  @override
  String get appTitle => 'GooeSteamKit';

  @override
  String get navAccounts => '帳號';

  @override
  String get navSettings => '設定';

  @override
  String get unlockTitle => '解鎖';

  @override
  String get unlockPrompt => '請輸入你的加密通行碼';

  @override
  String get unlockButton => '解鎖';

  @override
  String get unlockInvalid => '通行碼不正確。';

  @override
  String get unlockWithBiometric => '用生物辨識 / 裝置密碼解鎖';

  @override
  String get unlockLoading => '解密中…';

  @override
  String get unlockCantUnlock => '無法解鎖？';

  @override
  String get resetVaultTitle => '重設加密資料';

  @override
  String get resetVaultBody =>
      '這會刪除這台裝置上儲存的每一筆帳號項目與加密金鑰，之後你必須重新匯入 maFile 備份。你的 Steam 帳號與其驗證器不受影響。\n\n適用於正確的 PIN 一直被拒絕的情況——通常發生在備份還原或換機之後：硬體金鑰永遠不會離開原本那台裝置，還原回來的資料再也無法解密。\n\n此操作無法復原。';

  @override
  String get resetVaultConfirm => '刪除並重設';

  @override
  String get storeErrorTitle => '無法讀取已儲存的資料';

  @override
  String get storeErrorBody =>
      'GooeSteamKit 的本機帳號資料庫（manifest.json）遺失或損毀。寫入被中斷或還原不完整都可能造成這個情況。請先重試；若一直失敗，就重設後重新匯入你的 maFile 備份。';

  @override
  String get storeRepair => '嘗試修復';

  @override
  String storeActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get pinSetupTitle => '設定解鎖 PIN';

  @override
  String get pinSetupPrompt => '用 6 位數 PIN 保護 GooeSteamKit。解鎖時要輸入它（或用指紋）。';

  @override
  String get pinLabel => '6 位數 PIN';

  @override
  String get pinConfirmLabel => '確認 PIN';

  @override
  String get pinSetButton => '設定 PIN';

  @override
  String get settingsSet => '設定';

  @override
  String get pinChangeTitle => '變更 PIN';

  @override
  String get pinCurrentLabel => '目前的 PIN';

  @override
  String get pinNewLabel => '新的 PIN';

  @override
  String get pinSixDigits => '請輸入 6 位數 PIN。';

  @override
  String get pinMismatch => '兩次輸入的 PIN 不一致。';

  @override
  String get unlockBiometricReason => '解鎖 GooeSteamKit';

  @override
  String get settingsBiometric => '使用系統解鎖';

  @override
  String get settingsBiometricDesc =>
      '啟動驗證開啟時，可用指紋、Windows Hello 或裝置密碼代替 GooeSteamKit PIN。關閉啟動驗證會同時停用此項；重新開啟後需另行啟用。';

  @override
  String get settingsBiometricNeedPasskey => '請先設定加密通行碼。';

  @override
  String get settingsBiometricUnavailable => '這台裝置沒有設定生物辨識或螢幕鎖。';

  @override
  String get settingsBiometricEnabled => '已啟用系統解鎖';

  @override
  String get settingsHoldConfirm => '長按確認';

  @override
  String get settingsHoldConfirmDesc =>
      '不可逆的接受動作（交易、確認）需要長按才會生效。關閉後單擊就立即生效；批次動作仍會先詢問。';

  @override
  String get settingsDeleteHold => '刪除需長按確認';

  @override
  String get settingsDeleteHoldDesc => '刪除帳號的確認按鈕需按住蓄滿才會生效，誤觸點一下不會刪除帳號。';

  @override
  String get accountSessionInvalid => '登入已失效——點按重新登入';

  @override
  String get settingsHaptics => '觸覺回饋';

  @override
  String get settingsHapticsDesc => '長按確認的過程中與完成時的震動回饋。';

  @override
  String get settingsBlockScreenshots => '禁止截圖';

  @override
  String get settingsBlockScreenshotsDesc =>
      '讓 GooeSteamKit 不出現在截圖、螢幕錄影和最近使用畫面的預覽裡。代價是螢幕分享時視窗會變黑，也沒辦法再把截圖附到意見回饋裡。';

  @override
  String get passkeyLabel => '通行碼';

  @override
  String get accountsEmpty => '還沒有帳號。匯入 maFile 或登入來新增一個。';

  @override
  String get emptyAddAccount => '新增帳號';

  @override
  String get accountReady => '就緒';

  @override
  String get tutCodeTitle => '即時驗證碼';

  @override
  String get tutCodeBody => '點大字驗證碼就能複製。點帳號那一行可在帳號名稱 / 暱稱 / SteamID 之間切換。';

  @override
  String get tutSwipeRightTitle => '向右滑 → 交易確認';

  @override
  String get tutSwipeRightBody => '把帳號向右滑，直接打開它的交易確認。';

  @override
  String get tutSwipeLeftTitle => '向左滑 → 更多動作';

  @override
  String get tutSwipeLeftBody => '向左滑可更新登入狀態、匯出 maFile 或移除帳號。';

  @override
  String get tutLongPressTitle => '長按 → 庫存與市集';

  @override
  String get tutLongPressBody => '長按帳號可瀏覽它的庫存，並把物品上架到社群市集。';

  @override
  String get tutPullTitle => '下拉重新整理';

  @override
  String get tutPullBody => '下拉帳號清單可更新頭像，並檢查待處理的登入請求。';

  @override
  String get tutSkip => '略過';

  @override
  String get tutNext => '下一步';

  @override
  String get tutDone => '知道了';

  @override
  String get settingsTutorial => '手勢教學';

  @override
  String get settingsTutorialDesc => '重播主畫面的操作導覽（滑動、長按、下拉重新整理）。';

  @override
  String get settingsTutorialReplay => '重播';

  @override
  String get welcomeTitle => '歡迎使用 GooeSteamKit';

  @override
  String get welcomeSubtitle => '你的驗證器會加密儲存在這台裝置上。請選擇開始的方式。';

  @override
  String get welcomeLoginCta => '登入 Steam';

  @override
  String get welcomeLoginSub => '設定一個新的驗證器';

  @override
  String get welcomeImportCta => '匯入 .maFile';

  @override
  String get welcomeImportSub => '把既有帳號搬過來';

  @override
  String get welcomeSyncCta => '從同步還原';

  @override
  String get welcomeSyncSub => '從既有的同步庫拉取你的帳號';

  @override
  String get copyCode => '複製驗證碼';

  @override
  String get codeCopied => '登入驗證碼已複製到剪貼簿';

  @override
  String get copied => '已複製到剪貼簿';

  @override
  String get copySteamId => '複製 SteamID';

  @override
  String get pendingTitle => '待處理';

  @override
  String get pendingTabConfirmations => '確認';

  @override
  String get pendingTabOffers => '交易報價';

  @override
  String get confirmationsTitle => '確認';

  @override
  String get confirmationsEmpty => '沒有待處理的確認。';

  @override
  String get confirmationsRefresh => '重新整理';

  @override
  String get confAccept => '接受';

  @override
  String get confDecline => '拒絕';

  @override
  String get confSelectAll => '全選';

  @override
  String get confAcceptSelected => '接受所選';

  @override
  String get confDeclineSelected => '拒絕所選';

  @override
  String get confAcceptAll => '全部接受';

  @override
  String get confRejectAll => '全部拒絕';

  @override
  String confAcceptAllConfirm(int count) {
    return '要接受全部 $count 項確認嗎？';
  }

  @override
  String confRejectAllConfirm(int count) {
    return '要拒絕全部 $count 項確認嗎？';
  }

  @override
  String get confAcceptAllWarn => '這會一次批准所有待處理的交易與市集上架。請確認你認得其中每一項。';

  @override
  String get confRejectAllWarn => '這會一次取消所有待處理的確認。';

  @override
  String confPending(int count) {
    return '$count 項待確認';
  }

  @override
  String get confAllProcessed => '已全部處理';

  @override
  String get confTypeTrade => '交易';

  @override
  String get confTypeMarket => '市集上架';

  @override
  String get confTypeOther => '確認';

  @override
  String get confTypeFamilyJoin => '家庭群組邀請';

  @override
  String get confTypeApiKey => 'API 金鑰';

  @override
  String get confTypePhoneChange => '更換手機號碼';

  @override
  String get confTypeAccountRecovery => '帳號救援';

  @override
  String get confTypeFeatureOptOut => '功能退出';

  @override
  String confProcessing(int count) {
    return '正在處理 $count 項確認…';
  }

  @override
  String confResult(int ok, int fail) {
    return '成功 $ok 項，失敗 $fail 項';
  }

  @override
  String get confNeedsLogin => '登入狀態已過期——請重新登入以更新這個帳號。';

  @override
  String get confRejected =>
      'Steam 拒絕了這次確認請求。這通常代表 maFile 與帳號上目前的驗證器不符（買來的帳號很常見）——請先移除驗證器再重新綁定，或匯入正確的 maFile。裝置時間偏差過大也會造成這個問題。';

  @override
  String get offersSegReceived => '收到';

  @override
  String get offersSegSent => '送出';

  @override
  String get offersSegHistory => '紀錄';

  @override
  String get offersEmpty => '沒有交易報價。';

  @override
  String get offerGift => '贈送——你不用給出任何東西';

  @override
  String get offerOneSided => '你給出物品，卻收不到任何東西';

  @override
  String get offerEscrow => '物品會先由 Steam 保管一段時間才送達';

  @override
  String get offerAcceptHold => '長按接受';

  @override
  String get offerDecline => '拒絕';

  @override
  String get offerCancel => '取消報價';

  @override
  String get offerReceiveLabel => '你收到';

  @override
  String get offerGiveLabel => '你給出';

  @override
  String get offerAccepted => '已接受報價——請到「確認」頁完成確認';

  @override
  String get offerAcceptedNoConf => '已接受報價。';

  @override
  String offerActionFailed(String msg) {
    return '操作失敗：$msg';
  }

  @override
  String get offerDeclined => '已拒絕報價。';

  @override
  String get offerCanceled => '已取消報價。';

  @override
  String get pendingTabInvites => '邀請';

  @override
  String famInviteTitle(String groupName) {
    return '「$groupName」邀請你加入';
  }

  @override
  String get famInviteTitleGeneric => '家庭群組邀請';

  @override
  String famInviteFrom(String inviter) {
    return '邀請人：$inviter';
  }

  @override
  String famInviteRole(String role) {
    return '角色：$role';
  }

  @override
  String famInviteSlots(int used, int total) {
    return '成員 $used/$total';
  }

  @override
  String get famRoleAdult => '成人';

  @override
  String get famRoleChild => '兒童';

  @override
  String famRoleUnknown(int n) {
    return '角色 #$n';
  }

  @override
  String get famPreflightTitle => '加入前檢查';

  @override
  String get famCheckWalletMatch => '錢包地區相符';

  @override
  String get famCheckWalletMismatch => '錢包地區不符——Steam 會限制加入';

  @override
  String get famCheckIpMatch => '常用 IP 相符';

  @override
  String get famCheckIpMismatch => 'IP 與你的常用地點不符';

  @override
  String get famCheckCooldown => '加入後 1 年內無法更換家庭群組（Steam 冷卻期）';

  @override
  String famJoinRestricted(int code) {
    return 'Steam 阻擋了這次加入（限制碼 $code）';
  }

  @override
  String get famInviteJoinHold => '長按加入';

  @override
  String get famInviteAwaiting2fa => '等待確認中——請到「確認」頁處理';

  @override
  String get famInviteJoined => '已加入 ✓';

  @override
  String get famInviteViewGroup => '查看家庭群組 ›';

  @override
  String get famJoinSent => '已送出加入請求——請到「確認」頁完成確認';

  @override
  String get famJoinDone => '已加入家庭群組。';

  @override
  String famJoinFailed(String msg) {
    return '加入失敗：$msg';
  }

  @override
  String get famInvitesEmpty => '沒有待處理的家庭群組邀請。';

  @override
  String get famAccountAction => '家庭群組';

  @override
  String get famNotInGroup => '這個帳號不在任何家庭群組裡。';

  @override
  String famSummaryMembers(int used, int total) {
    return '成員 $used/$total';
  }

  @override
  String famSummaryCooldown(int days) {
    return '冷卻 $days 天';
  }

  @override
  String get famInvitesSection => '邀請';

  @override
  String get famSectionMembers => '成員';

  @override
  String get famMemberYou => '（你）';

  @override
  String get famSectionPending => '待處理';

  @override
  String get famPendingComingSoon => '購買審核會在後續版本推出。';

  @override
  String get deviceSessionsAction => '裝置';

  @override
  String get deviceSessionsTitle => '已登入的裝置';

  @override
  String get deviceSessionsEmpty => '這個帳號沒有使用中的裝置。';

  @override
  String get deviceRevokeAction => '登出';

  @override
  String deviceRevokeConfirm(String name) {
    return '要把「$name」從你的 Steam 帳號登出嗎？它必須重新登入。';
  }

  @override
  String deviceRevokeDone(String name) {
    return '已將「$name」登出。';
  }

  @override
  String deviceRevokeFailed(String error) {
    return '無法將這台裝置登出：$error';
  }

  @override
  String get deviceCurrent => '（本機）';

  @override
  String get deviceSignedOut => '已登出';

  @override
  String get deviceUnnamed => '未知裝置';

  @override
  String deviceLastSeen(String age) {
    return '$age前活躍';
  }

  @override
  String get devicePlatformSteam => 'Steam 用戶端';

  @override
  String get devicePlatformWeb => '網頁瀏覽器';

  @override
  String get devicePlatformMobile => '手機 App';

  @override
  String get devicePlatformUnknown => '未知';

  @override
  String deviceAgeDays(int n) {
    return '$n 天';
  }

  @override
  String deviceAgeHours(int n) {
    return '$n 小時';
  }

  @override
  String deviceAgeMinutes(int n) {
    return '$n 分鐘';
  }

  @override
  String get deviceAgeNow => '剛剛';

  @override
  String get keyRedeemAction => '兌換產品代碼';

  @override
  String get keyRedeemTitle => '兌換 Steam 產品代碼';

  @override
  String keyRedeemFor(String account) {
    return '啟動到 $account';
  }

  @override
  String get keyRedeemHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get keyRedeemPaste => '貼上';

  @override
  String get keyRedeemSubmit => '兌換';

  @override
  String get keyRedeemNote =>
      '啟動無法復原，產品會直接加進這個帳號。連續幾組產品代碼被拒絕後，Steam 會封鎖啟動約一小時，送出前請先核對。';

  @override
  String keyRedeemConfirm(String account) {
    return '要把這組產品代碼啟動到 $account 嗎？之後無法復原，也無法轉到其他帳號。';
  }

  @override
  String get keyRedeemDone => '產品代碼已啟動。';

  @override
  String get keyRedeemGranted => '已加入媒體庫：';

  @override
  String get keyRedeemNoProducts => 'Steam 接受了這組產品代碼，但沒有回報產品名稱。請到這個帳號的媒體庫確認。';

  @override
  String get keyRedeemNetworkError =>
      '連不上 Steam。如果是請求逾時，Steam 可能其實已經處理過了——再試這組產品代碼之前，請先到這個帳號的媒體庫確認。';

  @override
  String get keyErrInvalid =>
      'Steam 不認得這組產品代碼。請檢查是否打錯——0 與 O、1 與 I 之類的字元很容易看混。';

  @override
  String get keyErrAlreadyOwned => '這個帳號已經擁有這項產品。';

  @override
  String get keyErrAlreadyActivated => '這組產品代碼已經被用過了——可能是這個帳號，也可能是別的帳號。';

  @override
  String get keyErrRegionLocked => '這項產品無法在這個帳號所在的國家／地區啟動。';

  @override
  String get keyErrNeedsBaseProduct => '這是 DLC 或資料片，這個帳號必須先擁有本體遊戲。';

  @override
  String get keyErrNeedsPs3Login => '這項產品必須先在 PlayStation®3 主機上遊玩過才能啟動。';

  @override
  String get keyErrRateLimited => '最近被拒絕的產品代碼太多。Steam 會封鎖啟動約一小時——請稍後再試。';

  @override
  String keyErrUnknown(int code) {
    return 'Steam 拒絕了這組產品代碼（代碼 $code）。';
  }

  @override
  String get loginOrApprove => '…或者直接在 Steam 手機 App 裡點「允許」。';

  @override
  String get addErrPresent => '這個帳號已經有驗證器了。';

  @override
  String get addErrConfirmEmail => '請先確認 Steam 寄來的 Email，然後重試。';

  @override
  String get addErrLocked =>
      '這個帳號已被 Steam 鎖定／限制——請先到 help.steampowered.com 救回帳號，再新增驗證器。';

  @override
  String get addErrRateLimited => '嘗試次數太多。請稍等一陣子再試。';

  @override
  String get addErrFailed => '新增驗證器失敗。';

  @override
  String addErrSaveFailed(String code) {
    return '無法把驗證器存到這台裝置，所以在它生效之前就停止了設定。請記下這組撤銷碼，並從你的帳號移除這個待處理的驗證器，然後再試一次：$code';
  }

  @override
  String get addErrBadSms => '簡訊驗證碼錯誤，請再試一次。';

  @override
  String get debugLog => '除錯記錄';

  @override
  String get debugLogDesc => '用來診斷登入 / 確認的網路追蹤記錄';

  @override
  String get feedbackTitle => '意見回饋';

  @override
  String get feedbackDesc => '發現 bug 或有想法嗎？直接寄給開發者；想公開討論也可以到 GitHub 開 issue。';

  @override
  String get feedbackSend => '送出回饋';

  @override
  String get feedbackMessageLabel => '你的意見';

  @override
  String get feedbackMessageHint => '哪裡壞了 / 你想要什麼？';

  @override
  String get feedbackContactLabel => '聯絡方式（選填）';

  @override
  String get feedbackContactHint => 'Email 或使用者名稱——想要回覆才需要填';

  @override
  String feedbackAttachNote(String meta) {
    return '會隨你的訊息一起送出：$meta';
  }

  @override
  String get feedbackSent => '已送出，謝謝你的回饋！';

  @override
  String get feedbackFailed => '送不出去。請檢查網路後再試一次。';

  @override
  String feedbackRefused(String reason) {
    return '中繼服務拒絕了這份回報：$reason';
  }

  @override
  String feedbackRelayDown(String reason) {
    return '意見回饋服務自己那端出了問題（$reason）。你的網路沒問題——請稍後再試。';
  }

  @override
  String get feedbackAttachLog => '附上除錯記錄';

  @override
  String get feedbackAttachLogHint => '最近的網路追蹤記錄，可能包含帳號名稱 / SteamID';

  @override
  String get feedbackLogConsentBody =>
      '除錯記錄是這次執行期間最近的網路追蹤內容，可能包含你的帳號名稱與 SteamID——絕不含你的金鑰、權杖或密碼。它只會隨這份回報一起送出，詳見隱私權政策。';

  @override
  String get feedbackLogConsentAgree => '同意';

  @override
  String get backupReminderTitle => '請備份你的金鑰';

  @override
  String get backupReminderBody =>
      'GooeSteamKit 只把你的驗證器資料留在這台裝置上。請把 maFile 備份到安全的地方。撤銷碼（R 碼）只在你第一次新增驗證器時顯示一次——請當場抄下並保管好；萬一這台裝置遺失，它是你移除驗證器的最後手段。';

  @override
  String get backupReminderOk => '知道了';

  @override
  String get debugCopyAll => '全部複製';

  @override
  String get debugCopied => '記錄已複製';

  @override
  String get debugEmpty => '還沒有記錄。';

  @override
  String get commonOpen => '開啟';

  @override
  String get commonClear => '清除';

  @override
  String addErrFinalize(String detail) {
    return '完成綁定失敗：$detail';
  }

  @override
  String get loginTitle => '登入 Steam';

  @override
  String get loginUsername => '帳號名稱';

  @override
  String get loginPassword => '密碼';

  @override
  String get loginShowPassword => '顯示密碼';

  @override
  String get loginHidePassword => '隱藏密碼';

  @override
  String get loginSavePassword => '儲存密碼';

  @override
  String get loginSavePasswordHint =>
      '存在這個帳號的 maFile 裡，用來自動更新登入狀態；未加密的匯出檔會包含它。';

  @override
  String get loginButton => '登入';

  @override
  String get loginErrInvalidPassword => '帳號名稱或密碼錯誤。';

  @override
  String get loginErrRateLimited => '嘗試次數太多——請稍等一陣子再試。';

  @override
  String get loginErrCodeMismatch => '驗證碼不符——請核對後再試一次。';

  @override
  String get loginViaQr => '用 QR Code 登入';

  @override
  String get loginViaCredentials => '用密碼登入';

  @override
  String get loginScanWithApp => '用 Steam 手機 App 掃描這個 QR Code';

  @override
  String get loginNeedGuardCode => '請輸入 Steam 令牌驗證碼';

  @override
  String get loginNeedEmailCode => '請輸入寄到你信箱的驗證碼';

  @override
  String get loginSubmitCode => '送出';

  @override
  String get loginWaiting => '等待確認中…';

  @override
  String get loginStepCredentials => '帳密';

  @override
  String get loginStepConfirm => '確認';

  @override
  String get loginStepDone => '完成';

  @override
  String get loginWaitingDesc =>
      '請在 Steam 手機 App 上批准這次登入。你也可以改用 Email 驗證碼或 QR Code 登入。';

  @override
  String loginFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String get approveTitle => '批准登入';

  @override
  String get approveScanPrompt => '掃描你要登入的那台裝置上顯示的 QR Code。';

  @override
  String get approvePastePrompt => '或在這裡貼上 QR Code 連結';

  @override
  String get approveButton => '批准';

  @override
  String get approveReject => '拒絕';

  @override
  String get approveSuccess => '已批准登入。';

  @override
  String get approveRejected => '已拒絕登入。';

  @override
  String get approveBadCode => '這不是 Steam 登入用的 QR Code。';

  @override
  String get approveLocation => '地點';

  @override
  String get approveDevice => '裝置';

  @override
  String get approveWarnStranger => '不是你自己發起的登入嗎？請拒絕。';

  @override
  String get importTitle => '匯入帳號';

  @override
  String get importPickFile => '選擇 .maFile 檔案';

  @override
  String get importSuccess => '已匯入帳號。';

  @override
  String importFailed(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get importDuplicateTitle => '帳號已存在';

  @override
  String importDuplicateBody(String name) {
    return '這個 maFile 對應的帳號 $name 已經在這台裝置上。要用匯入的檔案覆寫已儲存的帳號嗎？檔案裡沒有的快取頭像、已存密碼與現有登入狀態會保留下來。';
  }

  @override
  String importDuplicateBodyUnreadable(String name) {
    return '這個 maFile 對應的帳號 $name 已經在這台裝置上，但它的資料已經無法讀取。匯入會把它完全取代掉。';
  }

  @override
  String get importDuplicateOverwrite => '覆寫';

  @override
  String get importSessionDeadTitle => '要啟用這個帳號嗎？';

  @override
  String get importSessionDeadBody =>
      '這個 maFile 裡的 Steam 登入狀態已經過期。現在登入就能使用交易確認與登入批准——Steam 令牌驗證碼會自動填入。';

  @override
  String get importSessionLater => '稍後';

  @override
  String get sdaImportAction => '匯入 SDA 資料夾';

  @override
  String get sdaImportHint =>
      '選取多個 .maFile 檔案批次匯入。未加密檔案不需要 manifest.json；SDA 加密檔案需同時選取 manifest.json，其中包含解密參數。';

  @override
  String get sdaImportNoManifest => '所選檔案裡沒有 manifest.json。請把它和 .maFile 一起選取。';

  @override
  String sdaImportBadManifest(String error) {
    return '這個 manifest.json 讀不了：$error';
  }

  @override
  String get sdaImportPassTitle => 'SDA 加密通行碼';

  @override
  String get sdaImportPassBody =>
      '這些 maFile 是加密的。請輸入你當初在 Steam Desktop Authenticator 裡設定的通行碼。';

  @override
  String get sdaImportWrongPass => '這個通行碼解不開任何一個檔案。';

  @override
  String sdaImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已匯入 $count 個帳號。',
    );
    return '$_temp0';
  }

  @override
  String sdaImportSkipped(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '略過了 $count 個帳號：$names',
    );
    return '$_temp0';
  }

  @override
  String get sdaImportNothing => '沒有匯入任何帳號。';

  @override
  String updateAvailable(String version) {
    return '新版本 $version 已發布';
  }

  @override
  String get updateView => '檢視';

  @override
  String get updateDismiss => '略過';

  @override
  String get settingsUpdateCheck => '啟動時檢查更新';

  @override
  String get settingsUpdateCheckDesc => '每次啟動向版本端點查詢一次。不帶帳號資料，端點不留日誌。';

  @override
  String get importSessionLoginNow => '立即登入';

  @override
  String get actionExport => '匯出 maFile';

  @override
  String get actionLoginRequests => '登入請求';

  @override
  String get loginRequestTitle => '要批准登入嗎？';

  @override
  String loginRequestBody(String device, String location) {
    return '$device 正從 $location 登入你的 Steam 帳號。';
  }

  @override
  String get loginRequestApprove => '允許';

  @override
  String get loginRequestDeny => '拒絕';

  @override
  String get loginNoPending => '沒有待處理的登入請求。';

  @override
  String get loginNeedSession => '請先登入以更新這個帳號的登入狀態。';

  @override
  String get loginApproved => '已允許登入。';

  @override
  String get loginDenied => '已拒絕登入。';

  @override
  String exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get exportWarnTitle => '要匯出未加密的 maFile 嗎？';

  @override
  String get exportWarnBody =>
      '匯出的 .maFile 沒有加密。它含有這個帳號的 Steam 令牌金鑰與撤銷碼——任何拿到這個檔案的人都能接管你的驗證器。請存放在安全的地方，用完立刻刪除。';

  @override
  String get exportIncludePassword => '一併包含已儲存的 Steam 密碼（不建議）';

  @override
  String get addAuthTitle => '新增驗證器';

  @override
  String get addAuthPhonePrompt => '請輸入你的手機號碼（含國碼）';

  @override
  String get addAuthSmsPrompt => '請輸入手機收到的簡訊驗證碼';

  @override
  String get addAuthEmailPrompt => '請輸入 Steam 寄到你信箱的啟用碼';

  @override
  String addAuthRevocationWarn(String code) {
    return '請記下你的撤銷碼：$code';
  }

  @override
  String get addAuthConfirmRevocation => '請再輸入一次撤銷碼，確認你已經存好了';

  @override
  String get addAuthLinked => '驗證器已成功綁定。';

  @override
  String get addAuthStepPhone => '手機';

  @override
  String get addAuthStepSms => '啟用';

  @override
  String get addAuthStepRevocation => '撤銷碼';

  @override
  String get addPresentTitle => '這個帳號已經有驗證器';

  @override
  String get addPresentIntro => 'Steam 每個帳號只允許一個手機驗證器。請先移除現有的那個，再點「重試」。';

  @override
  String get addPresentStep1 => '還有舊手機或 Steam App 嗎？打開它 → Steam 令牌 → 移除驗證器。';

  @override
  String get addPresentStep2 => '有撤銷碼（Rxxxxx）嗎？開啟下面的頁面，選擇「移除驗證器」。';

  @override
  String get addPresentStep3 => '兩個都用不了嗎？請走 Steam 客服 → 說明 → Steam 令牌手機驗證器。';

  @override
  String get addPresentManageUrl => 'store.steampowered.com/twofactor/manage';

  @override
  String get addPresentCopiedUrl => '已複製連結';

  @override
  String get addPresentFallbackTitle => '收不到 Email 嗎？';

  @override
  String get addMoveInButton => '把驗證器移到這台裝置';

  @override
  String get addMoveInBlurb => 'Steam 會寄一組驗證碼到這個帳號的信箱。不會有 15 天交易保留期。';

  @override
  String get addMoveInSending => '正在寄送驗證碼…';

  @override
  String get addMoveInCodePrompt => '請輸入 Steam 寄到你信箱的驗證碼';

  @override
  String get addMoveInWarn =>
      '一旦確認：舊手機上的驗證器會立刻失效，舊的撤銷碼（Rxxxxx）也會作廢並換成新的。此操作無法復原。';

  @override
  String get addMoveInConfirm => '移到這裡';

  @override
  String get addMoveInDone => '驗證器已移到這台裝置。';

  @override
  String get addMoveInPopBlocked => '正在搬移驗證器，請稍候。';

  @override
  String get addErrBadChallengeCode => '驗證碼不正確。請核對 Email 後再試一次。';

  @override
  String addMoveInSaveFailed(String code, String secret) {
    return '驗證器已經移到這個帳號，但 GooeSteamKit 沒能把它存到這台裝置。你的舊驗證器已經失效，所以以下是僅有的副本——關閉這個畫面之前請立刻抄下來。\n\n撤銷碼：$code\n\n金鑰：$secret';
  }

  @override
  String get addMoveInCopySecrets => '複製';

  @override
  String get addMoveInCopied => '已複製';

  @override
  String get moveInRescueDismiss => '我存好了——關閉';

  @override
  String get moveInRescueDismissTitle => '要捨棄這些金鑰嗎？';

  @override
  String get moveInRescueDismissBody =>
      'GooeSteamKit 沒有留下任何其他副本。如果你還沒抄下撤銷碼與金鑰，你將永久失去這個驗證器。';

  @override
  String get moveInRescueDismissConfirm => '我存好了';

  @override
  String get commonRetry => '重試';

  @override
  String get commonCopy => '複製連結';

  @override
  String get commonRefresh => '重新整理';

  @override
  String get commonExport => '匯出';

  @override
  String get commonDelete => '刪除';

  @override
  String get settingsEncryption => '加密';

  @override
  String get settingsEncryptionDesc =>
      '本機的 maFile 以存放在裝置 Keystore 的隨機 256 位元金鑰加密（AES-256-GCM）；你的 6 位數 PIN 用來解開它。';

  @override
  String get settingsThemeDesc => '切換整體介面風格。';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsAppearanceDesc => '標準外觀要淺色還是深色。啟用皮膚時以皮膚為準。';

  @override
  String get settingsTextSize => '文字大小';

  @override
  String get settingsTextSizeDesc => '在系統字型大小之上再套用。';

  @override
  String get textSizeSmall => '小';

  @override
  String get textSizeMedium => '中';

  @override
  String get textSizeLarge => '大';

  @override
  String get settingsSkin => '皮膚';

  @override
  String get settingsSkinDesc => '有專屬字型與特效的完整風格外觀。';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get skinNone => '無';

  @override
  String get settingsChange => '變更';

  @override
  String get settingsSetPasskey => '設定 / 變更加密通行碼';

  @override
  String get settingsAutoConfirmMarket => '自動確認市集交易';

  @override
  String get settingsAutoConfirmMarketDesc =>
      '上架物品時預先勾選確認框，讓新的上架建立後立刻被確認。它絕不會在背景確認任何東西。';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '系統預設';

  @override
  String get settingsTheme => '主題';

  @override
  String get themeNeon => '霓虹';

  @override
  String get themePixel => '像素';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '淺色';

  @override
  String get settingsAbout => '關於';

  @override
  String get aboutTagline => '開源的 Steam 令牌驗證器，以 Flutter 打造。';

  @override
  String get aboutSourceCode => '原始碼';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutLicense => '授權條款';

  @override
  String get aboutPrivacy => '隱私權政策';

  @override
  String get privacyConsentTitle => '你的隱私';

  @override
  String get privacyConsentBody =>
      'AVA 把你的 Steam 帳號與金鑰保存在本裝置上——絕不上傳;除非你啟用可選的同步功能並指定自己的伺服器,而那也是先在本機加密後才離開裝置。無需註冊任何帳號。Steam 請求直連 Valve。開發者自己的兩個服務只在需要時才會被連線:Pro 權益查驗,以及意見回饋(僅當你按下傳送)。Play 版免費方案還會顯示廣告。沒有任何追蹤或統計。這一切都寫在隱私權政策裡——繼續即表示你接受它。';

  @override
  String get privacyUpdateTitle => '隱私權政策已更新';

  @override
  String get privacyUpdateBody =>
      '隱私權說明在你同意之後有了變更。新增:GooeSteamKit 現在可以透過你自己指定的伺服器,在多台裝置間同步帳號庫——預設關閉,所有資料先在本機加密再上傳,開發者不營運任何同步伺服器。請閱讀下方最新的說明。';

  @override
  String get privacyConsentScrollHint => '請捲動到底才能繼續';

  @override
  String get privacyConsentRead => '閱讀完整的隱私權政策';

  @override
  String get privacyConsentAgree => '同意並繼續';

  @override
  String get privacyConsentExit => '結束';

  @override
  String get actionMarket => '庫存 / 市集';

  @override
  String get marketTabInventory => '庫存';

  @override
  String get marketTabListings => '我的出售';

  @override
  String get marketSelectGame => '選擇遊戲';

  @override
  String get marketNoItems => '這個庫存裡沒有物品。';

  @override
  String get marketNotMarketable => '無法上架';

  @override
  String get marketSellTitle => '上架出售';

  @override
  String get marketYouReceive => '你實得';

  @override
  String get marketBuyerPays => '買家支付';

  @override
  String get marketLowest => '最低價';

  @override
  String get marketMedian => '中位價';

  @override
  String get marketHigh => '最高';

  @override
  String get marketLow => '最低';

  @override
  String get marketPriceUnavailable => '無法取得市價';

  @override
  String get marketListButton => '確認上架';

  @override
  String get marketListed => '已上架——去確認以完成。';

  @override
  String get marketListedDone => '已上架並確認。';

  @override
  String marketListedPartial(int listed, int total) {
    return '已上架 $listed/$total 件——其餘失敗；待確認的請到「確認」頁完成。';
  }

  @override
  String marketListedSessionExpired(int listed, int total) {
    return '已上架 $listed/$total 件後登入狀態過期——請重新登入並完成確認。';
  }

  @override
  String marketConfirmPartial(int ok, int total) {
    return '已上架——已確認 $ok/$total，其餘請到「確認」頁完成。';
  }

  @override
  String get marketAutoConfirm => '上架後自動確認';

  @override
  String get marketQuantity => '數量';

  @override
  String get marketMax => '最大';

  @override
  String marketListFailed(String error) {
    return '上架失敗：$error';
  }

  @override
  String get marketInvalidPrice => '請輸入有效的價格。';

  @override
  String get marketCancel => '取消上架';

  @override
  String get marketCancelled => '已取消上架。';

  @override
  String get marketNoListings => '沒有上架中的商品。';

  @override
  String get marketFeeNote => 'Steam 與遊戲的手續費會加在你實得的金額之上。';

  @override
  String get aboutLicenses => '開源授權';

  @override
  String get aboutCredits => '致謝';

  @override
  String get aboutCreditsBody =>
      '靈感來自 Steam Desktop Authenticator，並相容其 maFile 格式。以 Flutter、Riverpod、Dio、PointyCastle、mobile_scanner、image 等開源函式庫獨立打造。';

  @override
  String get actionLogin => '登入 / 更新登入狀態';

  @override
  String get actionConfirmations => '待處理';

  @override
  String get actionRemove => '移除帳號';

  @override
  String get actionImport => '匯入';

  @override
  String get actionAddAuthenticator => '新增驗證器';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOk => '確定';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonClose => '關閉';

  @override
  String get commonError => '錯誤';

  @override
  String get sessionExpired => '你的 Steam 登入狀態已過期，請重新登入。';

  @override
  String get removeConfirm => '要把這個帳號從這台裝置移除嗎？請先確認你已經備份好 maFile。';

  @override
  String get settingsPro => 'AVA Pro';

  @override
  String get proOpen => '查看 AVA Pro';

  @override
  String get proStatusFree => '免費方案';

  @override
  String proStatusPro(Object date) {
    return 'Pro · 有效至 $date';
  }

  @override
  String proStatusVip(Object date) {
    return 'VIP · 有效至 $date';
  }

  @override
  String get proStatusLifetime => 'Pro · 終身';

  @override
  String proStatusActivations(Object classes) {
    return '已啟用於：$classes';
  }

  @override
  String proStatusClassThisDevice(Object name) {
    return '$name（本機）';
  }

  @override
  String get proDeviceClassAndroid => 'Android';

  @override
  String get proDeviceClassWindows => 'Windows';

  @override
  String get proDeviceClassLinux => 'Linux';

  @override
  String get proDeviceClassMacos => 'macOS';

  @override
  String get paywallTitle => 'AVA Pro';

  @override
  String get paywallPerksTitle => 'Pro 權益——核心安全功能永遠免費。';

  @override
  String get paywallPerkSkins => '主題包：Neon 與 Pixel 皮膚';

  @override
  String get paywallPerkNoAds => '沒有橫幅廣告';

  @override
  String get paywallPerkFuture => '之後推出：雲端同步、交易通知';

  @override
  String get paywallPlayTitle => '透過 Google Play 解鎖';

  @override
  String get paywallSubscribe => '訂閱 · \$0.99/月';

  @override
  String get paywallWatchAd => '看廣告 · 3 天 VIP';

  @override
  String get paywallRestore => '還原購買';

  @override
  String get paywallCnTitle => '透過愛發電解鎖';

  @override
  String get paywallAfdianIntro => '在愛發電以每月 ¥5 贊助，然後在這裡輸入訂單編號解鎖。';

  @override
  String get paywallOpenAfdian => '開啟愛發電';

  @override
  String get paywallOrderHint => '愛發電訂單編號';

  @override
  String get paywallRedeem => '解鎖';

  @override
  String get paywallBetaTitle => 'Beta 回禮';

  @override
  String get paywallBetaIntro => 'Beta 測試者可獲得終身 Pro——請輸入你的兌換碼。';

  @override
  String get paywallBetaHint => '終身兌換碼';

  @override
  String get paywallBetaRedeem => '兌換';

  @override
  String get proResultSuccess => '已解鎖，謝謝你！';

  @override
  String get proErrCanceled => '已取消。';

  @override
  String get proErrNetwork => '網路錯誤——請稍後再試。';

  @override
  String get proErrNotConfigured => '這個版本還不支援。';

  @override
  String get proErrNoSubscription =>
      'Play 商店目前帳號名下沒有有效訂閱。如果是用另一個 Google 帳號訂的：在 Play 商店裡（右上角頭像）切換到那個帳號，再回來重試。';

  @override
  String get proErrAlreadyOwned => 'Play 商店目前帳號已持有該訂閱——點「還原購買」即可。';

  @override
  String get proErrOrderBound => '這筆訂單已經綁定到其他使用者。';

  @override
  String get proErrOrderNotFound => '找不到訂單，或方案不符。';

  @override
  String get proErrDeviceRevoked => '這台裝置的名額已被較新的啟用取代。';

  @override
  String get proErrNoVip => '獎勵還沒確認到帳——請一分鐘後再試。';

  @override
  String get proErrPurchaseBound =>
      '該訂閱綁定在另一個 Google 帳號上。請重試，並在帳號選擇器裡選 Play 商店正在使用的那個帳號。';

  @override
  String proErrPurchaseBoundKnown(String account) {
    return '該訂閱綁定在 $account。請重試，並在選擇器裡選這個帳號。';
  }

  @override
  String proErrGeneric(Object code) {
    return '失敗：$code';
  }

  @override
  String get proErrCodeInvalid => '無法辨識這組兌換碼——請檢查是否打錯。';

  @override
  String get proErrCodeRedeemed =>
      '這組兌換碼已經在另一台裝置上啟用。要移到這裡，請來信 hi@dotslash.pro。';

  @override
  String get proErrCodeActivationLimit =>
      '這組兌換碼最近換裝置太頻繁。請稍後再試，或來信 hi@dotslash.pro。';

  @override
  String get proErrRateLimited => '嘗試次數太多。請等一分鐘再試。';

  @override
  String proErrSlotOccupied(Object slots) {
    return '使用中：$slots';
  }

  @override
  String proSlotEntry(Object name, Object time) {
    return '$name（$time）';
  }

  @override
  String get proSlotToday => '今天';

  @override
  String proSlotDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 天前',
    );
    return '$_temp0';
  }

  @override
  String get proErrRevoked => '這項權益已經失效。如果你覺得這是錯誤，請來信 hi@dotslash.pro。';

  @override
  String get privacyOptions => '隱私選項';

  @override
  String get skinProNotice => 'Neon 與 Pixel 皮膚現在是 Pro 權益。你的選擇已保留，解鎖 Pro 後就會回來。';

  @override
  String get skinProNoticeDismiss => '知道了';

  @override
  String get syncTitle => '同步';

  @override
  String get syncSetupTitle => '設定同步';

  @override
  String get syncSettingsDesc => '透過你自己掌控的伺服器在多台裝置間同步帳號。所有資料離開這台裝置前都已加密。';

  @override
  String get syncSetUp => '設定同步…';

  @override
  String get syncStatusOk => '已是最新';

  @override
  String get syncStatusSyncing => '同步中…';

  @override
  String get syncStatusErrorShort => '上次同步失敗——點開查看詳情。';

  @override
  String syncStatusConflicts(int count) {
    return '$count 個衝突等你決定';
  }

  @override
  String syncLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get syncNever => '從未';

  @override
  String get syncBackendTitle => '資料要放在哪裡？';

  @override
  String get syncBackendWebdav => 'WebDAV';

  @override
  String get syncBackendWebdavDesc =>
      'Nextcloud、坚果云（Jianguoyun）、NAS——任何一個你掌控的 WebDAV 資料夾。';

  @override
  String get syncBackendGdrive => 'Google 雲端硬碟';

  @override
  String get syncBackendGdriveSoon => 'Pro · 之後推出';

  @override
  String get syncServerTitle => '伺服器';

  @override
  String get syncServerHint =>
      '坚果云需要「應用程式密碼」（安全选项 → 添加应用密码），不是登入密碼。Nextcloud 的資料夾 URL 格式類似 https://cloud.example.com/remote.php/dav/files/使用者名稱/ava/。';

  @override
  String get syncServerUrlLabel => 'WebDAV 資料夾 URL';

  @override
  String get syncServerFolderLabel => '資料夾（選填）';

  @override
  String get syncServerFolderHint => '留空則直接使用上面的 URL；填寫則放入該子資料夾，不存在會自動建立。';

  @override
  String get syncServerUserLabel => '使用者名稱';

  @override
  String get syncServerPasswordLabel => '密碼 / 應用程式密碼';

  @override
  String get syncTestConnection => '測試連線';

  @override
  String get syncErrUrl => '請輸入有效的 http(s) 資料夾 URL。';

  @override
  String get syncErrAuth => '伺服器拒絕了使用者名稱或密碼。';

  @override
  String syncErrNetwork(String detail) {
    return '無法連上伺服器：$detail';
  }

  @override
  String syncErrServer(String detail) {
    return '伺服器回應了錯誤：$detail';
  }

  @override
  String get syncErrTls => '伺服器憑證不受信任。';

  @override
  String get syncTlsTitle => '未知的伺服器憑證';

  @override
  String syncTlsBody(String fp) {
    return '系統不信任這個伺服器的憑證。如果這是你自己的伺服器（自簽憑證），請把下面的指紋和伺服器上顯示的逐字比對，完全一致才信任。\n\nSHA-256\n$fp';
  }

  @override
  String get syncTlsTrust => '信任這個憑證';

  @override
  String get syncHttpPrivateTitle => '未加密連線';

  @override
  String get syncHttpPrivateBody =>
      '這是內部網路上的明文 HTTP 位址。帳號資料本身是端對端加密的，但伺服器密碼會在你的網路上明文傳輸。';

  @override
  String get syncHttpPublicTitle => '跨網際網路的明文 HTTP';

  @override
  String get syncHttpPublicBody =>
      '這個位址在公開網路上，連線不會加密：你和伺服器之間的任何人都能讀到伺服器密碼並登入你的伺服器。帳號資料本身仍是加密的。請改用 HTTPS 或區域網路位址——確定接受這個風險才繼續。';

  @override
  String get syncHttpPublicHold => '長按仍要允許';

  @override
  String get syncContinue => '繼續';

  @override
  String get syncPassphraseNewTitle => '設定同步密語';

  @override
  String get syncPassphraseNewBody =>
      '所有資料上傳前都會用這組密語加密；密語本身絕不會離開你的裝置。\n\n密語一旦遺失，同步的資料任何人都救不回來——沒有重設這回事。至少 8 個字元；長度比符號更重要。';

  @override
  String get syncPassphraseExistingTitle => '輸入同步密語';

  @override
  String syncPassphraseExistingBody(int count) {
    return '這個資料夾已經有一個包含 $count 個帳號的同步庫。請輸入建立它時設定的密語。';
  }

  @override
  String get syncPassphraseLabel => '同步密語';

  @override
  String get syncPassphraseConfirmLabel => '確認密語';

  @override
  String get syncPassphraseTooShort => '至少 8 個字元。';

  @override
  String get syncPassphraseMismatch => '兩次輸入的密語不一致。';

  @override
  String get syncPassphraseWrong => '這組密語打不開這個同步庫。';

  @override
  String get syncPreviewTitle => '首次同步';

  @override
  String get syncPreviewEmpty => '目前沒有要傳輸的內容——之後帳號有變動就會自動同步。';

  @override
  String syncPreviewPull(int count) {
    return '下載到這台裝置：$count 個帳號';
  }

  @override
  String syncPreviewPush(int count) {
    return '從這台裝置上傳：$count 個帳號';
  }

  @override
  String syncPreviewConflict(int count) {
    return '兩邊內容不同：$count 個——連線後逐一選擇';
  }

  @override
  String get syncStart => '開始同步';

  @override
  String get syncDoneTitle => '同步已開啟';

  @override
  String get syncDoneBody =>
      '帳號現在會自動同步。新裝置上每個帳號第一次使用時要重新登入——存過密碼的會自己完成，其餘的會問一次。';

  @override
  String get syncDone => '完成';

  @override
  String get syncNeedsPassphrase => '儲存的密語和遠端同步庫已對不上——請重新輸入。';

  @override
  String get syncEnterPassphrase => '輸入密語';

  @override
  String get syncConditionalWarn =>
      '這台伺服器會忽略條件寫入，兩台裝置同時同步可能互相覆寫。同步仍可使用；請避免在兩台裝置上同時改動。';

  @override
  String get syncConflictsTitle => '衝突';

  @override
  String get syncConflictTrashNote => '被捨棄的那一邊會在同步垃圾桶保留 30 天。';

  @override
  String get syncConflictEditEdit => '兩台裝置都改過';

  @override
  String get syncConflictEditDelete => '這裡改過，另一台裝置已刪除';

  @override
  String get syncConflictDeleteEdit => '這裡已刪除，另一台裝置改過';

  @override
  String get syncConflictKeepLocal => '保留這台的版本';

  @override
  String get syncConflictKeepRemote => '保留對方的版本';

  @override
  String get syncConflictLocalSide => '這台裝置';

  @override
  String get syncConflictRemoteSide => '另一台裝置';

  @override
  String get syncDeleted => '已刪除';

  @override
  String get syncConflictHasPassword => '已存密碼';

  @override
  String get syncConflictNoPassword => '未存密碼';

  @override
  String get syncAutoTitle => '自動同步';

  @override
  String get syncAutoDesc => '啟動時和每次改動後同步。關閉後只有下面的按鈕會同步。';

  @override
  String get syncPasswordsTitle => '同步帳號密碼';

  @override
  String get syncPasswordsDesc => '有密碼，新裝置才能自行登入。變更這一項會重新上傳所有帳號。';

  @override
  String get syncAppSettingsTitle => '同步應用程式設定';

  @override
  String get syncAppSettingsDesc =>
      '同步外觀與行為偏好，以及加密儲存的 Steam 加速訂閱、節點和所選節點。語言、文字大小和加速自動啟動開關維持各裝置獨立。';

  @override
  String get syncNowButton => '立即同步';

  @override
  String get syncViewRemote => '檢視遠端同步庫';

  @override
  String get syncRemoteEmpty => '遠端同步庫是空的。';

  @override
  String get syncRemoteDevices => '裝置';

  @override
  String get syncTrashTitle => '同步垃圾桶';

  @override
  String get syncTrashEmpty => '空的。被同步刪除或取代的帳號會在這裡保留 30 天。';

  @override
  String get syncTrashRestore => '還原';

  @override
  String get syncTrashRestored => '帳號已還原。';

  @override
  String get syncTrashRestoreFailed => '目前的密語解不開這筆資料。';

  @override
  String get syncTrashReasonRemoteDelete => '被另一台裝置刪除';

  @override
  String get syncTrashReasonConflict => '在衝突中被取代';

  @override
  String get syncChangePassphrase => '變更同步密語';

  @override
  String get syncPassphraseChanged => '密語已變更，資料已全部重新加密。其他裝置會要求輸入新密語。';

  @override
  String syncPassphraseChangeFailed(String reason) {
    return '密語未變更：$reason';
  }

  @override
  String get syncDisconnect => '中斷同步';

  @override
  String get syncDisconnectBody =>
      '這台裝置會停止同步。遠端同步庫可以留給你的其他裝置繼續用——也可以從伺服器上整個刪除。';

  @override
  String get syncDisconnectKeep => '保留遠端資料';

  @override
  String get syncDisconnectDeleteHold => '長按刪除遠端資料';

  @override
  String get netErrTls =>
      '無法與 Steam 建立安全連線。連線在 TLS 交握階段被切斷，通常是網路對它做了攔截，或者網路本身不穩定。換一個網路（或使用代理）後重試。';

  @override
  String get netErrUnreachable => '連不上 Steam。檢查網路連線後重試。';

  @override
  String get netErrTimeout => 'Steam 沒有在規定時間內回應。網路可能很慢，或者被攔截了。';

  @override
  String get netErrCert =>
      'Steam 的憑證未通過驗證，GooeSteamKit 已中斷這次連線。目前網路裡可能有東西在監聽流量。';

  @override
  String netErrServer(int code) {
    return 'Steam 回傳了一個錯誤（$code）。這通常是暫時的，稍後再試。';
  }

  @override
  String exportSaved(String path) {
    return '已儲存到 $path';
  }

  @override
  String get accountSearchHint => '搜尋帳號';

  @override
  String get accountSearchEmpty => '沒有符合的帳號';

  @override
  String get accountSearchClear => '清除搜尋';

  @override
  String get portableMode => '可攜模式';

  @override
  String get portableEnable => '開啟可攜模式';

  @override
  String get portableDisable => '關閉可攜模式';

  @override
  String get portableOnHelp => '新帳號儲存至程式旁的 maFiles。同時讀取兩個庫，同帳號優先使用可攜庫。';

  @override
  String get portableOffHelp => '新帳號儲存至 AppData。同時讀取兩個已解鎖的庫，同帳號優先使用本機庫。';

  @override
  String get portableCopyToUsb => '是否同時將現有本機帳號複製到程式旁的 maFiles？';

  @override
  String get portableCopyToLocal => '是否同時將可攜帳號複製回 AppData？';

  @override
  String get portableCopyHelp =>
      '複製後會驗證，原庫保留作備份。目標庫已有的帳號會略過，不覆寫。可攜帳號不參與本機的 WebDAV 同步。';

  @override
  String get portableNoCopy => '僅切換';

  @override
  String get portableCopy => '複製並切換';

  @override
  String get portableSetPassword => '設定可攜密碼';

  @override
  String get portableUnlock => '解鎖 maFiles';

  @override
  String get portablePasswordHelp => '請使用至少 12 個字元的獨立密碼並妥善保管。換電腦仍需此密碼，無法重設。';

  @override
  String get portableUnlockHelp => '請輸入此帳號庫的密碼。若為 SDA 加密資料夾，請使用原 SDA 密碼。';

  @override
  String get portableConfirmPassword => '確認密碼';

  @override
  String get portablePasswordMismatch => '兩次密碼不一致。';

  @override
  String get portableWrongPassword => '密碼錯誤，或此帳號庫無法解鎖。';

  @override
  String get portableFailed => '操作未完成，原帳號庫已保留。';

  @override
  String get portableDone => '模式已更新，原帳號已保留。';

  @override
  String get portableSkipped => '略過已有帳號';

  @override
  String get portableUnreadable =>
      '帳號庫損毀，或仍依賴原 Windows 的金鑰。請從匯出的 maFile 還原，來源檔案未變更。';

  @override
  String get friendsTitle => '好友與交易';

  @override
  String get friendsSearch => '搜尋名稱或 SteamID';

  @override
  String get friendsEmpty => '沒有可顯示的好友';

  @override
  String get friendsProfile => '檢視 Steam 個人檔案';

  @override
  String get friendsTrade => '建立交易報價';

  @override
  String get friendsOnline => '線上';

  @override
  String get friendsOffline => '離線';

  @override
  String get friendsPlaying => '遊戲中';

  @override
  String get tradeNewTitle => '新的交易報價';

  @override
  String get tradeYourItems => '你送出的物品';

  @override
  String get tradeTheirItems => '你收到的物品';

  @override
  String get tradeSelectItems => '選擇物品';

  @override
  String get tradeNote => '留言（選填）';

  @override
  String get tradeReview => '核對報價';

  @override
  String get tradeSend => '傳送報價';

  @override
  String get tradeReviewBody =>
      '請核對交易對象的 SteamID、雙方物品與數量。Steam 可能要求進行確認，或暫掛物品。';

  @override
  String get tradeGiftWarning => '你將送出這些物品，且不會收到任何物品。';

  @override
  String get tradeNoItems => '此處沒有可交易的物品。';

  @override
  String get tradeMore => '載入更多';

  @override
  String get tradeSent => '報價已傳送。';

  @override
  String get tradeNeedsMobile => '報價已建立。請至「待處理」完成行動驗證。';

  @override
  String get tradeNeedsEmail => '報價已建立。請依 Steam 寄出的電子郵件進行確認。';

  @override
  String get tradeOpenPending => '檢視待處理事項與報價';

  @override
  String get tradeUnknownResult => '無法確定報價是否已傳送。請先檢查已傳送的報價，再決定是否重試，以免重複傳送。';

  @override
  String get tradeChooseGame => '選擇物品庫';

  @override
  String get tradeQuantity => '數量';

  @override
  String get tradeLoadFailed => '無法讀取 Steam 好友或物品庫。請重新整理後再試。';

  @override
  String get tradeSendFailed => 'Steam 未確認報價是否已傳送。請先檢查你的報價，再決定是否重試。';

  @override
  String get marketListingActive => '出售中';

  @override
  String get marketListingOnHold => '暫掛中';

  @override
  String get marketListingPending => '等待確認';

  @override
  String get marketListingInactive => '未生效';

  @override
  String marketHoldUntil(String date) {
    return '暫掛至 $date';
  }

  @override
  String get marketListingsAll => '全部';

  @override
  String get marketCancelConfirm => '要取消這筆市場上架嗎？';

  @override
  String get settingsStartupVerification => '啟動時驗證身分';

  @override
  String get settingsStartupVerificationDesc =>
      '開啟時需輸入 GooeSteamKit PIN 或使用系統驗證。關閉後，任何能使用此裝置的人都可開啟 GooeSteamKit；帳戶檔案仍加密儲存在本機。';

  @override
  String get settingsStartupVerificationError => '無法儲存啟動驗證設定，請檢查系統安全儲存空間後重試。';

  @override
  String get settingsLockNow => '立即鎖定';

  @override
  String get settingsStartupVerificationPinChanged => '變更 PIN 後會重新開啟啟動驗證。';

  @override
  String get settingsStartupVerificationDisable => '要關閉啟動驗證嗎？';

  @override
  String get dashboardTitle => '帳戶總覽';

  @override
  String get dashboardWallet => '錢包餘額';

  @override
  String get dashboardPendingBalance => '待入帳餘額';

  @override
  String get dashboardUnavailable => '無法取得';

  @override
  String get dashboardMarket => '物品庫與市場';

  @override
  String get dashboardTools => '帳戶工具';

  @override
  String get dashboardCustomize => '選擇總覽卡片';

  @override
  String get dashboardViewAll => '檢視全部';

  @override
  String get dashboardNoListings => '沒有市場上架物品。';

  @override
  String get dashboardFetchFailed => '無法載入此資訊。請重新整理後再試。';

  @override
  String get dashboardSaveFailed => '無法儲存顯示偏好設定。';

  @override
  String get backupCodesTitle => '備用登入碼';

  @override
  String get backupCodesAccountCheck =>
      '瀏覽器可能登入了另一個 Steam 帳戶。產生備用碼前，請確認瀏覽器中的帳戶名稱與上方相同。';

  @override
  String get backupCodesHow => '向 Steam 取得備用碼';

  @override
  String get backupCodesSteps =>
      '1. 使用下方按鈕開啟 Steam Guard 設定。\n2. 登入上方顯示的帳戶。\n3. 選擇「取得備用 Steam Guard 驗證碼」。\n4. 完成 Steam 要求的驗證，並妥善保管產生的備用碼。';

  @override
  String get backupCodesExplanation =>
      '這些是一次性登入碼，與移除驗證器用的救援碼不同，由 Steam 發放及管理。GooeSteamKit 會開啟官方流程，不會產生或儲存這些備用碼。';

  @override
  String get backupCodesOpenSteam => '開啟 Steam 取得備用碼';

  @override
  String get backupCodesCopyLink => '複製官方連結';

  @override
  String get backupCodesOpenFailed => '無法開啟瀏覽器。請複製連結後手動開啟。';

  @override
  String get loginAccountMismatch => '登入的是其他 Steam 帳戶。請使用目前帳戶完成驗證，原帳戶未被修改。';

  @override
  String get tradeFromAccount => '發起帳戶';

  @override
  String get tradeToAccount => '交易對象';

  @override
  String get tradeValidationFailed => '報價尚未送出。請檢查所選物品和數量；每方最多選擇 256 項。';

  @override
  String get friendsProfileOpenFailed => '無法開啟瀏覽器，可複製下方 Steam 官方連結。';

  @override
  String get steamSwitchQrTitle => '用 GooeSteamKit 帳號掃碼登入';

  @override
  String get steamSwitchQrHelp =>
      '選擇 GooeSteamKit 帳號，在 Steam 顯示登入 QR 碼，再掃碼並確認登入請求。';

  @override
  String get steamSwitchQrAccount => 'GooeSteamKit 帳號';

  @override
  String get steamSwitchQrNeedsSession =>
      '請先在 GooeSteamKit 中重新登入此帳號。僅有離線驗證碼無法核准 QR 碼登入。';

  @override
  String get steamSwitchQrNoAccounts => '請先向 GooeSteamKit 新增帳號，再使用掃碼登入。';

  @override
  String get approveScreenSelect => '框選螢幕上的 QR 碼';

  @override
  String get approveScreenHelp =>
      '點擊後 GooeSteamKit 會暫時隱藏。拖曳框選 Steam 登入 QR 碼，再核對帳號與登入裝置並確認。';

  @override
  String get approveScreenInstruction => '拖曳框選一個 Steam 登入 QR 碼 · Esc / 右鍵取消';

  @override
  String get approveScreenNoCode => '未辨識到 QR 碼。請框選完整 QR 碼，保留少許周圍空白後重試。';

  @override
  String get approveScreenFailed => '無法擷取螢幕，請重試或貼上 QR 碼連結。';

  @override
  String get approveSessionUnavailable =>
      '此 QR 碼已過期或無法核實登入資訊，請在 Steam 重新整理 QR 碼後重試。';

  @override
  String get itemMarketActions => '物品市集選項';

  @override
  String get itemMarketViewPrice => '查看市集價格';

  @override
  String get itemMarketOpen => '在 Steam 市集查看';

  @override
  String get itemMarketVolume => '近期成交量';

  @override
  String get itemMarketReferenceNote => 'Steam 市集單件參考價，非出售實收；價格會變動。';

  @override
  String itemMarketCurrency(String currency) {
    return '幣別：$currency';
  }

  @override
  String get itemMarketNoIdentity => '此物品沒有可用於查價的市集名稱。';

  @override
  String get itemMarketOpenFailed => '無法開啟 Steam 市集頁面。';

  @override
  String get steamClientRunning => 'Steam 已啟動';

  @override
  String get steamClientStopped => 'Steam 未啟動';

  @override
  String get steamClientStatusLoading => '正在讀取 Steam 狀態…';

  @override
  String get steamClientStatusUnavailable => '暫時無法讀取 Steam 狀態';

  @override
  String steamClientCurrentAccount(String account) {
    return '目前登入：$account';
  }

  @override
  String get steamClientAccountUnknown => '尚未辨識目前登入帳戶';

  @override
  String get steamClientCurrentBadge => '目前登入';

  @override
  String get forkLocalFeaturesTitle => '本機功能已開放';

  @override
  String get forkLocalFeaturesBody =>
      '此獨立分支無需 Pro 驗證即可使用全部本機功能。不包含原作者的線上服務與訂閱。';

  @override
  String get forkPrivacyConsentBody =>
      '此 AVA 獨立分支將 Steam 帳戶與驗證器密鑰保存在本裝置上，Steam 請求直接連線至 Valve。選用同步只有在你設定自己的伺服器後才啟用，帳戶資料在本機加密後再同步。本機功能無需 Pro 驗證；此版本不使用廣告、付款服務或原版更新檢查。意見回饋只開啟本分支的 GitHub Issues，不會自動傳送報告或記錄。沒有追蹤或統計。請閱讀下方本分支的隱私說明，繼續即表示接受。';

  @override
  String get forkUpdateTitle => '軟體更新';

  @override
  String forkUpdateCurrentVersion(String version) {
    return '目前版本 $version';
  }

  @override
  String get forkUpdateCheck => '檢查更新';

  @override
  String get forkUpdateChecking => '正在檢查更新…';

  @override
  String get forkUpdateNoRelease => '暫時沒有可用的發布版本';

  @override
  String get forkUpdateUpToDate => '目前已是最新版本';

  @override
  String forkUpdateAvailable(String version) {
    return '發現新版本 $version';
  }

  @override
  String get forkUpdateReleaseNotes => '更新說明';

  @override
  String get forkUpdateNoNotes => '此版本沒有附上更新說明';

  @override
  String get forkUpdateDownload => '下載更新';

  @override
  String forkUpdateDownloading(String progress) {
    return '正在下載 $progress';
  }

  @override
  String get forkUpdateCancelDownload => '取消下載';

  @override
  String get forkUpdateReady => '安裝檔已下載並通過驗證';

  @override
  String get forkUpdateInstall => '安裝更新';

  @override
  String get forkUpdateInstallTitle => '安裝此更新？';

  @override
  String get forkUpdateInstallAndroid =>
      '將開啟系統安裝畫面。若出現提示，請允許 GooeSteamKit 安裝應用程式，再依系統指示完成更新。';

  @override
  String get forkUpdateInstallWindows =>
      '確認後將啟動安裝程式並關閉 GooeSteamKit。請先完成目前操作，再依安裝程式指示更新。';

  @override
  String get forkUpdateInstallConfirm => '繼續安裝';

  @override
  String get forkUpdateInstallStarted => '已開啟系統安裝程式，請依指示完成更新';

  @override
  String get forkUpdateCheckFailed => '無法檢查更新，請稍後再試';

  @override
  String get forkUpdateDownloadFailed => '下載失敗，請重試';

  @override
  String get forkUpdateHashFailed => '安裝檔驗證失敗，已阻止安裝，請重新下載';

  @override
  String get forkUpdateInstallFailed => '無法啟動安裝程式，請重試';

  @override
  String get forkUpdateNoCompatibleAsset => '此版本沒有適用於本裝置的安裝檔';

  @override
  String get forkUpdateUnverifiable => '此安裝檔缺少可信的校驗資訊，無法下載或安裝';

  @override
  String get forkUpdateInvalidMetadata => '發布資訊不完整或無效，請稍後再試';

  @override
  String get forkUpdateUnsupported => '此裝置暫不支援應用程式內更新';

  @override
  String get forkUpdateCancelled => '已取消下載';

  @override
  String get forkUpdatePermissionRequired => '請先允許 GooeSteamKit 安裝應用程式，再返回此頁安裝';

  @override
  String get forkUpdateOpenPermissionSettings => '允許安裝應用程式';

  @override
  String get forkUpdateWrongPackage => '安裝檔不屬於此應用程式，已阻止安裝';

  @override
  String get forkUpdateSignatureMismatch => '安裝檔簽章與目前應用程式不符，已阻止安裝';

  @override
  String get backupCodesNativeIntro =>
      '在這裡產生 Steam 一次性備用登入碼。Steam 需要驗證此帳戶綁定手機號碼收到的簡訊。產生新的一組可能取代原有備用碼。';

  @override
  String get backupCodesSendSms => '傳送驗證簡訊';

  @override
  String get backupCodesSmsPrompt => '輸入 Steam 簡訊中的驗證碼。';

  @override
  String get backupCodesSmsLabel => '簡訊驗證碼';

  @override
  String get backupCodesGenerate => '驗證並產生備用碼';

  @override
  String get backupCodesReady => '你的一次性備用登入碼';

  @override
  String get backupCodesKeepSafe =>
      '每個備用碼只能使用一次。請列印並妥善保存。GooeSteamKit 不會儲存這些碼；離開此頁或切換應用程式後會清除顯示。產生或使用備用碼時，Steam 會寄送電子郵件通知。';

  @override
  String get backupCodesClear => '清除備用碼';

  @override
  String get backupCodesRequestFailed => 'Steam 未能完成請求。程式沒有自動重試。請檢查網路後手動重試。';

  @override
  String get backupCodesUnexpectedResponse =>
      'Steam 傳回了無法識別的回應，無法確認結果；程式沒有重試請求。';

  @override
  String get backupCodesInvalidSms => 'Steam 未接受驗證碼，請核對簡訊後重試。';

  @override
  String get backupCodesRateLimited => 'Steam 限制了請求次數，請稍後再試。';

  @override
  String get backupCodesPhoneRequired => 'Steam 要求此帳戶已綁定並驗證手機號碼。';

  @override
  String get backupCodesManualHelp => 'Steam 官方網頁（備用方式）';

  @override
  String get steamAccelerationTitle => 'Steam 加速';

  @override
  String get steamAccelerationDesc =>
      '優先使用外部代理，外部關閉後接續內建加速。內建線路僅用於 GooeSteamKit 的 Steam 存取。';

  @override
  String get steamAccelerationOff => '未啟用';

  @override
  String get steamAccelerationLoading => '正在同步訂閱…';

  @override
  String get steamAccelerationStarting => '正在啟動…';

  @override
  String get steamAccelerationRunning => '執行中';

  @override
  String get steamAccelerationPaused => '內建加速待命';

  @override
  String get steamAccelerationFailed => '加速無法使用';

  @override
  String get steamAccelerationUnsupported => '目前僅支援 Windows 和 Android。';

  @override
  String get steamAccelerationConfigured => '訂閱已儲存在此裝置';

  @override
  String get steamAccelerationUnconfigured => '尚未設定訂閱';

  @override
  String get steamAccelerationConfigure => '新增訂閱';

  @override
  String get steamAccelerationReplace => '更換訂閱';

  @override
  String get steamAccelerationSubscription => '訂閱網址';

  @override
  String get steamAccelerationSubscriptionHelp =>
      '連結可能含有私人憑證，會安全儲存在裝置上。開啟「同步應用程式設定」後，訂閱與節點也會使用同步密碼加密同步。儲存後點選「更新節點」載入節點。';

  @override
  String get steamAccelerationClear => '清除訂閱';

  @override
  String get steamAccelerationClearConfirm =>
      '停止內建加速並刪除已儲存的訂閱和節點？開啟設定同步時，這項刪除也會同步到其他裝置。';

  @override
  String get steamAccelerationSync => '更新節點';

  @override
  String get steamAccelerationDownloadingCore => '正在下載加速元件…';

  @override
  String get steamAccelerationCoreDownload => '加速元件下載失敗，已嘗試鏡像與官方來源，請稍後再試。';

  @override
  String get steamAccelerationExternalActiveHelp =>
      '目前使用外部連線。開啟自動切換後，外部關閉時會接上內建線路，無需手動切換。';

  @override
  String get steamAccelerationNodes => '節點';

  @override
  String get steamAccelerationNoNodes => '請同步訂閱以取得可用節點。';

  @override
  String get steamAccelerationNode => '使用節點';

  @override
  String get steamAccelerationStart => '開啟自動切換';

  @override
  String get steamAccelerationStop => '暫停自動切換';

  @override
  String get steamAccelerationAuto => '啟動時自動開啟';

  @override
  String get steamAccelerationAutoDesc =>
      '優先使用外部代理或 VPN，關閉後恢復內建線路。手動暫停僅在本次執行期間生效。';

  @override
  String get steamAccelerationEnvironment => '外部代理偵測';

  @override
  String get steamAccelerationExternalProxy => '偵測到系統代理或 PAC';

  @override
  String get steamAccelerationExternalVpn => '偵測到 VPN 或通道';

  @override
  String get steamAccelerationNoExternal => '未偵測到外部代理';

  @override
  String get steamAccelerationDetectionUnavailable =>
      '無法確認外部代理，內建線路暫不啟動。請檢查系統代理設定後重新偵測。';

  @override
  String get steamAccelerationEnvironmentHelp =>
      '應用程式可見時自動檢查本機連線設定，不修改系統代理或 VPN。';

  @override
  String steamAccelerationSkipped(int count) {
    return '已略過 $count 個不支援的節點。';
  }

  @override
  String get steamAccelerationInvalidSubscription =>
      '請輸入有效的 HTTP 或 HTTPS 訂閱網址。';

  @override
  String get steamAccelerationNetworkError => '無法取得訂閱，請檢查網路後重試。';

  @override
  String get steamAccelerationUnsupportedSubscription =>
      '訂閱中沒有支援的節點，請使用相容的 Clash 訂閱。';

  @override
  String get steamAccelerationStorageError => '系統安全儲存空間無法使用，無法儲存設定。';

  @override
  String get steamAccelerationCoreUnavailable => '缺少加速元件，請安裝更新的應用程式套件。';

  @override
  String get steamAccelerationCoreIntegrity => '加速元件驗證失敗，已阻止啟動。';

  @override
  String get steamAccelerationStartFailed => '無法啟動加速，請重新整理環境偵測後再試。';

  @override
  String get inventorySearch => '搜尋物品';

  @override
  String get inventoryFilterType => '類型';

  @override
  String get inventoryFilterRarity => '品質';

  @override
  String get inventoryFilterOther => '其他／未分類';

  @override
  String get inventoryFilterNoMatches => '沒有符合篩選條件的物品';

  @override
  String get inventoryFilterLoaded => '篩選目前已載入的物品；載入更多後會包含其餘物品。';

  @override
  String get steamConnectionTitle => '連線檢查';

  @override
  String get steamConnectionNotChecked => '尚未檢查連線';

  @override
  String get steamConnectionChecking => '正在檢查連線…';

  @override
  String get steamConnectionAvailable => '連線可用';

  @override
  String get steamConnectionPartial => '部分 Steam 服務無法連線';

  @override
  String get steamConnectionUnavailable => '無法連線 Steam';

  @override
  String get steamConnectionCheck => '檢查連線';

  @override
  String get steamConnectionApi => 'Steam 登入介面';

  @override
  String get steamConnectionCommunity => 'Steam 社群與市集';

  @override
  String get steamConnectionReachable => '可連線';

  @override
  String get steamConnectionFailed => '連線失敗';

  @override
  String get steamConnectionInternal => '內建線路';

  @override
  String get steamConnectionExternal => '外部 HTTP 代理';

  @override
  String get steamConnectionSystem => '外部 VPN／通道';

  @override
  String get steamConnectionDirect => '直接連線';

  @override
  String steamConnectionCheckedAt(String time) {
    return '上次檢查：$time';
  }

  @override
  String get steamConnectionNoVpnIcon =>
      '僅代理 GooeSteamKit 內部的 Steam 請求，因此 Android 不顯示系統 VPN 圖示；Steam 用戶端和其他應用程式不會被加速。';

  @override
  String get steamConnectionScope =>
      '透過 GooeSteamKit 目前線路檢查 Steam 介面和社群，不傳送帳戶憑證。結果僅代表本次檢查，不會持續偵測。';

  @override
  String tradeSendNotSent(String reason) {
    return '報價未送出。$reason';
  }

  @override
  String get tradeCheckSendResult => '核對傳送結果';

  @override
  String get tradeSendNotFound =>
      '暫未查到對應的新報價，Steam 可能尚未更新。請先檢查待確認與已傳送報價，避免重複傳送。';

  @override
  String tradeSendCheckFailed(String reason) {
    return '暫時無法核對傳送結果。$reason';
  }

  @override
  String get tradeSendRejected => 'Steam 拒絕了這筆報價，但未提供詳細原因。請檢查所選物品與交易限制。';

  @override
  String get tradeSendUnreadableResponse => 'Steam 未傳回完整的傳送回執。';

  @override
  String get steamConnectionPacHelp =>
      '偵測到系統代理設定，但沒有可用的 HTTP 連接埠或 VPN 線路。本程式不解析 PAC 指令碼，請開啟外部代理的 HTTP 代理或 VPN 模式。';

  @override
  String forkUpdateTransferSize(String received, String total) {
    return '$received / $total MiB';
  }

  @override
  String forkUpdateTransferSpeed(String speed, String unit) {
    return '$speed $unit/秒';
  }

  @override
  String forkUpdateRemainingSeconds(int seconds) {
    return '預計還需 $seconds 秒';
  }

  @override
  String forkUpdateRemainingMinutes(int minutes) {
    return '預計還需 $minutes 分鐘';
  }

  @override
  String get forkUpdateWaitingForData => '等待資料…';

  @override
  String get forkUpdateVerifying => '正在驗證安裝套件…';

  @override
  String get forkUpdateConnectionHint =>
      '自動模式透過 GH-Proxy 直接下載，無需開啟代理；失敗時切回 GitHub。安裝檔一律依 GitHub 的 SHA-256 驗證。';

  @override
  String get forkUpdateSourceLabel => '下載來源';

  @override
  String get forkUpdateSourceAutomatic => '自動加速（建議）';

  @override
  String get forkUpdateSourceOfficial => 'GitHub 官方';

  @override
  String forkUpdateSourceAccelerated(String provider) {
    return '加速來源直連 · $provider';
  }

  @override
  String get marketTabSearch => '市場';

  @override
  String get marketSearchHint => '搜尋商品名稱，例如 AK-47';

  @override
  String get marketSearchEmpty => '選擇遊戲和幣別，輸入商品名稱後搜尋。僅在搜尋時載入。';

  @override
  String get marketSearchButton => '搜尋市場';

  @override
  String get marketSearchAllGames => '全部遊戲';

  @override
  String get marketSearchGame => '遊戲';

  @override
  String get marketSearchCurrency => '幣別';

  @override
  String get marketSearchNoResults => '找不到相關商品，請嘗試其他關鍵字。';

  @override
  String get marketSearchMore => '載入更多';

  @override
  String marketSearchListings(int count) {
    return '上架數量：$count';
  }

  @override
  String get marketSearchPriceUnavailable => '暫無價格';

  @override
  String get marketSearchPriceNote => '僅為畫面中可見的商品依所選幣別載入參考價格；價格可能變動。';

  @override
  String get marketSearchRefreshPrice => '更新價格';

  @override
  String get marketSearchRateLimited => 'Steam 請求過多，請稍後再試。';

  @override
  String get marketSearchUnavailable => '暫時無法取得市場商品，請稍後再試。';

  @override
  String marketSearchRequestedCurrency(String currency) {
    return '要求幣別：$currency';
  }

  @override
  String get steamConnectionUnresolvedProxy => '系統代理無法使用';

  @override
  String get steamDesktopLoginButton => '開啟 Steam 並登入';

  @override
  String get steamDesktopLoginHelp =>
      '使用所選帳號開啟或切換 Steam，並自動核准本次本機登入視窗的 QR 碼。請先退出正在執行的遊戲。';

  @override
  String get steamDesktopLoginPreparing => '正在準備所選帳號…';

  @override
  String get steamDesktopLoginWaitingQr => '正在等待本機 Steam 登入 QR 碼…';

  @override
  String get steamDesktopLoginApproving => '正在核准本機登入…';

  @override
  String get steamDesktopLoginWaitingAccount => '正在確認 Steam 登入狀態…';

  @override
  String get steamDesktopLoginComplete => '已核驗 Steam 用戶端目前帳號為所選帳號。';

  @override
  String get steamDesktopLoginManual => 'Steam 已開啟，但未能確認本機登入 QR 碼。可使用下方掃碼入口繼續。';

  @override
  String get steamDesktopLoginUnconfirmed =>
      '已提交登入核准請求，但尚未確認 Steam 已登入。請查看 Steam 視窗後重新整理狀態。';

  @override
  String get steamDesktopLoginCancelled => '已停止自動登入';

  @override
  String get steamDesktopLoginCancel => '停止自動核准';

  @override
  String get steamDesktopLoginWrongAccount => 'Steam 目前登入了其他帳號，已停止自動核准。';

  @override
  String get steamClientOpen => '開啟 Steam';

  @override
  String get steamSwitchLaunchFailed => 'Steam 無法啟動。請檢查安裝路徑，並確認 Steam 可以正常執行。';

  @override
  String get steamSwitchFileAccessFailed => '無法備份或修改 Steam 設定，請檢查安裝目錄的讀寫權限。';

  @override
  String get steamDesktopLoginSession => 'Steam 已開啟，正在連線至所選帳號…';

  @override
  String get steamSwitchInspecting => '檢查本機 Steam';

  @override
  String steamSwitchErrorDetails(
    String stage,
    String code,
    String systemError,
  ) {
    return '階段：$stage；錯誤碼：$code；Windows：$systemError。';
  }

  @override
  String get approveScreenBusy => '另一項螢幕擷取正在進行，請先完成或取消。';

  @override
  String get approveScreenDisplayChanged => '螢幕配置已變更，請重新框選。';

  @override
  String get approveScreenRegionTooLarge => '框選範圍過大，請只選取 QR 碼區域。';

  @override
  String approveScreenFailedDetail(String detail) {
    return '無法擷取螢幕，請重試。錯誤資訊：$detail。';
  }

  @override
  String get marketFavoriteTitle => '收藏';

  @override
  String get marketFavoriteAdd => '收藏商品';

  @override
  String get marketFavoriteRemove => '取消收藏';

  @override
  String get marketFavoriteEmpty => '在市場搜尋結果中收藏商品，下次可在這裡直接查看價格。';

  @override
  String get marketFavoriteSaveFailed => '無法讀取或儲存市場收藏，請重試。';

  @override
  String get syncCompareTitle => '比較本機與遠端';

  @override
  String get syncCompareRefresh => '重新整理比較';

  @override
  String get syncCompareHelp =>
      '先查看每項差異，再選擇方向。「較新」根據上次共同版本後的改動判斷；下方時間為最近同步時間，僅供參考。拉取或上傳只處理選中的這一項。';

  @override
  String get syncCompareStale => '本機或遠端內容已發生變化，請重新整理比較後再試。';

  @override
  String get syncCompareFailed => '比較或傳輸失敗，請檢查連線與同步密碼後重新整理；尚未確認傳輸成功。';

  @override
  String get syncCompareSame => '內容一致';

  @override
  String get syncCompareLocalOnly => '僅本機有';

  @override
  String get syncCompareRemoteOnly => '僅遠端有';

  @override
  String get syncCompareLocalNewer => '本機有較新改動';

  @override
  String get syncCompareRemoteNewer => '遠端有較新改動';

  @override
  String get syncCompareBothChanged => '兩端內容不同，請選擇保留哪一端';

  @override
  String get syncCompareRemoteDeleted => '遠端已刪除；上傳將還原此帳戶';

  @override
  String get syncCompareSettings => '設定、市集收藏與加速訂閱';

  @override
  String get syncCompareSettingsConflict => '兩端設定均有改動，請先比較再選擇上傳或拉取。';

  @override
  String get syncComparePull => '拉取遠端 → 本機';

  @override
  String get syncCompareUpload => '上傳本機 → 遠端';

  @override
  String get syncCompareHidden => '敏感內容不同（已隱藏）';

  @override
  String get syncCompareCurrency => '市集幣別';

  @override
  String get syncCompareFavorites => '市集收藏';

  @override
  String get syncCompareSubscription => '加速訂閱網址';

  @override
  String get syncCompareNodes => '加速節點設定';

  @override
  String get syncCompareSelectedNode => '選取的加速節點';

  @override
  String get marketFavoriteSearch => '搜尋';

  @override
  String get inventoryCooldownDetails => '交易與市場限制';

  @override
  String inventoryCooldownUntil(String time) {
    return '冷卻至 $time';
  }

  @override
  String get inventoryCooldownTradable => '可交易';

  @override
  String get inventoryCooldownNotTradable => '不可交易';

  @override
  String get inventoryCooldownMarketable => '可上架';

  @override
  String get inventoryCooldownLocalTime => '時間已轉換為本機時區。';

  @override
  String get inventoryCooldownUnknown => 'Steam 未提供可識別的解鎖時間，不估算日期。';

  @override
  String get inventoryCooldownElapsed => '該日期已到，請重新整理庫存，以 Steam 傳回的最新限制狀態為準。';

  @override
  String inventoryCooldownRemaining(int days, int hours, int minutes) {
    return '剩餘：$days 天 $hours 小時 $minutes 分鐘';
  }
}
