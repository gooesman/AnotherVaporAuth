import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/steam_guard_account.dart';
import '../core/models/steam_notification.dart';
import '../core/protocol/steam_notifications_client.dart';
import '../services/steam_request_scope.dart';
import 'providers.dart';

final steamNotificationsClientProvider = Provider<SteamNotificationsClient>(
  (ref) => SteamNotificationsClient(ref.read(apiClientProvider)),
);

final steamNotificationCountsEnabledProvider = Provider<bool>((ref) {
  final data = ref.watch(appControllerProvider).value;
  return data != null && !data.locked && data.privacyAccepted;
});

typedef _SessionKey = (int, String?, String?);
_SessionKey _key(SteamGuardAccount account) => (
  account.steamId,
  account.session.accessToken,
  account.session.refreshToken,
);

/// Only counters and freshness are retained, in memory, for one login session.
class AccountNotificationCounts {
  final _SessionKey _session;
  final SteamNotificationCounts counts;
  final bool loading;
  final bool stale;
  final bool confirmationStale;
  final DateTime? lastAttempt;

  const AccountNotificationCounts._(
    this._session, {
    required this.counts,
    this.loading = false,
    this.stale = false,
    this.confirmationStale = false,
    this.lastAttempt,
  });

  int? get confirmationCount => counts.confirmationCount;
  int? get pendingFriendCount => counts.pendingFriendCount;
  int? get unreadCount => counts.unreadCount;
  bool matches(SteamGuardAccount account) => _session == _key(account);
}

final steamNotificationCountsProvider =
    NotifierProvider<
      SteamNotificationCountsController,
      Map<int, AccountNotificationCounts>
    >(SteamNotificationCountsController.new);

class SteamNotificationCountsController
    extends Notifier<Map<int, AccountNotificationCounts>> {
  SteamNotificationCountsController({
    DateTime Function()? clock,
    this.minRequestGap = const Duration(seconds: 1),
    this.refreshInterval = const Duration(minutes: 2),
  }) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  final Duration minRequestGap;
  final Duration refreshInterval;
  final _pending = <_SessionKey, Future<void>>{};
  final _scopes = <int, SteamRequestScope>{};
  final _versions = <int, int>{};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  int _epoch = 0;

  bool get _enabled => ref.read(steamNotificationCountsEnabledProvider);

  @override
  Map<int, AccountNotificationCounts> build() {
    ref.listen(steamNotificationCountsEnabledProvider, (_, enabled) {
      if (!enabled) {
        _cancelAll();
        state = const {};
      }
    });
    ref.onDispose(_cancelAll);
    return const {};
  }

  void _cancelAll() {
    _epoch++;
    for (final scope in _scopes.values) {
      scope.cancel();
    }
    _scopes.clear();
    _pending.clear();
    _versions.clear();
  }

  /// A hidden/background home cancels both its active read and queued reads.
  /// Keep known counters for display, but retry cancelled work on resume.
  void cancelRefreshes() {
    if (!ref.mounted) return;
    _cancelAll();
    if (!_enabled) {
      state = const {};
      return;
    }
    state = {
      for (final entry in state.entries)
        entry.key: entry.value.loading
            ? AccountNotificationCounts._(
                entry.value._session,
                counts: entry.value.counts,
                stale: true,
                confirmationStale: true,
              )
            : entry.value,
    };
  }

  void _set(int id, AccountNotificationCounts value) {
    state = {...state, id: value};
  }

  Future<void> refreshAll(
    Iterable<SteamGuardAccount> accounts, {
    bool force = false,
  }) async {
    await Future.wait(accounts.map((a) => refresh(a, force: force)));
  }

  /// Read-only and globally serialized. Background failures retain the last
  /// known counts as stale; they never become a fabricated zero.
  Future<void> refresh(SteamGuardAccount account, {bool force = false}) {
    if (!ref.mounted ||
        !_enabled ||
        account.session.accessToken?.isNotEmpty != true) {
      return Future.value();
    }
    final session = _key(account);
    final running = _pending[session];
    if (running != null) return running;
    final cached = state[account.steamId];
    final previous = cached?.matches(account) == true ? cached : null;
    final now = _now();
    if (!force &&
        previous?.lastAttempt != null &&
        now.difference(previous!.lastAttempt!) < refreshInterval) {
      return Future.value();
    }
    final epoch = _epoch;
    final version = _versions[account.steamId] ?? 0;
    bool current() =>
        ref.mounted &&
        _enabled &&
        _epoch == epoch &&
        (_versions[account.steamId] ?? 0) == version &&
        _key(account) == session &&
        state[account.steamId]?._session == session;
    _set(
      account.steamId,
      AccountNotificationCounts._(
        session,
        counts: previous?.counts ?? const SteamNotificationCounts(),
        loading: true,
        stale: previous?.stale ?? false,
        confirmationStale: previous?.confirmationStale ?? false,
        lastAttempt: now,
      ),
    );
    late final Future<void> request;
    request = _queue
        .then((_) async {
          if (!current()) return;
          if (_lastRequest != null) {
            final wait = minRequestGap - _now().difference(_lastRequest!);
            if (wait > Duration.zero) await Future<void>.delayed(wait);
          }
          if (!current()) return;
          _lastRequest = _now();
          final scope = SteamRequestScope(timeout: const Duration(seconds: 8));
          _scopes[account.steamId] = scope;
          try {
            final counts = await scope.run(
              () => ref
                  .read(steamNotificationsClientProvider)
                  .fetchCounts(account),
            );
            if (current()) {
              _set(
                account.steamId,
                AccountNotificationCounts._(
                  session,
                  counts: counts,
                  lastAttempt: _now(),
                ),
              );
            }
          } catch (_) {
            if (current()) {
              _set(
                account.steamId,
                AccountNotificationCounts._(
                  session,
                  counts: previous?.counts ?? const SteamNotificationCounts(),
                  stale: true,
                  confirmationStale: true,
                  lastAttempt: _now(),
                ),
              );
            }
          } finally {
            if (identical(_scopes[account.steamId], scope)) {
              _scopes.remove(account.steamId);
            }
          }
        })
        .whenComplete(() {
          if (identical(_pending[session], request)) _pending.remove(session);
        });
    _pending[session] = request;
    _queue = request;
    return request;
  }

  void _advance(int id) {
    _versions[id] = (_versions[id] ?? 0) + 1;
    _scopes.remove(id)?.cancel();
    _pending.removeWhere((session, _) => session.$1 == id);
  }

  /// Call after a user action; older in-flight reads cannot restore old counts.
  void invalidate(SteamGuardAccount account) {
    if (!ref.mounted) return;
    _advance(account.steamId);
    final previous = state[account.steamId];
    if (previous?.matches(account) != true) return;
    _set(
      account.steamId,
      AccountNotificationCounts._(
        _key(account),
        counts: previous!.counts,
        stale: true,
        confirmationStale: true,
      ),
    );
  }

  /// Caller must verify its fetch still belongs to the same account session.
  void recordCounts(SteamGuardAccount account, SteamNotificationCounts counts) {
    if (!ref.mounted || !_enabled) return;
    _advance(account.steamId);
    _set(
      account.steamId,
      AccountNotificationCounts._(
        _key(account),
        counts: counts,
        lastAttempt: _now(),
      ),
    );
  }

  /// A successfully loaded confirmation list can refresh this one count
  /// without inventing friend/unread counts or issuing a second network read.
  void recordConfirmationCount(SteamGuardAccount account, int count) {
    if (!ref.mounted || !_enabled) return;
    _advance(account.steamId);
    final cached = state[account.steamId];
    final previous = cached?.matches(account) == true ? cached : null;
    _set(
      account.steamId,
      AccountNotificationCounts._(
        _key(account),
        counts: SteamNotificationCounts(
          confirmationCount: count,
          pendingFriendCount: previous?.pendingFriendCount,
          unreadCount: previous?.unreadCount,
        ),
        stale: previous?.stale ?? true,
        lastAttempt: previous?.lastAttempt,
      ),
    );
  }

  /// The request list is authoritative after accepting/rejecting an invite.
  /// Keep unread notifications and confirmations independent of this count.
  void recordFriendRequestCount(SteamGuardAccount account, int count) {
    if (!ref.mounted || !_enabled) return;
    _advance(account.steamId);
    final cached = state[account.steamId];
    final previous = cached?.matches(account) == true ? cached : null;
    _set(
      account.steamId,
      AccountNotificationCounts._(
        _key(account),
        counts: SteamNotificationCounts(
          confirmationCount: previous?.confirmationCount,
          pendingFriendCount: count,
          unreadCount: previous?.unreadCount,
        ),
        stale: previous?.stale ?? true,
        confirmationStale: previous?.confirmationStale ?? true,
        lastAttempt: previous?.lastAttempt,
      ),
    );
  }
}
