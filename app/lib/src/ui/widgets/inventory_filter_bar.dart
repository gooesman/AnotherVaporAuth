import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/inventory_filter.dart';
import '../../core/models/steam_item.dart';

/// Compact controls shared by market browsing and trade selection. Facets are
/// collected before filtering so choosing one never hides the other choices.
class InventoryFilterBar extends StatefulWidget {
  final Iterable<InventoryItem> items;
  final InventoryFilter value;
  final ValueChanged<InventoryFilter> onChanged;
  final bool hasMore;

  /// Optional snapshots for large inventories; callers invalidate these when
  /// loaded items or the localized unknown-category label change.
  final List<InventoryFacetOption>? typeOptions;
  final List<InventoryFacetOption>? rarityOptions;
  const InventoryFilterBar({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hasMore = false,
    this.typeOptions,
    this.rarityOptions,
  });

  @override
  State<InventoryFilterBar> createState() => _InventoryFilterBarState();
}

class _InventoryFilterBarState extends State<InventoryFilterBar> {
  late final _search = TextEditingController(text: widget.value.query);

  @override
  void didUpdateWidget(InventoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.value.query) _search.text = widget.value.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final types =
        widget.typeOptions ??
        inventoryFacetOptions(
          widget.items,
          InventoryFacet.type,
          unknownLabel: l.inventoryFilterOther,
        );
    final rarities =
        widget.rarityOptions ??
        inventoryFacetOptions(
          widget.items,
          InventoryFacet.rarity,
          unknownLabel: l.inventoryFilterOther,
        );
    Widget select(
      String label,
      String key,
      String selected,
      List<InventoryFacetOption> options,
      ValueChanged<String> onChanged,
    ) => InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey(key),
          value: selected,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                l.marketListingsAll,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final option in options)
              DropdownMenuItem(
                value: option.key,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('inventory-search'),
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            labelText: l.inventorySearch,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.value.query.isEmpty
                ? null
                : IconButton(
                    tooltip: l.accountSearchClear,
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        widget.onChanged(widget.value.copyWith(query: '')),
                  ),
          ),
          onChanged: (query) =>
              widget.onChanged(widget.value.copyWith(query: query)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: select(
                l.inventoryFilterType,
                'inventory-type',
                widget.value.type,
                types,
                (type) => widget.onChanged(widget.value.copyWith(type: type)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: select(
                l.inventoryFilterRarity,
                'inventory-rarity',
                widget.value.rarity,
                rarities,
                (rarity) =>
                    widget.onChanged(widget.value.copyWith(rarity: rarity)),
              ),
            ),
          ],
        ),
        if (widget.hasMore) ...[
          const SizedBox(height: 8),
          Text(
            l.inventoryFilterLoaded,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
