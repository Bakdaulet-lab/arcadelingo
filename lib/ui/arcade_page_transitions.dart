import 'package:flutter/material.dart';

PageTransitionsTheme arcadePageTransitions({required bool reduceMotion}) {
  final standard =
      reduceMotion
          ? const _ArcadeTransitions(reduceMotion: true)
          : const _ArcadeTransitions();
  final apple =
      reduceMotion
          ? const _InstantCupertinoTransitions()
          : const CupertinoPageTransitionsBuilder();
  return PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: switch (platform) {
          TargetPlatform.iOS || TargetPlatform.macOS => apple,
          _ => standard,
        },
    },
  );
}

class _ArcadeTransitions extends PageTransitionsBuilder {
  const _ArcadeTransitions({this.reduceMotion = false});

  final bool reduceMotion;

  static final _position = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));
  static final _opacity = CurveTween(curve: Curves.easeOut);

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 170);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion) return child;
    return FadeTransition(
      opacity: animation.drive(_opacity),
      child: SlideTransition(
        position: animation.drive(_position),
        child: child,
      ),
    );
  }
}

/// Мгновенный переход по кнопке сохраняет системный жест возврата от края.
class _InstantCupertinoTransitions extends CupertinoPageTransitionsBuilder {
  const _InstantCupertinoTransitions();

  @override
  Duration get transitionDuration => Duration.zero;
}
