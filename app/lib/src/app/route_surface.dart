import 'package:flutter/material.dart';

/// Android navigation waits for the back gesture to finish instead of moving
/// or shrinking the page under the user's finger. This builder deliberately
/// installs no predictive-back gesture observer; Flutter commits an unhandled
/// back gesture through the normal Navigator/PopScope path.
class AvaAndroidPageTransitionsBuilder extends PageTransitionsBuilder {
  const AvaAndroidPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

/// Gives each Material page its own opaque backdrop, inside its transition.
/// The other platforms keep their native transitions; a backdrop outside
/// Navigator lets transparent scaffolds expose the previous page's widgets.
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
