import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../core/models/steam_guard_account.dart';
import '../services/steam_client_service.dart';

final steamClientServiceProvider = Provider<SteamClientService>(
  (ref) => SteamClientService(),
);

/// Steam's remembered desktop accounts are separate from AVA's authenticator
/// accounts. Merely opening this screen never changes Steam's configuration.
class SteamClientScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount? initialAccount;

  const SteamClientScreen({super.key, this.initialAccount});

  @override
  ConsumerState<SteamClientScreen> createState() => _SteamClientScreenState();
}

class _SteamClientScreenState extends ConsumerState<SteamClientScreen> {
  String? _path;
  List<SteamClientAccount> _accounts = [];
  String? _selected;
  bool _loading = true;
  bool _switching = false;
  bool _launched = false;
  bool _missingInitial = false;
  SteamSwitchStage? _stage;
  Object? _error;
  String? _backupPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selectedPath}) async {
    setState(() {
      _loading = true;
      _error = null;
      _launched = false;
      _missingInitial = false;
      _accounts = [];
    });
    try {
      final service = ref.read(steamClientServiceProvider);
      final settings = ref.read(settingsStoreProvider);
      final path =
          selectedPath ??
          _path ??
          await settings.loadSteamClientPath() ??
          await service.discoverPath();
      if (path == null) {
        if (mounted) setState(() => _path = null);
        return;
      }
      if (mounted) setState(() => _path = path);
      final accounts = await service.listAccounts(path);
      if (selectedPath != null) await settings.saveSteamClientPath(path);
      if (!mounted) return;
      final initial = widget.initialAccount;
      String? selected = _selected;
      if (!accounts.any((a) => a.steamId == selected)) selected = null;
      if (selected == null && initial != null) {
        for (final account in accounts) {
          // An existing SteamID is authoritative. Never fall back to a name
          // match that would silently select a different SteamID.
          final matches = initial.steamId != 0
              ? account.steamId == '${initial.steamId}'
              : (initial.accountName?.isNotEmpty ?? false) &&
                    account.accountName.toLowerCase() ==
                        initial.accountName!.toLowerCase();
          if (matches) {
            selected = account.steamId;
            break;
          }
        }
      }
      setState(() {
        _accounts = accounts;
        _selected = selected;
        _missingInitial = initial != null && selected == null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _browse() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Steam (steam.exe)', extensions: ['exe']),
        ],
      );
      if (file == null || !mounted) return;
      if (p.basename(file.path).toLowerCase() != 'steam.exe') {
        setState(() => _error = const FormatException('steam.exe'));
        return;
      }
      await _load(selectedPath: p.dirname(file.path));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _switch(SteamClientAccount account) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.steamSwitchTitle),
        content: Text(l.steamSwitchConfirm(account.accountName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.steamSwitchButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _switching = true;
      _launched = false;
      _error = null;
      _backupPath = null;
      _stage = SteamSwitchStage.stopping;
    });
    try {
      final result = await ref
          .read(steamClientServiceProvider)
          .switchAccount(
            path: _path!,
            steamId: account.steamId,
            onProgress: (stage) {
              if (mounted) setState(() => _stage = stage);
            },
          );
      if (mounted) {
        setState(() {
          _launched = true;
          _backupPath = result.backupPath;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          if (error is SteamClientException) _backupPath = error.backupPath;
        });
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  String _errorText(AppLocalizations l, Object error) {
    if (error is FormatException) return l.steamSwitchInvalidPath;
    if (error is! SteamClientException) return l.steamSwitchFailed;
    if (error.rollbackIncomplete) return l.steamSwitchRecoveryNeeded;
    return switch (error.code) {
      'invalid_path' => l.steamSwitchInvalidPath,
      'account_missing' || 'account_changed' => l.steamSwitchNoMatch,
      'credentials_not_saved' => l.steamSwitchNeedsLogin,
      'shutdown_failed' || 'shutdown_timeout' => l.steamSwitchCloseFailed,
      'busy' => l.steamSwitchBusy,
      'concurrent_change' => l.steamSwitchChanged,
      _ => l.steamSwitchFailed,
    };
  }

  String _stageText(AppLocalizations l) => switch (_stage) {
    SteamSwitchStage.stopping => l.steamSwitchStopping,
    SteamSwitchStage.backingUp => l.steamSwitchBackingUp,
    SteamSwitchStage.configuring => l.steamSwitchConfiguring,
    SteamSwitchStage.starting => l.steamSwitchStarting,
    SteamSwitchStage.restoring => l.steamSwitchRestoring,
    null => l.steamSwitchStopping,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    SteamClientAccount? selected;
    for (final account in _accounts) {
      if (account.steamId == _selected) selected = account;
    }
    final canSwitch =
        !_loading &&
        !_switching &&
        selected != null &&
        selected.rememberPassword;
    return PopScope(
      canPop: !_switching,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.steamSwitchTitle),
          automaticallyImplyLeading: !_switching,
        ),
        body: ListView(
          padding: context.rSafeInsets(all: 24),
          children: [
            Text(l.steamSwitchHelp),
            const SizedBox(height: 20),
            Text(
              l.steamSwitchPath,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SelectableText(_path ?? l.steamSwitchNotFound),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading || _switching ? null : _browse,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l.steamSwitchBrowse),
                ),
                OutlinedButton.icon(
                  onPressed: _loading || _switching ? null : () => _load(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l.commonRefresh),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading &&
                _error == null &&
                _path != null &&
                _accounts.isEmpty)
              Text(l.steamSwitchNoAccounts),
            if (_missingInitial) ...[
              Text(l.steamSwitchNoMatch),
              const SizedBox(height: 12),
            ],
            for (final account in _accounts)
              Card(
                child: ListTile(
                  enabled: !_switching,
                  selected: account.steamId == _selected,
                  leading: Icon(
                    account.steamId == _selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(
                    account.personaName.isEmpty
                        ? account.accountName
                        : account.personaName,
                  ),
                  subtitle: Text(
                    '${account.accountName}\n${account.steamId}'
                    '${account.rememberPassword ? '' : '\n${l.steamSwitchNeedsLogin}'}',
                  ),
                  isThreeLine: true,
                  onTap: _switching
                      ? null
                      : () => setState(() {
                          _selected = account.steamId;
                          _error = null;
                          _launched = false;
                        }),
                ),
              ),
            const SizedBox(height: 16),
            if (_switching) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_stageText(l))),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: canSwitch ? () => _switch(selected!) : null,
              icon: const Icon(Icons.switch_account),
              label: Text(l.steamSwitchButton),
            ),
            if (_launched) ...[
              const SizedBox(height: 16),
              Text(l.steamSwitchLaunched),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorText(l, _error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_backupPath != null) ...[
              const SizedBox(height: 12),
              Text(l.steamSwitchBackup),
              SelectableText(_backupPath!),
            ],
          ],
        ),
      ),
    );
  }
}
