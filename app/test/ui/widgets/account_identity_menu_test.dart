import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/ui/widgets/account_identity_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SteamGuardAccount _account() => SteamGuardAccount(
  personaName: ' Steam nickname ',
  accountName: 'login_name',
  session: SessionData(steamId: 76561198000000000),
);

Widget _app({
  required TargetPlatform platform,
  SteamGuardAccount? account,
  VoidCallback? onTap,
  AvaThemeVariant variant = AvaThemeVariant.dark,
}) => MaterialApp(
  theme: buildAvaTheme(variant).copyWith(platform: platform),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: AccountIdentityMenu(
        account: account ?? _account(),
        onTap: onTap,
        child: const Text('Selected name'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, TargetPlatform platform) async {
  if (platform == TargetPlatform.android) {
    await tester.longPress(find.text('Selected name'));
  } else {
    await tester.tap(
      find.text('Selected name'),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  final writes = <String>[];
  Future<void> Function()? writeResult;
  setUp(() {
    writes.clear();
    writeResult = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String);
            await writeResult?.call();
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('$platform offers exact fields without changing primary tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_app(platform: platform, onTap: () => taps++));
      await tester.tap(find.text('Selected name'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      for (final entry in {
        'persona': ' Steam nickname ',
        'login': 'login_name',
        'id': '76561198000000000',
      }.entries) {
        await _open(tester, platform);
        expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('account-copy-${entry.key}')));
        await tester.pumpAndSettle();
        expect(writes.last, entry.value);
      }
      expect(taps, 1);
      expect(writes, [' Steam nickname ', 'login_name', '76561198000000000']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform cancel never writes to clipboard', (tester) async {
      await tester.pumpWidget(_app(platform: platform));
      await _open(tester, platform);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      expect(writes, isEmpty);
      expect(find.text('Copied to clipboard'), findsNothing);
    });
  }

  testWidgets(
    'missing fields stay disabled instead of copying fallback names',
    (tester) async {
      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.windows,
          account: SteamGuardAccount(personaName: ' ', accountName: null),
        ),
      );
      await _open(tester, TargetPlatform.windows);
      for (final key in ['persona', 'login', 'id']) {
        final finder = find.byKey(ValueKey('account-copy-$key'));
        expect(tester.widget<PopupMenuItem<String>>(finder).enabled, isFalse);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }
      expect(writes, isEmpty);
      expect(find.text('Unavailable'), findsNWidgets(3));
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('reports success only after clipboard write completes', (
    tester,
  ) async {
    final completed = Completer<void>();
    writeResult = () => completed.future;
    await tester.pumpWidget(_app(platform: TargetPlatform.android));
    await _open(tester, TargetPlatform.android);
    await tester.tap(find.byKey(const ValueKey('account-copy-id')));
    await tester.pumpAndSettle();
    expect(writes, ['76561198000000000']);
    expect(find.text('Copied to clipboard'), findsNothing);
    completed.complete();
    await tester.pumpAndSettle();
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('clipboard failure is visible and permits a subsequent retry', (
    tester,
  ) async {
    writeResult = () async => throw PlatformException(code: 'fixture_denied');
    await tester.pumpWidget(_app(platform: TargetPlatform.windows));
    await _open(tester, TargetPlatform.windows);
    await tester.tap(find.byKey(const ValueKey('account-copy-id')));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy. Please try again.'), findsOneWidget);
    expect(find.text('Copied to clipboard'), findsNothing);
    expect(tester.takeException(), isNull);
    writeResult = null;
    await _open(tester, TargetPlatform.windows);
    await tester.tap(find.byKey(const ValueKey('account-copy-login')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(writes, ['76561198000000000', 'login_name']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  for (final variant in AvaThemeVariant.values) {
    testWidgets('$variant fits a narrow phone with long identity values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = _account()
        ..personaName = 'A long Steam nickname with several words';
      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.android,
          account: account,
          variant: variant,
        ),
      );
      await _open(tester, TargetPlatform.android);
      expect(find.text(account.personaName!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
