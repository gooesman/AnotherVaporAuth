import 'sync_payload.dart';

class SyncFieldDiff {
  final String path;
  final Object? local;
  final Object? remote;
  final bool masked;
  const SyncFieldDiff(this.path, this.local, this.remote, this.masked);
}

/// Compare logical fields; never return credential values to the UI.
List<SyncFieldDiff> syncFieldDiff(
  Map<String, dynamic>? local,
  Map<String, dynamic>? remote,
) {
  final result = <SyncFieldDiff>[];
  final account =
      local?.containsKey('Session') == true ||
      remote?.containsKey('Session') == true;
  void walk(String path, Object? a, Object? b) {
    if (canonicalJson(a) == canonicalJson(b)) return;
    final masked =
        (account &&
            path.isNotEmpty &&
            !const {
              'account_name',
              'persona_name',
              'nickname',
              'Session',
              'Session.SteamID',
            }.contains(path)) ||
        RegExp(
          r'secret|password|token|revocation|serial_number|device_id',
          caseSensitive: false,
        ).hasMatch(path) ||
        path == 'steam_acceleration.url' ||
        path == 'steam_acceleration.nodes';
    if (masked) {
      result.add(
        SyncFieldDiff(
          path,
          a == null ? null : true,
          b == null ? null : true,
          true,
        ),
      );
    } else if (a is Map || b is Map) {
      final am = a is Map ? a : const {};
      final bm = b is Map ? b : const {};
      final keys = {...am.keys, ...bm.keys}.map((k) => '$k').toList()..sort();
      for (final key in keys) {
        walk(path.isEmpty ? key : '$path.$key', am[key], bm[key]);
      }
    } else if (path == 'market_favorites.items') {
      // Use stable product IDs instead of list positions so a deletion does
      // not make every subsequent favorite appear changed.
      Map<String, Object?> byProduct(Object? value) => value is List
          ? {
              for (final row in value.whereType<Map>())
                '${row['appid']}/${row['market_hash_name']}': row,
            }
          : {};
      walk(path, byProduct(a), byProduct(b));
    } else {
      result.add(SyncFieldDiff(path, a, b, false));
    }
  }

  walk('', local, remote);
  return result;
}
