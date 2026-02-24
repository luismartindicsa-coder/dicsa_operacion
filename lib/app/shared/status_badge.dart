import 'dart:ui';
import 'package:flutter/material.dart';

enum BadgeStatus { programado, enRuta, confirmado, cancelado }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final double height;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    Key? key,
    required this.label,
    required this.status,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  }) : super(key: key);

  factory StatusBadge.programado([String label = 'PROGRAMADO']) =>
      StatusBadge(label: label, status: BadgeStatus.programado);

  factory StatusBadge.enRuta([String label = 'EN RUTA']) =>
      StatusBadge(label: label, status: BadgeStatus.enRuta);

  factory StatusBadge.confirmado([String label = 'CONFIRMADO']) =>
      StatusBadge(label: label, status: BadgeStatus.confirmado);

  factory StatusBadge.cancelado([String label = 'CANCELADO']) =>
      StatusBadge(label: label, status: BadgeStatus.cancelado);

  @override
  Widget build(BuildContext context) {
    final s = _stylesFor(status);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: s.gradient,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: [
              // soft drop shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              // subtle colored glow
              BoxShadow(
                color: s.glowColor.withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // inner soft reflection (diagonal)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-0.9, -0.3),
                        end: Alignment(0.9, 0.5),
                        colors: [
                          Colors.white.withOpacity(0.06),
                          Colors.white.withOpacity(0.00),
                        ],
                        stops: const [0.0, 0.6],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),

              // faint top edge highlight to simulate glass
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: height * 0.28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.32),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(999), bottom: Radius.circular(999)),
                  ),
                ),
              ),

              // centered label
              Center(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: -0.4,
                    height: 1.02,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.12),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BadgeStyle _stylesFor(BadgeStatus s) {
    switch (s) {
      case BadgeStatus.programado:
        return _BadgeStyle(
          gradient: const LinearGradient(
            begin: Alignment(-0.9, -0.2),
            end: Alignment(0.9, 0.2),
            colors: [Color(0xFF3CE0FF), Color(0xFF0B72FF)],
          ),
          glowColor: const Color(0xFF4CE6FF),
          textColor: Colors.white,
        );

      case BadgeStatus.enRuta:
        return _BadgeStyle(
          gradient: const LinearGradient(
            begin: Alignment(-0.8, -0.2),
            end: Alignment(0.8, 0.2),
            colors: [Color(0xFF00E6C6), Color(0xFF0ABAB5)],
          ),
          glowColor: const Color(0xFF2EEAD0),
          textColor: Colors.white,
        );

      case BadgeStatus.confirmado:
        return _BadgeStyle(
          gradient: const LinearGradient(
            begin: Alignment(-0.9, -0.2),
            end: Alignment(0.9, 0.2),
            colors: [Color(0xFF7AF59A), Color(0xFF18BA6B)],
          ),
          glowColor: const Color(0xFF5FFB9C),
          textColor: Colors.white,
        );

      case BadgeStatus.cancelado:
        return _BadgeStyle(
          gradient: const LinearGradient(
            begin: Alignment(-0.9, -0.2),
            end: Alignment(0.9, 0.2),
            colors: [Color(0xFFFFD6D8), Color(0xFFFFA3A8)],
          ),
          glowColor: const Color(0xFFFFC2C7),
          textColor: Colors.white,
        );
    }
  }
}

class _BadgeStyle {
  final Gradient gradient;
  final Color glowColor;
  final Color textColor;

  _BadgeStyle({required this.gradient, required this.glowColor, required this.textColor});
}
