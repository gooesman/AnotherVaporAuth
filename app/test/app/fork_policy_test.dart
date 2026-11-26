import 'dart:io';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/settings_store.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/entitlement.dart';
import 'package:ava/src/core/fork_policy.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/disabled_entitlement.dart';
import 'package:ava/src/services/entitlement_store.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/paywall_screen.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:ava/src/ui/widgets/ava_banner.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsStore {
  _Settings(super.storage);
  int tokenReads = 0;
  int tokenWrites = 0;
  int tokenClears = 0;
  String? skin;
  String device = 'existing-sync-device';

  @override
  Future<String?> loadEntitlementToken() async {
    tokenReads++;
    return 'old-upstream-token';
  }

  @override
  Future<void> saveEntitlementToken(String raw) async {
    tokenWrites++;
  }

  @override
  Future<void> clearEntitlementToken() async {
    tokenClears++;
  }

  @override
  Future<String?> loadSkin() async => skin;

  @override
  Future<void> saveSkin(String value) async {
    skin = value;
  }

  @override
  Future<String?> loadDeviceId() async => device;
}

class _NoUpstreamApi implements EntitlementApi {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('The local fork must never call upstream Pro services');
  }
}

class _Unlocked extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(ref.read(storageProvider)),
    accounts: const [],
    locked: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late MemoryStorageProvider storage;
  late _Settings settings;
  late _NoUpstreamApi api;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ava-fork-policy-');
    storage = MemoryStorageProvider('${temp.path}/maFiles');
    settings = _Settings(storage);
    api = _NoUpstreamApi();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        settingsStoreProvider.overrideWithValue(settings),
        entitlementApiProvider.overrideWithValue(api),
        appControllerProvider.overrideWith(_Unlocked.new),
        startupVerificationEnabledProvider.overrideWith((ref) async => true),
        appVersionProvider.overrideWith((ref) async => '1.5.1-fork'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c, Widget child) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: buildAvaTheme(AvaThemeVariant.light),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  test(
    'fork default is explicit and both upstream adapters are inert',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(kForkLocalFeatures, isTrue);
      expect(c.read(upstreamProEnabledProvider), isFalse);
      expect(c.read(entitlementApiProvider), isA<DisabledEntitlementApi>());
      expect(c.read(playChannelProvider), isA<DisabledPlayChannel>());
      expect(c.read(playChannelProvider).available, isFalse);
      expect(await c.read(privacyOptionsRequiredProvider.future), isFalse);
      final disabled = c.read(entitlementApiProvider);
      final rejects = throwsA(
        isA<EntitlementApiException>().having(
          (e) => e.code,
          'code',
          'local_edition',
        ),
      );
      await expectLater(disabled.refresh('old-token', 'device'), rejects);
      await expectLater(disabled.status('old-token'), rejects);
      await expectLater(
        disabled.redeemBeta(
          code: 'code',
          deviceId: 'device',
          deviceClass: 'windows',
        ),
        rejects,
      );
      await expectLater(
        disabled.redeemAfdian(
          orderNo: 'order',
          deviceId: 'device',
          deviceClass: 'windows',
        ),
        rejects,
      );
      await expectLater(
        disabled.claimVip(deviceId: 'device', deviceClass: 'windows'),
        rejects,
      );
      await expectLater(
        disabled.verifyPlay(
          idToken: 'id',
          purchaseToken: 'purchase',
          deviceId: 'device',
          deviceClass: 'windows',
        ),
        rejects,
      );
    },
  );

  test(
    'old token is neither loaded, adopted, refreshed, cleared nor put on a timer',
    () {
      fakeAsync((async) {
        final c = container();
        expect(c.read(entitlementTokenProvider), isNull);
        expect(c.read(proStatusProvider), ProStatus.pro);
        expect(c.read(skinPaywallNoticeProvider), isFalse);
        var adopted = true;
        c
            .read(entitlementTokenProvider.notifier)
            .adopt('even-a-valid-token-is-unused')
            .then((value) => adopted = value);
        c.read(entitlementTokenProvider.notifier).refreshNow();
        async.flushMicrotasks();
        async.elapse(const Duration(days: 30));
        expect(adopted, isFalse);
        expect(c.read(entitlementTokenProvider), isNull);
        expect(settings.tokenReads, 0);
        expect(settings.tokenWrites, 0);
        expect(settings.tokenClears, 0);
        expect(api.calls, 0);
        expect(async.periodicTimerCount, 0);
        c.dispose();
      });
    },
  );

  test(
    'all purchase and reward actions stop before native, device, or API calls',
    () async {
      var nativeCalls = 0;
      const channel = MethodChannel('ava/play');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final c = container();
      final actions = c.read(proActionsProvider);
      for (final result in [
        await actions.subscribeViaPlay(),
        await actions.restoreViaPlay(),
        await actions.redeemAfdian('old-order'),
        await actions.redeemBeta('old-code'),
        await actions.watchRewarded(),
      ]) {
        expect(result.ok, isFalse);
        expect(result.code, 'local_edition');
      }
      expect(nativeCalls, 0);
      expect(api.calls, 0);
      expect(settings.tokenReads, 0);
    },
  );

  test(
    'all local skins persist and sync keeps the existing device identity',
    () async {
      final c = container();
      for (final skin in AvaSkin.values) {
        await c.read(skinProvider.notifier).setSkin(skin);
        expect(c.read(effectiveSkinProvider), skin);
        expect(settings.skin, skin.name);
      }
      expect(await c.read(deviceIdProvider.future), 'existing-sync-device');
      final reopened = container();
      reopened.read(skinProvider);
      await Future<void>.delayed(Duration.zero);
      expect(reopened.read(effectiveSkinProvider), AvaSkin.pixel);
      expect(
        await reopened.read(deviceIdProvider.future),
        'existing-sync-device',
      );
      expect(settings.tokenReads, 0);
      expect(api.calls, 0);
    },
  );

  testWidgets(
    'legacy paywall has only a local-edition explanation and no paid inputs',
    (tester) async {
      final c = container();
      await tester.pumpWidget(app(c, const PaywallScreen()));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(PaywallScreen)));
      expect(find.text(l.forkLocalFeaturesTitle), findsOneWidget);
      expect(find.text(l.forkLocalFeaturesBody), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l.paywallSubscribe), findsNothing);
      expect(find.text(l.paywallRedeem), findsNothing);
      expect(find.text(l.paywallWatchAd), findsNothing);
      expect(settings.tokenReads, 0);
      expect(api.calls, 0);
    },
  );

  testWidgets(
    'banner remains empty even with an explicitly free status',
    (tester) async {
      final c = ProviderContainer(
        overrides: [proStatusProvider.overrideWithValue(ProStatus.free)],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, const Scaffold(body: AvaBannerSlot())));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidView), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'settings directly selects both skins and hides Pro and official update entries',
    (tester) async {
      final c = container();
      await tester.pumpWidget(app(c, const SettingsScreen()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(find.text(l.settingsPro), findsNothing);
      expect(find.text(l.proOpen), findsNothing);
      expect(find.text(l.settingsUpdateCheck), findsNothing);
      await tester.scrollUntilVisible(find.text(l.themeNeon), 300);
      await Scrollable.ensureVisible(
        tester.element(find.text(l.themeNeon)),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.text(l.themeNeon));
      // Styled skins deliberately animate; they never settle.
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.read(effectiveSkinProvider), AvaSkin.neon);
      await tester.scrollUntilVisible(find.text(l.themePixel), 300);
      await Scrollable.ensureVisible(
        tester.element(find.text(l.themePixel)),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.text(l.themePixel));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.read(effectiveSkinProvider), AvaSkin.pixel);
      expect(find.byType(PaywallScreen), findsNothing);
      await tester.scrollUntilVisible(
        find.text('github.com/gooesman/AnotherVaporAuth/issues'),
        300,
      );
      expect(
        find.text('github.com/gooesman/AnotherVaporAuth/issues'),
        findsOneWidget,
      );
      expect(settings.tokenReads, 0);
      expect(api.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
