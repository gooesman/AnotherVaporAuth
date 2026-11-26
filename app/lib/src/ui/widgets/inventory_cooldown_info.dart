import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/responsive.dart';
import '../../core/models/steam_item.dart';

/// A quiet summary with complete Steam notes on tap. No timers or extra network
/// calls per inventory item; opening the details computes the remaining time.
class InventoryCooldownInfo extends StatelessWidget {
  const InventoryCooldownInfo({super.key, required this.item});

  final InventoryItem item;

  static String _date(DateTime value) =>
      DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());

  @override
  Widget build(BuildContext context) {
    if (item.marketable && item.tradable && item.restrictions.isEmpty) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final dates = item.restrictions.map((note) => note.until).nonNulls.toList()
      ..sort();
    final summary = dates.isEmpty
        ? l.inventoryCooldownDetails
        : l.inventoryCooldownUntil(_date(dates.last));
    return InkWell(
      key: ValueKey('inventory-cooldown-${item.assetId}'),
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, size: 12),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: context.r(9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.inventoryCooldownDetails),
        content: SingleChildScrollView(
          padding: context.rSafeInsets(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name),
              const SizedBox(height: 12),
              Text(
                item.tradable
                    ? l.inventoryCooldownTradable
                    : l.inventoryCooldownNotTradable,
              ),
              Text(
                item.marketable
                    ? l.inventoryCooldownMarketable
                    : l.marketNotMarketable,
              ),
              for (final note in item.restrictions) ...[
                const SizedBox(height: 12),
                Text(
                  note.until != null && note.dateText != null
                      ? note.text.replaceFirst(
                          note.dateText!,
                          _date(note.until!),
                        )
                      : note.text,
                ),
                if (note.until != null) ...[
                  Text(l.inventoryCooldownLocalTime),
                  Text(_remaining(l, note.until!, now)),
                ],
              ],
              if (item.restrictions.every((note) => note.until == null)) ...[
                const SizedBox(height: 12),
                Text(l.inventoryCooldownUnknown),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
  }

  static String _remaining(AppLocalizations l, DateTime until, DateTime now) {
    final remaining = until.difference(now);
    if (remaining <= Duration.zero) return l.inventoryCooldownElapsed;
    final minutes = (remaining.inSeconds / 60).ceil();
    return l.inventoryCooldownRemaining(
      minutes ~/ 1440,
      minutes % 1440 ~/ 60,
      minutes % 60,
    );
  }
}
