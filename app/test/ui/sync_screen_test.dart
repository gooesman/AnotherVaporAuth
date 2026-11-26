import 'dart:async';

import 'package:ava/l10n/app_localizations.dart';
import 'package:ava/src/app/sync_providers.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/services/sync/sync_config_store.dart';
import 'package:ava/src/services/sync/sync_engine.dart';
import 'package:ava/src/ui/sync/sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/sync_engine_test.dart'
    show MemoryConfigStore, MemoryTrash, FakePort;

class _NetworkProbe {
  int calls = 0;
}

class _ScreenEngine extends SyncEngine {
  _ScreenEngine(MemoryConfigStore store, _NetworkProbe probe)
    : super(
        configStore: store,
        accounts: FakePort(),
        trash: MemoryTrash(),
        deviceId: () async => 'sync-ui-test',
        transportFactory: (_, _) {
          probe.calls++;
          throw StateError('Unexpected network request');
        },
      );

  int uploads = 0;
  int pulls = 0;
  Completer<void>? pending;
  SyncEngineStatus current = const SyncEngineStatus(configured: true);
  final updates = StreamController<SyncEngineStatus>.broadcast();

  @override
  SyncEngineStatus get status => current;
  @override
  Stream<SyncEngineStatus> get statusStream => updates.stream;

  void publish(SyncEngineStatus value) {
    current = value;
    updates.add(value);
  }

  @override
  Future<void> uploadNow() async {
    uploads++;
    await pending?.future;
  }

  @override
  Future<void> pullNow() async {
    pulls++;
    await pending?.future;
  }

  @override
  void dispose() {
    updates.close();
    super.dispose();
  }
}

const _none = SyncSelection(
  accounts: false,
  settings: false,
  favorites: false,
  acceleration: false,
);

MemoryConfigStore _store({
  SyncSelection upload = const SyncSelection(),
  SyncSelection pull = const SyncSelection(),
}) => MemoryConfigStore()
  ..config = SyncConfig(
    url: 'https://sync.example.invalid/library/',
    username: 'fixture',
    deviceName: 'fixture',
    autoSync: false,
    uploadSelection: upload,
    pullSelection: pull,
  );

Future<void> _pump(
  WidgetTester tester,
  _ScreenEngine engine, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncEngineProvider.overrideWithValue(engine)],
      child: MaterialApp(
        theme: buildAvaTheme(AvaThemeVariant.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const SyncScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('partial results stay visible alongside a retryable failure', (
    tester,
  ) async {
    final engine = _ScreenEngine(_store(), _NetworkProbe())
      ..current = const SyncEngineStatus(
        configured: true,
        errorKind: SyncErrorKind.network,
        errorDetail: 'fixture unavailable',
        lastPulled: 2,
      );
    addTearDown(engine.dispose);
    await _pump(tester, engine);
    expect(
      find.text('Items uploaded: 0 · Items downloaded: 2'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Completed items are kept. You can retry the unfinished items.',
      ),
      findsOneWidget,
    );
    expect(find.text('Connected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone actions choose one direction and do not expose advanced options',
    (tester) async {
      final probe = _NetworkProbe();
      final engine = _ScreenEngine(_store(), probe);
      addTearDown(engine.dispose);
      await _pump(tester, engine);

      expect(find.byKey(const ValueKey('sync-upload-accounts')), findsNothing);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Up to date'), findsNothing);
      expect(engine.uploads, 0);
      expect(engine.pulls, 0);
      await _tapKey(tester, 'sync-upload-now');
      expect(engine.uploads, 1);
      expect(engine.pulls, 0);
      await _tapKey(tester, 'sync-pull-now');
      expect(engine.uploads, 1);
      expect(engine.pulls, 1);
      expect(probe.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('independent selections persist without starting a transfer', (
    tester,
  ) async {
    final store = _store();
    final probe = _NetworkProbe();
    final engine = _ScreenEngine(store, probe);
    addTearDown(engine.dispose);
    await _pump(tester, engine);
    await _tapKey(tester, 'sync-advanced-options');
    await _tapKey(tester, 'sync-upload-favorites');
    expect(store.config!.uploadSelection.favorites, isFalse);
    expect(store.config!.pullSelection.favorites, isTrue);
    await _tapKey(tester, 'sync-pull-acceleration');
    expect(store.config!.pullSelection.acceleration, isFalse);
    expect(store.config!.uploadSelection.acceleration, isTrue);
    await _tapKey(tester, 'sync-upload-passwords');
    expect(store.config!.syncPasswords, isFalse);
    await _tapKey(tester, 'sync-auto-upload');
    expect(store.config!.autoSync, isTrue);
    expect(engine.uploads, 0);
    expect(engine.pulls, 0);
    expect(probe.calls, 0);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, engine);
    await _tapKey(tester, 'sync-advanced-options');
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('sync-upload-favorites')),
          )
          .value,
      isFalse,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('sync-pull-acceleration')),
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('sync-pull-acceleration')),
          )
          .value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password child is unavailable when account upload is unchecked',
    (tester) async {
      final store = _store();
      final engine = _ScreenEngine(store, _NetworkProbe());
      addTearDown(engine.dispose);
      await _pump(tester, engine);
      await _tapKey(tester, 'sync-advanced-options');
      await _tapKey(tester, 'sync-upload-accounts');
      final child = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('sync-upload-passwords')),
      );
      expect(child.value, isFalse);
      expect(child.onChanged, isNull);
      expect(store.config!.pullSelection.accounts, isTrue);
      expect(store.config!.syncPasswords, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy transfers and empty selections disable both actions', (
    tester,
  ) async {
    final store = _store(upload: _none);
    final engine = _ScreenEngine(store, _NetworkProbe());
    addTearDown(engine.dispose);
    await _pump(tester, engine);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sync-upload-now')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sync-pull-now')))
          .onPressed,
      isNotNull,
    );

    engine.pending = Completer<void>();
    await _tapKey(tester, 'sync-pull-now');
    expect(engine.pulls, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sync-pull-now')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sync-upload-now')))
          .onPressed,
      isNull,
    );
    engine.pending!.complete();
    await tester.pumpAndSettle();
    engine.publish(const SyncEngineStatus(configured: true, syncing: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sync-pull-now')))
          .onPressed,
      isNull,
    );

    engine.publish(const SyncEngineStatus(configured: true));
    store.config = store.config!.copyWith(pullSelection: _none);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, engine);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sync-pull-now')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed option save keeps prior choices and reports failure', (
    tester,
  ) async {
    final store = _store()..failNextConfigSave = true;
    final probe = _NetworkProbe();
    final engine = _ScreenEngine(store, probe);
    addTearDown(engine.dispose);
    await _pump(tester, engine);
    await _tapKey(tester, 'sync-advanced-options');
    await _tapKey(tester, 'sync-upload-favorites');
    expect(store.config!.uploadSelection.favorites, isTrue);
    expect(
      find.text('Could not save sync options. Please try again.'),
      findsOneWidget,
    );
    expect(probe.calls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('phone layout with large text fits $locale', (tester) async {
      final engine = _ScreenEngine(_store(), _NetworkProbe());
      addTearDown(engine.dispose);
      await _pump(tester, engine, locale: locale);
      await _tapKey(tester, 'sync-advanced-options');
      for (final key in [
        'sync-upload-passwords',
        'sync-pull-acceleration',
        'sync-auto-upload',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
