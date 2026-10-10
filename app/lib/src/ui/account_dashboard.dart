import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../core/models/steam_guard_account.dart';
import '../core/models/steam_item.dart';
import '../core/steam_currency.dart';
import 'market/market_screen.dart' show marketListingStateLabel;
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';

final dashboardSectionsProvider =
    NotifierProvider<DashboardSections, Set<String>>(DashboardSections.new);

class DashboardSections extends Notifier<Set<String>> {
  static const defaults = {'wallet', 'listings', 'tools'};
  int _revision = 0;
  @override
  Set<String> build() {
    final generation = _revision;
    ref
        .read(settingsStoreProvider)
        .loadDashboardSections()
        .then((saved) {
          if (ref.mounted && generation == _revision && saved != null) {
            state = saved.where(defaults.contains).toSet();
          }
        })
        .catchError((Object _) {});
    return {...defaults};
  }

  Future<void> toggle(String section) async {
    if (!defaults.contains(section)) return;
    _revision++;
    final next = {...state};
    if (!next.remove(section)) next.add(section);
    await ref.read(settingsStoreProvider).saveDashboardSections(next.toList());
    if (ref.mounted) state = next;
  }
}

/// Account-bound data is held in this state, never in the one-second TOTP
/// builder. Changing the selected account invalidates every in-flight result.
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
  WalletInfo? _wallet;
  List<MarketListing>? _listings;
  bool _walletFailed = false;
  bool _listingsFailed = false;
  bool _needsLogin = false;
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AccountDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account ||
        oldWidget.compact != widget.compact) {
      _wallet = null;
      _listings = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final account = widget.account;
    final inventory = ref.read(inventoryClientProvider);
    final market = ref.read(marketClientProvider);
    setState(() {
      _busy = true;
      _needsLogin = false;
      _walletFailed = false;
      _listingsFailed = false;
    });
    try {
      final wallet = await fetchWithAutoRefresh(
        account,
        () => inventory.wallet(account),
        retryOnAnyError: false,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _wallet = wallet);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _wallet = null;
        _walletFailed = true;
        _needsLogin = isAuthError(e);
      });
    }
    if (!mounted || generation != _generation) return;
    if (!widget.compact && !_needsLogin) {
      try {
        final listings = await fetchWithAutoRefresh(
          account,
          () => market.myListings(account),
          retryOnAnyError: false,
        );
        if (!mounted || generation != _generation) return;
        setState(() => _listings = listings);
      } catch (e) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _listings = null;
          _listingsFailed = true;
          _needsLogin = isAuthError(e);
        });
      }
    }
    if (mounted && generation == _generation) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = ref.watch(dashboardSectionsProvider);
    final balance = _wallet?.balance;
    final balanceText = balance == null
        ? (_busy ? '…' : l.dashboardUnavailable)
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
            _action(l.backupCodesTitle, Icons.key_outlined, 'backup-codes'),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
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
                    Text(l.dashboardWallet),
                  ],
                ),
                const SizedBox(height: 16),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.marketTabListings,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onAction('listings'),
                      child: Text(l.dashboardViewAll),
                    ),
                  ],
                ),
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
                ] else if (!_busy)
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
        label: Text(label),
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
      title: Text(
        account.personaName ?? account.accountName ?? '${account.steamId}',
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
