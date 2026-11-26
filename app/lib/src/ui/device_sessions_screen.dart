// app/lib/src/ui/device_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/providers.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../core/models/device_session.dart';
import '../core/models/steam_guard_account.dart';
import 'pending/session_retry.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';
import 'error_text.dart';

/// Lists device sessions and revokes other devices' authorizations while
/// preserving the calling GooeSteamKit session and the Steam authenticator.
class DeviceSessionsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const DeviceSessionsScreen({super.key, required this.account});

  @override
  ConsumerState<DeviceSessionsScreen> createState() =>
      _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends ConsumerState<DeviceSessionsScreen>
    with SessionRetryState {
  DeviceSessionList? _list;
  bool _loading = true;
  bool _busy = false; // a revoke is in flight
  bool _revokingOthers = false;
  String? _error;
  bool _needsLogin = false;
  String? _listedAccessToken;
  String? _listedRefreshToken;

  // Missing/ambiguous requesting_token must never turn "other" into "all".
  bool get _canRevoke {
    final list = _list;
    return list != null &&
        widget.account.session.accessToken == _listedAccessToken &&
        widget.account.session.refreshToken == _listedRefreshToken &&
        list.requestingTokenId.isNotEmpty &&
        list.requestingTokenId != '0' &&
        list.devices.where(list.isCurrent).length == 1;
  }

  List<DeviceSession> _otherDevices(DeviceSessionList list) {
    final seen = <String>{};
    return list.devices
        .where((d) => !list.isCurrent(d) && seen.add(d.tokenId))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final client = ref.read(sessionsClientProvider);
      String? accessToken;
      String? refreshToken;
      // Auto-refresh the session and retry once on an expired token — same
      // pattern as the family / trade screens.
      final list = await fetchWithAutoRefresh<DeviceSessionList>(
        widget.account,
        () {
          // Account sessions can also change in the background. Bind the
          // requesting_token to the credentials actually used by this read.
          accessToken = widget.account.session.accessToken;
          refreshToken = widget.account.session.refreshToken;
          return client.enumerate(widget.account);
        },
        retryOnAnyError: false,
      );
      if (!mounted) return;
      setState(() {
        _list = list;
        _listedAccessToken = accessToken;
        _listedRefreshToken = refreshToken;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final needsLogin = isAuthError(e);
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _needsLogin = needsLogin;
        _error = needsLogin ? l.confNeedsLogin : fetchErrorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.deviceSessionsTitle),
        actions: [
          IconButton(
            tooltip: l.confirmationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _busy ? null : _load,
          ),
        ],
      ),
      body: ScanlineOverlay(child: _body(l, t)),
    );
  }

  Widget _body(AppLocalizations l, AvaTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: sessionErrorBody(
          l,
          t,
          error: _error!,
          needsLogin: _needsLogin,
          onSignIn: () => signInThen(widget.account, _load),
          onRetry: _load,
        ),
      );
    }
    final list = _list!;
    if (list.devices.isEmpty) {
      return Center(
        child: Padding(
          padding: context.rInsets(all: 24),
          child: Text(l.deviceSessionsEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: context.rSafeInsets(all: 16),
      children: [
        OutlinedButton.icon(
          onPressed: _busy || !_canRevoke || _otherDevices(list).isEmpty
              ? null
              : () => _revokeOthers(l),
          icon: _revokingOthers
              ? SizedBox.square(
                  dimension: context.r(18),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(
            _revokingOthers
                ? l.deviceRevokeOthersBusy
                : l.deviceRevokeOthersAction,
          ),
        ),
        if (!_canRevoke || _otherDevices(list).isEmpty)
          Padding(
            padding: context.rInsets(top: 8, bottom: 8),
            child: Text(
              !_canRevoke
                  ? l.deviceRevokeOthersCurrentUnknown
                  : l.deviceRevokeOthersNone,
              style: TextStyle(color: t.muted),
            ),
          ),
        SizedBox(height: context.r(8)),
        for (final d in list.devices)
          Padding(
            padding: context.rInsets(bottom: 8),
            child: _deviceCard(l, t, d, list.isCurrent(d)),
          ),
      ],
    );
  }

  /// Confirms, then remotely signs [d] out and refreshes. Never called for the
  /// current device (the card hides revoke for it — self-revoke would sign the
  /// app out of the account).
  Future<void> _revoke(AppLocalizations l, AvaTokens t, DeviceSession d) async {
    if (_busy || _loading || !_canRevoke || _list!.isCurrent(d)) return;
    setState(() => _busy = true);
    final name = d.description.isNotEmpty ? d.description : l.deviceUnnamed;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l.deviceRevokeConfirm(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.bad,
                foregroundColor: const Color(0xFF06060F),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.deviceRevokeAction),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (!_canRevoke) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.deviceRevokeOthersCurrentUnknown)),
        );
        await _load();
        return;
      }
      try {
        // A lost response may already have revoked the device. Never replay
        // this write through fetchWithAutoRefresh; only re-read the list.
        await ref.read(sessionsClientProvider).revoke(widget.account, d);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l.deviceRevokeDone(name))),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(
            '${l.deviceRevokeOthersPartial(0, 1)}\n$name: ${describeError(l, e)}',
          )),
        );
      }
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers(AppLocalizations l) async {
    if (_busy || _loading || !_canRevoke) return;
    // Only the devices reviewed in this confirmation are authorized targets.
    final targets = _otherDevices(_list!);
    if (targets.isEmpty) return;
    final client = ref.read(sessionsClientProvider);
    setState(() => _busy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.deviceRevokeOthersAction),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.deviceRevokeOthersConfirm(targets.length)),
              const SizedBox(height: 12),
              for (final d in targets)
                Text(
                  d.description.isNotEmpty ? d.description : l.deviceUnnamed,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.deviceRevokeOthersAction),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (!_canRevoke) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.deviceRevokeOthersCurrentUnknown)),
        );
        await _load();
        return;
      }
      setState(() => _revokingOthers = true);
      final batchAccessToken = _listedAccessToken;
      final batchRefreshToken = _listedRefreshToken;
      final batchRequestingToken = _list!.requestingTokenId;
      final attempted = <String>{};
      final errors = <String, String>{};
      // One request per confirmed token, in sequence. A timeout is an
      // unconfirmed result, never permission to repeat a non-idempotent write.
      for (final d in targets) {
        if (!_canRevoke) {
          // Stop using the old exclusion list after a background sign-in.
          for (final remaining
              in targets.where((d) => !attempted.contains(d.tokenId))) {
            errors[remaining.tokenId] = l.deviceRevokeOthersCurrentUnknown;
          }
          break;
        }
        attempted.add(d.tokenId);
        try {
          await client.revoke(widget.account, d, permanent: true);
        } catch (e) {
          errors[d.tokenId] = describeError(l, e);
        }
      }
      if (!mounted) return;
      setState(() => _revokingOthers = false);
      await _load();
      if (!mounted) return;
      // A successful write response alone cannot prove removal. Only a fresh
      // enumeration of the same current session can confirm the targets gone.
      final verified =
          _error == null &&
          _canRevoke &&
          _listedAccessToken == batchAccessToken &&
          _listedRefreshToken == batchRefreshToken &&
          _list!.requestingTokenId == batchRequestingToken;
      final remaining = _list!.devices.map((d) => d.tokenId).toSet();
      var done = 0;
      final failures = <String>[];
      for (final d in targets) {
        if (verified &&
            attempted.contains(d.tokenId) &&
            !remaining.contains(d.tokenId)) {
          done++;
        } else {
          final name = d.description.isNotEmpty
              ? d.description
              : l.deviceUnnamed;
          failures.add(
            '$name: ${errors[d.tokenId] ?? l.deviceRevokeOthersVerifyPending}',
          );
        }
      }
      if (failures.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.deviceRevokeOthersDone(done))));
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deviceRevokeOthersAction),
            scrollable: true,
            content: Text(
              [
                l.deviceRevokeOthersPartial(done, failures.length),
                ...failures,
              ].join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonClose),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _revokingOthers = false;
        });
      }
    }
  }

  Widget _deviceCard(
      AppLocalizations l, AvaTokens t, DeviceSession d, bool current) {
    final name = d.description.isNotEmpty ? d.description : l.deviceUnnamed;
    final loc = d.lastSeen?.locationLabel ?? '';
    final age = _age(l, d.timeUpdated);
    final sub = [
      _platformLabel(l, d.platformType),
      if (loc.isNotEmpty) loc,
      if (age.isNotEmpty) l.deviceLastSeen(age),
    ].join(' · ');
    return AvaPanel(
      padding: context.rInsets(all: 12),
      child: Row(
        children: [
          Icon(_platformIcon(d.platformType),
              size: context.r(20), color: current ? t.accent : t.muted),
          SizedBox(width: context.r(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text, fontSize: context.r(13))),
                    ),
                    if (current) ...[
                      SizedBox(width: context.r(6)),
                      Text(l.deviceCurrent,
                          style: TextStyle(
                              color: t.accent, fontSize: context.r(11))),
                    ],
                    if (!d.loggedIn) ...[
                      SizedBox(width: context.r(6)),
                      Text(l.deviceSignedOut,
                          style: TextStyle(
                              color: t.muted, fontSize: context.r(11))),
                    ],
                  ],
                ),
                SizedBox(height: context.r(2)),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.muted, fontSize: context.r(11))),
              ],
            ),
          ),
          // Revoke is offered for every device except this one — signing the
          // current device out would log the app off the account.
          if (!current)
            IconButton(
              tooltip: l.deviceRevokeAction,
              icon: Icon(Icons.logout, size: context.r(18), color: t.bad),
              onPressed: _busy || !_canRevoke ? null : () => _revoke(l, t, d),
            ),
        ],
      ),
    );
  }

  String _platformLabel(AppLocalizations l, int type) => switch (type) {
        1 => l.devicePlatformSteam,
        2 => l.devicePlatformWeb,
        3 => l.devicePlatformMobile,
        _ => l.devicePlatformUnknown,
      };

  IconData _platformIcon(int type) => switch (type) {
        1 => Icons.desktop_windows_outlined,
        2 => Icons.public,
        3 => Icons.smartphone_outlined,
        _ => Icons.devices_other_outlined,
      };

  /// Relative age of the last activity ("3d" / "5h" / "2m"), localized as a
  /// short suffix. Empty when unknown.
  String _age(AppLocalizations l, int epoch) {
    if (epoch == 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
    if (d.inDays > 0) return l.deviceAgeDays(d.inDays);
    if (d.inHours > 0) return l.deviceAgeHours(d.inHours);
    if (d.inMinutes > 0) return l.deviceAgeMinutes(d.inMinutes);
    return l.deviceAgeNow;
  }
}
