import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ava/src/app/market_favorites.dart';
import 'package:ava/src/core/models/market_search.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _item = MarketSearchItem(
  appid: 730,
  marketHashName: 'AK-47 | Test',
  name: 'Test rifle',
  iconUrl:
      'https://community.fastly.steamstatic.com/economy/image/abc/128fx128f',
  type: 'Rifle',
  rarityColor: '8847ff',
  listingCount: 42,
  lowestPriceMinor: 123,
  priceText: r'$1.23',
);

class _TempStorage extends StorageProvider {
  _TempStorage(this.root);
  final String root;
  @override
  Future<String> maFilesDir() async => p.join(root, 'maFiles');
}

class _MemoryStore extends MarketFavoritesStore {
  _MemoryStore() : super(MemoryStorageProvider());
  MarketFavorites value = const MarketFavorites();
  Completer<MarketFavorites>? pending;
  bool failSave = false;
  @override
  Future<MarketFavorites> load() async => pending?.future ?? value;
  @override
  Future<void> save(MarketFavorites next) async {
    if (failSave) throw const FileSystemException('test');
    value = next;
  }
}

void main() {
  test(
    'favorites and currency survive restart without price or listing cache',
    () async {
      final directory = await Directory.systemTemp.createTemp('ava_favorites_');
      addTearDown(() => directory.delete(recursive: true));
      final storage = _TempStorage(directory.path);
      final store = MarketFavoritesStore(storage);
      expect((await store.load()).items, isEmpty);
      await store.save(const MarketFavorites(items: [_item], currency: 23));
      final restarted = await MarketFavoritesStore(storage).load();
      expect(restarted.currency, 23);
      expect(restarted.items.single.marketHashName, _item.marketHashName);
      expect(restarted.items.single.iconUrl, _item.iconUrl);
      expect(restarted.items.single.lowestPriceMinor, isNull);
      expect(restarted.items.single.priceText, isNull);
      expect(restarted.items.single.listingCount, 0);
      final raw = await File(
        p.join(directory.path, 'market_favorites.json'),
      ).readAsString();
      expect(raw, isNot(contains(r'$1.23')));
      expect(
        jsonDecode(raw)['items'][0].keys,
        unorderedEquals([
          'appid',
          'market_hash_name',
          'name',
          'icon_url',
          'type',
          'rarity_color',
        ]),
      );
    },
  );

  test('sync export waits for durable load and queued writes', () async {
    final store = _MemoryStore()..pending = Completer();
    final container = ProviderContainer(
      overrides: [marketFavoritesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(marketFavoritesProvider.notifier);
    final export = notifier.exportForSync();
    var done = false;
    export.then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    store.pending!.complete(
      const MarketFavorites(items: [_item], currency: 23),
    );
    expect((await export)['items'], hasLength(1));
    final write = notifier.setCurrency(1);
    final nextExport = notifier.exportForSync();
    await write;
    expect((await nextExport)['currency'], 1);
  });

  test(
    'rapid writes retain items and remote apply replaces existing favorites',
    () async {
      final store = _MemoryStore();
      final container = ProviderContainer(
        overrides: [marketFavoritesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(marketFavoritesProvider.notifier);
      await Future.wait([notifier.toggle(_item), notifier.setCurrency(23)]);
      expect(store.value.items, hasLength(1));
      expect(store.value.currency, 23);
      await notifier.applySynced(const MarketFavorites(currency: 3).toJson());
      expect(store.value.items, isEmpty);
      expect(store.value.currency, 3);
    },
  );

  test(
    'read and write failures cannot publish empty or unpersisted changes',
    () async {
      final store = _MemoryStore()..pending = Completer();
      final container = ProviderContainer(
        overrides: [marketFavoritesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(marketFavoritesProvider.notifier);
      final export = notifier.exportForSync();
      store.pending!.completeError(const FileSystemException('test'));
      await expectLater(export, throwsA(isA<FileSystemException>()));
      await expectLater(
        notifier.toggle(_item),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.value.items, isEmpty);

      final healthy = _MemoryStore()
        ..value = const MarketFavorites(items: [_item], currency: 23);
      final other = ProviderContainer(
        overrides: [marketFavoritesStoreProvider.overrideWithValue(healthy)],
      );
      addTearDown(other.dispose);
      await other.read(marketFavoritesProvider.future);
      healthy.failSave = true;
      await expectLater(
        other.read(marketFavoritesProvider.notifier).toggle(_item),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        other.read(marketFavoritesProvider).requireValue.items,
        hasLength(1),
      );
    },
  );

  test(
    'remote favorites validate currency and identities and sanitize image origins',
    () {
      final data = const MarketFavorites(items: [_item], currency: 23).toJson();
      final items = data['items'] as List;
      items[0]['icon_url'] = 'https://untrusted.invalid/private';
      items.add(Map<String, Object>.from(items[0]));
      final parsed = MarketFavorites.fromJson(data);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.iconUrl, isEmpty);
      expect(
        () => MarketFavorites.fromJson({...data, 'currency': 0}),
        throwsFormatException,
      );
      items[0]['appid'] = -1;
      expect(() => MarketFavorites.fromJson(data), throwsFormatException);
    },
  );
}
