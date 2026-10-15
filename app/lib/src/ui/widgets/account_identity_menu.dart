import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/theme.dart';
import '../../core/models/steam_guard_account.dart';

/// Keeps the name's primary action while offering its exact identity fields.
class AccountIdentityMenu extends StatefulWidget {
  final SteamGuardAccount account;
  final Widget child;
  final VoidCallback? onTap;

  const AccountIdentityMenu({
    super.key,
    required this.account,
    required this.child,
    this.onTap,
  });

  @override
  State<AccountIdentityMenu> createState() => _AccountIdentityMenuState();
}

class _AccountIdentityMenuState extends State<AccountIdentityMenu> {
  bool _open = false;

  Future<void> _showMenu(Offset? position) async {
    if (_open) return;
    _open = true;
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).extension<AvaTokens>()!;
    String? available(String? value) =>
        value == null || value.trim().isEmpty ? null : value;
    final account = widget.account;
    final entries = [
      (
        key: 'persona',
        label: l.accountCopyPersonaName,
        value: available(account.personaName),
      ),
      (
        key: 'login',
        label: l.accountCopyLoginName,
        value: available(account.accountName),
      ),
      (
        key: 'id',
        label: l.copySteamId,
        value: account.steamId > 0 ? '${account.steamId}' : null,
      ),
    ];
    try {
      final overlay =
          Overlay.of(context).context.findRenderObject()! as RenderBox;
      final nameBox = context.findRenderObject()! as RenderBox;
      final anchor = overlay.globalToLocal(
        position ?? nameBox.localToGlobal(Offset(0, nameBox.size.height)),
      );
      final selected = await showMenu<String>(
        context: context,
        semanticLabel: l.accountCopyInfoTitle,
        position: RelativeRect.fromSize(anchor & Size.zero, overlay.size),
        items: [
          for (final entry in entries)
            PopupMenuItem<String>(
              key: ValueKey('account-copy-${entry.key}'),
              value: entry.value,
              enabled: entry.value != null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.label),
                          Text(
                            entry.value ?? l.accountCopyUnavailable,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_outlined, size: 18, color: t.muted),
                  ],
                ),
              ),
            ),
        ],
      );
      if (selected == null || !mounted) return;
      await Clipboard.setData(ClipboardData(text: selected));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.copied)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.accountCopyFailed)));
      }
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: mobile ? () => _showMenu(null) : null,
      onSecondaryTapDown: mobile
          ? null
          : (details) => _showMenu(details.globalPosition),
      child: widget.child,
    );
  }
}
