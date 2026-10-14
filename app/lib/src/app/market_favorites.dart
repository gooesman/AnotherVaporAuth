import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/models/market_search.dart';
import '../services/storage_provider.dart';
import 'providers.dart';

/// Public item identities and the preferred quote currency, never cached prices.
class MarketFavorites {
  const MarketFavorites({this.items = const [], this.currency});

  final List<MarketSearchItem> items;
  final int? currency;

  bool contains(MarketSearchItem item) => items.any(
    (saved) =>
        saved.appid == item.appid &&
        saved.marketHashName == item.marketHashName,
  );

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'items': [
      for (final item in items)
        {
          'appid': item.appid,
          'market_hash_name': item.marketHashName,
          'name': item.name,
          'icon_url': item.iconUrl,
          'type': item.type,
          'rarity_color': item.rarityColor,
        },
    ],
  };

  factory MarketFavorites.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'];
    final entries = json['items'];
    if ((currency != null &&
            (currency is! int || currency < 1 || currency > 32)) ||
        entries is! List) {
      throw const FormatException('Invalid market favorites');
    }
    final items = <(int, String), MarketSearchItem>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid market favorite');
      }
      final appid = entry['appid'];
      final hash = entry['market_hash_name'];
      if (appid is! int ||
          appid <= 0 ||
          hash is! String ||
          hash.isEmpty ||
          hash.length > 4096) {
        throw const FormatException('Invalid market favorite identity');
      }
      String text(String key) {
        final value = entry[key];
        if (value is! String || value.length > 8192) {
          throw const FormatException('Invalid market favorite metadata');
        }
        return value;
      }

      final icon = text('icon_url');
      final color = text('rarity_color');
      final uri = Uri.tryParse(icon);
      // A synced image must not become a request to an arbitrary host.
      final safeIcon =
          uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'community.fastly.steamstatic.com' &&
          uri.userInfo.isEmpty &&
          !uri.hasPort &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          RegExp(
            r'^/economy/image/[A-Za-z0-9_-]+/128fx128f$',
          ).hasMatch(uri.path);
      items[(appid, hash)] = MarketSearchItem(
        appid: appid,
        marketHashName: hash,
        name: text('name'),
        iconUrl: safeIcon ? icon : '',
        type: text('type'),
        rarityColor: RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(color) ? color : '',
      );
    }
    return MarketFavorites(
      items: List.unmodifiable(items.values),
      currency: currency as int?,
    );
  }
}

class MarketFavoritesStore {
  MarketFavoritesStore(this.storage);
  final StorageProvider storage;

  Future<File> _file() async => File(
    p.join(p.dirname(await storage.maFilesDir()), 'market_favorites.json'),
  );

  Future<MarketFavorites> load() async {
    final file = await _file();
    if (!await file.exists()) return const MarketFavorites();
    return MarketFavorites.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> save(MarketFavorites value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await StorageProvider.replaceFileAtomic(
      file.path,
      jsonEncode(value.toJson()),
    );
  }
}

final marketFavoritesStoreProvider = Provider<MarketFavoritesStore>(
  (ref) => MarketFavoritesStore(ref.read(storageProvider)),
);

final marketFavoritesProvider =
    AsyncNotifierProvider<MarketFavoritesNotifier, MarketFavorites>(
      MarketFavoritesNotifier.new,
      // A sync comparison must fail promptly instead of waiting on retries.
      retry: (_, _) => null,
    );

class MarketFavoritesNotifier extends AsyncNotifier<MarketFavorites> {
  Future<void> _writes = Future.value();

  @override
  Future<MarketFavorites> build() =>
      ref.read(marketFavoritesStoreProvider).load();

  Future<void> _update(MarketFavorites Function(MarketFavorites) change) {
    final task = _writes.then((_) async {
      final previous = await future;
      final next = change(previous);
      await ref.read(marketFavoritesStoreProvider).save(next);
      if (ref.mounted) state = AsyncData(next);
    });
    _writes = task.catchError((_) {});
    return task;
  }

  Future<void> toggle(MarketSearchItem item, {int? currency}) =>
      _update((current) {
        final items = current.contains(item)
            ? current.items
                  .where(
                    (saved) =>
                        saved.appid != item.appid ||
                        saved.marketHashName != item.marketHashName,
                  )
                  .toList()
            : [...current.items, item];
        // Use the same whitelist for local writes and remote imports.
        return MarketFavorites.fromJson(
          MarketFavorites(
            items: items,
            currency: currency ?? current.currency,
          ).toJson(),
        );
      });

  Future<void> setCurrency(int currency) => _update(
    (current) => MarketFavorites.fromJson(
      MarketFavorites(items: current.items, currency: currency).toJson(),
    ),
  );

  Future<Map<String, dynamic>> exportForSync() async {
    await _writes;
    return (await future).toJson();
  }

  Future<void> applySynced(Map<String, dynamic> value) {
    final parsed = MarketFavorites.fromJson(value);
    return _update((_) => parsed);
  }
}
