import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_grid.dart';
import 'providers.dart';

export 'dashboard_grid.dart';

final dashboardSectionsProvider =
    NotifierProvider<DashboardSections, Set<String>>(DashboardSections.new);

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutController, DashboardLayout>(
      DashboardLayoutController.new,
    );

/// Device-local arrangement, including cards that are currently switched off.
class DashboardLayout {
  static const defaultOrder = [
    'wallet',
    'listings',
    'favorites',
    'friends',
    'inventory',
    'tools',
  ];
  static const defaultSpans = {
    'wallet': 3,
    'listings': 3,
    'favorites': 1,
    'friends': 1,
    'inventory': 1,
    'tools': 3,
  };

  final List<String> order;
  final Map<String, int> spans;
  final Map<String, DashboardGridRect> rects;
  final Map<int, Map<String, DashboardGridRect>> responsiveRects;

  DashboardLayout._(
    List<String> order,
    Map<String, int> spans,
    Map<String, DashboardGridRect> rects,
    Map<int, Map<String, DashboardGridRect>> responsiveRects,
  ) : order = List.unmodifiable(order),
      spans = Map.unmodifiable(spans),
      rects = Map.unmodifiable(rects),
      responsiveRects = Map.unmodifiable({
        for (final entry in responsiveRects.entries)
          entry.key: Map<String, DashboardGridRect>.unmodifiable(entry.value),
      });

  factory DashboardLayout({
    List<String>? order,
    Map<String, int>? spans,
    Map<String, DashboardGridRect> rects = const {},
    Map<int, Map<String, DashboardGridRect>> responsiveRects = const {},
  }) => DashboardLayout.fromJson({
    'order': order,
    'spans': spans,
    'rects': {
      for (final entry in rects.entries) entry.key: entry.value.toJson(),
    },
    'responsiveRects': {
      for (final profile in responsiveRects.entries)
        '${profile.key}': {
          for (final entry in profile.value.entries)
            entry.key: entry.value.toJson(),
        },
    },
  });

  /// A missing narrow profile uses the nearest wider one for read-only
  /// projection. Only an explicit edit creates its own stored profile.
  Map<String, DashboardGridRect> gridForColumns(int columns) =>
      switch (columns.clamp(1, 3)) {
        1 => responsiveRects[1] ?? responsiveRects[2] ?? rects,
        2 => responsiveRects[2] ?? rects,
        _ => rects,
      };

  factory DashboardLayout.fromJson(Object? value) {
    final saved = value is Map ? value : const {};
    final rawOrder = saved['order'];
    final order = <String>{
      if (rawOrder is List)
        for (final section in rawOrder)
          if (section is String && defaultSpans.containsKey(section)) section,
      ...defaultOrder,
    }.toList();
    final rawSpans = saved['spans'];
    final spans = {...defaultSpans};
    if (rawSpans is Map) {
      for (final section in defaultOrder) {
        final span = rawSpans[section];
        if (span is int && span >= 1 && span <= 3) spans[section] = span;
      }
    }
    Map<String, DashboardGridRect> readRects(Object? value, int columns) {
      if (value is! Map) return {};
      return {
        for (final section in defaultOrder)
          section: ?DashboardGridRect.fromJson(
            value[section],
            columns: columns,
          ),
      };
    }

    final rawResponsive = saved['responsiveRects'];
    final responsive = <int, Map<String, DashboardGridRect>>{};
    if (rawResponsive is Map) {
      for (final columns in [1, 2]) {
        final profile = readRects(rawResponsive['$columns'], columns);
        if (profile.isNotEmpty) responsive[columns] = profile;
      }
    }
    return DashboardLayout._(
      order,
      spans,
      readRects(saved['rects'], 3),
      responsive,
    );
  }
}

class DashboardLayoutController extends Notifier<DashboardLayout> {
  int _generation = 0;
  Future<void> _writes = Future.value();
  bool ready = false;

  @override
  DashboardLayout build() {
    ready = false;
    final generation = ++_generation;
    _writes = Future.value();
    ref
        .read(settingsStoreProvider)
        .loadDashboardLayout()
        .then((saved) {
          if (ref.mounted && generation == _generation) {
            ready = true;
            state = DashboardLayout.fromJson(saved);
          }
        })
        .catchError((Object _) {
          if (ref.mounted && generation == _generation) {
            ready = true;
            state = DashboardLayout();
          }
        });
    return DashboardLayout();
  }

  Future<void> _save(DashboardLayout Function(DashboardLayout) change) {
    if (!ready) return Future.value();
    final generation = _generation;
    final store = ref.read(settingsStoreProvider);
    final write = _writes.then((_) async {
      if (!ref.mounted || generation != _generation) return;
      final next = change(state);
      if (identical(next, state)) return;
      await store.saveDashboardLayout(
        next.order,
        next.spans,
        rects: {
          for (final entry in next.rects.entries)
            entry.key: entry.value.toJson(),
        },
        responsiveRects: {
          for (final profile in next.responsiveRects.entries)
            profile.key: {
              for (final entry in profile.value.entries)
                entry.key: entry.value.toJson(),
            },
        },
      );
      if (ref.mounted && generation == _generation) state = next;
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> saveGrid(
    Map<String, DashboardGridRect> visibleDelta, {
    int columns = 3,
  }) {
    if (columns < 1 || columns > 3) return Future.value();
    final snapshot = {
      for (final entry in visibleDelta.entries)
        if (DashboardLayout.defaultSpans.containsKey(entry.key))
          entry.key: entry.value.normalized(columns: columns),
    };
    if (snapshot.isEmpty) return Future.value();
    return _save((current) {
      final delta = resolveDashboardGrid(
        order: current.order,
        spans: current.spans,
        rects: snapshot,
        visible: snapshot.keys,
        columns: columns,
      );
      final existing = columns == 3
          ? current.rects
          : current.responsiveRects[columns];
      if (existing != null &&
          delta.entries.every((entry) => existing[entry.key] == entry.value)) {
        return current;
      }
      final merged = {...current.gridForColumns(columns), ...delta};
      return DashboardLayout(
        order: current.order,
        spans: {
          ...current.spans,
          if (columns == 3)
            for (final entry in delta.entries)
              entry.key: entry.value.columnSpan,
        },
        rects: columns == 3 ? merged : current.rects,
        responsiveRects: {
          ...current.responsiveRects,
          if (columns != 3) columns: merged,
        },
      );
    });
  }

  Future<void> reset() => _save((_) => DashboardLayout());
}

class DashboardSections extends Notifier<Set<String>> {
  static const defaults = {'wallet', 'listings', 'tools'};
  static const all = {...defaults, 'friends', 'inventory', 'favorites'};
  int _generation = 0;
  Future<void> _writes = Future.value();
  bool ready = false;

  @override
  Set<String> build() {
    ready = false;
    final generation = ++_generation;
    _writes = Future.value();
    ref
        .read(settingsStoreProvider)
        .loadDashboardSections()
        .then((saved) {
          if (ref.mounted && generation == _generation) {
            ready = true;
            state = saved?.where(all.contains).toSet() ?? {...defaults};
          }
        })
        .catchError((Object _) {
          if (ref.mounted && generation == _generation) {
            ready = true;
            state = {...defaults};
          }
        });
    return {...defaults};
  }

  Future<void> toggle(String section) {
    if (!ready || !all.contains(section)) return Future.value();
    final generation = _generation;
    final store = ref.read(settingsStoreProvider);
    final write = _writes.then((_) async {
      if (!ref.mounted || generation != _generation) return;
      final next = {...state};
      if (!next.remove(section)) next.add(section);
      await store.saveDashboardSections(next.toList());
      if (ref.mounted && generation == _generation) state = next;
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
