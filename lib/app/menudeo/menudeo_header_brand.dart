import 'package:flutter/material.dart';

import '../shared/dicsa_logo_mark.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';

class MenudeoHeaderBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const MenudeoHeaderBrand({
    super.key,
    required this.contentAnim,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return AnimatedBuilder(
      animation: contentAnim,
      builder: (context, child) => Opacity(
        opacity: contentAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - contentAnim.value) * 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.44),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          spreadRadius: 1,
                          color: tokens.primaryStrong.withValues(alpha: 0.16),
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(child: DicsaLogoD(size: 40)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.primaryStrong.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.25,
                          height: 1.0,
                          color: tokens.primaryStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
