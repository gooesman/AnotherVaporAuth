import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../app/responsive.dart';
import '../app/steam_acceleration_providers.dart';
import '../app/theme.dart';
import '../services/steam_acceleration.dart';
import '../services/steam_connectivity.dart';
import 'widgets/ava_panel.dart';
import 'widgets/scanline_overlay.dart';
import 'widgets/steam_acceleration_status.dart';

/// This page never reads back a subscription URL or presents a raw exception.
/// Only the service's public, credential-free status is rendered.
class SteamAccelerationScreen extends ConsumerStatefulWidget {
  const SteamAccelerationScreen({super.key});

  @override
  ConsumerState<SteamAccelerationScreen> createState() =>
      _SteamAccelerationScreenState();
}

class _SteamAccelerationScreenState
    extends ConsumerState<SteamAccelerationScreen> {
  late final SteamAccelerationService _service;
  bool _working = false;
  bool _dialogOpen = false;
  bool _unexpectedError = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(steamAccelerationServiceProvider);
    if (_service.supported) {
      unawaited(
        _run(() async {
          await _service.load();
          await _service.checkEnvironment();
        }),
      );
    }
  }

  bool get _busy =>
      _working ||
      (!_unexpectedError &&
          switch (_service.state.phase) {
            SteamAccelerationPhase.loadingSubscription ||
            SteamAccelerationPhase.starting => true,
            _ => false,
          });

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() {
      _working = true;
      _unexpectedError = false;
    });
    try {
      await operation();
    } catch (_) {
      // The service normally reports an enum in its state. A defensive
      // fallback must not expose a URL through an exception or debug log.
      if (mounted) setState(() => _unexpectedError = true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editSubscription() async {
    if (_busy || _dialogOpen) return;
    _dialogOpen = true;
    final l = AppLocalizations.of(context);
    final configured = _service.state.configured;
    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        builder: (_) => _SubscriptionDialog(configured: configured),
      );
    } finally {
      _dialogOpen = false;
    }
    if (!mounted || result == null) return;
    final url = result;
    await _run(
      () => _service.configure(
        subscriptionUrl: url,
        autoStart: _service.state.autoStart,
      ),
    );
    if (!mounted) return;
    // No request is sent merely by saving the link. Synchronization is a
    // separate, explicit action, as explained in the dialog.
    if (_service.state.error == null && !_unexpectedError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.steamAccelerationConfigured)));
    }
  }

  Future<void> _clear() async {
    if (_busy || _dialogOpen) return;
    _dialogOpen = true;
    final l = AppLocalizations.of(context);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.steamAccelerationClear),
          content: Text(l.steamAccelerationClearConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('steam-acceleration-confirm-clear'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.commonDelete),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
    if (!mounted || confirmed != true) return;
    await _run(_service.clearConfiguration);
  }

  String _phaseLabel(AppLocalizations l, SteamAccelerationPhase phase) =>
      switch (phase) {
        SteamAccelerationPhase.off => l.steamAccelerationOff,
        SteamAccelerationPhase.loadingSubscription =>
          l.steamAccelerationLoading,
        SteamAccelerationPhase.starting => l.steamAccelerationStarting,
        SteamAccelerationPhase.running => l.steamAccelerationRunning,
        SteamAccelerationPhase.pausedExternal => l.steamAccelerationPaused,
        SteamAccelerationPhase.error => l.steamAccelerationFailed,
      };

  String _errorLabel(AppLocalizations l, SteamAccelerationError error) =>
      switch (error) {
        SteamAccelerationError.invalidSubscription =>
          l.steamAccelerationInvalidSubscription,
        SteamAccelerationError.network => l.steamAccelerationNetworkError,
        SteamAccelerationError.unsupportedSubscription =>
          l.steamAccelerationUnsupportedSubscription,
        SteamAccelerationError.storage => l.steamAccelerationStorageError,
        SteamAccelerationError.coreUnavailable =>
          l.steamAccelerationCoreUnavailable,
        SteamAccelerationError.coreIntegrity =>
          l.steamAccelerationCoreIntegrity,
        SteamAccelerationError.startFailed => l.steamAccelerationStartFailed,
        SteamAccelerationError.unsupportedPlatform =>
          l.steamAccelerationUnsupported,
        SteamAccelerationError.environmentUnknown =>
          l.steamAccelerationDetectionUnavailable,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return Scaffold(
      appBar: AppBar(title: Text(l.steamAccelerationTitle)),
      body: ScanlineOverlay(
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final state = _service.state;
            final running = state.phase == SteamAccelerationPhase.running;
            final environment = state.environment;
            final supported = _service.supported;
            final hasSelection = state.nodes.any(
              (node) => node.id == state.selectedNodeId,
            );
            final canStart =
                supported &&
                !_busy &&
                state.configured &&
                hasSelection &&
                !environment.hasExternal;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: context.rSafeInsets(all: 20),
                  children: [
                    AvaPanel(
                      emphasized: running,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.speed_outlined, color: t.accent, size: 30),
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              supported
                                  ? (_unexpectedError
                                        ? l.steamAccelerationFailed
                                        : _phaseLabel(l, state.phase))
                                  : l.steamAccelerationUnsupported,
                              key: const ValueKey('steam-acceleration-status'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(l.steamAccelerationDesc),
                          const SizedBox(height: 8),
                          Text(
                            l.steamConnectionNoVpnIcon,
                            style: TextStyle(color: t.muted),
                          ),
                          if (supported &&
                              !environment.detectionAvailable &&
                              !environment.hasExternal &&
                              !running) ...[
                            const SizedBox(height: 8),
                            Text(l.steamAccelerationDetectionUnavailable),
                          ],
                          if (_busy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          // An already detected proxy/VPN takes priority over
                          // an incomplete scan; manual startup stays disabled.
                          if (state.error != null &&
                              !(state.error ==
                                      SteamAccelerationError
                                          .environmentUnknown &&
                                  environment.hasExternal)) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorLabel(l, state.error!),
                              key: const ValueKey('steam-acceleration-error'),
                              style: TextStyle(color: t.bad),
                            ),
                          ],
                          if (supported) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const ValueKey('steam-acceleration-toggle'),
                              onPressed: running
                                  ? (_busy ? null : () => _run(_service.stop))
                                  : (canStart
                                        ? () => _run(_service.start)
                                        : null),
                              icon: Icon(
                                running
                                    ? Icons.stop_outlined
                                    : Icons.play_arrow_outlined,
                              ),
                              label: Text(
                                running
                                    ? l.steamAccelerationStop
                                    : l.steamAccelerationStart,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (supported) ...[
                      const SizedBox(height: 16),
                      const _ConnectionCheckCard(),
                      const SizedBox(height: 16),
                      AvaPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.steamAccelerationSubscription,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.configured
                                  ? l.steamAccelerationConfigured
                                  : l.steamAccelerationUnconfigured,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'steam-acceleration-configure',
                                  ),
                                  onPressed: _busy || running
                                      ? null
                                      : _editSubscription,
                                  icon: const Icon(Icons.link),
                                  label: Text(
                                    state.configured
                                        ? l.steamAccelerationReplace
                                        : l.steamAccelerationConfigure,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'steam-acceleration-sync',
                                  ),
                                  onPressed:
                                      _busy || running || !state.configured
                                      ? null
                                      : () =>
                                            _run(_service.refreshSubscription),
                                  icon: const Icon(Icons.sync),
                                  label: Text(l.steamAccelerationSync),
                                ),
                                if (state.configured)
                                  TextButton(
                                    key: const ValueKey(
                                      'steam-acceleration-clear',
                                    ),
                                    onPressed: _busy ? null : _clear,
                                    child: Text(l.steamAccelerationClear),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AvaPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.steamAccelerationNodes,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (state.nodes.isEmpty)
                              Text(l.steamAccelerationNoNodes)
                            else
                              DropdownButtonFormField<String>(
                                key: ValueKey((
                                  'steam-acceleration-node',
                                  state.selectedNodeId,
                                )),
                                initialValue: hasSelection
                                    ? state.selectedNodeId
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l.steamAccelerationNode,
                                ),
                                items: [
                                  for (final node in state.nodes)
                                    DropdownMenuItem(
                                      value: node.id,
                                      child: Text(
                                        node.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _busy || running
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          _run(
                                            () => _service.selectNode(value),
                                          );
                                        }
                                      },
                              ),
                            if (state.skippedNodes > 0) ...[
                              const SizedBox(height: 10),
                              Text(
                                l.steamAccelerationSkipped(state.skippedNodes),
                                style: TextStyle(color: t.muted),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.steamAccelerationAuto),
                                      const SizedBox(height: 4),
                                      Text(
                                        l.steamAccelerationAutoDesc,
                                        style: TextStyle(
                                          color: t.muted,
                                          fontSize: context.r(12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  key: const ValueKey(
                                    'steam-acceleration-auto',
                                  ),
                                  value: state.autoStart,
                                  onChanged: _busy || !state.configured
                                      ? null
                                      : (value) => _run(
                                          () => _service.setAutoStart(value),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AvaPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.steamAccelerationEnvironment,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (environment.systemProxyDetected ||
                                environment.pacDetected)
                              Text(l.steamAccelerationExternalProxy),
                            if (environment.vpnOrTunnelDetected)
                              Text(l.steamAccelerationExternalVpn),
                            if (!environment.hasExternal)
                              Text(
                                environment.detectionAvailable
                                    ? l.steamAccelerationNoExternal
                                    : l.steamAccelerationDetectionUnavailable,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              l.steamAccelerationEnvironmentHelp,
                              style: TextStyle(color: t.muted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'steam-acceleration-check-environment',
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _run(_service.checkEnvironment),
                              icon: const Icon(Icons.refresh),
                              label: Text(l.commonRefresh),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionCheckCard extends ConsumerWidget {
  const _ConnectionCheckCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(steamConnectivityProvider);
    final service = ref.watch(steamAccelerationServiceProvider);
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final state = monitor.state;
        final checking = state.status == SteamConnectionStatus.checking;
        final result = state.result;
        Widget endpoint(String label, bool available) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                available ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: available ? t.good : t.bad,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label · ${available ? l.steamConnectionReachable : l.steamConnectionFailed}',
                ),
              ),
            ],
          ),
        );
        return AvaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.steamConnectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  steamConnectionLabel(l, state.status),
                  key: const ValueKey('steam-connection-status'),
                ),
              ),
              const SizedBox(height: 8),
              Text(steamConnectionRouteLabel(l, state.route)),
              if (service.state.environment.pacDetected) ...[
                const SizedBox(height: 8),
                Text(
                  l.steamConnectionPacHelp,
                  style: TextStyle(color: t.muted),
                ),
              ],
              if (checking) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (result != null) ...[
                endpoint(l.steamConnectionApi, result.api),
                endpoint(l.steamConnectionCommunity, result.community),
              ],
              if (state.checkedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  l.steamConnectionCheckedAt(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(state.checkedAt!.toLocal()),
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                  ),
                  style: TextStyle(color: t.muted),
                ),
              ],
              const SizedBox(height: 8),
              Text(l.steamConnectionScope, style: TextStyle(color: t.muted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('steam-connection-check'),
                onPressed: checking ? null : monitor.check,
                icon: const Icon(Icons.network_check),
                label: Text(l.steamConnectionCheck),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({required this.configured});
  final bool configured;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _url = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _url.clear();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _url.text.trim();
    final uri = Uri.tryParse(text);
    if (text.length > 4096 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535 ||
        text.contains(RegExp(r'[\x00-\x20]'))) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.configured
            ? l.steamAccelerationReplace
            : l.steamAccelerationConfigure,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.steamAccelerationSubscriptionHelp),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('steam-acceleration-subscription-input'),
              controller: _url,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.steamAccelerationSubscription,
                errorText: _invalid
                    ? l.steamAccelerationInvalidSubscription
                    : null,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('steam-acceleration-save-subscription'),
          onPressed: _submit,
          child: Text(l.commonOk),
        ),
      ],
    );
  }
}
