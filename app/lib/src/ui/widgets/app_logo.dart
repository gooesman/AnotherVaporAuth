import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shared gooes SteamKit artwork, with the active skin's clipping and sampling.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).extension<AvaTokens>()?.variant ??
        AvaThemeVariant.neon;
    final radius = variant == AvaThemeVariant.pixel ? size * 0.12 : size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/icon/gooes_steamkit.png',
        width: size,
        height: size,
        filterQuality:
            variant == AvaThemeVariant.pixel ? FilterQuality.none : FilterQuality.medium,
      ),
    );
  }
}
