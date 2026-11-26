import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/steam_acceleration_providers.dart';
import '../../app/theme.dart';
import '../../services/steam_acceleration.dart';
import '../../services/steam_connectivity.dart';
import '../steam_acceleration_screen.dart';

String steamConnectionLabel(AppLocalizations l, SteamConnectionStatus status) =>
    switch (status) {
      SteamConnectionStatus.unchecked => l.steamConnectionNotChecked,
      SteamConnectionStatus.checking => l.steamConnectionChecking,
      SteamConnectionStatus.available => l.steamConnectionAvailable,
      SteamConnectionStatus.partial => l.steamConnectionPartial,
      SteamConnectionStatus.unavailable => l.steamConnectionUnavailable,
    };

String steamConnectionRouteLabel(
  AppLocalizations l,
  SteamConnectionRoute route,
) => switch (route) {
  SteamConnectionRoute.direct => l.steamConnectionDirect,
  SteamConnectionRoute.internal => l.steamConnectionInternal,
  SteamConnectionRoute.externalProxy => l.steamConnectionExternal,
  SteamConnectionRoute.system => l.steamConnectionSystem,
  SteamConnectionRoute.unresolvedProxy => l.steamConnectionUnresolvedProxy,
};

String steamAccelerationPhaseLabel(
  AppLocalizations l,
  SteamAccelerationPhase phase,
) => switch (phase) {
  SteamAccelerationPhase.off => l.steamAccelerationOff,
  SteamAccelerationPhase.loadingSubscription => l.steamAccelerationLoading,
  SteamAccelerationPhase.downloadingCore => l.steamAccelerationDownloadingCore,
  SteamAccelerationPhase.starting => l.steamAccelerationStarting,
  SteamAccelerationPhase.running => l.steamAccelerationRunning,
  SteamAccelerationPhase.pausedExternal => l.steamAccelerationPaused,
  SteamAccelerationPhase.error => l.steamAccelerationFailed,
};

/// Compact, app-local status beside settings; the account picker stays compact.
/// A green connection icon requires a completed check, not a running process.
class SteamAccelerationStatusChip extends ConsumerWidget {
  const SteamAccelerationStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(steamAccelerationServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.supported ||
            (!service.state.configured &&
                !service.state.environment.hasExternal)) {
          return const SizedBox.shrink();
        }
        return _ConnectionChip(service: service);
      },
    );
  }
}

class _ConnectionChip extends ConsumerWidget {
  const _ConnectionChip({required this.service});
  final SteamAccelerationService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(steamConnectivityProvider);
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final acceleration = service.state;
        final connection = monitor.state;
        final active =
            acceleration.phase == SteamAccelerationPhase.running ||
            connection.route != SteamConnectionRoute.direct;
        final phase = steamAccelerationPhaseLabel(l, acceleration.phase);
        final status = active
            ? steamConnectionLabel(l, connection.status)
            : phase;
        final good =
            active && connection.status == SteamConnectionStatus.available;
        final bad =
            acceleration.phase == SteamAccelerationPhase.error ||
            active &&
                (connection.status == SteamConnectionStatus.unavailable ||
                    connection.status == SteamConnectionStatus.partial);
        final color = good
            ? t.good
            : bad
            ? t.bad
            : t.muted;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Tooltip(
            message:
                '${l.steamAccelerationTitle} · $phase\n'
                '${steamConnectionRouteLabel(l, connection.route)} · '
                '${steamConnectionLabel(l, connection.status)}',
            child: OutlinedButton.icon(
              key: const ValueKey('steam-acceleration-home-status'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SteamAccelerationScreen(),
                ),
              ),
              icon: Icon(
                good ? Icons.check_circle_outline : Icons.speed_outlined,
                size: 16,
                color: color,
              ),
              label: Text(
                '${steamConnectionRouteLabel(l, connection.route)} · $status',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.text,
                backgroundColor: t.panel,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        );
      },
    );
  }
}
