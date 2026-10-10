import 'dart:ui' as ui;

import 'package:ava/src/app/theme.dart';
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

  for (final variant in [AvaThemeVariant.light, AvaThemeVariant.neon]) {
    testWidgets(
      'predictive back keeps an opaque ${variant.name} page and can cancel/commit',
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
              appBar: AppBar(title: const Text('redeem')),
              body: const SizedBox.expand(),
            ),
          ),
        );
        push();
        await tester.pumpAndSettle();

        Future<void> dragBack() async {
          await backMessage('startBackGesture', {
            'touchOffset': <double>[5, 300],
            'progress': 0.0,
            'swipeEdge': 0,
          });
          await tester.pump();
          await backMessage('updateBackGestureProgress', {
            'touchOffset': <double>[150, 300],
            'progress': 0.4,
            'swipeEdge': 0,
          });
          await tester.pumpAndSettle();
        }

        await dragBack();
        // During the gesture both routes paint. The middle of the outgoing
        // transparent scaffold must paint its own surface, never the red page
        // underneath (the original floating-controls regression).
        expect(find.text('underlying account'), findsOneWidget);
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final rgba = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset =
              ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
          final rgba = pixels.buffer.asUint8List(offset, 4).toList();
          image.dispose();
          return rgba;
        }))!;
        expect(rgba[3], 255);
        expect(rgba.take(3).toList(), isNot([255, 0, 0]));
        if (variant == AvaThemeVariant.light) {
          final bg = AvaTokens.of(variant).bg;
          expect(rgba.take(3).toList(), [
            (bg.r * 255).round(),
            (bg.g * 255).round(),
            (bg.b * 255).round(),
          ]);
        }

        await backMessage('cancelBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('redeem'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isTrue);

        await dragBack();
        await backMessage('commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('redeem'), findsNothing);
        expect(navigator.currentState!.canPop(), isFalse);

        push();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(navigator.currentState!.canPop(), isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
