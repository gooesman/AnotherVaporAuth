import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../../services/debug_log.dart';
import '../../services/image_disk_cache.dart';
import 'apng_decoder.dart';

/// A decoded (possibly animated) image: one or more frames with per-frame delays.
class SteamImageFrames {
  final List<ui.Image> frames;
  final List<int> delaysMs;
  final int totalMs;
  SteamImageFrames(this.frames, this.delaysMs)
    : totalMs = delaysMs.fold(0, (a, b) => a + b);
  bool get animated => frames.length > 1;
  int get byteSize =>
      frames.fold(0, (sum, frame) => sum + frame.width * frame.height * 4);

  // A clone owns separate engine handles while sharing the pixel allocation.
  // Cache eviction can then release its handles without invalidating a widget.
  SteamImageFrames clone() =>
      SteamImageFrames([for (final frame in frames) frame.clone()], delaysMs);

  void dispose() {
    for (final frame in frames) {
      frame.dispose();
    }
  }
}

class _SteamImageCacheEntry {
  final Future<SteamImageFrames?> pending;
  SteamImageFrames? frames;
  int readers = 0;
  _SteamImageCacheEntry(this.pending);
}

/// Raw frame data crossing the isolate boundary (ui.Image is not sendable).
class _RawFrame {
  final Uint8List rgba;
  final int width;
  final int height;
  final int delayMs;
  _RawFrame(this.rgba, this.width, this.height, this.delayMs);
}

/// Converts [f] from straight to premultiplied alpha, returning the image to
/// hand to the engine.
///
/// [ui.PixelFormat.rgba8888] — the format [SteamImageCache._toUiImage] uploads
/// with — is documented as "RGBA row-primary form **with premultiplied
/// alpha**", but `package:image` decodes PNG/GIF to straight alpha. The two
/// disagree exactly where alpha is low, and Steam's avatar-frame PNGs are the
/// worst case: every one of this frame's 36360 fully-transparent pixels stores
/// rgb(255,255,255). Read as premultiplied, each one contributes full white at
/// zero coverage — the frame's transparent middle paints as a solid white
/// block that hides the avatar behind it (issue #3).
///
/// Runs before the downscale on purpose: interpolating straight alpha would
/// smear that same white into a halo along every edge.
img.Image premultiplyAlpha(img.Image f) {
  // A palette image resolves alpha through the palette; give setRgba a direct
  // buffer to write into first.
  final out = f.hasPalette ? f.convert(numChannels: 4) : f;
  if (out.numChannels < 4) return out;
  for (final p in out) {
    final a = p.a.toInt();
    if (a == 255) continue;
    if (a == 0) {
      p.setRgba(0, 0, 0, 0);
      continue;
    }
    p.setRgba(
      (p.r.toInt() * a + 127) ~/ 255,
      (p.g.toInt() * a + 127) ~/ 255,
      (p.b.toInt() * a + 127) ~/ 255,
      a,
    );
  }
  return out;
}

/// Loads + decodes (with caching) Steam profile images, including animated
/// APNG avatars / avatar frames that Flutter's built-in codec renders as a
/// single static frame. Bytes come from [DiskImageCache] (instant on a
/// relaunch); decoding runs in a background isolate; the resulting frames are
/// shared across every widget that shows the same URL.
class SteamImageCache {
  SteamImageCache._()
    : _loader = _fetchAndDecode,
      maximumBytes = 32 * 1024 * 1024,
      maximumEntries = 16;

  @visibleForTesting
  SteamImageCache.withLoader(
    this._loader, {
    this.maximumBytes = 32 * 1024 * 1024,
    this.maximumEntries = 16,
  });

  static final SteamImageCache instance = SteamImageCache._();
  final Future<SteamImageFrames?> Function(String) _loader;
  final int maximumBytes;
  final int maximumEntries;
  final Map<String, _SteamImageCacheEntry> _cache = {};

  /// Returns owned handles; the caller must dispose them after displaying.
  /// Concurrent requests share decode work, and only inactive cache handles
  /// are evicted. Displayed frames survive eviction via their cloned handles.
  Future<SteamImageFrames?> load(String url) async {
    final entry = _cache.remove(url) ?? _SteamImageCacheEntry(_loader(url));
    _cache[url] = entry;
    entry.readers++;
    try {
      final frames = await entry.pending;
      entry.frames = frames;
      if (frames == null) {
        if (identical(_cache[url], entry)) _cache.remove(url);
        return null;
      }
      return frames.clone();
    } catch (_) {
      if (identical(_cache[url], entry)) _cache.remove(url);
      rethrow;
    } finally {
      entry.readers--;
      _trim();
    }
  }

  /// Drop retained frames on memory pressure; active widgets own their copies.
  void clear() => _trim(clearAll: true);

  void _trim({bool clearAll = false}) {
    var bytes = _cache.values.fold(
      0,
      (sum, entry) => sum + (entry.frames?.byteSize ?? 0),
    );
    for (final url in _cache.keys.toList(growable: false)) {
      if (!clearAll && _cache.length <= maximumEntries && bytes <= maximumBytes) {
        break;
      }
      final entry = _cache[url]!;
      // A pending reader has not cloned its handles yet.
      if (entry.readers > 0 || entry.frames == null) continue;
      _cache.remove(url);
      bytes -= entry.frames!.byteSize;
      entry.frames!.dispose();
    }
  }

  static Future<SteamImageFrames?> _fetchAndDecode(String url) async {
    final frames = <ui.Image>[];
    try {
      final bytes = await DiskImageCache.instance.load(url);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final raw = await Isolate.run(() => _decode(bytes));
      if (raw == null || raw.isEmpty) {
        // Decoded nothing out of real bytes: likely a corrupt cache entry.
        unawaited(DiskImageCache.instance.evict(url));
        return null;
      }
      final delays = <int>[];
      for (final f in raw) {
        frames.add(await _toUiImage(f));
        delays.add(f.delayMs <= 0 ? 100 : f.delayMs);
      }
      dlog('steam-image: $url -> ${frames.length} frame(s)');
      return SteamImageFrames(frames, delays);
    } catch (e) {
      dlog('steam-image decode failed ($url): $e');
      for (final frame in frames) {
        frame.dispose();
      }
      return null;
    }
  }

  static Future<ui.Image> _toUiImage(_RawFrame f) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      f.rgba,
      f.width,
      f.height,
      ui.PixelFormat.rgba8888,
      c.complete,
    );
    return c.future;
  }

  // Frames are only shown at small sizes (≤ ~68px logical); cap the decoded
  // dimension so a long animation (e.g. a 120-frame APNG) stays light on memory.
  static const int _maxDim = 192;

  /// Runs in an isolate: decode all frames to composited RGBA buffers,
  /// downscaling oversized frames.
  static List<_RawFrame>? _decode(Uint8List bytes) {
    // Animated APNG (avatar frames especially) must be composited by hand —
    // the image package mishandles offset sub-frames and they flicker.
    final apng = decodeApngFrames(bytes);
    if (apng != null) {
      return [for (final fr in apng) _rawFrom(_prepare(fr.image), fr.delayMs)];
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return [
      for (final frame in decoded.frames)
        _rawFrom(_prepare(frame), frame.frameDuration),
    ];
  }

  static img.Image _prepare(img.Image f) => _fit(premultiplyAlpha(f));

  static img.Image _fit(img.Image f) {
    final m = f.width > f.height ? f.width : f.height;
    if (m <= _maxDim) return f;
    final scale = _maxDim / m;
    return img.copyResize(
      f,
      width: (f.width * scale).round(),
      height: (f.height * scale).round(),
    );
  }

  static _RawFrame _rawFrom(img.Image f, int delayMs) => _RawFrame(
    f.getBytes(order: img.ChannelOrder.rgba),
    f.width,
    f.height,
    delayMs,
  );
}

/// Renders a Steam profile image at [size], animating it if it is an animated
/// APNG. Falls back to [fallback] (or empty) while loading or on failure.
class AnimatedSteamImage extends StatefulWidget {
  final String url;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final SteamImageCache? cache;
  const AnimatedSteamImage({
    super.key,
    required this.url,
    required this.size,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
    this.cache,
  });

  @override
  State<AnimatedSteamImage> createState() => _AnimatedSteamImageState();
}

class _AnimatedSteamImageState extends State<AnimatedSteamImage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  SteamImageFrames? _frames;
  Ticker? _ticker;
  int _frameIndex = 0;
  bool _animationsAllowed = true;
  bool _resumed = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsAllowed =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void didHaveMemoryPressure() {
    (widget.cache ?? SteamImageCache.instance).clear();
  }

  void _syncTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    if (_resumed && _animationsAllowed) {
      if (!ticker.isActive) ticker.start();
    } else {
      ticker.stop();
    }
  }

  @override
  void didUpdateWidget(AnimatedSteamImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.cache != widget.cache) {
      _ticker?.dispose();
      _ticker = null;
      // Keep showing the old frames until the replacement is ready — an
      // updated frame/avatar should swap in, not flash the fallback.
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final f = await (widget.cache ?? SteamImageCache.instance).load(widget.url);
    // Release obsolete handles even if the original URL changed away and back.
    if (!mounted || generation != _loadGeneration) {
      f?.dispose();
      return;
    }
    if (f == null) return;
    _ticker?.dispose();
    _ticker = null;
    final previous = _frames;
    setState(() {
      _frames = f;
      _frameIndex = 0;
    });
    previous?.dispose();
    if (f.animated && f.totalMs > 0) {
      _ticker = createTicker((elapsed) {
        final idx = _indexAt(f, elapsed.inMilliseconds % f.totalMs);
        if (idx != _frameIndex) setState(() => _frameIndex = idx);
      });
      _syncTicker();
    }
  }

  static int _indexAt(SteamImageFrames f, int t) {
    var acc = 0;
    for (var i = 0; i < f.frames.length; i++) {
      if (t < acc + f.delaysMs[i]) return i;
      acc += f.delaysMs[i];
    }
    return f.frames.length - 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _frames?.dispose();
    super.dispose();
  }

  ui.Image? get _current {
    final f = _frames;
    if (f == null) return null;
    return f.frames[_frameIndex.clamp(0, f.frames.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final image = _current;
    final Widget child = image == null
        ? (widget.fallback ?? const SizedBox.shrink())
        : RawImage(
            image: image,
            width: widget.size,
            height: widget.size,
            fit: widget.fit,
          );
    final sized = SizedBox(
      width: widget.size,
      height: widget.size,
      child: child,
    );
    return RepaintBoundary(
      child: widget.borderRadius == null
          ? sized
          : ClipRRect(borderRadius: widget.borderRadius!, child: sized),
    );
  }
}
