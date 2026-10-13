import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/steam_connectivity.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:ava/src/ui/steam_acceleration_screen.dart';
import 'package:ava/src/ui/home_screen.dart';
import 'package:ava/src/ui/widgets/steam_acceleration_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _nodes = [
  SteamAccelerationNode(id: 'node-a', name: '演示节点 A', type: 'ss'),
  SteamAccelerationNode(id: 'node-b', name: '演示节点 B', type: 'trojan'),
];
const _clearEnvironment = SteamAccelerationEnvironment(
  detectionAvailable: true,
);
const _ready = SteamAccelerationState(
  configured: true,
  nodes: _nodes,
  selectedNodeId: 'node-a',
  environment: _clearEnvironment,
);

class _Runtime implements SteamAccelerationRuntime {
  @override
  bool get supported => true;
  @override
  Future<SteamAccelerationEnvironment> detectEnvironment() async =>
      _clearEnvironment;
  @override
  Future<void> start(
    String configuration,
    SteamProxyEndpoint endpoint, {
    void Function(SteamAccelerationPhase)? onPhaseChanged,
  }) async {}
  @override
  Future<bool> isRunning() async => false;
  @override
  Future<void> stop() async {}
}

class _Service extends SteamAccelerationService {
  _Service([
    this.value = const SteamAccelerationState(environment: _clearEnvironment),
  ]) : super(runtime: _Runtime());
  SteamAccelerationState value;
  bool supportedValue = true;
  int loads = 0, refreshes = 0, starts = 0, stops = 0, checks = 0, clears = 0;
  int autoChanges = 0;
  final urls = <String>[];
  final selected = <String>[];
  Completer<void>? pendingRefresh;
  Object? refreshError;

  @override
  SteamAccelerationState get state => value;
  @override
  bool get supported => supportedValue;
  @override
  SteamProxyEndpoint? get proxyEndpoint =>
      value.phase == SteamAccelerationPhase.running
      ? const SteamProxyEndpoint(
          host: '127.0.0.1',
          port: 7890,
          username: 'synthetic',
          password: 'synthetic',
        )
      : null;

  void emit({
    SteamAccelerationPhase? phase,
    bool? configured,
    bool? autoStart,
    List<SteamAccelerationNode>? nodes,
    String? selectedNodeId,
    SteamAccelerationEnvironment? environment,
    SteamAccelerationError? error,
  }) {
    value = SteamAccelerationState(
      phase: phase ?? value.phase,
      configured: configured ?? value.configured,
      autoStart: autoStart ?? value.autoStart,
      nodes: nodes ?? value.nodes,
      selectedNodeId: selectedNodeId ?? value.selectedNodeId,
      environment: environment ?? value.environment,
      skippedNodes: value.skippedNodes,
      error: error,
    );
    notifyListeners();
  }

  @override
  Future<void> load() async {
    loads++;
  }

  @override
  Future<void> configure({
    required String subscriptionUrl,
    bool autoStart = false,
  }) async {
    urls.add(subscriptionUrl);
    emit(configured: true, autoStart: autoStart);
  }

  @override
  Future<void> refreshSubscription() async {
    refreshes++;
    emit(phase: SteamAccelerationPhase.loadingSubscription);
    if (refreshError != null) throw refreshError!;
    await pendingRefresh?.future;
    emit(
      phase: SteamAccelerationPhase.off,
      nodes: _nodes,
      selectedNodeId: 'node-a',
    );
  }

  @override
  Future<void> setAutoStart(bool value) async {
    autoChanges++;
    emit(autoStart: value);
  }

  @override
  Future<void> selectNode(String id) async {
    selected.add(id);
    emit(selectedNodeId: id);
  }

  @override
  Future<void> start({bool automatic = false}) async {
    expect(automatic, isFalse, reason: 'The page must only start explicitly');
    starts++;
    emit(phase: SteamAccelerationPhase.running);
  }

  @override
  Future<void> stop() async {
    stops++;
    emit(phase: SteamAccelerationPhase.off);
  }

  @override
  Future<void> checkEnvironment({bool allowAutomaticStart = true}) async {
    checks++;
  }

  @override
  Future<void> clearConfiguration() async {
    clears++;
    value = const SteamAccelerationState(environment: _clearEnvironment);
    notifyListeners();
  }
}

class _Probe extends SteamConnectivityProbe {
  int calls = 0;
  Completer<SteamConnectionResult>? pending;
  SteamConnectionResult result = const SteamConnectionResult(
    api: false,
    community: false,
  );
  @override
  Future<SteamConnectionResult> check(CancelToken cancel) async {
    calls++;
    return pending == null ? result : pending!.future;
  }
}

class _Unlocked extends AppController {
  @override
  Future<AppData> build() async => AppData(
    store: AccountStore(
      ref.read(storageProvider),
      Manifest(encrypted: true, vault: true),
    ),
    accounts: const [],
    locked: false,
    passKey: '123456',
    privacyVersion: 0,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Service service, {
  AvaThemeVariant variant = AvaThemeVariant.light,
  Locale locale = const Locale('en'),
  Widget home = const SteamAccelerationScreen(),
  Size size = const Size(393, 852),
  SteamConnectivityProbe? probe,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(MemoryStorageProvider()),
        appControllerProvider.overrideWith(_Unlocked.new),
        steamAccelerationServiceProvider.overrideWithValue(service),
        steamConnectivityProbeProvider.overrideWithValue(probe ?? _Probe()),
        tickProvider.overrideWith((ref) => Stream.value(1900000010)),
        timeAlignerProvider.overrideWithValue(() async {}),
      ],
      child: MaterialApp(
        theme: buildAvaTheme(
          variant,
        ).copyWith(platform: TargetPlatform.android),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _key(String suffix) =>
    find.byKey(ValueKey('steam-acceleration-$suffix'));

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: scrollable,
      maxScrolls: 30,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _reveal(tester, _key(key));
  await tester.tap(_key(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'connection card explains no VPN icon and only reports real probe results',
    (tester) async {
      final service = _Service(_ready)
        ..emit(phase: SteamAccelerationPhase.running);
      final pending = Completer<SteamConnectionResult>();
      final probe = _Probe()..pending = pending;
      await _pump(tester, service, probe: probe, locale: const Locale('zh'));
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(find.text(l.steamConnectionNoVpnIcon), findsOneWidget);
      expect(probe.calls, 1);
      final status = find.byKey(const ValueKey('steam-connection-status'));
      await _reveal(tester, status);
      expect(tester.widget<Text>(status).data, l.steamConnectionChecking);
      expect(find.text(l.steamConnectionAvailable), findsNothing);
      pending.complete(
        const SteamConnectionResult(api: true, community: false),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, l.steamConnectionPartial);
      expect(find.textContaining(l.steamConnectionApi), findsOneWidget);
      expect(find.textContaining(l.steamConnectionCommunity), findsOneWidget);
      probe.pending = null;
      probe.result = const SteamConnectionResult(api: true, community: true);
      final check = find.byKey(const ValueKey('steam-connection-check'));
      await _reveal(tester, check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(probe.calls, 2);
      expect(tester.widget<Text>(status).data, l.steamConnectionAvailable);
      expect(service.starts, 0);
    },
  );

  testWidgets(
    'home status stays compact with large labels and opens acceleration settings',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = _Service(_ready)
        ..emit(phase: SteamAccelerationPhase.running);
      final probe = _Probe()
        ..result = const SteamConnectionResult(api: true, community: true);
      await _pump(
        tester,
        service,
        probe: probe,
        home: const HomeScreen(),
        size: const Size(360, 740),
        locale: const Locale('zh'),
      );
      final chip = _key('home-status');
      expect(chip, findsOneWidget);
      expect(tester.getSize(chip).width, lessThanOrEqualTo(200));
      expect(tester.takeException(), isNull);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(SteamAccelerationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unconfigured or unsupported status entry stays hidden without checks',
    (tester) async {
      final service = _Service();
      final probe = _Probe();
      await _pump(
        tester,
        service,
        probe: probe,
        home: const Scaffold(body: SteamAccelerationStatusChip()),
      );
      expect(_key('home-status'), findsNothing);
      expect(probe.calls, 0);
      service.supportedValue = false;
      service.emit(configured: true);
      await tester.pump();
      expect(_key('home-status'), findsNothing);
      expect(probe.calls, 0);
    },
  );

  testWidgets(
    'opening the page keeps manual mode and never fetches a subscription',
    (tester) async {
      final service = _Service();
      await _pump(tester, service);
      expect(service.loads, 1);
      expect(service.checks, 1);
      expect(service.starts, 0);
      expect(service.refreshes, 0);
      await _reveal(tester, _key('auto'));
      expect(tester.widget<Switch>(_key('auto')).value, isFalse);
      await _reveal(tester, _key('toggle'));
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'subscription input stays masked, validates its scheme and saves without starting',
    (tester) async {
      final service = _Service();
      await _pump(tester, service);
      await _tap(tester, 'configure');
      final input = _key('subscription-input');
      expect(tester.widget<TextField>(input).obscureText, isTrue);
      expect(tester.widget<TextField>(input).enableSuggestions, isFalse);
      expect(
        tester.widget<TextField>(input).enableIMEPersonalizedLearning,
        isFalse,
      );
      await tester.enterText(input, 'ftp://invalid.example/subscription');
      await _tap(tester, 'save-subscription');
      expect(service.urls, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      const secretUrl =
          'https://example.invalid/subscribe?token=synthetic-private';
      await tester.enterText(input, secretUrl);
      await _tap(tester, 'save-subscription');
      expect(service.urls, [secretUrl]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('synthetic-private'), findsNothing);
      expect(service.starts, 0);
      expect(service.refreshes, 0);
      await _tap(tester, 'sync');
      expect(service.refreshes, 1);
      expect(service.starts, 0);
      expect(find.text('演示节点 A'), findsOneWidget);
    },
  );

  for (final url in [
    'http://fixture:password%40encoded@subscription.example.invalid/list.yml',
    'https://192.0.2.1:55356/api/subscribe?token=synthetic-private',
  ]) {
    testWidgets(
      'subscription dialog accepts compatible URL ${url.startsWith('http:') ? 'with basic authentication' : 'with a custom port'}',
      (tester) async {
        final service = _Service();
        await _pump(tester, service);
        await _tap(tester, 'configure');
        await tester.enterText(_key('subscription-input'), url);
        await _tap(tester, 'save-subscription');
        expect(service.urls, [url]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.textContaining('synthetic-private'), findsNothing);
        expect(find.textContaining('password%40encoded'), findsNothing);
        expect(service.starts, 0);
        expect(service.refreshes, 0);
      },
    );
  }

  testWidgets(
    'replacing a saved subscription opens a blank field and cancel preserves it',
    (tester) async {
      final service = _Service(_ready);
      await _pump(tester, service);
      await _tap(tester, 'configure');
      expect(
        tester.widget<TextField>(_key('subscription-input')).controller!.text,
        isEmpty,
      );
      await tester.enterText(
        _key('subscription-input'),
        'https://example.invalid/private',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.urls, isEmpty);
      await _tap(tester, 'configure');
      expect(
        tester.widget<TextField>(_key('subscription-input')).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'manual start and stop are explicit and do not change automatic mode',
    (tester) async {
      final service = _Service(_ready);
      await _pump(tester, service);
      await _tap(tester, 'toggle');
      expect(service.starts, 1);
      expect(service.state.phase, SteamAccelerationPhase.running);
      await _reveal(tester, find.byType(DropdownButtonFormField<String>));
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .onChanged,
        isNull,
      );
      expect(service.state.autoStart, isFalse);
      await _tap(tester, 'toggle');
      expect(service.stops, 1);
      expect(service.state.phase, SteamAccelerationPhase.off);
      expect(service.autoChanges, 0);
    },
  );

  testWidgets(
    'node choice and automatic preference save without starting a core',
    (tester) async {
      final service = _Service(_ready);
      await _pump(tester, service);
      await _reveal(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('演示节点 B').last);
      await tester.pumpAndSettle();
      expect(service.selected, ['node-b']);
      await _tap(tester, 'auto');
      expect(service.state.autoStart, isTrue);
      expect(service.autoChanges, 1);
      expect(service.starts, 0);
    },
  );

  for (final entry in {
    'system proxy': const SteamAccelerationEnvironment(
      detectionAvailable: true,
      systemProxyDetected: true,
    ),
    'PAC': const SteamAccelerationEnvironment(
      detectionAvailable: true,
      pacDetected: true,
    ),
    'VPN': const SteamAccelerationEnvironment(
      detectionAvailable: true,
      vpnOrTunnelDetected: true,
    ),
    'system proxy with incomplete detection':
        const SteamAccelerationEnvironment(systemProxyDetected: true),
    'PAC with incomplete detection': const SteamAccelerationEnvironment(
      pacDetected: true,
    ),
    'VPN with incomplete detection': const SteamAccelerationEnvironment(
      vpnOrTunnelDetected: true,
    ),
  }.entries) {
    testWidgets('${entry.key} environment prevents accidental internal start', (
      tester,
    ) async {
      final service = _Service(_ready)
        ..emit(
          phase: entry.value.hasExternal
              ? SteamAccelerationPhase.pausedExternal
              : SteamAccelerationPhase.off,
          environment: entry.value,
          error: entry.value.detectionAvailable
              ? null
              : SteamAccelerationError.environmentUnknown,
        );
      await _pump(tester, service, locale: const Locale('zh'));
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(tester.widget<Text>(_key('status')).data, '内置加速已暂停');
      expect(find.text(l.steamAccelerationDetectionUnavailable), findsNothing);
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      expect(find.text(l.steamAccelerationExternalActiveHelp), findsOneWidget);
      await _tap(tester, 'recheck-external');
      expect(service.checks, 2);
      await _tap(tester, 'check-environment');
      expect(find.text(l.steamAccelerationDetectionUnavailable), findsNothing);
      expect(
        find.text(
          entry.value.vpnOrTunnelDetected
              ? l.steamAccelerationExternalVpn
              : l.steamAccelerationExternalProxy,
        ),
        findsOneWidget,
      );
      expect(service.checks, 3);
      expect(service.starts, 0);
      service.emit(
        environment: _clearEnvironment,
        phase: SteamAccelerationPhase.off,
      );
      await tester.pump();
      expect(_key('external-help'), findsNothing);
      await _reveal(tester, _key('toggle'));
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNotNull);
    });
  }

  testWidgets(
    'component download has its own status and prevents duplicate starts',
    (tester) async {
      final service = _Service(_ready)
        ..emit(phase: SteamAccelerationPhase.downloadingCore);
      await _pump(tester, service);
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(
        tester.widget<Text>(_key('status')).data,
        l.steamAccelerationDownloadingCore,
      );
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      expect(service.starts, 0);
    },
  );

  testWidgets(
    'component download failure is distinct from subscription failure',
    (tester) async {
      final service = _Service(_ready)
        ..emit(
          phase: SteamAccelerationPhase.error,
          error: SteamAccelerationError.coreDownload,
        );
      await _pump(tester, service);
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(find.text(l.steamAccelerationCoreDownload), findsOneWidget);
      expect(find.text(l.steamAccelerationNetworkError), findsNothing);
    },
  );

  testWidgets(
    'unknown detection explains paused auto mode and allows only an explicit start',
    (tester) async {
      final service = _Service(_ready)
        ..emit(
          phase: SteamAccelerationPhase.pausedExternal,
          environment: const SteamAccelerationEnvironment(),
          error: SteamAccelerationError.environmentUnknown,
        );
      await _pump(tester, service, locale: const Locale('zh'));
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(find.text(l.steamAccelerationDetectionUnavailable), findsWidgets);
      expect(tester.widget<Text>(_key('status')).data, '内置加速已暂停');
      expect(find.text(l.steamAccelerationNoExternal), findsNothing);
      expect(service.starts, 0);
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNotNull);
      await _tap(tester, 'toggle');
      expect(service.starts, 1);
      expect(service.autoChanges, 0);
      expect(service.state.autoStart, isFalse);
    },
  );

  testWidgets('clearing configuration requires confirmation', (tester) async {
    final service = _Service(_ready);
    await _pump(tester, service);
    await _tap(tester, 'clear');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.clears, 0);
    await _tap(tester, 'clear');
    await _tap(tester, 'confirm-clear');
    expect(service.clears, 1);
    await _reveal(tester, _key('toggle'));
    expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
  });

  testWidgets(
    'busy sync blocks duplicate actions and completion after leaving is harmless',
    (tester) async {
      final pending = Completer<void>();
      final service = _Service(_ready)..pendingRefresh = pending;
      await _pump(tester, service);
      await _tap(tester, 'sync');
      expect(tester.widget<OutlinedButton>(_key('sync')).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(_key('configure')).onPressed,
        isNull,
      );
      await _reveal(tester, _key('toggle'));
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      expect(service.refreshes, 1);
      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unexpected errors never render a private subscription URL', (
    tester,
  ) async {
    final service = _Service(_ready)
      ..refreshError = StateError(
        'https://example.invalid/?token=private-token',
      );
    await _pump(tester, service);
    await _tap(tester, 'sync');
    await _reveal(tester, _key('status'));
    final l = AppLocalizations.of(
      tester.element(find.byType(SteamAccelerationScreen)),
    );
    expect(find.text(l.steamAccelerationFailed), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await _reveal(tester, _key('sync'));
    expect(tester.widget<OutlinedButton>(_key('sync')).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'integrity and network failures provide different safe recovery messages',
    (tester) async {
      final service = _Service(_ready)
        ..emit(
          phase: SteamAccelerationPhase.error,
          error: SteamAccelerationError.coreIntegrity,
        );
      await _pump(tester, service);
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(find.text(l.steamAccelerationCoreIntegrity), findsOneWidget);
      service.emit(
        phase: SteamAccelerationPhase.error,
        error: SteamAccelerationError.network,
      );
      await tester.pump();
      expect(find.text(l.steamAccelerationNetworkError), findsOneWidget);
      expect(find.text(l.steamAccelerationCoreIntegrity), findsNothing);
    },
  );

  testWidgets(
    'unsupported devices do not load configuration or offer actions',
    (tester) async {
      final service = _Service()..supportedValue = false;
      await _pump(tester, service);
      expect(service.loads, 0);
      expect(_key('toggle'), findsNothing);
      expect(_key('configure'), findsNothing);
    },
  );

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '${variant.name} page handles long labels and large text on a small phone',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final service = _Service(_ready);
        await _pump(
          tester,
          service,
          variant: variant,
          locale: const Locale('de'),
          size: const Size(320, 640),
        );
        await _reveal(tester, _key('check-environment'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _tap(tester, 'configure');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('settings opens the app-local acceleration page', (tester) async {
    final service = _Service();
    await _pump(tester, service, home: const SettingsScreen());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'settings-open');
    expect(find.byType(SteamAccelerationScreen), findsOneWidget);
    expect(service.starts, 0);
    expect(service.refreshes, 0);
    expect(tester.takeException(), isNull);
  });
}
