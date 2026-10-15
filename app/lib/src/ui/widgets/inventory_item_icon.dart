import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/steam_item.dart';
import 'steam_image_provider.dart';

/// A restrained rarity cue around an inventory thumbnail. The surrounding
/// selection/card still uses the current AVA skin and its normal accent.
class InventoryItemIcon extends StatelessWidget {
  final InventoryItem item;
  final double? size;
  final BoxFit fit;

  const InventoryItemIcon({
    super.key,
    required this.item,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AvaTokens>()!;
    final raw = item.rarityColor.trim();
    final rgb = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(raw)
        ? int.tryParse(raw.replaceFirst('#', ''), radix: 16)
        : null;
    final color = rgb == null ? null : Color(0xff000000 | rgb);
    final radius = BorderRadius.circular(tokens.radiusSm);
    final frame = Container(
      width: size ?? double.infinity,
      height: size ?? double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.06) ?? tokens.panel2,
        border: Border.all(
          color: color?.withValues(alpha: 0.5) ?? tokens.borderColor,
          width: 1,
        ),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: item.iconUrl.isEmpty
            ? Icon(Icons.inventory_2_outlined, color: tokens.muted)
            : LayoutBuilder(
                builder: (context, constraints) => Image(
                  image: steamThumbnailProvider(
                    item.iconUrl,
                    logicalSize: Size(
                      constraints.hasBoundedWidth ? constraints.maxWidth : 128,
                      constraints.hasBoundedHeight
                          ? constraints.maxHeight
                          : 128,
                    ),
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  fit: fit,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.inventory_2_outlined, color: tokens.muted),
                ),
              ),
      ),
    );
    return item.rarityName.trim().isEmpty
        ? frame
        : Tooltip(
            message: item.rarityName.trim(),
            // Hover still explains the color on desktop. Do not consume a
            // parent's long-press gesture used to open item actions on mobile.
            triggerMode: TooltipTriggerMode.manual,
            child: frame,
          );
  }
}
