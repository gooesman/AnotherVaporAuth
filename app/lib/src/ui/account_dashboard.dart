import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../core/models/steam_guard_account.dart';
import '../core/models/steam_item.dart';
import '../core/steam_currency.dart';
import '../services/account_dashboard_loader.dart';
import 'market/market_screen.dart' show marketListingStateLabel;
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/account_identity_menu.dart';
import 'widgets/pending_confirmation_badge.dart';
import 'widgets/steam_notifications_button.dart';

final dashboardSectionsProvider =
    NotifierProvider<DashboardSections, Set<String>>(DashboardSections.new);

final accountDashboardLoaderProvider = Provider<AccountDashboardLoader>((ref) {
  final controller = ref.read(appControllerProvider.notifier);
  final loader = AccountDashboardLoader(
    inventory: ref.read(inventoryClientProvider),
    market: ref.read(marketClientProvider),
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

class DashboardSections extends Notifier<Set<String>> {
  static const defaults = {'wallet', 'listings', 'tools'};
  int _revision = 0;
  bool ready = false;
  @override
  Set<String> build() {
    ready = false;
    final generation = _revision;
    ref
        .read(settingsStoreProvider)
        .loadDashboardSections()
        .then((saved) {
          if (ref.mounted && generation == _revision) {
            ready = true;
            state = saved?.where(defaults.contains).toSet() ?? {...defaults};
          }
        })
        .catchError((Object _) {
          if (ref.mounted && generation == _revision) {
            ready = true;
            state = {...state};
          }
        });
    return {...defaults};
  }

  Future<void> toggle(String section) async {
    if (!defaults.contains(section)) return;
    ready = true;
    _revision++;
    final next = {...state};
    if (!next.remove(section)) next.add(section);
    await ref.read(settingsStoreProvider).saveDashboardSections(next.toList());
    if (ref.mounted) state = next;
  }
}

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
    with SessionRetryState {
  late final AccountDashboardLoader _loader;
  DashboardLease? _lease;
  DashboardData get _data => _lease!.data;
  WalletInfo? get _wallet => _data.wallet.value;
  List<MarketListing>? get _listings => _data.listings.value;
  bool get _walletFailed => _data.wallet.failed;
  bool get _listingsFailed => _data.listings.failed;
  bool get _needsLogin =>
      (_lease!.wallet && _data.wallet.needsLogin) ||
      (_lease!.listings && _data.listings.needsLogin);
  bool get _busy =>
      (_lease!.wallet && _data.wallet.loading) ||
      (_lease!.listings && _data.listings.loading);

  @override
  void initState() {
    super.initState();
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
    _bind(ref.read(dashboardSectionsProvider));
  }

  void _bind(Set<String> sections) {
    final app = ref.read(appControllerProvider).value;
    final available =
        app != null &&
        !app.locked &&
        app.visibleAccounts.any(
          (account) =>
              account.steamId == widget.account.steamId &&
              account.fromPortable == widget.account.fromPortable &&
              account.accountName == widget.account.accountName,
        );
    final ready =
        ref.read(dashboardSectionsProvider.notifier).ready && available;
    final wallet = ready && sections.contains('wallet');
    final listings = ready && !widget.compact && sections.contains('listings');
    final previous = _lease;
    if (previous != null &&
        _loader.matches(previous, widget.account) &&
        previous.wallet == wallet &&
        previous.listings == listings) {
      return;
    }
    previous?.data.removeListener(_changed);
    // Retain the next view before releasing the old one, so a layout change
    // never cancels a read that is still useful to the same account.
    _lease = _loader.acquire(
      widget.account,
      wallet: wallet,
      listings: listings,
    );
    previous?.release();
    _data.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _load() => _lease?.refresh();

  @override
  void dispose() {
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
    ref.watch(appControllerProvider.select((state) => state.value?.locked));
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
                ])
                  CheckedPopupMenuItem(
                    value: pair.$1,
                    checked: sections.contains(pair.$1),
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
