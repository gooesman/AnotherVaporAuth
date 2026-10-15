import 'dart:async';

import 'package:ava/src/app/dashboard_sections.dart';
import 'package:ava/src/app/theme.dart';
import 'package:ava/src/ui/widgets/ava_panel.dart';
import 'package:ava/src/ui/widgets/dashboard_card_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'wallet',
  'friends',
  'listings',
  'inventory',
  'favorites',
  'tools',
];

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
  const _Harness({
    super.key,
    required this.counts,
    this.many = false,
    this.contentHeight = 88,
  });
  final _Counts counts;
  final bool many;
  final double contentHeight;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool editing = false, failSave = false;
  late final ids = widget.many ? _ids : _ids.take(4).toList();
  late DashboardLayout layout = DashboardLayout(
    order: _ids,
    spans: {for (final id in _ids) id: 1},
    rects: {
      for (var i = 0; i < ids.length; i++)
        ids[i]: DashboardGridRect(
          column: i % 2,
          row: (i ~/ 2) * 4,
          columnSpan: 1,
          rowSpan: 4,
        ),
    },
  );
  final saves = <(int, Map<String, DashboardGridRect>)>[];
  final scroll = ScrollController();
  Completer<void>? saving;
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
            for (final id in ids)
              id: AvaPanel(
                emphasized: id == 'wallet',
                child: _Card(id, widget.counts, widget.contentHeight),
              ),
          },
          titles: {for (final id in ids) id: 'Card $id'},
          layout: layout,
          editing: editing,
          dragLabel: 'Move',
          resizeLabel: 'Resize',
          onChanged: (columns, rects) async {
            saves.add((columns, rects));
            if (saving != null) await saving!.future;
            if (failSave) throw StateError('Test save failure');
            if (mounted) {
              setState(
                () => layout = DashboardLayout(
                  order: layout.order,
                  spans: layout.spans,
                  rects: columns == 3
                      ? {...layout.rects, ...rects}
                      : layout.rects,
                  responsiveRects: {
                    ...layout.responsiveRects,
                    if (columns < 3)
                      columns: {...?layout.responsiveRects[columns], ...rects},
                  },
                ),
              );
            }
          },
        ),
      ),
    ),
  );
}

Future<(_HarnessState, _Counts)> _pump(
  WidgetTester tester, {
  Size size = const Size(1200, 1000),
  bool many = false,
  double contentHeight = 88,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey<_HarnessState>(), counts = _Counts();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAvaTheme(AvaThemeVariant.dark),
      home: _Harness(
        key: key,
        counts: counts,
        many: many,
        contentHeight: contentHeight,
      ),
    ),
  );
  await tester.pump();
  return (key.currentState!, counts);
}

Finder _card(String id) => find.byKey(ValueKey('dashboard-layout-$id'));
Finder _drag(String id) => find.byKey(ValueKey('dashboard-drag-$id'));
Finder _resize(String id) => find.byKey(ValueKey('dashboard-resize-$id'));
Future<TestGesture> _gesture(
  WidgetTester tester,
  Finder handle,
  Offset delta,
) async {
  final start = tester.getCenter(handle);
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(const Offset(24, 4));
  await tester.pump();
  await gesture.moveTo(start + delta);
  await tester.pump();
  return gesture;
}

void _test(
  String name,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.windows,
}) =>
    testWidgets(name, callback, variant: TargetPlatformVariant.only(platform));
void _focus(WidgetTester tester, Finder handle) => Focus.of(
  tester.element(find.descendant(of: handle, matching: find.byType(Icon))),
).requestFocus();

void main() {
  _test('editing overlays do not change content size or recreate readers', (
    tester,
  ) async {
    final (state, counts) = await _pump(tester);
    final rect = tester.getRect(_card('wallet'));
    expect(_drag('wallet'), findsNothing);
    expect(_resize('wallet'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('content-wallet')));
    state.edit(true);
    await tester.pump();
    expect(tester.getRect(_card('wallet')), rect);
    await tester.tap(find.byKey(const ValueKey('content-friends')));
    state.edit(false);
    await tester.pump();
    expect(tester.getRect(_card('wallet')), rect);
    expect(counts.clicked, ['wallet', 'friends']);
    expect(counts.created.values, everyElement(1));
    expect(counts.disposed, isEmpty);
    expect(state.saves, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _test('free x/y move keeps blank cells and commits once on release', (
    tester,
  ) async {
    final (state, counts) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    final oldFriends = tester.getRect(_card('friends'));
    final unit = tester.getSize(_card('wallet')).width + 16;
    final gesture = await _gesture(
      tester,
      _drag('wallet'),
      Offset(unit * 2, 48 * 5),
    );
    expect(state.saves, isEmpty);
    expect(
      tester.getTopLeft(_card('wallet')),
      Offset(12 + unit * 2, 12 + 48 * 5),
    );
    expect(tester.getRect(_card('friends')), oldFriends);
    await gesture.up();
    await tester.pump();
    expect(state.saves, hasLength(1));
    expect(
      state.layout.rects['wallet'],
      const DashboardGridRect(column: 2, row: 5, columnSpan: 1, rowSpan: 4),
    );
    expect(counts.created.values, everyElement(1));
    expect(counts.disposed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _test('corner resize changes both dimensions and blocks saves until stored', (
    tester,
  ) async {
    final (state, counts) = await _pump(tester);
    state.edit(true);
    state.saving = Completer<void>();
    await tester.pump();
    final unit = tester.getSize(_card('wallet')).width + 16;
    final gesture = await _gesture(
      tester,
      _resize('wallet'),
      Offset(unit, 144),
    );
    expect(tester.getSize(_card('wallet')), Size(unit * 2 - 16, 7 * 48 - 16));
    expect(state.saves, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(state.saves, hasLength(1));
    expect(state.layout.rects['wallet']!.rowSpan, 4);
    state.edit(false);
    await tester.pump();
    state.edit(true);
    await tester.pump();
    _focus(tester, _resize('wallet'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final blocked = await _gesture(
      tester,
      _resize('wallet'),
      const Offset(0, 96),
    );
    await blocked.up();
    await tester.pump();
    expect(state.saves, hasLength(1));
    state.saving!.complete();
    await tester.pump();
    expect(state.layout.rects['wallet']!.rowSpan, 7);
    expect(state.layout.rects['wallet']!.columnSpan, 2);
    expect(counts.created.values, everyElement(1));
    expect(counts.disposed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _test('pointer cancel and leaving edit mode discard unsaved placement', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    final original = tester.getRect(_card('wallet'));
    for (final handle in [_drag('wallet'), _resize('wallet')]) {
      final gesture = await _gesture(tester, handle, const Offset(0, 144));
      await gesture.cancel();
      await tester.pump();
      expect(tester.getRect(_card('wallet')), original);
    }
    final gesture = await _gesture(
      tester,
      _drag('wallet'),
      const Offset(0, 144),
    );
    state.edit(false);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(tester.getRect(_card('wallet')), original);
    expect(state.saves, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _test('failed persistence restores coordinates and permits retry', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.failSave = true;
    state.edit(true);
    await tester.pump();
    final original = tester.getRect(_card('wallet'));
    var gesture = await _gesture(
      tester,
      _resize('wallet'),
      const Offset(0, 144),
    );
    await gesture.up();
    await tester.pump();
    expect(tester.getRect(_card('wallet')), original);
    state.failSave = false;
    gesture = await _gesture(tester, _resize('wallet'), const Offset(0, 96));
    await gesture.up();
    await tester.pump();
    expect(state.layout.rects['wallet']!.rowSpan, 6);
    expect(tester.takeException(), isNull);
  });

  _test('a second finger on resize cannot finish an active move gesture', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    final moving = await _gesture(
      tester,
      _drag('wallet'),
      const Offset(0, 144),
    );
    final preview = tester.getRect(_card('wallet'));
    final resizing = await tester.startGesture(
      tester.getCenter(_resize('wallet')),
      pointer: 2,
    );
    await resizing.moveBy(const Offset(24, 0));
    await resizing.moveBy(const Offset(0, 96));
    await resizing.up();
    await tester.pump();
    expect(state.saves, isEmpty);
    expect(tester.getRect(_card('wallet')), preview);
    await moving.up();
    await tester.pump();
    expect(state.saves, hasLength(1));
    expect(state.layout.rects['wallet']!.row, 3);
    expect(state.layout.rects['wallet']!.rowSpan, 4);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    _test(
      '$platform stays single column and stores vertical edits separately',
      (tester) async {
        final (state, _) = await _pump(tester);
        final original = Map.of(state.layout.rects);
        state.edit(true);
        await tester.pump();
        expect(tester.getSize(_card('wallet')).width, 1176);
        final gesture = await _gesture(
          tester,
          _resize('wallet'),
          const Offset(-200, 96),
        );
        await gesture.up();
        await tester.pump();
        expect(state.saves.single.$1, 1);
        expect(state.layout.responsiveRects[1]!['wallet']!.rowSpan, 6);
        expect(state.layout.rects, original);
        expect(tester.getSize(_drag('wallet')), const Size(44, 44));
        expect(tester.takeException(), isNull);
      },
      platform: platform,
    );
  }

  _test(
    'window narrowing only projects and never overwrites desktop coordinates',
    (tester) async {
      final (state, counts) = await _pump(tester);
      final original = tester.getRect(_card('friends'));
      tester.view.physicalSize = const Size(300, 900);
      await tester.pump();
      expect(tester.getSize(_card('wallet')).width, 276);
      expect(state.saves, isEmpty);
      tester.view.physicalSize = const Size(1200, 1000);
      await tester.pump();
      expect(tester.getRect(_card('friends')), original);
      expect(counts.disposed, isEmpty);
      expect(counts.created.values, everyElement(1));
      expect(tester.takeException(), isNull);
    },
  );

  _test('changing columns during a gesture cancels its uncommitted preview', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    final original = Map.of(state.layout.rects);
    final gesture = await _gesture(
      tester,
      _resize('wallet'),
      const Offset(0, 144),
    );
    tester.view.physicalSize = const Size(600, 900);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(state.saves, isEmpty);
    expect(state.layout.rects, original);
    expect(tester.takeException(), isNull);
  });

  _test('fixed card surface replaces only embedded panel decoration', (
    tester,
  ) async {
    await _pump(tester);
    final panelFinder = find.descendant(
      of: _card('wallet'),
      matching: find.byType(AvaPanel),
    );
    expect(panelFinder, findsOneWidget);
    final panel = tester.widget<AvaPanel>(panelFinder);
    final padding = tester.widget<Padding>(
      find.descendant(of: panelFinder, matching: find.byType(Padding)).first,
    );
    expect(padding.padding, panel.padding);
    expect(
      find.descendant(of: panelFinder, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    final surface = tester.widget<DecoratedBox>(
      find
          .descendant(of: _card('wallet'), matching: find.byType(DecoratedBox))
          .first,
    );
    final decoration = surface.decoration as BoxDecoration;
    final tokens = Theme.of(
      tester.element(_card('wallet')),
    ).extension<AvaTokens>()!;
    expect(decoration.color, tokens.panel);
    expect(decoration.border!.top.color, tokens.accent);
    expect(tester.takeException(), isNull);
  });

  _test('keyboard supports both axes for movement and resizing', (
    tester,
  ) async {
    final (state, _) = await _pump(tester);
    state.edit(true);
    await tester.pump();
    _focus(tester, _drag('wallet'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(state.layout.rects['wallet']!.column, 1);
    expect(state.layout.rects['wallet']!.row, 1);
    _focus(tester, _resize('wallet'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(state.layout.rects['wallet']!.columnSpan, 2);
    expect(state.layout.rects['wallet']!.rowSpan, 5);
    expect(tester.takeException(), isNull);
  });

  _test(
    'overflowing content scrolls within its card then yields to outer page',
    (tester) async {
      final (state, _) = await _pump(
        tester,
        size: const Size(1200, 380),
        many: true,
        contentHeight: 600,
      );
      final inner = tester
          .widget<SingleChildScrollView>(
            find.descendant(
              of: _card('wallet'),
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .controller!;
      var position = tester.getCenter(_card('wallet'));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pump();
      expect(inner.offset, 120);
      expect(state.scroll.offset, 0);
      inner.jumpTo(inner.position.maxScrollExtent);
      await tester.pump();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pump();
      expect(state.scroll.offset, greaterThan(0));
      state.scroll.jumpTo(0);
      await tester.pump();
      position = tester.getCenter(_card('wallet'));
      final touch = await tester.startGesture(position);
      await touch.moveBy(const Offset(0, -30));
      await touch.moveBy(const Offset(0, -60));
      await tester.pump();
      await touch.up();
      await tester.pumpAndSettle();
      expect(state.scroll.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  _test(
    'edge dragging scrolls the outer page and stops after release',
    (tester) async {
      final (state, counts) = await _pump(
        tester,
        size: const Size(400, 380),
        many: true,
      );
      state.edit(true);
      await tester.pump();
      final gesture = await _gesture(
        tester,
        _drag('wallet'),
        const Offset(0, 340),
      );
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state.scroll.offset, greaterThan(150));
      expect(state.saves, isEmpty);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.saves, hasLength(1));
      final stopped = state.scroll.offset;
      await tester.pump(const Duration(seconds: 1));
      expect(state.scroll.offset, stopped);
      expect(counts.disposed, isEmpty);
      expect(counts.created.values, everyElement(1));
      expect(tester.takeException(), isNull);
    },
    platform: TargetPlatform.android,
  );

  _test(
    'disposing an active edge drag stops scrolling without saving',
    (tester) async {
      final (state, counts) = await _pump(
        tester,
        size: const Size(400, 380),
        many: true,
      );
      state.edit(true);
      await tester.pump();
      final gesture = await _gesture(
        tester,
        _drag('wallet'),
        const Offset(0, 340),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.saves, isEmpty);
      expect(counts.disposed.values, everyElement(1));
      expect(tester.takeException(), isNull);
    },
    platform: TargetPlatform.android,
  );
}
