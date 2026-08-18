import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';

class HumanResourcesAreaNavEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const HumanResourcesAreaNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });
}

enum HumanResourcesAreaScreen {
  dashboard,
  personnel,
  attendance,
  importConciliation,
  vacations,
  permissions,
  prenomina,
  nomina,
}

class HumanResourcesAreaNavSection {
  final String label;
  final List<HumanResourcesAreaNavEntry> items;

  const HumanResourcesAreaNavSection({
    required this.label,
    required this.items,
  });
}

List<HumanResourcesAreaNavSection> buildHumanResourcesAreaSections({
  required HumanResourcesAreaScreen activeScreen,
  required Future<void> Function() openPersonnel,
  required Future<void> Function() openAttendance,
  required Future<void> Function() openImportConciliation,
  required Future<void> Function() openVacations,
  required Future<void> Function() openPermissions,
  required Future<void> Function() openPrenomina,
  required Future<void> Function() openNomina,
}) {
  HumanResourcesAreaNavEntry buildEntry({
    required HumanResourcesAreaScreen screen,
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    final isActive = screen == activeScreen;
    return HumanResourcesAreaNavEntry(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accented: isActive,
      onTap: isActive ? null : onTap,
    );
  }

  return [
    HumanResourcesAreaNavSection(
      label: 'BASE',
      items: [
        buildEntry(
          screen: HumanResourcesAreaScreen.importConciliation,
          icon: Icons.schedule_rounded,
          title: 'Importación y conciliación',
          subtitle: 'Lectura y cruce de NGTeco y CONTPAQ',
          onTap: openImportConciliation,
        ),
        buildEntry(
          screen: HumanResourcesAreaScreen.personnel,
          icon: Icons.badge_outlined,
          title: 'Personal',
          subtitle: 'Grid homologado de expediente base',
          onTap: openPersonnel,
        ),
      ],
    ),
    HumanResourcesAreaNavSection(
      label: 'OPERACIÓN',
      items: [
        buildEntry(
          screen: HumanResourcesAreaScreen.vacations,
          icon: Icons.beach_access_rounded,
          title: 'Vacaciones',
          subtitle: 'Derecho, aplicación y saldo por ejercicio',
          onTap: openVacations,
        ),
        buildEntry(
          screen: HumanResourcesAreaScreen.permissions,
          icon: Icons.assignment_turned_in_outlined,
          title: 'Permisos',
          subtitle: 'Ledger operativo por periodo y colaborador',
          onTap: openPermissions,
        ),
        buildEntry(
          screen: HumanResourcesAreaScreen.attendance,
          icon: Icons.fact_check_outlined,
          title: 'Asistencia',
          subtitle: 'Cierre editable semanal por colaborador',
          onTap: openAttendance,
        ),
      ],
    ),
    HumanResourcesAreaNavSection(
      label: 'PAGO',
      items: [
        buildEntry(
          screen: HumanResourcesAreaScreen.prenomina,
          icon: Icons.payments_outlined,
          title: 'Prenómina',
          subtitle: 'Corrida borrador semanal por colaborador',
          onTap: openPrenomina,
        ),
        HumanResourcesAreaNavEntry(
          icon: Icons.receipt_long_rounded,
          title: 'Nómina',
          subtitle: 'Pantalla futura de corrida final y cierre fiscal',
          accented: activeScreen == HumanResourcesAreaScreen.nomina,
          onTap: activeScreen == HumanResourcesAreaScreen.nomina
              ? null
              : openNomina,
        ),
      ],
    ),
  ];
}

List<HumanResourcesAreaNavEntry> buildHumanResourcesAccessItems({
  required HumanResourcesAreaScreen activeScreen,
  required Future<void> Function() openDashboard,
  required bool canReturnToDirection,
  required Future<void> Function() openDirectionDashboard,
}) {
  final items = <HumanResourcesAreaNavEntry>[
    HumanResourcesAreaNavEntry(
      icon: Icons.space_dashboard_rounded,
      title: 'Dashboard RH',
      subtitle: 'Resumen y contexto del área',
      accented: activeScreen == HumanResourcesAreaScreen.dashboard,
      onTap: activeScreen == HumanResourcesAreaScreen.dashboard
          ? null
          : openDashboard,
    ),
  ];
  if (canReturnToDirection) {
    items.add(
      HumanResourcesAreaNavEntry(
        icon: Icons.assessment_outlined,
        title: 'Dashboard Dirección',
        subtitle: 'Vista ejecutiva multiarea',
        onTap: openDirectionDashboard,
      ),
    );
  }
  return items;
}

class HumanResourcesAreaBackground extends StatelessWidget {
  const HumanResourcesAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF140B25), Color(0xFF24103F), Color(0xFF4A1D7A)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -240,
          top: -140,
          child: _HumanResourcesBackgroundCircle(
            diameter: 760,
            colors: [Color(0xFF2A174A), Color(0xFF12091F)],
          ),
        ),
        Positioned(
          right: -180,
          top: -80,
          child: _HumanResourcesBackgroundCircle(
            diameter: 560,
            colors: [Color(0xFF9465F4), Color(0x33261540)],
          ),
        ),
        Positioned(
          left: 40,
          bottom: -240,
          child: _HumanResourcesBackgroundCircle(
            diameter: 660,
            colors: [Color(0x33573797), Color(0xFFE9D8FF)],
          ),
        ),
      ],
    );
  }
}

class _HumanResourcesBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _HumanResourcesBackgroundCircle({
    required this.diameter,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.03),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class HumanResourcesAreaHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const HumanResourcesAreaHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  State<HumanResourcesAreaHeaderButton> createState() =>
      _HumanResourcesAreaHeaderButtonState();
}

class _HumanResourcesAreaHeaderButtonState
    extends State<HumanResourcesAreaHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              width: widget.compact ? 56 : 186,
              height: 56,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 0 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.18 : 0.12),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.20 : 0.12,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.22 : 0.12,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.14 : 0.06,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: widget.compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 20, color: tokens.onGlass),
                  if (!widget.compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: tokens.onGlass,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HumanResourcesAreaSidePanel extends StatelessWidget {
  final String label;
  final bool canReturnToDirection;
  final List<HumanResourcesAreaNavSection> sections;
  final List<HumanResourcesAreaNavEntry> accessItems;

  const HumanResourcesAreaSidePanel({
    super.key,
    required this.label,
    required this.canReturnToDirection,
    required this.sections,
    required this.accessItems,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.onGlass,
                ),
              ),
              const SizedBox(height: 16),
              for (
                var sectionIndex = 0;
                sectionIndex < sections.length;
                sectionIndex++
              ) ...[
                _HumanResourcesAreaSectionHeader(
                  label: sections[sectionIndex].label,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x99432A65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var itemIndex = 0;
                        itemIndex < sections[sectionIndex].items.length;
                        itemIndex++
                      ) ...[
                        HumanResourcesAreaNavItem(
                          icon: sections[sectionIndex].items[itemIndex].icon,
                          title: sections[sectionIndex].items[itemIndex].title,
                          subtitle:
                              sections[sectionIndex].items[itemIndex].subtitle,
                          accented:
                              sections[sectionIndex].items[itemIndex].accented,
                          onTap: sections[sectionIndex].items[itemIndex].onTap,
                        ),
                        if (itemIndex !=
                            sections[sectionIndex].items.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                if (sectionIndex != sections.length - 1)
                  const SizedBox(height: 14),
              ],
              if (accessItems.isNotEmpty) ...[
                if (sections.isNotEmpty) const SizedBox(height: 14),
                const _HumanResourcesAreaSectionHeader(label: 'ACCESOS'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x99432A65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < accessItems.length;
                        index++
                      ) ...[
                        HumanResourcesAreaNavItem(
                          icon: accessItems[index].icon,
                          title: accessItems[index].title,
                          subtitle: accessItems[index].subtitle,
                          accented: accessItems[index].accented,
                          onTap: accessItems[index].onTap,
                        ),
                        if (index != accessItems.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HumanResourcesAreaNavigationOverlay extends StatelessWidget {
  final bool menuOpen;
  final VoidCallback onDismiss;
  final bool canReturnToDirection;
  final List<HumanResourcesAreaNavSection> sections;
  final List<HumanResourcesAreaNavEntry> accessItems;
  final String label;

  const HumanResourcesAreaNavigationOverlay({
    super.key,
    required this.menuOpen,
    required this.onDismiss,
    required this.canReturnToDirection,
    required this.sections,
    required this.accessItems,
    this.label = 'Recursos Humanos',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !menuOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: menuOpen ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: Container(color: Colors.black.withValues(alpha: 0.12)),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: menuOpen ? 0 : -332,
            top: 0,
            bottom: 0,
            width: 320,
            child: IgnorePointer(
              ignoring: !menuOpen,
              child: HumanResourcesAreaSidePanel(
                label: label,
                canReturnToDirection: canReturnToDirection,
                sections: sections,
                accessItems: accessItems,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanResourcesAreaSectionHeader extends StatelessWidget {
  final String label;

  const _HumanResourcesAreaSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}

class HumanResourcesAreaNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const HumanResourcesAreaNavItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accented
                  ? const Color(0xCC6B46C1)
                  : const Color(0x9925163A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: tokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(
                            alpha: accented ? 0.92 : 0.58,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.primary,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
