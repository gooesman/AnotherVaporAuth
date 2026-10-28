import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/steam_notifications_provider.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/models/steam_notification.dart';
import 'package:ava/src/ui/widgets/steam_notifications_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets('bell only indicates unread notifications (compact=$compact)', (
      tester,
    ) async {
      final account = SteamGuardAccount(
        session: SessionData(steamId: 1, accessToken: 'fixture'),
      );
      final container = ProviderContainer(
        overrides: [
          steamNotificationCountsEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SteamNotificationsButton(
                account: account,
                compact: compact,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final controller = container.read(
        steamNotificationCountsProvider.notifier,
      );
      for (final unread in [0, 1, 0]) {
        controller.recordCounts(
          account,
          SteamNotificationCounts(unreadCount: unread, pendingFriendCount: 2),
        );
        await tester.pump();
        expect(
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
          unread > 0,
        );
      }
    });
  }
}
