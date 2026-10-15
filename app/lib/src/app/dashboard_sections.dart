import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

final dashboardSectionsProvider =
    NotifierProvider<DashboardSections, Set<String>>(DashboardSections.new);

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
