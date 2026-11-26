import 'dart:convert';
import 'dart:io';

import 'package:ava/src/app/providers.dart';
import 'package:ava/src/app/sync_providers.dart';
import 'package:ava/src/core/models/steam_guard_account.dart';
import 'package:ava/src/core/sync/sync_payload.dart';
import 'package:ava/src/services/account_store.dart';
import 'package:ava/src/services/avatar_service.dart';
import 'package:ava/src/services/storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = 76561198000000123;
final _port = Provider<AppAccountsPort>(AppAccountsPort.new);

Map<String, dynamic> _initial() => {
  'shared_secret': base64Encode(List.generate(20, (i) => i)),
  'identity_secret': 'synthetic-identity',
  'account_name': 'synthetic-account',
  'password': 'synthetic-local-password',
  'persona_name': 'Local nickname',
  'avatar_url': 'https://example.invalid/avatar',
  'avatar_frame_url': 'https://example.invalid/frame',
  'animated_avatar_url': 'https://example.invalid/animated',
  'Session': {
    'SteamID': _id,
    'AccessToken': 'synthetic-local-access',
    'RefreshToken': 'synthetic-local-refresh',
    'SteamLoginSecure': 'synthetic-local-cookie',
  },
};

class _Storage extends MemoryStorageProvider {
  _Storage(super.directory);
  bool failWrites = false;
  @override
  Future<void> writeFile(String filename, String contents) async {
    if (failWrites) throw const FileSystemException('synthetic write failure');
    await super.writeFile(filename, contents);
  }
}

class _Avatars implements AvatarService {
  int calls = 0;
  @override
  Future<SteamProfile> fetchProfile(int steamId) async {
    calls++;
    return const SteamProfile();
  }

  @override
  Future<EquippedItems> fetchEquippedItems(int steamId, String? token) async =>
      const EquippedItems();
}

void main() {
  late _Storage storage;
  late _Avatars avatars;
  late ProviderContainer container;
  late AppAccountsPort port;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('ava-sync-apply-');
    storage = _Storage('${directory.path}/maFiles');
    avatars = _Avatars();
    container = ProviderContainer(
      overrides: [
        storageProvider.overrideWithValue(storage),
        avatarServiceProvider.overrideWithValue(avatars),
        timeAlignerProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await directory.delete(recursive: true);
    });
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .importMaFile(jsonEncode(_initial()));
    await Future<void>.delayed(Duration.zero);
    port = container.read(_port);
  });

  Future<SteamGuardAccount> persisted() async =>
      (await container
              .read(appControllerProvider)
              .requireValue
              .store
              .getAllAccounts())
          .single;

  for (final cleared in <String?>[null, '']) {
    test(
      'real sync port applies explicit ${cleared == null ? 'null' : 'empty'} fields and retains local session',
      () async {
        final before = port.snapshot()!.single;
        final avatarCalls = avatars.calls;
        final remote = {
          'Session': {
            'SteamID': _id,
            'AccessToken': 'other-device-token-must-not-be-imported',
          },
          'password': cleared,
          'persona_name': cleared,
          'avatar_url': cleared,
          'avatar_frame_url': cleared,
          'animated_avatar_url': cleared,
        };
        await port.applyRemote(remote);
        final saved = await persisted();
        for (final key in remote.keys.where((key) => key != 'Session')) {
          expect(saved.toJson()[key], cleared, reason: key);
          expect(port.snapshot()!.single.toJson()[key], cleared, reason: key);
        }
        expect(saved.sharedSecret, before.sharedSecret);
        expect(saved.session.toJson(), before.session.toJson());
        expect(avatars.calls, avatarCalls);
        expect(
          syncPayloadJson(saved, includePassword: true)['password'],
          cleared,
        );
        // The previously displayed object was not mutated before persistence.
        expect(before.password, 'synthetic-local-password');
      },
    );
  }

  test(
    'old remote payload omissions preserve fields while supplied fields win',
    () async {
      final before = port.snapshot()!.single.toJson();
      await port.applyRemote({
        'Session': {'SteamID': _id},
        'persona_name': 'Remote nickname',
      });
      final saved = (await persisted()).toJson();
      expect(saved, {...before, 'persona_name': 'Remote nickname'});
      expect(port.snapshot()!.single.personaName, 'Remote nickname');
    },
  );

  test(
    'failed sync save leaves live account and stored payload unchanged',
    () async {
      final before = port.snapshot()!.single;
      final oldPayload = before.toJson();
      final files = Map<String, String>.from(storage.files);
      storage.failWrites = true;
      await expectLater(
        port.applyRemote({
          'Session': {'SteamID': _id},
          'password': null,
          'persona_name': null,
        }),
        throwsA(isA<MaFileImportException>()),
      );
      expect(storage.files, files);
      expect(before.toJson(), oldPayload);
      expect(identical(port.snapshot()!.single, before), isTrue);
      expect((await persisted()).toJson(), oldPayload);
    },
  );

  test(
    'new sync account never adopts another device session credentials',
    () async {
      await port.applyRemote({
        ..._initial(),
        'Session': {
          'SteamID': _id + 1,
          'AccessToken': 'synthetic-remote-access',
          'RefreshToken': 'synthetic-remote-refresh',
          'SteamLoginSecure': 'synthetic-remote-cookie',
        },
      });
      final added = port.snapshot()!.singleWhere((a) => a.steamId == _id + 1);
      expect(added.session.toJson(), {'SteamID': _id + 1});
      expect(added.password, 'synthetic-local-password');
    },
  );

  test(
    'manual maFile import still keeps cached enrichment and saved password',
    () async {
      await container
          .read(appControllerProvider.notifier)
          .importMaFile(
            jsonEncode({
              'Session': {'SteamID': _id},
              'password': '',
              'persona_name': null,
              'avatar_url': null,
            }),
          );
      final saved = await persisted();
      expect(saved.password, 'synthetic-local-password');
      expect(saved.personaName, 'Local nickname');
      expect(saved.avatarUrl, 'https://example.invalid/avatar');
      expect(saved.session.accessToken, 'synthetic-local-access');
    },
  );
}
