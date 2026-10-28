import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/route_observer.dart';
import '../core/backup_codes.dart';
import '../core/models/steam_guard_account.dart';
import '../services/backup_codes_service.dart';
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';

final backupCodesServiceProvider = Provider<BackupCodesService>((ref) {
  final service = BackupCodesService();
  ref.onDispose(service.dispose);
  return service;
});

/// Also prevents a still-mounted route over the lock screen exposing codes.
final backupCodesLockedProvider = Provider<bool>(
  (ref) => ref.watch(
    appControllerProvider.select((state) => state.value?.locked ?? true),
  ),
);

/// Manual fallback only; never put a session credential in this browser URL.
final backupCodesLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class BackupCodesScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const BackupCodesScreen({super.key, required this.account});

  static final steamUrl = Uri.https(
    'store.steampowered.com',
    '/twofactor/emergency_codes',
  );

  @override
  ConsumerState<BackupCodesScreen> createState() => _BackupCodesScreenState();
}

class _BackupCodesScreenState extends ConsumerState<BackupCodesScreen>
    with WidgetsBindingObserver, RouteAware, SessionRetryState {
  final _smsCode = TextEditingController();
  BackupCodesChallenge? _challenge;
  List<String>? _codes;
  BackupCodesError? _error;
  CancelToken? _cancelToken;
  bool _busy = false;
  bool _opening = false;
  bool _openFailed = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Opening the page must not send an SMS or generate/revoke any codes.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) routeObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(BackupCodesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.account, widget.account)) _clear();
  }

  @override
  void didPushNext() => _clear();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    // Keep an acknowledged SMS challenge while the user reads their messages.
    // Returned backup codes and typed verification text never survive hiding.
    if (_codes != null || _smsCode.text.isNotEmpty) {
      setState(() {
        _codes = null;
        _smsCode.clear();
      });
    }
    if ((state == AppLifecycleState.inactive && _challenge != null) ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_busy) {
        _operation++;
        _cancelToken?.cancel();
        _cancelToken = null;
        setState(() {
          _busy = false;
          _error = BackupCodesError.network;
        });
      }
    }
  }

  @override
  void dispose() {
    _operation++;
    _cancelToken?.cancel();
    _codes = null;
    _challenge = null;
    _smsCode.clear();
    _smsCode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _clear() {
    _operation++;
    _cancelToken?.cancel();
    _cancelToken = null;
    setState(() {
      _busy = false;
      _challenge = null;
      _codes = null;
      _error = null;
      _smsCode.clear();
    });
  }

  Future<void> _request({bool generate = false}) async {
    if (_busy || ref.read(backupCodesLockedProvider)) return;
    final challenge = _challenge;
    if (generate && challenge == null) return;
    final smsCode = _smsCode.text;
    final operation = ++_operation;
    final steamId = widget.account.steamId;
    final cancelToken = _cancelToken = CancelToken();
    setState(() {
      _busy = true;
      _error = null;
      _codes = null;
      _smsCode.clear();
    });
    try {
      final service = ref.read(backupCodesServiceProvider);
      if (generate) {
        final codes = await service.generate(
          widget.account,
          challenge!,
          smsCode,
          cancelToken: cancelToken,
        );
        if (!_current(operation, steamId)) return;
        setState(() {
          _codes = codes;
          _challenge = null;
        });
      } else {
        final challenge = await service.requestSms(
          widget.account,
          cancelToken: cancelToken,
        );
        if (!_current(operation, steamId)) return;
        setState(() => _challenge = challenge);
      }
    } catch (error) {
      if (!_current(operation, steamId)) return;
      setState(() {
        // Never feed a raw exception/request/response to a generic error view.
        _error = error is BackupCodesException
            ? error.code
            : BackupCodesError.network;
        if (_error == BackupCodesError.authenticationRequired) {
          _challenge = null;
        }
      });
    } finally {
      if (_current(operation, steamId)) {
        setState(() {
          _busy = false;
          _cancelToken = null;
        });
      }
    }
  }

  bool _current(int operation, int steamId) =>
      mounted &&
      operation == _operation &&
      widget.account.steamId == steamId &&
      !ref.read(backupCodesLockedProvider);

  Future<void> _signIn() async {
    _clear();
    // Returning from login only resets the form. It must not resend an SMS or
    // repeat an earlier verification/generation action automatically.
    await signInThen(widget.account, _clear);
  }

  Future<void> _open() async {
    if (_opening || ref.read(backupCodesLockedProvider)) return;
    _clear();
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    var opened = false;
    try {
      opened = await ref.read(backupCodesLauncherProvider)(
        BackupCodesScreen.steamUrl,
      );
    } catch (_) {
      // A missing browser is independent from the native backup-code flow.
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _openFailed = !opened;
      });
    }
  }

  String _errorText(AppLocalizations l) => switch (_error) {
    BackupCodesError.authenticationRequired => l.sessionExpired,
    BackupCodesError.invalidCode => l.backupCodesInvalidSms,
    BackupCodesError.rateLimited => l.backupCodesRateLimited,
    BackupCodesError.phoneRequired => l.backupCodesPhoneRequired,
    BackupCodesError.invalidResponse => l.backupCodesUnexpectedResponse,
    _ => l.backupCodesRequestFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locked = ref.watch(backupCodesLockedProvider);
    ref.listen(backupCodesLockedProvider, (_, locked) {
      if (locked) _clear();
    });
    final name =
        widget.account.accountName ??
        widget.account.personaName ??
        '${widget.account.steamId}';
    return Scaffold(
      appBar: AppBar(title: Text(l.backupCodesTitle)),
      body: locked
          ? Center(child: Text(l.sessionExpired))
          : ListView(
              padding: context.rSafeInsets(all: 24),
              children: [
                AvaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.key_outlined, size: 32),
                      const SizedBox(height: 16),
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      SelectableText('SteamID ${widget.account.steamId}'),
                      const SizedBox(height: 16),
                      Text(l.backupCodesNativeIntro),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AvaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_codes != null) ...[
                        Text(
                          l.backupCodesReady,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            for (final code in _codes!)
                              SelectableText(
                                code,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontFamily: 'monospace'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(l.backupCodesKeepSafe),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(l.backupCodesClear),
                        ),
                      ] else if (_challenge != null) ...[
                        Text(l.backupCodesSmsPrompt),
                        if (_challenge!.phoneHint case final phone?) ...[
                          const SizedBox(height: 8),
                          Text(phone),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('backup-sms-code'),
                          controller: _smsCode,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLength: 64,
                          decoration: InputDecoration(
                            labelText: l.backupCodesSmsLabel,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _request(generate: true),
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(l.backupCodesGenerate),
                        ),
                        TextButton(
                          onPressed: _clear,
                          child: Text(l.commonCancel),
                        ),
                      ] else if (_error !=
                          BackupCodesError.authenticationRequired)
                        FilledButton.icon(
                          onPressed: _busy ? null : _request,
                          icon: const Icon(Icons.sms_outlined),
                          label: Text(l.backupCodesSendSms),
                        ),
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(liveRegion: true, child: Text(_errorText(l))),
                      ],
                      if (_error ==
                          BackupCodesError.authenticationRequired) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _signIn,
                          child: Text(l.loginButton),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  title: Text(l.backupCodesManualHelp),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Text(l.backupCodesAccountCheck),
                    TextButton.icon(
                      onPressed: _opening || _busy ? null : _open,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.backupCodesOpenSteam),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: BackupCodesScreen.steamUrl.toString(),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.copied)));
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(l.backupCodesCopyLink),
                    ),
                    if (_openFailed) Text(l.backupCodesOpenFailed),
                  ],
                ),
              ],
            ),
    );
  }
}
