import 'package:ava/src/core/models/steam_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only confirmed notification schemas expose display text', () {
    for (final type in [3, 6, 10]) {
      final notification = SteamNotification(
        id: '1',
        type: type,
        body: {
          'title': ' Title ',
          'text': 'Comment',
          'body': 'Body',
          'message': 'Unverified field',
        },
      );
      expect(notification.displayTitle, 'Title');
      expect(notification.displayBody, type == 3 ? 'Comment' : 'Body');
    }
    const general = SteamNotification(
      id: '1',
      type: 10,
      body: {
        'display_name': 'Account notice',
        'title': 123,
        'body': ['private'],
      },
    );
    expect(general.displayTitle, 'Account notice');
    expect(general.displayBody, isNull);
    const unknown = SteamNotification(
      id: '1',
      type: 999,
      body: {
        'title': 'private token',
        'body': 'private data',
        'text': 'private text',
      },
    );
    expect(unknown.displayTitle, isNull);
    expect(unknown.displayBody, isNull);
  });

  test('gift, comment, request and trade account IDs become SteamID64', () {
    for (final entry in {
      2: 'gifter_account',
      3: 'account_id',
      5: 'requestor_id',
      9: 'sender',
    }.entries) {
      final notification = SteamNotification(
        id: '1',
        type: entry.key,
        body: {entry.value: '123'},
      );
      expect(notification.partnerSteamId, '76561197960265851');
      for (final value in [
        0,
        -1,
        '4294967296',
        '76561198000000001',
        true,
        1.5,
        '1x',
      ]) {
        expect(
          SteamNotification(
            id: '1',
            type: entry.key,
            body: {entry.value: value},
          ).partnerSteamId,
          isNull,
        );
      }
    }
    const ownerOnly = SteamNotification(
      id: '1',
      type: 3,
      body: {'owner_steam_id': '76561198000000001'},
    );
    expect(
      ownerOnly.partnerSteamId,
      isNull,
    ); // The page owner is not the commenter.
    expect(
      const SteamNotification(
        id: '1',
        type: 9,
        body: {'sender': 4294967295},
      ).partnerSteamId,
      '76561202255233023',
    );
  });

  test(
    'inventory keys are type-specific and preserve exact decimal identity',
    () {
      const notification = SteamNotification(
        id: '1',
        type: 4,
        body: {
          'app_id': '730',
          'context_id': '2',
          'asset_id': '18446744073709551615',
        },
      );
      expect(notification.inventoryAppId, 730);
      expect(notification.contextId, '2');
      expect(notification.assetId, '18446744073709551615');
      const alternateKeys = SteamNotification(
        id: '1',
        type: 4,
        body: {'appid': 730, 'contextid': '2', 'assetid': '900'},
      );
      expect(alternateKeys.inventoryAppId, isNull);
      expect(alternateKeys.contextId, isNull);
      expect(alternateKeys.assetId, isNull);
      const otherType = SteamNotification(
        id: '1',
        type: 9,
        body: {'app_id': 730, 'context_id': '2', 'asset_id': '900'},
      );
      expect(otherType.inventoryAppId, isNull);
      expect(otherType.contextId, isNull);
      expect(otherType.assetId, isNull);
    },
  );
}
