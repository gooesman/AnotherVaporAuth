const dashboardGridRowHeight = 48.0;
const dashboardGridGap = 16.0;
const dashboardGridMinRowSpan = 3;
const dashboardGridMaxRowSpan = 24;
const dashboardGridMaxRows = 256;

const _defaultRows = {
  'wallet': 4,
  'listings': 6,
  'favorites': 8,
  'friends': 6,
  'inventory': 6,
  'tools': 4,
};

/// Logical grid units, independent of screen pixels and Flutter widgets.
class DashboardGridRect {
  const DashboardGridRect({
    required this.column,
    required this.row,
    required this.columnSpan,
    required this.rowSpan,
  });

  final int column, row, columnSpan, rowSpan;

  int get right => column + columnSpan;
  int get bottom => row + rowSpan;

  DashboardGridRect copyWith({
    int? column,
    int? row,
    int? columnSpan,
    int? rowSpan,
  }) => DashboardGridRect(
    column: column ?? this.column,
    row: row ?? this.row,
    columnSpan: columnSpan ?? this.columnSpan,
    rowSpan: rowSpan ?? this.rowSpan,
  );

  DashboardGridRect normalized({int columns = 3}) {
    final count = columns.clamp(1, 3);
    final width = columnSpan.clamp(1, count);
    final height = rowSpan.clamp(
      dashboardGridMinRowSpan,
      dashboardGridMaxRowSpan,
    );
    return DashboardGridRect(
      column: column.clamp(0, count - width),
      row: row.clamp(0, dashboardGridMaxRows - height),
      columnSpan: width,
      rowSpan: height,
    );
  }

  static DashboardGridRect? fromJson(Object? value, {int columns = 3}) {
    if (value is! Map ||
        value['column'] is! int ||
        value['row'] is! int ||
        value['columnSpan'] is! int ||
        value['rowSpan'] is! int) {
      return null;
    }
    return DashboardGridRect(
      column: value['column'] as int,
      row: value['row'] as int,
      columnSpan: value['columnSpan'] as int,
      rowSpan: value['rowSpan'] as int,
    ).normalized(columns: columns);
  }

  Map<String, int> toJson() => {
    'column': column,
    'row': row,
    'columnSpan': columnSpan,
    'rowSpan': rowSpan,
  };

  bool overlaps(DashboardGridRect other) =>
      column < other.right &&
      right > other.column &&
      row < other.bottom &&
      bottom > other.row;

  @override
  bool operator ==(Object other) =>
      other is DashboardGridRect &&
      column == other.column &&
      row == other.row &&
      columnSpan == other.columnSpan &&
      rowSpan == other.rowSpan;

  @override
  int get hashCode => Object.hash(column, row, columnSpan, rowSpan);
}

DashboardGridRect _pushDown(
  DashboardGridRect rect,
  Iterable<DashboardGridRect> placed,
) {
  while (true) {
    var nextRow = rect.row;
    for (final other in placed) {
      if (rect.overlaps(other) && other.bottom > nextRow) {
        nextRow = other.bottom;
      }
    }
    if (nextRow == rect.row) return rect;
    rect = rect.copyWith(row: nextRow);
  }
}

int _compareRects(DashboardGridRect a, DashboardGridRect b) {
  final row = a.row.compareTo(b.row);
  return row == 0 ? a.column.compareTo(b.column) : row;
}

/// Projects saved rectangles without mutating them. Legacy cards retain their
/// Wrap order; new cards fill free cells. Hidden cards never reserve cells.
Map<String, DashboardGridRect> resolveDashboardGrid({
  required List<String> order,
  required Map<String, int> spans,
  required Map<String, DashboardGridRect> rects,
  required Iterable<String> visible,
  int columns = 3,
}) {
  final count = columns.clamp(1, 3);
  final enabled = visible.toSet();
  final ids = {...order.where(enabled.contains), ...enabled}.toList();
  final desired = {
    for (final id in ids)
      id:
          (rects[id] ??
                  DashboardGridRect(
                    column: 0,
                    row: 0,
                    columnSpan: spans[id] ?? 3,
                    rowSpan: _defaultRows[id] ?? 6,
                  ))
              .normalized(columns: count),
  };
  if (!ids.any(rects.containsKey)) {
    var column = 0, row = 0, rowBottom = 0;
    final flowed = <String, DashboardGridRect>{};
    for (final id in ids) {
      final rect = desired[id]!;
      if (column + rect.columnSpan > count) {
        column = 0;
        row = rowBottom;
      }
      flowed[id] = rect.copyWith(column: column, row: row);
      column += rect.columnSpan;
      if (row + rect.rowSpan > rowBottom) rowBottom = row + rect.rowSpan;
    }
    return Map.unmodifiable(flowed);
  }
  // Reserve a tail large enough for collision displacement of every card.
  final maxStart =
      (dashboardGridMaxRows -
              desired.values.fold<int>(0, (sum, rect) => sum + rect.rowSpan))
          .clamp(0, dashboardGridMaxRows);
  final explicit = ids.where(rects.containsKey).toList()
    ..sort((a, b) {
      // Keep the saved visual order when projection collapses two columns.
      final position = _compareRects(rects[a]!, rects[b]!);
      return position == 0
          ? ids.indexOf(a).compareTo(ids.indexOf(b))
          : position;
    });
  Map<String, DashboardGridRect> place({bool reserveTail = false}) {
    final placed = <String, DashboardGridRect>{};
    for (final id in explicit) {
      final rect = desired[id]!;
      placed[id] = _pushDown(
        reserveTail ? rect.copyWith(row: rect.row.clamp(0, maxStart)) : rect,
        placed.values,
      );
    }
    for (final id in ids.where((id) => !rects.containsKey(id))) {
      final rect = desired[id]!;
      DashboardGridRect? best;
      for (var column = 0; column <= count - rect.columnSpan; column++) {
        final candidate = _pushDown(
          rect.copyWith(column: column),
          placed.values,
        );
        if (best == null || _compareRects(candidate, best) < 0) {
          best = candidate;
        }
      }
      placed[id] = best!;
    }
    return placed;
  }

  var placed = place();
  if (placed.values.any((rect) => rect.bottom > dashboardGridMaxRows)) {
    placed = place(reserveTail: true);
  }
  return Map.unmodifiable({for (final id in ids) id: placed[id]!});
}

/// Applies one move or resize, giving the edited card priority. Other cards
/// retain their columns and can only move downward to resolve collisions.
Map<String, DashboardGridRect> relocateDashboardGrid({
  required Map<String, DashboardGridRect> current,
  required String section,
  required DashboardGridRect target,
  int columns = 3,
}) {
  if (!current.containsKey(section)) return Map.unmodifiable(current);
  final count = columns.clamp(1, 3);
  final base = resolveDashboardGrid(
    order: current.keys.toList(),
    spans: const {},
    rects: current,
    visible: current.keys,
    columns: count,
  );
  final desired = {
    for (final entry in base.entries)
      entry.key: (entry.key == section ? target : entry.value).normalized(
        columns: count,
      ),
  };
  final maxStart =
      (dashboardGridMaxRows -
              desired.values.fold<int>(0, (sum, rect) => sum + rect.rowSpan))
          .clamp(0, dashboardGridMaxRows);
  final selected = desired[section]!;
  final placed = <String, DashboardGridRect>{
    section: selected.copyWith(row: selected.row.clamp(0, maxStart)),
  };
  final originalOrder = current.keys.toList();
  final ids = originalOrder.where((id) => id != section).toList()
    ..sort((a, b) {
      final position = _compareRects(desired[a]!, desired[b]!);
      return position == 0
          ? originalOrder.indexOf(a).compareTo(originalOrder.indexOf(b))
          : position;
    });
  for (final id in ids) {
    final rect = desired[id]!;
    placed[id] = _pushDown(rect, placed.values);
  }
  return Map.unmodifiable({for (final id in current.keys) id: placed[id]!});
}
