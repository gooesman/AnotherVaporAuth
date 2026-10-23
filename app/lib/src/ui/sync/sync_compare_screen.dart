import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../app/sync_providers.dart';
import '../../core/sync/sync_field_diff.dart';
import '../../core/steam_currency.dart';
import '../../core/sync/sync_transport.dart';
import '../../services/sync/sync_engine.dart';
import '../widgets/ava_panel.dart';

class SyncCompareScreen extends ConsumerStatefulWidget {
  const SyncCompareScreen({super.key});

  @override
  ConsumerState<SyncCompareScreen> createState() => _SyncCompareScreenState();
}

class _SyncCompareScreenState extends ConsumerState<SyncCompareScreen> {
  SyncComparison? _preview;
  bool _busy = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await ref.read(syncEngineProvider).compareWithRemote();
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(SyncComparisonItem item, bool upload) async {
    final preview = _preview;
    if (_busy ||
        preview == null ||
        (upload && preview.uploadBlockedByPasswordChange)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncEngineProvider)
          .applyComparison(preview, item, upload: upload);
      await _load();
    } catch (e) {
      // Discard the old buttons; a refreshed comparison is required to retry.
      if (mounted) {
        setState(() {
          _error = e;
          _preview = null;
          _busy = false;
        });
      }
    }
  }

  String _time(DateTime? date) =>
      date == null ? '—' : date.toLocal().toString().substring(0, 16);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.syncCompareTitle),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: l.syncCompareRefresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: context.rSafeInsets(all: 16),
            children: [
              Text(l.syncCompareHelp),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error is SyncComparisonChanged ||
                          _error is SyncPreconditionFailed
                      ? l.syncCompareStale
                      : l.syncCompareFailed,
                ),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: Text(l.syncCompareRefresh),
                ),
              ],
              if (preview != null) ...[
                if (preview.uploadBlockedByPasswordChange) ...[
                  const SizedBox(height: 12),
                  Text(l.syncComparePasswordChangePending),
                ],
                const SizedBox(height: 12),
                Text(
                  '${l.syncConflictLocalSide}: ${_time(preview.localSyncAt)}\n${l.syncConflictRemoteSide}: ${_time(preview.remoteSyncAt)}',
                ),
                const SizedBox(height: 12),
                if (preview.items.isEmpty) Text(l.syncRemoteEmpty),
                for (final item in preview.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _item(l, item),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(AppLocalizations l, SyncComparisonItem item) {
    final differences = syncFieldDiff(item.local, item.remote);
    final relation = switch (item.kind) {
      SyncComparisonKind.same => l.syncCompareSame,
      SyncComparisonKind.localOnly =>
        item.remoteDeleted
            ? l.syncCompareRemoteDeleted
            : l.syncCompareLocalOnly,
      SyncComparisonKind.remoteOnly => l.syncCompareRemoteOnly,
      SyncComparisonKind.localChanged => l.syncCompareLocalNewer,
      SyncComparisonKind.remoteChanged => l.syncCompareRemoteNewer,
      SyncComparisonKind.bothChanged => l.syncCompareBothChanged,
    };
    return AvaPanel(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          initiallyExpanded: item.kind != SyncComparisonKind.same,
          title: Text(item.steamId == null ? l.syncCompareSettings : item.name),
          subtitle: Text(
            '$relation · ${l.syncConflictRemoteSide} r${item.remoteRevision}',
          ),
          childrenPadding: context.rInsets(h: 16, bottom: 12),
          children: [
            for (final diff in differences) _field(l, diff),
            if (item.kind != SyncComparisonKind.same)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !_busy && item.canPull
                          ? () => _apply(item, false)
                          : null,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(l.syncComparePull),
                    ),
                    FilledButton.icon(
                      onPressed: !_busy &&
                              item.canUpload &&
                              _preview?.uploadBlockedByPasswordChange != true
                          ? () => _apply(item, true)
                          : null,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(l.syncCompareUpload),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(AppLocalizations l, SyncFieldDiff diff) {
    String value(Object? v) =>
        diff.path == 'market_favorites.currency' && v is int
        ? steamCurrencyCode(v)
        : v == null
        ? '—'
        : diff.masked
        ? l.syncCompareHidden
        : v is String
        ? v
        : jsonEncode(v);
    final path = diff.path
        .replaceFirst('market_favorites.currency', l.syncCompareCurrency)
        .replaceFirst('market_favorites.items.', '${l.syncCompareFavorites} / ')
        .replaceFirst('steam_acceleration.url', l.syncCompareSubscription)
        .replaceFirst('steam_acceleration.nodes', l.syncCompareNodes)
        .replaceFirst('steam_acceleration.selected', l.syncCompareSelectedNode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(path, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${l.syncConflictLocalSide}: ${value(diff.local)}'),
          Text('${l.syncConflictRemoteSide}: ${value(diff.remote)}'),
        ],
      ),
    );
  }
}
