import 'dart:async';
import 'dart:io';

import 'package:ava/src/ui/widgets/steam_image_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform originalPaths;
  const url = 'https://community.steamstatic.com/test-thumbnail.png';

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('ava_thumbnail_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary.path);
    final cache = await Directory('${temporary.path}/image_cache').create();
    final bytes = img.encodePng(img.Image(width: 2048, height: 1024));
    await File(
      '${cache.path}/${hashlib.sha1.string(url).hex()}',
    ).writeAsBytes(bytes);
  });
  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  testWidgets('44dp 3x thumbnail decodes a 2048x1024 source to 160x80', (
    tester,
  ) async {
    final provider = steamThumbnailProvider(
      url,
      logicalSize: const Size(44, 44),
      devicePixelRatio: 3,
    );
    final decoded = await tester.runAsync(() async {
      final result = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) => result.complete(info),
        onError: result.completeError,
      );
      stream.addListener(listener);
      try {
        return await result.future;
      } finally {
        stream.removeListener(listener);
      }
    });
    expect(decoded!.image.width, 160);
    expect(decoded.image.height, 80);
    expect(decoded.image.width * decoded.image.height * 4, 51200);
    decoded.dispose();
  });

  test(
    'small layout changes share a bucket and large thumbnails stay bounded',
    () {
      final a = steamThumbnailProvider(
        url,
        logicalSize: const Size(44, 44),
        devicePixelRatio: 3,
      );
      final b = steamThumbnailProvider(
        url,
        logicalSize: const Size(45, 45),
        devicePixelRatio: 3,
      );
      expect(a.width, b.width);
      expect(a.height, b.height);
      expect(a.policy, ResizeImagePolicy.fit);
      expect(a.allowUpscaling, isFalse);
      final large = steamThumbnailProvider(
        url,
        logicalSize: const Size(3000, 1000),
        devicePixelRatio: 4,
      );
      expect(large.width, 768);
      expect(large.height, 768);
    },
  );
}
