import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_friend.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/protocol/friends_client.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/friends/friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Friends extends FriendsClient {
  _Friends() : super(SteamApiClient());
  @override
  Future<List<SteamFriend>> fetch(SteamGuardAccount account) async =>
      List.generate(
        1000,
        (index) => SteamFriend(
          steamId: '${76561198000000000 + index}',
          name: 'Friend $index',
        ),
      );
}

void main() {
  testWidgets(
    'large friend lists build visible rows and search still finds offscreen friends',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageProvider.overrideWithValue(MemoryStorageProvider('mock')),
            timeAlignerProvider.overrideWithValue(() async {}),
            friendsClientProvider.overrideWithValue(_Friends()),
          ],
          child: MaterialApp(
            theme: buildAvaTheme(AvaThemeVariant.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: FriendsScreen(
              account: SteamGuardAccount(
                session: SessionData(
                  steamId: 76561198000000001,
                  accessToken: 'fake',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final builtRows = find.byType(ListTile).evaluate().length;
      debugPrint('1000 friends: $builtRows rows built initially');
      expect(builtRows, inInclusiveRange(1, 20));
      expect(find.text('Friend 999'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Friend 999');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Friend 999'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('SteamID: 76561198000000999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
