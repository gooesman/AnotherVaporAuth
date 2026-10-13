import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/qr_approval_client.dart';
import '../services/auto_login.dart';
import '../services/desktop_steam_login.dart';
import '../services/steam_client_service.dart';
import '../services/steam_request_scope.dart';
import 'approve_login_screen.dart';
import 'login_screen.dart';

final steamClientServiceProvider = Provider<SteamClientService>(
  (ref) => SteamClientService(),
);

final desktopSteamLoginProvider = Provider<DesktopSteamLogin>((ref) {
  return DesktopSteamLogin(
    steam: ref.read(steamClientServiceProvider),
    approval: QrApprovalClient(ref.read(apiClientProvider)),
    ensureSession: (account) async {
      if (!AutoLogin.accessTokenStale(account.session.accessToken)) return true;
      final controller = ref.read(appControllerProvider.notifier);
      if (await ref.read(autoLoginProvider).ensureSession(account) !=
          AutoLoginOutcome.ok) {
        return false;
      }
      await controller.persistSession(account);
      return true;
    },
  );
});

/// Steam's remembered desktop accounts are separate from AVA's authenticator
/// accounts. Merely opening this screen never changes Steam's configuration.
class SteamClientScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount? initialAccount;

  const SteamClientScreen({super.key, this.initialAccount});

  @override
  ConsumerState<SteamClientScreen> createState() => _SteamClientScreenState();
}

class _SteamClientScreenState extends ConsumerState<SteamClientScreen>
    with WidgetsBindingObserver {
  String? _path;
  List<SteamClientAccount> _accounts = [];
  String? _selected;
  int? _selectedAvaSteamId;
  bool _loading = true;
  bool _switching = false;
  bool _launched = false;
  bool _missingInitial = false;
  SteamSwitchStage? _stage;
  DesktopLoginStage? _desktopStage;
  DesktopLoginOutcome? _desktopOutcome;
  bool _cancelDesktopLogin = false;
  SteamRequestScope? _desktopScope;
  SteamGuardAccount? _desktopAccount;
  Object? _error;
  String? _backupPath;
  SteamClientStatus? _status;
  bool _statusLoading = true;
  int _statusGeneration = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _cancelDesktopLogin = true;
    _desktopScope?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_loading &&
        !_switching &&
        ModalRoute.of(context)?.isCurrent == true) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    final generation = ++_statusGeneration;
    final path = _path;
    setState(() {
      _statusLoading = true;
      // A previous login must not remain labeled current during a new read.
      _status = null;
    });
    try {
      if (path == null) return;
      final status = await ref.read(steamClientServiceProvider).status(path);
      if (mounted && generation == _statusGeneration && !_switching) {
        setState(() => _status = status);
      }
    } catch (_) {
      // Reading status is advisory; a detection failure must not look stopped
      // or prevent QR login and the separate remembered-account operations.
    } finally {
      if (mounted && generation == _statusGeneration) {
        setState(() => _statusLoading = false);
      }
    }
  }

  Future<void> _load({String? selectedPath}) async {
    final generation = ++_loadGeneration;
    ++_statusGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _launched = false;
      _missingInitial = false;
      _desktopOutcome = null;
      _accounts = [];
      _status = null;
      _statusLoading = true;
    });
    try {
      final service = ref.read(steamClientServiceProvider);
      final settings = ref.read(settingsStoreProvider);
      final path =
          selectedPath ??
          _path ??
          await settings.loadSteamClientPath() ??
          await service.discoverPath();
      if (!mounted || generation != _loadGeneration) return;
      if (path == null) {
        setState(() {
          _path = null;
          _statusLoading = false;
        });
        return;
      }
      setState(() => _path = path);
      await _refreshStatus();
      if (!mounted || generation != _loadGeneration) return;
      final accounts = await service.listAccounts(path);
      if (selectedPath != null) await settings.saveSteamClientPath(path);
      if (!mounted || generation != _loadGeneration) return;
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
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = error;
          _statusLoading = false;
        });
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
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
    if (_loading || _switching || _path == null) return;
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
    if (confirmed != true || !mounted || _switching || _loading) return;
    ++_statusGeneration;
    setState(() {
      _switching = true;
      _launched = false;
      _error = null;
      _backupPath = null;
      _stage = SteamSwitchStage.stopping;
      _desktopOutcome = null;
      _status = null;
      _statusLoading = true;
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
      if (mounted) {
        setState(() => _switching = false);
        // Launch success does not prove Steam has signed in to the target.
        await _refreshStatus();
      }
    }
  }

  SteamGuardAccount? _currentAvaAccount(int steamId) => ref
      .read(appControllerProvider)
      .value
      ?.visibleAccounts
      .where((account) => account.steamId == steamId)
      .firstOrNull;

  Future<void> _approveLogin(int steamId) async {
    final account = _currentAvaAccount(steamId);
    if (_switching || account == null || !account.session.hasTokens) return;
    // This only opens the existing approval flow. Its confirmation screen
    // remains responsible for renewing tokens and approving the QR request.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApproveLoginScreen(initialAccount: account),
      ),
    );
    if (mounted) await _refreshStatus();
  }

  Future<void> _loginDesktop(int steamId) async {
    final account = _currentAvaAccount(steamId);
    final path = _path;
    if (_loading || _switching || path == null || account == null) return;
    ++_statusGeneration;
    final scope = _desktopScope = SteamRequestScope(
      timeout: const Duration(seconds: 20),
    );
    _desktopAccount = account;
    setState(() {
      _switching = true;
      _cancelDesktopLogin = false;
      _desktopOutcome = null;
      _desktopStage = DesktopLoginStage.preparing;
      _stage = null;
      _launched = false;
      _error = null;
      _backupPath = null;
      _status = null;
      _statusLoading = true;
    });
    try {
      final result = await ref
          .read(desktopSteamLoginProvider)
          .login(
            path: path,
            account: account,
            requestScope: scope,
            isCurrent: () {
              if (!mounted || _cancelDesktopLogin) return false;
              final data = ref.read(appControllerProvider).value;
              return data != null &&
                  !data.locked &&
                  data.visibleAccounts.any((item) => identical(item, account));
            },
            onProgress: (stage) {
              if (mounted) setState(() => _desktopStage = stage);
            },
          );
      if (mounted) {
        setState(() {
          _desktopOutcome = result.outcome;
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
      scope.cancel();
      _desktopScope = null;
      _desktopAccount = null;
      if (mounted) {
        setState(() {
          _switching = false;
          _desktopStage = null;
        });
        await _refreshStatus();
      }
    }
  }

  String _desktopStageText(AppLocalizations l) => switch (_desktopStage) {
    DesktopLoginStage.preparing => l.steamDesktopLoginPreparing,
    DesktopLoginStage.waitingQr => l.steamDesktopLoginWaitingQr,
    DesktopLoginStage.approving => l.steamDesktopLoginApproving,
    DesktopLoginStage.waitingAccount => l.steamDesktopLoginWaitingAccount,
    null => '',
  };

  String _desktopOutcomeText(AppLocalizations l) => switch (_desktopOutcome) {
    DesktopLoginOutcome.loggedIn => l.steamDesktopLoginComplete,
    DesktopLoginOutcome.manualRequired => l.steamDesktopLoginManual,
    DesktopLoginOutcome.approvedUnconfirmed => l.steamDesktopLoginUnconfirmed,
    DesktopLoginOutcome.cancelled => l.steamDesktopLoginCancelled,
    DesktopLoginOutcome.differentAccount => l.steamDesktopLoginWrongAccount,
    null => '',
  };

  bool _isCurrentAccount(SteamClientAccount account) =>
      !_statusLoading &&
      _status?.running == true &&
      _status?.activeSteamId == account.steamId;

  Widget _statusCard(AppLocalizations l, List<SteamGuardAccount> avaAccounts) {
    final status = _status;
    final activeId = status?.running == true ? status?.activeSteamId : null;
    final local = _accounts.where((a) => a.steamId == activeId).firstOrNull;
    final ava = avaAccounts
        .where((a) => '${a.steamId}' == activeId)
        .firstOrNull;
    final name = local != null
        ? local.personaName.isNotEmpty
              ? local.personaName
              : local.accountName
        : ava?.personaName?.isNotEmpty == true
        ? ava!.personaName
        : ava?.accountName;
    final label = _statusLoading
        ? l.steamClientStatusLoading
        : status == null
        ? l.steamClientStatusUnavailable
        : status.running
        ? l.steamClientRunning
        : l.steamClientStopped;
    return Card(
      key: const ValueKey('steam-client-status'),
      child: Padding(
        padding: context.rInsets(all: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                status?.running == true
                    ? Icons.desktop_windows_outlined
                    : Icons.power_settings_new,
                color: status?.running == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  if (!_statusLoading && status?.running == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      activeId == null
                          ? l.steamClientAccountUnknown
                          : l.steamClientCurrentAccount(
                              name?.isNotEmpty == true
                                  ? name!
                                  : 'SteamID: $activeId',
                            ),
                    ),
                    if (activeId != null && name?.isNotEmpty == true)
                      Text(
                        'SteamID: $activeId',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAvaLogin(int steamId) async {
    final account = _currentAvaAccount(steamId);
    if (_switching || account == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LoginScreen(reason: LoginReason.refresh, account: account),
      ),
    );
    // Read accounts from the provider again on return. A refresh may replace
    // an object, or the account may have been removed while this page was away.
    if (mounted) setState(() {});
  }

  Widget _qrLoginCard(
    AppLocalizations l,
    List<SteamGuardAccount> accounts,
    SteamGuardAccount? selected,
  ) => Card(
    child: Padding(
      padding: context.rInsets(all: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.steamDesktopLoginButton,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l.steamDesktopLoginHelp),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            Text(l.steamSwitchQrNoAccounts)
          else
            DropdownButtonFormField<int>(
              // Recreate the field when a matching local Steam account is
              // selected, so its displayed value follows that explicit choice.
              key: ValueKey('steam-client-ava-account-${selected?.steamId}'),
              initialValue: selected?.steamId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.steamSwitchQrAccount,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.steamId,
                    child: Text(
                      account.accountName ?? '${account.steamId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _switching
                  ? null
                  : (value) => setState(() {
                      _selectedAvaSteamId = value;
                      _desktopOutcome = null;
                    }),
            ),
          if (selected != null && !selected.session.hasTokens) ...[
            const SizedBox(height: 12),
            Text(l.steamSwitchQrNeedsSession),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('steam-client-ava-login'),
              onPressed: _switching
                  ? null
                  : () => _refreshAvaLogin(selected.steamId),
              icon: const Icon(Icons.login),
              label: Text(l.loginButton),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('steam-client-login'),
            onPressed:
                !_loading &&
                    !_switching &&
                    _path != null &&
                    selected != null &&
                    selected.session.hasTokens &&
                    (selected.sharedSecret?.isNotEmpty ?? false)
                ? () => _loginDesktop(selected.steamId)
                : null,
            icon: const Icon(Icons.login),
            label: Text(l.steamDesktopLoginButton),
          ),
          if (_desktopStage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_desktopStageText(l)),
                  ),
                ),
              ],
            ),
            TextButton(
              key: const ValueKey('steam-client-login-cancel'),
              onPressed: _cancelDesktopLogin
                  ? null
                  : () => setState(() {
                      _cancelDesktopLogin = true;
                      _desktopScope?.cancel();
                    }),
              child: Text(l.steamDesktopLoginCancel),
            ),
          ],
          if (_desktopOutcome != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_desktopOutcomeText(l))),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('steam-client-qr-login'),
            onPressed:
                !_switching && selected != null && selected.session.hasTokens
                ? () => _approveLogin(selected.steamId)
                : null,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l.steamSwitchQrTitle),
          ),
        ],
      ),
    ),
  );

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
      'session_expired' => l.sessionExpired,
      'identity_mismatch' => l.loginAccountMismatch,
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
    ref.listen(appControllerProvider, (_, next) {
      final account = _desktopAccount;
      if (account == null) return;
      final data = next.value;
      if (data == null ||
          data.locked ||
          !data.visibleAccounts.any((item) => identical(item, account))) {
        _cancelDesktopLogin = true;
        _desktopScope?.cancel();
      }
    });
    final l = AppLocalizations.of(context);
    final avaAccounts =
        ref.watch(appControllerProvider).value?.visibleAccounts ??
        const <SteamGuardAccount>[];
    final selectedAvaId = _selectedAvaSteamId ?? widget.initialAccount?.steamId;
    final selectedAva =
        avaAccounts.where((a) => a.steamId == selectedAvaId).firstOrNull ??
        avaAccounts.firstOrNull;
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
            _statusCard(l, avaAccounts),
            const SizedBox(height: 12),
            _qrLoginCard(l, avaAccounts, selectedAva),
            const SizedBox(height: 24),
            Text(
              l.steamSwitchButton,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
                  trailing: _isCurrentAccount(account)
                      ? Text(
                          l.steamClientCurrentBadge,
                          key: ValueKey(
                            'steam-client-current-${account.steamId}',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  onTap: _switching
                      ? null
                      : () => setState(() {
                          _selected = account.steamId;
                          final matchingAva = avaAccounts
                              .where((a) => '${a.steamId}' == account.steamId)
                              .firstOrNull;
                          if (matchingAva != null) {
                            _selectedAvaSteamId = matchingAva.steamId;
                          }
                          _error = null;
                          _launched = false;
                          _desktopOutcome = null;
                        }),
                ),
              ),
            const SizedBox(height: 16),
            if (_switching && _stage != null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_stageText(l))),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              key: const ValueKey('steam-client-switch'),
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
