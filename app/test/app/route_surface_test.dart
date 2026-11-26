import 'dart:ui' as ui;

import 'package:ava/src/app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> backMessage(String method, [Map<String, dynamic>? args]) =>
      binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  Future<List<int>> pixels(
    WidgetTester tester,
    GlobalKey capture,
  ) async => (await tester.runAsync(() async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = bytes.buffer.asUint8List().toList();
    image.dispose();
    return result;
  }))!;

  Future<void> dragBack(WidgetTester tester, {int edge = 0}) async {
    await backMessage('startBackGesture', {
      'touchOffset': <double>[edge == 0 ? 5 : 795, 300],
      'progress': 0.0,
      'swipeEdge': edge,
    });
    await tester.pump();
    await backMessage('updateBackGestureProgress', {
      'touchOffset': <double>[edge == 0 ? 150 : 650, 300],
      'progress': 0.65,
      'swipeEdge': edge,
    });
    await tester.pumpAndSettle();
  }

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      'Android ${variant.name} page stays still until back commits and cancellation preserves it',
      (tester) async {
        final capture = GlobalKey();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: buildAvaTheme(variant),
              home: const Scaffold(
                backgroundColor: Colors.red,
                body: Center(child: Text('underlying account')),
              ),
            ),
          ),
        );

        void push() => navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              key: const ValueKey('foreground-page'),
              appBar: AppBar(title: const Text('redeem')),
              body: const SizedBox.expand(),
            ),
          ),
        );
        push();
        await tester.pumpAndSettle();
        final baseline = await pixels(tester, capture);
        final bounds = tester.getRect(
          find.byKey(const ValueKey('foreground-page')),
        );

        await dragBack(tester);
        // Check the entire rendered page: no scaling, translation, rounding,
        // dimming, or old-page contents appear before the gesture commits.
        expect(listEquals(await pixels(tester, capture), baseline), isTrue);
        expect(
          tester.getRect(find.byKey(const ValueKey('foreground-page'))),
          bounds,
        );
        expect(find.text('underlying account'), findsNothing);

        await backMessage('cancelBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('redeem'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isTrue);

        await dragBack(tester, edge: 1);
        expect(listEquals(await pixels(tester, capture), baseline), isTrue);
        await backMessage('commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('redeem'), findsNothing);
        expect(navigator.currentState!.canPop(), isFalse);

        push();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(navigator.currentState!.canPop(), isFalse);

        // With the manifest opt-out AndroidX dispatches ordinary back after
        // completion instead of progress events; that path still pops once.
        push();
        await tester.pumpAndSettle();
        await binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(navigator.currentState!.canPop(), isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'ordinary and committed Android back respect a busy PopScope',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final canPop = ValueNotifier(false);
      addTearDown(canPop.dispose);
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: buildAvaTheme(AvaThemeVariant.light),
          home: const Scaffold(body: Text('home')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: canPop,
            builder: (_, enabled, _) => PopScope(
              canPop: enabled,
              onPopInvokedWithResult: (popped, _) => results.add(popped),
              child: const Scaffold(body: Text('busy transaction')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await dragBack(tester);
      await backMessage('commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('busy transaction'), findsOneWidget);
      expect(results, [false]);
      await binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(results, [false, false]);
      canPop.value = true;
      await tester.pump();
      await binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(results, [false, false, true]);
      expect(navigator.currentState!.canPop(), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'root back cancellation stays in AVA; committed back requests one system exit',
    (tester) async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAvaTheme(AvaThemeVariant.light),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.pumpAndSettle();
      await dragBack(tester);
      await backMessage('cancelBackGesture');
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
      );
      await dragBack(tester);
      await backMessage('commitBackGesture');
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android back dismisses a modal without also popping its page',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: buildAvaTheme(AvaThemeVariant.light),
          home: const Scaffold(body: Text('home')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('details'));
          },
        ),
      );
      await tester.pumpAndSettle();
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
      await tester.pumpAndSettle();
      await dragBack(tester);
      await backMessage('commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(find.text('details'), findsOneWidget);
      showModalBottomSheet<void>(
        context: pageContext,
        builder: (_) => const SizedBox(height: 100, child: Text('sheet')),
      );
      await tester.pumpAndSettle();
      await binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('details'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
