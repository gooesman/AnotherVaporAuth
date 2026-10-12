import 'package:ava_installer/engine.dart';
import 'package:ava_installer/fx.dart';
import 'package:ava_installer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final uninstall in [false, true]) {
    testWidgets(
      'brand fits fixed ${uninstall ? 'uninstall' : 'setup'} window',
      (tester) async {
        tester.view.physicalSize = const Size(760, 460);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          InstallerApp(uninstall: uninstall, auto: false, staged: false),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final title = find.byType(GlitchTitle);
        expect(tester.widget<GlitchTitle>(title).text, 'gooes SteamKit');
        expect(
          find.text('$appDisplayName ${uninstall ? 'UNINSTALL' : 'SETUP'}'),
          findsOneWidget,
        );
        final version = find.text(
          '${uninstall ? 'UNINSTALL' : 'SETUP'} v$appVersion',
        );
        expect(
          tester.getRect(title).right,
          lessThan(tester.getRect(version).left),
        );
        expect(tester.takeException(), isNull);

        // Dispose continuously running decorative animations without settling.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
