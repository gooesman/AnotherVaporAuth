import 'dart:async';
import 'dart:convert';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/core/models/session_data.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/proto/protobuf_wire.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/avatar_service.dart';
import 'package:ava/src/services/credential_store.dart';
import 'package:ava/src/services/steam_api_client.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = 76561198000000123;

class _Controller extends AppController {
  // Test the same locked state without a platform keystore or real vault.
  void setLocked() =>
      state = AsyncData(state.value!.copyWith(locked: true, accounts: []));
}

class _Credentials implements CredentialStore {
  @override
  Future<String?> password(int steamId) async => null;
  @override
  Future<void> clear(int steamId) async {}
  @override
  Future<void> savePassword(int steamId, String password) async {}
}

class _Avatars implements AvatarService {
  final profile = Completer<SteamProfile>();
  final equipped = Completer<EquippedItems>();
  final tokens = <String?>[];

  @override
  Future<SteamProfile> fetchProfile(int steamId) => profile.future;

  @override
  Future<EquippedItems> fetchEquippedItems(int steamId, String? accessToken) {
    tokens.add(accessToken);
    return tokens.length == 1
        ? equipped.future
        : Future.value(const EquippedItems(frameUrl: 'replacement-frame'));
  }
}

class _Api extends SteamApiClient {
  final started = Completer<void>();
  final response = Completer<ProtoReader>();
  int exchanges = 0;

  @override
  Future<ProtoReader> callProtobuf(
    String iface,
    String method, {
    required ProtoWriter request,
    String? accessToken,
    bool useGet = false,
    int version = 1,
  }) {
    expect(method, 'GenerateAccessTokenForApp');
    exchanges++;
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  void complete() => response.complete(
    ProtoReader(
      (ProtoWriter()
            ..writeString(1, 'replacement-access')
            ..writeString(2, 'replacement-refresh'))
          .toBytes(),
    ),
  );
}

class _Harness {
  _Harness(
    this.storage,
    this.container,
    this.controller,
    this.avatars,
    this.api,
  );
  final MemoryStorageProvider storage;
  final ProviderContainer container;
  final _Controller controller;
  final _Avatars avatars;
  final _Api api;
  bool disposed = false;

  SteamGuardAccount get account =>
      container.read(appControllerProvider).value!.accounts.single;
  Map<String, dynamic> get saved =>
      jsonDecode(storage.files['$_id.maFile']!) as Map<String, dynamic>;
  void dispose() {
    if (!disposed) container.dispose();
    disposed = true;
  }
}

Future<_Harness> _setup() async {
  final storage = MemoryStorageProvider();
  await AccountStore(storage).saveAccount(
    SteamGuardAccount(
      accountName: 'synthetic-avatar-user',
      sharedSecret: 'synthetic-shared',
      identitySecret: 'synthetic-identity',
      password: 'old-password',
      session: SessionData(
        steamId: _id,
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      ),
    ),
    false,
  );
  final avatars = _Avatars();
  final api = _Api();
  final controller = _Controller();
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(() => controller),
      storageProvider.overrideWithValue(storage),
      avatarServiceProvider.overrideWithValue(avatars),
      credentialStoreProvider.overrideWithValue(_Credentials()),
      apiClientProvider.overrideWithValue(api),
      timeAlignerProvider.overrideWithValue(() async {}),
    ],
  );
  final harness = _Harness(storage, container, controller, avatars, api);
  addTearDown(harness.dispose);
  await container.read(appControllerProvider.future);
  return harness;
}

void main() {
  test('late avatar results never restore a deleted local account', () async {
    final h = await _setup();
    final account = h.account;
    final refresh = h.controller.refreshAvatars();
    await h.controller.removeAccount(account);
    h.avatars.profile.complete(const SteamProfile(personaName: 'late-persona'));
    h.avatars.equipped.complete(const EquippedItems());
    await refresh;
    expect(h.container.read(appControllerProvider).value!.accounts, isEmpty);
    expect(h.storage.files.containsKey('$_id.maFile'), isFalse);
    expect(h.api.exchanges, 0);
  });

  test(
    'late results cannot overwrite a replacement import or its credentials',
    () async {
      final h = await _setup();
      final original = h.account;
      final refresh = h.controller.refreshAvatars();
      final replacement = SteamGuardAccount.fromJson(original.toJson())
        ..sharedSecret = 'replacement-shared'
        ..password = 'replacement-password'
        ..personaName = 'current-persona'
        ..session.accessToken = 'imported-access';
      await h.container
          .read(appControllerProvider)
          .value!
          .store
          .saveAccount(replacement, false);
      await h.controller.reload();
      h.avatars.profile.complete(
        const SteamProfile(personaName: 'late-persona'),
      );
      h.avatars.equipped.complete(const EquippedItems());
      await refresh;
      expect(h.account.personaName, 'current-persona');
      expect(h.account.sharedSecret, 'replacement-shared');
      expect(h.account.password, 'replacement-password');
      expect(h.account.session.accessToken, 'imported-access');
      expect(h.saved['password'], 'replacement-password');
      expect(h.saved['persona_name'], 'current-persona');
    },
  );

  test(
    'ordinary reload still merges cosmetics onto the equivalent live copy',
    () async {
      final h = await _setup();
      final oldInstance = h.account;
      final refresh = h.controller.refreshAvatars();
      await h.controller.reload();
      expect(identical(h.account, oldInstance), isFalse);
      h.avatars.profile.complete(
        const SteamProfile(personaName: 'fresh-persona'),
      );
      h.avatars.equipped.complete(const EquippedItems());
      await refresh;
      expect(h.account.personaName, 'fresh-persona');
      expect(h.saved['persona_name'], 'fresh-persona');
      expect(oldInstance.personaName, isNull);
    },
  );

  for (final invalidate in ['lock', 'delete', 'dispose']) {
    test('$invalidate before a late 401 prevents token exchange', () async {
      final h = await _setup();
      final refresh = h.controller.refreshAvatars();
      if (invalidate == 'lock') h.controller.setLocked();
      if (invalidate == 'delete') await h.controller.removeAccount(h.account);
      if (invalidate == 'dispose') h.dispose();
      h.avatars.equipped.completeError(FrameUnauthorized());
      h.avatars.profile.complete(
        const SteamProfile(personaName: 'late-persona'),
      );
      await refresh;
      expect(h.api.exchanges, 0);
      expect(h.avatars.tokens, ['old-access']);
      if (invalidate == 'lock') expect(h.saved['persona_name'], isNull);
    });
  }

  test(
    'locking during exchange prevents retry and mutation of retained objects',
    () async {
      final h = await _setup();
      final oldAccount = h.account;
      final refresh = h.controller.refreshAvatars();
      h.avatars.equipped.completeError(FrameUnauthorized());
      await h.api.started.future;
      h.controller.setLocked();
      h.api.complete();
      h.avatars.profile.complete(
        const SteamProfile(personaName: 'late-persona'),
      );
      await refresh;
      expect(h.avatars.tokens, ['old-access']);
      expect(oldAccount.session.accessToken, 'old-access');
      expect(oldAccount.session.refreshToken, 'old-refresh');
      expect(h.saved['Session']['AccessToken'], 'old-access');
      expect(h.saved['persona_name'], isNull);
    },
  );

  test(
    'successful renewal merges after reload without saving an obsolete object',
    () async {
      final h = await _setup();
      final oldAccount = h.account;
      final refresh = h.controller.refreshAvatars();
      h.avatars.equipped.completeError(FrameUnauthorized());
      await h.api.started.future;
      await h.controller.reload();
      h.api.complete();
      h.avatars.profile.complete(
        const SteamProfile(personaName: 'fresh-persona'),
      );
      await refresh;
      expect(h.avatars.tokens, ['old-access', 'replacement-access']);
      expect(h.account.session.accessToken, 'replacement-access');
      expect(h.account.session.refreshToken, 'replacement-refresh');
      expect(h.account.personaName, 'fresh-persona');
      expect(h.saved['Session']['AccessToken'], 'replacement-access');
      expect(h.saved['password'], 'old-password');
      expect(oldAccount.session.accessToken, 'old-access');
    },
  );
}
