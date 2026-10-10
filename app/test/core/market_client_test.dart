import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_item.dart';
import 'package:ava/src/core/protocol/market_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Community POST that always throws the stale-session exception the status
/// gate raises for a 302/401 reply.
class _AuthThrowingApi extends SteamApiClient {
  @override
  Future<Map<String, dynamic>> communityPostJson(
    String path,
    Map<String, dynamic> form, {
    Map<String, String>? cookies,
    String? referer,
  }) async {
    throw CommunityAuthException(302, path);
  }
}

class _ListingsApi extends SteamApiClient {
  final List<Map<String, dynamic>> pages;
  final starts = <String>[];
  _ListingsApi(this.pages);

  @override
  Future<Map<String, dynamic>> communityGetJson(
    String path,
    Map<String, dynamic> query, {
    Map<String, String>? cookies,
  }) async {
    starts.add(query['start'] as String);
    return pages[starts.length - 1];
  }
}

Map<String, dynamic> _listing(String id, {int active = 1}) => {
  'listingid': id,
  'active': active,
  'price': 115,
  'fee': 15,
  'asset': {'appid': 730, 'contextid': '2', 'id': id, 'name': 'Test item $id'},
};

SteamGuardAccount _account() => SteamGuardAccount(
  identitySecret: 'YQ==',
  session: SessionData(
    steamId: 76561198000000123,
    accessToken: 'tok',
    refreshToken: 'r',
  ),
);

void main() {
  group('MarketClient.isCancelSuccess', () {
    test(
      'bare/empty body (Steam\'s normal removelisting reply) is success',
      () {
        expect(MarketClient.isCancelSuccess(const {}), isTrue);
      },
    );

    test('explicit success:true is success', () {
      expect(MarketClient.isCancelSuccess(const {'success': true}), isTrue);
    });

    test('explicit success:false is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'success': false}), isFalse);
    });

    test('success:false with a message is still a failure', () {
      expect(
        MarketClient.isCancelSuccess(const {
          'success': false,
          'message': 'You already sold this',
        }),
        isFalse,
      );
    });

    test('needauth marker is a failure even without success:false', () {
      expect(MarketClient.isCancelSuccess(const {'needauth': true}), isFalse);
    });

    test('needsauth (alternate key) marker is a failure', () {
      expect(MarketClient.isCancelSuccess(const {'needsauth': true}), isFalse);
    });

    test('needauth wins even if success is truthy', () {
      expect(
        MarketClient.isCancelSuccess(const {'success': true, 'needauth': true}),
        isFalse,
      );
    });

    test('a non-boolean success value does not count as success', () {
      expect(MarketClient.isCancelSuccess(const {'success': 1}), isFalse);
    });
  });

  group('MarketClient.cancel', () {
    test('a stale-session throw yields false, never a fake success', () async {
      // Before the status gate a 302/401 empty body decoded to {} and
      // isCancelSuccess({}) reported "Listing cancelled." while nothing
      // happened; the throw must land in cancel's catch-all as false.
      final client = MarketClient(_AuthThrowingApi());
      expect(await client.cancel(_account(), '123456789'), isFalse);
    });
  });

  group('MarketClient.myListings', () {
    test(
      'buyer total includes fees and original listing currency is retained',
      () {
        final listing = MarketListing.fromJson({
          ..._listing('1'),
          'price': 100,
          'fee': 15,
          'currencyid': '2023',
        });
        expect(listing.buyerPrice, 115);
        expect(listing.sellerReceives, 100);
        expect(listing.currency, 23);
        expect(listing.priceAvailable, isTrue);
      },
    );

    test('converted price, fee and currency are used together', () {
      final listing = MarketListing.fromJson({
        ..._listing('1'),
        'price': 1000,
        'fee': 150,
        'currencyid': '2023',
        'converted_price': 140,
        'converted_fee': 21,
        'converted_currencyid': '2001',
      });
      expect(listing.buyerPrice, 161);
      expect(listing.sellerReceives, 140);
      expect(listing.currency, 1);
    });

    test(
      'partial conversion cannot combine prices from different currencies',
      () {
        final listing = MarketListing.fromJson({
          ..._listing('1'),
          'price': 1000,
          'fee': 150,
          'currencyid': '2023',
          'converted_price': 140,
          'converted_currencyid': '2001',
        });
        expect(listing.buyerPrice, 1150);
        expect(listing.currency, 23);
      },
    );

    test(
      'missing held price and currency do not become an available zero price',
      () {
        final listing = MarketListing.fromJson({
          'listingid': '1',
          'active': 0,
          'asset': {'appid': 730},
        }, state: MarketListingState.onHold);
        expect(listing.priceAvailable, isFalse);
        expect(listing.currency, isNull);
      },
    );

    test(
      'keeps active, held, pending and inactive records instead of hiding them',
      () async {
        final api = _ListingsApi([
          {
            'success': true,
            'listings': [_listing('1'), _listing('4', active: 0)],
            'listings_on_hold': [
              {..._listing('2', active: 0), 'time_finish_hold': '1900000000'},
            ],
            'listings_to_confirm': [_listing('3', active: 0)],
          },
        ]);
        final result = await MarketClient(api).myListings(_account());
        expect(result.map((l) => l.listingId), ['1', '4', '2', '3']);
        expect(result.map((l) => l.state), [
          MarketListingState.active,
          MarketListingState.inactive,
          MarketListingState.onHold,
          MarketListingState.pendingConfirmation,
        ]);
        expect(result[2].holdUntil, 1900000000);
      },
    );

    test('joins referenced asset details using app, context and asset ID', () {
      final result = MarketClient.parseListings({
        'listings_on_hold': [
          {
            'listingid': '2',
            'asset': {'appid': 730, 'contextid': '2', 'id': '900'},
          },
        ],
        'assets': {
          '730': {
            '2': {
              '900': {
                'name': 'Held test item',
                'market_hash_name': 'Held item',
                'icon_url': 'icon',
              },
            },
          },
        },
      });
      expect(result.single.name, 'Held test item');
      expect(result.single.marketHashName, 'Held item');
      expect(result.single.iconUrl, endsWith('/icon'));
    });

    test('a hold bucket wins over a duplicate active entry', () {
      final result = MarketClient.parseListings({
        'listings': [_listing('1')],
        'listings_on_hold': [_listing('1', active: 0)],
      });
      expect(result, hasLength(1));
      expect(result.single.state, MarketListingState.onHold);
    });

    test('loads later pages and deduplicates repeated hold buckets', () async {
      final api = _ListingsApi([
        {
          'success': true,
          'total_count': 3,
          'listings': [_listing('1'), _listing('2')],
          'listings_on_hold': [_listing('4', active: 0)],
        },
        {
          'success': true,
          'total_count': 3,
          'listings': [_listing('3')],
          'listings_on_hold': [_listing('4', active: 0)],
        },
      ]);
      final result = await MarketClient(api).myListings(_account(), count: 2);
      expect(api.starts, ['0', '2']);
      expect(result.map((l) => l.listingId), ['1', '2', '4', '3']);
    });

    test(
      'repeating pages are reported as an error, not a complete listing set',
      () async {
        final page = {
          'success': true,
          'total_count': 5,
          'listings': [_listing('1')],
        };
        final api = _ListingsApi([page, page]);
        await expectLater(
          MarketClient(api).myListings(_account(), count: 1),
          throwsFormatException,
        );
        expect(api.starts, ['0', '1']);
      },
    );

    test(
      'explicit auth failure offers reauthentication instead of no listings',
      () async {
        final api = _ListingsApi([
          {'success': false, 'needauth': true},
        ]);
        await expectLater(
          MarketClient(api).myListings(_account()),
          throwsA(isA<CommunityAuthException>()),
        );
      },
    );

    test(
      'repeating the final page cannot masquerade as complete pagination',
      () async {
        final page = {
          'success': true,
          'total_count': 2,
          'listings': [_listing('1')],
        };
        final api = _ListingsApi([
          page,
          {
            ...page,
            // A new held record must not disguise the lack of active-page progress.
            'listings_on_hold': [_listing('3', active: 0)],
          },
        ]);
        await expectLater(
          MarketClient(api).myListings(_account(), count: 1),
          throwsFormatException,
        );
        expect(api.starts, ['0', '1']);
      },
    );

    test(
      'an empty later page before the advertised total is an error',
      () async {
        final api = _ListingsApi([
          {
            'success': true,
            'total_count': 2,
            'listings': [_listing('1')],
          },
          {'success': true, 'total_count': 2, 'listings': []},
        ]);
        await expectLater(
          MarketClient(api).myListings(_account(), count: 1),
          throwsFormatException,
        );
        expect(api.starts, ['0', '1']);
      },
    );

    test(
      'partly overlapping final page must still satisfy unique total',
      () async {
        final api = _ListingsApi([
          {
            'success': true,
            'total_count': 4,
            'listings': [_listing('1'), _listing('2')],
          },
          {
            'success': true,
            'total_count': 4,
            'listings': [_listing('2'), _listing('3')],
          },
        ]);
        await expectLater(
          MarketClient(api).myListings(_account(), count: 2),
          throwsFormatException,
        );
      },
    );

    test('soft failure is not treated as an empty market', () async {
      final api = _ListingsApi([
        {'success': false},
      ]);
      await expectLater(
        MarketClient(api).myListings(_account()),
        throwsFormatException,
      );
    });

    test(
      'successful empty market and empty array asset maps are supported',
      () async {
        final api = _ListingsApi([
          {
            'success': true,
            'listings': [],
            'assets': [],
            'listings_on_hold': [],
            'listings_to_confirm': [],
          },
        ]);
        expect(await MarketClient(api).myListings(_account()), isEmpty);
      },
    );
  });
}
