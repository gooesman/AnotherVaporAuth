import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_friend.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/core/protocol/inventory_client.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/account_dashboard_loader.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/steam_request_scope.dart';
import 'package:dio/dio.dart';
// Already pinned through flutter_test; no new runtime or test dependency.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final cancelled = <String>[];
  FutureOr<ResponseBody> Function(RequestOptions) respond = _success;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    cancelFuture?.then((_) => cancelled.add(options.uri.path));
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, Object?> body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
ResponseBody _success(RequestOptions request) => request.uri.path == '/market/'
    ? ResponseBody.fromString(
        'var g_rgWalletInfo = {"wallet_currency":23,"wallet_balance":12345};',
        200,
      )
    : _json({'success': true, 'listings': [], 'total_count': 0});
ResponseBody _summaries(RequestOptions request) {
  if (request.uri.path.endsWith('/friends/')) {
    return ResponseBody.fromString('''
      <div class="profile_friends">
        <div class="friend_block_v2 online" data-steamid="76561198000000002">
          <div class="friend_block_content">Synthetic friend<br></div>
        </div>
      </div>
    ''', 200);
  }
  if (request.uri.path.endsWith('/inventory/')) {
    return ResponseBody.fromString('''
      var g_rgAppContextData = {"730":{"name":"Counter-Strike 2","rgContexts":{
        "2":{"name":"Inventory","asset_count":12},
        "16":{"name":"Trade-protected Items","asset_count":3}
      }}};
    ''', 200);
  }
  return _success(request);
}

SteamGuardAccount _account([int id = 1]) => SteamGuardAccount(
  accountName: 'demo_$id',
  session: SessionData(
    steamId: id,
    accessToken: 'synthetic',
    refreshToken: 'synthetic-refresh',
  ),
);

(_Adapter, AccountDashboardLoader, SteamApiClient) _loader(
  FakeAsync clock, {
  int maxEntries = 16,
  Future<void> Function(SteamGuardAccount)? persist,
}) {
  final adapter = _Adapter();
  final dio = Dio(
    BaseOptions(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = adapter;
  final api = SteamApiClient(dio: dio);
  return (
    adapter,
    AccountDashboardLoader(
      inventory: InventoryClient(api),
      market: MarketClient(api),
      api: api,
      persistSession: persist ?? (_) async {},
      now: () => DateTime(2026).add(clock.elapsed),
      maxEntries: maxEntries,
    ),
    api,
  );
}

void _flush(FakeAsync clock) {
  clock.flushMicrotasks();
  clock.elapse(Duration.zero);
  clock.flushMicrotasks();
}

void main() {
  test('optional summaries stay idle until a reader enables each card', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      adapter.respond = _summaries;
      final account = _account(76561198000000001);
      final disabled = loader.acquire(account, wallet: false, listings: false);
      _flush(clock);
      disabled.refresh();
      _flush(clock);
      expect(adapter.requests, isEmpty);
      final enabled = loader.acquire(
        account,
        wallet: false,
        listings: false,
        friends: true,
        inventory: true,
      );
      _flush(clock);
      expect(adapter.requests.map((r) => r.uri.path), [
        '/profiles/76561198000000001/friends/',
        '/profiles/76561198000000001/inventory/',
      ]);
      expect(enabled.data.friends.value?.single.name, 'Synthetic friend');
      expect(enabled.data.friends.value?.single.state, SteamFriendState.online);
      expect(enabled.data.inventory.value?.games.map((g) => g.itemCount), [
        12,
        3,
      ]);
      expect(enabled.data.inventory.value?.games.map((g) => g.contextId), [
        '2',
        '16',
      ]);
      expect(enabled.friends, isTrue);
      expect(enabled.inventory, isTrue);
      expect(enabled.data.friends.failed, isFalse);
      expect(enabled.data.inventory.failed, isFalse);
      disabled.release();
      enabled.release();
      loader.clear();
    });
  });

  test(
    'summary readers share fetches and cancel each disabled card separately',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        final pending = Completer<ResponseBody>();
        adapter.respond = (_) => pending.future;
        final account = _account(76561198000000001);
        final both = loader.acquire(
          account,
          wallet: false,
          listings: false,
          friends: true,
          inventory: true,
        );
        final inventoryOnly = loader.acquire(
          account,
          wallet: false,
          listings: false,
          inventory: true,
        );
        _flush(clock);
        expect(adapter.requests, hasLength(2));
        expect(identical(both.data, inventoryOnly.data), isTrue);
        both.release();
        _flush(clock);
        expect(adapter.cancelled, ['/profiles/76561198000000001/friends/']);
        expect(inventoryOnly.data.friends.loading, isFalse);
        expect(inventoryOnly.data.inventory.loading, isTrue);
        inventoryOnly.release();
        _flush(clock);
        expect(
          adapter.cancelled,
          contains('/profiles/76561198000000001/inventory/'),
        );
        pending.complete(_summaries(adapter.requests.last));
        _flush(clock);
        expect(inventoryOnly.data.inventory.value, isNull);
        loader.clear();
      });
    },
  );

  test(
    'a stalled friends card does not block inventory or trigger item requests',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        adapter.respond = (request) => request.uri.path.endsWith('/friends/')
            ? Completer<ResponseBody>().future
            : _summaries(request);
        final lease = loader.acquire(
          _account(76561198000000001),
          wallet: false,
          listings: false,
          friends: true,
          inventory: true,
        );
        _flush(clock);
        expect(lease.data.friends.loading, isTrue);
        expect(lease.data.inventory.value?.games, hasLength(2));
        clock.elapse(const Duration(seconds: 12));
        _flush(clock);
        expect(lease.data.friends.failed, isTrue);
        expect(lease.data.friends.needsLogin, isFalse);
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.any((r) => r.uri.path.startsWith('/inventory/')),
          isFalse,
        );
        lease.release();
        loader.clear();
      });
    },
  );

  test('summary cache expires, refreshes and is cleared with the account', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      adapter.respond = _summaries;
      final account = _account(76561198000000001);
      DashboardLease acquire() => loader.acquire(
        account,
        wallet: false,
        listings: false,
        friends: true,
        inventory: true,
      );
      var lease = acquire();
      _flush(clock);
      lease.release();
      lease = acquire();
      _flush(clock);
      expect(adapter.requests, hasLength(2));
      lease.refresh();
      lease.refresh();
      _flush(clock);
      expect(adapter.requests, hasLength(4));
      lease.release();
      clock.elapse(const Duration(seconds: 31));
      lease = acquire();
      _flush(clock);
      expect(adapter.requests, hasLength(6));
      loader.retainAccounts([]);
      expect(lease.data.friends.value, isNull);
      expect(lease.data.inventory.value, isNull);
      expect(lease.data.friends.checkedAt, isNull);
      expect(lease.data.inventory.checkedAt, isNull);
      lease.release();
      loader.clear();
    });
  });

  test(
    'moving the same account object to another source discards its old cache',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        final account = _account();
        final local = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        account.fromPortable = true;
        expect(loader.matches(local, account), isFalse);
        loader.retainAccounts([account]);
        expect(local.data.wallet.value, isNull);
        local.release();
        final portable = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        expect(adapter.requests, hasLength(2));
        portable.release();
        loader.clear();
      });
    },
  );

  test('cards start together and a stalled wallet does not block listings', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      final pending = Completer<ResponseBody>();
      adapter.respond = (request) =>
          request.uri.path == '/market/' ? pending.future : _success(request);
      final lease = loader.acquire(_account(), wallet: true, listings: true);
      _flush(clock);
      expect(adapter.requests.map((r) => r.uri.path), [
        '/market/',
        '/market/mylistings/',
      ]);
      expect(lease.data.wallet.loading, isTrue);
      expect(lease.data.listings.value, isEmpty);
      expect(lease.data.listings.loading, isFalse);
      clock.elapse(const Duration(seconds: 12));
      _flush(clock);
      expect(lease.data.wallet.loading, isFalse);
      expect(lease.data.wallet.failed, isTrue);
      expect(lease.data.wallet.needsLogin, isFalse);
      expect(lease.data.wallet.value, isNull);
      expect(adapter.cancelled, contains('/market/'));
      expect(adapter.requests, hasLength(2), reason: 'No offline retry/login');
      lease.release();
      loader.clear();
    });
  });

  test(
    'last card subscriber leaving cancels HTTP; another view keeps it alive',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        final pending = Completer<ResponseBody>();
        adapter.respond = (_) => pending.future;
        final account = _account();
        final first = loader.acquire(account, wallet: true, listings: false);
        final second = loader.acquire(
          _account(),
          wallet: true,
          listings: false,
        );
        _flush(clock);
        expect(identical(first.data, second.data), isTrue);
        expect(adapter.requests, hasLength(1));
        first.release();
        _flush(clock);
        expect(adapter.cancelled, isEmpty);
        second.release();
        _flush(clock);
        expect(adapter.cancelled, ['/market/']);
        pending.complete(_success(adapter.requests.first));
        _flush(clock);
        expect(second.data.wallet.value, isNull);
        loader.clear();
      });
    },
  );

  test(
    'fresh reads reuse memory, manual retry bypasses it, expiry reloads',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        var lease = loader.acquire(_account(), wallet: true, listings: false);
        _flush(clock);
        lease.release();
        lease = loader.acquire(_account(), wallet: true, listings: false);
        _flush(clock);
        expect(adapter.requests, hasLength(1));
        lease.refresh();
        lease.refresh();
        _flush(clock);
        expect(adapter.requests, hasLength(2));
        lease.release();
        clock.elapse(const Duration(seconds: 31));
        lease = loader.acquire(_account(), wallet: true, listings: false);
        _flush(clock);
        expect(adapter.requests, hasLength(3));
        lease.release();
        loader.clear();
      });
    },
  );

  test(
    'source, credentials and language partition the bounded memory cache',
    () {
      fakeAsync((clock) {
        final (adapter, loader, api) = _loader(clock, maxEntries: 2);
        final account = _account();
        var lease = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        lease.release();
        final portable = _account()..fromPortable = true;
        lease = loader.acquire(portable, wallet: true, listings: false);
        _flush(clock);
        lease.release();
        final updated = _account()..session.accessToken = 'new-session';
        lease = loader.acquire(updated, wallet: true, listings: false);
        _flush(clock);
        lease.release();
        expect(adapter.requests, hasLength(3));
        // The least-recent inactive original entry was evicted.
        lease = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        expect(adapter.requests, hasLength(4));
        lease.release();
        api.steamLanguage = 'schinese';
        lease = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        expect(adapter.requests, hasLength(5));
        lease.release();
        loader.clear();
      });
    },
  );

  test('lock/clear removes balances and cancels outstanding reads', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      final first = loader.acquire(_account(), wallet: true, listings: false);
      _flush(clock);
      expect(first.data.wallet.value?.balance, 12345);
      adapter.respond = (_) => Completer<ResponseBody>().future;
      first.refresh();
      _flush(clock);
      loader.clear();
      _flush(clock);
      expect(first.data.wallet.value, isNull);
      expect(first.data.wallet.loading, isFalse);
      expect(adapter.cancelled, contains('/market/'));
      first.release();
    });
  });

  test(
    'startup token rotation retains fresh cache through account publication',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        final account = _account();
        final initial = loader.acquire(account, wallet: true, listings: false);
        _flush(clock);
        account.session.accessToken = 'renewed-at-startup';
        loader.retainAccounts([account]);
        initial.release();
        final reopened = loader.acquire(
          _account()..session.accessToken = 'renewed-at-startup',
          wallet: true,
          listings: false,
        );
        _flush(clock);
        expect(reopened.data.wallet.value?.balance, 12345);
        expect(adapter.requests, hasLength(1));
        reopened.release();
        loader.clear();
      });
    },
  );

  test('session-key collisions retain one entry and cancel duplicate HTTP', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      final oldAccount = _account();
      final currentAccount = _account()..session.accessToken = 'renewed';
      adapter.respond = (_) => Completer<ResponseBody>().future;
      final old = loader.acquire(oldAccount, wallet: true, listings: false);
      final current = loader.acquire(
        currentAccount,
        wallet: true,
        listings: false,
      );
      _flush(clock);
      oldAccount.session.accessToken = 'renewed';
      final overlap = loader.acquire(
        currentAccount,
        wallet: true,
        listings: false,
      );
      _flush(clock);
      expect(
        identical(overlap.data, current.data),
        isTrue,
        reason: 'Exact session entry wins before publication re-keys others',
      );
      loader.retainAccounts([currentAccount]);
      _flush(clock);
      expect(adapter.cancelled, hasLength(1));
      expect(old.data.wallet.loading, isFalse);
      expect(current.data.wallet.loading, isTrue);
      final reopened = loader.acquire(
        currentAccount,
        wallet: true,
        listings: false,
      );
      _flush(clock);
      expect(identical(reopened.data, current.data), isTrue);
      expect(adapter.requests, hasLength(2));
      old.release();
      current.release();
      overlap.release();
      reopened.release();
      loader.clear();
    });
  });

  test('active cache overflow shrinks after views release their entries', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock, maxEntries: 2);
      final first = loader.acquire(_account(1), wallet: true, listings: false);
      final second = loader.acquire(_account(2), wallet: true, listings: false);
      final third = loader.acquire(_account(3), wallet: true, listings: false);
      _flush(clock);
      expect(first.data.wallet.value?.balance, 12345);
      first.release();
      expect(
        first.data.wallet.value,
        isNull,
        reason: 'Released overflow is evicted',
      );
      second.release();
      third.release();
      final reopened = loader.acquire(
        _account(1),
        wallet: true,
        listings: false,
      );
      _flush(clock);
      expect(adapter.requests, hasLength(4));
      reopened.release();
      loader.clear();
    });
  });

  test(
    'removing one account clears only that identity and later reads restart',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        final first = loader.acquire(
          _account(1),
          wallet: true,
          listings: false,
        );
        final second = loader.acquire(
          _account(2),
          wallet: true,
          listings: false,
        );
        _flush(clock);
        loader.retainAccounts([_account(2)]);
        expect(first.data.wallet.value, isNull);
        expect(second.data.wallet.value?.balance, 12345);
        first.release();
        second.release();
        final added = loader.acquire(
          _account(1),
          wallet: true,
          listings: false,
        );
        _flush(clock);
        expect(adapter.requests, hasLength(3));
        added.release();
        loader.clear();
      });
    },
  );

  test('two authentication failures share one renewal and persist it once', () {
    fakeAsync((clock) {
      var persisted = 0;
      final (adapter, loader, _) = _loader(
        clock,
        persist: (_) async {
          persisted++;
        },
      );
      final tokenResponse = Completer<ResponseBody>();
      final account = _account();
      adapter.respond = (request) {
        if (request.uri.path.contains('GenerateAccessTokenForApp')) {
          return tokenResponse.future;
        }
        if (account.session.accessToken == 'synthetic') return _json({}, 401);
        return _success(request);
      };
      final lease = loader.acquire(account, wallet: true, listings: true);
      _flush(clock);
      expect(adapter.requests, hasLength(3));
      final bytes = (ProtoWriter()..writeString(1, 'renewed')).toBytes();
      tokenResponse.complete(ResponseBody.fromBytes(bytes, 200));
      _flush(clock);
      expect(persisted, 1);
      expect(account.session.accessToken, 'renewed');
      expect(lease.data.wallet.value?.balance, 12345);
      expect(lease.data.listings.value, isEmpty);
      lease.release();
      final reopened = loader.acquire(
        _account()..session.accessToken = 'renewed',
        wallet: true,
        listings: true,
      );
      _flush(clock);
      expect(adapter.requests, hasLength(5));
      reopened.release();
      loader.clear();
    });
  });

  test('renewal network failure is unavailable, not a request to re-login', () {
    fakeAsync((clock) {
      final (adapter, loader, _) = _loader(clock);
      adapter.respond = (request) =>
          request.uri.path.contains('GenerateAccessTokenForApp')
          ? throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionTimeout,
            )
          : _json({}, 401);
      final lease = loader.acquire(_account(), wallet: true, listings: true);
      _flush(clock);
      expect(adapter.requests, hasLength(3));
      expect(lease.data.wallet.failed, isTrue);
      expect(lease.data.wallet.needsLogin, isFalse);
      expect(lease.data.listings.needsLogin, isFalse);
      adapter.respond = _success;
      lease.refresh();
      _flush(clock);
      expect(lease.data.wallet.value?.balance, 12345);
      lease.release();
      loader.clear();
    });
  });

  test(
    'listing pagination uses one deadline and cancellation reaches next page',
    () {
      fakeAsync((clock) {
        final (adapter, loader, _) = _loader(clock);
        adapter.respond = (request) {
          if (request.queryParameters['start'] == '0') {
            return _json({
              'success': true,
              'total_count': 2,
              'listings': [
                {
                  'listingid': '123',
                  'asset': {'appid': 730, 'name': 'Synthetic'},
                },
              ],
            });
          }
          return Completer<ResponseBody>().future;
        };
        final lease = loader.acquire(_account(), wallet: false, listings: true);
        _flush(clock);
        expect(adapter.requests, hasLength(2));
        final tokens = adapter.requests.map((r) => r.cancelToken).toSet();
        expect(tokens, hasLength(1));
        expect(tokens.single, isNotNull);
        clock.elapse(const Duration(seconds: 12));
        _flush(clock);
        expect(lease.data.listings.loading, isFalse);
        expect(
          lease.data.listings.value,
          isNull,
          reason: 'Partial counts are not complete counts',
        );
        expect(adapter.cancelled, hasLength(2));
        lease.release();
        loader.clear();
      });
    },
  );

  test(
    'HTML redirects keep scope while an unrelated request stays uncancelled',
    () {
      fakeAsync((clock) {
        final (adapter, loader, api) = _loader(clock);
        adapter.respond = (request) => request.uri.path == '/market/'
            ? ResponseBody.fromString(
                '',
                302,
                headers: {
                  'location': ['/market/eligibilitycheck'],
                },
              )
            : Completer<ResponseBody>().future;
        final scoped = SteamRequestScope();
        Object? error;
        scoped.run(() => api.communityGetText('/market/')).catchError((
          Object e,
        ) {
          error = e;
          return '';
        });
        api.communityGetJson('/unrelated', {}).ignore();
        _flush(clock);
        scoped.cancel();
        _flush(clock);
        expect(error, isA<DioException>());
        expect(
          adapter.cancelled,
          containsAll(['/market/', '/market/eligibilitycheck']),
        );
        expect(adapter.cancelled, isNot(contains('/unrelated')));
        expect(
          adapter.requests
              .singleWhere((r) => r.uri.path == '/unrelated')
              .cancelToken,
          isNull,
        );
        loader.clear();
      });
    },
  );
}
