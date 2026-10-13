import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/steam_guard_account.dart';
import '../core/protocol/qr_approval_client.dart';
import '../services/auto_login.dart';
import '../services/screen_qr_capture.dart';
import 'login_screen.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';
import 'error_text.dart';

final screenQrCaptureProvider = Provider<ScreenQrCapture>(
  (ref) => const ScreenQrCapture(),
);

bool _accountStillAvailable(WidgetRef ref, SteamGuardAccount account, int id) {
  final data = ref.read(appControllerProvider).value;
  return data != null &&
      !data.locked &&
      account.steamId == id &&
      data.visibleAccounts.any((a) => identical(a, account));
}

/// The approval endpoints authenticate with the access token alone, and Steam
/// access tokens are short-lived (~24 h JWTs) — anyone scanning a QR a day
/// after their last session refresh would fail. Renew a stale token up front
/// via the same fallback chain as checkPendingLogins (refresh token, then
/// headless password re-login). Returns false when no usable session could be
/// established; callers should send the user to re-login.
Future<bool> _ensureUsableSession(
  WidgetRef ref,
  SteamGuardAccount account,
) async {
  if (!AutoLogin.accessTokenStale(account.session.accessToken)) return true;
  // Captured before the await: the renewed (possibly rotated) tokens must be
  // persisted even if the calling widget is gone by the time it returns.
  final controller = ref.read(appControllerProvider.notifier);
  try {
    final outcome = await ref.read(autoLoginProvider).ensureSession(account);
    if (outcome != AutoLoginOutcome.ok) return false;
    // Persist the renewed tokens so the next launch skips the dance.
    await controller.persistSession(account);
    return true;
  } catch (_) {
    return false;
  }
}

/// Streamlined entry for the home screen's top-right scan button: on touch
/// devices, jump straight into the camera for [account] and confirm from a
/// dialog showing where the sign-in comes from; desktop (no camera) falls
/// back to the full screen with the paste field, preselected to [account].
Future<void> quickApproveLogin(
  BuildContext context,
  WidgetRef ref,
  SteamGuardAccount account,
) async {
  final l = AppLocalizations.of(context);
  if (!(Platform.isAndroid || Platform.isIOS)) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApproveLoginScreen(initialAccount: account),
      ),
    );
    return;
  }
  if (!account.session.hasTokens) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.sessionExpired)));
    return;
  }
  final code = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
  if (code == null || !context.mounted) return;
  final challenge = QrChallenge.tryParse(code);
  if (challenge == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.approveBadCode)));
    return;
  }
  final accountId = account.steamId;
  if (!await _ensureUsableSession(ref, account)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.sessionExpired)));
    }
    return;
  }
  if (!context.mounted) return;
  if (!_accountStillAvailable(ref, account, accountId) ||
      !qrApprovalIdentityMatches(account)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.loginAccountMismatch)));
    return;
  }
  final client = QrApprovalClient(ref.read(apiClientProvider));
  // A scanned challenge must still have verifiable, current session details.
  AuthSessionInfo? info;
  try {
    info = await client.sessionInfo(account, challenge.clientId);
  } catch (_) {}
  if (!context.mounted) return;
  if (info == null || info.version != challenge.version) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.approveSessionUnavailable)));
    return;
  }
  final approve = await _confirmApproveDialog(context, account, info);
  if (approve == null || !context.mounted) return;
  if (!_accountStillAvailable(ref, account, accountId) ||
      !qrApprovalIdentityMatches(account)) {
    return;
  }
  try {
    final ok = await client.respond(account, challenge, approve: approve);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? (approve ? l.approveSuccess : l.approveRejected) : l.commonError,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l.commonError}: ${describeError(l, e)}')),
    );
  }
}

Future<bool?> _confirmApproveDialog(
  BuildContext context,
  SteamGuardAccount account,
  AuthSessionInfo? info,
) {
  final l = AppLocalizations.of(context);
  final t = Theme.of(context).extension<AvaTokens>()!;
  Widget detail(String text) => Padding(
    padding: EdgeInsets.only(top: context.r(3)),
    child: Text(
      text,
      style: TextStyle(color: t.muted, fontSize: context.r(13)),
    ),
  );
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.approveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.accountName ?? '${account.steamId}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: context.r(15),
            ),
          ),
          detail('SteamID: ${account.steamId}'),
          SizedBox(height: context.r(6)),
          if (info != null) ...[
            if (info.location.isNotEmpty)
              detail('${l.approveLocation}: ${info.location}'),
            if (info.ip.isNotEmpty) detail('IP: ${info.ip}'),
            if (info.deviceName.isNotEmpty)
              detail('${l.approveDevice}: ${info.deviceName}'),
          ],
          SizedBox(height: context.r(12)),
          Text(
            l.approveWarnStranger,
            style: TextStyle(color: t.warn, fontSize: context.r(12.5)),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.approveReject),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.approveButton),
        ),
      ],
    ),
  );
}

class ApproveLoginScreen extends ConsumerStatefulWidget {
  /// Preselects this account in the dropdown (if it has a live session).
  final SteamGuardAccount? initialAccount;
  const ApproveLoginScreen({super.key, this.initialAccount});

  @override
  ConsumerState<ApproveLoginScreen> createState() => _ApproveLoginScreenState();
}

class _ApproveLoginScreenState extends ConsumerState<ApproveLoginScreen> {
  final _link = TextEditingController();
  SteamGuardAccount? _account;
  bool _initializedAccount = false;
  bool _busy = false;
  String? _message;

  bool get _canScan => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _link.text = code ?? '';
    });
    if (code != null) await _respond(true);
  }

  Future<void> _scanScreen() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final account = _account;
    if (account == null) return;
    final accountId = account.steamId;
    setState(() {
      _busy = true;
      _message = null;
      _link.clear();
    });
    String? code;
    try {
      code = await ref
          .read(screenQrCaptureProvider)
          .capture(
            instruction: l.approveScreenInstruction,
            accent: Theme.of(context).extension<AvaTokens>()!.accent.toARGB32(),
          );
      if (!mounted) return;
      if (!_accountStillAvailable(ref, account, accountId)) {
        setState(() => _message = l.sessionExpired);
        return;
      }
      if (code != null && QrChallenge.tryParse(code) == null) {
        setState(() => _message = l.approveBadCode);
        return;
      }
      if (code != null) _link.text = code;
    } on ScreenQrNotFound {
      if (mounted) setState(() => _message = l.approveScreenNoCode);
      return;
    } catch (error) {
      final failure = ScreenQrFailure.fromError(error);
      if (mounted) {
        setState(
          () => _message = switch (failure.code) {
            'capture_busy' => l.approveScreenBusy,
            'display_changed' => l.approveScreenDisplayChanged,
            'region_too_large' => l.approveScreenRegionTooLarge,
            _ => l.approveScreenFailedDetail(failure.diagnostic),
          },
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (code != null && mounted) await _respond(true);
  }

  Future<void> _signIn() async {
    final account = _account;
    if (_busy || account == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LoginScreen(reason: LoginReason.refresh, account: account),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _respond(bool approve) async {
    final l = AppLocalizations.of(context);
    final account = _account;
    if (_busy || account == null) return;
    final accountId = account.steamId;
    final challenge = QrChallenge.tryParse(_link.text);
    if (challenge == null) {
      setState(() => _message = l.approveBadCode);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!await _ensureUsableSession(ref, account)) {
        if (mounted) setState(() => _message = l.sessionExpired);
        return;
      }
      if (!mounted) return;
      if (!_accountStillAvailable(ref, account, accountId) ||
          !qrApprovalIdentityMatches(account)) {
        setState(() => _message = l.loginAccountMismatch);
        return;
      }
      final client = QrApprovalClient(ref.read(apiClientProvider));
      var finalApprove = approve;
      if (approve) {
        AuthSessionInfo? info;
        try {
          info = await client.sessionInfo(account, challenge.clientId);
        } catch (_) {}
        if (!mounted) return;
        if (info == null || info.version != challenge.version) {
          setState(() => _message = l.approveSessionUnavailable);
          return;
        }
        final confirmed = await _confirmApproveDialog(context, account, info);
        if (!mounted || confirmed == null) return;
        finalApprove = confirmed;
      }
      if (!_accountStillAvailable(ref, account, accountId) ||
          !qrApprovalIdentityMatches(account)) {
        if (mounted) setState(() => _message = l.loginAccountMismatch);
        return;
      }
      final ok = await client.respond(
        account,
        challenge,
        approve: finalApprove,
      );
      if (!mounted) return;
      setState(() {
        _message = ok
            ? (finalApprove ? l.approveSuccess : l.approveRejected)
            : l.commonError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '${l.commonError}: ${describeError(l, e)}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = ref.watch(appControllerProvider);
    final accounts =
        (appState.value?.visibleAccounts ?? const <SteamGuardAccount>[])
            .toList();
    final selectedId = _initializedAccount
        ? _account?.steamId
        : widget.initialAccount?.steamId;
    _account = accounts.where((a) => a.steamId == selectedId).firstOrNull;
    if (!_initializedAccount && widget.initialAccount == null) {
      _account = accounts.firstOrNull;
    }
    if (appState.hasValue) _initializedAccount = true;
    final hasSession = _account?.session.hasTokens ?? false;
    final screenCapture = ref.watch(screenQrCaptureProvider);

    final t = Theme.of(context).extension<AvaTokens>()!;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.approveTitle)),
        body: ScanlineOverlay(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: context.rSafeInsets(all: 24),
                child: AvaPanel(
                  padding: context.rInsets(all: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: context.r(40),
                        color: t.accent,
                      ),
                      SizedBox(height: context.r(14)),
                      if (accounts.isEmpty)
                        Text(l.steamSwitchQrNoAccounts)
                      else
                        DropdownButtonFormField<SteamGuardAccount>(
                          key: ValueKey(_account),
                          initialValue: _account,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l.steamSwitchQrAccount,
                          ),
                          items: accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    a.accountName ?? '${a.steamId}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  _account = v;
                                  _message = null;
                                  _link.clear();
                                }),
                        ),
                      if (_account != null && !hasSession) ...[
                        SizedBox(height: context.r(12)),
                        Text(l.steamSwitchQrNeedsSession),
                        TextButton(
                          onPressed: _busy ? null : _signIn,
                          child: Text(l.loginButton),
                        ),
                      ],
                      SizedBox(height: context.r(16)),
                      Text(
                        screenCapture.available
                            ? l.approveScreenHelp
                            : l.approveScanPrompt,
                      ),
                      SizedBox(height: context.r(8)),
                      if (_canScan)
                        OutlinedButton.icon(
                          onPressed: _busy || !hasSession ? null : _scan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(l.approveTitle),
                        ),
                      if (screenCapture.available)
                        FilledButton.icon(
                          key: const ValueKey('screen-qr-capture'),
                          onPressed: _busy || !hasSession ? null : _scanScreen,
                          icon: const Icon(Icons.crop_free),
                          label: Text(l.approveScreenSelect),
                        ),
                      SizedBox(height: context.r(8)),
                      TextField(
                        enabled: !_busy && hasSession,
                        controller: _link,
                        decoration: InputDecoration(
                          labelText: l.approvePastePrompt,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: context.r(16)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy || !hasSession
                                  ? null
                                  : () => _respond(false),
                              child: Text(l.approveReject),
                            ),
                          ),
                          SizedBox(width: context.r(8)),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy || !hasSession
                                  ? null
                                  : () => _respond(true),
                              child: Text(l.approveButton),
                            ),
                          ),
                        ],
                      ),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_message != null) ...[
                        SizedBox(height: context.r(16)),
                        Text(_message!, textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  // MobileScanner keeps re-detecting the same code every frame while the pop
  // animation plays; without this latch each extra detection pops another
  // route *below* the scanner, leaving a blank Navigator.
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // "Sign in with QR" — the user came here to scan; "approve" only makes
      // sense on the confirm step that follows.
      appBar: AppBar(title: Text(AppLocalizations.of(context).loginViaQr)),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final code = capture.barcodes
              .map((b) => b.rawValue)
              .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
          if (code == null) return;
          _done = true;
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}
