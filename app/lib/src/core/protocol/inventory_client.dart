import 'dart:convert';

import '../../services/debug_log.dart';
import '../../services/steam_api_client.dart';
import '../json_coerce.dart';
import '../models/steam_guard_account.dart';
import '../models/steam_item.dart';
import 'community_session.dart';

/// One page of inventory items plus pagination state.
class InventoryPage {
  final List<InventoryItem> items;
  final String? lastAssetId;
  final bool more;
  const InventoryPage(this.items, this.lastAssetId, this.more);
}

/// The account's games (with inventory) + the live wallet/fee constants, both
/// scraped from the inventory page.
class InventoryOverview {
  final List<InventoryGame> games;
  final WalletInfo wallet;
  const InventoryOverview(this.games, this.wallet);
}

/// Reads a Steam account's inventory (games list, wallet info, items) via the
/// community endpoints, authorized with the account's own session cookie.
class InventoryClient {
  final SteamApiClient api;
  InventoryClient(this.api);

  /// Fetches the game picker + wallet info by scraping the inventory page.
  Future<InventoryOverview> overview(
    SteamGuardAccount account, {
    String? ownerSteamId,
  }) async {
    final owner = _ownerId(account, ownerSteamId);
    final html = await api.communityGetText(
      '/profiles/$owner/inventory/',
      query: {'l': api.steamLanguage},
      cookies: communityCookies(account),
    );
    _ensureLoggedIn(html, '/profiles/$owner/inventory/');
    final apps = _extractJsonObject(html, 'g_rgAppContextData');
    if (apps == null) {
      throw const FormatException('Steam inventory overview is unavailable.');
    }
    final walletJson = _extractJsonObject(html, 'g_rgWalletInfo');
    final wallet = walletJson != null
        ? WalletInfo.fromJson(walletJson)
        : WalletInfo.fallback;

    final games = <InventoryGame>[];
    apps.forEach((appid, raw) {
      if (raw is! Map) return;
      // rgContexts is an object of {contextid: {...}}, but Steam encodes an
      // empty one as a JSON array [] — skip those.
      final ctxRaw = raw['rgContexts'];
      if (ctxRaw is! Map) return;
      final contexts = ctxRaw.entries
          .where((e) => e.value is Map && asInt(e.value['asset_count']) > 0)
          .toList();
      final contextNames = <String, int>{};
      for (final entry in contexts) {
        final name = (entry.value['name'] as String?)?.trim() ?? '';
        contextNames[name] = (contextNames[name] ?? 0) + 1;
      }
      for (final entry in contexts) {
        final cid = entry.key;
        final craw = entry.value as Map;
        final count = asInt(craw['asset_count']);
        final contextName = (craw['name'] as String?)?.trim() ?? '';
        games.add(
          InventoryGame(
            appid: int.tryParse(appid) ?? 0,
            contextId: '$cid',
            name: (raw['name'] ?? '') as String,
            iconUrl: (raw['icon'] ?? '') as String,
            itemCount: count,
            // Even if Steam gives two contexts the same name, retain the IDs
            // so the picker never shows indistinguishable entries.
            contextName:
                contextName.isNotEmpty && contextNames[contextName] == 1
                ? contextName
                : contextName.isEmpty
                ? '$cid'
                : '$contextName ($cid)',
            showContext: contexts.length > 1,
          ),
        );
      }
    });
    games.sort((a, b) => b.itemCount.compareTo(a.itemCount));
    dlog(
      'inventory overview: ${games.length} games, wallet=${wallet.currency}',
    );
    return InventoryOverview(games, wallet);
  }

  /// Read-only wallet fetch for account dashboards. This reads Steam's own
  /// market page and never opens a purchase/listing flow. A missing balance is
  /// returned as null, so a locked/unavailable wallet cannot look like zero.
  Future<WalletInfo> wallet(SteamGuardAccount account) async {
    final html = await api.communityGetText(
      '/market/',
      query: {'l': api.steamLanguage},
      cookies: communityCookies(account),
    );
    _ensureLoggedIn(html, '/market/');
    final data = _extractJsonObject(html, 'g_rgWalletInfo');
    if (data == null) {
      throw const FormatException('Steam wallet information is unavailable.');
    }
    return WalletInfo.fromJson(data);
  }

  static void _ensureLoggedIn(String html, String path) {
    // The market is also a public page: an expired cookie can return HTTP 200
    // with an anonymous page rather than redirecting to login.
    if (RegExp(r'\bg_bLoggedIn\s*=\s*false\b').hasMatch(html)) {
      throw CommunityAuthException(401, path);
    }
  }

  static String _ownerId(SteamGuardAccount account, String? ownerSteamId) {
    final owner = ownerSteamId ?? '${account.steamId}';
    if (!RegExp(r'^\d{17}$').hasMatch(owner)) {
      throw ArgumentError.value(owner, 'ownerSteamId', 'Invalid Steam ID');
    }
    return owner;
  }

  /// Fetches one page of items for a game/context.
  Future<InventoryPage> items(
    SteamGuardAccount account,
    int appid,
    String contextId, {
    String? ownerSteamId,
    String? startAssetId,
    int count = 75,
  }) async {
    final json = await api.communityGetJson(
      '/inventory/${_ownerId(account, ownerSteamId)}/$appid/$contextId',
      {
        'l': api.steamLanguage,
        'count': '$count',
        'start_assetid': ?startAssetId,
      },
      cookies: communityCookies(account),
    );
    if (json['needauth'] == true || json['needsauth'] == true) {
      throw CommunityAuthException(401, '/inventory/');
    }
    if (json['success'] != true && asInt(json['success']) != 1) {
      throw const FormatException('Steam inventory is private or unavailable.');
    }
    final assets = (json['assets'] as List?) ?? const [];
    final descriptions = (json['descriptions'] as List?) ?? const [];
    // Index descriptions by classid_instanceid.
    final descByKey = <String, Map<String, dynamic>>{};
    for (final d in descriptions) {
      final m = d as Map<String, dynamic>;
      descByKey['${m['classid']}_${m['instanceid']}'] = m;
    }
    final items = <InventoryItem>[];
    for (final a in assets) {
      final m = a as Map<String, dynamic>;
      final d = descByKey['${m['classid']}_${m['instanceid']}'];
      if (d == null) continue;
      final feeApp = d['market_fee'];
      final rarity = _rarity(d);
      items.add(
        InventoryItem(
          appid: asInt(m['appid']),
          contextId: '${m['contextid']}',
          assetId: '${m['assetid']}',
          classId: '${m['classid']}',
          instanceId: '${m['instanceid']}',
          amount: asInt(m['amount']),
          marketHashName: (d['market_hash_name'] ?? '') as String,
          name: (d['name'] ?? '') as String,
          type: (d['type'] ?? '') as String,
          iconUrl: itemImageUrl(d['icon_url'] as String?),
          marketable: asInt(d['marketable']) == 1,
          tradable: asInt(d['tradable']) == 1,
          publisherFeePct: feeApp is num ? feeApp.toDouble() : null,
          rarityColor: rarity.color,
          rarityName: rarity.name,
          tags: _tags(d),
        ),
      );
    }
    return InventoryPage(
      items,
      json['last_assetid'] as String?,
      json['more_items'] == 1 || json['more_items'] == true,
    );
  }

  static List<InventoryTag> _tags(Map<String, dynamic> item) {
    final raw = item['tags'];
    if (raw is! List) return const [];
    final result = <String, InventoryTag>{};
    for (final tag in raw.whereType<Map>()) {
      final category = tag['category'];
      final internal = tag['internal_name'];
      final localized = tag['localized_tag_name'];
      if (category is! String ||
          internal is! String ||
          category.trim().isEmpty ||
          internal.trim().isEmpty) {
        continue;
      }
      final value = InventoryTag(
        category: category.trim(),
        internalName: internal.trim(),
        label: localized is String ? localized.trim() : '',
      );
      // Some descriptions repeat their tags. A duplicate is not a new facet.
      result.putIfAbsent(value.key, () => value);
    }
    return List.unmodifiable(result.values);
  }

  /// Categories are machine-readable keys; localized names are display-only.
  /// Prefer the game's rarity tag over quality (e.g. StatTrak), then use its
  /// item-name color when no usable tag color was provided.
  static ({String color, String name}) _rarity(Map<String, dynamic> item) {
    final tags = item['tags'];
    if (tags is List) {
      for (final category in const ['rarity', 'quality']) {
        for (final tag in tags.whereType<Map>()) {
          final rawCategory = tag['category'];
          if (rawCategory is! String || rawCategory.toLowerCase() != category) {
            continue;
          }
          final color = _rgbHex(tag['color']);
          if (color.isEmpty) continue;
          final name = tag['localized_tag_name'];
          return (color: color, name: name is String ? name.trim() : '');
        }
      }
    }
    // name_color is a presentation fallback, not proof of a named rarity.
    return (color: _rgbHex(item['name_color']), name: '');
  }

  static String _rgbHex(dynamic raw) {
    if (raw is! String) return '';
    final value = raw.trim();
    if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(value)) return '';
    return value.replaceFirst('#', '').toLowerCase();
  }

  /// Extracts a `var <name> = { … };` JSON object from page HTML by matching
  /// balanced braces (the values are JSON-parseable object literals).
  static Map<String, dynamic>? _extractJsonObject(String html, String name) {
    final marker = RegExp('$name\\s*=\\s*');
    final m = marker.firstMatch(html);
    if (m == null) return null;
    var i = m.end;
    if (i >= html.length || html[i] != '{') return null;
    var depth = 0;
    var inStr = false;
    String? quote;
    final start = i;
    for (; i < html.length; i++) {
      final c = html[i];
      if (inStr) {
        if (c == '\\') {
          i++;
        } else if (c == quote) {
          inStr = false;
        }
        continue;
      }
      if (c == '"' || c == "'") {
        inStr = true;
        quote = c;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          final raw = html.substring(start, i + 1);
          try {
            return jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }
}
