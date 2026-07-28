import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';

enum ContabilidadAreaScreen {
  dashboard,
  tradeBalance,
  flujoGeneral,
  analisisGastos,
  estadoResultados,
  confiabilidad,
}

List<DashboardNavAction> buildContabilidadAreaItems({
  required ContabilidadAreaScreen current,
  required Future<void> Function() onOpenTradeBalance,
  Future<void> Function()? onOpenFlujoGeneral,
  Future<void> Function()? onOpenAnalisisGastos,
  Future<void> Function()? onOpenEstadoResultados,
  Future<void> Function()? onOpenConfiabilidad,
}) {
  return [
    DashboardNavAction(
      title: 'Resultado Comercial',
      subtitle: 'Compra, venta y margen comercial del periodo',
      icon: Icons.swap_horiz_rounded,
      current: current == ContabilidadAreaScreen.tradeBalance,
      onTap: current == ContabilidadAreaScreen.tradeBalance
          ? _noop
          : onOpenTradeBalance,
    ),
    DashboardNavAction(
      title: 'Flujo General',
      subtitle: 'Entradas y salidas reales consolidadas',
      icon: Icons.waterfall_chart_rounded,
      current: current == ContabilidadAreaScreen.flujoGeneral,
      onTap: current == ContabilidadAreaScreen.flujoGeneral
          ? _noop
          : onOpenFlujoGeneral ?? _noop,
    ),
    DashboardNavAction(
      title: 'Analisis de Gastos',
      subtitle: 'Clasificacion de egresos y salidas internas',
      icon: Icons.receipt_long_rounded,
      current: current == ContabilidadAreaScreen.analisisGastos,
      onTap: current == ContabilidadAreaScreen.analisisGastos
          ? _noop
          : onOpenAnalisisGastos ?? _noop,
    ),
    DashboardNavAction(
      title: 'Estado de Resultados',
      subtitle: 'Ingresos, costo, gasto y utilidad',
      icon: Icons.assessment_rounded,
      current: current == ContabilidadAreaScreen.estadoResultados,
      onTap: current == ContabilidadAreaScreen.estadoResultados
          ? _noop
          : onOpenEstadoResultados ?? _noop,
    ),
    DashboardNavAction(
      title: 'Confiabilidad',
      subtitle: 'Cruces y validaciones para cierre contable',
      icon: Icons.rule_folder_rounded,
      current: current == ContabilidadAreaScreen.confiabilidad,
      onTap: current == ContabilidadAreaScreen.confiabilidad
          ? _noop
          : onOpenConfiabilidad ?? _noop,
    ),
  ];
}

List<DashboardNavAction> buildContabilidadAccessItems({
  required ContabilidadAreaScreen current,
  required Future<void> Function() onOpenDashboard,
}) {
  return [
    DashboardNavAction(
      title: 'Dashboard Contabilidad',
      subtitle: 'Base contable homologada',
      icon: Icons.space_dashboard_rounded,
      current: current == ContabilidadAreaScreen.dashboard,
      onTap: current == ContabilidadAreaScreen.dashboard
          ? _noop
          : onOpenDashboard,
    ),
  ];
}

class ContabilidadAreaSidePanel extends StatelessWidget {
  final String label;
  final bool canReturnToDirection;
  final List<DashboardNavAction> areaItems;
  final List<DashboardNavAction> accessItems;

  const ContabilidadAreaSidePanel({
    super.key,
    required this.label,
    required this.canReturnToDirection,
    required this.areaItems,
    this.accessItems = const <DashboardNavAction>[],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final visibleAccessItems = canReturnToDirection || accessItems.isNotEmpty;
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
              const _ContabilidadSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.glassSurface.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < areaItems.length; index++) ...[
                      _ContabilidadNavItem(action: areaItems[index]),
                      if (index != areaItems.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if (visibleAccessItems) ...[
                const SizedBox(height: 14),
                const _ContabilidadSectionHeader(label: 'ACCESOS'),
                const SizedBox(height: 8),
                for (var index = 0; index < accessItems.length; index++) ...[
                  _ContabilidadNavItem(action: accessItems[index]),
                  if (index != accessItems.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContabilidadSectionHeader extends StatelessWidget {
  final String label;

  const _ContabilidadSectionHeader({required this.label});

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

class _ContabilidadNavItem extends StatelessWidget {
  final DashboardNavAction action;

  const _ContabilidadNavItem({required this.action});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: action.onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: action.current
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x2867D2D8), Color(0x2287E6BF)],
                    )
                  : null,
              color: action.current
                  ? null
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: action.current ? 0.18 : 0.08,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: action.current
                        ? tokens.primary.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: action.current ? 0.18 : 0.08,
                      ),
                    ),
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.onGlass.withValues(alpha: 0.74),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  action.current
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: action.current
                      ? tokens.primary
                      : tokens.onGlass.withValues(alpha: 0.60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _noop() async {}
