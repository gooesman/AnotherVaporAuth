import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_item.dart';
import '../../core/protocol/market_client.dart';
import '../../core/steam_currency.dart';

typedef _PriceKey = (int, String, int, String);

/// A small, memory-only cache for explicit, read-only price lookups. Identical
/// copies share a request; failures briefly cool down instead of hammering Steam.
class ItemMarketPriceCache {
  ItemMarketPriceCache(this.client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MarketClient client;
  final DateTime Function() _now;
  final _values = <_PriceKey, (DateTime, MarketPrice?)>{};
  final _pending = <_PriceKey, Future<MarketPrice?>>{};

  Future<MarketPrice?> lookup(int appid, String hashName, int currency) {
    if (appid <= 0 || hashName.trim().isEmpty || currency <= 0) {
      return Future.value(null);
    }
    final key = (appid, hashName, currency, client.api.steamLanguage);
    final pending = _pending[key];
    if (pending != null) return pending;
    final cached = _values[key];
    if (cached != null && _now().isBefore(cached.$1)) {
      return Future.value(cached.$2);
    }
    final request = _fetch(key).whenComplete(() {
      _pending.remove(key);
    });
    _pending[key] = request;
    return request;
  }

  Future<MarketPrice?> _fetch(_PriceKey key) async {
    MarketPrice? price;
    try {
      price = await client.priceOverview(key.$1, key.$2, key.$3);
    } catch (_) {
      // The read-only advisory price must never disrupt inventory selection.
    }
    final hasPrice =
        _nonblank(price?.lowest) != null || _nonblank(price?.median) != null;
    if (_values.length >= 256) _values.remove(_values.keys.first);
    _values[key] = (
      _now().add(
        hasPrice ? const Duration(minutes: 5) : const Duration(seconds: 30),
      ),
      price,
    );
    return price;
  }
}

final itemMarketPriceCacheProvider = Provider<ItemMarketPriceCache>(
  (ref) => ItemMarketPriceCache(ref.watch(marketClientProvider)),
);

final itemMarketLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Construct the listing address from path segments, never by interpolating a
/// market hash name into a URL (item names can contain slashes, #, ? and %).
Uri itemMarketListingUri(InventoryItem item) => Uri(
  scheme: 'https',
  host: 'steamcommunity.com',
  pathSegments: ['market', 'listings', '${item.appid}', item.marketHashName],
);

String? _nonblank(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

enum _MarketAction { price, open }

/// Adds read-only market actions without taking over the inventory's primary
/// tap. Desktop right-click, mobile long-press and a visible overflow button all
/// open the same menu. [builder] receives a label only after an explicit lookup.
class ItemMarketActions extends ConsumerStatefulWidget {
  const ItemMarketActions({
    super.key,
    required this.item,
    required this.currency,
    required this.builder,
  });

  final InventoryItem item;
  final int currency;
  final Widget Function(
    BuildContext context,
    Widget? priceLabel,
    VoidCallback showActions,
  )
  builder;

  @override
  ConsumerState<ItemMarketActions> createState() => _ItemMarketActionsState();
}

class _ItemMarketActionsState extends ConsumerState<ItemMarketActions> {
  _PriceKey? _shownKey;
  ItemMarketPriceCache? _shownCache;
  MarketPrice? _price;
  bool _hasPriceResult = false;
  bool _menuOpen = false;
  bool _opening = false;

  int get _currency =>
      widget.currency > 0 ? widget.currency : WalletInfo.fallback.currency;

  bool get _hasIdentity =>
      widget.item.appid > 0 && widget.item.marketHashName.trim().isNotEmpty;

  _PriceKey _key(ItemMarketPriceCache cache) => (
    widget.item.appid,
    widget.item.marketHashName,
    _currency,
    cache.client.api.steamLanguage,
  );

  Future<void> _showActions([Offset? position]) async {
    if (_menuOpen || !mounted) return;
    final l = AppLocalizations.of(context);
    final cache = ref.read(itemMarketPriceCacheProvider);
    final key = _key(cache);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final globalPosition =
        position ?? box.localToGlobal(box.size.center(Offset.zero));
    final localPosition = overlay.globalToLocal(globalPosition);
    _menuOpen = true;
    final result = await showMenu<_MarketAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localPosition.dx, localPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          key: const ValueKey('item-market-view-price'),
          value: _MarketAction.price,
          enabled: _hasIdentity,
          child: Text(l.itemMarketViewPrice),
        ),
        PopupMenuItem(
          key: const ValueKey('item-market-open'),
          value: _MarketAction.open,
          enabled: _hasIdentity,
          child: Text(l.itemMarketOpen),
        ),
        if (!_hasIdentity)
          PopupMenuItem(enabled: false, child: Text(l.itemMarketNoIdentity)),
      ],
    );
    _menuOpen = false;
    if (!mounted || key != _key(ref.read(itemMarketPriceCacheProvider))) return;
    switch (result) {
      case _MarketAction.price:
        await _showPrice();
      case _MarketAction.open:
        await _openMarket();
      case null:
        break;
    }
  }

  Future<void> _openMarket([InventoryItem? target]) async {
    if (!_hasIdentity || _opening) return;
    _opening = true;
    var opened = false;
    try {
      opened = await ref.read(itemMarketLauncherProvider)(
        itemMarketListingUri(target ?? widget.item),
      );
    } catch (_) {
      // Missing URI handlers and plugin failures use the same useful message.
    }
    _opening = false;
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).itemMarketOpenFailed),
        ),
      );
    }
  }

  Future<void> _showPrice() async {
    if (!_hasIdentity) return;
    final cache = ref.read(itemMarketPriceCacheProvider);
    final key = _key(cache);
    final item = widget.item;
    final currency = _currency;
    final future = cache.lookup(item.appid, item.marketHashName, currency);
    future.then((price) {
      if (!mounted ||
          !identical(cache, ref.read(itemMarketPriceCacheProvider)) ||
          key != _key(cache)) {
        return;
      }
      setState(() {
        _shownKey = key;
        _shownCache = cache;
        _price = price;
        _hasPriceResult = true;
      });
    });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l = AppLocalizations.of(dialogContext);
        final t = Theme.of(dialogContext).extension<AvaTokens>()!;
        return AlertDialog(
          title: Text(l.itemMarketViewPrice),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              padding: dialogContext.rSafeInsets(all: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.itemMarketCurrency(steamCurrencyCode(currency)),
                    style: TextStyle(color: t.muted),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<MarketPrice?>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LinearProgressIndicator();
                      }
                      final price = snapshot.data;
                      final lowest = _nonblank(price?.lowest);
                      final median = _nonblank(price?.median);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lowest != null)
                            Text('${l.marketLowest}: $lowest'),
                          if (median != null)
                            Text('${l.marketMedian}: $median'),
                          if (lowest == null && median == null)
                            Text(l.marketPriceUnavailable),
                          if (price?.volume != null && price!.volume! >= 0)
                            Text('${l.itemMarketVolume}: ${price.volume}'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.itemMarketReferenceNote,
                    style: TextStyle(color: t.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _openMarket(item),
              child: Text(l.itemMarketOpen),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.commonClose),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(itemMarketPriceCacheProvider);
    final l = AppLocalizations.of(context);
    Widget? priceLabel;
    if (_hasPriceResult &&
        _shownKey == _key(cache) &&
        identical(_shownCache, cache)) {
      final lowest = _nonblank(_price?.lowest);
      final median = _nonblank(_price?.median);
      final value = lowest ?? median;
      final text = value == null
          ? l.marketPriceUnavailable
          : '${lowest != null ? l.marketLowest : l.marketMedian}: $value · ${steamCurrencyCode(_currency)}';
      priceLabel = Tooltip(
        triggerMode: TooltipTriggerMode.manual,
        message: text,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).extension<AvaTokens>()!.muted,
            fontSize: 11,
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _showActions(details.globalPosition),
      onLongPressStart: (details) => _showActions(details.globalPosition),
      child: widget.builder(context, priceLabel, () => _showActions()),
    );
  }
}
