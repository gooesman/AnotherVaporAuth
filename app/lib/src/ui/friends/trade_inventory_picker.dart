import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/steam_item.dart';
import '../../core/models/trade_draft.dart';
import '../../core/protocol/inventory_client.dart';
import '../error_text.dart';
import '../market/item_market_actions.dart';
import '../pending/session_retry.dart';
import '../widgets/inventory_item_icon.dart';

class TradeInventoryPicker extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final String ownerSteamId;
  final bool mine;
  final List<TradeSelection> selected;
  const TradeInventoryPicker({
    super.key,
    required this.account,
    required this.ownerSteamId,
    required this.mine,
    required this.selected,
  });

  @override
  ConsumerState<TradeInventoryPicker> createState() =>
      _TradeInventoryPickerState();
}

class _TradeInventoryPickerState extends ConsumerState<TradeInventoryPicker>
    with SessionRetryState {
  final _selected = <String, TradeSelection>{};
  final _items = <String, InventoryItem>{};
  InventoryOverview? _overview;
  InventoryGame? _game;
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  String? _cursor;
  bool _more = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    for (final selection in widget.selected) {
      _selected[selection.key] = selection;
    }
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final overview = await fetchWithAutoRefresh(
        widget.account,
        () => ref
            .read(inventoryClientProvider)
            .overview(widget.account, ownerSteamId: widget.ownerSteamId),
        retryOnAnyError: false,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
      if (overview.games.isNotEmpty) await _selectGame(overview.games.first);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _selectGame(InventoryGame game) async {
    _generation++;
    setState(() {
      _game = game;
      _cursor = null;
      _more = false;
      _items.clear();
      _error = null;
      _loading = false;
    });
    await _loadItems();
  }

  void _fail(Object e) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _loading = false;
      _needsLogin = isAuthError(e);
      _error = _needsLogin
          ? l.confNeedsLogin
          : e is FormatException
          ? l.tradeLoadFailed
          : describeError(l, e);
    });
  }

  Future<void> _loadItems() async {
    final game = _game;
    if (_loading || game == null) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final page = await fetchWithAutoRefresh(
        widget.account,
        () => ref
            .read(inventoryClientProvider)
            .items(
              widget.account,
              game.appid,
              game.contextId,
              ownerSteamId: widget.ownerSteamId,
              startAssetId: _cursor,
            ),
        retryOnAnyError: false,
      );
      if (!mounted || generation != _generation) return;
      // Reject a stuck cursor instead of providing an endless Load more loop.
      if (page.more &&
          (page.lastAssetId == null || page.lastAssetId == _cursor)) {
        throw const FormatException('Inventory cursor did not advance');
      }
      setState(() {
        for (final item in page.items.where(
          (item) => item.tradable && item.amount > 0,
        )) {
          _items['${item.appid}/${item.contextId}/${item.assetId}'] = item;
        }
        _cursor = page.lastAssetId;
        _more = page.more;
        _loading = false;
      });
    } catch (e) {
      if (generation == _generation) _fail(e);
    }
  }

  void _quantity(String key, InventoryItem item, int amount) => setState(() {
    if (amount <= 0) {
      _selected.remove(key);
    } else if (_selected.containsKey(key) || _selected.length < 256) {
      _selected[key] = TradeSelection(
        ownerSteamId: widget.ownerSteamId,
        item: item,
        amount: amount.clamp(1, item.amount),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mine ? l.tradeYourItems : l.tradeTheirItems),
        actions: [
          TextButton(
            key: const ValueKey('trade-selection-done'),
            onPressed: () => Navigator.pop(context, _selected.values.toList()),
            child: Text('${l.commonConfirm} (${_selected.length})'),
          ),
        ],
      ),
      body: ListView(
        padding: context.rSafeInsets(all: 16),
        children: [
          if (_selected.length >= 256)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.tradeValidationFailed),
            ),
          if (_overview != null && _overview!.games.isNotEmpty)
            DropdownButtonFormField<InventoryGame>(
              initialValue: _game,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.tradeChooseGame),
              items: [
                for (final game in _overview!.games)
                  DropdownMenuItem(value: game, child: Text(game.displayName)),
              ],
              onChanged: _loading
                  ? null
                  : (game) {
                      if (game != null) _selectGame(game);
                    },
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(_error!),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _needsLogin
                        ? () => signInThen(widget.account, _loadOverview)
                        : _overview == null
                        ? _loadOverview
                        : _loadItems,
                    child: Text(_needsLogin ? l.loginButton : l.commonRetry),
                  ),
                ],
              ),
            ),
          if (!_loading && _error == null && _items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.tradeNoItems),
            ),
          for (final entry in _items.entries)
            ItemMarketActions(
              key: ValueKey('market-${entry.key}'),
              item: entry.value,
              // Steam embeds the signed-in viewer's wallet even when this
              // inventory belongs to the trade partner.
              currency:
                  _overview?.wallet.currency ?? WalletInfo.fallback.currency,
              builder: (context, priceLabel, showActions) => Card(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            key: ValueKey('asset-${entry.key}'),
                            value: _selected.containsKey(entry.key),
                            onChanged:
                                !_selected.containsKey(entry.key) &&
                                    _selected.length >= 256
                                ? null
                                : (selected) => _quantity(
                                    entry.key,
                                    entry.value,
                                    selected == true ? 1 : 0,
                                  ),
                            title: Text(entry.value.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.value.type}\n${entry.value.assetId}',
                                ),
                                if (priceLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: priceLabel,
                                  ),
                              ],
                            ),
                            secondary: InventoryItemIcon(
                              item: entry.value,
                              size: 44,
                            ),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('item-actions-${entry.key}'),
                          tooltip: l.itemMarketActions,
                          onPressed: showActions,
                          icon: const Icon(Icons.more_horiz),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    if (_selected.containsKey(entry.key) &&
                        entry.value.amount > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(l.tradeQuantity),
                          IconButton(
                            onPressed: () => _quantity(
                              entry.key,
                              entry.value,
                              _selected[entry.key]!.amount - 1,
                            ),
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${_selected[entry.key]!.amount}'),
                          IconButton(
                            onPressed:
                                _selected[entry.key]!.amount >=
                                    entry.value.amount
                                ? null
                                : () => _quantity(
                                    entry.key,
                                    entry.value,
                                    _selected[entry.key]!.amount + 1,
                                  ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_more && !_loading)
            OutlinedButton(onPressed: _loadItems, child: Text(l.tradeMore)),
        ],
      ),
    );
  }
}
