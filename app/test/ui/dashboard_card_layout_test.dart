import 'dart:async';

import 'package:ava/src/app/theme.dart';
import 'package:ava/src/ui/widgets/dashboard_card_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counts {
  final created = <String, int>{};
  final disposed = <String, int>{};
  final clicked = <String>[];
}

class _Card extends StatefulWidget {
  const _Card(this.id, this.counts, this.height);
  final String id;
  final _Counts counts;
  final double height;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  @override
  void initState() {
    super.initState();
    widget.counts.created.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.counts.disposed.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: Center(
      child: TextButton(
        key: ValueKey('content-${widget.id}'),
        onPressed: () => widget.counts.clicked.add(widget.id),
        child: Text('Open ${widget.id}'),
      ),
    ),
  );
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.counts, this.many = false});
  final _Counts counts;
  final bool many;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool editing = false;
  late List<String> order = widget.many
      ? ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
      : ['a', 'b', 'c', 'd'];
  final spans = <String, int>{'a': 1, 'b': 1, 'c': 1, 'd': 1};
  final moves = <(String, String)>[];
  final resizes = <(String, int)>[];
  final scroll = ScrollController();
  Completer<void>? saving;
  bool rejectSave = false;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void edit(bool value) => setState(() => editing = value);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      controller: scroll,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DashboardCardLayout(
          cards: {
            for (final id in order)
              id: _Card(id, widget.counts, widget.many ? 180 : 88),
          },
          titles: {for (final id in order) id: 'Card $id'},
          order: order,
          spans: spans,
          editing: editing,
          dragLabel: 'Reorder',
          resizeLabel: 'Resize',
          onMove: (moving, target) async {
            moves.add((moving, target));
            final at = order.indexOf(target);
            setState(() {
              order = [...order]..remove(moving);
              order.insert(at, moving);
            });
          },
          onResize: (id, span) async {
            resizes.add((id, span));
            if (saving != null) await saving!.future;
            if (!rejectSave) setState(() => spans[id] = span);
          },
        ),
      ),
    ),
  );
}

Future<(_HarnessState, _Counts)> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
  bool many = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final key = GlobalKey<_HarnessState>();
  final counts = _Counts();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAvaTheme(AvaThemeVariant.dark),
      home: _Harness(key: key, counts: counts, many: many),
    ),
  );
  await tester.pump();
  return (key.currentState!, counts);
}

Finder _card(String id) => find.byKey(ValueKey('dashboard-layout-$id'));
Finder _drag(String id) => find.byKey(ValueKey('dashboard-drag-$id'));
Finder _resize(String id) => find.byKey(ValueKey('dashboard-resize-$id'));

void _testWidgets(
  String description,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.windows,
}) => testWidgets(
  description,
  callback,
  variant: TargetPlatformVariant.only(platform),
);

void main() {
  _testWidgets('normal cards have no edit chrome and buttons remain usable', (
    tester,
  ) async {
    final (state, counts) = await _pump(tester);
    expect(find.byType(Draggable<String>), findsNothing);
    expect(_resize('a'), findsNothing);
    expect(tester.getSize(_card('a')).height, 88);
    await tester.tap(find.byKey(const ValueKey('content-a')));
    state.edit(true);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('content-b')));
    await tester.drag(
      find.byKey(const ValueKey('content-c')),
      const Offset(20, 10),
    );
    expect(counts.clicked, ['a', 'b']);
    expect(state.moves, isEmpty);
    state.edit(false);
    await tester.pump();
    expect(tester.getSize(_card('a')).height, 88);
    expect(counts.created.values, everyElement(1));
    expect(counts.disposed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _testWidgets(
    'handle drag reorders to target index without duplicating content',
    (tester) async {
      final (state, counts) = await _pump(tester);
      state.edit(true);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_drag('a')));
      await gesture.moveBy(const Offset(24, 5));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_card('c')));
      await tester.pump();
      expect(find.byKey(const ValueKey('dashboard-insert-c')), findsOneWidget);
      expect(find.byType(_Card), findsNWidgets(4));
      expect(counts.created.values, everyElement(1));
      await gesture.up();
      await tester.pump();
      expect(state.moves, [('a', 'c')]);
      expect(state.order, ['b', 'c', 'a', 'd']);
      expect(counts.disposed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  _testWidgets(
    'resize snaps live, saves once and keeps preview until storage finishes',
    (tester) async {
      final (state, counts) = await _pump(tester);
      state.edit(true);
      state.saving = Completer<void>();
      await tester.pump();
      final initial = tester.getSize(_card('a')).width;
      final gesture = await tester.startGesture(tester.getCenter(_resize('a')));
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      await gesture.moveBy(Offset(initial + 6, 0));
      await tester.pump();
      expect(tester.getSize(_card('a')).width, closeTo(initial * 2 + 16, .01));
      expect(state.resizes, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(state.resizes, [('a', 2)]);
      expect(state.spans['a'], 1);
      expect(tester.getSize(_card('a')).width, closeTo(initial * 2 + 16, .01));
      // A second gesture while persistence is pending must not change or clear
      // the first preview, or start a competing save for the same section.
      final pendingGesture = await tester.startGesture(
        tester.getCenter(_resize('a')),
      );
      await pendingGesture.moveBy(const Offset(24, 0));
      await pendingGesture.moveBy(Offset(initial, 0));
      await pendingGesture.up();
      await tester.pump();
      expect(state.resizes, [('a', 2)]);
      expect(tester.getSize(_card('a')).width, closeTo(initial * 2 + 16, .01));
      state.edit(false);
      await tester.pump();
      state.edit(true);
      await tester.pump();
      Focus.of(
        tester.element(
          find.descendant(of: _resize('a'), matching: find.byType(Icon)),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(state.resizes, [('a', 2)]);
      state.saving!.complete();
      await tester.pump();
      expect(state.spans['a'], 2);
      expect(counts.created.values, everyElement(1));
      expect(counts.disposed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  _testWidgets(
    'cancelled resize and rejected save restore the original width',
    (tester) async {
      final (state, _) = await _pump(tester);
      state.edit(true);
      await tester.pump();
      final initial = tester.getSize(_card('a')).width;
      var gesture = await tester.startGesture(tester.getCenter(_resize('a')));
      await gesture.moveBy(Offset(initial + 16, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(state.resizes, isEmpty);
      expect(tester.getSize(_card('a')).width, initial);
      state.rejectSave = true;
      gesture = await tester.startGesture(tester.getCenter(_resize('a')));
      await gesture.moveBy(const Offset(24, 0));
      await gesture.moveBy(Offset(initial + 16, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(tester.getSize(_card('a')).width, initial);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    _testWidgets('$platform stays one column even in landscape', (
      tester,
    ) async {
      final (state, _) = await _pump(tester);
      state.edit(true);
      await tester.pump();
      expect(tester.getSize(_card('a')).width, 1176);
      expect(
        tester.getTopLeft(_card('b')).dy,
        greaterThan(tester.getBottomLeft(_card('a')).dy),
      );
      expect(_resize('a'), findsNothing);
      expect(tester.getSize(_drag('a')), const Size(44, 44));
      expect(tester.takeException(), isNull);
    }, platform: platform);
  }

  _testWidgets('narrow desktop clamps saved widths without height clipping', (
    tester,
  ) async {
    final (state, _) = await _pump(tester, size: const Size(300, 900));
    state.spans['a'] = 3;
    state.edit(true);
    await tester.pump();
    expect(tester.getSize(_card('a')).width, 276);
    expect(tester.getSize(_card('a')).height, 132);
    expect(_resize('a'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _testWidgets('two-column maximum stores full width for wider windows', (
    tester,
  ) async {
    final (state, _) = await _pump(tester, size: const Size(800, 900));
    state.edit(true);
    await tester.pump();
    final initial = tester.getSize(_card('a')).width;
    final gesture = await tester.startGesture(tester.getCenter(_resize('a')));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveBy(Offset(initial, 0));
    await gesture.up();
    await tester.pump();
    expect(state.spans['a'], 3);
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(tester.getSize(_card('a')).width, 1176);
    expect(tester.takeException(), isNull);
  });

  _testWidgets('cancelled drag never saves the highlighted destination', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(_drag('a')));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(tester.getCenter(_card('c')));
    await tester.pump();
    expect(find.byKey(const ValueKey('dashboard-insert-c')), findsOneWidget);
    await gesture.cancel();
    await tester.pump();
    expect(state.moves, isEmpty);
    expect(find.byKey(const ValueKey('dashboard-insert-c')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _testWidgets('keyboard handles move cards and change their width', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    Focus.of(
      tester.element(
        find.descendant(of: _drag('a'), matching: find.byType(Icon)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(state.order, ['b', 'a', 'c', 'd']);
    Focus.of(
      tester.element(
        find.descendant(of: _resize('a'), matching: find.byType(Icon)),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.spans['a'], 2);
    expect(tester.takeException(), isNull);
  });

  _testWidgets(
    'dragging at the viewport edge scrolls and drops on the current card',
    (tester) async {
      final (state, counts) = await _pump(
        tester,
        size: const Size(400, 380),
        many: true,
      );
      state.edit(true);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(_drag('a')));
      await gesture.moveBy(const Offset(5, 24));
      await tester.pump();
      await gesture.moveTo(const Offset(200, 374));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state.scroll.offset, greaterThan(150));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.moves, hasLength(1));
      expect(state.moves.single.$2, isNot('b'));
      final stopped = state.scroll.offset;
      await tester.pump(const Duration(seconds: 1));
      expect(state.scroll.offset, stopped);
      expect(counts.created.values, everyElement(1));
      expect(counts.disposed, isEmpty);
      expect(tester.takeException(), isNull);
    },
    platform: TargetPlatform.android,
  );
}
