import 'dart:math';

import 'package:ava/src/app/dashboard_grid.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardGridRect rect(int column, int row, int width, int height) =>
    DashboardGridRect(
      column: column,
      row: row,
      columnSpan: width,
      rowSpan: height,
    );

void validGrid(Map<String, DashboardGridRect> grid, int columns) {
  for (final a in grid.entries) {
    expect(a.value.column, greaterThanOrEqualTo(0));
    expect(a.value.right, lessThanOrEqualTo(columns));
    expect(a.value.row, greaterThanOrEqualTo(0));
    expect(a.value.bottom, lessThanOrEqualTo(dashboardGridMaxRows));
    expect(
      a.value.rowSpan,
      inInclusiveRange(dashboardGridMinRowSpan, dashboardGridMaxRowSpan),
    );
    for (final b in grid.entries) {
      if (a.key != b.key) {
        expect(
          a.value.overlaps(b.value),
          isFalse,
          reason: '${a.key} overlaps ${b.key}',
        );
      }
    }
  }
}

void main() {
  test('legacy visible cards pack without space for disabled cards', () {
    final result = resolveDashboardGrid(
      order: ['wallet', 'listings', 'friends', 'inventory', 'tools'],
      spans: {
        'wallet': 3,
        'listings': 3,
        'friends': 1,
        'inventory': 1,
        'tools': 3,
      },
      rects: {},
      visible: ['wallet', 'tools'],
    );
    expect(result, {'wallet': rect(0, 0, 3, 4), 'tools': rect(0, 4, 3, 4)});
    validGrid(result, 3);
  });

  test(
    'explicit coordinates keep intentional gaps and unsaved cards fill available cells',
    () {
      final source = {'a': rect(2, 10, 1, 4)};
      final result = resolveDashboardGrid(
        order: ['a', 'b'],
        spans: {'b': 2},
        rects: source,
        visible: ['a', 'b'],
      );
      expect(result['a'], source['a']);
      expect(result['b'], rect(0, 0, 2, 6));
      expect(source, {'a': rect(2, 10, 1, 4)});
      validGrid(result, 3);
    },
  );

  test(
    'legacy mixed widths retain Wrap order instead of filling earlier holes',
    () {
      final result = resolveDashboardGrid(
        order: ['wallet', 'listings', 'favorites', 'tools'],
        spans: {'wallet': 2, 'listings': 2, 'favorites': 1, 'tools': 3},
        rects: {},
        visible: ['wallet', 'listings', 'favorites', 'tools'],
      );
      expect(result['wallet'], rect(0, 0, 2, 4));
      expect(result['listings'], rect(0, 4, 2, 6));
      expect(result['favorites'], rect(2, 4, 1, 8));
      expect(result['tools'], rect(0, 12, 3, 4));
      validGrid(result, 3);
    },
  );

  test(
    'moving changes x and y independently and pushes only collisions down',
    () {
      final current = {
        'a': rect(0, 0, 1, 4),
        'b': rect(1, 0, 1, 4),
        'c': rect(1, 4, 1, 4),
        'd': rect(2, 0, 1, 4),
      };
      final result = relocateDashboardGrid(
        current: current,
        section: 'a',
        target: rect(1, 2, 1, 4),
      );
      expect(result['a'], rect(1, 2, 1, 4));
      expect(result['b'], rect(1, 6, 1, 4));
      expect(result['c'], rect(1, 10, 1, 4));
      expect(result['d'], current['d']);
      expect(current['a'], rect(0, 0, 1, 4));
      validGrid(result, 3);
    },
  );

  test(
    'one resize gives edited width and height priority over other cards',
    () {
      final current = {
        'a': rect(0, 0, 1, 4),
        'b': rect(1, 0, 2, 4),
        'c': rect(0, 4, 3, 4),
      };
      final result = relocateDashboardGrid(
        current: current,
        section: 'a',
        target: rect(0, 0, 2, 8),
      );
      expect(result['a'], rect(0, 0, 2, 8));
      expect(result['b'], rect(1, 8, 2, 4));
      expect(result['c'], rect(0, 12, 3, 4));
      validGrid(result, 3);
    },
  );

  test(
    'narrow projection is single column and never mutates desktop coordinates',
    () {
      final source = {
        'a': rect(2, 0, 1, 4),
        'b': rect(0, 0, 2, 4),
        'c': rect(0, 4, 3, 6),
      };
      final before = {...source};
      final result = resolveDashboardGrid(
        order: ['b', 'a', 'c'],
        spans: {},
        rects: source,
        visible: source.keys,
        columns: 1,
      );
      expect(result['b'], rect(0, 0, 1, 4));
      expect(result['a'], rect(0, 4, 1, 4));
      expect(result['c'], rect(0, 8, 1, 6));
      expect(source, before);
      validGrid(result, 1);
    },
  );

  test(
    'hidden card coordinates are restored without reserving its footprint',
    () {
      final source = {'a': rect(0, 0, 1, 6), 'b': rect(2, 14, 1, 4)};
      final hidden = resolveDashboardGrid(
        order: ['a', 'b'],
        spans: {},
        rects: source,
        visible: ['a'],
      );
      expect(hidden, {'a': source['a']});
      final shown = resolveDashboardGrid(
        order: ['a', 'b'],
        spans: {},
        rects: source,
        visible: source.keys,
      );
      expect(shown, source);
    },
  );

  test(
    'narrow projection follows saved visual position after free movement',
    () {
      final source = {'a': rect(2, 0, 1, 4), 'b': rect(0, 0, 2, 4)};
      final result = resolveDashboardGrid(
        order: ['a', 'b'],
        spans: {},
        rects: source,
        visible: source.keys,
        columns: 1,
      );
      expect(result['b'], rect(0, 0, 1, 4));
      expect(result['a'], rect(0, 4, 1, 4));
    },
  );

  test(
    'malformed and bottom-edge geometry resolves into finite legal cells',
    () {
      final source = {
        'a': rect(-10, -50, 0, -1),
        'b': rect(5, 10000, 10, 1000),
        'c': rect(0, 10000, 3, 24),
      };
      final result = resolveDashboardGrid(
        order: source.keys.toList(),
        spans: {},
        rects: source,
        visible: source.keys,
      );
      validGrid(result, 3);
      expect(result['a'], rect(0, 0, 1, 3));
      final moved = relocateDashboardGrid(
        current: result,
        section: 'a',
        target: rect(9, 10000, 99, 1000),
      );
      validGrid(moved, 3);
    },
  );

  test(
    'legal saved coordinates near the bottom remain unchanged on reload',
    () {
      final source = {'a': rect(0, 240, 3, 6), 'b': rect(0, 250, 3, 6)};
      final result = resolveDashboardGrid(
        order: ['a', 'b'],
        spans: {},
        rects: source,
        visible: source.keys,
      );
      expect(result, source);
      validGrid(result, 3);
    },
  );

  test('sequential moves and resizes stay bounded and never overlap', () {
    final random = Random(1516);
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    for (final columns in [1, 2, 3]) {
      var grid = resolveDashboardGrid(
        order: ids,
        spans: {},
        rects: {},
        visible: ids,
        columns: columns,
      );
      for (var step = 0; step < 200; step++) {
        final section = ids[random.nextInt(ids.length)];
        final previous = grid;
        grid = relocateDashboardGrid(
          current: grid,
          section: section,
          target: rect(
            random.nextInt(6) - 1,
            random.nextInt(400) - 10,
            random.nextInt(5),
            random.nextInt(40),
          ),
          columns: columns,
        );
        validGrid(grid, columns);
        for (final id in ids.where((id) => id != section)) {
          expect(grid[id]!.row, greaterThanOrEqualTo(previous[id]!.row));
        }
        final reopened = resolveDashboardGrid(
          order: ids,
          spans: {},
          rects: grid,
          visible: ids,
          columns: columns,
        );
        expect(reopened, grid);
      }
    }
  });

  test('unknown edits and returned maps cannot alter existing geometry', () {
    final current = {'a': rect(1, 2, 1, 4)};
    final result = relocateDashboardGrid(
      current: current,
      section: 'unknown',
      target: rect(0, 0, 3, 8),
    );
    expect(result, current);
    expect(() => result.clear(), throwsUnsupportedError);
  });
}
