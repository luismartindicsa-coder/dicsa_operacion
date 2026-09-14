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
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_diesel_store.dart';
import 'logistics_gasoline_page.dart';
import 'logistics_savings_page.dart';
import 'logistics_gasoline_store.dart';
import 'logistics_performance_store.dart';
import 'logistics_theme.dart';

class LogisticsPerformancePage extends StatefulWidget {
  const LogisticsPerformancePage({super.key});

  @override
  State<LogisticsPerformancePage> createState() =>
      _LogisticsPerformancePageState();
}

class _LogisticsPerformancePageState extends State<LogisticsPerformancePage> {
  final supa = Supabase.instance.client;
  bool _loading = true;
  bool _importing = false;
  bool _generatingReport = false;
  bool _canReturnToDirection = false;
  String? _loadError;
  DateTimeRange? _dateRange;
  String? _vehicleFilterKey;
  _PerformanceFuelFilter _fuelFilter = _PerformanceFuelFilter.all;
  List<_PerformanceRow> _rows = const <_PerformanceRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        AuthAccess.resolveCurrentProfile(),
        LogisticsVehicleMileageStore.loadEntries(),
        LogisticsDieselConsumptionStore.loadEntries(),
        LogisticsGasolineControlStore.loadEntries(),
        supa.from('vehicles').select('id,code').order('code'),
        supa
            .from('services')
            .select('service_date,due_date,vehicle_id,client_id,direction')
            .eq('area', 'LOGISTICA')
            .not('vehicle_id', 'is', null),
        supa.from('sites').select('id,name').eq('type', 'cliente'),
      ]);
      if (!mounted) return;

      final vehicles = (results[4] as List)
          .map(
            (raw) => _VehicleOption(
              id: (raw['id'] ?? '').toString(),
              label: (raw['code'] ?? '').toString().trim(),
            ),
          )
          .where((vehicle) => vehicle.id.isNotEmpty && vehicle.label.isNotEmpty)
          .toList(growable: false);
      final vehicleKeyById = <String, String>{
        for (final vehicle in vehicles)
          vehicle.id: logisticsVehicleKey(vehicle.label),
      };
      final vehicleLabelByKey = <String, String>{
        for (final vehicle in vehicles)
          logisticsVehicleKey(vehicle.label): vehicle.label,
      };

      final fuelByDayAndVehicle = <String, _FuelTotals>{};
      void addDiesel(LogisticsDieselConsumptionRecord entry) {
        final key = _entryVehicleKey(
          vehicleId: entry.vehicleId,
          vehicleLabel: entry.vehicleLabel,
          vehicleKeyById: vehicleKeyById,
        );
        if (key.isEmpty) return;
        final bucketKey = _dayVehicleKey(entry.entryDate, key);
        final current = fuelByDayAndVehicle[bucketKey] ?? const _FuelTotals();
        fuelByDayAndVehicle[bucketKey] = current.copyWith(
          diesel: current.diesel + entry.litersRequested,
        );
      }

      void addGasoline(LogisticsGasolineControlRecord entry) {
        final key = _entryVehicleKey(
          vehicleId: entry.vehicleId,
          vehicleLabel: entry.vehicleLabel,
          vehicleKeyById: vehicleKeyById,
        );
        if (key.isEmpty) return;
        final bucketKey = _dayVehicleKey(entry.entryDate, key);
        final current = fuelByDayAndVehicle[bucketKey] ?? const _FuelTotals();
        fuelByDayAndVehicle[bucketKey] = current.copyWith(
          gasoline: current.gasoline + entry.litersLoaded,
        );
      }

      for (final entry
          in results[2] as List<LogisticsDieselConsumptionRecord>) {
        addDiesel(entry);
      }
      for (final entry in results[3] as List<LogisticsGasolineControlRecord>) {
        addGasoline(entry);
      }

      final clientNameById = <String, String>{
        for (final raw in results[6] as List)
          (raw['id'] ?? '').toString(): _siteLabel(raw),
      };
      final tripsByDayAndVehicle = <String, List<_TripDetail>>{};
      for (final raw in results[5] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final vehicleId = row['vehicle_id']?.toString() ?? '';
        final vehicleKey = vehicleKeyById[vehicleId] ?? '';
        final date = _parseDate(row['due_date'] ?? row['service_date']);
        if (vehicleKey.isEmpty || date == null) continue;
        final key = _dayVehicleKey(date, vehicleKey);
        (tripsByDayAndVehicle[key] ??= <_TripDetail>[]).add(
          _TripDetail(
            destination:
                clientNameById[row['client_id']?.toString()] ?? 'Sin destino',
            movement: _movementLabel(row['direction']?.toString()),
          ),
        );
      }

      final sourceRows = results[1] as List<LogisticsVehicleMileageRecord>;
      final rows =
          sourceRows
              .map((mileage) {
                final key = _dayVehicleKey(
                  mileage.entryDate,
                  mileage.vehicleKey,
                );
                final fuel = fuelByDayAndVehicle[key] ?? const _FuelTotals();
                final trips =
                    tripsByDayAndVehicle[key] ?? const <_TripDetail>[];
                return _PerformanceRow(
                  date: mileage.entryDate,
                  vehicleLabel:
                      vehicleLabelByKey[mileage.vehicleKey] ??
                      mileage.vehicleLabel,
                  vehicleKey: mileage.vehicleKey,
                  kilometers: mileage.kilometers,
                  tripDetails: trips,
                  fuel: fuel,
                );
              })
              .toList(growable: false)
            ..sort((a, b) {
              final byDate = b.date.compareTo(a.date);
              return byDate != 0
                  ? byDate
                  : a.vehicleLabel.compareTo(b.vehicleLabel);
            });

      setState(() {
        _canReturnToDirection = AuthAccess.isDirectionRole(results[0]);
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo consolidar Rendimiento: $error';
      });
    }
  }

  List<_PerformanceRow> get _visibleRows {
    final range = _dateRange;
    return _rows
        .where((row) {
          if (range != null) {
            final start = DateUtils.dateOnly(range.start);
            final end = DateUtils.dateOnly(range.end);
            if (row.date.isBefore(start) || row.date.isAfter(end)) return false;
          }
          if (_vehicleFilterKey != null &&
              row.vehicleKey != _vehicleFilterKey) {
            return false;
          }
          return _fuelFilter.matches(row.fuel);
        })
        .toList(growable: false);
  }

  Future<void> _importMileageXlsx() async {
    if (_importing) return;
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
      initialDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecciona el mes de las filas “Día N”',
    );
    if (month == null || !mounted) return;

    setState(() => _importing = true);
    try {
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
            ),
          )
          .toList(growable: false);
      await LogisticsVehicleMileageStore.upsertEntries(records);
      if (!mounted) return;
      _toast('${records.length} lecturas de kilometraje importadas');
      await _reload();
    } catch (error) {
      _toast('No se pudo importar el Excel: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _selectDateRange() async {
    final bounds = _rows.isEmpty
        ? DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 365)),
            end: DateTime.now().add(const Duration(days: 365)),
          )
        : DateTimeRange(
            start: _rows
                .map((row) => row.date)
                .reduce((a, b) => a.isBefore(b) ? a : b),
            end: _rows
                .map((row) => row.date)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
    final result = await _showPerformanceDateRangeDialog(
      context,
      bounds: bounds,
      initialRange: _dateRange,
    );
    if (result == null || !mounted) return;
    setState(() => _dateRange = result.clear ? null : result.range);
  }

  Future<void> _openReportDialog() async {
    if (_generatingReport || _visibleRows.isEmpty) {
      if (_visibleRows.isEmpty) _toast('No hay datos con los filtros actuales');
      return;
    }
    var period = _PerformanceReportPeriod.weekly;
    final selected = await showLogisticsContractDialog<_PerformanceReportPeriod>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _performanceDialogDecoration(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generar reporte de rendimiento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ServicesVisualPalette.of(context).textPrimary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'El reporte respetará los filtros activos de fecha, unidad y combustible.',
                        style: TextStyle(
                          color: ServicesVisualPalette.of(
                            context,
                          ).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<_PerformanceReportPeriod>(
                        style: ButtonStyle(
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: ServicesVisualPalette.of(
                                context,
                              ).borderStrong,
                            ),
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            ServicesVisualPalette.of(context).textPrimary,
                          ),
                        ),
                        segments: _PerformanceReportPeriod.values
                            .map(
                              (value) =>
                                  ButtonSegment<_PerformanceReportPeriod>(
                                    value: value,
                                    label: Text(value.label),
                                  ),
                            )
                            .toList(growable: false),
                        selected: {period},
                        onSelectionChanged: (value) =>
                            setDialogState(() => period = value.first),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: _performanceOutlinedButtonStyle(context),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: _performanceFilledButtonStyle(context),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(period),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text('Generar PDF'),
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
      ),
    );
    if (selected != null) await _generateReport(selected);
  }

  Future<void> _generateReport(_PerformanceReportPeriod period) async {
    if (_generatingReport) return;
    final sourceRows = _visibleRows;
    if (sourceRows.isEmpty) return;
    setState(() => _generatingReport = true);
    try {
      final aggregates = _buildReportAggregates(sourceRows, period);
      pw.MemoryImage? logo;
      try {
        final asset = await rootBundle.load('assets/images/logo_dicsa.png');
        logo = pw.MemoryImage(asset.buffer.asUint8List());
      } catch (_) {
        // The report remains usable if the local logo asset is unavailable.
      }
      const ink = PdfColor.fromInt(0xFF1C222A);
      const muted = PdfColor.fromInt(0xFF59636E);
      const steel = PdfColor.fromInt(0xFF68727C);
      const soft = PdfColor.fromInt(0xFFE9EDF0);
      const border = PdfColor.fromInt(0xFFC4CBD1);
      final totalKm = aggregates.fold<double>(
        0,
        (sum, row) => sum + row.kilometers,
      );
      final totalFuel = aggregates.fold<double>(
        0,
        (sum, row) => sum + row.fuel.total,
      );
      final totalTrips = aggregates.fold<int>(0, (sum, row) => sum + row.trips);
      final average = totalFuel == 0 ? null : totalKm / totalFuel;
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 20),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DICSA - Rendimiento de unidades',
                style: const pw.TextStyle(color: muted, fontSize: 7.5),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 7.5),
              ),
            ],
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(13),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: border, width: .8),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 42,
                    height: 42,
                    padding: const pw.EdgeInsets.all(5),
                    child: logo == null
                        ? pw.Center(
                            child: pw.Text(
                              'D',
                              style: pw.TextStyle(
                                color: steel,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          )
                        : pw.Image(logo),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REPORTE DE RENDIMIENTO',
                          style: pw.TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '${period.label.toUpperCase()} - ${_reportFilterLabel()}',
                          style: const pw.TextStyle(color: muted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  _pdfMetric('KM', totalKm.toStringAsFixed(1), soft, ink),
                  pw.SizedBox(width: 7),
                  _pdfMetric('LITROS', totalFuel.toStringAsFixed(1), soft, ink),
                  pw.SizedBox(width: 7),
                  _pdfMetric('VIAJES', '$totalTrips', soft, ink),
                  pw.SizedBox(width: 7),
                  _pdfMetric(
                    'PROMEDIO',
                    average == null
                        ? 'Pendiente'
                        : '${average.toStringAsFixed(2)} km/L',
                    soft,
                    ink,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: const [
                'CORTE',
                'UNIDAD',
                'DIESEL',
                'GASOLINA',
                'TOTAL L',
                'KM',
                'VIAJES',
                'KM/L',
                'DESTINOS',
              ],
              data: aggregates
                  .map(
                    (row) => [
                      row.periodLabel,
                      row.vehicleLabel,
                      row.fuel.diesel.toStringAsFixed(1),
                      row.fuel.gasoline.toStringAsFixed(1),
                      row.fuel.total.toStringAsFixed(1),
                      row.kilometers.toStringAsFixed(1),
                      '${row.trips}',
                      row.performance == null
                          ? 'Pendiente'
                          : row.performance!.toStringAsFixed(2),
                      row.destinations.isEmpty
                          ? 'Sin destino'
                          : row.destinations.join(', '),
                    ],
                  )
                  .toList(growable: false),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 7.5,
              ),
              cellStyle: const pw.TextStyle(color: ink, fontSize: 7.6),
              headerDecoration: const pw.BoxDecoration(color: steel),
              oddRowDecoration: const pw.BoxDecoration(color: soft),
              border: pw.TableBorder(
                top: const pw.BorderSide(color: border, width: .6),
                bottom: const pw.BorderSide(color: border, width: .6),
                horizontalInside: const pw.BorderSide(
                  color: border,
                  width: .35,
                ),
              ),
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 6,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(1.15),
                1: pw.FlexColumnWidth(.8),
                2: pw.FlexColumnWidth(.7),
                3: pw.FlexColumnWidth(.8),
                4: pw.FlexColumnWidth(.7),
                5: pw.FlexColumnWidth(.7),
                6: pw.FlexColumnWidth(.6),
                7: pw.FlexColumnWidth(.7),
                8: pw.FlexColumnWidth(2.45),
              },
            ),
          ],
        ),
      );
      if (kIsWeb) {
        _toast(
          'La exportación de PDF está disponible desde la aplicación de escritorio.',
        );
        return;
      }
      final stamp = DateTime.now();
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte de rendimiento',
        fileName:
            'rendimiento_${period.fileKey}_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}.pdf',
        allowedExtensions: const ['pdf'],
        type: FileType.custom,
        lockParentWindow: true,
      );
      if (outputPath == null || outputPath.trim().isEmpty) return;
      final path = outputPath.toLowerCase().endsWith('.pdf')
          ? outputPath
          : '$outputPath.pdf';
      await File(path).writeAsBytes(await document.save(), flush: true);
      _toast('Reporte guardado: $path');
    } catch (error) {
      _toast('No se pudo generar el reporte: $error');
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  List<_PerformanceReportRow> _buildReportAggregates(
    List<_PerformanceRow> rows,
    _PerformanceReportPeriod period,
  ) {
    final grouped = <String, _PerformanceReportRow>{};
    for (final row in rows) {
      final periodStart = period.startOf(row.date);
      final key =
          '${_dayVehicleKey(periodStart, row.vehicleKey)}|${period.name}';
      final aggregate = grouped.putIfAbsent(
        key,
        () => _PerformanceReportRow(
          periodStart: periodStart,
          periodLabel: period.labelFor(periodStart),
          vehicleLabel: row.vehicleLabel,
        ),
      );
      aggregate.add(row);
    }
    final output = grouped.values.toList(growable: false)
      ..sort((a, b) {
        final byPeriod = b.periodStart.compareTo(a.periodStart);
        return byPeriod != 0
            ? byPeriod
            : a.vehicleLabel.compareTo(b.vehicleLabel);
      });
    return output;
  }

  String _reportFilterLabel() {
    final parts = <String>[];
    if (_dateRange != null) {
      parts.add(
        '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
      );
    }
    if (_vehicleFilterKey != null) {
      parts.add('Unidad ${_vehicleLabelFor(_vehicleFilterKey!)}');
    }
    if (_fuelFilter != _PerformanceFuelFilter.all) {
      parts.add(_fuelFilter.label);
    }
    return parts.isEmpty ? 'Todos los registros' : parts.join(' | ');
  }

  String _vehicleLabelFor(String key) =>
      _rows.firstWhere((row) => row.vehicleKey == key).vehicleLabel;

  Future<void> _openDashboard() =>
      _replace(const LogisticsDashboardPage(instantOpen: true));
  Future<void> _openControlDaily() =>
      _replace(const LogisticsControlDailyPage());
  Future<void> _openCatalogs() => _replace(const LogisticsCatalogPage());
  Future<void> _openDiesel() => _replace(const LogisticsDieselPage());
  Future<void> _openGasoline() => _replace(const LogisticsGasolinePage());
  Future<void> _openDirection() =>
      _replace(const GeneralDashboardPage(instantOpen: true));

  Future<void> _replace(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: page, duration: const Duration(milliseconds: 420)),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
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
      case kLogisticsNavFleetStatusLabel:
      case kLogisticsNavIncidentsLabel:
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
    return ServicesVisualModeScope(
      logisticsSilverMode: true,
      child: AreaThemeScope(
        tokens: logisticsAreaTokens,
        child: ServicesShell(
          headerTitle: 'Rendimiento de Unidades',
          servicesNavLabel: kLogisticsNavPerformanceLabel,
          sideMenuWidth: kLogisticsSideMenuWidth,
          customSideMenuBuilder: (context, closeMenu) => LogisticsAreaSidePanel(
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
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final rows = _visibleRows;
    final totalKilometers = rows.fold<double>(
      0,
      (sum, row) => sum + row.kilometers,
    );
    final totalFuel = rows.fold<double>(0, (sum, row) => sum + row.fuel.total);
    final totalTrips = rows.fold<int>(0, (sum, row) => sum + row.trips);
    final average = totalFuel <= 0 ? null : totalKilometers / totalFuel;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummary(totalKilometers, totalFuel, totalTrips, average),
          const SizedBox(height: 10),
          _buildActions(),
          const SizedBox(height: 10),
          Expanded(child: _buildTable(rows)),
        ],
      ),
    );
  }

  Widget _buildSummary(
    double kilometers,
    double fuel,
    int trips,
    double? average,
  ) {
    final cards = [
      _MetricCard(
        'Kilometraje',
        '${kilometers.toStringAsFixed(1)} km',
        Icons.speed_rounded,
      ),
      _MetricCard(
        'Combustible',
        '${fuel.toStringAsFixed(1)} L',
        Icons.local_gas_station_rounded,
      ),
      _MetricCard('Viajes', '$trips', Icons.route_rounded),
      _MetricCard(
        'Rendimiento promedio',
        average == null ? 'Pendiente' : '${average.toStringAsFixed(2)} km/L',
        Icons.insights_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map(
              (card) => SizedBox(
                width: constraints.maxWidth < 900
                    ? (constraints.maxWidth - 10) / 2
                    : (constraints.maxWidth - 30) / 4,
                child: card,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildActions() {
    final rangeLabel = _dateRange == null
        ? 'Todas las fechas'
        : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}';
    return Container(
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
          OutlinedButton.icon(
            style: _performanceOutlinedButtonStyle(context),
            onPressed: _importing ? null : _importMileageXlsx,
            icon: Icon(
              _importing
                  ? Icons.hourglass_top_rounded
                  : Icons.upload_file_rounded,
            ),
            label: const Text('Importar kilometraje'),
          ),
          OutlinedButton.icon(
            style: _performanceOutlinedButtonStyle(context),
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range_rounded),
            label: Text(rangeLabel),
          ),
          PopupMenuButton<String>(
            color: ServicesVisualPalette.of(context).surfaceElevated,
            elevation: 8,
            shadowColor: ServicesVisualPalette.of(
              context,
            ).shadow.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: ServicesVisualPalette.of(context).borderStrong,
              ),
            ),
            offset: const Offset(0, 44),
            onSelected: (value) => setState(
              () => _vehicleFilterKey = value == '__all__' ? null : value,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '__all__',
                child: _PerformancePopupItem(
                  label: 'Todas las unidades',
                  selected: _vehicleFilterKey == null,
                ),
              ),
              ...(_rows.map((row) => row.vehicleKey).toSet().toList()..sort())
                  .map(
                    (key) => PopupMenuItem(
                      value: key,
                      child: _PerformancePopupItem(
                        label: _vehicleLabelFor(key),
                        selected: _vehicleFilterKey == key,
                      ),
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
          PopupMenuButton<_PerformanceFuelFilter>(
            color: ServicesVisualPalette.of(context).surfaceElevated,
            elevation: 8,
            shadowColor: ServicesVisualPalette.of(
              context,
            ).shadow.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: ServicesVisualPalette.of(context).borderStrong,
              ),
            ),
            offset: const Offset(0, 44),
            onSelected: (value) => setState(() => _fuelFilter = value),
            itemBuilder: (context) => _PerformanceFuelFilter.values
                .map(
                  (value) => PopupMenuItem(
                    value: value,
                    child: _PerformancePopupItem(
                      label: value.label,
                      selected: _fuelFilter == value,
                    ),
                  ),
                )
                .toList(growable: false),
            child: _PerformanceFilterButton(
              icon: Icons.local_gas_station_rounded,
              label: _fuelFilter.label,
            ),
          ),
          if (_dateRange != null ||
              _vehicleFilterKey != null ||
              _fuelFilter != _PerformanceFuelFilter.all)
            TextButton(
              style: _performanceTextButtonStyle(context),
              onPressed: () => setState(() {
                _dateRange = null;
                _vehicleFilterKey = null;
                _fuelFilter = _PerformanceFuelFilter.all;
              }),
              child: const Text('Limpiar filtros'),
            ),
          TextButton.icon(
            style: _performanceTextButtonStyle(context),
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
          FilledButton.icon(
            style: _performanceFilledButtonStyle(context),
            onPressed: _generatingReport ? null : _openReportDialog,
            icon: Icon(
              _generatingReport
                  ? Icons.hourglass_top_rounded
                  : Icons.picture_as_pdf_rounded,
            ),
            label: const Text('Generar reporte'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<_PerformanceRow> rows) {
    return Container(
      decoration: BoxDecoration(
        gradient: kLogisticsPanelGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLogisticsSilverBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5B6570),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: rows.isEmpty
          ? const Center(
              child: Text('Aún no hay kilometraje importado para este filtro.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  kLogisticsSilverSurfaceInteractive,
                ),
                columns: const [
                  DataColumn(label: Text('FECHA')),
                  DataColumn(label: Text('UNIDAD')),
                  DataColumn(label: Text('COMBUSTIBLE')),
                  DataColumn(numeric: true, label: Text('# VIAJES')),
                  DataColumn(numeric: true, label: Text('KILOMETRAJE')),
                  DataColumn(numeric: true, label: Text('RENDIMIENTO')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(_formatDate(row.date))),
                          DataCell(Text(row.vehicleLabel)),
                          DataCell(_FuelChip(fuel: row.fuel)),
                          DataCell(Text('${row.trips}')),
                          DataCell(
                            Text('${row.kilometers.toStringAsFixed(1)} km'),
                          ),
                          DataCell(
                            Text(
                              row.performance == null
                                  ? 'Pendiente'
                                  : '${row.performance!.toStringAsFixed(2)} km/L',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
    );
  }
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

ButtonStyle _performanceTextButtonStyle(BuildContext context) {
  final palette = ServicesVisualPalette.of(context);
  return TextButton.styleFrom(
    foregroundColor: palette.textSecondary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _PerformancePopupItem extends StatelessWidget {
  final String label;
  final bool selected;
  const _PerformancePopupItem({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Row(
      children: [
        Icon(
          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 17,
          color: selected ? palette.textPrimary : palette.icon,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
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
        Column(
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
            Text(
              value,
              style: const TextStyle(
                color: kLogisticsSilverTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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

class _FuelChip extends StatelessWidget {
  final _FuelTotals fuel;
  const _FuelChip({required this.fuel});

  @override
  Widget build(BuildContext context) {
    final label = fuel.diesel > 0 && fuel.gasoline > 0
        ? 'Mixto ${fuel.total.toStringAsFixed(1)} L'
        : fuel.diesel > 0
        ? 'Diesel ${fuel.diesel.toStringAsFixed(1)} L'
        : fuel.gasoline > 0
        ? 'Gasolina ${fuel.gasoline.toStringAsFixed(1)} L'
        : 'Sin carga';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: kLogisticsSilverSurfaceInteractive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FuelTotals {
  final double diesel;
  final double gasoline;
  const _FuelTotals({this.diesel = 0, this.gasoline = 0});
  double get total => diesel + gasoline;
  _FuelTotals copyWith({double? diesel, double? gasoline}) => _FuelTotals(
    diesel: diesel ?? this.diesel,
    gasoline: gasoline ?? this.gasoline,
  );
}

enum _PerformanceFuelFilter {
  all('Todo combustible'),
  diesel('Diesel'),
  gasoline('Gasolina');

  final String label;
  const _PerformanceFuelFilter(this.label);

  bool matches(_FuelTotals fuel) {
    return switch (this) {
      _PerformanceFuelFilter.all => true,
      _PerformanceFuelFilter.diesel => fuel.diesel > 0,
      _PerformanceFuelFilter.gasoline => fuel.gasoline > 0,
    };
  }
}

enum _PerformanceReportPeriod {
  daily('Diario', 'diario'),
  weekly('Semanal', 'semanal'),
  monthly('Mensual', 'mensual');

  final String label;
  final String fileKey;
  const _PerformanceReportPeriod(this.label, this.fileKey);

  DateTime startOf(DateTime date) {
    switch (this) {
      case _PerformanceReportPeriod.daily:
        return DateUtils.dateOnly(date);
      case _PerformanceReportPeriod.weekly:
        return DateUtils.dateOnly(
          date,
        ).subtract(Duration(days: date.weekday - 1));
      case _PerformanceReportPeriod.monthly:
        return DateTime(date.year, date.month);
    }
  }

  String labelFor(DateTime date) {
    switch (this) {
      case _PerformanceReportPeriod.daily:
        return _formatDate(date);
      case _PerformanceReportPeriod.weekly:
        final end = date.add(const Duration(days: 6));
        return '${_formatDate(date)} - ${_formatDate(end)}';
      case _PerformanceReportPeriod.monthly:
        return '${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}

class _TripDetail {
  final String destination;
  final String movement;
  const _TripDetail({required this.destination, required this.movement});
}

class _PerformanceReportRow {
  final DateTime periodStart;
  final String periodLabel;
  final String vehicleLabel;
  double kilometers = 0;
  int trips = 0;
  _FuelTotals fuel = const _FuelTotals();
  final Set<String> destinations = <String>{};

  _PerformanceReportRow({
    required this.periodStart,
    required this.periodLabel,
    required this.vehicleLabel,
  });

  double? get performance => fuel.total <= 0 ? null : kilometers / fuel.total;

  void add(_PerformanceRow row) {
    kilometers += row.kilometers;
    trips += row.trips;
    fuel = fuel.copyWith(
      diesel: fuel.diesel + row.fuel.diesel,
      gasoline: fuel.gasoline + row.fuel.gasoline,
    );
    destinations.addAll(
      row.tripDetails
          .map((trip) => trip.destination.trim())
          .where((destination) => destination.isNotEmpty),
    );
  }
}

class _PerformanceRow {
  final DateTime date;
  final String vehicleLabel;
  final String vehicleKey;
  final double kilometers;
  final List<_TripDetail> tripDetails;
  final _FuelTotals fuel;
  const _PerformanceRow({
    required this.date,
    required this.vehicleLabel,
    required this.vehicleKey,
    required this.kilometers,
    required this.tripDetails,
    required this.fuel,
  });
  int get trips => tripDetails.length;
  double? get performance => fuel.total <= 0 ? null : kilometers / fuel.total;
}

class _VehicleOption {
  final String id;
  final String label;
  const _VehicleOption({required this.id, required this.label});
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

String _entryVehicleKey({
  required String? vehicleId,
  required String vehicleLabel,
  required Map<String, String> vehicleKeyById,
}) {
  return vehicleKeyById[vehicleId?.trim() ?? ''] ??
      logisticsVehicleKey(vehicleLabel);
}

String _siteLabel(dynamic raw) {
  final map = Map<String, dynamic>.from(raw as Map);
  final name = (map['name'] ?? '').toString().trim();
  return name.isEmpty ? 'Sin destino' : name;
}

String _movementLabel(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'recoleccion':
      return 'Recolección';
    case 'entrega':
      return 'Entrega';
    default:
      return 'Servicio';
  }
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

String _dayVehicleKey(DateTime date, String vehicleKey) =>
    '${date.year}-${date.month}-${date.day}|$vehicleKey';

DateTime? _parseDate(dynamic raw) {
  final value = raw?.toString() ?? '';
  if (value.length < 10) return null;
  return DateTime.tryParse(value.substring(0, 10));
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().substring(2)}';
