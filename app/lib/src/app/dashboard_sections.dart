import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

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

  DashboardLayout._(List<String> order, Map<String, int> spans)
    : order = List.unmodifiable(order),
      spans = Map.unmodifiable(spans);

  factory DashboardLayout({List<String>? order, Map<String, int>? spans}) =>
      DashboardLayout.fromJson({'order': order, 'spans': spans});

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
    return DashboardLayout._(order, spans);
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
      await store.saveDashboardLayout(next.order, next.spans);
      if (ref.mounted && generation == _generation) state = next;
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> move(String moving, String target) => _save((current) {
    final from = current.order.indexOf(moving);
    final to = current.order.indexOf(target);
    if (from < 0 || to < 0 || from == to) return current;
    final order = [...current.order]..removeAt(from);
    order.insert(to, moving);
    return DashboardLayout(order: order, spans: current.spans);
  });

  Future<void> setSpan(String section, int span) => _save((current) {
    if (!current.spans.containsKey(section) ||
        span < 1 ||
        span > 3 ||
        current.spans[section] == span) {
      return current;
    }
    return DashboardLayout(
      order: current.order,
      spans: {...current.spans, section: span},
    );
  });

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
