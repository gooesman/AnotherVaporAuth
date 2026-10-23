import 'models/steam_item.dart';

enum InventoryFacet { type, rarity }

/// Choose a game's genuine type metadata rather than guessing from a name.
/// Steam community items use item_class, while CS2 / Dota expose Type.
InventoryTag? inventoryFacetTag(InventoryItem item, InventoryFacet facet) {
  final categories = facet == InventoryFacet.type
      ? const ['type', 'item_class']
      : const ['rarity', 'quality'];
  for (final category in categories) {
    for (final tag in item.tags) {
      if (tag.category.toLowerCase() == category) return tag;
    }
  }
  return null;
}

const inventoryUnknownFacet = '__unknown__';

String inventoryFacetKey(InventoryItem item, InventoryFacet facet) {
  final tag = inventoryFacetTag(item, facet);
  return tag == null || tag.label.isEmpty ? inventoryUnknownFacet : tag.key;
}

class InventoryFilter {
  final String query;
  final String type;
  final String rarity;
  const InventoryFilter({this.query = '', this.type = '', this.rarity = ''});

  InventoryFilter copyWith({String? query, String? type, String? rarity}) =>
      InventoryFilter(
        query: query ?? this.query,
        type: type ?? this.type,
        rarity: rarity ?? this.rarity,
      );

  bool matches(InventoryItem item) {
    if (type.isNotEmpty &&
        inventoryFacetKey(item, InventoryFacet.type) != type) {
      return false;
    }
    if (rarity.isNotEmpty &&
        inventoryFacetKey(item, InventoryFacet.rarity) != rarity) {
      return false;
    }
    if (query.trim().isEmpty) return true;
    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.isEmpty) return true;
    final text = [
      item.name,
      item.marketHashName,
      item.type,
      item.assetId,
      for (final tag in item.tags) tag.label,
    ].join(' ').toLowerCase();
    return words.every(text.contains);
  }
}

class InventoryFacetOption {
  final String key;
  final String label;
  const InventoryFacetOption(this.key, this.label);
}

List<InventoryFacetOption> inventoryFacetOptions(
  Iterable<InventoryItem> items,
  InventoryFacet facet, {
  required String unknownLabel,
}) {
  final options = <String, InventoryFacetOption>{};
  for (final item in items) {
    final tag = inventoryFacetTag(item, facet);
    final key = inventoryFacetKey(item, facet);
    final label = tag == null || tag.label.isEmpty ? unknownLabel : tag.label;
    options.putIfAbsent(key, () => InventoryFacetOption(key, label));
  }
  final result = options.values.toList();
  result.sort((a, b) {
    if (a.key == b.key) return 0;
    if (a.key == inventoryUnknownFacet) return 1;
    if (b.key == inventoryUnknownFacet) return -1;
    return a.label.compareTo(b.label);
  });
  return result;
}
