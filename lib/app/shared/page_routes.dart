import 'package:flutter/material.dart';

Route<T> appPageRoute<T>({
  required Widget page,
  Duration duration = const Duration(milliseconds: 480),
  Duration reverseDuration = const Duration(milliseconds: 480),
  bool fade = true,
  bool routeAnimation = true,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (!routeAnimation) return child;
      final fadeAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      final scale = Tween<double>(
        begin: 0.992,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final content = ScaleTransition(scale: scale, child: child);
      if (!fade) return content;
      return FadeTransition(opacity: fadeAnim, child: content);
    },
  );
}
