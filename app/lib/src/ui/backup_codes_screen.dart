import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../app/responsive.dart';
import '../core/models/steam_guard_account.dart';
import 'widgets/ava_panel.dart';

/// Steam generates the one-use codes after its own account/phone verification.
/// Never substitute the authenticator revocation code or transfer a session
/// token through a browser URL. The browser may be signed in to another account.
final backupCodesLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class BackupCodesScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const BackupCodesScreen({super.key, required this.account});

  static final steamUrl = Uri.https(
    'store.steampowered.com',
    '/twofactor/manage',
  );

  @override
  ConsumerState<BackupCodesScreen> createState() => _BackupCodesScreenState();
}

class _BackupCodesScreenState extends ConsumerState<BackupCodesScreen> {
  bool _opening = false;
  bool _failed = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await ref.read(backupCodesLauncherProvider)(
        BackupCodesScreen.steamUrl,
      );
    } catch (_) {
      // Browsers can be unavailable (including a desktop with no URI handler).
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name =
        widget.account.accountName ??
        widget.account.personaName ??
        '${widget.account.steamId}';
    return Scaffold(
      appBar: AppBar(title: Text(l.backupCodesTitle)),
      body: ListView(
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
                Text(l.backupCodesAccountCheck),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.backupCodesHow,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(l.backupCodesSteps),
          const SizedBox(height: 20),
          Text(l.backupCodesExplanation),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _opening ? null : _open,
            icon: const Icon(Icons.open_in_new),
            label: Text(l.backupCodesOpenSteam),
          ),
          const SizedBox(height: 12),
          SelectableText(BackupCodesScreen.steamUrl.toString()),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: BackupCodesScreen.steamUrl.toString()),
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
          if (_failed) Text(l.backupCodesOpenFailed),
        ],
      ),
    );
  }
}
