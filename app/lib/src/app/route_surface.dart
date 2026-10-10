import 'package:flutter/material.dart';

/// Gives each Material page its own opaque backdrop, inside its transition.
/// A backdrop outside Navigator cannot travel with Android's predictive-back
/// transform and lets transparent scaffolds expose the previous page's widgets.
class AvaPageTransitionsBuilder extends PageTransitionsBuilder {
  const AvaPageTransitionsBuilder({
    required this.delegate,
    required this.color,
    this.gradient,
  });

  final PageTransitionsBuilder delegate;
  final Color color;
  final Gradient? gradient;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegate.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return delegate.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      DecoratedBox(
        key: const ValueKey('ava-route-surface'),
        decoration: BoxDecoration(color: color, gradient: gradient),
        child: child,
      ),
    );
  }
}
