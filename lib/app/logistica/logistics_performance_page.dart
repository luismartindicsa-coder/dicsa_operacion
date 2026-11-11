import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../gerencia/gerencia_dashboard_page.dart';
import '../gerencia/gerencia_operational_viewer_side_menu.dart';
import '../maintenance/maintenance_page.dart';
import '../maintenance/purchase_orders_page.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_operations_pages.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_gasoline_page.dart';
import 'logistics_gps_page.dart';
import 'logistics_savings_page.dart';
import 'logistics_performance_store.dart';
import 'logistics_performance_data.dart';
import 'logistics_performance_period.dart';
import 'logistics_fuel_followup_store.dart';
import 'logistics_fuel_followup_widgets.dart';
import 'logistics_fuel_load_origin.dart';
import 'logistics_fuel_cost.dart';
import 'logistics_fuel_price_store.dart';
import 'logistics_resource_profile_store.dart';
import 'logistics_theme.dart';

class LogisticsPerformancePage extends StatefulWidget {
  final bool viewerMode;

  const LogisticsPerformancePage({super.key, this.viewerMode = false});

  @override
  State<LogisticsPerformancePage> createState() =>
      _LogisticsPerformancePageState();
}

// Read-only operational summary with auxiliary detail; keeps the Logistics shell
// and palette. Editing remains in the existing homologated source grids.
class _LogisticsPerformancePageState extends State<LogisticsPerformancePage>
    with WidgetsBindingObserver {
  final supa = Supabase.instance.client;
  bool _loading = true;
  bool _importing = false;
  bool _generatingReport = false;
  bool _canReturnToDirection = false;
  bool _managementViewer = false;
  bool get _isViewerMode => widget.viewerMode || _managementViewer;
  String? _loadError;
  late DateTimeRange _dateRange;
  String _period = 'month';
  String? _vehicleFilterKey;
  List<PerformanceDay> _rows = const [];
  List<LogisticsLoadMileage> _loadMileage = const [];
  bool _editingFollowup = false;
  bool _editingPrices = false;
  Timer? _refreshTimer;
  bool _reloading = false;
  String? _refreshError;

  DateTimeRange _currentPeriod(String period) {
    return logisticsClosedPeriod(period, DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _dateRange = _currentPeriod(_period);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshIfIdle(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfIdle();
  }

  void _refreshIfIdle() {
    if (!mounted ||
        _importing ||
        _editingFollowup ||
        _editingPrices ||
        _generatingReport ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    unawaited(_reload(silent: true));
  }

  Future<void> _reload({bool silent = false}) async {
    if (_reloading) return;
    _reloading = true;
    try {
      final results = await Future.wait<dynamic>([
        AuthAccess.resolveCurrentProfile(),
        LogisticsPerformanceData.load(),
        LogisticsLoadMileage.loadEntries(),
      ]);
      if (!mounted) return;
      setState(() {
        _canReturnToDirection = AuthAccess.isDirectionRole(results[0]);
        _managementViewer =
            AuthAccess.hasManagementAccess(results[0]) &&
            !_canReturnToDirection;
        _rows = results[1] as List<PerformanceDay>;
        _loadMileage = results[2] as List<LogisticsLoadMileage>;
        if (_period != 'custom') _dateRange = _currentPeriod(_period);
        _loading = false;
        _loadError = null;
        _refreshError = null;
        if (_vehicleFilterKey != null &&
            !_rows.any((r) => r.vehicleKey == _vehicleFilterKey)) {
          _vehicleFilterKey = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (silent || _rows.isNotEmpty) {
          _refreshError =
              'No se pudo actualizar. Se muestran los últimos datos; reintentaremos automáticamente.';
        } else {
          _loadError =
              'No se pudo cargar Rendimiento. Reintentaremos automáticamente.';
        }
      });
    } finally {
      _reloading = false;
    }
  }

  List<PerformanceDay> get _visibleRows => _rows
      .where(
        (row) =>
            !row.date.isBefore(_dateRange.start) &&
            !row.date.isAfter(_dateRange.end) &&
            row.date.isBefore(DateUtils.dateOnly(DateTime.now())) &&
            (_vehicleFilterKey == null || row.vehicleKey == _vehicleFilterKey),
      )
      .toList();

  List<PerformanceUnit> get _units => groupPerformanceUnits(_visibleRows);

  String get _calculationNote =>
      'km/L cargado = kilómetros del periodo ÷ litros entregados. '
      'Con cargas parciales es una referencia, no consumo medido. '
      'Un valor parcial usa los km registrados y puede aumentar al completar los días faltantes.'
      '${_dateRange.end.difference(_dateRange.start).inDays < 29 ? ' En periodos cortos puede variar mucho por cargas fuera del corte; consulta 30 días.' : ''}';

  void _selectPeriod(String period) => setState(() {
    _period = period;
    _dateRange = _currentPeriod(period);
  });

  Future<void> _importMileageXlsx({DateTime? forDate}) async {
    if (_isViewerMode || _importing) return;
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
        lockParentWindow: true,
        dialogTitle: 'Seleccionar Excel de kilometraje',
      );
      if (picked == null || picked.files.isEmpty) return;
      if (!mounted) return;
      final file = picked.files.single;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        _toast('No se pudo leer el archivo seleccionado');
        return;
      }
      if (!mounted) return;

      final month = await showDatePicker(
        context: context,
        initialDate:
            forDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        helpText: 'Selecciona el mes de las filas “Día N”',
      );
      if (month == null || !mounted) return;

      final imported = _LogisticsMileageXlsxReader.read(
        bytes: bytes,
        year: month.year,
        month: month.month,
        sourceFileName: file.name,
      );
      if (imported.isEmpty) {
        _toast('No se encontraron filas “Día N” con kilometraje en el Excel');
        return;
      }

      final prices = await showLogisticsContractDialog<_ImportFuelPrices>(
        context: context,
        builder: (_) => _PerformanceScope(
          child: AreaThemeScope(
            tokens: logisticsAreaTokens,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kLogisticsSilverIcon,
                  secondary: kLogisticsSilverIcon,
                  surface: kLogisticsSilverSurfaceElevated,
                ),
              ),
              child: _ImportFuelPricesDialog(rowCount: imported.length),
            ),
          ),
        ),
      );
      if (prices == null || !mounted) return;

      final vehicleRows = await supa.from('vehicles').select('id,code');
      final vehicleIdByKey = <String, String>{
        for (final raw in vehicleRows as List)
          logisticsVehicleKey((raw['code'] ?? '').toString()): (raw['id'] ?? '')
              .toString(),
      };
      final records = imported
          .map(
            (row) => LogisticsVehicleMileageRecord(
              id: null,
              entryDate: row.date,
              vehicleId: vehicleIdByKey[row.vehicleKey],
              vehicleLabel: row.vehicleLabel,
              vehicleKey: row.vehicleKey,
              kilometers: row.kilometers,
              sourceFileName: file.name,
              dieselPricePerLiter: prices.diesel,
              gasolinePricePerLiter: prices.gasoline,
            ),
          )
          .toList(growable: false);
      await LogisticsVehicleMileageStore.upsertEntries(records);
      if (!mounted) return;
      _toast('${records.length} lecturas de kilometraje importadas');
      setState(() {
        _period = 'custom';
        _dateRange = DateTimeRange(
          start: DateTime(month.year, month.month),
          end: DateTime(month.year, month.month + 1, 0),
        );
      });
      await _reload(silent: true);
    } catch (error) {
      _toast('No se pudo importar el Excel: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _selectDateRange() async {
    final dates = [
      _dateRange.start,
      _dateRange.end,
      DateTime.now(),
      ..._rows.map((r) => r.date),
    ]..sort();
    final result = await _showPerformanceDateRangeDialog(
      context,
      bounds: DateTimeRange(
        start: DateTime(dates.first.year, 1, 1),
        end: _currentPeriod('week').end,
      ),
      initialRange: _dateRange,
    );
    if (result == null || !mounted) return;
    if (result.clear || result.range == null) {
      _selectPeriod('week');
    } else {
      setState(() {
        _period = 'custom';
        _dateRange = result.range!;
      });
    }
  }

  String get _rangeLabel =>
      '${_formatDate(_dateRange.start)} – ${_formatDate(_dateRange.end)}';

  Future<void> _generateReport() async {
    final units = _units;
    if (_generatingReport || units.isEmpty) return;
    setState(() => _generatingReport = true);
    try {
      const ink = PdfColor.fromInt(0xFF1C222A);
      const steel = PdfColor.fromInt(0xFF68727C);
      const soft = PdfColor.fromInt(0xFFE9EDF0);
      final totalKm = units.fold<double>(0, (sum, u) => sum + u.kilometers);
      final totalLiters = units.fold<double>(0, (sum, u) => sum + u.fuel.total);
      final totalServices = units.fold<int>(0, (sum, u) => sum + u.trips);
      final cost = units.fold(
        const LogisticsFuelCost(),
        (sum, u) => sum + u.cost,
      );
      final partialKm = units.any((u) => u.missingMileageDays > 0);
      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
          ),
          bold: pw.Font.ttf(
            await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
          ),
        ),
      );
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DICSA · Rendimiento de unidades',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          build: (_) => [
            pw.Text(
              'RENDIMIENTO DE UNIDADES',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '$_rangeLabel${_vehicleFilterKey == null ? '' : ' · ${_vehicleLabelFor(_vehicleFilterKey!)}'}',
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                _pdfMetric(
                  'KM REGISTRADOS',
                  '${totalKm.toStringAsFixed(1)}${partialKm ? ' (parcial)' : ''}',
                  soft,
                  ink,
                ),
                pw.SizedBox(width: 8),
                _pdfMetric(
                  'LITROS CARGADOS',
                  totalLiters.toStringAsFixed(1),
                  soft,
                  ink,
                ),
                pw.SizedBox(width: 8),
                _pdfMetric(
                  'SERVICIOS COMPLETADOS',
                  '$totalServices',
                  soft,
                  ink,
                ),
                pw.SizedBox(width: 8),
                _pdfMetric('GASTO REGISTRADO', cost.label, soft, ink),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              '$_calculationNote EPCOM aporta recorridos de días terminados; las lecturas importadas tienen prioridad. Sin estimación cuando no hay ninguna lectura de kilometraje, no hay cargas o se mezclan combustibles.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (!cost.isComplete)
              pw.Text(
                'El gasto parcial incluye solo cargas con precio capturado.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const [
                'UNIDAD',
                'SERVICIOS',
                'KILÓMETROS',
                'LITROS',
                'KM/L CARGADO',
                'GASTO',
                'POR REVISAR',
              ],
              data: units
                  .map(
                    (u) => [
                      u.vehicleLabel,
                      '${u.trips}',
                      u.kilometerLabel,
                      u.fuel.total.toStringAsFixed(1),
                      u.performanceLabel,
                      u.cost.label,
                      u.warnings.isEmpty ? '—' : u.warnings.join(' · '),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(color: steel),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8, color: ink),
              oddRowDecoration: const pw.BoxDecoration(color: soft),
              border: const pw.TableBorder(),
              cellPadding: const pw.EdgeInsets.all(7),
              columnWidths: const {
                0: pw.FlexColumnWidth(.8),
                1: pw.FlexColumnWidth(.65),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(.7),
                4: pw.FlexColumnWidth(1),
                5: pw.FlexColumnWidth(1.4),
                6: pw.FlexColumnWidth(2),
              },
            ),
          ],
        ),
      );
      if (kIsWeb) {
        _toast('Descarga disponible desde la aplicación de escritorio.');
        return;
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte de rendimiento',
        fileName:
            'rendimiento_${_dateRange.start.toIso8601String().substring(0, 10)}_${_dateRange.end.toIso8601String().substring(0, 10)}.pdf',
        allowedExtensions: const ['pdf'],
        type: FileType.custom,
        lockParentWindow: true,
      );
      if (path == null || path.trim().isEmpty) return;
      final output = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
      await File(output).writeAsBytes(await doc.save(), flush: true);
      _toast('Reporte guardado: $output');
    } catch (error) {
      _toast('No se pudo generar el reporte: $error');
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  String _vehicleLabelFor(String key) =>
      _rows.firstWhere((r) => r.vehicleKey == key).vehicleLabel;

  Future<void> _openDashboard() =>
      _replace(const LogisticsDashboardPage(instantOpen: true));
  Future<void> _openControlDaily() =>
      _replace(const LogisticsControlDailyPage());
  Future<void> _openCatalogs() => _replace(const LogisticsCatalogPage());
  Future<void> _openDiesel() => _replace(const LogisticsDieselPage());
  Future<void> _openGasoline() => _replace(const LogisticsGasolinePage());
  Future<void> _openDirection() => _isViewerMode
      ? _returnToGerenciaDashboard()
      : _replace(const GeneralDashboardPage(instantOpen: true));

  Future<void> _returnToGerenciaDashboard() =>
      _replace(const GerenciaDashboardPage(instantOpen: true));

  Future<void> _replace(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: page, duration: const Duration(milliseconds: 420)),
    );
  }

  void _handleNavigationAction(String label) {
    if (_isViewerMode) return;
    switch (label) {
      case kLogisticsNavGpsLabel:
        unawaited(_replace(const LogisticsGpsPage()));
        return;
      case kLogisticsNavFleetStatusLabel:
        unawaited(
          Navigator.of(
            context,
          ).pushReplacement(appPageRoute(page: const LogisticsUnitsPage())),
        );
        return;
      case kLogisticsNavIncidentsLabel:
        unawaited(
          Navigator.of(
            context,
          ).pushReplacement(appPageRoute(page: const LogisticsIncidentsPage())),
        );
        return;
      case kLogisticsNavDashboardLabel:
        unawaited(_openDashboard());
        return;
      case kLogisticsNavControlDailyLabel:
        unawaited(_openControlDaily());
        return;
      case kLogisticsNavCatalogsLabel:
        unawaited(_openCatalogs());
        return;
      case kLogisticsNavDieselLabel:
        unawaited(_openDiesel());
        return;
      case kLogisticsNavGasolineLabel:
        unawaited(_openGasoline());
        return;
      case kLogisticsNavDirectionDashboardLabel:
        unawaited(_openDirection());
        return;
      case kLogisticsNavSavingsLabel:
        unawaited(
          Navigator.of(
            context,
          ).pushReplacement(appPageRoute(page: const LogisticsSavingsPage())),
        );
        return;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PerformanceScope(
      child: AreaThemeScope(
        tokens: logisticsAreaTokens,
        child: ServicesShell(
          headerTitle: _isViewerMode
              ? 'Rendimiento de Unidades · Solo consulta'
              : 'Rendimiento de Unidades',
          servicesNavLabel: kLogisticsNavPerformanceLabel,
          sideMenuWidth: kLogisticsSideMenuWidth,
          customSideMenuBuilder: _isViewerMode
              ? (context, closeMenu) => GerenciaOperationalViewerSideMenu(
                  closeMenu: closeMenu,
                  currentDestination: GerenciaOperationalViewerMenuDestination
                      .logisticsPerformance,
                  onGoToGerenciaDashboard: _returnToGerenciaDashboard,
                  onGoToMaintenance: () =>
                      _replace(const MaintenancePage(viewerMode: true)),
                  onGoToPurchaseOrders: () =>
                      _replace(const PurchaseOrdersPage(viewerMode: true)),
                )
              : (context, closeMenu) => LogisticsAreaSidePanel(
                  currentLabel: kLogisticsNavPerformanceLabel,
                  canReturnToDirection: _canReturnToDirection,
                  onNavigate: (label) {
                    closeMenu();
                    _handleNavigationAction(label);
                  },
                ),
          activeOverlayModule: ServicesOverlayNavModule.servicios,
          onLogout: () async => signOutAndRouteToLogin(context),
          onGoToGeneralDashboard: _openDirection,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
                  child: Text(
                    _loadError!,
                    style: const TextStyle(color: kLogisticsSilverTextPrimary),
                  ),
                )
              : Builder(builder: (context) => _buildContent(context)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_period == 'loads') {
      final rows =
          groupPerformanceUnits(_rows)
              .where(
                (u) =>
                    _vehicleFilterKey == null ||
                    u.vehicleKey == _vehicleFilterKey,
              )
              .map(
                (u) => LogisticsFuelFollowup(
                  u,
                  DateTime.now(),
                  _loadMileage
                      .where((m) => m.vehicleId == u.days.first.vehicleId)
                      .firstOrNull,
                ),
              )
              .toList()
            ..sort((a, b) {
              final date = (b.day?.date ?? DateTime(1900)).compareTo(
                a.day?.date ?? DateTime(1900),
              );
              return date != 0
                  ? date
                  : a.unit.vehicleLabel.compareTo(b.unit.vehicleLabel);
            });
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            _buildActions(context),
            if (_refreshError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_refreshError!),
              ),
            Expanded(
              child: LogisticsFuelFollowupPanel(
                rows: rows,
                onOpen: _openFuelFollowup,
              ),
            ),
          ],
        ),
      );
    }
    final units = _units;
    final cost = units.fold(
      const LogisticsFuelCost(),
      (sum, u) => sum + u.cost,
    );
    final km = units.fold<double>(0, (sum, u) => sum + u.kilometers);
    final partial = units.any((u) => u.missingMileageDays > 0);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActions(context),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _MetricCard(
                  'Kilómetros registrados',
                  '${km.toStringAsFixed(1)} km${partial ? ' (parcial)' : ''}',
                  Icons.speed_rounded,
                ),
                _MetricCard(
                  'Litros cargados',
                  '${units.fold<double>(0, (sum, u) => sum + u.fuel.total).toStringAsFixed(1)} L',
                  Icons.local_gas_station_rounded,
                ),
                _MetricCard(
                  'Servicios completados',
                  '${units.fold<int>(0, (sum, u) => sum + u.trips)}',
                  Icons.route_rounded,
                ),
                _MetricCard(
                  'Gasto registrado',
                  cost.label,
                  Icons.payments_outlined,
                ),
              ];
              final count = constraints.maxWidth < 900 ? 2 : 4;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width:
                            (constraints.maxWidth - (count - 1) * 10) / count,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              '$_rangeLabel · Corte común hasta ${_formatDate(_dateRange.end)} · ${units.length} unidades',
              style: const TextStyle(color: kLogisticsSilverTextSecondary),
            ),
          ),
          if (_refreshError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_refreshError!),
            ),
          Expanded(child: _buildTable(units)),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _calculationNote,
              style: const TextStyle(
                fontSize: 12,
                color: kLogisticsSilverTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      gradient: kLogisticsPanelGradient,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kLogisticsSilverBorder),
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Desde última carga'),
          selected: _period == 'loads',
          onSelected: (_) => _selectPeriod('loads'),
        ),
        ChoiceChip(
          label: const Text('Últimos 7 días'),
          selected: _period == 'week',
          onSelected: (_) => _selectPeriod('week'),
        ),
        ChoiceChip(
          label: const Text('Últimos 30 días'),
          selected: _period == 'month',
          onSelected: (_) => _selectPeriod('month'),
        ),
        OutlinedButton.icon(
          style: _performanceOutlinedButtonStyle(context),
          onPressed: _selectDateRange,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(_period == 'custom' ? _rangeLabel : 'Elegir fechas'),
        ),
        PopupMenuButton<String>(
          color: kLogisticsSilverSurfaceElevated,
          onSelected: (value) => setState(
            () => _vehicleFilterKey = value == '__all__' ? null : value,
          ),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: '__all__',
              child: Text('Todas las unidades'),
            ),
            ...groupPerformanceUnits(_rows).map(
              (u) => PopupMenuItem(
                value: u.vehicleKey,
                child: Text(u.vehicleLabel),
              ),
            ),
          ],
          child: _PerformanceFilterButton(
            icon: Icons.local_shipping_rounded,
            label: _vehicleFilterKey == null
                ? 'Todas las unidades'
                : _vehicleLabelFor(_vehicleFilterKey!),
          ),
        ),
        if (!_isViewerMode)
          OutlinedButton.icon(
            style: _performanceOutlinedButtonStyle(context),
            onPressed: _editingPrices ? null : _editGeneralPrices,
            icon: const Icon(Icons.local_gas_station_outlined),
            label: const Text('Precios de combustible'),
          ),
        if (!_isViewerMode)
          OutlinedButton.icon(
            style: _performanceOutlinedButtonStyle(context),
            onPressed: _importing ? null : () => _importMileageXlsx(),
            icon: Icon(
              _importing
                  ? Icons.hourglass_top_rounded
                  : Icons.upload_file_rounded,
            ),
            label: const Text('Importar kilometraje'),
          ),
        if (_period != 'loads')
          FilledButton.icon(
            style: _performanceFilledButtonStyle(context),
            onPressed: _generatingReport || _units.isEmpty
                ? null
                : _generateReport,
            icon: Icon(
              _generatingReport
                  ? Icons.hourglass_top_rounded
                  : Icons.picture_as_pdf_rounded,
            ),
            label: const Text('Descargar PDF'),
          ),
      ],
    ),
  );

  Widget _buildTable(List<PerformanceUnit> units) => Container(
    decoration: BoxDecoration(
      gradient: kLogisticsPanelGradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kLogisticsSilverBorder),
    ),
    child: units.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insights_outlined,
                  size: 36,
                  color: kLogisticsSilverIcon,
                ),
                const SizedBox(height: 12),
                const Text('No hay actividad registrada en este periodo.'),
                const SizedBox(height: 6),
                const Text('Elige otras fechas o importa el kilometraje.'),
              ],
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: (constraints.maxWidth - 24).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: DataTable(
                    showCheckboxColumn: false,
                    columnSpacing: 22,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 76,
                    headingRowColor: const WidgetStatePropertyAll(
                      kLogisticsSilverSurfaceInteractive,
                    ),
                    columns: const [
                      DataColumn(label: Text('UNIDAD')),
                      DataColumn(numeric: true, label: Text('SERVICIOS')),
                      DataColumn(numeric: true, label: Text('KILÓMETROS')),
                      DataColumn(numeric: true, label: Text('LITROS')),
                      DataColumn(numeric: true, label: Text('KM/L CARGADO')),
                      DataColumn(numeric: true, label: Text('GASTO')),
                      DataColumn(label: Text('POR REVISAR')),
                    ],
                    rows: units
                        .map(
                          (u) => DataRow(
                            key: ValueKey('performance-unit-${u.vehicleLabel}'),
                            onSelectChanged: (_) => _openUnitDetail(u),
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      u.vehicleLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text('${u.trips}')),
                              DataCell(Text(u.kilometerLabel)),
                              DataCell(
                                Text('${u.fuel.total.toStringAsFixed(1)} L'),
                              ),
                              DataCell(Text(u.performanceLabel)),
                              DataCell(Text(u.cost.label)),
                              DataCell(
                                SizedBox(
                                  width: 205,
                                  child: Tooltip(
                                    message: u.warnings.join('\n'),
                                    child: Text(
                                      u.warnings.isEmpty
                                          ? '—'
                                          : u.warnings.join(' · '),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: kLogisticsSilverTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
  );

  Future<void> _openFuelFollowup(LogisticsFuelFollowup row) async {
    _editingFollowup = true;
    try {
      await showLogisticsContractDialog<void>(
        context: context,
        builder: (detailContext) => _PerformanceScope(
          child: LogisticsFuelFollowupDetail(
            row: row,
            onSource: _isViewerMode
                ? null
                : (day, load) async {
                    Navigator.pop(detailContext);
                    await _openFuelSource(day, diesel: load.diesel, load: load);
                  },
          ),
        ),
      );
    } finally {
      _editingFollowup = false;
    }
  }

  Future<void> _openUnitDetail(PerformanceUnit source) async {
    await showLogisticsContractDialog<void>(
      context: context,
      builder: (dialogContext) => _PerformanceScope(
        child: AreaThemeScope(
          tokens: logisticsAreaTokens,
          child: StatefulBuilder(
            builder: (context, refreshDetail) {
              final unit =
                  _units
                      .where((u) => u.vehicleKey == source.vehicleKey)
                      .firstOrNull ??
                  source;
              return Dialog(
                backgroundColor: kLogisticsSilverSurfaceElevated,
                insetPadding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 1040,
                  height: MediaQuery.sizeOf(context).height * .82,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${unit.vehicleLabel} · Detalle del periodo',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar detalle',
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        Text(
                          '$_rangeLabel · Tanque: ${logisticsTankCapacityLabel(unit.tankCapacityLiters)}',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 6,
                          children: [
                            Text(unit.kilometerLabel),
                            Text(
                              '${unit.fuel.total.toStringAsFixed(1)} L cargados',
                            ),
                            Text('${unit.trips} servicios completados'),
                            Text(unit.cost.label),
                            Text(
                              '${unit.performanceLabel} · por litro cargado',
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_calculationNote),
                        ),
                        if (unit.warnings.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(unit.warnings.join(' · ')),
                          ),
                        const Divider(height: 24),
                        Expanded(
                          child: ListView.builder(
                            itemCount: unit.days.length,
                            itemBuilder: (context, index) {
                              final day = unit.days[index];
                              return Card(
                                color: kLogisticsSilverSurfaceInteractive,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ExpansionTile(
                                  key: PageStorageKey(
                                    'performance-day-${day.date}-${day.vehicleKey}',
                                  ),
                                  initiallyExpanded:
                                      unit.days.length == 1 ||
                                      day.missingMileage ||
                                      !day.cost.isComplete,
                                  title: Text(
                                    _formatDate(day.date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${day.mileage == null ? 'Falta kilometraje' : '${day.kilometers.toStringAsFixed(1)} km'} · ${day.fuel.total.toStringAsFixed(1)} L · ${day.trips} servicios · ${day.cost.label}',
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  children: [
                                    if (day.mileage != null ||
                                        day.gpsMileage != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Kilometraje: ${day.mileageSourceLabel}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        if (!_isViewerMode &&
                                            day.missingMileage)
                                          OutlinedButton.icon(
                                            style:
                                                _performanceOutlinedButtonStyle(
                                                  context,
                                                ),
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                              unawaited(
                                                _importMileageXlsx(
                                                  forDate: day.date,
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.upload_file_rounded,
                                            ),
                                            label: const Text(
                                              'Importar kilometraje faltante',
                                            ),
                                          ),
                                        if (!_isViewerMode &&
                                            day.mileage != null &&
                                            day.fuel.total > 0)
                                          OutlinedButton.icon(
                                            style:
                                                _performanceOutlinedButtonStyle(
                                                  context,
                                                ),
                                            onPressed: () async {
                                              await _editDayPrices(day);
                                              if (context.mounted) {
                                                refreshDetail(() {});
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.payments_outlined,
                                            ),
                                            label: Text(
                                              day.cost.isComplete
                                                  ? 'Editar precios'
                                                  : 'Capturar precio',
                                            ),
                                          ),
                                        if (!_isViewerMode &&
                                            day.fuel.total == 0)
                                          OutlinedButton.icon(
                                            style:
                                                _performanceOutlinedButtonStyle(
                                                  context,
                                                ),
                                            onPressed: () async {
                                              final diesel =
                                                  await _chooseFuel();
                                              if (diesel == null ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              Navigator.pop(dialogContext);
                                              await _openFuelSource(
                                                day,
                                                diesel: diesel,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.local_gas_station_outlined,
                                            ),
                                            label: const Text('Revisar cargas'),
                                          ),
                                      ],
                                    ),
                                    if (day.loads.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Cargas registradas',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      ...day.loads.map(
                                        (load) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            '${load.diesel ? 'Diésel' : 'Gasolina'} · ${load.liters.toStringAsFixed(1)} L${load.litersEstimated ? ' estimados' : ''} · ${logisticsFuelLoadOriginLabel(load.origin)}',
                                          ),
                                          subtitle: Text(
                                            '${load.driver} · ${_priceLabel(load.diesel ? day.dieselPrice : day.gasolinePrice)}',
                                          ),
                                          trailing: _isViewerMode
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Abrir carga',
                                                  icon: const Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 19,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                    unawaited(
                                                      _openFuelSource(
                                                        day,
                                                        diesel: load.diesel,
                                                        load: load,
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ),
                                    ],
                                    if (day.services.isNotEmpty) ...[
                                      const Divider(),
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Servicios completados',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      ...day.services.map(
                                        (service) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            '${service.company} · ${service.movement}',
                                          ),
                                          subtitle: Text(service.driver),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _priceLabel(double? price) => price == null
      ? 'Sin precio'
      : '${logisticsFuelMoney((price * 100).round())}/L';

  Future<void> _editGeneralPrices() async {
    if (_isViewerMode) return;
    setState(() => _editingPrices = true);
    try {
      final history = await LogisticsFuelPriceStore.loadEntries();
      if (!mounted) return;
      final saved = await showLogisticsContractDialog<_ImportFuelPrices>(
        context: context,
        builder: (_) => _PerformanceScope(
          child: AreaThemeScope(
            tokens: logisticsAreaTokens,
            child: _ImportFuelPricesDialog(
              rowCount: 0,
              editing: true,
              history: history,
              onSave: LogisticsFuelPriceStore.save,
              description:
                  'Precios generales para todas las unidades. Se aplican desde la fecha elegida hasta el siguiente cambio. Los precios individuales tienen prioridad.',
            ),
          ),
        ),
      );
      if (saved != null && mounted) {
        await _reload(silent: true);
        if (mounted) _toast('Precios de combustible guardados');
      }
    } catch (_) {
      if (mounted) {
        _toast('No se pudieron consultar los precios. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _editingPrices = false);
    }
  }

  Future<void> _editDayPrices(PerformanceDay day) async {
    if (_isViewerMode) return;
    final prices = await showLogisticsContractDialog<_ImportFuelPrices>(
      context: context,
      builder: (_) => _PerformanceScope(
        child: AreaThemeScope(
          tokens: logisticsAreaTokens,
          child: _ImportFuelPricesDialog(
            rowCount: 1,
            editing: true,
            description: '${day.vehicleLabel} · ${_formatDate(day.date)}',
            initialDiesel: day.dieselPrice,
            initialGasoline: day.gasolinePrice,
          ),
        ),
      ),
    );
    if (prices == null || !mounted) return;
    try {
      await LogisticsVehicleMileageStore.updatePrices(
        day.mileage!,
        diesel: prices.diesel,
        gasoline: prices.gasoline,
      );
      await _reload(silent: true);
      _toast('Precios guardados');
    } catch (error) {
      _toast('No se pudieron guardar los precios: $error');
    }
  }

  Future<bool?> _chooseFuel() => showLogisticsContractDialog<bool>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: kLogisticsSilverSurfaceElevated,
      title: const Text('Revisar combustible'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Diésel'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Gasolina'),
        ),
      ],
    ),
  );

  Future<void> _openFuelSource(
    PerformanceDay day, {
    required bool diesel,
    PerformanceLoad? load,
  }) async {
    if (_isViewerMode) return;
    final range = DateTimeRange(start: day.date, end: day.date);
    await Navigator.of(context).push(
      appPageRoute(
        page: diesel
            ? LogisticsDieselPage(
                initialDateRange: range,
                initialVehicleId: day.vehicleId,
                initialVehicleLabel: load?.vehicleLabel ?? day.vehicleLabel,
                initialRecordId: load?.id,
              )
            : LogisticsGasolinePage(
                initialDateRange: range,
                initialVehicleId: day.vehicleId,
                initialVehicleLabel: load?.vehicleLabel ?? day.vehicleLabel,
                initialRecordId: load?.id,
              ),
      ),
    );
    if (mounted) await _reload(silent: true);
  }
}

class _PerformanceScope extends StatelessWidget {
  final Widget child;
  const _PerformanceScope({required this.child});
  @override
  Widget build(BuildContext context) => ServicesVisualModeScope(
    logisticsSilverMode: true,
    child: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: logisticsAreaTokens.primary,
          onPrimary: kLogisticsSilverBorderLight,
          primaryContainer: kLogisticsSilverSurfaceInteractive,
          onPrimaryContainer: kLogisticsSilverTextPrimary,
          secondary: kLogisticsSilverIcon,
          secondaryContainer: kLogisticsSilverSurfaceHover,
          onSecondaryContainer: kLogisticsSilverTextPrimary,
          surface: kLogisticsSilverSurfaceElevated,
          outline: kLogisticsSilverBorder,
          outlineVariant: kLogisticsSilverDivider,
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          iconColor: kLogisticsSilverIcon,
          textColor: kLogisticsSilverTextPrimary,
          shape: Border(),
          collapsedShape: Border(),
        ),
      ),
      child: child,
    ),
  );
}

ButtonStyle _performanceOutlinedButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: palette.textPrimary,
    backgroundColor: palette.surfaceElevated,
    side: BorderSide(color: palette.borderStrong),
    surfaceTintColor: Colors.transparent,
  ).copyWith(
    overlayColor: WidgetStatePropertyAll(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) return 6;
      if (states.contains(WidgetState.pressed)) return 1.5;
      return 0;
    }),
  );
}

ButtonStyle _performanceFilledButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return FilledButton.styleFrom(
    foregroundColor: palette.buttonFillForeground,
    backgroundColor: palette.buttonFill,
    disabledBackgroundColor: palette.surfaceHover,
    disabledForegroundColor: palette.textMuted,
  ).copyWith(
    overlayColor: WidgetStatePropertyAll(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) return 7;
      if (states.contains(WidgetState.pressed)) return 1.5;
      return 0;
    }),
  );
}

BoxDecoration _performanceDialogDecoration(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return BoxDecoration(
    color: palette.surfaceBase,
    gradient: palette.glassCardGradient,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: palette.borderStrong),
    boxShadow: [
      BoxShadow(
        color: palette.shadow.withValues(alpha: 0.16),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _ImportFuelPrices {
  final double? diesel;
  final double? gasoline;
  const _ImportFuelPrices(this.diesel, this.gasoline);
}

class _ImportFuelPricesDialog extends StatefulWidget {
  final int rowCount;
  final bool editing;
  final String? description;
  final double? initialDiesel;
  final double? initialGasoline;
  final List<LogisticsFuelPrices> history;
  final Future<void> Function(LogisticsFuelPrices)? onSave;
  const _ImportFuelPricesDialog({
    required this.rowCount,
    this.editing = false,
    this.description,
    this.initialDiesel,
    this.initialGasoline,
    this.history = const [],
    this.onSave,
  });

  @override
  State<_ImportFuelPricesDialog> createState() =>
      _ImportFuelPricesDialogState();
}

class _ImportFuelPricesDialogState extends State<_ImportFuelPricesDialog> {
  final _diesel = TextEditingController();
  final _gasoline = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;
  bool _saving = false;
  late DateTime _effectiveDate;
  bool get _general => widget.onSave != null;

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _setDate(DateTime date) {
    _effectiveDate = DateUtils.dateOnly(date);
    final entry = widget.history
        .where((p) => DateUtils.isSameDay(p.effectiveDate, date))
        .firstOrNull;
    _diesel.text = entry?.diesel?.toStringAsFixed(2) ?? '';
    _gasoline.text = entry?.gasoline?.toStringAsFixed(2) ?? '';
    _error = null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Vigente desde',
    );
    if (date != null && mounted) {
      setState(() {
        if (_diesel.text.isEmpty && _gasoline.text.isEmpty) {
          _setDate(date);
        } else {
          _effectiveDate = date;
          _error = null;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _diesel.text = widget.initialDiesel?.toStringAsFixed(2) ?? '';
    _gasoline.text = widget.initialGasoline?.toStringAsFixed(2) ?? '';
    if (_general) _setDate(DateTime.now());
  }

  @override
  void dispose() {
    _diesel.dispose();
    _gasoline.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final diesel = parseLogisticsFuelPrice(_diesel.text);
    final gasoline = parseLogisticsFuelPrice(_gasoline.text);
    if (diesel == null && gasoline == null) {
      setState(() => _error = 'Captura al menos un precio de combustible.');
      return;
    }
    if (_general) {
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        await widget.onSave!(
          LogisticsFuelPrices(
            effectiveDate: _effectiveDate,
            diesel: diesel,
            gasoline: gasoline,
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error =
                'No se pudieron guardar los precios. Reintenta; tus datos siguen aquí.';
          });
        }
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(_ImportFuelPrices(diesel, gasoline));
  }

  Widget _priceField(
    String label,
    TextEditingController controller, {
    bool autofocus = false,
  }) => TextFormField(
    controller: controller,
    autofocus: autofocus,
    enabled: !_saving,
    cursorColor: kLogisticsSilverTextPrimary,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixText: r'$ ',
      suffixText: '/ L',
    ),
    validator: (value) {
      try {
        parseLogisticsFuelPrice(value ?? '');
        return null;
      } on FormatException catch (error) {
        return error.message;
      }
    },
    onChanged: (_) {
      if (_error != null) setState(() => _error = null);
    },
    onFieldSubmitted: (_) => _submit(),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: kLogisticsSilverSurfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _performanceDialogDecoration(context),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Precios de combustible',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ServicesVisualPalette.of(context).textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description ??
                        '${widget.rowCount} ${widget.rowCount == 1 ? 'lectura' : 'lecturas'} por importar. El monto se calcula con los litros registrados para cada unidad y día.',
                  ),
                  const SizedBox(height: 18),
                  if (_general) ...[
                    OutlinedButton.icon(
                      style: _performanceOutlinedButtonStyle(context),
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Vigente desde: ${_dateLabel(_effectiveDate)}',
                      ),
                    ),
                    if (widget.history.isNotEmpty)
                      PopupMenuButton<LogisticsFuelPrices>(
                        enabled: !_saving,
                        color: kLogisticsSilverSurfaceElevated,
                        onSelected: (entry) =>
                            setState(() => _setDate(entry.effectiveDate)),
                        itemBuilder: (_) => [
                          for (final entry in widget.history)
                            PopupMenuItem(
                              value: entry,
                              child: Text(_dateLabel(entry.effectiveDate)),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Consultar precios anteriores'),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  _priceField('Precio de diésel', _diesel, autofocus: true),
                  const SizedBox(height: 14),
                  _priceField('Precio de gasolina', _gasoline),
                  const SizedBox(height: 12),
                  Text(
                    _general || widget.editing
                        ? 'Deja vacío el combustible que no cambie; conservará su precio anterior.'
                        : 'Deja vacío el combustible que no aplique. Al reimportar, un campo vacío conserva su precio anterior.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: _performanceOutlinedButtonStyle(context),
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: _performanceFilledButtonStyle(context),
                        onPressed: _saving ? null : _submit,
                        child: Text(
                          _saving
                              ? 'Guardando…'
                              : widget.editing
                              ? 'Guardar precios'
                              : 'Importar',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PerformanceDateRangeResult {
  final DateTimeRange? range;
  final bool clear;
  const _PerformanceDateRangeResult({this.range, this.clear = false});
}

Future<_PerformanceDateRangeResult?> _showPerformanceDateRangeDialog(
  BuildContext context, {
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  final palette = ServicesVisualPalette.of(context);
  return showLogisticsContractDialog<_PerformanceDateRangeResult>(
    context: context,
    builder: (dialogContext) {
      var displayedMonth = DateTime(
        (initialRange?.start ?? bounds.start).year,
        (initialRange?.start ?? bounds.start).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;
      DateTime dateOnly(DateTime value) =>
          DateTime(value.year, value.month, value.day);
      bool sameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      bool allowed(DateTime value) {
        final day = dateOnly(value);
        return !day.isBefore(dateOnly(bounds.start)) &&
            !day.isAfter(dateOnly(bounds.end));
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final firstDay = DateTime(displayedMonth.year, displayedMonth.month);
          final gridStart = firstDay.subtract(
            Duration(days: (firstDay.weekday + 6) % 7),
          );
          bool inRange(DateTime value) {
            if (start == null || (end == null && hover == null)) return false;
            final other = end ?? hover!;
            final from = start!.isBefore(other) ? start! : other;
            final to = start!.isBefore(other) ? other : start!;
            return !value.isBefore(from) && !value.isAfter(to);
          }

          void applySelection(DateTime value) {
            final picked = dateOnly(value);
            setLocalState(() {
              if (start == null || end != null) {
                start = picked;
                end = null;
                hover = null;
              } else if (picked.isBefore(start!)) {
                start = picked;
                hover = null;
              } else {
                end = picked;
                hover = null;
              }
            });
          }

          DateTimeRange? result() {
            if (start == null) return null;
            final last = end ?? start!;
            return DateTimeRange(
              start: start!.isBefore(last) ? start! : last,
              end: start!.isBefore(last) ? last : start!,
            );
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop();
                return KeyEventResult.handled;
              }
              if ((event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                  result() != null) {
                Navigator.of(
                  dialogContext,
                ).pop(_PerformanceDateRangeResult(range: result()));
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _performanceDialogDecoration(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro de fechas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Mes anterior',
                                onPressed: () => setLocalState(
                                  () => displayedMonth = DateTime(
                                    displayedMonth.year,
                                    displayedMonth.month - 1,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: palette.icon,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_performanceMonthName(displayedMonth.month)} ${displayedMonth.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Mes siguiente',
                                onPressed: () => setLocalState(
                                  () => displayedMonth = DateTime(
                                    displayedMonth.year,
                                    displayedMonth.month + 1,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: palette.icon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              _PerformanceWeekday('L'),
                              _PerformanceWeekday('M'),
                              _PerformanceWeekday('M'),
                              _PerformanceWeekday('J'),
                              _PerformanceWeekday('V'),
                              _PerformanceWeekday('S'),
                              _PerformanceWeekday('D'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 250,
                            child: Column(
                              children: List.generate(
                                6,
                                (week) => Expanded(
                                  child: Row(
                                    children: List.generate(7, (weekday) {
                                      final day = gridStart.add(
                                        Duration(days: week * 7 + weekday),
                                      );
                                      final isActive =
                                          (start != null &&
                                              sameDay(day, start!)) ||
                                          (end != null && sameDay(day, end!));
                                      final selectedRange = inRange(day);
                                      final isAllowed = allowed(day);
                                      return Expanded(
                                        child: MouseRegion(
                                          onHover: (_) {
                                            if (start != null &&
                                                end == null &&
                                                isAllowed) {
                                              setLocalState(
                                                () => hover = dateOnly(day),
                                              );
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: isAllowed
                                                ? () => applySelection(day)
                                                : null,
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? palette.filterAccent
                                                    : selectedRange
                                                    ? palette.filterAccentSoft
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                                border:
                                                    selectedRange && !isActive
                                                    ? Border.all(
                                                        color: palette
                                                            .filterAccent
                                                            .withValues(
                                                              alpha: 0.38,
                                                            ),
                                                      )
                                                    : null,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${day.day}',
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? palette
                                                              .buttonFillForeground
                                                        : !isAllowed
                                                        ? palette.textMuted
                                                        : day.month ==
                                                              displayedMonth
                                                                  .month
                                                        ? palette.textPrimary
                                                        : palette.textSecondary,
                                                    fontWeight: isActive
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            start == null
                                ? 'Selecciona fecha inicial'
                                : end == null
                                ? 'Selecciona fecha final'
                                : '${_formatDate(start!)} - ${_formatDate(end!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _performanceOutlinedButtonStyle(context),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: _performanceOutlinedButtonStyle(context),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(
                                      const _PerformanceDateRangeResult(
                                        clear: true,
                                      ),
                                    ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: _performanceFilledButtonStyle(context),
                                onPressed: result() == null
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(
                                        _PerformanceDateRangeResult(
                                          range: result(),
                                        ),
                                      ),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _PerformanceWeekday extends StatelessWidget {
  final String label;
  const _PerformanceWeekday(this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: ServicesVisualPalette.of(context).textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

String _performanceMonthName(int month) {
  const names = <String>[
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return names[(month - 1).clamp(0, 11)];
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: kLogisticsModuleGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kLogisticsSilverBorder),
    ),
    child: Row(
      children: [
        Icon(icon, color: kLogisticsSilverIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kLogisticsSilverTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: kLogisticsSilverTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PerformanceFilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerformanceFilterButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: kLogisticsSilverSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kLogisticsSilverBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: kLogisticsSilverIcon),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }
}

class _MileageImportRow {
  final DateTime date;
  final String vehicleLabel;
  final String vehicleKey;
  final double kilometers;
  const _MileageImportRow({
    required this.date,
    required this.vehicleLabel,
    required this.vehicleKey,
    required this.kilometers,
  });
}

class _LogisticsMileageXlsxReader {
  static List<_MileageImportRow> read({
    required List<int> bytes,
    required int year,
    required int month,
    required String sourceFileName,
  }) {
    const mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const relNs =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const pkgRelNs =
        'http://schemas.openxmlformats.org/package/2006/relationships';
    final archive = ZipDecoder().decodeBytes(bytes);
    String text(String path) {
      final file = archive.findFile(path);
      if (file == null) throw StateError('Falta $path en el XLSX');
      return utf8.decode(file.content);
    }

    final sharedStrings = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedFile != null) {
      final doc = XmlDocument.parse(utf8.decode(sharedFile.content));
      for (final item in doc.findAllElements('si', namespace: mainNs)) {
        sharedStrings.add(
          item
              .findAllElements('t', namespace: mainNs)
              .map((node) => node.innerText)
              .join(),
        );
      }
    }
    final workbook = XmlDocument.parse(text('xl/workbook.xml'));
    final rels = XmlDocument.parse(text('xl/_rels/workbook.xml.rels'));
    final sheet = workbook
        .findAllElements('sheet', namespace: mainNs)
        .firstWhere(
          (item) => item.getAttribute('name')?.trim().toUpperCase() == 'VIAJES',
          orElse: () => throw StateError('El Excel no contiene la hoja Viajes'),
        );
    final relationId = sheet.getAttribute('id', namespace: relNs) ?? '';
    final relation = rels
        .findAllElements('Relationship', namespace: pkgRelNs)
        .firstWhere(
          (item) => item.getAttribute('Id') == relationId,
          orElse: () => throw StateError('No se encontró la hoja Viajes'),
        );
    final target = relation.getAttribute('Target') ?? '';
    final sheetDoc = XmlDocument.parse(
      text(target.startsWith('xl/') ? target : 'xl/$target'),
    );
    final rows = <List<String>>[];
    for (final row in sheetDoc.findAllElements('row', namespace: mainNs)) {
      final cells = <int, String>{};
      for (final cell in row.findElements('c', namespace: mainNs)) {
        final ref = cell.getAttribute('r') ?? '';
        final column = _xlsxColumn(ref);
        var value = cell.getElement('v', namespace: mainNs)?.innerText ?? '';
        if (cell.getAttribute('t') == 's') {
          final index = int.tryParse(value);
          if (index != null && index >= 0 && index < sharedStrings.length) {
            value = sharedStrings[index];
          }
        }
        cells[column] = value;
      }
      final max = cells.keys.isEmpty
          ? -1
          : cells.keys.reduce((a, b) => a > b ? a : b);
      rows.add(
        max < 0
            ? const <String>[]
            : List<String>.generate(max + 1, (i) => cells[i] ?? ''),
      );
    }
    var currentVehicle = '';
    final output = <_MileageImportRow>[];
    final dayPattern = RegExp(r'^D[IÍ]A\s*(\d{1,2})$', caseSensitive: false);
    for (final row in rows.skip(1)) {
      if (row.isEmpty) continue;
      final label = row.first.trim();
      final day = dayPattern.firstMatch(label);
      if (day == null) {
        if (RegExp(
          r'^[A-Z]+[^A-Z0-9]*\d+',
          caseSensitive: false,
        ).hasMatch(label)) {
          currentVehicle = label;
        }
        continue;
      }
      if (currentVehicle.isEmpty || row.length < 2) continue;
      final number = int.tryParse(day.group(1)!);
      final kilometers = double.tryParse(row[1].trim().replaceAll(',', ''));
      if (number == null || kilometers == null || kilometers < 0) continue;
      final lastDay = DateTime(year, month + 1, 0).day;
      if (number > lastDay) continue;
      output.add(
        _MileageImportRow(
          date: DateTime(year, month, number),
          vehicleLabel: currentVehicle,
          vehicleKey: logisticsVehicleKey(currentVehicle),
          kilometers: kilometers,
        ),
      );
    }
    return output;
  }
}

int _xlsxColumn(String reference) {
  final letters = reference.replaceAll(RegExp(r'[^A-Z]'), '');
  var result = 0;
  for (final codeUnit in letters.codeUnits) {
    result = result * 26 + (codeUnit - 64);
  }
  return result - 1;
}

pw.Widget _pdfMetric(
  String label,
  String value,
  PdfColor background,
  PdfColor ink,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: ink,
            fontWeight: pw.FontWeight.bold,
            fontSize: 6.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: ink,
            fontWeight: pw.FontWeight.bold,
            fontSize: 8.5,
          ),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().substring(2)}';
