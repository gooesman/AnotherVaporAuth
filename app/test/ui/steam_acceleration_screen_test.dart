import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/steam_acceleration_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/core/models/manifest.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/steam_acceleration.dart';
import 'package:ava/src/services/steam_acceleration_runtime.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:ava/src/ui/settings_screen.dart';
import 'package:ava/src/ui/steam_acceleration_screen.dart';
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
  Future<void> start(String configuration, SteamProxyEndpoint endpoint) async {}
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
  Future<void> checkEnvironment() async {
    checks++;
  }

  @override
  Future<void> clearConfiguration() async {
    clears++;
    value = const SteamAccelerationState(environment: _clearEnvironment);
    notifyListeners();
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
    'opening the page keeps manual mode and never fetches a subscription',
    (tester) async {
      final service = _Service();
      await _pump(tester, service);
      expect(service.loads, 1);
      expect(service.checks, 1);
      expect(service.starts, 0);
      expect(service.refreshes, 0);
      expect(tester.widget<Switch>(_key('auto')).value, isFalse);
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'subscription input stays masked, validates HTTPS and saves without starting',
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
      await tester.enterText(input, 'http://invalid.example/subscription');
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
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
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
        );
      await _pump(tester, service);
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNull);
      await _tap(tester, 'check-environment');
      expect(service.checks, 2);
      expect(service.starts, 0);
      service.emit(
        environment: _clearEnvironment,
        phase: SteamAccelerationPhase.off,
      );
      await tester.pump();
      await _reveal(tester, _key('toggle'));
      expect(tester.widget<FilledButton>(_key('toggle')).onPressed, isNotNull);
    });
  }

  testWidgets(
    'unknown detection explains paused auto mode and allows only an explicit start',
    (tester) async {
      final service = _Service(_ready)
        ..emit(environment: const SteamAccelerationEnvironment());
      await _pump(tester, service);
      final l = AppLocalizations.of(
        tester.element(find.byType(SteamAccelerationScreen)),
      );
      expect(find.text(l.steamAccelerationDetectionUnavailable), findsWidgets);
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
