import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/market_search.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_item.dart';
import '../../core/protocol/market_client.dart';
import '../../core/steam_currency.dart';
import '../../services/steam_api_client.dart';
import '../../services/steam_request_scope.dart';
import '../error_text.dart';
import '../widgets/steam_image_provider.dart';
import 'item_market_actions.dart';
import 'market_search_prices.dart';

typedef _AccountKey = (int, bool, String?, String?, String?, Object?);
typedef _Query = ({String text, int? appid, int currency, String language});
typedef _PageKey = (_Query, int);

_AccountKey _accountKey(SteamGuardAccount account) => (
  account.steamId,
  account.fromPortable,
  account.accountName,
  account.session.accessToken,
  account.session.refreshToken,
  account.steamId == 0 ? account : null,
);

/// Explicit, read-only market discovery. Mounting, typing and selecting filters
/// never start requests. The page owns its bounded cache and request lifetimes.
class MarketSearchTab extends ConsumerStatefulWidget {
  const MarketSearchTab({
    super.key,
    required this.account,
    required this.active,
    this.reload = 0,
    this.initialCurrency,
  });

  final SteamGuardAccount account;
  final bool active;
  final int reload;
  final int? initialCurrency;

  @override
  ConsumerState<MarketSearchTab> createState() => _MarketSearchTabState();
}

class _MarketSearchTabState extends ConsumerState<MarketSearchTab>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _cache = <_PageKey, (DateTime, MarketSearchPage)>{};
  late _AccountKey _account;
  late MarketClient _client;
  late MarketSearchPrices _prices;
  String? _locale;
  String? _language;
  int? _currency;
  int? _appid;
  _Query? _submitted;
  List<MarketSearchItem> _items = const [];
  SteamRequestScope? _scope;
  int _generation = 0;
  int _nextStart = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _foreground = true;
  Object? _error;
  int? _retryStart;
  _DetailLifetime? _details;
  DialogRoute<void>? _detailRoute;
  NavigatorState? _detailNavigator;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _account = _accountKey(widget.account);
    _client = ref.read(marketClientProvider);
    _prices = _newPrices(_client);
    WidgetsBinding.instance.addObserver(this);
  }

  MarketSearchPrices _newPrices(MarketClient client) => MarketSearchPrices(
    ItemMarketPriceCache(client, now: ref.read(clockProvider), checked: true),
    now: ref.read(clockProvider),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    _currency ??=
        widget.initialCurrency != null &&
            widget.initialCurrency! >= 1 &&
            widget.initialCurrency! <= 32
        ? widget.initialCurrency!
        : locale.languageCode == 'zh'
        ? 23
        : 1;
    final tag = locale.toLanguageTag();
    if (_locale != null &&
        (_locale != tag || _language != _client.api.steamLanguage)) {
      _reset(clearCache: true);
    }
    _locale = tag;
    _language = _client.api.steamLanguage;
  }

  @override
  void didUpdateWidget(MarketSearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final account = _accountKey(widget.account);
    if (_account != account || _language != _client.api.steamLanguage) {
      _account = account;
      _language = _client.api.steamLanguage;
      _text.clear();
      _reset(clearCache: true);
    } else if (!widget.active) {
      _cancel();
    } else if (widget.reload != oldWidget.reload && _submitted != null) {
      _load(_submitted!, 0, force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() {
        _foreground = state == AppLifecycleState.resumed;
        if (!_foreground) _cancel();
      });
    }
  }

  void _closeDetails() {
    _details?.cancel();
    _details = null;
    final route = _detailRoute;
    final navigator = _detailNavigator;
    _detailRoute = null;
    _detailNavigator = null;
    if (route != null && navigator != null) {
      // Account/tab changes can arrive while the parent is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
  }

  void _cancel() {
    _generation++;
    _scope?.cancel();
    _scope = null;
    _loading = false;
    _prices.reset();
    _closeDetails();
  }

  void _reset({bool clearCache = false}) {
    _cancel();
    _submitted = null;
    _items = const [];
    _nextStart = 0;
    _hasMore = false;
    _error = null;
    _retryStart = null;
    if (clearCache) _cache.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    _prices.dispose();
    _cache.clear();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _current(int generation, _Query query, MarketClient client) =>
      mounted &&
      widget.active &&
      generation == _generation &&
      _account == _accountKey(widget.account) &&
      identical(client, ref.read(marketClientProvider)) &&
      client.api.steamLanguage == query.language;

  Future<void> _submit() async {
    if (!widget.active || _text.text.trim().isEmpty) return;
    // Accounts and the shared client's language can also change in place.
    final account = _accountKey(widget.account);
    if (_account != account || _language != _client.api.steamLanguage) {
      _account = account;
      _language = _client.api.steamLanguage;
      _reset(clearCache: true);
    }
    final query = (
      text: _text.text.trim(),
      appid: _appid,
      currency: _currency!,
      language: _client.api.steamLanguage,
    );
    if (_loading && _submitted == query) return;
    FocusScope.of(context).unfocus();
    await _load(query, 0);
  }

  Future<void> _load(_Query query, int start, {bool force = false}) async {
    if (!widget.active || query.text.isEmpty) return;
    if (_loading && !force) return;
    _cancel();
    final generation = _generation;
    final client = _client;
    final scope = SteamRequestScope();
    final key = (query, start);
    final now = ref.read(clockProvider)();
    if (force) {
      _cache.removeWhere((key, _) => key.$1 == query);
      _prices.cache.clear();
    }
    final cached = _cache.remove(key);
    final cachedPage = cached != null && now.isBefore(cached.$1)
        ? cached.$2
        : null;
    if (cachedPage != null) _cache[key] = cached!;
    setState(() {
      _scope = scope;
      _submitted = query;
      _error = null;
      _retryStart = start;
      _loading = true;
      if (start == 0) {
        _items = const [];
        _hasMore = false;
        _nextStart = 0;
      }
    });
    try {
      final MarketSearchPage page =
          cachedPage ??
          await scope.run<MarketSearchPage>(
            () => client.search(
              query: query.text,
              appid: query.appid,
              currency: query.currency,
              start: start,
              count: 20,
            ),
          );
      if (!_current(generation, query, client)) return;
      final unique = <(int, String), MarketSearchItem>{
        if (start > 0)
          for (final item in _items) (item.appid, item.marketHashName): item,
      };
      final previousCount = unique.length;
      for (final item in page.items) {
        unique[(item.appid, item.marketHashName)] = item;
      }
      if (page.start != start ||
          (page.hasMore && page.nextStart <= start) ||
          (start > 0 && page.hasMore && unique.length == previousCount)) {
        throw const FormatException('Market pagination did not advance');
      }
      if (cachedPage == null) {
        _cache[key] = (
          ref.read(clockProvider)().add(const Duration(minutes: 5)),
          page,
        );
        while (_cache.length > 12) {
          _cache.remove(_cache.keys.first);
        }
      }
      setState(() {
        _items = unique.values.toList(growable: false);
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
        _retryStart = null;
      });
    } catch (error) {
      if (_current(generation, query, client)) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          if (!_current(generation, query, client)) {
            _account = _accountKey(widget.account);
            _language = _client.api.steamLanguage;
            _reset(clearCache: true);
          } else {
            _scope = null;
            _loading = false;
          }
        });
      }
    }
  }

  Future<void> _showDetails(MarketSearchItem item) async {
    if (!widget.active || _details != null) return;
    final generation = _generation;
    final query = _submitted!;
    final client = _client;
    final initialPrice = _prices.quote((
      item.appid,
      item.marketHashName,
      query.currency,
      query.language,
    )).price;
    final lifetime = _DetailLifetime(
      () => _current(generation, query, client),
      _closeDetails,
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => _MarketItemDetails(
        item: item,
        currency: query.currency,
        client: client,
        lifetime: lifetime,
        cache: _prices.cache,
        initialPrice: initialPrice,
      ),
    );
    _details = lifetime;
    _detailRoute = route;
    _detailNavigator = navigator;
    _prices.reset();
    setState(() {});
    await navigator.push(route);
    lifetime.cancel();
    if (identical(_details, lifetime)) {
      _details = null;
      _detailRoute = null;
      _detailNavigator = null;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(marketClientProvider, (_, client) {
      setState(() {
        _client = client;
        _language = client.api.steamLanguage;
        _reset(clearCache: true);
        _prices.dispose();
        _prices = _newPrices(client);
      });
    });
    final l = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    return CustomScrollView(
      key: const ValueKey('market-search-scroll'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: context.rSafeInsets(all: 16).copyWith(bottom: 8),
          sliver: SliverToBoxAdapter(child: _form(l)),
        ),
        if (_submitted == null)
          SliverToBoxAdapter(child: _message(l.marketSearchEmpty))
        else if (!_loading &&
            _error == null &&
            _retryStart == null &&
            _items.isEmpty)
          SliverToBoxAdapter(child: _message(l.marketSearchNoResults)),
        SliverPadding(
          padding: context.rSafeInsets(h: 16).copyWith(top: 0, bottom: 0),
          sliver: SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Card(
                key: ValueKey(
                  'market-result-${item.appid}-${item.marketHashName}',
                ),
                margin: EdgeInsets.only(bottom: context.r(8)),
                child: ListTile(
                  contentPadding: context.rInsets(all: 12),
                  leading: _MarketThumbnail(item: item, size: context.r(48)),
                  title: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.type.isNotEmpty)
                        Text(
                          item.type,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      _VisibleMarketPrice(
                        item: item,
                        prices: _prices,
                        currency: _submitted!.currency,
                        language: _submitted!.language,
                        active:
                            widget.active && _foreground && _details == null,
                      ),
                      Text(l.marketSearchListings(item.listingCount)),
                    ],
                  ),
                  onTap: () => _showDetails(item),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: context.rSafeInsets(all: 16).copyWith(top: 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      key: ValueKey('market-search-loading'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_error != null) _message(_searchError(l, _error!)),
                if (!_loading &&
                    _submitted != null &&
                    (_hasMore || _retryStart != null))
                  TextButton(
                    key: const ValueKey('market-search-more'),
                    onPressed: widget.active
                        ? () => _load(_submitted!, _retryStart ?? _nextStart)
                        : null,
                    child: Text(
                      _retryStart != null ? l.commonRetry : l.marketSearchMore,
                    ),
                  ),
                if (_submitted != null)
                  Text(
                    l.marketSearchPriceNote,
                    style: TextStyle(color: tokens.muted),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _message(String text) => Padding(
    padding: context.rInsets(all: 16),
    child: Text(text, textAlign: TextAlign.center),
  );

  Widget _form(AppLocalizations l) {
    final game = DropdownButtonFormField<int>(
      key: const ValueKey('market-search-game'),
      initialValue: _appid ?? 0,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.marketSearchGame),
      items: [
        DropdownMenuItem(value: 0, child: Text(l.marketSearchAllGames)),
        for (final (id, name) in const [
          (730, 'Counter-Strike 2'),
          (570, 'Dota 2'),
          (753, 'Steam'),
          (440, 'Team Fortress 2'),
        ])
          DropdownMenuItem(value: id, child: Text(name)),
      ],
      onChanged: (value) => setState(() {
        _appid = value == 0 ? null : value;
        _reset();
      }),
    );
    final currency = DropdownButtonFormField<int>(
      key: const ValueKey('market-search-currency'),
      initialValue: _currency,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.marketSearchCurrency),
      items: [
        for (var currency = 1; currency <= 32; currency++)
          DropdownMenuItem(
            value: currency,
            child: Text(steamCurrencyCode(currency)),
          ),
      ],
      onChanged: (value) => setState(() {
        _currency = value!;
        final submitted = _submitted;
        if (submitted != null && _items.isNotEmpty) {
          // Search identities do not depend on currency. Keep the list and
          // immediately quote its visible rows again, without another search.
          _cancel();
          _submitted = (
            text: submitted.text,
            appid: submitted.appid,
            currency: value,
            language: submitted.language,
          );
        } else {
          _reset();
        }
      }),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 500
              ? Column(children: [game, const SizedBox(height: 12), currency])
              : Row(
                  children: [
                    Expanded(child: game),
                    const SizedBox(width: 12),
                    SizedBox(width: 180, child: currency),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('market-search-query'),
          controller: _text,
          decoration: InputDecoration(
            labelText: l.marketSearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(_reset),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('market-search-submit'),
            onPressed:
                widget.active && !_loading && _text.text.trim().isNotEmpty
                ? _submit
                : null,
            icon: const Icon(Icons.search),
            label: Text(l.marketSearchButton),
          ),
        ),
      ],
    );
  }
}

String _searchError(AppLocalizations l, Object error) {
  if (error is SteamApiException) {
    return error.httpStatus == 429 || error.eresult == 84
        ? l.marketSearchRateLimited
        : l.marketSearchUnavailable;
  }
  if (error is FormatException) return l.marketSearchUnavailable;
  return describeError(l, error);
}

/// Sliver builders also create offscreen cache children. Check actual viewport
/// intersection after layout, so these children never prefetch market quotes.
class _VisibleMarketPrice extends StatefulWidget {
  const _VisibleMarketPrice({
    required this.item,
    required this.prices,
    required this.currency,
    required this.language,
    required this.active,
  });
  final MarketSearchItem item;
  final MarketSearchPrices prices;
  final int currency;
  final String language;
  final bool active;

  @override
  State<_VisibleMarketPrice> createState() => _VisibleMarketPriceState();
}

class _VisibleMarketPriceState extends State<_VisibleMarketPrice> {
  final _owner = Object();
  ScrollPosition? _position;
  bool _scheduled = false;
  bool _inViewport = false;

  MarketSearchPriceKey get _key => (
    widget.item.appid,
    widget.item.marketHashName,
    widget.currency,
    widget.language,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(_VisibleMarketPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prices != widget.prices) {
      oldWidget.prices.visible(_owner, null);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      var visible = false;
      if (widget.active &&
          widget.item.listingCount > 0 &&
          box is RenderBox &&
          box.hasSize &&
          box.attached) {
        final viewport = RenderAbstractViewport.maybeOf(box);
        final viewportBox = viewport is RenderBox
            ? viewport as RenderBox
            : null;
        if (viewportBox != null && viewportBox.hasSize) {
          final rect =
              box.localToGlobal(Offset.zero, ancestor: viewportBox) & box.size;
          visible = rect.overlaps(Offset.zero & viewportBox.size);
        }
      }
      widget.prices.visible(_owner, visible ? _key : null);
      if (_inViewport != visible) setState(() => _inViewport = visible);
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    widget.prices.visible(_owner, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.prices,
    builder: (context, _) {
      _schedule();
      final l = AppLocalizations.of(context);
      final quote = widget.prices.quote(_key);
      final price = quote.price?.lowest?.trim();
      if (quote.loading &&
          widget.active &&
          _inViewport &&
          widget.item.listingCount > 0) {
        return Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text(steamCurrencyCode(widget.currency)),
          ],
        );
      }
      if (price?.isNotEmpty == true) {
        return Text(
          price!,
          style: TextStyle(
            color: Theme.of(context).extension<AvaTokens>()!.accent,
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: Text(
              quote.error == null
                  ? l.marketSearchPriceUnavailable
                  : _searchError(l, quote.error!),
            ),
          ),
          IconButton(
            tooltip: l.commonRetry,
            onPressed: () => widget.prices.retry(_key),
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      );
    },
  );
}

class _MarketThumbnail extends StatelessWidget {
  const _MarketThumbnail({required this.item, required this.size});
  final MarketSearchItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final hex = item.rarityColor.replaceFirst('#', '');
    final rgb = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)
        ? int.tryParse(hex, radix: 16)
        : null;
    final color = rgb == null ? null : Color(0xff000000 | rgb);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.06) ?? t.panel2,
        border: Border.all(
          color: color?.withValues(alpha: 0.5) ?? t.borderColor,
        ),
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusSm),
        child: item.iconUrl.isEmpty
            ? const Icon(Icons.inventory_2_outlined)
            : Image(
                image: steamThumbnailProvider(
                  item.iconUrl,
                  logicalSize: Size.square(size),
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.inventory_2_outlined),
              ),
      ),
    );
  }
}

class _DetailLifetime {
  _DetailLifetime(this.isCurrent, this.onInvalid);
  final bool Function() isCurrent;
  final VoidCallback onInvalid;
  bool _cancelled = false;
  SteamRequestScope? scope;
  bool get valid {
    if (_cancelled) return false;
    if (isCurrent()) return true;
    cancel();
    onInvalid();
    return false;
  }

  void cancel() {
    _cancelled = true;
    scope?.cancel();
    scope = null;
  }
}

class _MarketItemDetails extends ConsumerStatefulWidget {
  const _MarketItemDetails({
    required this.item,
    required this.currency,
    required this.client,
    required this.lifetime,
    required this.cache,
    this.initialPrice,
  });
  final MarketSearchItem item;
  final int currency;
  final MarketClient client;
  final _DetailLifetime lifetime;
  final ItemMarketPriceCache cache;
  final MarketPrice? initialPrice;

  @override
  ConsumerState<_MarketItemDetails> createState() => _MarketItemDetailsState();
}

class _MarketItemDetailsState extends ConsumerState<_MarketItemDetails> {
  bool _loading = false;
  bool _opening = false;
  bool _checked = false;
  MarketPrice? _price;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _price = widget.initialPrice;
    _checked = _price != null;
    final hasQuote =
        _price?.lowest?.trim().isNotEmpty == true ||
        _price?.median?.trim().isNotEmpty == true;
    if (!hasQuote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.lifetime.valid) _refresh(invalidateCache: false);
      });
    }
  }

  @override
  void dispose() {
    widget.lifetime.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool invalidateCache = true}) async {
    if (_loading || !widget.lifetime.valid) return;
    final scope = SteamRequestScope();
    widget.lifetime.scope = scope;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (invalidateCache) {
        widget.cache.invalidate(
          widget.item.appid,
          widget.item.marketHashName,
          widget.currency,
        );
      }
      final price = await scope.run(
        () => widget.cache.lookup(
          widget.item.appid,
          widget.item.marketHashName,
          widget.currency,
        ),
      );
      if (mounted && widget.lifetime.valid) {
        setState(() {
          _price = price;
          _checked = true;
        });
      }
    } catch (error) {
      if (mounted && widget.lifetime.valid) setState(() => _error = error);
    } finally {
      if (mounted && widget.lifetime.valid) setState(() => _loading = false);
      if (identical(widget.lifetime.scope, scope)) widget.lifetime.scope = null;
    }
  }

  Future<void> _open() async {
    if (_opening || !widget.lifetime.valid) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await ref.read(itemMarketLauncherProvider)(
        Uri(
          scheme: 'https',
          host: 'steamcommunity.com',
          pathSegments: [
            'market',
            'listings',
            '${widget.item.appid}',
            widget.item.marketHashName,
          ],
        ),
      );
    } catch (_) {}
    if (!mounted || !widget.lifetime.valid) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).itemMarketOpenFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    final lowest = _price?.lowest?.trim();
    final median = _price?.median?.trim();
    return AlertDialog(
      key: const ValueKey('market-search-details'),
      title: Text(widget.item.name),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          padding: context.rSafeInsets(all: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MarketThumbnail(item: widget.item, size: context.r(96)),
              const SizedBox(height: 12),
              if (widget.item.type.isNotEmpty) Text(widget.item.type),
              Text(
                l.marketSearchRequestedCurrency(
                  steamCurrencyCode(widget.currency),
                ),
              ),
              Text(l.marketSearchListings(widget.item.listingCount)),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (lowest?.isNotEmpty == true)
                Text('${l.marketLowest}: $lowest'),
              if (median?.isNotEmpty == true)
                Text('${l.marketMedian}: $median'),
              if (_checked &&
                  lowest?.isNotEmpty != true &&
                  median?.isNotEmpty != true)
                Text(l.marketSearchPriceUnavailable),
              if (_price?.volume != null)
                Text('${l.itemMarketVolume}: ${_price!.volume}'),
              if (_error != null) Text(_searchError(l, _error!)),
              TextButton.icon(
                key: const ValueKey('market-search-refresh-price'),
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l.marketSearchRefreshPrice),
              ),
              Text(l.marketSearchPriceNote, style: TextStyle(color: t.muted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _opening ? null : _open,
          child: Text(l.itemMarketOpen),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    );
  }
}
