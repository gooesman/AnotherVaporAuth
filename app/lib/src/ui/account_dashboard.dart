import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/dashboard_sections.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../core/models/steam_friend.dart';
import '../core/models/steam_guard_account.dart';
import '../core/models/steam_item.dart';
import '../core/steam_currency.dart';
import '../services/account_dashboard_loader.dart';
import 'market/market_screen.dart';
import 'friends/friends_screen.dart' show friendsClientProvider;
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/account_identity_menu.dart';
import 'widgets/pending_confirmation_badge.dart';
import 'widgets/steam_notifications_button.dart';
import 'widgets/dashboard_favorites_card.dart';

export '../app/dashboard_sections.dart';

final accountDashboardLoaderProvider = Provider<AccountDashboardLoader>((ref) {
  final controller = ref.read(appControllerProvider.notifier);
  final loader = AccountDashboardLoader(
    inventory: ref.read(inventoryClientProvider),
    market: ref.read(marketClientProvider),
    friends: ref.read(friendsClientProvider),
    api: ref.read(apiClientProvider),
    persistSession: (account) async {
      await controller.persistSession(account);
    },
  );
  ref.listen(appControllerProvider, (previous, next) {
    final data = next.value;
    if (data == null || data.locked) {
      loader.clear();
    } else if (previous?.value != null) {
      loader.retainAccounts(data.visibleAccounts);
    }
  });
  ref.onDispose(loader.clear);
  return loader;
});

/// Local actions render immediately. Each visible card owns an independent,
/// bounded read, shared with other overview instances for this same session.
class AccountDashboard extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final ValueChanged<String> onAction;
  final bool compact;
  final VoidCallback? onExpand;
  const AccountDashboard({
    super.key,
    required this.account,
    required this.onAction,
    this.compact = false,
    this.onExpand,
  });

  @override
  ConsumerState<AccountDashboard> createState() => _AccountDashboardState();
}

class _AccountDashboardState extends ConsumerState<AccountDashboard>
    with SessionRetryState, WidgetsBindingObserver {
  late final AccountDashboardLoader _loader;
  bool _foreground = true;
  bool _routeVisible = false;
  int _favoritesReload = 0;
  bool get _active => _foreground && _routeVisible;
  DashboardLease? _lease;
  DashboardData get _data => _lease!.data;
  WalletInfo? get _wallet => _data.wallet.value;
  List<MarketListing>? get _listings => _data.listings.value;
  bool get _walletFailed => _data.wallet.failed;
  bool get _listingsFailed => _data.listings.failed;
  bool get _needsLogin =>
      (_lease!.wallet && _data.wallet.needsLogin) ||
      (_lease!.listings && _data.listings.needsLogin) ||
      (_lease!.friends && _data.friends.needsLogin) ||
      (_lease!.inventory && _data.inventory.needsLogin);
  bool get _busy =>
      (_lease!.wallet && _data.wallet.loading) ||
      (_lease!.listings && _data.listings.loading) ||
      (_lease!.friends && _data.friends.loading) ||
      (_lease!.inventory && _data.inventory.loading);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _loader = ref.read(accountDashboardLoaderProvider);
    _bind(ref.read(dashboardSectionsProvider));
  }

  @override
  void didUpdateWidget(covariant AccountDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind(ref.read(dashboardSectionsProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    _bind(ref.read(dashboardSectionsProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _bind(ref.read(dashboardSectionsProvider));
    });
  }

  bool _accountAvailable(AppData? app) =>
      app != null &&
      !app.locked &&
      app.visibleAccounts.any(
        (account) =>
            account.steamId == widget.account.steamId &&
            account.fromPortable == widget.account.fromPortable &&
            account.accountName == widget.account.accountName &&
            account.session.accessToken == widget.account.session.accessToken &&
            account.session.refreshToken ==
                widget.account.session.refreshToken &&
            (account.steamId != 0 || identical(account, widget.account)),
      );

  void _bind(Set<String> sections) {
    final available = _accountAvailable(ref.read(appControllerProvider).value);
    final ready =
        ref.read(dashboardSectionsProvider.notifier).ready &&
        available &&
        _active;
    final wallet = ready && sections.contains('wallet');
    final listings = ready && !widget.compact && sections.contains('listings');
    final friends = ready && !widget.compact && sections.contains('friends');
    final inventory =
        ready && !widget.compact && sections.contains('inventory');
    final previous = _lease;
    if (previous != null &&
        _loader.matches(previous, widget.account) &&
        previous.wallet == wallet &&
        previous.listings == listings &&
        previous.friends == friends &&
        previous.inventory == inventory) {
      return;
    }
    previous?.data.removeListener(_changed);
    // Retain the next view before releasing the old one, so a layout change
    // never cancels a read that is still useful to the same account.
    _lease = _loader.acquire(
      widget.account,
      wallet: wallet,
      listings: listings,
      friends: friends,
      inventory: inventory,
    );
    previous?.release();
    _data.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _load() {
    _lease?.refresh();
    setState(() => _favoritesReload++);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lease?.data.removeListener(_changed);
    _lease?.release();
    super.dispose();
  }

  Widget _progress(String section) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: LinearProgressIndicator(key: ValueKey('dashboard-$section-loading')),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = ref.watch(dashboardSectionsProvider);
    final available = ref.watch(
      appControllerProvider.select((state) => _accountAvailable(state.value)),
    );
    _bind(sections);
    ref.listen(dashboardSectionsProvider, (_, next) {
      _bind(next);
    });
    final balance = _wallet?.balance;
    final balanceText = balance == null
        ? (_data.wallet.loading ? '…' : l.dashboardUnavailable)
        : formatSteamMoney(balance, _wallet!.currency);
    if (widget.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sections.contains('wallet'))
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l.dashboardWallet}  $balanceText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: widget.onExpand,
                  child: Text(l.dashboardTitle),
                ),
              ],
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _action(l.dashboardMarket, Icons.storefront_outlined, 'market'),
              _action(l.friendsTitle, Icons.people_outline, 'friends'),
              _action(l.backupCodesTitle, Icons.key_outlined, 'backup-codes'),
              if (!sections.contains('wallet'))
                TextButton(
                  onPressed: widget.onExpand,
                  child: Text(l.dashboardTitle),
                ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.dashboardTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: l.commonRefresh,
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              tooltip: l.dashboardCustomize,
              icon: const Icon(Icons.tune),
              onSelected: (section) async {
                try {
                  await ref
                      .read(dashboardSectionsProvider.notifier)
                      .toggle(section);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.dashboardSaveFailed)),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                for (final pair in [
                  ('wallet', l.dashboardWallet),
                  ('listings', l.marketTabListings),
                  ('tools', l.dashboardTools),
                  ('friends', l.dashboardFriends),
                  ('inventory', l.dashboardInventory),
                  ('favorites', l.dashboardFavorites),
                ])
                  CheckedPopupMenuItem(
                    value: pair.$1,
                    checked: sections.contains(pair.$1),
                    enabled: ref.read(dashboardSectionsProvider.notifier).ready,
                    child: Text(pair.$2),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (Platform.isWindows)
              _action(
                l.steamSwitchTitle,
                Icons.switch_account_outlined,
                'steam-client',
              ),
            _action(l.dashboardMarket, Icons.storefront_outlined, 'market'),
            _action(l.friendsTitle, Icons.people_outline, 'friends'),
            _action(l.pendingTitle, Icons.fact_check_outlined, 'confirm'),
            SteamNotificationsButton(
              account: widget.account,
              onPressed: () => widget.onAction('notifications'),
            ),
            _action(l.backupCodesTitle, Icons.key_outlined, 'backup-codes'),
          ],
        ),
        if (_needsLogin)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(l.sessionExpired)),
                TextButton(
                  onPressed: () => signInThen(widget.account, _load),
                  child: Text(l.loginButton),
                ),
              ],
            ),
          ),
        if (sections.contains('wallet')) ...[
          const SizedBox(height: 20),
          AvaPanel(
            emphasized: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.dashboardWallet)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_data.wallet.loading) _progress('wallet'),
                Text(
                  balanceText,
                  key: const ValueKey('wallet-balance'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if ((_wallet?.delayedBalance ?? 0) > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l.dashboardPendingBalance}: ${formatSteamMoney(_wallet!.delayedBalance!, _wallet!.currency)}',
                  ),
                ],
                if (_walletFailed && !_needsLogin) Text(l.dashboardFetchFailed),
              ],
            ),
          ),
        ],
        if (sections.contains('listings')) ...[
          const SizedBox(height: 20),
          AvaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      l.marketTabListings,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => widget.onAction('listings'),
                      child: Text(l.dashboardViewAll),
                    ),
                  ],
                ),
                if (_data.listings.loading) _progress('listings'),
                if (_listings != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final state in [
                        MarketListingState.active,
                        MarketListingState.onHold,
                        MarketListingState.pendingConfirmation,
                      ])
                        Chip(
                          label: Text(
                            '${marketListingStateLabel(l, state)} ${_listings!.where((entry) => entry.state == state).length}',
                          ),
                        ),
                    ],
                  ),
                  if (_listings!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l.dashboardNoListings),
                    ),
                  for (final listing in _listings!.take(6))
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: listing.iconUrl.isEmpty
                              ? const Icon(Icons.inventory_2_outlined)
                              : Image.network(
                                  listing.iconUrl,
                                  fit: BoxFit.contain,
                                  cacheWidth: context.rCache(44),
                                  cacheHeight: context.rCache(44),
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.inventory_2_outlined),
                                ),
                        ),
                        title: Text(
                          listing.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          marketListingStateLabel(l, listing.state),
                        ),
                        trailing:
                            !listing.priceAvailable || listing.currency == null
                            ? null
                            : Text(
                                formatSteamMoney(
                                  listing.buyerPrice,
                                  listing.currency!,
                                ),
                              ),
                        onTap: () => widget.onAction('listings'),
                      ),
                    ),
                ] else if (!_data.listings.loading)
                  Text(
                    _listingsFailed
                        ? l.dashboardFetchFailed
                        : l.dashboardUnavailable,
                  ),
              ],
            ),
          ),
        ],
        if (sections.any(
          const {'favorites', 'friends', 'inventory'}.contains,
        )) ...[
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                if (sections.contains('favorites'))
                  DashboardFavoritesCard(
                    account: widget.account,
                    active: _active && available,
                    reload: _favoritesReload,
                    onViewAll: () => widget.onAction('favorites'),
                  ),
                if (sections.contains('friends')) _friendsCard(l),
                if (sections.contains('inventory')) _inventoryCard(l),
              ];
              final columns = (constraints.maxWidth / 340).floor().clamp(
                1,
                cards.length,
              );
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
        ],
        if (sections.contains('tools')) ...[
          const SizedBox(height: 20),
          AvaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dashboardTools,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _action(
                      l.deviceSessionsAction,
                      Icons.devices_outlined,
                      'devices',
                    ),
                    _action(
                      l.famAccountAction,
                      Icons.family_restroom,
                      'family',
                    ),
                    _action(l.keyRedeemAction, Icons.redeem_outlined, 'redeem'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cardHeader(String title, VoidCallback onViewAll) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      TextButton(
        onPressed: onViewAll,
        child: Text(AppLocalizations.of(context).dashboardViewAll),
      ),
    ],
  );

  Widget _friendsCard(AppLocalizations l) {
    final friends = _data.friends.value;
    final online = friends?.where(
      (friend) => friend.state != SteamFriendState.offline,
    );
    final preview = friends == null
        ? const <SteamFriend>[]
        : [
            ...online!.take(4),
            ...friends
                .where((friend) => friend.state == SteamFriendState.offline)
                .take(4),
          ].take(4);
    return AvaPanel(
      key: const ValueKey('dashboard-friends'),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader(l.dashboardFriends, () => widget.onAction('friends')),
            if (_data.friends.loading) _progress('friends'),
            if (friends != null) ...[
              Text(l.dashboardFriendsSummary(friends.length, online!.length)),
              if (friends.isEmpty) Text(l.dashboardFriendsEmpty),
              for (final friend in preview)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    friend.state == SteamFriendState.playing
                        ? Icons.sports_esports_outlined
                        : Icons.person_outline,
                    color: friend.state == SteamFriendState.offline
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    friend.game.isNotEmpty
                        ? friend.game
                        : switch (friend.state) {
                            SteamFriendState.offline => l.friendsOffline,
                            SteamFriendState.online => l.friendsOnline,
                            SteamFriendState.playing => l.friendsPlaying,
                          },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => widget.onAction('friends'),
                ),
              if (friends.length > 4) Text(l.dashboardCardsLimited(4)),
            ] else if (!_data.friends.loading)
              Text(
                _data.friends.failed
                    ? l.dashboardFetchFailed
                    : l.dashboardUnavailable,
              ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryCard(AppLocalizations l) {
    final games = _data.inventory.value?.games;
    return AvaPanel(
      key: const ValueKey('dashboard-inventory'),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader(l.dashboardInventory, () => widget.onAction('market')),
            if (_data.inventory.loading) _progress('inventory'),
            if (games != null) ...[
              Text(
                l.dashboardInventorySummary(
                  games.length,
                  games.fold<int>(0, (sum, game) => sum + game.itemCount),
                ),
              ),
              if (games.isEmpty) Text(l.dashboardInventoryEmpty),
              for (final game in games.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    game.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('${game.itemCount}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MarketScreen(
                        account: widget.account,
                        initialAppId: game.appid,
                        initialContextId: game.contextId,
                      ),
                    ),
                  ),
                ),
              if (games.length > 4) Text(l.dashboardCardsLimited(4)),
            ] else if (!_data.inventory.loading)
              Text(
                _data.inventory.failed
                    ? l.dashboardFetchFailed
                    : l.dashboardUnavailable,
              ),
          ],
        ),
      ),
    );
  }

  Widget _action(String label, IconData icon, String value) =>
      OutlinedButton.icon(
        onPressed: () => widget.onAction(value),
        icon: Icon(icon, size: 18),
        label: value != 'confirm'
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label)),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: PendingConfirmationBadge(
                      account: widget.account,
                      showIcon: false,
                    ),
                  ),
                ],
              ),
      );
}

class AccountDashboardScreen extends StatelessWidget {
  final SteamGuardAccount account;
  final ValueChanged<String> onAction;
  const AccountDashboardScreen({
    super.key,
    required this.account,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AccountIdentityMenu(
        account: account,
        child: Text(
          account.personaName ?? account.accountName ?? '${account.steamId}',
        ),
      ),
    ),
    body: ListView(
      padding: context.rSafeInsets(all: 20),
      children: [
        SelectableText(
          'SteamID ${account.steamId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        AccountDashboard(account: account, onAction: onAction),
      ],
    ),
  );
}
