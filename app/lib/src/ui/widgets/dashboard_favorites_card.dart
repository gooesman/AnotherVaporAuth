import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/market_favorites.dart';
import '../../app/providers.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/protocol/market_client.dart';
import '../../core/steam_currency.dart';
import '../market/item_market_actions.dart';
import '../market/market_search_prices.dart';
import '../market/market_search_tab.dart'
    show MarketThumbnail, VisibleMarketPrice;
import 'ava_panel.dart';

typedef _AccountKey = (int, bool, String?, String?, String?, Object?);

_AccountKey _accountKey(SteamGuardAccount account) => (
  account.steamId,
  account.fromPortable,
  account.accountName,
  account.session.accessToken,
  account.session.refreshToken,
  account.steamId == 0 ? account : null,
);

/// A bounded preview of saved market identities, quoting visible rows only.
class DashboardFavoritesCard extends ConsumerStatefulWidget {
  const DashboardFavoritesCard({
    super.key,
    required this.account,
    required this.active,
    this.reload = 0,
    required this.onViewAll,
  });

  final SteamGuardAccount account;
  final bool active;
  final int reload;
  final VoidCallback onViewAll;

  @override
  ConsumerState<DashboardFavoritesCard> createState() =>
      _DashboardFavoritesCardState();
}

class _DashboardFavoritesCardState extends ConsumerState<DashboardFavoritesCard>
    with WidgetsBindingObserver {
  MarketSearchPrices? _prices;
  (_AccountKey, MarketClient, String, int)? _identity;
  List<(int, String)> _items = const [];
  bool _foreground = true;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(DashboardFavoritesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || widget.reload != oldWidget.reload) {
      _prices?.reset();
    }
    if (widget.reload != oldWidget.reload) _prices?.cache.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _prices?.reset();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prices?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = ref.watch(marketClientProvider);
    final favorites = ref.watch(marketFavoritesProvider);
    final saved = favorites.asData?.value;
    final currency =
        saved?.currency ??
        (Localizations.localeOf(context).languageCode == 'zh' ? 23 : 1);
    final identity = (
      _accountKey(widget.account),
      client,
      client.api.steamLanguage,
      currency,
    );
    if (_identity != identity) {
      _prices?.dispose();
      _prices = MarketSearchPrices(
        ItemMarketPriceCache(
          client,
          now: ref.read(clockProvider),
          checked: true,
        ),
        now: ref.read(clockProvider),
      );
      _identity = identity;
    }
    final items = saved?.items.take(4).toList() ?? const [];
    final keys = [for (final item in items) (item.appid, item.marketHashName)];
    final app = ref.watch(appControllerProvider).value;
    final available =
        app != null &&
        !app.locked &&
        app.visibleAccounts.any(
          (account) => _accountKey(account) == identity.$1,
        );
    final active = widget.active && _foreground && available;
    if (_active != active || !listEquals(_items, keys)) _prices!.reset();
    _active = active;
    _items = keys;

    return AvaPanel(
      key: const ValueKey('dashboard-favorites'),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star_border_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l.dashboardFavorites)),
                Flexible(
                  child: TextButton(
                    onPressed: widget.onViewAll,
                    child: Text(l.dashboardFavoritesMore),
                  ),
                ),
              ],
            ),
            if (favorites.isLoading)
              const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (favorites.hasError)
              Row(
                children: [
                  Expanded(child: Text(l.marketFavoriteSaveFailed)),
                  TextButton(
                    onPressed: () => ref.invalidate(marketFavoritesProvider),
                    child: Text(l.commonRetry),
                  ),
                ],
              )
            else if (items.isEmpty)
              Text(l.dashboardFavoritesEmpty)
            else ...[
              Text(l.dashboardFavoritesPriceNote(steamCurrencyCode(currency))),
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  key: ValueKey(
                    'dashboard-favorite-${item.appid}-${item.marketHashName}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: MarketThumbnail(item: item, size: 40),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: VisibleMarketPrice(
                    item: item,
                    prices: _prices!,
                    currency: currency,
                    language: client.api.steamLanguage,
                    active: active,
                    quoteWithoutListingCount: true,
                  ),
                  onTap: widget.onViewAll,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
