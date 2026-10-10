// Steam economy models for the inventory + market feature.

import '../json_coerce.dart';

const String _imageBase =
    'https://community.fastly.steamstatic.com/economy/image/';

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Live wallet / fee constants parsed from `g_rgWalletInfo` on a community page.
class WalletInfo {
  final int currency; // wallet_currency (23 = CNY, 1 = USD, …)
  /// Steam's integer wallet units. Null means unavailable, never a guessed 0.
  final int? balance;
  final int? delayedBalance;
  final double steamFeePct; // wallet_fee_percent (0.05)
  final double publisherFeePct; // wallet_publisher_fee_percent_default (0.10)
  final int marketMinimum; // wallet_market_minimum (minor units)
  final int currencyIncrement; // wallet_currency_increment

  const WalletInfo({
    required this.currency,
    required this.steamFeePct,
    required this.publisherFeePct,
    required this.marketMinimum,
    required this.currencyIncrement,
    this.balance,
    this.delayedBalance,
  });

  /// Safe default (USD-like) used until the real wallet is fetched.
  static const fallback = WalletInfo(
    currency: 1,
    steamFeePct: 0.05,
    publisherFeePct: 0.10,
    marketMinimum: 1,
    currencyIncrement: 1,
  );

  /// Parses the `g_rgWalletInfo` object (values are strings).
  factory WalletInfo.fromJson(Map<String, dynamic> j) => WalletInfo(
    currency: asInt(j['wallet_currency']),
    balance: j['success'] == false || j['success'] == 0 || j['success'] == '0'
        ? null
        : asIntOrNull(j['wallet_balance']),
    delayedBalance:
        j['success'] == false || j['success'] == 0 || j['success'] == '0'
        ? null
        : asIntOrNull(j['wallet_delayed_balance']),
    steamFeePct: _asDouble(j['wallet_fee_percent']),
    publisherFeePct: _asDouble(j['wallet_publisher_fee_percent_default']),
    marketMinimum: asInt(j['wallet_market_minimum']),
    currencyIncrement: asInt(j['wallet_currency_increment']).clamp(1, 1 << 30),
  );
}

/// A game + inventory context the account has items in (the game picker).
class InventoryGame {
  final int appid;
  final String contextId;
  final String name;
  final String iconUrl; // full URL
  final int itemCount;
  final String contextName;

  /// True when the game has several nonempty inventory contexts.
  final bool showContext;

  const InventoryGame({
    required this.appid,
    required this.contextId,
    required this.name,
    required this.iconUrl,
    required this.itemCount,
    this.contextName = '',
    this.showContext = false,
  });

  /// Different contexts are real inventories. Keep them selectable and use the
  /// name supplied by Steam, falling back to the context ID when unavailable.
  String get displayName => showContext
      ? '$name · ${contextName.isEmpty ? contextId : contextName}'
      : name;
}

/// Steam's stable category/tag identifiers with its localized display label.
/// Labels are never used to classify items: translations vary by game/language.
class InventoryTag {
  final String category;
  final String internalName;
  final String label;
  const InventoryTag({
    required this.category,
    required this.internalName,
    required this.label,
  });

  String get key => '${category.toLowerCase()}/$internalName';
}

/// One inventory item (asset merged with its description).
class InventoryItem {
  final int appid;
  final String contextId;
  final String assetId;
  final String classId;
  final String instanceId;
  final int amount;
  final String marketHashName;
  final String name;
  final String type;
  final String iconUrl; // full URL
  final bool marketable;
  final bool tradable;
  final double? publisherFeePct; // per-item override, if any
  /// Steam's RGB hex color, without '#'. Empty when no valid color is supplied.
  final String rarityColor;

  /// Localized rarity/quality label supplied by Steam, never inferred from name.
  final String rarityName;

  final List<InventoryTag> tags;

  const InventoryItem({
    required this.appid,
    required this.contextId,
    required this.assetId,
    required this.classId,
    required this.instanceId,
    required this.amount,
    required this.marketHashName,
    required this.name,
    required this.type,
    required this.iconUrl,
    required this.marketable,
    required this.tradable,
    this.publisherFeePct,
    this.rarityColor = '',
    this.rarityName = '',
    this.tags = const [],
  });
}

enum MarketListingState { active, onHold, pendingConfirmation, inactive }

/// An account's market listing, including holds and outstanding confirmations.
class MarketListing {
  final String listingId;
  final int appid;
  final String marketHashName;
  final String name;
  final String iconUrl; // full URL
  final int buyerPrice; // what buyers pay (minor units)
  final int fee; // total fee (minor units)
  final int createdAt; // unix seconds
  final bool active;
  final MarketListingState state;
  final int? holdUntil; // time_finish_hold, unix seconds
  final int? currency; // normalized Steam currency ID, without the 2000 offset
  final bool priceAvailable;

  const MarketListing({
    required this.listingId,
    required this.appid,
    required this.marketHashName,
    required this.name,
    required this.iconUrl,
    required this.buyerPrice,
    required this.fee,
    required this.createdAt,
    required this.active,
    this.state = MarketListingState.active,
    this.holdUntil,
    this.currency,
    this.priceAvailable = true,
  });

  /// Amount the seller receives = buyer price − fee.
  int get sellerReceives => buyerPrice - fee;

  factory MarketListing.fromJson(
    Map<String, dynamic> j, {
    MarketListingState? state,
  }) {
    final asset = (j['asset'] as Map<String, dynamic>?) ?? const {};
    final active = j['active'] == true || asInt(j['active']) == 1;
    final holdUntil = asIntOrNull(j['time_finish_hold']);
    // Steam's price excludes fees; its official market.js computes the buyer
    // total as converted_price_per_unit + converted_fee_per_unit. Keep amount,
    // fee and currency from the same set of fields when a converted price is
    // supplied, rather than labeling an old-currency listing with today's
    // wallet currency.
    final convertedPrice = asIntOrNull(j['converted_price']);
    final convertedFee = asIntOrNull(j['converted_fee']);
    final convertedCurrency = asIntOrNull(j['converted_currencyid']);
    final converted =
        convertedPrice != null &&
        convertedFee != null &&
        convertedCurrency != null &&
        convertedCurrency > 0;
    final price = converted ? convertedPrice : asInt(j['price']);
    final fee = converted ? convertedFee : asInt(j['fee']);
    final currencyId = converted
        ? convertedCurrency
        : asIntOrNull(j['currencyid']);
    return MarketListing(
      listingId: '${j['listingid']}',
      appid: asInt(asset['appid']),
      marketHashName: (asset['market_hash_name'] ?? '') as String,
      name: (asset['name'] ?? asset['market_name'] ?? '') as String,
      iconUrl: _icon(asset['icon_url'] as String?),
      buyerPrice: price + fee,
      fee: fee,
      priceAvailable:
          converted ||
          (asIntOrNull(j['price']) != null && asIntOrNull(j['fee']) != null),
      currency: currencyId != null && currencyId > 0
          ? (currencyId >= 2000 ? currencyId - 2000 : currencyId)
          : null,
      createdAt: asInt(j['time_created']),
      active: active,
      state:
          state ??
          (active ? MarketListingState.active : MarketListingState.inactive),
      holdUntil: holdUntil != null && holdUntil > 0 ? holdUntil : null,
    );
  }
}

/// Market price reference from `priceoverview` (localized strings).
class MarketPrice {
  final String? lowest;
  final String? median;
  final int? volume;
  const MarketPrice({this.lowest, this.median, this.volume});

  factory MarketPrice.fromJson(Map<String, dynamic> j) => MarketPrice(
    lowest: j['lowest_price'] as String?,
    median: j['median_price'] as String?,
    volume: j['volume'] is String
        ? int.tryParse((j['volume'] as String).replaceAll(',', ''))
        : (j['volume'] as int?),
  );
}

String _icon(String? raw) =>
    (raw == null || raw.isEmpty) ? '' : '$_imageBase$raw';

/// Exposed for the inventory/description merge.
String itemImageUrl(String? iconUrl) => _icon(iconUrl);
