import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'commercial_area_chrome.dart';
import 'commercial_directory_page.dart';
import 'commercial_store.dart';
import 'commercial_theme.dart';

class CommercialDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const CommercialDashboardPage({super.key, this.instantOpen = false});

  @override
  State<CommercialDashboardPage> createState() =>
      _CommercialDashboardPageState();
}

class _CommercialDashboardPageState extends State<CommercialDashboardPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  CommercialDashboardBundle? _bundle;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDashboard());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
    });
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final bundle = await CommercialStore.loadDashboard();
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const CommercialDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final alerts = bundle?.alerts ?? const <CommercialAlertRecord>[];
    final materials =
        bundle?.materialRows ?? const <CommercialMaterialSnapshotRecord>[];
    final counterparties =
        bundle?.counterpartyRows ??
        const <CommercialCounterpartyActivityRecord>[];
    final generalMaterials =
        bundle?.generalMaterialRows ??
        const <CommercialGeneralMaterialSnapshotRecord>[];
    final generalCounterparties =
        bundle?.generalCounterpartyRows ??
        const <CommercialGeneralCounterpartyActivityRecord>[];
    final catalogPriceRows =
        bundle?.catalogPriceRows ??
        const <CommercialCatalogPriceReferenceRecord>[];

    return AreaThemeScope(
      tokens: commercialAreaTokens,
      child: Theme(
        data: buildCommercialAreaTheme(Theme.of(context)),
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
          child: AppShell(
            background: const CommercialAreaBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => CommercialAreaHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _CommercialHeaderBrand(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommercialAreaHeaderButton(
                  label: 'Recargar',
                  icon: Icons.refresh_rounded,
                  compact: true,
                  onTap: _loadDashboard,
                ),
                const SizedBox(width: 10),
                CommercialAreaHeaderButton(
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
                    constraints: const BoxConstraints(maxWidth: 1520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                      child: _CommercialDashboardBody(
                        loading: _loading,
                        alerts: alerts,
                        materials: materials,
                        counterparties: counterparties,
                        generalMaterials: generalMaterials,
                        generalCounterparties: generalCounterparties,
                        catalogPriceRows: catalogPriceRows,
                        onOpenDirectory: _openDirectory,
                        onReload: _loadDashboard,
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
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _menuOpen ? 0 : -332,
                  top: 0,
                  bottom: 0,
                  width: 320,
                  child: IgnorePointer(
                    ignoring: !_menuOpen,
                    child: CommercialAreaSidePanel(
                      label: 'Desarrollo Comercial',
                      canReturnToDirection: _canReturnToDirection,
                      areaItems: [
                        const CommercialAreaNavEntry(
                          icon: Icons.radar_rounded,
                          title: 'Radar Comercial',
                          subtitle: 'Precio, alertas y contexto',
                          accented: true,
                        ),
                        CommercialAreaNavEntry(
                          icon: Icons.badge_outlined,
                          title: 'Directorio Comercial',
                          subtitle: 'Cuentas, contactos y seguimiento',
                          onTap: _openDirectory,
                        ),
                      ],
                      accessItems: [
                        if (_canReturnToDirection)
                          CommercialAreaNavEntry(
                            icon: Icons.assessment_outlined,
                            title: 'Dashboard Dirección',
                            subtitle: 'Vista ejecutiva multiarea',
                            onTap: _openDirectionDashboard,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CommercialChannelFilter { ambos, menudeo, mayoreo }

enum _CommercialFlowFilter { ambos, compra, venta }

class _CommercialDashboardBody extends StatefulWidget {
  final bool loading;
  final List<CommercialAlertRecord> alerts;
  final List<CommercialMaterialSnapshotRecord> materials;
  final List<CommercialCounterpartyActivityRecord> counterparties;
  final List<CommercialGeneralMaterialSnapshotRecord> generalMaterials;
  final List<CommercialGeneralCounterpartyActivityRecord> generalCounterparties;
  final List<CommercialCatalogPriceReferenceRecord> catalogPriceRows;
  final Future<void> Function() onOpenDirectory;
  final Future<void> Function() onReload;

  const _CommercialDashboardBody({
    required this.loading,
    required this.alerts,
    required this.materials,
    required this.counterparties,
    required this.generalMaterials,
    required this.generalCounterparties,
    required this.catalogPriceRows,
    required this.onOpenDirectory,
    required this.onReload,
  });

  @override
  State<_CommercialDashboardBody> createState() =>
      _CommercialDashboardBodyState();
}

class _CommercialDashboardBodyState extends State<_CommercialDashboardBody> {
  _CommercialChannelFilter _channel = _CommercialChannelFilter.ambos;
  _CommercialFlowFilter _flow = _CommercialFlowFilter.ambos;
  String? _selectedMaterial;
  bool _onlyComparable = false;

  @override
  Widget build(BuildContext context) {
    final materialOptions =
        widget.catalogPriceRows
            .map((row) => row.generalMaterialLabel.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final filteredAlerts = widget.alerts
        .where((alert) {
          if (!_matchesChannel(alert.channel)) return false;
          if (!_matchesFlow(alert.flow)) return false;
          return _selectedMaterial == null ||
              _matchesGeneralMaterial(alert.materialLabel, _selectedMaterial!);
        })
        .toList(growable: false);

    final filteredCommercialRows = widget.materials
        .where((row) {
          if (!_matchesChannel(row.channel)) return false;
          if (_selectedMaterial == null) return true;
          return _matchesGeneralMaterial(row.materialLabel, _selectedMaterial!);
        })
        .toList(growable: false);

    final filteredCatalogRows = widget.catalogPriceRows
        .where((row) {
          if (!_matchesChannel(row.channel)) return false;
          if (!_matchesFlow(row.flow)) return false;
          if (_selectedMaterial != null &&
              row.generalMaterialLabel != _selectedMaterial) {
            return false;
          }
          return row.finalPrice > 0;
        })
        .toList(growable: false);

    final buyRows = _buildPriceRadarRows(
      filteredCatalogRows,
      flow: 'purchase',
      onlyComparable: _onlyComparable,
    );
    final sellRows = _buildPriceRadarRows(
      filteredCatalogRows,
      flow: 'sale',
      onlyComparable: _onlyComparable,
    );
    final positioningRows = _buildPositioningRows(
      filteredCatalogRows,
      onlyComparable: _onlyComparable,
    );
    final recentReferences = filteredCatalogRows.toList(growable: false)
      ..sort((a, b) {
        final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    final recentMaterialChanges = _buildRecentMaterialChanges(recentReferences);
    final opportunities = _buildOpportunityRows(
      filteredCommercialRows,
      selectedMaterial: _selectedMaterial,
    );
    final insights = _buildInsights(
      alerts: filteredAlerts,
      buyRows: buyRows,
      sellRows: sellRows,
      positioningRows: positioningRows,
      catalogRows: filteredCatalogRows,
      opportunities: opportunities,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1180;
        return ListView(
          children: [
            _CommercialFiltersBar(
              materialOptions: materialOptions,
              channel: _channel,
              flow: _flow,
              selectedMaterial: _selectedMaterial,
              onlyComparable: _onlyComparable,
              onReload: widget.onReload,
              onOpenDirectory: widget.onOpenDirectory,
              onChannelChanged: (value) => setState(() => _channel = value),
              onFlowChanged: (value) => setState(() => _flow = value),
              onMaterialChanged: (value) =>
                  setState(() => _selectedMaterial = value),
              onComparableChanged: () =>
                  setState(() => _onlyComparable = !_onlyComparable),
            ),
            const SizedBox(height: 14),
            _CommercialInsightsCard(
              loading: widget.loading,
              insights: insights,
              channel: _channel,
              flow: _flow,
            ),
            const SizedBox(height: 14),
            if (stacked)
              Column(
                children: [
                  _PriceRadarCard(
                    loading: widget.loading,
                    flow: _flow,
                    buyRows: buyRows,
                    sellRows: sellRows,
                    onOpenDirectory: widget.onOpenDirectory,
                  ),
                  const SizedBox(height: 14),
                  _PricePositioningCard(
                    loading: widget.loading,
                    rows: positioningRows,
                    selectedMaterial: _selectedMaterial,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _PriceRadarCard(
                      loading: widget.loading,
                      flow: _flow,
                      buyRows: buyRows,
                      sellRows: sellRows,
                      onOpenDirectory: widget.onOpenDirectory,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: _PricePositioningCard(
                      loading: widget.loading,
                      rows: positioningRows,
                      selectedMaterial: _selectedMaterial,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            if (stacked)
              Column(
                children: [
                  _RecentReferencesCard(
                    loading: widget.loading,
                    rows: recentMaterialChanges,
                  ),
                  const SizedBox(height: 14),
                  _AlertsPanel(
                    loading: widget.loading,
                    alerts: filteredAlerts,
                    onOpenDirectory: widget.onOpenDirectory,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: _RecentReferencesCard(
                      loading: widget.loading,
                      rows: recentMaterialChanges,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: _AlertsPanel(
                      loading: widget.loading,
                      alerts: filteredAlerts,
                      onOpenDirectory: widget.onOpenDirectory,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  bool _matchesChannel(String value) {
    return switch (_channel) {
      _CommercialChannelFilter.ambos => true,
      _CommercialChannelFilter.menudeo => value == 'menudeo',
      _CommercialChannelFilter.mayoreo => value == 'mayoreo',
    };
  }

  bool _matchesFlow(String value) {
    return switch (_flow) {
      _CommercialFlowFilter.ambos => true,
      _CommercialFlowFilter.compra => value == 'purchase',
      _CommercialFlowFilter.venta => value == 'sale',
    };
  }
}

class _CommercialHeaderBrand extends StatelessWidget {
  const _CommercialHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 12),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Radar Comercial',
              maxLines: 1,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.25,
                height: 1.0,
                color: Color(0xFFF0E9D1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Radar de precios y contexto comercial para menudeo y mayoreo',
              style: TextStyle(
                color: tokens.badgeText.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommercialFiltersBar extends StatelessWidget {
  final List<String> materialOptions;
  final _CommercialChannelFilter channel;
  final _CommercialFlowFilter flow;
  final String? selectedMaterial;
  final bool onlyComparable;
  final Future<void> Function() onReload;
  final Future<void> Function() onOpenDirectory;
  final ValueChanged<_CommercialChannelFilter> onChannelChanged;
  final ValueChanged<_CommercialFlowFilter> onFlowChanged;
  final ValueChanged<String?> onMaterialChanged;
  final VoidCallback onComparableChanged;

  const _CommercialFiltersBar({
    required this.materialOptions,
    required this.channel,
    required this.flow,
    required this.selectedMaterial,
    required this.onlyComparable,
    required this.onReload,
    required this.onOpenDirectory,
    required this.onChannelChanged,
    required this.onFlowChanged,
    required this.onMaterialChanged,
    required this.onComparableChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1260;
        final leftCluster = _FilterClusterCard(
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterGroup<_CommercialChannelFilter>(
                label: 'Canal',
                value: channel,
                items: const [
                  _FilterOption(
                    value: _CommercialChannelFilter.ambos,
                    label: 'Ambos',
                  ),
                  _FilterOption(
                    value: _CommercialChannelFilter.menudeo,
                    label: 'Menudeo',
                  ),
                  _FilterOption(
                    value: _CommercialChannelFilter.mayoreo,
                    label: 'Mayoreo',
                  ),
                ],
                onChanged: onChannelChanged,
              ),
              _FilterDivider(),
              _FilterGroup<_CommercialFlowFilter>(
                label: 'Flujo',
                value: flow,
                items: const [
                  _FilterOption(
                    value: _CommercialFlowFilter.ambos,
                    label: 'Ambos',
                  ),
                  _FilterOption(
                    value: _CommercialFlowFilter.compra,
                    label: 'Compra',
                  ),
                  _FilterOption(
                    value: _CommercialFlowFilter.venta,
                    label: 'Venta',
                  ),
                ],
                onChanged: onFlowChanged,
              ),
            ],
          ),
        );
        final rightCluster = _FilterClusterCard(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MaterialDropdown(
                options: materialOptions,
                value: selectedMaterial,
                onChanged: onMaterialChanged,
              ),
              _CompactToggleChip(
                label: 'Solo comparables',
                selected: onlyComparable,
                icon: Icons.filter_alt_outlined,
                onTap: onComparableChanged,
              ),
              _ActionOutlineChip(
                label: 'Recargar',
                icon: Icons.refresh_rounded,
                onTap: onReload,
              ),
              _ActionFilledChip(
                label: 'Nueva cuenta',
                icon: Icons.add_rounded,
                onTap: onOpenDirectory,
              ),
            ],
          ),
        );
        if (stacked) {
          return Column(
            children: [leftCluster, const SizedBox(height: 12), rightCluster],
          );
        }
        return Row(
          children: [
            Expanded(flex: 11, child: leftCluster),
            const SizedBox(width: 12),
            Expanded(flex: 13, child: rightCluster),
          ],
        );
      },
    );
  }
}

class _CommercialInsightsCard extends StatelessWidget {
  final bool loading;
  final _CommercialInsights insights;
  final _CommercialChannelFilter channel;
  final _CommercialFlowFilter flow;

  const _CommercialInsightsCard({
    required this.loading,
    required this.insights,
    required this.channel,
    required this.flow,
  });

  @override
  Widget build(BuildContext context) {
    final tone = AreaThemeScope.of(context);
    return _DashboardSectionCard(
      title: 'Lectura ejecutiva',
      subtitle:
          'Radar comercial inspirado en Mercado, con menudeo y mayoreo separados',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1180;
          final metricCards = [
            _ExecutiveMetricCard(
              label: 'Materiales con referencia',
              value: '${insights.materialsWithReference}',
              icon: Icons.inventory_2_outlined,
              tone: const Color(0xFF78DA7A),
              subtitle: 'Con datos comparables',
            ),
            _ExecutiveMetricCard(
              label: 'Cruces comparables',
              value: '${insights.comparableSegments}',
              icon: Icons.hub_outlined,
              tone: const Color(0xFF5CCEE6),
              subtitle: 'Oportunidades de cruce',
            ),
            _ExecutiveMetricCard(
              label: 'Alertas activas',
              value: '${insights.activeAlerts}',
              icon: Icons.warning_amber_rounded,
              tone: const Color(0xFFEA6C47),
              subtitle: 'A revisar hoy',
            ),
            _ExecutiveMetricCard(
              label: 'Contrapartes con precio',
              value: '${insights.counterpartiesWithReference}',
              icon: Icons.groups_2_outlined,
              tone: const Color(0xFF68D3B4),
              subtitle: 'Proveedores y clientes',
            ),
          ];
          final metrics = GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: stacked ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: stacked ? 198 : 186,
            ),
            itemCount: metricCards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) => metricCards[index],
          );
          final bullets = loading
              ? const _PanelLoading(label: 'Preparando lectura ejecutiva...')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InsightBullet(
                      text:
                          'Vista actual: ${_channelFilterLabel(channel)} · ${_flowFilterLabel(flow)}.',
                      tone: tone.badgeText,
                    ),
                    _InsightBullet(
                      text: insights.primaryMessage,
                      tone: const Color(0xFFF0C247),
                    ),
                    _InsightBullet(
                      text: insights.secondaryMessage,
                      tone: const Color(0xFF8FDC84),
                    ),
                    _InsightBullet(
                      text: insights.tertiaryMessage,
                      tone: tone.badgeText,
                    ),
                  ],
                );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [metrics, const SizedBox(height: 14), bullets],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: metrics),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: bullets),
            ],
          );
        },
      ),
    );
  }
}

class _PriceRadarCard extends StatelessWidget {
  final bool loading;
  final _CommercialFlowFilter flow;
  final List<_PriceRadarRow> buyRows;
  final List<_PriceRadarRow> sellRows;
  final Future<void> Function() onOpenDirectory;

  const _PriceRadarCard({
    required this.loading,
    required this.flow,
    required this.buyRows,
    required this.sellRows,
    required this.onOpenDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final showBuy = flow != _CommercialFlowFilter.venta;
    final showSell = flow != _CommercialFlowFilter.compra;
    return _DashboardSectionCard(
      title: 'Radar de precios',
      subtitle:
          'Precio observado 30d por material general, sin mezclar canales',
      child: Column(
        children: [
          if (showBuy)
            _PriceRadarSection(
              title: 'Compra',
              tone: const Color(0xFFE7A74D),
              loading: loading,
              rows: buyRows,
              emptyLabel:
                  'No hay referencias de compra suficientes para el filtro actual.',
            ),
          if (showBuy && showSell) const SizedBox(height: 16),
          if (showBuy && showSell)
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          if (showBuy && showSell) const SizedBox(height: 16),
          if (showSell)
            _PriceRadarSection(
              title: 'Venta',
              tone: const Color(0xFF7DDA7E),
              loading: loading,
              rows: sellRows,
              emptyLabel:
                  'No hay referencias de venta suficientes para el filtro actual.',
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _PanelActionButton(
              label: 'Ver todos los materiales',
              onTap: onOpenDirectory,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRadarSection extends StatelessWidget {
  final String title;
  final Color tone;
  final bool loading;
  final List<_PriceRadarRow> rows;
  final String emptyLabel;

  const _PriceRadarSection({
    required this.title,
    required this.tone,
    required this.loading,
    required this.rows,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CompactToggleChip(label: title, selected: true, onTap: () {}),
            const SizedBox(width: 8),
            _CompactToggleChip(
              label: 'Menudeo vs Mayoreo',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PanelTableHeader(
          columns: const [
            'Material general',
            'Menudeo',
            'Mayoreo',
            'Lectura',
            '',
          ],
          flexes: const [26, 19, 19, 24, 12],
        ),
        const SizedBox(height: 8),
        if (loading)
          const _PanelLoading(label: 'Cargando referencias de precio...')
        else if (rows.isEmpty)
          _EmptyPanelText(label: emptyLabel)
        else
          for (var index = 0; index < rows.length; index++) ...[
            _PriceRadarTableRow(row: rows[index], tone: tone),
            if (index < rows.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PricePositioningCard extends StatelessWidget {
  final bool loading;
  final List<_PricePositioningRow> rows;
  final String? selectedMaterial;

  const _PricePositioningCard({
    required this.loading,
    required this.rows,
    required this.selectedMaterial,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionCard(
      title: 'Posición de precios',
      subtitle: selectedMaterial == null
          ? 'Rangos por material, canal y flujo'
          : 'Rango observado para $selectedMaterial',
      child: Column(
        children: [
          _PanelTableHeader(
            columns: const [
              'Segmento',
              'Bajo',
              'Ref.',
              'Alto',
              'Rango',
              'Muestras',
            ],
            flexes: const [28, 12, 12, 12, 26, 10],
          ),
          const SizedBox(height: 8),
          if (loading)
            const _PanelLoading(label: 'Calculando rangos observados...')
          else if (rows.isEmpty)
            _EmptyPanelText(
              label:
                  'No hay suficientes contrapartes con precio para posicionar este filtro.',
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              _PositioningTableRow(row: rows[index]),
              if (index < rows.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _RecentReferencesCard extends StatelessWidget {
  final bool loading;
  final List<_MaterialActivityRow> rows;

  const _RecentReferencesCard({required this.loading, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionCard(
      title: 'Cambios recientes por material',
      subtitle: 'Resumen de movimientos recientes sin listar todos los ajustes',
      child: loading
          ? const _PanelLoading(label: 'Cargando cambios recientes...')
          : rows.isEmpty
          ? _EmptyPanelText(
              label:
                  'Todavía no hay cambios recientes de precio para el filtro actual.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width > 1180
                    ? (width - 60) / 6
                    : width > 860
                    ? (width - 36) / 4
                    : width > 560
                    ? (width - 12) / 2
                    : width;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final row in rows.take(8))
                      SizedBox(
                        width: cardWidth,
                        child: _RecentReferenceTile(row: row),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  final bool loading;
  final List<CommercialAlertRecord> alerts;
  final Future<void> Function() onOpenDirectory;

  const _AlertsPanel({
    required this.loading,
    required this.alerts,
    required this.onOpenDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final prioritized = alerts.toList(growable: false)
      ..sort((a, b) {
        final severityCompare = _alertSeverityRank(
          b.severity,
        ).compareTo(_alertSeverityRank(a.severity));
        if (severityCompare != 0) return severityCompare;
        final deltaA = a.deltaPercent?.abs() ?? 0;
        final deltaB = b.deltaPercent?.abs() ?? 0;
        return deltaB.compareTo(deltaA);
      });
    final visibleAlerts = prioritized.take(8).toList(growable: false);
    final criticalCount = alerts
        .where((item) => item.severity == 'critica')
        .length;
    final attentionCount = alerts
        .where((item) => item.severity == 'atencion')
        .length;
    final infoCount = alerts.length - criticalCount - attentionCount;
    return _DashboardSectionCard(
      title: 'Alertas de variación',
      subtitle: 'A quién marcar hoy y qué validar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const _PanelLoading(label: 'Cargando alertas...')
          else if (alerts.isEmpty)
            _EmptyPanelText(
              label: 'No hay alertas activas para el filtro seleccionado.',
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AlertSummaryChip(label: 'Críticas', value: criticalCount),
                _AlertSummaryChip(label: 'Atención', value: attentionCount),
                if (infoCount > 0)
                  _AlertSummaryChip(label: 'Informativas', value: infoCount),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 760),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleAlerts.length;
                      index++
                    ) ...[
                      _AlertTile(alert: visibleAlerts[index]),
                      if (index < visibleAlerts.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            if (alerts.length > visibleAlerts.length) ...[
              const SizedBox(height: 10),
              Text(
                'Mostrando ${visibleAlerts.length} de ${alerts.length} alertas priorizadas.',
                style: TextStyle(
                  color: AreaThemeScope.of(context).badgeText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _PanelActionButton(
              label: 'Ver todas las alertas',
              onTap: onOpenDirectory,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertSummaryChip extends StatelessWidget {
  final String label;
  final int value;

  const _AlertSummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: label == 'Críticas'
            ? const Color(0x33FF4D3D)
            : const Color(0x4D101713),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: label == 'Críticas'
              ? const Color(0x66FF4D3D)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: label == 'Críticas'
              ? const Color(0xFFF3F1E8)
              : const Color(0xADF3F1E8),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DashboardSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5A000000),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xADF3F1E8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PanelTableHeader extends StatelessWidget {
  final List<String> columns;
  final List<int> flexes;

  const _PanelTableHeader({required this.columns, required this.flexes});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            Expanded(
              flex: flexes[index],
              child: Text(
                columns[index],
                style: TextStyle(
                  color: tokens.badgeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceRadarTableRow extends StatelessWidget {
  final _PriceRadarRow row;
  final Color tone;

  const _PriceRadarTableRow({required this.row, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final materialTone = _materialTone(row.label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x91212E27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 26,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: materialTone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: materialTone.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    _materialIcon(row.label),
                    color: materialTone,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: tokens.onGlass,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 19,
            child: _PriceCell(
              value: row.menudeoPrice,
              tone: const Color(0xFFF2C94C),
            ),
          ),
          Expanded(
            flex: 19,
            child: _PriceCell(
              value: row.mayoreoPrice,
              tone: const Color(0xFF41D978),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              row.reading,
              style: TextStyle(
                color: row.menudeoPrice != null && row.mayoreoPrice != null
                    ? tone
                    : tokens.badgeText,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 78,
                height: 28,
                child: _MiniSparkline(
                  color: _sparklineToneForRow(row),
                  values: _sparklineValuesForRow(row),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositioningTableRow extends StatelessWidget {
  final _PricePositioningRow row;

  const _PositioningTableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = row.flow == 'purchase'
        ? const Color(0xFFE7A74D)
        : const Color(0xFF7DDA7E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x91212E27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_flowLabel(row.flow)} · ${row.channel}',
                  style: TextStyle(color: tokens.badgeText, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: _InlinePrice(value: row.low, tone: tone),
          ),
          Expanded(
            flex: 12,
            child: _InlinePrice(value: row.average, tone: tone),
          ),
          Expanded(
            flex: 12,
            child: _InlinePrice(value: row.high, tone: tone),
          ),
          Expanded(
            flex: 26,
            child: _PositionRangeLine(
              low: row.low,
              average: row.average,
              high: row.high,
              tone: tone,
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              '${row.samples}',
              style: TextStyle(
                color: tokens.badgeText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterClusterCard extends StatelessWidget {
  final Widget child;

  const _FilterClusterCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x59101913),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: DefaultTextStyle(
            style: TextStyle(color: tokens.onGlass),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FilterDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _ActionFilledChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _ActionFilledChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF183826),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2D6E49)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF41D978), size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionOutlineChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _ActionOutlineChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0x4D101713),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tokens.badgeText, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: tokens.badgeText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final String subtitle;

  const _ExecutiveMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xADF3F1E8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xADF3F1E8),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PositionRangeLine extends StatelessWidget {
  final double low;
  final double average;
  final double high;
  final Color tone;

  const _PositionRangeLine({
    required this.low,
    required this.average,
    required this.high,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final span = (high - low).abs();
    final markerFraction = span < 0.0001
        ? 0.5
        : ((average - low) / span).clamp(0.0, 1.0);
    return SizedBox(
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment(-1 + (markerFraction * 2), 0),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReferenceTile extends StatelessWidget {
  final _MaterialActivityRow row;

  const _RecentReferenceTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = _materialTone(row.materialLabel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tone.withValues(alpha: 0.24)),
                ),
                child: Icon(
                  _materialIcon(row.materialLabel),
                  color: tone,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.materialLabel,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                row.priceBandLabel.replaceAll(' a ', ' → '),
                style: TextStyle(color: tone, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.summaryLabel,
            style: TextStyle(
              color: tokens.badgeText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Último cambio ${_formatShortDate(row.lastUpdatedAt)}',
            style: TextStyle(color: tokens.badgeText, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${row.referenceCount} referencias tocadas',
            style: TextStyle(color: tokens.badgeText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilterGroup<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<_FilterOption<T>> items;
  final ValueChanged<T> onChanged;

  const _FilterGroup({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.badgeText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _CompactToggleChip(
                label: item.label,
                selected: item.value == value,
                onTap: () => onChanged(item.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterOption<T> {
  final T value;
  final String label;

  const _FilterOption({required this.value, required this.label});
}

class _MaterialDropdown extends StatelessWidget {
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _MaterialDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x4D101713),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          dropdownColor: const Color(0xFF1A241F),
          style: const TextStyle(
            color: Color(0xFFF3F1E8),
            fontWeight: FontWeight.w700,
          ),
          iconEnabledColor: const Color(0xADF3F1E8),
          hint: Text(
            'Material general',
            style: TextStyle(color: tokens.badgeText),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Todos los materiales',
                style: TextStyle(
                  color: Color(0xFFF3F1E8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String?>(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(
                    color: Color(0xFFF3F1E8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CompactToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _CompactToggleChip({
    required this.label,
    required this.selected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final fill = selected
        ? const Color(0xFF183826)
        : Colors.white.withValues(alpha: 0.04);
    final border = selected
        ? const Color(0xFF41D978)
        : Colors.white.withValues(alpha: 0.08);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? const Color(0xFFF3F1E8) : tokens.badgeText,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFF3F1E8) : tokens.badgeText,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightBullet extends StatelessWidget {
  final String text;
  final Color tone;

  const _InsightBullet({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 8, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.onGlass,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  final double? value;
  final Color tone;

  const _PriceCell({required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final visualValue = value == null ? 0.0 : value!.clamp(0.0, 250.0) / 250.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value == null ? 'Sin ref.' : formatMoney(value!),
            style: TextStyle(
              color: value == null ? tokens.badgeText : tone,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: Colors.white.withValues(alpha: 0.08),
              child: FractionallySizedBox(
                widthFactor: visualValue,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _MiniSparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final dx = (size.width / (values.length - 1)) * index;
      final normalized = (values[index] - minValue) / span;
      final dy = size.height - (normalized * (size.height - 4)) - 2;
      if (index == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

Color _materialTone(String label) {
  final key = _normalizeLabel(label);
  if (key.contains('METAL')) return const Color(0xFF69A8FF);
  if (key.contains('MADERA')) return const Color(0xFFF2994A);
  if (key.contains('PLAST')) return const Color(0xFF41D978);
  if (key.contains('TEXTIL')) return const Color(0xFFF2C94C);
  if (key.contains('VIDRIO')) return const Color(0xFF56CCF2);
  if (key.contains('PAPEL')) return const Color(0xFFD8A84F);
  if (key.contains('CARTON')) return const Color(0xFF6F8CFF);
  if (key.contains('CHATARRA')) return const Color(0xFF7BE27F);
  return const Color(0xFFB27CFF);
}

IconData _materialIcon(String label) {
  final key = _normalizeLabel(label);
  if (key.contains('METAL')) return Icons.settings_input_component_outlined;
  if (key.contains('MADERA')) return Icons.texture_outlined;
  if (key.contains('PLAST')) return Icons.recycling_outlined;
  if (key.contains('TEXTIL')) return Icons.checkroom_outlined;
  if (key.contains('VIDRIO')) return Icons.window_outlined;
  if (key.contains('PAPEL')) return Icons.description_outlined;
  if (key.contains('CARTON')) return Icons.inventory_2_outlined;
  if (key.contains('CHATARRA')) return Icons.delete_outline_rounded;
  return Icons.grid_view_rounded;
}

Color _sparklineToneForRow(_PriceRadarRow row) {
  if (row.menudeoPrice != null && row.mayoreoPrice != null) {
    final delta = (row.mayoreoPrice! - row.menudeoPrice!).abs();
    if (delta < 0.01) return const Color(0xFFF2C94C);
    return row.mayoreoPrice! > row.menudeoPrice!
        ? const Color(0xFF41D978)
        : const Color(0xFFF2994A);
  }
  return row.mayoreoPrice != null
      ? const Color(0xFF41D978)
      : const Color(0xFFF2994A);
}

List<double> _sparklineValuesForRow(_PriceRadarRow row) {
  final baseline = row.mayoreoPrice ?? row.menudeoPrice ?? 1.0;
  final contrast = row.menudeoPrice == null || row.mayoreoPrice == null
      ? baseline * 0.32
      : (row.mayoreoPrice! - row.menudeoPrice!).abs().clamp(0.12, baseline);
  return [
    baseline * 0.62,
    baseline * 0.64,
    baseline * 0.6,
    baseline * 0.72,
    baseline * 0.68,
    baseline * 0.94,
    baseline * 0.74,
    baseline + (contrast * 0.08),
  ];
}

class _InlinePrice extends StatelessWidget {
  final double value;
  final Color tone;

  const _InlinePrice({required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoney(value),
      style: TextStyle(
        color: tone,
        fontWeight: FontWeight.w900,
        fontSize: 12.5,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final CommercialAlertRecord alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = switch (alert.severity) {
      'critica' => const Color(0xFFCC4B37),
      'atencion' => const Color(0xFFF0B33F),
      _ => const Color(0xFF70D68B),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${alert.channel} · ${_readableBusinessGroup(alert.businessGroup)}',
                        style: TextStyle(
                          color: tokens.badgeText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (alert.deltaPercent != null)
                      Text(
                        '${alert.deltaPercent!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${alert.entityLabel.isEmpty ? alert.materialLabel : alert.entityLabel} · ${alert.materialLabel}',
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alert.suggestedAction,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            height: 54,
            child: _MiniSparkline(
              color: tone,
              values: [1.0, 0.96, 0.94, 0.9, 0.62, 0.58, 0.53, 0.49],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelActionButton extends StatelessWidget {
  final String label;
  final Future<void> Function() onTap;

  const _PanelActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x4D101713),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: tokens.badgeText),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelLoading extends StatelessWidget {
  final String label;

  const _PanelLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: tokens.badgeText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanelText extends StatelessWidget {
  final String label;

  const _EmptyPanelText({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: TextStyle(color: tokens.badgeText, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PriceRadarRow {
  final String label;
  final double? menudeoPrice;
  final double? mayoreoPrice;
  final String reading;

  const _PriceRadarRow({
    required this.label,
    required this.menudeoPrice,
    required this.mayoreoPrice,
    required this.reading,
  });
}

class _PricePositioningRow {
  final String label;
  final String channel;
  final String flow;
  final double low;
  final double average;
  final double high;
  final int samples;

  const _PricePositioningRow({
    required this.label,
    required this.channel,
    required this.flow,
    required this.low,
    required this.average,
    required this.high,
    required this.samples,
  });
}

class _CommercialOpportunityRow {
  final String materialLabel;
  final String businessGroup;
  final String channel;
  final double buyPrice;
  final double sellPrice;
  final double spread;
  final double buyFraction;
  final double sellFraction;

  const _CommercialOpportunityRow({
    required this.materialLabel,
    required this.businessGroup,
    required this.channel,
    required this.buyPrice,
    required this.sellPrice,
    required this.spread,
    required this.buyFraction,
    required this.sellFraction,
  });
}

class _MaterialActivityRow {
  final String materialLabel;
  final DateTime? lastUpdatedAt;
  final int referenceCount;
  final Set<String> channels;
  final Set<String> flows;
  final double minPrice;
  final double maxPrice;

  const _MaterialActivityRow({
    required this.materialLabel,
    required this.lastUpdatedAt,
    required this.referenceCount,
    required this.channels,
    required this.flows,
    required this.minPrice,
    required this.maxPrice,
  });

  String get summaryLabel {
    final channelText = channels.toList()..sort();
    final flowText = flows.map(_flowLabel).toList()..sort();
    return '${channelText.join(' + ')} · ${flowText.join(' + ')}';
  }

  String get priceBandLabel {
    if ((maxPrice - minPrice).abs() < 0.01) return formatMoney(maxPrice);
    return '${formatMoney(minPrice)} a ${formatMoney(maxPrice)}';
  }
}

class _CommercialInsights {
  final int materialsWithReference;
  final int comparableSegments;
  final int activeAlerts;
  final int counterpartiesWithReference;
  final String primaryMessage;
  final String secondaryMessage;
  final String tertiaryMessage;

  const _CommercialInsights({
    required this.materialsWithReference,
    required this.comparableSegments,
    required this.activeAlerts,
    required this.counterpartiesWithReference,
    required this.primaryMessage,
    required this.secondaryMessage,
    required this.tertiaryMessage,
  });
}

List<_PriceRadarRow> _buildPriceRadarRows(
  List<CommercialCatalogPriceReferenceRecord> rows, {
  required String flow,
  required bool onlyComparable,
}) {
  final grouped = <String, Map<String, List<double>>>{};
  for (final row in rows) {
    if (row.flow != flow || row.finalPrice <= 0) continue;
    final channelKey = row.channel == 'mayoreo' ? 'mayoreo' : 'menudeo';
    grouped.putIfAbsent(
      row.generalMaterialLabel,
      () => <String, List<double>>{},
    );
    grouped[row.generalMaterialLabel]!
        .putIfAbsent(channelKey, () => <double>[])
        .add(row.finalPrice);
  }

  final result = <_PriceRadarRow>[];
  for (final entry in grouped.entries) {
    final menPrices = entry.value['menudeo'] ?? const <double>[];
    final mayPrices = entry.value['mayoreo'] ?? const <double>[];
    final menudeoPrice = menPrices.isEmpty
        ? null
        : menPrices.reduce((left, right) => left + right) / menPrices.length;
    final mayoreoPrice = mayPrices.isEmpty
        ? null
        : mayPrices.reduce((left, right) => left + right) / mayPrices.length;
    if (onlyComparable && (menudeoPrice == null || mayoreoPrice == null)) {
      continue;
    }
    result.add(
      _PriceRadarRow(
        label: entry.key,
        menudeoPrice: menudeoPrice,
        mayoreoPrice: mayoreoPrice,
        reading: _priceReading(menudeoPrice, mayoreoPrice),
      ),
    );
  }

  result.sort((a, b) {
    final aScore = (a.menudeoPrice ?? 0) + (a.mayoreoPrice ?? 0);
    final bScore = (b.menudeoPrice ?? 0) + (b.mayoreoPrice ?? 0);
    return bScore.compareTo(aScore);
  });
  return result;
}

List<_PricePositioningRow> _buildPositioningRows(
  List<CommercialCatalogPriceReferenceRecord> rows, {
  required bool onlyComparable,
}) {
  final grouped = <String, List<double>>{};
  final metadata = <String, CommercialCatalogPriceReferenceRecord>{};
  for (final row in rows) {
    if (row.finalPrice <= 0) continue;
    final key = '${row.generalMaterialLabel}|${row.channel}|${row.flow}';
    grouped.putIfAbsent(key, () => <double>[]).add(row.finalPrice);
    metadata[key] = row;
  }

  final result = <_PricePositioningRow>[];
  for (final entry in grouped.entries) {
    if (onlyComparable && entry.value.length < 2) continue;
    final values = entry.value.toList()..sort();
    final sample = metadata[entry.key]!;
    final average =
        values.reduce((left, right) => left + right) / values.length;
    result.add(
      _PricePositioningRow(
        label: sample.generalMaterialLabel,
        channel: sample.channel,
        flow: sample.flow,
        low: values.first,
        average: average,
        high: values.last,
        samples: values.length,
      ),
    );
  }

  result.sort((a, b) => b.samples.compareTo(a.samples));
  return result;
}

List<_CommercialOpportunityRow> _buildOpportunityRows(
  List<CommercialMaterialSnapshotRecord> rows, {
  required String? selectedMaterial,
}) {
  final filtered = rows
      .where((row) {
        if (row.avgBuyPrice30d == null || row.avgSellPrice30d == null) {
          return false;
        }
        if (selectedMaterial == null) return true;
        return _matchesGeneralMaterial(row.materialLabel, selectedMaterial);
      })
      .toList(growable: false);

  final result =
      filtered
          .map((row) {
            final buy = row.avgBuyPrice30d!;
            final sell = row.avgSellPrice30d!;
            final high = buy > sell ? buy : sell;
            return _CommercialOpportunityRow(
              materialLabel: row.materialLabel,
              businessGroup: _readableBusinessGroup(row.businessGroup),
              channel: row.channel,
              buyPrice: buy,
              sellPrice: sell,
              spread: sell - buy,
              buyFraction: high <= 0 ? 0 : buy / high,
              sellFraction: high <= 0 ? 0 : sell / high,
            );
          })
          .where((row) => row.spread > 0)
          .toList(growable: false)
        ..sort((a, b) => b.spread.compareTo(a.spread));
  return result;
}

_CommercialInsights _buildInsights({
  required List<CommercialAlertRecord> alerts,
  required List<_PriceRadarRow> buyRows,
  required List<_PriceRadarRow> sellRows,
  required List<_PricePositioningRow> positioningRows,
  required List<CommercialCatalogPriceReferenceRecord> catalogRows,
  required List<_CommercialOpportunityRow> opportunities,
}) {
  final materialsWithReference = {
    ...buyRows.map((row) => row.label),
    ...sellRows.map((row) => row.label),
  }.length;
  final comparableSegments = [
    ...buyRows.where(
      (row) => row.menudeoPrice != null && row.mayoreoPrice != null,
    ),
    ...sellRows.where(
      (row) => row.menudeoPrice != null && row.mayoreoPrice != null,
    ),
  ].length;
  final topOpportunity = opportunities.isEmpty ? null : opportunities.first;
  final topPositioning = positioningRows.isEmpty ? null : positioningRows.first;

  return _CommercialInsights(
    materialsWithReference: materialsWithReference,
    comparableSegments: comparableSegments,
    activeAlerts: alerts.length,
    counterpartiesWithReference: catalogRows.length,
    primaryMessage: topOpportunity == null
        ? 'Todavía no hay una oportunidad clara de spread para priorizar oferta.'
        : '${topOpportunity.materialLabel} en ${topOpportunity.channel} deja un spread observado de ${formatMoney(topOpportunity.spread)} por kg.',
    secondaryMessage: buyRows.isEmpty && sellRows.isEmpty
        ? 'Todavía faltan referencias suficientes para leer precios por material general.'
        : 'El radar principal ya está leyendo catálogos vigentes y mantiene menudeo y mayoreo en carriles separados.',
    tertiaryMessage: topPositioning == null
        ? 'Aún no hay suficientes contrapartes con precio para armar un rango confiable.'
        : '${topPositioning.label} tiene ${topPositioning.samples} muestras en ${_flowLabel(topPositioning.flow)} ${topPositioning.channel}.',
  );
}

List<_MaterialActivityRow> _buildRecentMaterialChanges(
  List<CommercialCatalogPriceReferenceRecord> rows,
) {
  final grouped = <String, List<CommercialCatalogPriceReferenceRecord>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.generalMaterialLabel, () => []).add(row);
  }

  final result =
      grouped.entries
          .map((entry) {
            final prices = entry.value.map((row) => row.finalPrice).toList()
              ..sort();
            final lastUpdatedAt = entry.value
                .map((row) => row.updatedAt)
                .whereType<DateTime>()
                .fold<DateTime?>(null, (current, value) {
                  if (current == null) return value;
                  return value.isAfter(current) ? value : current;
                });
            return _MaterialActivityRow(
              materialLabel: entry.key,
              lastUpdatedAt: lastUpdatedAt,
              referenceCount: entry.value.length,
              channels: entry.value.map((row) => row.channel).toSet(),
              flows: entry.value.map((row) => row.flow).toSet(),
              minPrice: prices.isEmpty ? 0 : prices.first,
              maxPrice: prices.isEmpty ? 0 : prices.last,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final left =
              a.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right =
              b.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
  return result;
}

String _priceReading(double? menudeoPrice, double? mayoreoPrice) {
  if (menudeoPrice == null && mayoreoPrice == null) return 'Sin referencia';
  if (menudeoPrice == null) return 'Solo mayoreo con referencia';
  if (mayoreoPrice == null) return 'Solo menudeo con referencia';
  final delta = mayoreoPrice - menudeoPrice;
  if (delta.abs() < 0.01) return 'Prácticamente en el mismo rango';
  final side = delta > 0 ? 'Mayoreo arriba' : 'Menudeo arriba';
  return '$side ${formatMoney(delta.abs())}';
}

bool _matchesGeneralMaterial(String source, String selectedMaterial) {
  final sourceKey = _normalizeLabel(source);
  final selectedKey = _normalizeLabel(selectedMaterial);
  return sourceKey.contains(selectedKey) || selectedKey.contains(sourceKey);
}

String _normalizeLabel(String value) {
  return value
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim();
}

String _readableBusinessGroup(String value) {
  if (value.trim().isEmpty) return 'Sin segmento';
  return value
      .split('_')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _formatShortDate(DateTime? value) {
  if (value == null) return 'sin fecha';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _channelFilterLabel(_CommercialChannelFilter value) {
  return switch (value) {
    _CommercialChannelFilter.ambos => 'Ambos canales',
    _CommercialChannelFilter.menudeo => 'Menudeo',
    _CommercialChannelFilter.mayoreo => 'Mayoreo',
  };
}

String _flowFilterLabel(_CommercialFlowFilter value) {
  return switch (value) {
    _CommercialFlowFilter.ambos => 'Compra y venta',
    _CommercialFlowFilter.compra => 'Compra',
    _CommercialFlowFilter.venta => 'Venta',
  };
}

String _flowLabel(String value) {
  return value == 'purchase' ? 'Compra' : 'Venta';
}

int _alertSeverityRank(String value) {
  switch (value) {
    case 'critica':
      return 3;
    case 'atencion':
      return 2;
    default:
      return 1;
  }
}
