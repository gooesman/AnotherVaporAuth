import 'dart:async';
import 'dart:ui' as ui;

import 'package:ava/src/ui/widgets/animated_steam_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

SteamImageFrames _frames({bool animated = false}) {
  ui.Image image(Color color) {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = color);
    final picture = recorder.endRecording();
    final result = picture.toImageSync(4, 4);
    picture.dispose();
    return result;
  }

  return SteamImageFrames(
    [
      image(const Color(0xffff0000)),
      if (animated) image(const Color(0xff0000ff)),
    ],
    [100, if (animated) 100],
  );
}

Widget _app(
  SteamImageCache cache, {
  String url = 'avatar',
  bool ticker = true,
  bool reduced = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: TickerMode(
      enabled: ticker,
      child: AnimatedSteamImage(url: url, size: 44, cache: cache),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'LRU byte limit disposes cache handles while displayed copies remain valid',
    () async {
      final originals = <String, SteamImageFrames>{};
      final cache = SteamImageCache.withLoader((url) async {
        return originals[url] = _frames();
      }, maximumBytes: 128);
      final a = (await cache.load('a'))!;
      final b = (await cache.load('b'))!;
      final a2 = (await cache.load('a'))!;
      final c = (await cache.load('c'))!;
      expect(originals['b']!.frames.single.debugDisposed, isTrue);
      expect(originals['a']!.frames.single.debugDisposed, isFalse);
      expect(b.frames.single.debugDisposed, isFalse);
      expect(a.frames.single.isCloneOf(a2.frames.single), isTrue);
      expect((await b.frames.single.toByteData())!.lengthInBytes, 64);
      cache.clear();
      expect(
        originals.values.every((frames) => frames.frames.single.debugDisposed),
        isTrue,
      );
      for (final copy in [a, b, a2, c]) {
        copy.dispose();
      }
    },
  );

  test('entry cap also evicts many small images', () async {
    final originals = <String, SteamImageFrames>{};
    final cache = SteamImageCache.withLoader(
      (url) async => originals[url] = _frames(),
      maximumEntries: 2,
    );
    for (final url in ['a', 'b', 'c']) {
      (await cache.load(url))!.dispose();
    }
    expect(originals['a']!.frames.single.debugDisposed, isTrue);
    expect(originals['b']!.frames.single.debugDisposed, isFalse);
    cache.clear();
  });

  test(
    'concurrent readers share decode and clone before immediate eviction',
    () async {
      final pending = Completer<SteamImageFrames?>();
      var decodes = 0;
      final cache = SteamImageCache.withLoader((url) {
        decodes++;
        return pending.future;
      }, maximumBytes: 0);
      final first = cache.load('a');
      final second = cache.load('a');
      final source = _frames();
      pending.complete(source);
      final copies = await Future.wait([first, second]);
      expect(decodes, 1);
      expect(source.frames.single.debugDisposed, isTrue);
      for (final copy in copies) {
        expect(copy!.frames.single.debugDisposed, isFalse);
        copy.dispose();
      }
    },
  );

  test('failed image loads may be retried', () async {
    var calls = 0;
    final cache = SteamImageCache.withLoader(
      (url) async => ++calls == 1 ? null : _frames(),
      maximumBytes: 0,
    );
    expect(await cache.load('a'), isNull);
    final copy = await cache.load('a');
    expect(copy, isNotNull);
    expect(calls, 2);
    copy!.dispose();
  });

  testWidgets('animated frames stop in background and under disabled motion', (
    tester,
  ) async {
    final cache = SteamImageCache.withLoader(
      (url) async => _frames(animated: true),
      maximumBytes: 0,
    );
    await tester.pumpWidget(_app(cache));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final animatedFrame = tester.widget<RawImage>(find.byType(RawImage)).image;
    expect(tester.binding.transientCallbackCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image,
      same(animatedFrame),
    );
    expect(tester.binding.transientCallbackCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(_app(cache, ticker: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app(cache, reduced: true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app(cache));
    expect(tester.binding.transientCallbackCount, 1);
    final displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
    await tester.pumpWidget(const SizedBox());
    expect(displayed.debugDisposed, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale loads and replaced frames release their owned handles', (
    tester,
  ) async {
    final pending = <String, Completer<SteamImageFrames?>>{};
    final cache = SteamImageCache.withLoader(
      (url) => (pending[url] = Completer()).future,
      maximumBytes: 0,
    );
    await tester.pumpWidget(_app(cache, url: 'old'));
    await tester.pumpWidget(_app(cache, url: 'new'));
    final obsolete = _frames();
    pending['old']!.complete(obsolete);
    await tester.pumpAndSettle();
    expect(obsolete.frames.single.debugGetOpenHandleStackTraces(), isEmpty);
    pending['new']!.complete(_frames());
    await tester.pumpAndSettle();
    final displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
    await tester.pumpWidget(_app(cache, url: 'replacement'));
    expect(displayed.debugDisposed, isFalse);
    pending['replacement']!.complete(_frames());
    await tester.pumpAndSettle();
    expect(displayed.debugDisposed, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
