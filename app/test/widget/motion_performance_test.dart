import 'package:ava/src/app/theme.dart';
import 'package:ava/src/ui/widgets/flip_code.dart';
import 'package:ava/src/ui/widgets/motion.dart';
import 'package:ava/src/ui/widgets/stepper3.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  AvaThemeVariant variant = AvaThemeVariant.light,
  bool reduce = false,
  bool visible = true,
}) => MaterialApp(
  theme: buildAvaTheme(variant),
  themeAnimationDuration: Duration.zero,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: TickerMode(enabled: visible, child: child!),
  ),
  home: Scaffold(body: Center(child: child)),
);

const _ambient = Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    PulsingDot(color: Colors.green),
    FloatingLogo(child: Icon(Icons.shield)),
    Stepper3(labels: ['Account', 'Verify', 'Done'], current: 1),
  ],
);

void main() {
  for (final variant in [
    AvaThemeVariant.light,
    AvaThemeVariant.dark,
    AvaThemeVariant.pixel,
  ]) {
    testWidgets('$variant ambient widgets leave the idle screen idle', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_ambient, variant: variant));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets(
    'neon animation stops on reduced motion and resumes when allowed',
    (tester) async {
      await tester.pumpWidget(_host(_ambient, variant: AvaThemeVariant.neon));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        _host(_ambient, variant: AvaThemeVariant.neon, reduce: true),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(_host(_ambient, variant: AvaThemeVariant.neon));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    },
  );

  testWidgets('hidden ambient widgets stop requesting frames', (tester) async {
    await tester.pumpWidget(_host(_ambient, variant: AvaThemeVariant.neon));
    await tester.pump();
    await tester.pumpWidget(
      _host(_ambient, variant: AvaThemeVariant.neon, visible: false),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a completed stepper stops its pulse', (tester) async {
    Widget steps(int step) =>
        Stepper3(labels: const ['Account', 'Done'], current: step);
    await tester.pumpWidget(_host(steps(0), variant: AvaThemeVariant.neon));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(_host(steps(2), variant: AvaThemeVariant.neon));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'reduced motion presents the new code without showing both values',
    (tester) async {
      await tester.pumpWidget(
        _host(const FlipCode(code: 'ABCDE'), reduce: true),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(const FlipCode(code: 'VWXYZ'), reduce: true),
      );
      expect(find.text('ABCDE'), findsNothing);
      expect(find.text('VWXYZ'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('plain code change finishes within 160ms', (tester) async {
    await tester.pumpWidget(_host(const FlipCode(code: 'ABCDE')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const FlipCode(code: 'VWXYZ')));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump();
    expect(find.text('ABCDE'), findsNothing);
    expect(find.text('VWXYZ'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion keeps feedback and loading widgets static', (
    tester,
  ) async {
    Widget feedback(int trigger) => Column(
      children: [
        ShakeWidget(trigger: trigger, child: const Text('Check the PIN')),
        const SpinnerRing(child: Icon(Icons.shield)),
      ],
    );
    await tester.pumpWidget(_host(feedback(0), reduce: true));
    await tester.pumpAndSettle();
    final position = tester.getTopLeft(find.text('Check the PIN'));
    await tester.pumpWidget(_host(feedback(1), reduce: true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(find.text('Check the PIN')), position);
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final variant in AvaThemeVariant.values) {
    testWidgets(
      '$variant Android back gesture never moves or shrinks the route',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: buildAvaTheme(
              variant,
            ).copyWith(platform: TargetPlatform.android),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(key: ValueKey('detail'), body: Text('Detail')),
          ),
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byKey(const ValueKey('detail')));
        Future<void> gesture(String method, double progress) async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, {
                'touchOffset': <double>[600 * (1 - progress), 300],
                'progress': progress,
                'swipeEdge': 1,
              }),
            ),
            (_) {},
          );
          await tester.pump(const Duration(milliseconds: 32));
        }

        await gesture('startBackGesture', 0);
        await gesture('updateBackGestureProgress', 0.6);
        expect(tester.getRect(find.byKey(const ValueKey('detail'))), rect);
        expect(find.text('Home'), findsNothing);
        await gesture('cancelBackGesture', 0);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      },
    );
  }
}
