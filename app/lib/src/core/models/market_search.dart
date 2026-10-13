/// One public Community Market search result. The quoted price is Steam's
/// current lowest listing, not a completed sale or a guaranteed purchase price.
class MarketSearchItem {
  final int appid;
  final String marketHashName;
  final String name;
  final String iconUrl;
  final String type;
  final String rarityColor;

  /// Raw amount from Steam, whose response does not identify its currency.
  /// Never relabel this with the requested currency. Search prices are not used
  /// for selected-currency quotes; the UI queries priceoverview for visible rows.
  final int? lowestPriceMinor;

  /// Steam's already formatted, unverified search price. The search endpoint
  /// may ignore the requested currency, so this is not a selected-currency quote.
  final String? priceText;
  final int listingCount;

  const MarketSearchItem({
    required this.appid,
    required this.marketHashName,
    required this.name,
    this.iconUrl = '',
    this.type = '',
    this.rarityColor = '',
    this.lowestPriceMinor,
    this.priceText,
    this.listingCount = 0,
  });

  factory MarketSearchItem.fromJson(Map<String, dynamic> json) {
    final asset = json['asset_description'];
    if (asset is! Map<String, dynamic>) {
      throw const FormatException('Missing market search asset');
    }
    final appid = _integer(asset['appid'], 'appid', minimum: 1);
    final hash = _text(
      asset['market_hash_name'] ?? json['hash_name'],
      'market_hash_name',
      required: true,
    );
    final name = _text(json['name'] ?? asset['name'], 'name');
    final listings = _integer(json['sell_listings'], 'sell_listings');
    final rawPrice = json['sell_price'];
    final price = rawPrice == null ? null : _integer(rawPrice, 'sell_price');
    final rawText = _text(json['sell_price_text'], 'sell_price_text');
    final color = asset['name_color'];
    final rawIcon = asset['icon_url'];
    // Steam returns an opaque image key. Build the URL ourselves: response
    // data must never select an arbitrary image host, query, or path traversal.
    final icon =
        rawIcon is String &&
            rawIcon.length <= 4096 &&
            RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(rawIcon)
        ? 'https://community.fastly.steamstatic.com/economy/image/$rawIcon/128fx128f'
        : '';
    return MarketSearchItem(
      appid: appid,
      marketHashName: hash,
      name: name.isEmpty ? hash : name,
      iconUrl: icon,
      type: _text(asset['type'], 'type'),
      rarityColor:
          color is String && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(color)
          ? color
          : '',
      lowestPriceMinor: listings > 0 ? price : null,
      priceText: listings > 0 && rawText.isNotEmpty ? rawText : null,
      listingCount: listings,
    );
  }
}

/// A single bounded search response. Empty pages stop pagination even if
/// Steam's changing total still claims that more listings exist.
class MarketSearchPage {
  final List<MarketSearchItem> items;
  final int start;
  final int pageSize;
  final int total;

  const MarketSearchPage({
    required this.items,
    required this.start,
    required this.pageSize,
    required this.total,
  });

  int get nextStart => start + pageSize;
  bool get hasMore =>
      items.isNotEmpty &&
      pageSize > 0 &&
      nextStart > start &&
      nextStart < total;

  factory MarketSearchPage.fromJson(
    Map<String, dynamic> json, {
    required int expectedStart,
    required int maximumPageSize,
  }) {
    final start = _integer(json['start'], 'start');
    final size = _integer(
      json['pagesize'],
      'pagesize',
      maximum: maximumPageSize,
    );
    final total = _integer(json['total_count'], 'total_count');
    final results = json['results'];
    if (start != expectedStart ||
        results is! List ||
        results.length > size ||
        results.length > total) {
      throw const FormatException('Invalid market search page');
    }
    final items = <MarketSearchItem>[];
    for (final result in results) {
      if (result is! Map<String, dynamic>) {
        throw const FormatException('Invalid market search result');
      }
      items.add(MarketSearchItem.fromJson(result));
    }
    return MarketSearchPage(
      items: List.unmodifiable(items),
      start: start,
      pageSize: size,
      total: total,
    );
  }
}

int _integer(
  Object? value,
  String field, {
  int minimum = 0,
  int maximum = 0x7fffffff,
}) {
  // Do not silently truncate fractional prices, accept booleans, or turn an
  // absent count/price into a plausible zero.
  final parsed = value is int
      ? value
      : value is String && RegExp(r'^\d{1,10}$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (parsed == null || parsed < minimum || parsed > maximum) {
    throw FormatException('Invalid market search $field');
  }
  return parsed;
}

String _text(Object? value, String field, {bool required = false}) {
  if (value == null && !required) return '';
  if (value is! String ||
      value.length > 2048 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
      (required && value.trim().isEmpty)) {
    throw FormatException('Invalid market search $field');
  }
  return value;
}
