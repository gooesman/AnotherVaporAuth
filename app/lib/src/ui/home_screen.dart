import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../l10n/app_localizations.dart';
import '../app/account_name_mode.dart';
import '../app/providers.dart';
import '../app/steam_notifications_provider.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/steam_totp.dart';
import '../services/steam_time.dart';
import 'widgets/animated_steam_image.dart';
import 'widgets/account_identity_menu.dart';
import 'widgets/app_logo.dart';
import 'widgets/countdown_ring.dart';
import 'widgets/flip_code.dart';
import 'widgets/hold_button.dart';
import 'widgets/motion.dart';
import '../skins/skin_engine.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/update_banner.dart';
import 'widgets/steam_image_provider.dart';
import 'widgets/steam_acceleration_status.dart';
import 'widgets/steam_notifications_button.dart';
import 'widgets/pending_confirmation_badge.dart';
import 'notifications/notifications_screen.dart';
import 'approve_login_screen.dart';
import 'account_dashboard.dart';
import 'backup_codes_screen.dart';
import 'friends/friends_screen.dart';
import 'steam_client_screen.dart';
import 'pending/pending_screen.dart';
import 'import_helper.dart';
import 'pending_login.dart';
import 'device_sessions_screen.dart';
import 'family_group_screen.dart';
import 'login_screen.dart';
import 'market/market_screen.dart';
import 'redeem_key_screen.dart';
import 'settings_screen.dart';
import 'portable_mode_card.dart';
import 'tutorial.dart';

const _palette = [
  Color(0xFF00F0FF),
  Color(0xFFFF2BD6),
  Color(0xFF36F0A0),
  Color(0xFFFFD23B),
  Color(0xFFFF8A3D),
  Color(0xFF43C8FF),
];

String _initial(SteamGuardAccount a) {
  final n = (a.accountName ?? '').trim();
  return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
}

Color _avatarColor(SteamGuardAccount a) =>
    _palette[a.steamId.hashCode.abs() % _palette.length];

bool _hasInlineDashboard(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform != TargetPlatform.android &&
      platform != TargetPlatform.iOS &&
      MediaQuery.sizeOf(context).width >= 640;
}

String _codeFor(SteamGuardAccount a, int tick) {
  try {
    return a.generateCode(tick);
  } catch (_) {
    return '—————';
  }
}

/// The 30-second token and 1-second countdown have separate subscriptions.
/// Keeping the clock at these leaves avoids rebuilding avatars, swipe panes,
/// the account list and the desktop dashboard on every second.
class _AccountCode extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final Widget Function(BuildContext context, String code) builder;

  const _AccountCode({required this.account, required this.builder});

  @override
  ConsumerState<_AccountCode> createState() => _AccountCodeState();
}

class _AccountCodeState extends ConsumerState<_AccountCode> {
  int? _window;
  String? _secret;
  String? _code;

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(
      tickProvider.select(
        (tick) => (tick.value ?? SteamTime.currentSteamTime) ~/ 30,
      ),
    );
    // Accounts are mutable. Include the current secret in the cache key so
    // replacing/re-enrolling an account within the same window is immediate.
    if (_window != window ||
        _secret != widget.account.sharedSecret ||
        _code == null) {
      _window = window;
      _secret = widget.account.sharedSecret;
      _code = _codeFor(widget.account, window * 30);
    }
    return RepaintBoundary(child: widget.builder(context, _code!));
  }
}

class _LiveCountdown extends ConsumerWidget {
  final bool wide;

  const _LiveCountdown({required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tick = ref.watch(tickProvider).value ?? SteamTime.currentSteamTime;
    return RepaintBoundary(
      child: CountdownRing(
        remaining: SteamTotp.secondsRemaining(tick),
        size: context.r(wide ? 52 : 42),
        stroke: context.r(6),
      ),
    );
  }
}

String _displayName(SteamGuardAccount a, AccountNameMode mode) {
  switch (mode) {
    case AccountNameMode.username:
      return a.accountName ?? '${a.steamId}';
    case AccountNameMode.persona:
      final p = a.personaName;
      return (p != null && p.isNotEmpty) ? p : (a.accountName ?? '${a.steamId}');
    case AccountNameMode.id:
      return '${a.steamId}';
  }
}

/// A short crossfade with a small vertical movement when an account changes.
Widget _nameTransition(Widget child, Animation<double> anim) {
  final slide = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: slide,
      child: child,
    ),
  );
}

/// An account label that animates whenever its text changes.
class _AnimatedName extends StatelessWidget {
  final SteamGuardAccount account;
  final AccountNameMode mode;
  final TextStyle style;
  const _AnimatedName(
      {required this.account, required this.mode, required this.style});

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": update immediately instead of sliding.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 0 : 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: reduce
          ? (child, anim) => FadeTransition(opacity: anim, child: child)
          : _nameTransition,
      // Clip the outgoing label so it doesn't bleed into neighbours.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        children: [...previous, ?current],
      ),
      child: Text(
        _displayName(account, mode),
        key: ValueKey('${account.steamId}-${mode.index}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// Main screen — design screen 01, Variant A: a sidebar account list (each row
/// shows its own live code) + a main panel for the selected account (avatar,
/// big code, countdown ring + copy). Responsive: side-by-side on wide screens,
/// stacked (panel on top, list below) on phones.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _selected = 0;
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  bool _checkedLogins = false;
  bool _checkedTutorial = false;
  int _lastTutorialReplay = 0;

  // First-run gesture tutorial hooks: spotlight targets + a controller that
  // lets the tutorial physically open the first row's swipe panes. The targets
  // are LayerLinks so the spotlight follows the real painted position of the
  // code / first row across every layout (phone, tablet two-pane, foldable) —
  // the compositing layer handles the transform, no manual coordinate math.
  final _codeLink = LayerLink();
  final _firstRowLink = LayerLink();
  late final SlidableController _demoSlidable;

  // Pointer movement only rebuilds the small refresh indicator, not the home.
  final _pull = ValueNotifier<double>(0);
  bool _refreshing = false;
  // Account-list manual sort mode (toggled by the sidebar's sort button).
  bool _sortMode = false;
  // Whether the running refresh should show the pull indicator
  // (true for the pull gesture, false for the desktop refresh button).
  bool _pullVisual = false;
  // Measured in finger travel (logical px), not scroll pixels: the list uses
  // BouncingScrollPhysics, whose rubber-band damping
  // (0.52 * (1 - overscrollPast/viewportDimension)^2) scales with the
  // viewport height, so on small screens the same finger travel produces a
  // much smaller scroll-pixel delta — a pixel-based threshold made small
  // phones need a near full-screen drag to trigger. ~130 logical px of real
  // finger travel matches Material's RefreshIndicator feel on any screen.
  static const double _pullThreshold = 130;

  @override
  void initState() {
    super.initState();
    // Empty libraries never build a row. Initialize while mounted instead of
    // letting the first lazy access create a ticker during disposal.
    _demoSlidable = SlidableController(this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _demoSlidable.dispose();
    _pull.dispose();
    super.dispose();
  }

  /// Shows the gesture tutorial once, on touch platforms only (desktop users
  /// get a right-click context menu on the rows instead).
  void _maybeShowTutorial() {
    if (_checkedTutorial) return;
    _checkedTutorial = true;
    final platform = Theme.of(context).platform;
    final touch = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
    if (!touch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Only over the home screen itself — the first account may appear while
      // a login/finalize screen is still on top (revocation code!). Re-arm and
      // retry from the clock listener once we're current.
      if (ModalRoute.of(context)?.isCurrent != true) {
        _checkedTutorial = false;
        return;
      }
      final store = ref.read(settingsStoreProvider);
      if (await store.loadTutorialSeen() || !mounted) return;
      await showGestureTutorial(
        context,
        codeLink: _codeLink,
        firstRowLink: _firstRowLink,
        slidable: _demoSlidable,
      );
      await store.saveTutorialSeen();
    });
  }

  void _cycleNameMode() =>
      unawaited(ref.read(accountNameModeProvider.notifier).cycle());

  /// Accumulates the finger's real vertical travel while the list is
  /// overscrolled at the top (dy > 0 pulls further; dy < 0 — dragging back
  /// up — subtracts, clamped to >= 0). Driving this off finger delta rather
  /// than scroll pixels keeps the trigger travel consistent across screen
  /// sizes (see `_pullThreshold`).
  void _onPullDelta(double dy) {
    if (_refreshing) return;
    final p = (_pull.value + dy).clamp(0.0, _pullThreshold * 1.5);
    if (p == _pull.value) return;
    // Haptic "click" the moment the pull charges past the trigger threshold.
    if (_pull.value < _pullThreshold && p >= _pullThreshold) {
      if (ref.read(hapticsProvider)) HapticFeedback.mediumImpact();
    }
    _pull.value = p;
  }

  /// The list scrolled back into its normal (non-overscrolled) region — any
  /// accumulated pull is stale and must be cleared immediately.
  void _onPullReset() {
    if (_refreshing || _pull.value == 0) return;
    _pull.value = 0;
  }

  void _onPullEnd() {
    if (_refreshing) return;
    if (_pull.value >= _pullThreshold) {
      _startRefresh();
    } else if (_pull.value != 0) {
      _pull.value = 0;
    }
  }

  /// Refreshes avatars/frames and polls the selected account's sign-ins. Shared
  /// by the pull gesture and the desktop refresh button.
  Future<void> _runRefresh() async {
    final accounts =
        ref.read(appControllerProvider).value?.visibleAccounts ?? const [];
    // Freeze the account before either request starts: the user can change
    // selection while avatars load. Independent reads need not queue up.
    final selectedAccount =
        _selected < accounts.length ? accounts[_selected] : null;
    // Counts update independently; an offline account must not hold the home
    // refresh animation open while other accounts wait in the read queue.
    unawaited(ref.read(steamNotificationCountsProvider.notifier)
        .refreshAll(accounts, force: true));
    await Future.wait<void>([
      ref.read(appControllerProvider.notifier).refreshAvatars(),
      if (selectedAccount != null)
        checkPendingLogins(context, ref, selectedAccount, silent: false),
    ]);
  }

  Future<void> _startRefresh({bool visual = true}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _pullVisual = visual;
    });
    try {
      await _runRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullVisual = false;
          _pull.value = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nameMode = ref.watch(accountNameModeProvider);
    // Row glow / border styling still keys off the resolved variant.
    final neon = Theme.of(context).extension<AvaTokens>()?.variant ==
        AvaThemeVariant.neon;
    final accounts =
        ref.watch(appControllerProvider).value?.visibleAccounts ??
            const <SteamGuardAccount>[];
    final haptics = ref.watch(hapticsProvider);
    if (_selected >= accounts.length) _selected = 0;
    final hasAccounts = accounts.isNotEmpty;
    // A first account can be added while the login screen is still above us.
    // Retain the tutorial retry without subscribing the whole home to time.
    ref.listen(tickProvider, (_, _) {
      if (hasAccounts && !_checkedTutorial) _maybeShowTutorial();
    });

    // Auto-check the selected account for pending sign-in requests once on open.
    if (hasAccounts && !_checkedLogins) {
      _checkedLogins = true;
      final acc = accounts[_selected];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) checkPendingLogins(context, ref, acc, silent: true);
      });
    }
    // Settings → "replay tutorial" bumps the counter; re-arm the walkthrough.
    final replay = ref.watch(tutorialReplayProvider);
    if (replay != _lastTutorialReplay) {
      _lastTutorialReplay = replay;
      _checkedTutorial = false;
    }
    if (hasAccounts) _maybeShowTutorial();

    return NotificationCountsRefresh(
      accounts: accounts,
      child: Scaffold(
      // Header removed — settings is a floating button in the bottom-right.
      // endFloat already lifts the FAB clear of minViewPadding.bottom, so the
      // gesture pill is handled — but it sits in the bottom-*right* corner,
      // exactly where the display's arc cuts in. Nudge it up by the part of
      // the corner the system inset doesn't already cover.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: context.cornerOvershoot),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(child: SteamAccelerationStatusChip()),
            SizedBox(width: context.r(12)),
            _SettingsFab(
              label: l.navSettings,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
      body: Column(children: [
        // Inform-only update strip (v1.3); SizedBox.shrink almost always.
        const UpdateBanner(),
        const PortableLibraryBanner(),
        Expanded(
          child: ScanlineOverlay(
        child: !hasAccounts
            ? Stack(
                children: [
                  const Positioned.fill(child: SkinAmbient()),
                  SafeArea(child: _EmptyState(onAdd: () => _addMenu(context))),
                ],
              )
            : LayoutBuilder(
                builder: (context, c) {
                  final sidebar = _Sidebar(
                    accounts: accounts,
                    searchController: _searchController,
                          searchOpen: _searchOpen,
                          onToggleSearch: () => setState(() {
                            _searchOpen = !_searchOpen;
                            _sortMode = false;
                            if (!_searchOpen) _searchController.clear();
                          }),
                          onSearchChanged: (_) =>
                              setState(() => _sortMode = false),
                          selected: _selected,
                    onSelect: (i) {
                      setState(() => _selected = i);
                      // Tapping an account polls its pending sign-in requests.
                      checkPendingLogins(context, ref, accounts[i],
                          silent: true);
                    },
                    onAdd: () => _addMenu(context),
                    nameMode: nameMode,
                    neon: neon,
                    haptics: haptics,
                    // Per-account swipe actions (the old overflow menu).
                    onAction: (acc, action) => _onAction(context, acc, action),
                    // Pull feedback stays in the account-list header, clear of
                    // the selected account's name, token and QR button.
                    pullIndicator: ValueListenableBuilder<double>(
                      valueListenable: _pull,
                      builder: (_, pull, _) {
                        final busy = _refreshing && _pullVisual;
                        if (!busy && pull <= 0) {
                          return const SizedBox.shrink();
                        }
                        return IgnorePointer(
                          child: _HomeRefreshIndicator(
                            progress: (pull / _pullThreshold).clamp(0.0, 1.0),
                            refreshing: busy,
                          ),
                        );
                      },
                    ),
                    onPullDelta: _onPullDelta,
                    onPullReset: _onPullReset,
                    onPullEnd: _onPullEnd,
                    // Desktop has no touch pull-to-refresh — the sidebar shows
                    // a refresh button there instead (no floating indicator).
                    onRefresh: () => _startRefresh(visual: false),
                    refreshing: _refreshing,
                    firstRowLink: _firstRowLink,
                    demoSlidable: _demoSlidable,
                    sorting: _sortMode && !accounts.any((a) => a.fromPortable),
                    onToggleSort: accounts.any((a) => a.fromPortable) ? null : () =>
                        setState(() => _sortMode = !_sortMode),
                    onReorder: (from, to) {
                      // Keep the selection on the same account across the move.
                      final selectedAccount = accounts[_selected];
                      ref
                          .read(appControllerProvider.notifier)
                          .reorder(from, to);
                      setState(() {
                        final order = [...accounts];
                        final moved = order.removeAt(from);
                        order.insert(to, moved);
                        _selected = order.indexOf(selectedAccount);
                      });
                    },
                  );
                  final panel = _MainPanel(
                    account: accounts[_selected],
                    onCopy: _copy,
                    wide: c.maxWidth >= 640,
                    nameMode: nameMode,
                    onTapName: _cycleNameMode,
                    onRelogin: () =>
                        _onAction(context, accounts[_selected], 'login'),
                    onAction: (action) => _onAction(context, accounts[_selected], action),
                    onOpenDashboard: () => _openDashboard(accounts[_selected]),
                    codeLink: _codeLink,
                  );
                  final Widget content = SafeArea(
                    bottom: false,
                    child: c.maxWidth >= 640
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: context.r(240), child: sidebar),
                              Expanded(child: panel),
                            ],
                          )
                        : Column(
                            children: [
                              // Preserve room for accounts on short screens.
                              ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: c.maxHeight * 0.56),
                                child: SingleChildScrollView(child: panel),
                              ),
                              Divider(height: context.r(1)),
                              Expanded(child: sidebar),
                            ],
                          ),
                  );
                  return Stack(
                    children: [
                      // Skin ambience behind the content and HUD above it.
                      const Positioned.fill(child: SkinAmbient()),
                      content,
                      const Positioned.fill(child: SkinOverlay()),
                      // Top-right: approve a sign-in started elsewhere by
                      // scanning its QR code as the selected account
                      // (desktop falls back to the paste flow).
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            // Nested inside the skins' corner brackets (their
                            // lines sit 6–10px from the edges) instead of
                            // colliding with them.
                            padding: context.rInsets(top: 16, right: 16),
                            child: _ScanFab(
                              label: l.loginViaQr,
                              onTap: () => quickApproveLogin(
                                  context, ref, accounts[_selected]),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ),
        ),
      ]),
      ),
    );
  }

  Future<void> _addMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;

    // Themed floating sheet (neon: glowing rounded panel / pixel: hard-edged
    // sticker) instead of the stock M3 list.
    Widget row(BuildContext ctx, IconData icon, String label, String result) =>
        InkWell(
          onTap: () => Navigator.pop(ctx, result),
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: Padding(
            padding: context.rInsets(h: 16, v: 11),
            child: Row(
              children: [
                Container(
                  width: context.r(36),
                  height: context.r(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.55),
                        width: t.borderWidth),
                  ),
                  child: Icon(icon, color: t.accent, size: context.r(18)),
                ),
                SizedBox(width: context.r(14)),
                Text(label,
                    style:
                        TextStyle(color: t.text, fontSize: context.r(14.5))),
              ],
            ),
          ),
        );

    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: context.rInsets(h: 10, bottom: 10),
          padding: context.rInsets(v: 8),
          decoration: BoxDecoration(
            // Nearly opaque so the list doesn't ghost through the neon glass.
            color: t.isPixel ? t.panel2 : t.panel2.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(t.isPixel ? 0 : t.radius),
            border: Border.all(
              color: t.isPixel
                  ? t.borderColor
                  : t.accent.withValues(alpha: 0.5),
              width: t.borderWidth,
            ),
            boxShadow: t.isPixel
                ? t.cardShadow()
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                    ...t.glowShadow(blur: context.r(18), opacity: 0.18),
                  ],
          ),
          // Transparent Material above the opaque panel so the row ink
          // ripples actually show.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: context.rInsets(top: 2, bottom: 6),
                    width: context.r(40),
                    height: context.r(4),
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius:
                          BorderRadius.circular(t.isPixel ? 0 : context.r(2)),
                    ),
                  ),
                ),
                row(ctx, Icons.file_open_outlined, l.actionImport, 'import'),
                row(ctx, Icons.folder_open_outlined, l.sdaImportAction, 'sda'),
                row(ctx, Icons.add_moderator_outlined,
                    l.actionAddAuthenticator, 'login'),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || value == null) return;
    switch (value) {
      case 'import':
        await importMaFileFlow(context, ref);
        break;
      case 'sda':
        await importSdaBundleFlow(context, ref);
        break;
      case 'login':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LoginScreen(reason: LoginReason.add)));
        break;
    }
  }

  void _openDashboard(SteamGuardAccount account) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountDashboardScreen(
        account: account,
        onAction: (action) => _onAction(context, account, action),
      ),
    ));
  }

  Future<void> _onAction(
      BuildContext context, SteamGuardAccount account, String value) async {
    final l = AppLocalizations.of(context);
    switch (value) {
      case 'notifications':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NotificationsScreen(account: account),
        ));
        break;
      case 'dashboard':
        _openDashboard(account);
        break;
      case 'friends':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendsScreen(account: account)));
        break;
      case 'backup-codes':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BackupCodesScreen(account: account)));
        break;
      case 'listings':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketScreen(account: account, initialTab: 1)));
        break;
      case 'steam-client':
        if (Platform.isWindows) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SteamClientScreen(initialAccount: account)));
        }
        break;
      case 'confirm':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PendingScreen(account: account)));
        break;
      case 'login':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                LoginScreen(reason: LoginReason.refresh, account: account)));
        break;
      case 'export':
        await exportMaFileFlow(context, account);
        break;
      case 'logins':
        await checkPendingLogins(context, ref, account);
        break;
      case 'market':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MarketScreen(account: account)));
        break;
      case 'family':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FamilyGroupScreen(account: account)));
        break;
      case 'devices':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DeviceSessionsScreen(account: account)));
        break;
      case 'redeem':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RedeemKeyScreen(account: account)));
        break;
      case 'remove':
        final t = Theme.of(context).extension<AvaTokens>()!;
        // Local delete has no trash — the confirm button is the app's
        // standard hold-to-confirm (issue #8), unless the user turned the
        // dedicated toggle off (then it degrades to a plain tap).
        final holdEnabled = ref.read(deleteHoldProvider);
        final hapticsEnabled = ref.read(hapticsProvider);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l.removeConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.commonCancel)),
              // Destructive action — red, visually separated from the accent.
              HoldToConfirmButton(
                  label: l.actionRemove,
                  color: t.bad,
                  holdEnabled: holdEnabled,
                  hapticsEnabled: hapticsEnabled,
                  onConfirmed: () => Navigator.pop(ctx, true)),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(appControllerProvider.notifier).removeAccount(account);
        }
        break;
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).codeCopied)),
    );
  }
}

/// Left/bottom account list. Each row shows the account's own live code.
class _Sidebar extends StatelessWidget {
  final List<SteamGuardAccount> accounts;
  final TextEditingController searchController;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  List<int> get visibleIndices {
    final query = searchController.text.trim().toLowerCase();
    return [
      for (var i = 0; i < accounts.length; i++)
        if (query.isEmpty ||
            (accounts[i].accountName ?? '').toLowerCase().contains(query) ||
            (accounts[i].personaName ?? '').toLowerCase().contains(query) ||
            '${accounts[i].steamId}'.contains(query))
          i,
    ];
  }

  final int selected;
  final void Function(int index) onSelect;
  final VoidCallback onAdd;
  final void Function(double dy) onPullDelta;
  final VoidCallback onPullReset;
  final VoidCallback onPullEnd;
  final Widget pullIndicator;
  final void Function(SteamGuardAccount account, String action) onAction;
  final AccountNameMode nameMode;
  final bool neon;
  final bool haptics;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final LayerLink? firstRowLink;
  final SlidableController? demoSlidable;
  final bool sorting;
  final VoidCallback? onToggleSort;
  final void Function(int from, int to)? onReorder;
  const _Sidebar({
    required this.accounts,
    required this.searchController,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.nameMode,
    required this.neon,
    required this.haptics,
    required this.onAction,
    required this.onPullDelta,
    required this.onPullReset,
    required this.onPullEnd,
    required this.pullIndicator,
    this.onRefresh,
    this.refreshing = false,
    this.firstRowLink,
    this.demoSlidable,
    this.sorting = false,
    this.onToggleSort,
    this.onReorder,
  });

  Widget _list(BuildContext context) {
    final indices = visibleIndices;
    if (indices.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).accountSearchEmpty),
      );
    }
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        // Bouncing so the custom pull-to-refresh reads overscroll on both
        // themes (neon fill / pixel blocks).
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        // Bottom clearance so the floating settings button doesn't cover the
        // last row.
        padding: context.rSafeInsets(left: 8, right: 8, top: 4, bottom: 78),
        key: ValueKey(searchController.text),
        itemCount: indices.length,
        itemBuilder: (context, visibleIndex) {
          final i = indices[visibleIndex];
          final row = _SidebarRow(
            account: accounts[i],
            selected: i == selected,
            nameMode: nameMode,
            neon: neon,
            haptics: haptics,
            onTap: () => onSelect(i),
            onAction: onAction,
            controller: i == 0 ? demoSlidable : null,
          );
          // The first row anchors the tutorial spotlight (+ its swipe demo).
          if (i == 0 && firstRowLink != null) {
            return CompositedTransformTarget(link: firstRowLink!, child: row);
          }
          return row;
        },
      ),
    );
  }

  /// Sort mode: rows lose their tap/swipe gestures and gain a drag handle;
  /// dragging the handle reorders, everything else still scrolls.
  Widget _sortList(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: context.rSafeInsets(left: 8, right: 8, top: 4, bottom: 78),
      itemCount: accounts.length,
      // onReorderItem already adjusts the target index for the removed item.
      onReorderItem: (from, to) {
        if (to != from) onReorder?.call(from, to);
      },
      proxyDecorator: (child, _, _) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) => Stack(
        key: ValueKey(accounts[i].steamId),
        alignment: Alignment.centerRight,
        children: [
          IgnorePointer(
            child: _SidebarRow(
              account: accounts[i],
              selected: i == selected,
              nameMode: nameMode,
              neon: neon,
              haptics: haptics,
              onTap: () {},
              onAction: onAction,
            ),
          ),
          Padding(
            padding: context.rInsets(right: 10),
            child: ReorderableDragStartListener(
              index: i,
              child: Container(
                // Generous hit area for the handle; visual stays a small icon.
                width: context.r(40),
                height: context.r(48),
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Icon(Icons.drag_indicator,
                    size: context.r(18), color: t.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Neon panel is already translucent; make the pixel list translucent too
        // so the starfield backdrop shows through.
        color: neon ? t.panel : t.panel.withValues(alpha: 0.32),
        border: Border(right: BorderSide(color: t.line, width: t.borderWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: context.rInsets(left: 14, right: 10),
            // Fixed 48dp-tall header so the add button gets a full-size touch
            // target; the 24px visual is unchanged.
            child: SizedBox(
              key: const ValueKey('home-account-list-header'),
              height: context.r(48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.navAccounts,
                      style: TextStyle(
                          color: t.muted,
                          fontSize: context.r(11),
                          letterSpacing: context.r(1)),
                    ),
                  ),
                  pullIndicator,
                  IconButton(
                    tooltip: l.accountSearchHint,
                    onPressed: onToggleSearch,
                    icon: Icon(
                      searchOpen ? Icons.search_off : Icons.search,
                      color: t.accent,
                      size: context.r(18),
                    ),
                  ),
                  // Mouse users can't pull-to-refresh — give desktop a button.
                  if (onRefresh != null &&
                      switch (Theme.of(context).platform) {
                        TargetPlatform.linux ||
                        TargetPlatform.macOS ||
                        TargetPlatform.windows =>
                          true,
                        _ => false,
                      })
                    InkWell(
                      key: const ValueKey('home-refresh-button'),
                      onTap: refreshing ? null : onRefresh,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      child: SizedBox(
                        width: context.r(40),
                        height: context.r(48),
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: context.r(24),
                            height: context.r(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: t.border,
                              borderRadius: BorderRadius.circular(t.radiusSm),
                            ),
                            child: refreshing
                                ? SizedBox(
                                    width: context.r(13),
                                    height: context.r(13),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: t.accent,
                                      semanticsLabel: l.commonRefresh,
                                      value: MediaQuery.disableAnimationsOf(context)
                                          ? 0.75
                                          : null,
                                    ),
                                  )
                                : Icon(Icons.refresh,
                                    size: context.r(15), color: t.accent),
                          ),
                        ),
                      ),
                    ),
                  // Manual reorder toggle — only meaningful with 2+ accounts.
                  if (onToggleSort != null && accounts.length > 1 &&
                      searchController.text.isEmpty)
                    InkWell(
                      onTap: onToggleSort,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      child: SizedBox(
                        width: context.r(40),
                        height: context.r(48),
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: context.r(24),
                            height: context.r(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: t.border,
                              borderRadius: BorderRadius.circular(t.radiusSm),
                              color: sorting
                                  ? t.accent.withValues(alpha: 0.18)
                                  : null,
                            ),
                            child: Icon(
                                sorting ? Icons.check : Icons.swap_vert,
                                size: context.r(15), color: t.accent),
                          ),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    child: SizedBox(
                      width: context.r(52),
                      height: context.r(48),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: context.r(24),
                          height: context.r(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: t.border,
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                          child: Icon(Icons.add,
                              size: context.r(16), color: t.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (searchOpen)
            Padding(
              padding: context.rInsets(h: 10, bottom: 8),
              child: TextField(
                controller: searchController,
                autofocus: true,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: l.accountSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.accountSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
          Expanded(
            child: Listener(
              onPointerUp: (_) => onPullEnd(),
              onPointerCancel: (_) => onPullReset(),
              // Trackpads (macOS) scroll via pan-zoom events, not pointer up.
              onPointerPanZoomEnd: (_) => onPullEnd(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  final metrics = n.metrics;
                  // Back inside the normal scroll region — no longer pulling.
                  if (metrics.pixels > 0) {
                    onPullReset();
                    return false;
                  }
                  // Only real finger drags count — mouse wheel / trackpad
                  // scroll notifications never carry dragDetails, so desktop
                  // scrolling can never trigger the pull. Only accumulate
                  // while the list is overscrolled at the top, or on the very
                  // first frame of the pull (pixels may still read 0 before
                  // BouncingScrollPhysics' damping produces a negative value).
                  if (n is ScrollUpdateNotification) {
                    final drag = n.dragDetails;
                    final atTop = metrics.pixels < 0 ||
                        (metrics.extentBefore == 0 &&
                            (drag?.delta.dy ?? 0) > 0);
                    if (drag != null && atTop) onPullDelta(drag.delta.dy);
                  }
                  return false;
                },
                child: sorting ? _sortList(context) : _list(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends ConsumerWidget {
  final SteamGuardAccount account;
  final bool selected;
  final AccountNameMode nameMode;
  final bool neon;
  final bool haptics;
  final VoidCallback onTap;
  final void Function(SteamGuardAccount account, String action) onAction;
  final SlidableController? controller;
  const _SidebarRow({
    required this.account,
    required this.selected,
    required this.nameMode,
    required this.neon,
    required this.haptics,
    required this.onTap,
    required this.onAction,
    this.controller,
  });

  /// Desktop/mouse path for the swipe + long-press actions: a right-click
  /// context menu.
  ///
  /// Deliberately still lists the swipe actions (confirmations / refresh /
  /// export / remove) that touch users reach by swiping — with a mouse this menu is
  /// the *only* discoverable way to reach them. The sidebar's refresh button
  /// is a global avatar refresh, not this account's re-login.
  Future<void> _contextMenu(BuildContext context, Offset at) async {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    PopupMenuItem<String> item(String value, IconData icon, String label,
            {Color? color}) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? t.muted),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    style: color != null ? TextStyle(color: color) : null),
              ),
            ],
          ),
        );

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        if (!_hasInlineDashboard(context))
          item('dashboard', Icons.dashboard_outlined, l.dashboardTitle),
        item('notifications', Icons.notifications_outlined, l.notificationsTitle),
        item('friends', Icons.people_outline, l.friendsTitle),
        item('backup-codes', Icons.key_outlined, l.backupCodesTitle),
        if (Platform.isWindows)
          item('steam-client', Icons.switch_account_outlined, l.steamSwitchTitle),
        item('confirm', Icons.verified_user_outlined, l.actionConfirmations),
        item('market', Icons.inventory_2_outlined, l.actionMarket),
        item('family', Icons.family_restroom, l.famAccountAction),
        item('devices', Icons.devices_outlined, l.deviceSessionsAction),
        item('redeem', Icons.vpn_key_outlined, l.keyRedeemAction),
        item('login', Icons.refresh, l.commonRefresh),
        item('export', Icons.ios_share, l.commonExport),
        item('remove', Icons.delete_outline, l.commonDelete, color: t.bad),
      ],
    );
    if (action != null && context.mounted) onAction(account, action);
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final r = context.r(1);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final neon = t.glow;
    final pixel = t.variant == AvaThemeVariant.pixel;
    // Neon theme: dark glassy pill + neon border/inset glow (HUD look).
    // Pixel theme: chunky retro button — bright fill, hard 2px border, hard
    // offset shadow, dark text (no blur, radius 0).
    const ink = Color(0xFF15111F);
    final fill = pixel ? color : color.withValues(alpha: neon ? 0.16 : 0.08);
    final fg = neon ? color : pixel ? ink : t.text;
    return CustomSlidableAction(
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      onPressed: (_) {
        if (haptics) HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        // Extra vertical margin insets the pill so it isn't as tall as the row.
        margin: EdgeInsets.symmetric(
            horizontal: neon ? 3 * r : 4 * r, vertical: 12 * r),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: neon
              ? Border.all(
                  color: color.withValues(alpha: 0.9), width: t.borderWidth)
              : Border.all(color: pixel ? ink : t.line,
                  width: pixel ? 2 : t.borderWidth),
          boxShadow: neon
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 5,
                      blurStyle: BlurStyle.inner),
                ]
              : pixel
                  ? [BoxShadow(color: ink, offset: Offset(3 * r, 3 * r))]
                  : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 19 * r),
            SizedBox(height: 3 * r),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2 * r),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg,
                      fontSize: 11.5 * r,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final l = AppLocalizations.of(context);
    final sessionInvalid = ref.watch(sessionHealthProvider.select(
      (invalidAccounts) => invalidAccounts.contains(account.steamId),
    ));
    return Padding(
      padding: context.rInsets(bottom: 8),
      child: Slidable(
        key: ValueKey((account.steamId, account.fromPortable)),
        controller: controller,
        // Desktop rows select accounts or expose actions through right-click.
        // Keep phone gestures even in a wide/foldable layout, and disable them
        // on desktop even when the window is narrow or the screen has touch.
        enabled: switch (Theme.of(context).platform) {
          TargetPlatform.windows ||
          TargetPlatform.macOS ||
          TargetPlatform.linux => false,
          _ => true,
        },
        // Swipe RIGHT → enter the pending center (full swipe enters directly).
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.34,
          dismissible: DismissiblePane(
            closeOnCancel: true,
            confirmDismiss: () async {
              onAction(account, 'confirm');
              return false; // navigate, don't actually remove the row
            },
            onDismissed: () {},
          ),
          children: [
            _action(context,
                icon: Icons.verified_user_outlined,
                label: l.actionConfirmations,
                color: t.good,
                onTap: () => onAction(account, 'confirm')),
          ],
        ),
        // Swipe LEFT → the other per-account actions.
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.66,
          children: [
            _action(context,
                icon: Icons.refresh,
                label: l.commonRefresh,
                color: t.accent,
                onTap: () => onAction(account, 'login')),
            _action(context,
                icon: Icons.ios_share,
                label: l.commonExport,
                color: t.accent2,
                onTap: () => onAction(account, 'export')),
            _action(context,
                icon: Icons.delete_outline,
                label: l.commonDelete,
                color: t.bad,
                onTap: () => onAction(account, 'remove')),
          ],
        ),
        child: _PressableCard(
          // Hold an account to open its overview directly; swipe panes
          // hold the remaining management actions. Desktop keeps right-click.
          radius: t.radiusSm,
          onTap: onTap,
          onLongPress: _hasInlineDashboard(context)
              ? null
              : () => onAction(account, 'dashboard'),
          onSecondaryMenu: (pos) => _contextMenu(context, pos),
          child: Container(
            padding: context.rInsets(all: 8),
            decoration: neon
            ? BoxDecoration(
                color:
                    selected ? t.panel2 : t.panel2.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(t.radiusSm),
                // Every account gets a neon frame; the selected one glows.
                border: Border.all(
                  color: selected ? t.accent : t.accent.withValues(alpha: 0.28),
                  width: selected ? context.r(1.6) : context.r(1),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.35),
                          blurRadius: context.r(10),
                          spreadRadius: context.r(0.5),
                        ),
                      ]
                    : null,
              )
            : BoxDecoration(
                // Plain themes use flat rounded cards; only the pixel skin
                // keeps its intentional offset shadow.
                color: selected ? t.panel2 : t.panel.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(
                  color: selected ? t.accent : t.line,
                  width: t.borderWidth,
                ),
                boxShadow: selected && t.variant == AvaThemeVariant.pixel
                    ? [
                        BoxShadow(
                          color: t.borderColor,
                          offset: Offset(context.r(4), context.r(4)),
                        ),
                      ]
                    : null,
              ),
        child: Row(
          children: [
            _Avatar(account: account, size: context.r(70)),
            SizedBox(width: context.r(15)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _AnimatedName(
                          account: account,
                          mode: nameMode,
                          style: TextStyle(
                              color: t.text, fontSize: context.r(19.5)),
                        ),
                      ),
                      if (account.fromPortable) Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(message: l.portableMode,
                          child: Icon(Icons.usb, size: context.r(14), color: t.muted)),
                      ),
                      if (sessionInvalid) ...[
                        SizedBox(width: context.r(5)),
                        // Same verdict the main panel spells out — here just
                        // a marker so the list scans at a glance.
                        Tooltip(
                          message: l.accountSessionInvalid,
                          child: Icon(Icons.error_outline,
                              size: context.r(15), color: t.bad),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          key: ValueKey('account-pending-${account.steamId}'),
                          onTap: () => onAction(account, 'confirm'),
                          child: PendingConfirmationBadge(account: account),
                        ),
                      ),
                    ],
                  ),
                  _AccountCode(
                    account: account,
                    builder: (context, code) => Text(
                      code,
                      style: TextStyle(
                        color: t.accent,
                        fontSize: context.r(18),
                        letterSpacing: context.r(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

/// Tapping selects the token; holding opens its overview without a second menu.
/// Desktop retains its right-click context menu.
class _PressableCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(Offset) onSecondaryMenu;
  const _PressableCard({
    required this.child,
    required this.radius,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryMenu,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onSecondaryTapDown: (d) => onSecondaryMenu(d.globalPosition),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      );
}

class _MainPanel extends ConsumerWidget {
  final SteamGuardAccount account;
  final void Function(String code) onCopy;
  final bool wide; // two-pane (tablet/desktop) layout
  final AccountNameMode nameMode;
  final VoidCallback onTapName;
  final VoidCallback onRelogin; // invalid-session status line → re-login
  final ValueChanged<String> onAction;
  final VoidCallback onOpenDashboard;
  final LayerLink? codeLink; // tutorial spotlight anchor
  const _MainPanel(
      {required this.account,
      required this.onCopy,
      required this.nameMode,
      required this.onTapName,
      required this.onRelogin,
      required this.onAction,
      required this.onOpenDashboard,
      this.codeLink,
      this.wide = false});

  Widget _linkTarget(LayerLink? link, Widget child) =>
      link == null ? child : CompositedTransformTarget(link: link, child: child);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final platform = Theme.of(context).platform;
    final mobile = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS;
    final sessionInvalid = ref.watch(sessionHealthProvider.select(
      (invalidAccounts) => invalidAccounts.contains(account.steamId),
    ));

    final header = Padding(
      padding: context.rInsets(h: 16, v: wide ? 24 : 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: const ValueKey('selected-account-avatar'),
                onLongPress: mobile ? onOpenDashboard : null,
                child: _Avatar(account: account, size: context.r(wide ? 76 : 56)),
              ),
              SizedBox(width: context.r(18)),
              Flexible(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tap still cycles the remembered display mode.
                  AccountIdentityMenu(
                    key: const ValueKey('selected-account-name'),
                    account: account,
                    onTap: onTapName,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: _AnimatedName(
                              account: account,
                              mode: nameMode,
                              style: TextStyle(
                                  color: t.text, fontSize: context.r(23)),
                            ),
                          ),
                          SizedBox(width: context.r(6)),
                          Icon(Icons.swap_horiz,
                              size: context.r(16), color: t.muted),
                        ],
                      ),
                    ),
                  ),
                  // Ready / invalid status line. A credentials-rejected
                  // account (password changed elsewhere — issue #8) turns the
                  // dot red and the line tappable, leading straight to
                  // re-login.
                  GestureDetector(
                    onTap: sessionInvalid ? onRelogin : null,
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulsingDot(
                              color: sessionInvalid ? t.bad : t.good,
                              size: context.r(7)),
                          SizedBox(width: context.r(6)),
                          Flexible(
                            child: Text(
                                sessionInvalid
                                    ? l.accountSessionInvalid
                                    : l.accountReady,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: sessionInvalid ? t.bad : t.muted,
                                    fontSize: context.r(12))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.r(wide ? 20 : 12)),
          // Code + countdown ring on one row. Tap the code to copy it (the
          // explicit copy button is gone). Phone: scale the code relative to the
          // viewport; tablet / two-pane: keep the fixed design size.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                // The tutorial spotlight follows this via a LayerLink, so it
                // tracks the code's real painted position in every layout.
                child: _linkTarget(
                  codeLink,
                  _AccountCode(
                    account: account,
                    builder: (context, code) => _TapScale(
                      onTap: () => onCopy(code),
                      child: wide
                          ? FlipCode(code: code, fontSize: 42)
                          : SizedBox(
                              width: (MediaQuery.sizeOf(context).width * 0.40)
                                  .clamp(110.0, 200.0),
                              child: FittedBox(
                                fit: BoxFit.fitWidth,
                                child: FlipCode(code: code, fontSize: 56),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.r(18)),
              _LiveCountdown(wide: wide),
              if (mobile || !wide) ...[
                const SizedBox(width: 8),
                SteamNotificationsButton(
                  account: account,
                  compact: true,
                  onPressed: () => onAction('notifications'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    // The phone home stays a token and account picker. Its richer account
    // tools are opened explicitly from the avatar or account action menu.
    final touchPlatform = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    if (!wide || touchPlatform) return header;
    final dashboard = AccountDashboard(
      key: ValueKey(('dashboard', account.steamId, account.fromPortable, wide)),
      account: account,
      onAction: onAction,
    );
    return ListView(
      padding: context.rSafeInsets(left: 28, right: 96, top: 52, bottom: 96),
      children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 12), dashboard],
        ))),
      ],
    );
  }
}

/// Shared chrome for the floating corner buttons: flat rounded plain themes,
/// a neon glass disc, or the pixel skin's square with an offset shadow. The two
/// call sites deliberately differ in size and emphasis — those constants are
/// explicit arguments here instead of drifting copies.
class _AvaFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final double size; // logical design size, scaled via context.r()
  final double iconSize;
  // Neon look: null border alpha keeps the accent token untouched.
  final double? neonBorderAlpha;
  final double neonBorderWidth;
  final double neonGlowAlpha;
  final double neonGlowBlur;
  // Pixel look: hard shadow offset (same value for dx and dy).
  final double pixelShadowOffset;
  final bool tooltip;
  const _AvaFab({
    required this.label,
    required this.onTap,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.neonBorderAlpha,
    required this.neonBorderWidth,
    required this.neonGlowAlpha,
    required this.neonGlowBlur,
    required this.pixelShadowOffset,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final neon = t.glow;
    final pixel = t.variant == AvaThemeVariant.pixel;
    final side = context.r(size);
    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(neon ? side / 2 : t.radiusSm),
        child: Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: neon
              ? BoxDecoration(
                  color: t.panel2,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: neonBorderAlpha == null
                          ? t.accent
                          : t.accent.withValues(alpha: neonBorderAlpha!),
                      width: context.r(neonBorderWidth)),
                  boxShadow: [
                    BoxShadow(
                        color: t.accent.withValues(alpha: neonGlowAlpha),
                        blurRadius: context.r(neonGlowBlur)),
                  ],
                )
              : BoxDecoration(
                  color: t.panel2,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  border: Border.all(color: pixel ? t.accent : t.line,
                      width: pixel ? 2 : t.borderWidth),
                  boxShadow: pixel ? [
                    BoxShadow(
                        color: t.borderColor,
                        offset: Offset(context.r(pixelShadowOffset),
                            context.r(pixelShadowOffset))),
                  ] : null,
                ),
          child: Icon(icon, color: t.accent, size: context.r(iconSize)),
        ),
      ),
    );
    if (tooltip) button = Tooltip(message: label, child: button);
    return Semantics(button: true, label: label, child: button);
  }
}

/// Compact top-right corner chip that launches the QR sign-in approval for
/// the selected account — same visual language as [_SettingsFab], sized down.
class _ScanFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ScanFab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => _AvaFab(
        label: label,
        onTap: onTap,
        icon: Icons.qr_code_scanner,
        size: 44,
        iconSize: 20,
        neonBorderAlpha: 0.75,
        neonBorderWidth: 1.2,
        neonGlowAlpha: 0.3,
        neonGlowBlur: 10,
        pixelShadowOffset: 2,
        tooltip: true,
      );
}

/// Floating settings button (bottom-right), styled per theme: neon glass disc
/// with an accent glow, or a chunky pixel square with a hard offset shadow.
class _SettingsFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SettingsFab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => _AvaFab(
        label: label,
        onTap: onTap,
        icon: Icons.settings_outlined,
        size: 54,
        iconSize: 26,
        neonBorderAlpha: null,
        neonBorderWidth: 1.4,
        neonGlowAlpha: 0.4,
        neonGlowBlur: 14,
        pixelShadowOffset: 3,
        tooltip: false,
      );
}

/// Wraps a tappable child with a subtle press-scale for tactile feedback.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down && !MediaQuery.disableAnimationsOf(context) ? 0.98 : 1.0,
        duration: Duration(milliseconds:
            MediaQuery.disableAnimationsOf(context) ? 0 : 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bounded refresh feedback shared by every skin. Only the ring animates while
/// work is pending; pulling never paints a wash over the account list.
class _HomeRefreshIndicator extends StatelessWidget {
  final double progress;
  final bool refreshing;

  const _HomeRefreshIndicator({
    required this.progress,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: Container(
        key: const ValueKey('home-pull-refresh-indicator'),
        width: context.r(44),
        height: context.r(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.panel2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.isPixel ? 8 : 22),
        ),
        child: SizedBox(
          width: context.r(22),
          height: context.r(22),
          child: CircularProgressIndicator(
            value: refreshing ? (reduce ? 0.75 : null) : progress,
            strokeWidth: 2.5,
            color: t.accent,
            backgroundColor: t.line,
            semanticsLabel: AppLocalizations.of(context).commonRefresh,
          ),
        ),
      ),
    );
  }
}
class _Avatar extends StatelessWidget {
  final SteamGuardAccount account;
  final double size;
  const _Avatar({required this.account, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final radius = BorderRadius.circular(t.radiusSm);
    Widget fallback(double d) => Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _avatarColor(account),
            borderRadius: radius,
          ),
          child: Text(
            _initial(account),
            style: TextStyle(
              color: const Color(0xFF06060F),
              fontSize: d * 0.36,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    final url = account.avatarUrl;
    final animUrl = account.animatedAvatarUrl;
    final frameUrl = account.avatarFrameUrl;
    final hasFrame = frameUrl != null && frameUrl.isNotEmpty;
    // With a frame, inset the avatar so the frame's border sits around it.
    final avatarSize = hasFrame ? size * 0.78 : size;
    // Prefer the animated avatar (a GIF, which the engine codec animates
    // natively) and fall back to the static avatar. SteamImageProvider serves
    // bytes from the disk cache, so a relaunch shows avatars instantly; the
    // background profile refresh swaps the URL when the avatar changes.
    final displayUrl =
        (animUrl != null && animUrl.isNotEmpty) ? animUrl : url;
    final Widget avatar = (displayUrl == null || displayUrl.isEmpty)
        ? fallback(avatarSize)
        : ClipRRect(
            borderRadius: radius,
            child: Image(
              // Decode at display size (animated GIFs keep animating), in
              // 32px buckets so desktop window resizes don't re-decode.
              image: ResizeImage.resizeIfNeeded(
                (((avatarSize * MediaQuery.devicePixelRatioOf(context))
                                .ceil() +
                            31) ~/
                        32) *
                    32,
                null,
                SteamImageProvider(displayUrl),
              ),
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback(avatarSize),
              frameBuilder: (ctx, child, frame, syncLoaded) =>
                  (frame == null && !syncLoaded)
                      ? fallback(avatarSize)
                      : child,
            ),
          );
    if (!hasFrame) return avatar;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          // The frame may itself be animated (APNG); contain to fit the box.
          IgnorePointer(
            child: AnimatedSteamImage(
              url: frameUrl,
              size: size,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Center(
      child: Padding(
        padding: context.rInsets(all: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingLogo(child: AppLogo(size: context.r(84))),
            SizedBox(height: context.r(22)),
            Text(l.accountsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted, height: 1.6)),
            SizedBox(height: context.r(18)),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l.emptyAddAccount),
            ),
          ],
        ),
      ),
    );
  }
}
