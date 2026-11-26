import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// One display choice for the selected account and every home account row.
enum AccountNameMode { username, persona, id }

final accountNameModeProvider =
    NotifierProvider<AccountNameModeController, AccountNameMode>(
      AccountNameModeController.new,
    );

class AccountNameModeController extends Notifier<AccountNameMode> {
  Object? _pendingLoad;

  @override
  AccountNameMode build() {
    final load = Object();
    _pendingLoad = load;
    ref.read(settingsStoreProvider).loadAccountNameMode().then((name) {
      // A tap during startup wins over the older stored value. The provider
      // also keeps the choice when home is rebuilt after locking/unlocking.
      if (!ref.mounted || !identical(_pendingLoad, load)) return;
      for (final mode in AccountNameMode.values) {
        if (mode.name == name) {
          state = mode;
          break;
        }
      }
    });
    return AccountNameMode.username;
  }

  Future<void> cycle() async {
    _pendingLoad = null;
    final next = AccountNameMode
        .values[(state.index + 1) % AccountNameMode.values.length];
    state = next;
    // SettingsStore serializes writes, including rapid repeated taps.
    await ref.read(settingsStoreProvider).saveAccountNameMode(next.name);
  }
}
