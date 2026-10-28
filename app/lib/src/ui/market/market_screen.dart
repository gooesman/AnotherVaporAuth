import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/inventory_filter.dart';
import '../../core/models/steam_item.dart';
import '../../core/protocol/inventory_client.dart';
import '../../core/steam_currency.dart';
import '../../services/auto_login.dart';
import '../../services/steam_api_client.dart' show CommunityAuthException;
import '../pending/session_retry.dart';
import '../widgets/inventory_item_icon.dart';
import '../widgets/inventory_filter_bar.dart';
import '../widgets/inventory_cooldown_info.dart';
import 'item_market_actions.dart';
import 'market_search_tab.dart';
import 'sell_sheet.dart';
import '../error_text.dart';

/// Inventory, personal listings, and public market search for one account.
class MarketScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final int initialTab;
  final int? initialAppId;
  final String? initialContextId;
  const MarketScreen({
    super.key,
    required this.account,
    this.initialTab = 0,
    this.initialAppId,
    this.initialContextId,
  })
    : assert(initialTab >= 0 && initialTab < 3);

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin, SessionRetryState {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  late int _activeTab = widget.initialTab;
  bool _inventoryStarted = false;
  bool _loadingOverview = false;

  InventoryOverview? _overview;
  String? _error;
  bool _needsLogin = false; // session expired → offer sign-in, not retry
  String? _itemsError;
  InventoryGame? _game;

  // Dirty generation: a hidden listings tab waits until it becomes active.
  int _listingsReload = 0;
  int _marketSearchReload = 0;

  // Identical items are stacked (grouped by classid_instanceid) for display and
  // batch selling.
  final _stacks = <ItemStack>[];
  final _stackByKey = <String, ItemStack>{};
  final _scroll = ScrollController();
  String? _lastAssetId;
  bool _moreItems = false;
  bool _loadingItems = false;
  // Bumped on game switch / refresh so an in-flight page can't append stale
  // items to the freshly cleared grid.
  int _loadGen = 0;
  InventoryFilter _filter = const InventoryFilter();
  List<ItemStack>? _visibleStacks;
  List<InventoryFacetOption>? _typeOptions;
  List<InventoryFacetOption>? _rarityOptions;
  String? _facetUnknownLabel;

  void _invalidateInventoryViews() {
    _visibleStacks = null;
    _typeOptions = null;
    _rarityOptions = null;
  }

  void _ensureFacetOptions(AppLocalizations l) {
    if (_facetUnknownLabel != l.inventoryFilterOther) {
      _typeOptions = null;
      _rarityOptions = null;
      _facetUnknownLabel = l.inventoryFilterOther;
    }
    final items = _stacks.map((stack) => stack.item);
    _typeOptions ??= inventoryFacetOptions(
      items,
      InventoryFacet.type,
      unknownLabel: l.inventoryFilterOther,
    );
    _rarityOptions ??= inventoryFacetOptions(
      items,
      InventoryFacet.rarity,
      unknownLabel: l.inventoryFilterOther,
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _tabs.addListener(_onTabChanged);
    if (_activeTab == 0) _loadOverview();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_activeTab == _tabs.index) return;
    setState(() => _activeTab = _tabs.index);
    if (_activeTab == 0) {
      if (!_inventoryStarted) {
        _loadOverview();
      } else if (_game == null && (_overview?.games.isNotEmpty ?? false)) {
        // An overview that finished while hidden is cached; defer its first
        // inventory page until the user actually returns to this tab.
        _selectGame(_initialGame(_overview!.games));
      }
    }
  }

  InventoryGame _initialGame(List<InventoryGame> games) => games.firstWhere(
    (game) =>
        game.appid == widget.initialAppId &&
        (widget.initialContextId == null ||
            game.contextId == widget.initialContextId),
    orElse: () => games.first,
  );

  void _refreshCurrentTab() {
    switch (_activeTab) {
      case 0:
        final game = _game;
        if (game == null || _needsLogin) {
          _loadOverview();
        } else {
          _selectGame(game, refresh: true);
        }
      case 1:
        setState(() => _listingsReload++);
      case 2:
        setState(() => _marketSearchReload++);
    }
  }

  Future<void> _loadOverview() async {
    if (_activeTab != 0 || _loadingOverview) return;
    setState(() {
      _inventoryStarted = true;
      _loadingOverview = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      // Make sure the session is fresh before hitting the community
      // endpoints. A refresh failure (expired login, no stored password,
      // needs an interactive email code, ...) must not fall through to an
      // inventory fetch that would just come back empty and be mistaken for
      // "no items".
      final outcome = await ref
          .read(autoLoginProvider)
          .ensureSession(widget.account);
      if (!mounted) return;
      if (_activeTab != 0) {
        _inventoryStarted = false;
        return;
      }
      if (outcome != AutoLoginOutcome.ok) {
        // The session can't be refreshed silently (expired, no stored password,
        // or a code-only import that was never signed in) — offer sign-in, not
        // a pointless retry.
        if (mounted) {
          setState(() {
            _error = AppLocalizations.of(context).sessionExpired;
            _needsLogin = true;
          });
        }
        return;
      }
      final ov = await ref
          .read(inventoryClientProvider)
          .overview(widget.account);
      if (!mounted) return;
      setState(() => _overview = ov);
      if (_activeTab == 0 && ov.games.isNotEmpty) {
        _selectGame(_initialGame(ov.games), refresh: true);
      }
    } on CommunityAuthException {
      // The session died between the ensureSession pre-check and the fetch —
      // same routing as the pre-check failure: sign-in, not a raw exception.
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).sessionExpired;
          _needsLogin = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() => _error = describeError(l, e));
      }
    } finally {
      if (mounted) setState(() => _loadingOverview = false);
    }
  }

  Future<void> _selectGame(InventoryGame g, {bool refresh = false}) async {
    if (!refresh &&
        _game?.appid == g.appid &&
        _game?.contextId == g.contextId) {
      return;
    }
    setState(() {
      _game = g;
      _stacks.clear();
      _stackByKey.clear();
      _filter = const InventoryFilter();
      _invalidateInventoryViews();
      _lastAssetId = null;
      _moreItems = false;
      _itemsError = null;
      _loadGen++; // discard any in-flight page
      _loadingItems = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _loadItems();
  }

  Future<void> _loadItems() async {
    if (_activeTab != 0 || _loadingItems || _game == null) return;
    final gen = _loadGen;
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final page = await ref
          .read(inventoryClientProvider)
          .items(
            widget.account,
            _game!.appid,
            _game!.contextId,
            startAssetId: _lastAssetId,
          );
      if (!mounted || gen != _loadGen) return; // stale page — drop it
      if (page.more &&
          (page.lastAssetId == null || page.lastAssetId == _lastAssetId)) {
        throw const FormatException('Inventory cursor did not advance');
      }
      setState(() {
        for (final it in page.items) {
          final key = '${it.classId}_${it.instanceId}';
          final existing = _stackByKey[key];
          if (existing != null) {
            existing.assetIds.add(it.assetId);
          } else {
            final s = ItemStack(item: it, assetIds: [it.assetId]);
            _stackByKey[key] = s;
            _stacks.add(s);
          }
        }
        _lastAssetId = page.lastAssetId;
        _moreItems = page.more;
        _invalidateInventoryViews();
      });
    } on CommunityAuthException {
      // Session died mid-browse: route to the overview's sign-in affordance
      // instead of echoing a raw exception into the items pane.
      if (mounted && gen == _loadGen) {
        setState(() {
          _error = AppLocalizations.of(context).sessionExpired;
          _needsLogin = true;
        });
      }
    } catch (e) {
      // Keep loaded items and offer an explicit retry, including when a filter
      // currently hides them. Do not get stuck behind an endless footer spinner.
      if (mounted && gen == _loadGen) {
        final l = AppLocalizations.of(context);
        setState(() => _itemsError = describeError(l, e));
      }
    } finally {
      if (mounted && gen == _loadGen) setState(() => _loadingItems = false);
    }
  }

  void _onScroll() {
    if (_activeTab == 0 &&
        _moreItems &&
        _itemsError == null &&
        !_loadingItems &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadItems();
    }
  }

  Future<void> _openSell(ItemStack stack) async {
    final ov = _overview;
    if (ov == null) return;
    final listed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellSheet(
        account: widget.account,
        item: stack.item,
        assetIds: List.of(stack.assetIds),
        wallet: ov.wallet,
      ),
    );
    if (listed == true && mounted) {
      // Keep hidden tabs idle; the next listings activation consumes this.
      setState(() => _listingsReload++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.accountName ?? l.actionMarket),
        actions: [
          // Visible refresh so desktop/mouse users aren't stuck without
          // pull-to-refresh.
          IconButton(
            tooltip: l.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrentTab,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.marketTabInventory),
            Tab(text: l.marketTabListings),
            Tab(text: l.marketTabSearch),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          TickerMode(enabled: _activeTab == 0, child: _inventoryTab(l)),
          TickerMode(
            enabled: _activeTab == 1,
            child: _MyListingsTab(
              account: widget.account,
              active: _activeTab == 1,
              reload: _listingsReload,
            ),
          ),
          TickerMode(
            enabled: _activeTab == 2,
            child: MarketSearchTab(
              account: widget.account,
              active: _activeTab == 2,
              reload: _marketSearchReload,
              initialCurrency: _overview?.wallet.currency,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryTab(AppLocalizations l) {
    if (_error != null) {
      return _Centered(
        text: _error!,
        // A successful sign-in refreshes the session (and, for a code-only
        // import, fills in the real SteamID) before the reload.
        action: _needsLogin
            ? FilledButton(
                onPressed: () => signInThen(widget.account, _loadOverview),
                child: Text(l.loginButton),
              )
            : TextButton(onPressed: _loadOverview, child: Text(l.commonRetry)),
      );
    }
    final ov = _overview;
    if (ov == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _ensureFacetOptions(l);
    // The filter header shares the grid's scroll area. Keeping it fixed can
    // consume the entire short-screen viewport when the keyboard is open.
    return CustomScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _gamePicker(ov.games)),
        if (_game != null)
          SliverToBoxAdapter(
            child: Padding(
              // This is an interior header; the grid owns bottom safe space.
              padding: context
                  .rSafeInsets(left: 12, right: 12)
                  .copyWith(top: 0, bottom: context.r(8)),
              child: InventoryFilterBar(
                items: _stacks.map((stack) => stack.item),
                typeOptions: _typeOptions,
                rarityOptions: _rarityOptions,
                value: _filter,
                hasMore: _moreItems,
                onChanged: (filter) {
                  setState(() {
                    _filter = filter;
                    _visibleStacks = null;
                  });
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
              ),
            ),
          ),
        _itemGrid(l),
      ],
    );
  }

  Widget _gamePicker(List<InventoryGame> games) {
    if (games.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).extension<AvaTokens>()!;
    final l = AppLocalizations.of(context);
    final selectedGame = _game ?? games.first;
    bool isSelected(InventoryGame game) =>
        game.appid == selectedGame.appid &&
        game.contextId == selectedGame.contextId;
    Widget icon(InventoryGame game) => Padding(
      padding: EdgeInsets.only(right: context.r(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusSm),
        child: Image.network(
          game.iconUrl,
          width: context.r(28),
          height: context.r(28),
          cacheWidth: context.rCache(28),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    BoxDecoration decoration(bool selected) => BoxDecoration(
      color: selected ? t.panel2 : Colors.transparent,
      borderRadius: BorderRadius.circular(t.radiusSm),
      border: Border.all(
        color: selected ? t.accent : t.line,
        width: t.borderWidth,
      ),
    );
    Widget picker({Widget? child}) => PopupMenuButton<InventoryGame>(
      key: const ValueKey('market-game-menu'),
      tooltip: l.marketTabInventory,
      initialValue: selectedGame,
      onSelected: _selectGame,
      borderRadius: BorderRadius.circular(t.radiusSm),
      color: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      constraints: BoxConstraints(
        minWidth: 200,
        maxWidth: math.min(480, MediaQuery.sizeOf(context).width - 32),
      ),
      itemBuilder: (context) => [
        for (final game in games)
          PopupMenuItem(
            key: ValueKey('market-game-option-${game.appid}-${game.contextId}'),
            value: game,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (game.iconUrl.isNotEmpty) icon(game),
                  Expanded(
                    child: Text(
                      game.displayName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${game.itemCount}', style: TextStyle(color: t.accent)),
                  if (isSelected(game)) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, size: 18, color: t.accent),
                  ],
                ],
              ),
            ),
          ),
      ],
      icon: child == null ? const Icon(Icons.expand_more) : null,
      child: child,
    );
    return Padding(
      // Bottom bars and display corners belong to the scroll view's bottom,
      // not this short header: including them can collapse the entire row.
      padding: context
          .rSafeInsets(h: 12)
          .copyWith(top: context.r(10), bottom: context.r(10)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A phone keeps the selected context in view in both orientations.
          // Its menu exposes every game/context without a hidden horizontal row.
          final compact =
              constraints.maxWidth < 600 ||
              MediaQuery.sizeOf(context).shortestSide < 600;
          if (compact) {
            return picker(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: context.rInsets(h: 12, v: 10),
                decoration: decoration(true),
                child: Row(
                  children: [
                    if (selectedGame.iconUrl.isNotEmpty) icon(selectedGame),
                    Expanded(
                      child: Text(
                        '${selectedGame.displayName}  ',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: context.r(13),
                        ),
                      ),
                    ),
                    SizedBox(width: context.r(8)),
                    Text(
                      '${selectedGame.itemCount}',
                      style: TextStyle(
                        color: t.accent,
                        fontSize: context.r(12),
                      ),
                    ),
                    SizedBox(width: context.r(8)),
                    Icon(Icons.expand_more, color: t.accent),
                  ],
                ),
              ),
            );
          }
          final height = math.max(
            48.0,
            MediaQuery.textScalerOf(context).scale(context.r(13)) * 1.5 +
                context.r(16),
          );
          return SizedBox(
            height: height,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: games.length,
                    separatorBuilder: (_, _) => SizedBox(width: context.r(8)),
                    itemBuilder: (context, i) {
                      final game = games[i];
                      final selected = isSelected(game);
                      return Semantics(
                        selected: selected,
                        child: InkWell(
                          onTap: () => _selectGame(game),
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          child: Container(
                            padding: context.rInsets(h: 10, v: 6),
                            decoration: decoration(selected),
                            child: Row(
                              children: [
                                if (game.iconUrl.isNotEmpty) icon(game),
                                Text(
                                  '${game.displayName}  ',
                                  style: TextStyle(
                                    color: selected ? t.text : t.muted,
                                    fontSize: context.r(13),
                                  ),
                                ),
                                Text(
                                  '${game.itemCount}',
                                  style: TextStyle(
                                    color: t.accent,
                                    fontSize: context.r(12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: context.r(8)),
                SizedBox(width: 48, child: picker()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemGrid(AppLocalizations l) {
    final visible = _visibleStacks ??= _stacks
        .where((stack) => _filter.matches(stack.item))
        .toList(growable: false);
    if (visible.isEmpty) {
      if (_loadingItems) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (_itemsError != null) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _Centered(
            text: '${l.commonError}: $_itemsError',
            action: TextButton(
              onPressed: _loadItems,
              child: Text(l.commonRetry),
            ),
          ),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _Centered(
          text: _stacks.isEmpty ? l.marketNoItems : l.inventoryFilterNoMatches,
          action: _moreItems
              ? TextButton(onPressed: _loadItems, child: Text(l.tradeMore))
              : null,
        ),
      );
    }
    // A manual load action also remains reachable when filtering leaves a
    // grid too short to scroll. Only an actual request shows a spinner.
    final footer = _moreItems || _loadingItems || _itemsError != null;
    return SliverPadding(
      padding: context.rSafeInsets(all: 12),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: context.r(110),
          mainAxisSpacing: context.r(10),
          crossAxisSpacing: context.r(10),
          // Reserve thumbnail space even when names, status and a price are
          // shown together with the user's larger text setting.
          mainAxisExtent:
              context.r(90) +
              MediaQuery.textScalerOf(context).scale(context.r(94)),
        ),
        itemCount: visible.length + (footer ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= visible.length) {
            if (!_loadingItems) {
              return Center(
                child: TextButton(
                  onPressed: _loadItems,
                  child: Text(
                    _itemsError != null ? l.commonRetry : l.tradeMore,
                  ),
                ),
              );
            }
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return _ItemTile(
            key: ValueKey(
              'inventory-${visible[i].item.appid}-${visible[i].item.contextId}-${visible[i].item.assetId}',
            ),
            stack: visible[i],
            currency: _overview!.wallet.currency,
            onTap: visible[i].item.marketable
                ? () => _openSell(visible[i])
                : null,
          );
        },
      ),
    );
  }
}

/// A group of identical inventory items (one tile, one sell sheet).
class ItemStack {
  final InventoryItem item;
  final List<String> assetIds;
  ItemStack({required this.item, required this.assetIds});
  int get count => assetIds.length;
}

class _ItemTile extends StatelessWidget {
  final ItemStack stack;
  final int currency;
  final VoidCallback? onTap;
  const _ItemTile({
    super.key,
    required this.stack,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AvaTokens>()!;
    final l = AppLocalizations.of(context);
    final item = stack.item;
    return ItemMarketActions(
      item: item,
      currency: currency,
      builder: (context, priceLabel, showActions) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusSm),
        child: Container(
          padding: context.rInsets(all: 6),
          decoration: BoxDecoration(
            color: t.panel2.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(t.radiusSm),
            border: Border.all(color: t.line, width: t.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: InventoryItemIcon(item: item)),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: l.itemMarketActions,
                        onPressed: showActions,
                        icon: const Icon(Icons.more_horiz),
                        iconSize: context.r(18),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: context.r(28),
                          height: context.r(28),
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: t.muted,
                          backgroundColor: t.panel.withValues(alpha: 0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    if (stack.count > 1)
                      Positioned(
                        bottom: context.r(2),
                        right: context.r(2),
                        child: Container(
                          padding: context.rInsets(h: 5, v: 1),
                          decoration: BoxDecoration(
                            color: t.panel.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(t.radiusSm),
                          ),
                          child: Text(
                            '×${stack.count}',
                            style: TextStyle(
                              color: t.text,
                              fontSize: context.r(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.r(4)),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: context.r(10.5)),
              ),
              if (priceLabel != null) ...[
                SizedBox(height: context.r(2)),
                priceLabel,
              ],
              if (!item.marketable)
                Text(
                  l.marketNotMarketable,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontSize: context.r(9)),
                ),
              InventoryCooldownInfo(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListingsTab extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final bool active;

  /// Bumped by the parent (new listing created / appbar refresh) to reload.
  final int reload;
  const _MyListingsTab({
    required this.account,
    required this.active,
    this.reload = 0,
  });

  @override
  ConsumerState<_MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends ConsumerState<_MyListingsTab>
    with AutomaticKeepAliveClientMixin, SessionRetryState {
  Future<List<MarketListing>>? _future;
  int? _loadedReload;
  bool _loading = false;
  MarketListingState? _filter;
  final _cancelling = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.active) _refresh();
  }

  @override
  void didUpdateWidget(_MyListingsTab old) {
    super.didUpdateWidget(old);
    if (widget.active && (_future == null || _loadedReload != widget.reload)) {
      _refresh();
    }
  }

  Future<List<MarketListing>> _load() async {
    final client = ref.read(marketClientProvider);
    final outcome = await ref
        .read(autoLoginProvider)
        .ensureSession(widget.account);
    if (!mounted || !widget.active) {
      // A slow sign-in check must not start a private fetch after switching to
      // public search. A later activation retries instead of caching emptiness.
      _loadedReload = null;
      return const [];
    }
    if (outcome != AutoLoginOutcome.ok) {
      throw CommunityAuthException(401, '/market/mylistings/');
    }
    return client.myListings(widget.account);
  }

  Future<void> _refresh() async {
    if (!mounted || !widget.active || _loading) return;
    _loading = true;
    _loadedReload = widget.reload;
    final future = _load();
    setState(() {
      _future = future;
    });
    // FutureBuilder displays the failure; don't create an additional unhandled
    // error from a refresh gesture or the app bar's fire-and-forget callback.
    try {
      await future;
    } catch (_) {
    } finally {
      _loading = false;
      if (mounted && widget.active && _loadedReload != widget.reload) {
        _refresh();
      }
    }
  }

  /// Wraps empty/error states in a scrollable RefreshIndicator so they can
  /// still be pulled to refresh (list content gets its own indicator below).
  Widget _refreshable(Widget child) => RefreshIndicator(
    onRefresh: _refresh,
    child: LayoutBuilder(
      builder: (context, c) => ListView(
        padding: context.rSafeInsets(all: 0),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: c.maxHeight, child: child)],
      ),
    ),
  );

  Future<void> _cancel(MarketListing l) async {
    if (_cancelling.contains(l.listingId)) return;
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.marketCancel),
        content: Text('${l.name}\n\n${loc.marketCancelConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(l.listingId));
    final ok = await ref
        .read(marketClientProvider)
        .cancel(widget.account, l.listingId);
    if (!mounted) return;
    setState(() => _cancelling.remove(l.listingId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? loc.marketCancelled : loc.commonError)),
    );
    if (ok) {
      _loadedReload = null;
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return FutureBuilder<List<MarketListing>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          // A stale session reads as "session expired", not a raw exception;
          // re-auth lives on the overview, so retry is still the action here.
          return _refreshable(
            _Centered(
              text: snap.error is CommunityAuthException
                  ? l.sessionExpired
                  : '${l.commonError}: ${snap.error}',
              action: snap.error is CommunityAuthException
                  ? FilledButton(
                      onPressed: () => signInThen(widget.account, _refresh),
                      child: Text(l.loginButton),
                    )
                  : TextButton(onPressed: _refresh, child: Text(l.commonRetry)),
            ),
          );
        }
        final listings = snap.data ?? const <MarketListing>[];
        if (listings.isEmpty) {
          return _refreshable(_Centered(text: l.marketNoListings));
        }
        final visible = _filter == null
            ? listings
            : listings.where((item) => item.state == _filter).toList();
        return Column(
          children: [
            Padding(
              padding: context.rInsets(h: 12, v: 8),
              child: Wrap(
                spacing: context.r(8),
                runSpacing: context.r(4),
                children: [
                  ChoiceChip(
                    label: Text('${l.marketListingsAll} (${listings.length})'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final state in MarketListingState.values)
                    if (listings.any((item) => item.state == state))
                      ChoiceChip(
                        label: Text(
                          '${marketListingStateLabel(l, state)} '
                          '(${listings.where((item) => item.state == state).length})',
                        ),
                        selected: _filter == state,
                        onSelected: (_) => setState(() => _filter = state),
                      ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: context.rSafeInsets(all: 12),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: t.line, height: context.r(1)),
                  itemBuilder: (context, i) {
                    final lst = visible[i];
                    return ListTile(
                      leading: lst.iconUrl.isEmpty
                          ? null
                          : Image.network(
                              lst.iconUrl,
                              width: context.r(40),
                              cacheWidth: context.rCache(40),
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.inventory_2_outlined),
                            ),
                      title: Text(
                        lst.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          marketListingStateLabel(l, lst.state),
                          if (lst.priceAvailable && lst.currency != null)
                            '${l.marketBuyerPays}: ${formatSteamMoney(lst.buyerPrice, lst.currency!)}',
                          if (lst.state == MarketListingState.onHold &&
                              lst.holdUntil != null)
                            l.marketHoldUntil(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(
                                DateTime.fromMillisecondsSinceEpoch(
                                  lst.holdUntil! * 1000,
                                ),
                              ),
                            ),
                        ].join('\n'),
                        style: TextStyle(color: t.accent),
                      ),
                      trailing: IconButton(
                        tooltip: l.marketCancel,
                        icon: Icon(Icons.close, color: t.bad),
                        onPressed: _cancelling.contains(lst.listingId)
                            ? null
                            : () => _cancel(lst),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String marketListingStateLabel(AppLocalizations l, MarketListingState state) =>
    switch (state) {
      MarketListingState.active => l.marketListingActive,
      MarketListingState.onHold => l.marketListingOnHold,
      MarketListingState.pendingConfirmation => l.marketListingPending,
      MarketListingState.inactive => l.marketListingInactive,
    };

class _Centered extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Centered({required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: context.rInsets(all: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
