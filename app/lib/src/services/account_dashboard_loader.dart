import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/steam_guard_account.dart';
import '../core/models/steam_item.dart';
import '../core/protocol/inventory_client.dart';
import '../core/protocol/market_client.dart';
import '../core/protocol/community_session.dart';
import 'session_manager.dart';
import 'steam_api_client.dart';
import 'steam_request_scope.dart';

typedef _Identity = (int, bool, String?, String?, String?, String, Object?);

/// A small memory-only cache. Independent readers share requests, while the
/// final reader leaving a card cancels its actual HTTP work, not just its UI.
class AccountDashboardLoader {
  AccountDashboardLoader({
    required this.inventory,
    required this.market,
    required this.api,
    required this.persistSession,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 12),
    this.cacheLifetime = const Duration(seconds: 30),
    this.maxEntries = 16,
  }) : now = now ?? DateTime.now;

  final InventoryClient inventory;
  final MarketClient market;
  final SteamApiClient api;
  final Future<void> Function(SteamGuardAccount) persistSession;
  final DateTime Function() now;
  final Duration timeout;
  final Duration cacheLifetime;
  final int maxEntries;
  final _entries = <_Identity, DashboardData>{};

  (int, bool, String?, Object?) _source(SteamGuardAccount a) =>
      (a.steamId, a.fromPortable, a.accountName, a.steamId == 0 ? a : null);

  _Identity _identity(SteamGuardAccount a) => (
    a.steamId,
    a.fromPortable,
    a.accountName,
    a.session.accessToken,
    a.session.refreshToken,
    api.steamLanguage,
    a.steamId == 0 ? a : null,
  );

  DashboardLease acquire(
    SteamGuardAccount account, {
    required bool wallet,
    required bool listings,
  }) {
    final key = _identity(account);
    // Startup session maintenance can update the same live account instance.
    // Re-key its entry instead of losing a still-fresh read on that renewal.
    final exact = _entries.remove(key);
    final previousKey = exact == null
        ? _entries.keys.cast<_Identity?>().firstWhere(
            (candidate) =>
                _identity(_entries[candidate]!.account) == key &&
                _entries[candidate]!._source == _source(account) &&
                _entries[candidate]!._language == api.steamLanguage,
            orElse: () => null,
          )
        : null;
    final data =
        exact ??
        (previousKey == null ? null : _entries.remove(previousKey)) ??
        DashboardData._(this, account);
    _entries[key] = data;
    data._retain(wallet: wallet, listings: listings);
    _trim();
    return DashboardLease._(data, wallet, listings);
  }

  void _trim() {
    for (final candidate in _entries.keys.toList()) {
      if (_entries.length <= maxEntries) break;
      if (_entries[candidate]!._readers == 0) {
        _entries.remove(candidate)!._clear();
      }
    }
  }

  bool matches(DashboardLease lease, SteamGuardAccount account) =>
      !lease.data._cleared &&
      lease.data._source == _source(account) &&
      _identity(lease.data.account) == _identity(account) &&
      lease.data._language == api.steamLanguage;

  void retainAccounts(Iterable<SteamGuardAccount> accounts) {
    final identities = accounts.map(_identity).toSet();
    final previous = _entries.entries.toList();
    _entries.clear();
    final discarded = <DashboardData>[];
    for (final entry in previous) {
      final data = entry.value;
      final liveKey = _identity(data.account);
      if (!identities.contains(liveKey) ||
          data._language != api.steamLanguage ||
          data._source != _source(data.account)) {
        discarded.add(data);
      } else {
        final existing = _entries[liveKey];
        if (existing != null) {
          // Prefer an active entry, then the entry already stored under the
          // current session key. Cancel the duplicate after the map is stable.
          final keepExisting =
              existing._readers > 0 && data._readers == 0 ||
              existing._readers == data._readers && entry.key != liveKey;
          if (keepExisting) {
            discarded.add(data);
            continue;
          }
          discarded.add(existing);
        }
        _entries[liveKey] = data;
      }
    }
    for (final data in discarded) {
      data._clear();
    }
  }

  void clear() {
    final previous = _entries.values.toList();
    _entries.clear();
    for (final data in previous) {
      data._clear();
    }
  }
}

class DashboardValue<T> {
  T? value;
  bool loading = false;
  bool failed = false;
  bool needsLogin = false;
  DateTime? checkedAt;
  SteamRequestScope? _scope;
}

class DashboardData extends ChangeNotifier {
  DashboardData._(this._loader, this.account)
    : _language = _loader.api.steamLanguage,
      _source = _loader._source(account);

  final AccountDashboardLoader _loader;
  final SteamGuardAccount account;
  final String _language;
  final (int, bool, String?, Object?) _source;
  final wallet = DashboardValue<WalletInfo>();
  final listings = DashboardValue<List<MarketListing>>();
  int _walletReaders = 0, _listingReaders = 0;
  int get _readers => _walletReaders + _listingReaders;
  Future<SessionRefreshOutcome>? _refreshingSession;
  SteamRequestScope? _sessionScope;
  bool _cleared = false;

  void _retain({required bool wallet, required bool listings}) {
    if (wallet) _walletReaders++;
    if (listings) _listingReaders++;
    // Attaching an overview during route construction must not synchronously
    // rebuild another overview that is already listening to this entry.
    scheduleMicrotask(load);
  }

  void _release({required bool wallet, required bool listings}) {
    if (wallet) _walletReaders--;
    if (listings) _listingReaders--;
    if (_walletReaders == 0) _cancel(this.wallet);
    if (_listingReaders == 0) _cancel(this.listings);
    if (_readers == 0) _sessionScope?.cancel();
    _loader._trim();
  }

  void _cancel(DashboardValue<Object?> section) {
    section._scope?.cancel();
    section._scope = null;
    section.loading = false;
  }

  void _clear() {
    _cleared = true;
    _cancel(wallet);
    _cancel(listings);
    _sessionScope?.cancel();
    wallet.value = null;
    listings.value = null;
    wallet.checkedAt = listings.checkedAt = null;
    notifyListeners();
  }

  /// Manual refresh bypasses the short cache; an in-flight card is coalesced.
  void load({bool force = false}) {
    if (_cleared) return;
    if (!wallet.loading && !listings.loading && _sessionScope == null) {
      _refreshingSession = null;
    }
    if (_walletReaders > 0) {
      _load(wallet, () => _loader.inventory.wallet(account), force: force);
    }
    if (_listingReaders > 0) {
      _load(listings, () => _loader.market.myListings(account), force: force);
    }
  }

  void _load<T>(
    DashboardValue<T> section,
    Future<T> Function() fetch, {
    required bool force,
  }) {
    if (section.loading) return;
    final age = section.checkedAt == null
        ? null
        : _loader.now().difference(section.checkedAt!);
    // Do not cache failures: after enabling a proxy, explicit retry and
    // reopening the overview must be able to recover immediately.
    if (!force &&
        section.value != null &&
        age != null &&
        !age.isNegative &&
        age < _loader.cacheLifetime) {
      return;
    }
    final scope = SteamRequestScope(timeout: _loader.timeout);
    section
      .._scope = scope
      ..loading = true
      ..failed = false
      ..needsLogin = false;
    notifyListeners();
    unawaited(() async {
      try {
        final value = await scope.run(() async {
          final token = account.session.accessToken;
          try {
            requireAccessToken(account);
            return await fetch();
          } catch (error) {
            if (!SessionManager.isAuthenticationError(error)) rethrow;
            // A simultaneous startup/card renewal may already have fixed it.
            if (account.session.accessToken == token) {
              final outcome = await _refreshSession();
              if (outcome == SessionRefreshOutcome.failed) {
                throw const DashboardConnectionException();
              }
              if (outcome != SessionRefreshOutcome.refreshed) rethrow;
            }
            return fetch();
          }
        });
        if (_cleared || section._scope != scope) return;
        section.value = value;
        section.checkedAt = _loader.now();
      } catch (error) {
        if (_cleared || section._scope != scope) return;
        section
          ..value = null
          ..checkedAt = null
          ..failed = true
          ..needsLogin = SessionManager.isAuthenticationError(error);
      } finally {
        if (!_cleared && section._scope == scope) {
          section._scope = null;
          section.loading = false;
          if (wallet._scope == null && listings._scope == null) {
            _sessionScope?.cancel();
          }
          notifyListeners();
        }
      }
    }());
  }

  Future<SessionRefreshOutcome>
  _refreshSession() => _refreshingSession ??= () async {
    final scope = SteamRequestScope(timeout: _loader.timeout);
    _sessionScope = scope;
    try {
      return await scope.run(() async {
        final outcome = await SessionManager(
          _loader.api,
        ).refreshResult(account.session);
        // A rotated token must still be persisted if the view closed while
        // the response was arriving. The caller captured this safe callback.
        if (outcome == SessionRefreshOutcome.refreshed) {
          await _loader.persistSession(account);
        }
        return outcome;
      });
    } catch (_) {
      return SessionRefreshOutcome.failed;
    } finally {
      _sessionScope = null;
      // Keep a completed renewal for this load burst: two concurrent 401s
      // share the same single attempt, including a failed renewal.
    }
  }();
}

class DashboardConnectionException implements Exception {
  const DashboardConnectionException();
}

class DashboardLease {
  DashboardLease._(this.data, this.wallet, this.listings);
  final DashboardData data;
  final bool wallet, listings;
  bool _released = false;

  void refresh() {
    data.load(force: true);
  }

  void release() {
    if (_released) return;
    _released = true;
    data._release(wallet: wallet, listings: listings);
  }
}
