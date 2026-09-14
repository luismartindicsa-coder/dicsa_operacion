import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_theme.dart';

/// DICSA glass card with the same lift used by area navigation and dashboards.
class DocumentalActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String label;
  final bool selected;
  final EdgeInsetsGeometry padding;

  const DocumentalActionCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.selected = false,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  State<DocumentalActionCard> createState() => _DocumentalActionCardState();
}

class _DocumentalActionCardState extends State<DocumentalActionCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final lifted = _hovered || _focused;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: lifted ? 1.012 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: t.glow.withValues(alpha: lifted ? 0.16 : 0.04),
                  blurRadius: lifted ? 24 : 12,
                  offset: Offset(0, lifted ? 12 : 6),
                ),
              ],
            ),
            child: ContractGlassCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onFocusChange: (value) => setState(() => _focused = value),
                  borderRadius: BorderRadius.circular(24),
                  hoverColor: t.primary.withValues(alpha: 0.08),
                  focusColor: t.primary.withValues(alpha: 0.12),
                  splashColor: t.primary.withValues(alpha: 0.14),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? t.primary.withValues(alpha: 0.13)
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.selected || _focused
                            ? t.primary.withValues(alpha: 0.7)
                            : Colors.transparent,
                      ),
                    ),
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DocumentalBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const DocumentalBadge(this.label, {super.key, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: t.badgeBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: iconColor ?? t.badgeText),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: t.badgeText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentalProgress extends StatelessWidget {
  final int value;
  const DocumentalProgress(this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value%',
          style: TextStyle(
            color: tokens.primarySoft,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0, 100) / 100,
            minHeight: 6,
            color: tokens.primary,
            backgroundColor: tokens.primary.withValues(alpha: 0.14),
            semanticsLabel: 'Avance del trámite',
            semanticsValue: '$value%',
          ),
        ),
      ],
    );
  }
}

class DocumentalUrgencyBadge extends StatelessWidget {
  final DocumentalUrgency urgency;
  const DocumentalUrgencyBadge(this.urgency, {super.key});
  @override
  Widget build(BuildContext context) => DocumentalBadge(
    urgency.label,
    icon: urgency.icon,
    iconColor: documentalUrgencyColor(context, urgency),
  );
}

class DocumentalIcon extends StatelessWidget {
  final IconData icon;
  const DocumentalIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: t.primary, size: 23),
    );
  }
}

class DocumentalEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  const DocumentalEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.folder_open_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(
        children: [
          DocumentalIcon(icon),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.onGlass,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.onGlass.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentalPageHeading extends StatelessWidget {
  final String title;
  final String description;
  final Widget? action;
  const DocumentalPageHeading({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: t.onGlass,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: t.onGlass.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            if (action != null) ...[const SizedBox(width: 20), action!],
          ],
        );
      },
    );
  }
}
