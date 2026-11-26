import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Ambient motion belongs to the neon skin, never to the quiet/plain look.
/// Stopping the controller (rather than just hiding its output) lets an idle
/// screen stop scheduling frames. TickerMode also covers routes off screen.
bool ambientMotionAllowed(BuildContext context) =>
    (Theme.of(context).extension<AvaTokens>()?.glow ?? false) &&
    !MediaQuery.disableAnimationsOf(context) &&
    TickerMode.valuesOf(context).enabled;

/// Horizontal shake, triggered by bumping [trigger] (e.g. on a wrong passkey).
/// Brief damped feedback; the error text remains when motion is disabled.
class ShakeWidget extends StatefulWidget {
  final int trigger;
  final Widget child;
  const ShakeWidget({super.key, required this.trigger, required this.child});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void didUpdateWidget(ShakeWidget old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final dx = math.sin(_c.value * math.pi * 4) * 6 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Small status dot that pulses its glow (the design's `glowPulse`).
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingDot({super.key, required this.color, this.size = 9});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = ambientMotionAllowed(context);
    if (_animate) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) {
      return SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final glow = 4 + _c.value * 8;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4 + _c.value * 0.4),
                  blurRadius: glow,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Gentle vertical float (floatY 3.5s), used for the welcome / lock logo.
class FloatingLogo extends StatefulWidget {
  final Widget child;
  const FloatingLogo({super.key, required this.child});

  @override
  State<FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3500),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = ambientMotionAllowed(context);
    if (_animate) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final dy = -4 * math.sin(_c.value * math.pi);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}
