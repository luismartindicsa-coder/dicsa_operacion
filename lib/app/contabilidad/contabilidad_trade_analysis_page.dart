import 'package:flutter/material.dart';

import 'contabilidad_area_chrome.dart';
import '../direction/direction_trade_analysis_page.dart';
import '../shared/page_routes.dart';
import 'contabilidad_dashboard_page.dart';
import 'contabilidad_flow_analysis_page.dart';
import 'contabilidad_income_statement_page.dart';
import 'contabilidad_theme.dart';

class ContabilidadTradeAnalysisPage extends StatelessWidget {
  final bool instantOpen;

  const ContabilidadTradeAnalysisPage({super.key, this.instantOpen = false});

  Future<void> _openContabilidadDashboard(BuildContext context) async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openTradeBalance(BuildContext context) async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ContabilidadTradeAnalysisPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openFlow(BuildContext context) async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadFlowAnalysisPage(instantOpen: true)),
    );
  }

  Future<void> _openIncomeStatement(BuildContext context) async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ContabilidadIncomeStatementPage(instantOpen: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DirectionTradeAnalysisPage(
      instantOpen: instantOpen,
      pageTitle: 'Resultado Comercial',
      areaLabel: 'RESULTADO COMERCIAL',
      areaDetail: 'Compra, venta y margen comercial del periodo',
      dashboardTitle: 'Dashboard Contabilidad',
      dashboardSubtitle: 'Vista base del área contable',
      currentMenuSubtitle: 'Costo, venta y margen del periodo',
      exportDialogTitle: 'Guardar Excel resultado comercial...',
      errorTitle: 'No se pudo cargar el resultado comercial.',
      onOpenDashboard: _openContabilidadDashboard,
      tokens: contabilidadAreaTokens,
      useContabilidadVisuals: true,
      sidePanelBuilder: (context, onOpenDashboard) => ContabilidadAreaSidePanel(
        label: 'Contabilidad',
        canReturnToDirection: false,
        areaItems: buildContabilidadAreaItems(
          current: ContabilidadAreaScreen.tradeBalance,
          onOpenTradeBalance: () => _openTradeBalance(context),
          onOpenFlujoGeneral: () => _openFlow(context),
          onOpenEstadoResultados: () => _openIncomeStatement(context),
        ),
        accessItems: buildContabilidadAccessItems(
          current: ContabilidadAreaScreen.tradeBalance,
          onOpenDashboard: () => _openContabilidadDashboard(context),
        ),
      ),
    );
  }
}
