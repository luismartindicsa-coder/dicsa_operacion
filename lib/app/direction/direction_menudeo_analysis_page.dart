import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'analysis/menudeo/menudeo_analysis_models.dart';
import 'analysis/menudeo/menudeo_analysis_pdf_report.dart';
import 'analysis/menudeo/menudeo_analysis_state.dart';
import 'analysis/menudeo/menudeo_cash_tab.dart';
import 'analysis/menudeo/menudeo_market_tab.dart';
import 'analysis/menudeo/menudeo_operations_tab.dart';
import 'direction_cash_entries_exits_page.dart';
import 'direction_cash_taxonomy_page.dart';
import 'direction_theme.dart';

class DirectionMenudeoAnalysisPage extends StatefulWidget {
  final bool instantOpen;

  const DirectionMenudeoAnalysisPage({super.key, this.instantOpen = false});

  @override
  State<DirectionMenudeoAnalysisPage> createState() =>
      _DirectionMenudeoAnalysisPageState();
}

class _DirectionMenudeoAnalysisPageState
    extends State<DirectionMenudeoAnalysisPage> {
  final MenudeoAnalysisState _state = MenudeoAnalysisState();
  bool _menuOpen = false;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    unawaited(_state.load());
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openVault() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashEntriesExitsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openVaultCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashTaxonomyPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _exportPdfReport() async {
    final market = _state.marketView;
    final cash = _state.cashDataset;
    final operation = _state.operationDataset;

    if (_state.loading) {
      _toast('Espera a que termine de cargar el análisis antes de exportar.');
      return;
    }
    if (_state.error != null) {
      _toast('Corrige primero el error del análisis antes de exportar.');
      return;
    }
    if (market == null || cash == null || operation == null) {
      _toast('No hay datos suficientes para generar el reporte.');
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      final bytes = await buildMenudeoAnalysisReportPdf(
        filters: _state.filters,
        market: market,
        cash: cash,
        operation: operation,
        generatedAt: DateTime.now(),
      );
      final suggestedName = _buildSuggestedPdfName(_state.filters);
      String? outputPath;
      if (!kIsWeb) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar reporte ejecutivo de menudeo como PDF',
          fileName: suggestedName,
          allowedExtensions: const ['pdf'],
          type: FileType.custom,
          lockParentWindow: true,
        );
      }
      if (outputPath == null || outputPath.trim().isEmpty) {
        _toast('Guardado cancelado.');
        return;
      }
      final normalized = outputPath.toLowerCase().endsWith('.pdf')
          ? outputPath
          : '$outputPath.pdf';
      await File(normalized).writeAsBytes(bytes, flush: true);
      _toast('Reporte PDF guardado: $normalized');
    } catch (error) {
      _toast('No se pudo generar el reporte PDF: $error');
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  String _buildSuggestedPdfName(MenudeoAnalysisFilters filters) {
    final range = filters.dateRange;
    if (range != null) {
      final start = _compactDate(range.start);
      final end = _compactDate(range.end);
      return 'direccion_menudeo_reporte_${start}_a_$end.pdf';
    }
    final now = DateTime.now();
    final stamp = _compactDate(now);
    return 'direccion_menudeo_reporte_${filters.windowDays}d_$stamp.pdf';
  }

  String _compactDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: directionAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _state,
          builder: (context, _) {
            return AppShell(
              background: const DirectionExecutiveBackground(),
              wrapBodyInGlass: false,
              animateHeaderSlots: false,
              animateBody: !widget.instantOpen,
              headerBodySpacing: 8,
              padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
              leadingBuilder: (_, _) => DirectionHeaderButton(
                label: _menuOpen ? 'Cerrar panel' : 'Navegación',
                icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
                onTapSync: () => setState(() => _menuOpen = !_menuOpen),
              ),
              centerBuilder: (_, contentAnim) => DirectionHeaderBrand(
                contentAnim: contentAnim,
                title: 'Análisis Menudeo',
              ),
              trailingBuilder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DirectionHeaderButton(
                    label: _exportingPdf ? 'Generando PDF...' : 'Reporte PDF',
                    icon: _exportingPdf
                        ? Icons.hourglass_top_rounded
                        : Icons.picture_as_pdf_rounded,
                    width: 186,
                    onTap: _exportingPdf ? null : _exportPdfReport,
                  ),
                  const SizedBox(width: 10),
                  DirectionHeaderButton(
                    label: 'Cerrar sesión',
                    icon: Icons.logout_rounded,
                    onTap: _logout,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 56, right: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                DirectionMetricCard(
                                  icon: Icons.storefront_rounded,
                                  title: 'ÁREA',
                                  value: 'MENUDEO',
                                  detail: 'Capa ejecutiva de análisis',
                                  accent: directionAreaTokens.primary,
                                ),
                                DirectionMetricCard(
                                  icon: Icons.insights_rounded,
                                  title: 'TAB ACTIVO',
                                  value: 'Mercado',
                                  detail: 'Primera entrega interactiva',
                                  accent: directionAreaTokens.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: DirectionGlassPanel(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  18,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                blurSigma: 30,
                                fillColor: kDirectionOliveDeep.withValues(
                                  alpha: 0.24,
                                ),
                                borderColor: Colors.white.withValues(
                                  alpha: 0.24,
                                ),
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.10,
                                ),
                                edgeHighlightColor: Colors.white.withValues(
                                  alpha: 0.62,
                                ),
                                bevelShadowColor: Colors.black.withValues(
                                  alpha: 0.16,
                                ),
                                glowColor: kDirectionOliveGlow.withValues(
                                  alpha: 0.10,
                                ),
                                child: DefaultTabController(
                                  length: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                          ),
                                        ),
                                        child: const TabBar(
                                          dividerColor: Colors.transparent,
                                          labelColor: kDirectionSurfaceText,
                                          unselectedLabelColor:
                                              kDirectionMutedText,
                                          indicatorSize:
                                              TabBarIndicatorSize.tab,
                                          indicator: BoxDecoration(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(16),
                                            ),
                                            gradient:
                                                kDirectionSelectionGradient,
                                          ),
                                          tabs: [
                                            Tab(text: 'Mercado'),
                                            Tab(text: 'Efectivo'),
                                            Tab(text: 'Operación'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            SingleChildScrollView(
                                              child: MenudeoMarketTab(
                                                state: _state,
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              child: MenudeoCashTab(
                                                state: _state,
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              child: MenudeoOperationsTab(
                                                state: _state,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_menuOpen,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _menuOpen ? 1 : 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _menuOpen = false),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: _menuOpen ? 0 : -332,
                    top: 0,
                    width: 320,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !_menuOpen,
                      child: SingleChildScrollView(
                        child: _DirectionMenudeoAnalysisMenu(
                          onOpenDashboard: _openDashboard,
                          onOpenVault: _openVault,
                          onOpenVaultCatalog: _openVaultCatalog,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DirectionMenudeoAnalysisMenu extends StatelessWidget {
  final Future<void> Function() onOpenDashboard;
  final Future<void> Function() onOpenVault;
  final Future<void> Function() onOpenVaultCatalog;

  const _DirectionMenudeoAnalysisMenu({
    required this.onOpenDashboard,
    required this.onOpenVault,
    required this.onOpenVaultCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return DirectionModuleMenuPanel(
      entries: [
        DirectionModuleMenuEntry(
          icon: Icons.home_work_rounded,
          title: 'Dashboard Dirección',
          subtitle: 'Vista general del área',
          onTap: () => unawaited(onOpenDashboard()),
        ),
        const DirectionModuleMenuEntry(
          icon: Icons.analytics_rounded,
          title: 'Análisis Menudeo',
          subtitle: 'Mercado, efectivo y operación',
          current: true,
        ),
        DirectionModuleMenuEntry(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Bóveda',
          subtitle: 'Captura operativa de efectivo',
          onTap: () => unawaited(onOpenVault()),
        ),
        DirectionModuleMenuEntry(
          icon: Icons.tune_rounded,
          title: 'Catálogo Bóveda',
          subtitle: 'Conceptos, personas y parámetros',
          onTap: () => unawaited(onOpenVaultCatalog()),
        ),
      ],
    );
  }
}
