import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/steam_item.dart';
import '../../services/steam_request_scope.dart';
import 'item_market_actions.dart';

typedef MarketSearchPriceKey = (int, String, int, String);

class MarketSearchQuote {
  const MarketSearchQuote({this.price, this.error, this.loading = false});
  final MarketPrice? price;
  final Object? error;
  final bool loading;
}

/// Only visible rows request quotes. One read at a time, with a one-second gap;
/// a failed read pauses the queue for 30 seconds rather than fanning out errors.
/// The existing currency/language-aware price cache survives page changes.
class MarketSearchPrices extends ChangeNotifier {
  MarketSearchPrices(this.cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ItemMarketPriceCache cache;
  final DateTime Function() _now;
  final _visible = <Object, MarketSearchPriceKey>{};
  final _values = <MarketSearchPriceKey, MarketSearchQuote>{};
  SteamRequestScope? _scope;
  MarketSearchPriceKey? _reading;
  Timer? _timer;
  DateTime? _nextRead;
  DateTime? _pausedUntil;
  Object? _pauseError;
  int _generation = 0;
  bool _disposed = false;

  MarketSearchQuote quote(MarketSearchPriceKey key) {
    final value = _values[key];
    if (value != null) return value;
    final cached = cache.peek(key.$1, key.$2, key.$3);
    if (cached != null) return MarketSearchQuote(price: cached.price);
    return MarketSearchQuote(error: _pauseError, loading: _pauseError == null);
  }

  void visible(Object owner, MarketSearchPriceKey? key) {
    if (_disposed) return;
    if (key == null) {
      _visible.remove(owner);
    } else {
      if (_visible[owner] == key) return;
      _visible[owner] = key;
    }
    if (_reading != null && !_visible.containsValue(_reading)) {
      _reading = null;
      _scope?.cancel();
    }
    _pump();
  }

  void retry(MarketSearchPriceKey key) {
    if (_disposed) return;
    cache.invalidate(key.$1, key.$2, key.$3);
    _values.remove(key);
    final until = _pausedUntil;
    if (until != null && _now().isBefore(until)) {
      // An explicit retry waits out the shared cooldown. Scrolling alone never
      // installs this retry timer, and leaving the page cancels it.
      _timer?.cancel();
      _timer = Timer(until.difference(_now()), () {
        _timer = null;
        _pausedUntil = null;
        _pauseError = null;
        _pump();
      });
    } else {
      _pump();
    }
    notifyListeners();
  }

  void _pump() {
    if (_disposed || _scope != null || _timer != null) return;
    final now = _now();
    if (_pausedUntil != null && now.isBefore(_pausedUntil!)) return;
    _pauseError = null;
    _pausedUntil = null;
    MarketSearchPriceKey? next;
    for (final key in _visible.values) {
      final cached = cache.peek(key.$1, key.$2, key.$3);
      if (cached != null) {
        _values[key] = MarketSearchQuote(price: cached.price);
        continue;
      }
      if (!_values.containsKey(key)) {
        next = key;
        break;
      }
    }
    if (next == null) return;
    if (_nextRead != null && now.isBefore(_nextRead!)) {
      _timer = Timer(_nextRead!.difference(now), () {
        _timer = null;
        _nextRead = null;
        _pump();
      });
      return;
    }
    unawaited(_fetch(next));
  }

  Future<void> _fetch(MarketSearchPriceKey key) async {
    final generation = _generation;
    final scope = SteamRequestScope();
    _scope = scope;
    _reading = key;
    try {
      final price = await scope.run(() => cache.lookup(key.$1, key.$2, key.$3));
      if (_disposed || generation != _generation || _reading != key) return;
      _values[key] = MarketSearchQuote(price: price);
    } catch (error) {
      if (_disposed || generation != _generation || _reading != key) return;
      _values[key] = MarketSearchQuote(error: error);
      _pauseError = error;
      _pausedUntil = _now().add(const Duration(seconds: 30));
    } finally {
      if (!_disposed && generation == _generation) {
        _scope = null;
        _reading = null;
        _nextRead = _now().add(const Duration(seconds: 1));
        notifyListeners();
        _pump();
      }
    }
  }

  /// Keep only successful cache entries; no cancelled/failed work is replayed.
  void reset() {
    _generation++;
    _scope?.cancel();
    _scope = null;
    _reading = null;
    _timer?.cancel();
    _timer = null;
    _visible.clear();
    _values.clear();
    // Preserve a rate-limit cooldown across searches and currency changes.
    _nextRead = null;
  }

  @override
  void dispose() {
    reset();
    _disposed = true;
    super.dispose();
  }
}
