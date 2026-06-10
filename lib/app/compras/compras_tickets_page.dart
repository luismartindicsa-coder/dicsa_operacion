// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../finanzas/finanzas_dashboard_page.dart';
import '../services/inventory_movements_grid.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'compras_area_chrome.dart';
import 'compras_dashboard_page.dart';
import 'compras_catalog_page.dart';
import 'compras_data_store.dart';
import 'compras_price_adjustments_page.dart';
import 'compras_provider_directory_page.dart';
import 'compras_theme.dart';
import 'compras_tickets_store.dart';

const double _kTicketActionsW = 86;
final DateTimeRange _kClearedTicketDateRange = DateTimeRange(
  start: DateTime(1900),
  end: DateTime(1900),
);
const double _kTicketDateW = 120;
const double _kTicketNumberW = 110;
const double _kTicketProviderW = 220;
const double _kTicketMaterialW = 170;
const double _kTicketWeightW = 90;
const double _kTicketPriceW = 100;
const double _kTicketPremiumW = 105;
const double _kTicketAmountW = 120;
const double _kTicketFacturaW = 160;
const double _kTicketPagoW = 160;
const double _kTicketDialogFieldW = 220;
const double _kTicketDialogWideFieldW = 300;
const List<int> _kComprasTicketsPageSizeOptions = <int>[25, 40, 60, 100];
const double _kTicketContentW =
    _kTicketDateW +
    _kTicketNumberW +
    _kTicketProviderW +
    _kTicketMaterialW +
    _kTicketWeightW +
    _kTicketPriceW +
    _kTicketPremiumW +
    _kTicketAmountW +
    _kTicketFacturaW +
    _kTicketPagoW;

class ComprasTicketsPage extends StatefulWidget {
  final bool instantOpen;

  const ComprasTicketsPage({super.key, this.instantOpen = false});

  @override
  State<ComprasTicketsPage> createState() => _ComprasTicketsPageState();
}

class _ComprasTicketsPageState extends State<ComprasTicketsPage> {
  bool _canReturnToDirection = false;
  bool _canAccessFinanzasArea = false;
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool _deletingSelection = false;
  final ScrollController _rowsScrollController = ScrollController();
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'compras_tickets_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  final FocusNode _gridRowsFocusNode = FocusNode(
    debugLabel: 'compras_tickets_grid_rows',
  );
  List<ComprasTicketRecord> _rows = <ComprasTicketRecord>[];
  List<ComprasCatalogProviderRecord> _providers =
      <ComprasCatalogProviderRecord>[];
  List<ComprasCatalogMaterialRecord> _materials =
      <ComprasCatalogMaterialRecord>[];
  List<ComprasCatalogPriceRecord> _prices = <ComprasCatalogPriceRecord>[];
  DateTimeRange? _dateRangeFilter;
  Set<String> _ticketFilters = <String>{};
  Set<String> _providerFilters = <String>{};
  Set<String> _materialFilters = <String>{};
  Set<String> _facturaFilters = <String>{};
  Set<String> _pagoFilters = <String>{};
  int _currentPage = 0;
  int _pageSize = 40;
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _dragSelectionActive = false;
  List<String> _dragSelectionKeys = const <String>[];
  String? _dragSelectionAnchorKey;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  @override
  void dispose() {
    _rowsScrollController.dispose();
    _gridRowsFocusNode.dispose();
    _dragAutoScrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
      _canAccessFinanzasArea = AuthAccess.canAccessFinanzasArea(profile);
    });
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      ComprasTicketsStore.loadTickets(),
      ComprasTicketsStore.loadReferenceData(),
    ]);
    if (!mounted) return;
    final tickets = results[0] as List<ComprasTicketRecord>;
    final reference = results[1] as ComprasTicketsReferenceData;
    setState(() {
      _rows = tickets;
      _providers = reference.providers;
      _materials = reference.materials;
      _prices = reference.prices;
      _loading = false;
      _pruneSelectionKeys();
    });
  }

  List<ComprasTicketRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_dateRangeFilter != null &&
              !_matchesDateRange(row.date, _dateRangeFilter!)) {
            return false;
          }
          if (_ticketFilters.isNotEmpty &&
              !_ticketFilters.contains(row.ticket)) {
            return false;
          }
          if (_providerFilters.isNotEmpty &&
              !_providerFilters.contains(row.providerNameSnapshot)) {
            return false;
          }
          if (_materialFilters.isNotEmpty &&
              !_materialFilters.contains(row.materialNameSnapshot)) {
            return false;
          }
          if (_facturaFilters.isNotEmpty &&
              !_facturaFilters.contains(
                comprasFacturaStatusLabel(row.facturaStatus),
              )) {
            return false;
          }
          if (_pagoFilters.isNotEmpty &&
              !_pagoFilters.contains(comprasPagoStatusLabel(row.pagoStatus))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<ComprasTicketRecord> get _pagedRows {
    final rows = _visibleRows;
    if (rows.isEmpty) return const <ComprasTicketRecord>[];
    final start = (_currentPage * _pageSize).clamp(0, rows.length);
    final end = (start + _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  int get _totalPages {
    final rows = _visibleRows.length;
    if (rows == 0) return 1;
    return ((rows - 1) ~/ _pageSize) + 1;
  }

  List<String> get _visibleRowKeys =>
      _pagedRows.map((row) => _rowKey(row)).toList(growable: false);

  String _rowKey(ComprasTicketRecord row) => 'ct:${row.id}';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatNumber(double value, {int decimals = 2}) {
    final negative = value < 0;
    final absolute = value.abs();
    final fixed = absolute.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts.first;
    final fraction = parts.length > 1 ? parts[1] : '';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buffer.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    final prefix = negative ? '-' : '';
    return decimals > 0
        ? '$prefix${buffer.toString()}.$fraction'
        : '$prefix${buffer.toString()}';
  }

  bool _matchesDateRange(DateTime date, DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _dateRangeLabel(DateTimeRange range) =>
      '${_dateLabel(range.start)} - ${_dateLabel(range.end)}';

  String _weight(double value) => '${_formatNumber(value)} kg';

  String _money(double value) => '\$${_formatNumber(value)}';

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<ComprasTicketRecord> get _selectedReportRows => _rows
      .where((row) => _bulkSelectedRowKeys.contains(_rowKey(row)))
      .toList(growable: false);

  ComprasTicketRecord? _rowByKey(String rowKey) {
    final id = rowKey.split(':').last;
    for (final row in _rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  double get _selectedPayableWeightSum => _rows
      .where((row) => _bulkSelectedRowKeys.contains(_rowKey(row)))
      .fold<double>(0, (sum, row) => sum + row.payableWeight);

  double get _selectedAmountSum => _rows
      .where((row) => _bulkSelectedRowKeys.contains(_rowKey(row)))
      .fold<double>(0, (sum, row) => sum + row.amount);

  Future<void> _printSelectedReports() async {
    final selectedRows = _selectedReportRows;
    if (selectedRows.isEmpty) {
      _toast('Selecciona al menos un ticket para generar el reporte.');
      return;
    }
    try {
      final pdfBytes = await _buildSelectedReportsPdfBytes(selectedRows);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${Directory.systemTemp.path}/compras_tickets_lote_$stamp.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      await _openPdfFile(file.path);
    } catch (error) {
      _toast('No se pudo abrir el reporte en PDF: $error');
    }
  }

  Future<Uint8List> _buildSelectedReportsPdfBytes(
    List<ComprasTicketRecord> rows,
  ) async {
    final doc = pw.Document();
    final dicsaBlueSoft = PdfColor.fromHex('#E9F0FF');
    final dicsaBlueDeep = PdfColor.fromHex('#173A7A');
    final dicsaGreenSoft = PdfColor.fromHex('#EEF9F1');
    final dicsaInk = PdfColor.fromHex('#16202B');
    final dicsaMuted = PdfColor.fromHex('#5E6B78');
    final dicsaBorder = PdfColor.fromHex('#B8C7DD');
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final totalNetWeight = rows.fold<double>(
      0,
      (sum, row) => sum + row.netWeight,
    );
    final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final allSameProvider = rows.every(
      (row) => row.providerId == rows.first.providerId,
    );
    final providerLabel = allSameProvider
        ? rows.first.providerNameSnapshot
        : 'PROVEEDORES MIXTOS';

    pw.Widget summaryCard(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: dicsaBlueSoft,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: dicsaBorder),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaBlueDeep,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15.5,
                  fontWeight: pw.FontWeight.bold,
                  color: dicsaInk,
                ),
              ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (_) => [
          pw.Row(
            children: [
              if (logoImage != null)
                pw.SizedBox(
                  width: 42,
                  height: 28,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              if (logoImage != null) pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaBlueDeep,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      providerLabel,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: dicsaMuted,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                printedAt,
                style: pw.TextStyle(fontSize: 9.5, color: dicsaMuted),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              summaryCard(
                'PESO NETO TOTAL',
                '${_formatNumber(totalNetWeight)} KG',
              ),
              pw.SizedBox(width: 10),
              summaryCard('IMPORTE TOTAL', _money(totalAmount)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: dicsaBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.7),
              3: const pw.FlexColumnWidth(1.55),
              4: const pw.FlexColumnWidth(1.05),
              5: const pw.FlexColumnWidth(1.1),
              6: const pw.FlexColumnWidth(1.0),
              7: const pw.FlexColumnWidth(1.15),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: dicsaGreenSoft),
                children:
                    [
                          'TICKET',
                          'FECHA',
                          'PROVEEDOR',
                          'MATERIAL',
                          'PESO',
                          'PRECIO',
                          'S/PRECIO',
                          'IMPORTE',
                        ]
                        .map(
                          (label) => pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              label,
                              style: pw.TextStyle(
                                fontSize: 9.4,
                                fontWeight: pw.FontWeight.bold,
                                color: dicsaBlueDeep,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
              for (final row in rows)
                pw.TableRow(
                  children:
                      [
                            row.ticket,
                            _dateLabel(row.date),
                            row.providerNameSnapshot,
                            row.materialNameSnapshot,
                            '${_formatNumber(row.payableWeight)} KG',
                            _money(row.price),
                            _money(row.premium),
                            _money(row.amount),
                          ]
                          .map(
                            (value) => pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Text(
                                value,
                                style: pw.TextStyle(
                                  fontSize: 9.2,
                                  color: dicsaInk,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _openPdfFile(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  bool _isCtrlOrCmdPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  bool _isEditableTextFocused() {
    final widget = FocusManager.instance.primaryFocus?.context?.widget;
    return widget is EditableText;
  }

  GlobalKey _rowItemKey(String rowKey) {
    return _rowItemKeys.putIfAbsent(
      rowKey,
      () => GlobalKey(debugLabel: 'compras_ticket_row_$rowKey'),
    );
  }

  void _setSingleSelection(String rowKey) {
    _selectedRowKey = rowKey;
    _selectionAnchorRowKey = rowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..add(rowKey);
  }

  void _clearSelection() {
    _selectedRowKey = null;
    _selectionAnchorRowKey = null;
    _bulkSelectedRowKeys.clear();
  }

  void _pruneSelectionKeys() {
    final validKeys = _rows.map(_rowKey).toSet();
    _bulkSelectedRowKeys.removeWhere((key) => !validKeys.contains(key));
    if (_selectedRowKey != null && !validKeys.contains(_selectedRowKey)) {
      _selectedRowKey = _bulkSelectedRowKeys.isEmpty
          ? null
          : _bulkSelectedRowKeys.last;
    }
    if (_selectionAnchorRowKey != null &&
        !validKeys.contains(_selectionAnchorRowKey)) {
      _selectionAnchorRowKey = _selectedRowKey;
    }
    final totalPages = _totalPages;
    if (_currentPage > totalPages - 1) {
      _currentPage = totalPages - 1;
    }
  }

  void _goToPreviousPage() {
    if (_currentPage == 0) return;
    setState(() => _currentPage -= 1);
  }

  void _goToNextPage() {
    if (_currentPage >= _totalPages - 1) return;
    setState(() => _currentPage += 1);
  }

  void _changePageSize(int value) {
    setState(() {
      _pageSize = value;
      _currentPage = 0;
    });
  }

  void _selectRange(String targetRowKey, List<String> visibleKeys) {
    final anchor = _selectionAnchorRowKey ?? _selectedRowKey ?? targetRowKey;
    final start = visibleKeys.indexOf(anchor);
    final end = visibleKeys.indexOf(targetRowKey);
    if (start == -1 || end == -1) {
      _setSingleSelection(targetRowKey);
      return;
    }
    final range = visibleKeys.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    _selectedRowKey = targetRowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..addAll(range);
  }

  void _handleRowSelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_isShiftPressed()) {
        _selectRange(rowKey, visibleKeys);
        return;
      }
      if (_isCtrlOrCmdPressed()) {
        if (_bulkSelectedRowKeys.contains(rowKey)) {
          _bulkSelectedRowKeys.remove(rowKey);
          _selectedRowKey = _bulkSelectedRowKeys.isEmpty
              ? null
              : _bulkSelectedRowKeys.last;
        } else {
          _bulkSelectedRowKeys.add(rowKey);
          _selectedRowKey = rowKey;
        }
        _selectionAnchorRowKey ??= rowKey;
        return;
      }
      _setSingleSelection(rowKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(rowKey);
    });
  }

  void _handleRowSecondarySelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_bulkSelectedRowKeys.contains(rowKey)) {
        _selectedRowKey = rowKey;
        _selectionAnchorRowKey ??= rowKey;
      } else {
        _setSingleSelection(rowKey);
      }
    });
  }

  void _beginDragSelection(String rowKey, List<String> visibleKeys) {
    if (_isCtrlOrCmdPressed() || _isShiftPressed()) return;
    _gridRowsFocusNode.requestFocus();
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionKeys = visibleKeys;
      _dragSelectionAnchorKey = rowKey;
      _dragPointerGlobal = null;
      _setSingleSelection(rowKey);
    });
  }

  void _updateDragSelection(String rowKey) {
    if (!_dragSelectionActive || _dragSelectionAnchorKey == null) return;
    final visibleKeys = _dragSelectionKeys;
    final start = visibleKeys.indexOf(_dragSelectionAnchorKey!);
    final end = visibleKeys.indexOf(rowKey);
    if (start == -1 || end == -1) return;
    setState(() {
      final range = visibleKeys.sublist(
        start < end ? start : end,
        start < end ? end + 1 : start + 1,
      );
      _selectedRowKey = rowKey;
      _selectionAnchorRowKey = _dragSelectionAnchorKey;
      _bulkSelectedRowKeys
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionKeys = const <String>[];
      _dragSelectionAnchorKey = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  void _ensureRowVisible(String rowKey) {
    final rowContext = _rowItemKey(rowKey).currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<String> visibleKeys,
  ) {
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(List<String> visibleKeys, {required bool last}) {
    final indexes = <int>[];
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) indexes.add(i);
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<String> visibleKeys,
  ) {
    if (!_dragSelectionActive) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(visibleKeys);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      visibleKeys,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(visibleKeys[visibleIndex]);
  }

  void _updateDragAutoScroll(List<String> visibleKeys) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final local = box.globalToLocal(_dragPointerGlobal!);
    final y = local.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
    } else {
      _dragAutoScrollVelocity = 0;
    }
    if (_dragAutoScrollVelocity == 0) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performDragAutoScroll(visibleKeys),
    );
  }

  void _performDragAutoScroll(List<String> visibleKeys) {
    if (!_dragSelectionActive ||
        _dragAutoScrollVelocity == 0 ||
        !_rowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _rowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _rowsScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _rowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, visibleKeys);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(visibleKeys[targetIndex]);
  }

  KeyEventResult _handleGridKeyEvent(KeyEvent event, List<String> visibleKeys) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isEditableTextFocused()) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_menuOpen) {
        setState(() => _menuOpen = false);
        return KeyEventResult.handled;
      }
      if (_bulkSelectedRowKeys.isNotEmpty) {
        setState(_clearSelection);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final row = _selectedRowKey == null ? null : _rowByKey(_selectedRowKey!);
      if (row != null) unawaited(_editRow(row));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_bulkSelectedRowKeys.isEmpty) return KeyEventResult.ignored;
      unawaited(_confirmDeleteSelection());
      return KeyEventResult.handled;
    }
    if (visibleKeys.isEmpty) return KeyEventResult.ignored;
    final currentKey = _selectedRowKey ?? visibleKeys.first;
    final currentIndex = visibleKeys
        .indexOf(currentKey)
        .clamp(0, visibleKeys.length - 1);
    if (key == LogicalKeyboardKey.arrowDown) {
      final target =
          visibleKeys[(currentIndex + 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final target =
          visibleKeys[(currentIndex - 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveRow(ComprasTicketRecord row) async {
    final previous = _rows;
    setState(() {
      final index = _rows.indexWhere((current) => current.id == row.id);
      if (index == -1) {
        _rows = <ComprasTicketRecord>[row, ..._rows];
      } else {
        _rows = [
          for (final current in _rows)
            if (current.id == row.id) row else current,
        ];
      }
      _setSingleSelection(_rowKey(row));
    });
    try {
      await ComprasTicketsStore.saveTicket(row);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el ticket. Se restauró el estado anterior.',
          ),
        ),
      );
    }
  }

  Future<void> _createRow() async {
    final saved = await showDialog<ComprasTicketRecord>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: comprasAreaTokens,
        child: _ComprasTicketEditDialog(
          providers: _providers,
          materials: _materials,
          prices: _prices,
        ),
      ),
    );
    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _editRow(ComprasTicketRecord row) async {
    final saved = await showDialog<ComprasTicketRecord>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: comprasAreaTokens,
        child: _ComprasTicketEditDialog(
          row: row,
          providers: _providers,
          materials: _materials,
          prices: _prices,
        ),
      ),
    );
    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _deleteRows(Set<String> ids) async {
    if (ids.isEmpty || _deletingSelection) return;
    setState(() => _deletingSelection = true);
    final previous = _rows;
    setState(() {
      _rows = _rows
          .where((row) => !ids.contains(row.id))
          .toList(growable: false);
      _clearSelection();
    });
    try {
      await ComprasTicketsStore.deleteTickets(ids);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron eliminar los tickets. Se restauró el estado anterior.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingSelection = false);
    }
  }

  Future<void> _confirmDeleteSelection() async {
    if (_bulkSelectedRowKeys.isEmpty || _deletingSelection) return;
    final confirmed = await _showTicketDeleteConfirmDialog(
      context,
      count: _bulkSelectedRowKeys.length,
      subject: _bulkSelectedRowKeys.length == 1
          ? 'ticket seleccionado'
          : 'tickets seleccionados',
    );
    if (confirmed != true || !mounted) return;
    final ids = _bulkSelectedRowKeys.map((key) => key.split(':').last).toSet();
    await _deleteRows(ids);
  }

  Future<void> _confirmDeleteRow(ComprasTicketRecord row) async {
    final confirmed = await _showTicketDeleteConfirmDialog(
      context,
      count: 1,
      subject: 'ticket ${row.ticket}',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _setSingleSelection(_rowKey(row)));
    await _deleteRows({row.id});
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    final lines = <String>[
      'fecha,ticket,proveedor,material,bruto,tara,neto,humedad,basura,peso,precio,sobreprecio,importe,factura,pago,cobertura',
      for (final row in _visibleRows)
        [
          _dateLabel(row.date),
          row.ticket,
          row.providerNameSnapshot,
          row.materialNameSnapshot,
          row.grossWeight.toStringAsFixed(2),
          row.tareWeight.toStringAsFixed(2),
          row.netWeight.toStringAsFixed(2),
          row.humidityPercent.toStringAsFixed(2),
          row.trashPercent.toStringAsFixed(2),
          row.payableWeight.toStringAsFixed(2),
          row.price.toStringAsFixed(2),
          row.premium.toStringAsFixed(2),
          row.amount.toStringAsFixed(2),
          comprasFacturaStatusLabel(row.facturaStatus),
          comprasPagoStatusLabel(row.pagoStatus),
          comprasCoverageStatusLabel(row.coverageStatus),
        ].map(_csvCell).join(','),
    ];
    try {
      await saveCsvFile(
        fileName: 'compras_tickets.csv',
        content: lines.join('\n'),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  Future<void> _pickMultiFilter({
    required String title,
    required List<String> options,
    required Set<String> initialValues,
    required ValueChanged<Set<String>> onSelected,
  }) async {
    final result = await _showTicketsMultiSelectDialog<String>(
      context,
      title: title,
      options: options,
      initialValues: initialValues,
    );
    if (result == null || !mounted) return;
    setState(() {
      onSelected(result);
      _currentPage = 0;
    });
  }

  Future<void> _pickDateFilter() async {
    final availableDates =
        _rows
            .map((row) => DateUtils.dateOnly(row.date))
            .toSet()
            .toList(growable: false)
          ..sort();
    final picked = await _showTicketDateRangeDialog(
      context,
      initialRange: _dateRangeFilter,
      firstDate: availableDates.isNotEmpty
          ? availableDates.first
          : DateTime(2024),
      lastDate: availableDates.isNotEmpty
          ? availableDates.last
          : DateTime(2035),
    );
    if (picked == null || !mounted) return;
    if (picked == _kClearedTicketDateRange) {
      setState(() {
        _dateRangeFilter = null;
        _currentPage = 0;
      });
      return;
    }
    setState(() {
      _dateRangeFilter = picked;
      _currentPage = 0;
    });
  }

  Future<DateTime?> _showThemedDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) => _showComprasThemedDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  Future<void> _pickTicketFilter() => _pickMultiFilter(
    title: 'Filtrar ticket',
    options: _rows.map((row) => row.ticket).toSet().toList()..sort(),
    initialValues: _ticketFilters,
    onSelected: (value) => _ticketFilters = value,
  );

  Future<void> _pickProviderFilter() => _pickMultiFilter(
    title: 'Filtrar proveedor',
    options: _rows.map((row) => row.providerNameSnapshot).toSet().toList()
      ..sort(),
    initialValues: _providerFilters,
    onSelected: (value) => _providerFilters = value,
  );

  Future<void> _pickMaterialFilter() => _pickMultiFilter(
    title: 'Filtrar material',
    options: _rows.map((row) => row.materialNameSnapshot).toSet().toList()
      ..sort(),
    initialValues: _materialFilters,
    onSelected: (value) => _materialFilters = value,
  );

  Future<void> _pickFacturaFilter() => _pickMultiFilter(
    title: 'Filtrar factura',
    options: kComprasFacturaStatuses.map(comprasFacturaStatusLabel).toList(),
    initialValues: _facturaFilters,
    onSelected: (value) => _facturaFilters = value,
  );

  Future<void> _pickPagoFilter() => _pickMultiFilter(
    title: 'Filtrar pago',
    options: kComprasPagoStatuses.map(comprasPagoStatusLabel).toList(),
    initialValues: _pagoFilters,
    onSelected: (value) => _pagoFilters = value,
  );

  List<String> get _activeFilterLabels => <String>[
    if (_dateRangeFilter != null)
      'Fecha: ${_dateRangeLabel(_dateRangeFilter!)}',
    for (final value in _ticketFilters) 'Ticket: $value',
    for (final value in _providerFilters) 'Proveedor: $value',
    for (final value in _materialFilters) 'Material: $value',
    for (final value in _facturaFilters) 'Factura: $value',
    for (final value in _pagoFilters) 'Pago: $value',
  ];

  void _clearAllFilters() {
    setState(() {
      _dateRangeFilter = null;
      _ticketFilters.clear();
      _providerFilters.clear();
      _materialFilters.clear();
      _facturaFilters.clear();
      _pagoFilters.clear();
      _currentPage = 0;
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasCatalogPage(instantOpen: true)),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openProviderDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasProviderDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openFinanzas() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Compras':
        unawaited(_openComprasDashboard());
        return;
      case 'Catálogo Compras':
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      case 'Directorio Proveedores':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openProviderDirectory());
        return;
      case 'Tickets Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Dashboard Finanzas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openFinanzas());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _visibleRows;
    final visibleRows = _pagedRows;
    final selectedRow = _selectedRowKey == null
        ? null
        : _rowByKey(_selectedRowKey!);
    return AreaThemeScope(
      tokens: comprasAreaTokens,
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
          background: const _ComprasTicketsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _ComprasTicketsHeaderBrand(),
          trailingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                    child: Focus(
                      focusNode: _gridRowsFocusNode,
                      autofocus: true,
                      onKeyEvent: (_, event) =>
                          _handleGridKeyEvent(event, _visibleRowKeys),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_bulkSelectedRowKeys.isNotEmpty) {
                            setState(_clearSelection);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                              child: InventoryGridTopBar(
                                data: InventoryGridTopBarData(
                                  metricIcon:
                                      Icons.confirmation_number_outlined,
                                  metricLabel: 'TICKETS',
                                  metricValue: '${filteredRows.length}',
                                  metricSubtitle:
                                      '${_rows.length} registrados · ${filteredRows.where((row) => row.pagoStatus != 'PAGADO').length} abiertos',
                                  exportingCsv: _exportingCsv,
                                  gridEditMode: false,
                                  canToggleGridEdit: false,
                                  canDeleteSelection:
                                      _bulkSelectedRowKeys.isNotEmpty,
                                  deletingSelection: _deletingSelection,
                                  selectedCount: _bulkSelectedRowKeys.length,
                                  selectedKgSumLabel:
                                      _bulkSelectedRowKeys.isEmpty
                                      ? null
                                      : _weight(_selectedPayableWeightSum),
                                  selectedSecondaryLabel:
                                      _bulkSelectedRowKeys.isEmpty
                                      ? null
                                      : 'Importe: ${_money(_selectedAmountSum)}',
                                  activeCellLabel: selectedRow?.ticket,
                                  onExportCsv: _exportCsv,
                                  onDeleteSelection: _confirmDeleteSelection,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ContractGlassCard(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ComprasTicketsFilterSummary(
                                            labels: _activeFilterLabels,
                                            onClearAll:
                                                _activeFilterLabels.isEmpty
                                                ? null
                                                : _clearAllFilters,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          style: _comprasPdfButtonStyle(),
                                          onPressed:
                                              _bulkSelectedRowKeys.isEmpty
                                              ? null
                                              : _printSelectedReports,
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                          label: Text(
                                            _bulkSelectedRowKeys.isEmpty
                                                ? 'Descargar PDF'
                                                : 'PDF ${_bulkSelectedRowKeys.length}',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        FilledButton.icon(
                                          style: _comprasRedFilledButtonStyle(),
                                          onPressed: _createRow,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('Nuevo ticket'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Expanded(
                                      child: _loading
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : visibleRows.isEmpty
                                          ? _ComprasTicketsEmptyState(
                                              onCreate: _createRow,
                                            )
                                          : Column(
                                              children: [
                                                _ComprasTicketsHeaderRow(
                                                  contentWidth:
                                                      _kTicketContentW,
                                                  columns: [
                                                    _ComprasTicketsHeaderColumn(
                                                      'FECHA',
                                                      _kTicketDateW,
                                                      onFilter: _pickDateFilter,
                                                      active:
                                                          _dateRangeFilter !=
                                                          null,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'TICKET',
                                                      _kTicketNumberW,
                                                      onFilter:
                                                          _pickTicketFilter,
                                                      active: _ticketFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'PROVEEDOR',
                                                      _kTicketProviderW,
                                                      onFilter:
                                                          _pickProviderFilter,
                                                      active: _providerFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'MATERIAL',
                                                      _kTicketMaterialW,
                                                      onFilter:
                                                          _pickMaterialFilter,
                                                      active: _materialFilters
                                                          .isNotEmpty,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'PESO',
                                                      _kTicketWeightW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'PRECIO',
                                                      _kTicketPriceW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'SOBREPRECIO',
                                                      _kTicketPremiumW,
                                                    ),
                                                    const _ComprasTicketsHeaderColumn(
                                                      'IMPORTE',
                                                      _kTicketAmountW,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'FACTURA',
                                                      _kTicketFacturaW,
                                                      onFilter:
                                                          _pickFacturaFilter,
                                                      active: _facturaFilters
                                                          .isNotEmpty,
                                                    ),
                                                    _ComprasTicketsHeaderColumn(
                                                      'PAGO',
                                                      _kTicketPagoW,
                                                      onFilter: _pickPagoFilter,
                                                      active: _pagoFilters
                                                          .isNotEmpty,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: Listener(
                                                    onPointerMove: (event) =>
                                                        _handleRowsPointerMove(
                                                          event,
                                                          _visibleRowKeys,
                                                        ),
                                                    onPointerUp: (_) =>
                                                        _endDragSelection(),
                                                    onPointerCancel: (_) =>
                                                        _endDragSelection(),
                                                    child: ListView.separated(
                                                      key: _rowsViewportKey,
                                                      controller:
                                                          _rowsScrollController,
                                                      itemCount:
                                                          visibleRows.length,
                                                      separatorBuilder:
                                                          (_, _) =>
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        final row =
                                                            visibleRows[index];
                                                        final rowKey = _rowKey(
                                                          row,
                                                        );
                                                        return KeyedSubtree(
                                                          key: _rowItemKey(
                                                            rowKey,
                                                          ),
                                                          child: _ComprasTicketDataRow(
                                                            row: row,
                                                            dateLabel:
                                                                _dateLabel(
                                                                  row.date,
                                                                ),
                                                            weightFormatter:
                                                                _weight,
                                                            moneyFormatter:
                                                                _money,
                                                            selected:
                                                                _bulkSelectedRowKeys
                                                                    .contains(
                                                                      rowKey,
                                                                    ),
                                                            onTap: () =>
                                                                _handleRowSelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onPrimaryPointerDown: () =>
                                                                _beginDragSelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onDragEnter: () =>
                                                                _updateDragSelection(
                                                                  rowKey,
                                                                ),
                                                            onPointerEnd:
                                                                _endDragSelection,
                                                            onSecondarySelection: () =>
                                                                _handleRowSecondarySelection(
                                                                  rowKey,
                                                                  _visibleRowKeys,
                                                                ),
                                                            onEdit: () =>
                                                                _editRow(row),
                                                            onDelete: () =>
                                                                _confirmDeleteRow(
                                                                  row,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                _ComprasTicketsPager(
                                                  currentPage: _currentPage,
                                                  totalPages: _totalPages,
                                                  pageSize: _pageSize,
                                                  totalRows:
                                                      filteredRows.length,
                                                  onPrevious: _goToPreviousPage,
                                                  onNext: _goToNextPage,
                                                  onPageSizeChanged:
                                                      _changePageSize,
                                                ),
                                              ],
                                            ),
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
                  child: ComprasAreaSidePanel(
                    label: 'Compras Mayoreo',
                    canReturnToDirection: _canReturnToDirection,
                    areaItems: [
                      const ComprasAreaNavEntry(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Tickets Compras',
                        subtitle: 'Captura y seguimiento operativo',
                        accented: true,
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.tune_rounded,
                        title: 'Ajuste de precios',
                        subtitle: 'Vigentes e historial operativo',
                        onTap: () async =>
                            _handleNavigationAction('Ajuste de precios'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.price_check_rounded,
                        title: 'Catálogo Compras',
                        subtitle: 'Proveedores, materiales y precios',
                        onTap: () async =>
                            _handleNavigationAction('Catálogo Compras'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.badge_rounded,
                        title: 'Directorio Proveedores',
                        subtitle: 'Crédito, contacto y operación',
                        onTap: () async =>
                            _handleNavigationAction('Directorio Proveedores'),
                      ),
                    ],
                    accessItems: [
                      ComprasAreaNavEntry(
                        icon: Icons.shopping_cart_checkout_rounded,
                        title: 'Dashboard Compras',
                        subtitle: 'Tickets y operación de compra',
                        onTap: () async =>
                            _handleNavigationAction('Dashboard Compras'),
                      ),
                      if (_canAccessFinanzasArea)
                        ComprasAreaNavEntry(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dashboard Finanzas',
                          subtitle: 'Pagos, liquidez y compromisos',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Finanzas'),
                        ),
                      if (_canReturnToDirection)
                        ComprasAreaNavEntry(
                          icon: Icons.assessment_outlined,
                          title: 'Dashboard Dirección',
                          subtitle: 'Vista ejecutiva multiarea',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Dirección'),
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
}

class _ComprasTicketEditDialog extends StatefulWidget {
  final ComprasTicketRecord? row;
  final List<ComprasCatalogProviderRecord> providers;
  final List<ComprasCatalogMaterialRecord> materials;
  final List<ComprasCatalogPriceRecord> prices;

  const _ComprasTicketEditDialog({
    this.row,
    required this.providers,
    required this.materials,
    required this.prices,
  });

  @override
  State<_ComprasTicketEditDialog> createState() =>
      _ComprasTicketEditDialogState();
}

class _ComprasTicketEditDialogState extends State<_ComprasTicketEditDialog> {
  late final TextEditingController _ticketC;
  late final TextEditingController _grossC;
  late final TextEditingController _tareC;
  late final TextEditingController _humidityC;
  late final TextEditingController _trashC;
  late final TextEditingController _priceC;
  late final TextEditingController _premiumC;
  late DateTime _date;
  String? _providerId;
  String? _materialId;
  late String _facturaStatus;
  late final String? _initialProviderId;
  late final String? _initialMaterialId;

  void _refreshPreview() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _ticketC = TextEditingController(text: row?.ticket ?? '');
    _grossC = TextEditingController(
      text: row == null ? '' : row.grossWeight.toStringAsFixed(2),
    );
    _tareC = TextEditingController(
      text: row == null ? '' : row.tareWeight.toStringAsFixed(2),
    );
    _humidityC = TextEditingController(
      text: row == null ? '0' : row.humidityPercent.toStringAsFixed(2),
    );
    _trashC = TextEditingController(
      text: row == null ? '0' : row.trashPercent.toStringAsFixed(2),
    );
    _priceC = TextEditingController(
      text: row == null ? '' : row.price.toStringAsFixed(2),
    );
    _premiumC = TextEditingController(
      text: row == null ? '0' : row.premium.toStringAsFixed(2),
    );
    _date = row?.date ?? DateTime.now();
    _providerId = row?.providerId;
    _materialId = row?.materialId;
    _initialProviderId = row?.providerId;
    _initialMaterialId = row?.materialId;
    _facturaStatus = row?.facturaStatus ?? 'PENDIENTE_DE_FACTURAR';
    _ticketC.addListener(_refreshPreview);
    _grossC.addListener(_refreshPreview);
    _tareC.addListener(_refreshPreview);
    _humidityC.addListener(_refreshPreview);
    _trashC.addListener(_refreshPreview);
    _priceC.addListener(_refreshPreview);
    _premiumC.addListener(_refreshPreview);
    if (row == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPriceFromSelection(force: true);
      });
    }
  }

  @override
  void dispose() {
    _ticketC.removeListener(_refreshPreview);
    _grossC.removeListener(_refreshPreview);
    _tareC.removeListener(_refreshPreview);
    _humidityC.removeListener(_refreshPreview);
    _trashC.removeListener(_refreshPreview);
    _priceC.removeListener(_refreshPreview);
    _premiumC.removeListener(_refreshPreview);
    _ticketC.dispose();
    _grossC.dispose();
    _tareC.dispose();
    _humidityC.dispose();
    _trashC.dispose();
    _priceC.dispose();
    _premiumC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await _showComprasThemedDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  void _save() {
    final provider = _selectedProvider;
    final material = _selectedMaterial;
    if (_ticketC.text.trim().isEmpty || provider == null || material == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa ticket, proveedor y material.')),
      );
      return;
    }
    if (_priceC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero define un precio vigente en Ajuste de precios para ese proveedor y material.',
          ),
        ),
      );
      return;
    }
    final record = buildComprasTicketDraft(
      id:
          widget.row?.id ??
          'compras-ticket-${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      ticket: _ticketC.text.trim(),
      providerId: provider.id,
      providerNameSnapshot: provider.name,
      materialId: material.id,
      materialNameSnapshot: material.name,
      grossWeight: _parseDouble(_grossC.text),
      tareWeight: _parseDouble(_tareC.text),
      humidityPercent: _parseDouble(_humidityC.text),
      trashPercent: _parseDouble(_trashC.text),
      price: _parseDouble(_priceC.text),
      premium: _parseDouble(_premiumC.text),
      facturaStatus: _facturaStatus,
      pagoStatus: widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
      coverageStatus: widget.row?.coverageStatus ?? 'SIN_CUBRIR',
    ).copyWith(createdAt: widget.row?.createdAt, updatedAt: DateTime.now());
    Navigator.of(context).pop(record);
  }

  double _parseDouble(String value) =>
      double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

  bool get _selectionMatchesOriginal =>
      _providerId == _initialProviderId && _materialId == _initialMaterialId;

  void _syncPriceFromSelection({bool force = false}) {
    final providerId = _providerId;
    final materialId = _materialId;
    if (providerId == null || materialId == null) return;
    if (!force && widget.row != null && _selectionMatchesOriginal) return;
    final currentPrice = resolveComprasCurrentPrice(
      prices: widget.prices,
      providerId: providerId,
      materialId: materialId,
    );
    _priceC.text = currentPrice?.toStringAsFixed(2) ?? '';
  }

  ComprasCatalogProviderRecord? get _selectedProvider {
    for (final row in widget.providers) {
      if (row.id == _providerId) return row;
    }
    return null;
  }

  ComprasCatalogMaterialRecord? get _selectedMaterial {
    for (final row in widget.materials) {
      if (row.id == _materialId) return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _selectedProvider;
    final material = _selectedMaterial;
    final preview = buildComprasTicketDraft(
      id: widget.row?.id ?? 'preview',
      date: _date,
      ticket: _ticketC.text.trim(),
      providerId: provider?.id ?? '',
      providerNameSnapshot: provider?.name ?? '',
      materialId: material?.id ?? '',
      materialNameSnapshot: material?.name ?? '',
      grossWeight: _parseDouble(_grossC.text),
      tareWeight: _parseDouble(_tareC.text),
      humidityPercent: _parseDouble(_humidityC.text),
      trashPercent: _parseDouble(_trashC.text),
      price: _parseDouble(_priceC.text),
      premium: _parseDouble(_premiumC.text),
      facturaStatus: _facturaStatus,
      pagoStatus: widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
      coverageStatus: widget.row?.coverageStatus ?? 'SIN_CUBRIR',
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: comprasAreaTokens.fieldSurface.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.row == null
                                  ? 'Nuevo ticket'
                                  : widget.row!.ticket,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: kComprasInk,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'El precio se toma del vigente configurado por proveedor y material, y queda congelado dentro del ticket.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kComprasMutedInk.withValues(alpha: 0.90),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _TicketFormSection(
                    step: '1',
                    title: 'Identificación',
                    subtitle:
                        'Primero define fecha, ticket, proveedor, material y estatus base.',
                    children: [
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Fecha',
                        icon: Icons.calendar_month_outlined,
                        value:
                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                        trailingIcon: Icons.keyboard_arrow_down_rounded,
                        onTap: _pickDate,
                        readOnly: true,
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Ticket',
                        icon: Icons.confirmation_number_outlined,
                        controller: _ticketC,
                        hintText: 'Escribe el ticket',
                      ),
                      _TicketPickerField<ComprasCatalogProviderRecord>(
                        width: _kTicketDialogWideFieldW,
                        label: 'Proveedor',
                        icon: Icons.storefront_outlined,
                        value: provider,
                        items: widget.providers,
                        hintText: 'Selecciona proveedor',
                        labelBuilder: (item) => item.name,
                        onChanged: (item) => setState(() {
                          _providerId = item?.id;
                          _syncPriceFromSelection();
                        }),
                      ),
                      _TicketPickerField<ComprasCatalogMaterialRecord>(
                        width: _kTicketDialogWideFieldW,
                        label: 'Material',
                        icon: Icons.precision_manufacturing_outlined,
                        value: material,
                        items: widget.materials,
                        hintText: 'Selecciona material',
                        labelBuilder: (item) => item.name,
                        onChanged: (item) => setState(() {
                          _materialId = item?.id;
                          _syncPriceFromSelection();
                        }),
                      ),
                      _TicketPickerField<String>(
                        width: _kTicketDialogFieldW,
                        label: 'Factura',
                        icon: Icons.receipt_long_outlined,
                        value: _facturaStatus,
                        items: const ['SIN_FACTURA', 'PENDIENTE_DE_FACTURAR'],
                        hintText: 'Selecciona estatus',
                        labelBuilder: comprasFacturaStatusLabel,
                        onChanged: (item) => setState(
                          () => _facturaStatus = item ?? _facturaStatus,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Pago',
                        icon: Icons.account_balance_wallet_outlined,
                        value: comprasPagoStatusLabel(
                          widget.row?.pagoStatus ?? 'PENDIENTE_DE_PAGO',
                        ),
                        readOnly: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TicketFormSection(
                    step: '2',
                    title: 'Precio',
                    subtitle:
                        'Después valida el precio vigente y captura solo el sobreprecio necesario.',
                    children: [
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Precio vigente',
                        icon: Icons.attach_money_rounded,
                        controller: _priceC,
                        hintText: 'Vigente por proveedor y material',
                        readOnly: true,
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Sobreprecio',
                        icon: Icons.trending_up_rounded,
                        controller: _premiumC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Tarifa final',
                        icon: Icons.price_change_outlined,
                        value:
                            '\$${(preview.price + preview.premium).toStringAsFixed(2)}',
                        readOnly: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TicketFormSection(
                    step: '3',
                    title: 'Pesos y cálculo',
                    subtitle:
                        'Por último captura pesos y mermas; el sistema calcula neto, peso pagable e importe.',
                    children: [
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Bruto',
                        icon: Icons.scale_outlined,
                        controller: _grossC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Tara',
                        icon: Icons.line_weight_rounded,
                        controller: _tareC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Humedad %',
                        icon: Icons.water_drop_outlined,
                        controller: _humidityC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Basura %',
                        icon: Icons.delete_sweep_outlined,
                        controller: _trashC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Neto',
                        icon: Icons.straighten_rounded,
                        value: preview.netWeight.toStringAsFixed(2),
                        readOnly: true,
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Peso pagable',
                        icon: Icons.scale_rounded,
                        value: preview.payableWeight.toStringAsFixed(2),
                        readOnly: true,
                      ),
                      _TicketDialogField(
                        width: _kTicketDialogFieldW,
                        label: 'Importe',
                        icon: Icons.payments_outlined,
                        value: '\$${preview.amount.toStringAsFixed(2)}',
                        readOnly: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _TicketInlinePreviewCard(preview: preview),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: _comprasRedOutlinedButtonStyle(),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: _comprasRedFilledButtonStyle(),
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ],
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

class _ComprasTicketsPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSizeChanged;

  const _ComprasTicketsPager({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          style: _comprasRedOutlinedButtonStyle(),
          onPressed: currentPage > 0 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Anterior'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: comprasAreaTokens.glassSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: comprasAreaTokens.border.withValues(alpha: 0.68),
            ),
          ),
          child: Text(
            'Página ${totalRows == 0 ? 0 : currentPage + 1} de $totalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          width: 148,
          child: DropdownButtonFormField<int>(
            initialValue: pageSize,
            items: _kComprasTicketsPageSizeOptions
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value filas'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onPageSizeChanged(value);
            },
            decoration: contractGlassFieldDecoration(
              context,
              hintText: 'Filas / pág',
            ),
            dropdownColor: const Color(0xFF232833),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            iconEnabledColor: comprasAreaTokens.accent,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: comprasAreaTokens.glassSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: comprasAreaTokens.border.withValues(alpha: 0.68),
            ),
          ),
          child: Text(
            '$totalRows registros',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        OutlinedButton.icon(
          style: _comprasRedOutlinedButtonStyle(),
          onPressed: currentPage < totalPages - 1 ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Siguiente'),
        ),
      ],
    );
  }
}

class _ComprasTicketsHeaderBrand extends StatelessWidget {
  const _ComprasTicketsHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DicsaLogoD(size: 42, progress: 1),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tickets Compras',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFE6DBD8),
              ),
            ),
            Text(
              'Control operativo de compra mayoreo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD1C0BC),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComprasTicketsHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _ComprasTicketsHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_ComprasTicketsHeaderButton> createState() =>
      _ComprasTicketsHeaderButtonState();
}

class _ComprasTicketsHeaderButtonState
    extends State<_ComprasTicketsHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap:
                widget.onTapSync ??
                (widget.onTap == null
                    ? null
                    : () => unawaited(widget.onTap!())),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -2.5 : 0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _hovered ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: _hovered ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _hovered ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, _hovered ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 2),
                  Icon(widget.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

class _ComprasTicketsFilterSummary extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _ComprasTicketsFilterSummary({required this.labels, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty && onClearAll == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: comprasAreaTokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: comprasAreaTokens.border.withValues(alpha: 0.70),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kComprasInk,
              ),
            ),
          ),
        if (onClearAll != null)
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
          ),
      ],
    );
  }
}

class _ComprasTicketsHeaderRow extends StatelessWidget {
  final List<_ComprasTicketsHeaderColumn> columns;
  final double contentWidth;

  const _ComprasTicketsHeaderRow({
    required this.columns,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    final tokens = AreaThemeScope.of(context);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: ContractGridScaledRow(
                child: SizedBox(
                  width: contentWidth + _kTicketActionsW,
                  child: Row(
                    children: [
                      for (final column in columns)
                        SizedBox(
                          width: column.width,
                          child: Row(
                            children: [
                              if (column.onFilter != null) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: column.onFilter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: column.active
                                          ? tokens.primary
                                          : tokens.badgeBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: column.active
                                            ? tokens.primaryStrong
                                            : tokens.border,
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: column.active
                                          ? Colors.white
                                          : tokens.badgeText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    column.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle.copyWith(
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: _kTicketActionsW),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ComprasTicketsHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _ComprasTicketsHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _ComprasTicketDataRow extends StatefulWidget {
  final ComprasTicketRecord row;
  final String dateLabel;
  final String Function(double value) weightFormatter;
  final String Function(double value) moneyFormatter;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onSecondarySelection;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _ComprasTicketDataRow({
    required this.row,
    required this.dateLabel,
    required this.weightFormatter,
    required this.moneyFormatter,
    required this.selected,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondarySelection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ComprasTicketDataRow> createState() => _ComprasTicketDataRowState();
}

class _ComprasTicketDataRowState extends State<_ComprasTicketDataRow> {
  bool _hovering = false;
  int? _hoveredEmphasisColumn;

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    widget.onSecondarySelection?.call();
    final action = await showMenu<_TicketRowMenuAction>(
      context: context,
      color: comprasAreaTokens.fieldSurface.withValues(alpha: 0.94),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
      ),
      items:
          [
                _TicketRowMenuAction(
                  label: 'Editar',
                  icon: Icons.edit_rounded,
                  onTap: () => unawaited(widget.onEdit()),
                ),
                _TicketRowMenuAction(
                  label: 'Eliminar',
                  icon: Icons.delete_outline_rounded,
                  onTap: () => unawaited(widget.onDelete()),
                ),
              ]
              .map((item) {
                return PopupMenuItem<_TicketRowMenuAction>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: comprasAreaTokens.primaryStrong,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: comprasAreaTokens.onGlass,
                        ),
                      ),
                    ],
                  ),
                );
              })
              .toList(growable: false),
    );
    action?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final softenDividers = _hoveredEmphasisColumn != null;
    final fill = widget.selected
        ? tokens.badgeBackground.withValues(alpha: 0.68)
        : _hovering
        ? tokens.glassSurface.withValues(alpha: 0.92)
        : tokens.fieldSurface.withValues(alpha: 0.78);

    Widget buildCell(int index, _TicketCellData cell) {
      final hoveredEmphasis = cell.emphasize && _hoveredEmphasisColumn == index;
      final cellChild = SizedBox(
        width: cell.width,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ContractEditableHoverCapsule(
                hovered: hoveredEmphasis,
                selectedContext: widget.selected,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: cell.child,
              ),
            ),
            Positioned(
              right: 4,
              top: 2,
              bottom: 2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 110),
                opacity: softenDividers ? 0.0 : 1.0,
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: tokens.border.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      if (!cell.emphasize) return cellChild;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredEmphasisColumn = index),
        onExit: (_) {
          if (_hoveredEmphasisColumn == index) {
            setState(() => _hoveredEmphasisColumn = null);
          }
        },
        child: cellChild,
      );
    }

    final cells = <_TicketCellData>[
      _TicketCellData(
        width: _kTicketDateW,
        child: _TicketCell(width: _kTicketDateW, text: widget.dateLabel),
      ),
      _TicketCellData(
        width: _kTicketNumberW,
        child: _TicketCell(
          width: _kTicketNumberW,
          text: widget.row.ticket,
          bold: true,
        ),
        emphasize: true,
      ),
      _TicketCellData(
        width: _kTicketProviderW,
        child: _TicketCell(
          width: _kTicketProviderW,
          text: widget.row.providerNameSnapshot,
        ),
        emphasize: true,
      ),
      _TicketCellData(
        width: _kTicketMaterialW,
        child: _TicketCell(
          width: _kTicketMaterialW,
          text: widget.row.materialNameSnapshot,
        ),
        emphasize: true,
      ),
      _TicketCellData(
        width: _kTicketWeightW,
        child: _TicketCell(
          width: _kTicketWeightW,
          text: widget.weightFormatter(widget.row.payableWeight),
          alignEnd: true,
        ),
      ),
      _TicketCellData(
        width: _kTicketPriceW,
        child: _TicketCell(
          width: _kTicketPriceW,
          text: widget.moneyFormatter(widget.row.price),
          alignEnd: true,
        ),
      ),
      _TicketCellData(
        width: _kTicketPremiumW,
        child: _TicketCell(
          width: _kTicketPremiumW,
          text: widget.moneyFormatter(widget.row.premium),
          alignEnd: true,
        ),
      ),
      _TicketCellData(
        width: _kTicketAmountW,
        child: _TicketCell(
          width: _kTicketAmountW,
          text: widget.moneyFormatter(widget.row.amount),
          alignEnd: true,
          bold: true,
        ),
      ),
      _TicketCellData(
        width: _kTicketFacturaW,
        child: _TicketCell(
          width: _kTicketFacturaW,
          child: _TicketBadge(
            label: comprasFacturaStatusLabel(widget.row.facturaStatus),
            tone: _facturaTone(widget.row.facturaStatus),
          ),
        ),
        emphasize: true,
      ),
      _TicketCellData(
        width: _kTicketPagoW,
        child: _TicketCell(
          width: _kTicketPagoW,
          child: _TicketBadge(
            label: comprasPagoStatusLabel(widget.row.pagoStatus),
            tone: _pagoTone(widget.row.pagoStatus),
          ),
        ),
        emphasize: true,
      ),
    ];
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        widget.onDragEnter?.call();
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            widget.onPrimaryPointerDown?.call();
          }
        },
        onPointerUp: (_) => widget.onPointerEnd?.call(),
        onPointerCancel: (_) => widget.onPointerEnd?.call(),
        child: Card(
          elevation: 0,
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: widget.selected
                  ? tokens.primaryStrong.withValues(alpha: 0.52)
                  : tokens.border.withValues(alpha: 0.72),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: ContractGridScaledRow(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onSecondaryTapDown: (details) {
                        unawaited(_openContextMenuAt(details.globalPosition));
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onTap,
                          onDoubleTap: () => unawaited(widget.onEdit()),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: _kTicketContentW + _kTicketActionsW,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < cells.length; i++)
                                    buildCell(i, cells[i]),
                                  AnchoredActionSlot(
                                    width: _kTicketActionsW,
                                    trailingWidth: 36,
                                    leading: const SizedBox.shrink(),
                                    trailing:
                                        PopupMenuButton<_TicketRowMenuAction>(
                                          tooltip: 'Acciones',
                                          padding: EdgeInsets.zero,
                                          color: comprasAreaTokens.fieldSurface
                                              .withValues(alpha: 0.94),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.70,
                                              ),
                                            ),
                                          ),
                                          onOpened: widget.onSecondarySelection,
                                          onSelected: (item) => item.onTap(),
                                          itemBuilder: (context) => [
                                            PopupMenuItem<_TicketRowMenuAction>(
                                              value: _TicketRowMenuAction(
                                                label: 'Editar',
                                                icon: Icons.edit_rounded,
                                                onTap: () =>
                                                    unawaited(widget.onEdit()),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_rounded,
                                                    size: 18,
                                                    color: comprasAreaTokens
                                                        .primaryStrong,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Editar',
                                                    style: TextStyle(
                                                      color: comprasAreaTokens
                                                          .onGlass,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<_TicketRowMenuAction>(
                                              value: _TicketRowMenuAction(
                                                label: 'Eliminar',
                                                icon: Icons
                                                    .delete_outline_rounded,
                                                onTap: () => unawaited(
                                                  widget.onDelete(),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: comprasAreaTokens
                                                        .primaryStrong,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Eliminar',
                                                    style: TextStyle(
                                                      color: comprasAreaTokens
                                                          .onGlass,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: widget.selected
                                                  ? tokens.primarySoft
                                                        .withValues(alpha: 0.42)
                                                  : tokens.fieldSurface
                                                        .withValues(
                                                          alpha: 0.92,
                                                        ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: widget.selected
                                                    ? tokens.primaryStrong
                                                          .withValues(
                                                            alpha: 0.36,
                                                          )
                                                    : tokens.border.withValues(
                                                        alpha: 0.82,
                                                      ),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                  color: Colors.black
                                                      .withValues(alpha: 0.06),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.more_horiz_rounded,
                                                size: 20,
                                                color: tokens.primaryStrong,
                                              ),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCellData {
  final double width;
  final Widget child;
  final bool emphasize;

  const _TicketCellData({
    required this.width,
    required this.child,
    this.emphasize = false,
  });
}

class _TicketRowMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TicketRowMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

Color _facturaTone(String status) {
  switch (status) {
    case 'FACTURADO':
      return const Color(0xFF0F766E);
    case 'PENDIENTE_DE_FACTURAR':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _pagoTone(String status) {
  switch (status) {
    case 'PAGADO':
      return const Color(0xFF0F766E);
    case 'ABONO':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFFB42318);
  }
}

class _TicketCell extends StatelessWidget {
  final double width;
  final String? text;
  final Widget? child;
  final bool alignEnd;
  final bool bold;

  const _TicketCell({
    required this.width,
    this.text,
    this.child,
    this.alignEnd = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Text(
          text ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: kComprasInk,
            height: 1.15,
          ),
        );
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: content,
        ),
      ),
    );
  }
}

class _TicketBadge extends StatelessWidget {
  final String label;
  final Color tone;

  const _TicketBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _TicketDialogField extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final IconData? trailingIcon;
  final TextEditingController? controller;
  final String? value;
  final bool readOnly;
  final String? hintText;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const _TicketDialogField({
    required this.width,
    required this.label,
    required this.icon,
    this.trailingIcon,
    this.controller,
    this.value,
    this.readOnly = false,
    this.hintText,
    this.keyboardType,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = _ticketDialogFieldDecoration(
      label: label,
      icon: icon,
      trailingIcon: trailingIcon,
      hintText: hintText,
    );
    final textStyle = TextStyle(
      fontWeight: FontWeight.w800,
      color: comprasAreaTokens.onGlass,
      fontSize: 13.5,
    );
    return SizedBox(
      width: width,
      child: controller != null
          ? TextField(
              controller: controller,
              readOnly: readOnly || onTap != null,
              onTap: onTap,
              onChanged: onChanged,
              keyboardType: keyboardType,
              style: textStyle,
              cursorColor: comprasAreaTokens.primary,
              decoration: decoration,
            )
          : TextField(
              readOnly: true,
              controller: TextEditingController(text: value ?? ''),
              onTap: onTap,
              style: textStyle,
              decoration: decoration,
            ),
    );
  }
}

class _TicketPickerField<T> extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String hintText;
  final String Function(T item) labelBuilder;
  final ValueChanged<T?> onChanged;

  const _TicketPickerField({
    required this.width,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.hintText,
    required this.labelBuilder,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showTicketsSingleSelectDialog<T>(
      context,
      title: label,
      initialValue: value,
      options: items
          .map(
            (item) =>
                _TicketsPickerOption<T>(value: item, label: labelBuilder(item)),
          )
          .toList(growable: false),
      allowClear: false,
    );
    if (selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return _TicketDialogField(
      width: width,
      label: label,
      icon: icon,
      value: value == null ? '' : labelBuilder(value as T),
      hintText: hintText,
      trailingIcon: Icons.keyboard_arrow_down_rounded,
      readOnly: true,
      onTap: () => _openPicker(context),
    );
  }
}

InputDecoration _ticketDialogFieldDecoration({
  required String label,
  required IconData icon,
  IconData? trailingIcon,
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: comprasAreaTokens.onGlass.withValues(alpha: 0.88),
    ),
    hintText: hintText,
    hintStyle: TextStyle(
      color: comprasAreaTokens.onGlass.withValues(alpha: 0.58),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: comprasAreaTokens.fieldSurface.withValues(alpha: 0.88),
    prefixIcon: Icon(icon, color: comprasAreaTokens.primary, size: 24),
    suffixIcon: trailingIcon == null
        ? null
        : Icon(
            trailingIcon,
            color: comprasAreaTokens.onGlass.withValues(alpha: 0.68),
            size: 24,
          ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.35,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: comprasAreaTokens.primary, width: 1.6),
    ),
  );
}

ButtonStyle _comprasRedFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: comprasAreaTokens.accent,
    foregroundColor: const Color(0xFF0B0E12),
    disabledBackgroundColor: comprasAreaTokens.accent.withValues(alpha: 0.42),
    disabledForegroundColor: const Color(0xFF0B0E12).withValues(alpha: 0.56),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

ButtonStyle _comprasRedOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: comprasAreaTokens.onGlass,
    side: BorderSide(color: Colors.white.withValues(alpha: 0.14), width: 1.4),
    backgroundColor: comprasAreaTokens.fieldSurface.withValues(alpha: 0.68),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

ButtonStyle _comprasPdfButtonStyle() {
  const pdfRed = Color(0xFFB42318);
  const pdfRedGlow = Color(0xFFE14B40);
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFFFE7E4),
    disabledForegroundColor: const Color(0xFFFFE7E4).withValues(alpha: 0.48),
    side: BorderSide(color: pdfRedGlow.withValues(alpha: 0.52), width: 1.45),
    backgroundColor: pdfRed.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    shadowColor: pdfRedGlow.withValues(alpha: 0.34),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => pdfRedGlow.withValues(
        alpha: states.contains(WidgetState.hovered) ? 0.12 : 0.06,
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return pdfRed.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.hovered)) {
        return pdfRed.withValues(alpha: 0.22);
      }
      return pdfRed.withValues(alpha: 0.14);
    }),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? pdfRedGlow.withValues(alpha: 0.20)
            : pdfRedGlow.withValues(
                alpha: states.contains(WidgetState.hovered) ? 0.72 : 0.52,
              ),
        width: states.contains(WidgetState.hovered) ? 1.7 : 1.45,
      ),
    ),
    elevation: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered) ? 2 : 0,
    ),
  );
}

Future<bool?> _showTicketDeleteConfirmDialog(
  BuildContext context, {
  required int count,
  required String subject,
}) {
  final plural = count == 1 ? 'este registro' : 'estos registros';
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ContractGlassCard(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: comprasAreaTokens.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: comprasAreaTokens.onGlass,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Confirmar eliminación',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kComprasInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Vas a eliminar $subject. Esta acción quitará ${count == 1 ? plural : '$count tickets'} del grid y del backend.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: kComprasMutedInk.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _comprasRedOutlinedButtonStyle(),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: _comprasRedFilledButtonStyle(),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<DateTime?> _showComprasThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      final theme = Theme.of(context);
      final primary = comprasAreaTokens.accent;
      const onPrimary = Color(0xFF0B0E12);
      const surface = Color(0xFF12171C);
      final onSurface = comprasAreaTokens.onGlass;
      final colorScheme = theme.colorScheme.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
      );
      return Theme(
        data: theme.copyWith(
          colorScheme: colorScheme,
          datePickerTheme: DatePickerThemeData(
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: primary,
            headerForegroundColor: onPrimary,
            rangeSelectionBackgroundColor: primary.withValues(alpha: 0.16),
            rangeSelectionOverlayColor: WidgetStateProperty.all(
              primary.withValues(alpha: 0.08),
            ),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return onPrimary;
              return onSurface;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return primary;
              return null;
            }),
            todayForegroundColor: WidgetStateProperty.all(primary),
            todayBorder: BorderSide(color: primary, width: 1.4),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: comprasAreaTokens.onGlass,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

String _formatTicketFilterDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _comprasTicketMonthNameEs(int month) {
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

Future<DateTimeRange?> _showTicketDateRangeDialog(
  BuildContext context, {
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange?>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? firstDate).year,
        (initialRange?.start ?? firstDate).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      return AreaThemeScope(
        tokens: comprasAreaTokens,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final tokens = AreaThemeScope.of(context);
            final theme = Theme.of(context);
            final monthFirst = DateTime(
              displayMonth.year,
              displayMonth.month,
              1,
            );
            final leading = (monthFirst.weekday + 6) % 7;
            final gridStart = monthFirst.subtract(Duration(days: leading));
            final previewEnd = end ?? hover;

            bool withinBounds(DateTime day) {
              final d = dateOnly(day);
              return !d.isBefore(dateOnly(firstDate)) &&
                  !d.isAfter(dateOnly(lastDate));
            }

            bool inPreviewRange(DateTime day) {
              if (start == null || previewEnd == null) return false;
              final a = dateOnly(start!);
              final b = dateOnly(previewEnd);
              final from = a.isBefore(b) ? a : b;
              final to = a.isBefore(b) ? b : a;
              final d = dateOnly(day);
              return !d.isBefore(from) && !d.isAfter(to);
            }

            DateTimeRange? buildResult() {
              if (start == null) return null;
              final s = dateOnly(start!);
              final e = dateOnly(end ?? start!);
              final from = s.isBefore(e) ? s : e;
              final to = s.isBefore(e) ? e : s;
              return DateTimeRange(start: from, end: to);
            }

            final colorScheme = theme.colorScheme.copyWith(
              primary: tokens.primaryStrong,
              secondary: tokens.primary,
              surface: const Color(0xFF151A20),
              onSurface: tokens.onGlass,
            );

            return Theme(
              data: theme.copyWith(
                colorScheme: colorScheme,
                splashColor: tokens.primaryStrong.withValues(alpha: 0.12),
                highlightColor: tokens.primaryStrong.withValues(alpha: 0.08),
                hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
                focusColor: tokens.primarySoft.withValues(alpha: 0.16),
                iconTheme: IconThemeData(color: tokens.primaryStrong),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
                    highlightColor: tokens.primaryStrong.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    overlayColor: tokens.primaryStrong.withValues(alpha: 0.08),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.primaryStrong,
                    overlayColor: tokens.primaryStrong.withValues(alpha: 0.08),
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    overlayColor: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 516,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtrar fecha',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            color: tokens.primaryStrong,
                            onPressed: () => setLocalState(
                              () => displayMonth = DateTime(
                                displayMonth.year,
                                displayMonth.month - 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_comprasTicketMonthNameEs(monthFirst.month)} ${monthFirst.year}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: tokens.badgeText,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            color: tokens.primaryStrong,
                            onPressed: () => setLocalState(
                              () => displayMonth = DateTime(
                                displayMonth.year,
                                displayMonth.month + 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final dayLabel in const [
                            'L',
                            'M',
                            'M',
                            'J',
                            'V',
                            'S',
                            'D',
                          ])
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 42,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.08,
                            ),
                        itemBuilder: (_, index) {
                          final day = gridStart.add(Duration(days: index));
                          final inMonth = day.month == monthFirst.month;
                          final allowed = withinBounds(day);
                          final active =
                              (start != null && isSameDay(day, start!)) ||
                              (end != null && isSameDay(day, end!));
                          final inRange = inPreviewRange(day) && allowed;
                          return MouseRegion(
                            onEnter: (_) {
                              if (start != null && end == null && allowed) {
                                setLocalState(() => hover = dateOnly(day));
                              }
                            },
                            child: GestureDetector(
                              onTap: !allowed
                                  ? null
                                  : () {
                                      final picked = dateOnly(day);
                                      setLocalState(() {
                                        if (start == null || end != null) {
                                          start = picked;
                                          end = null;
                                          hover = null;
                                        } else {
                                          end = picked;
                                          hover = null;
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: active
                                      ? tokens.primaryStrong.withValues(
                                          alpha: 0.18,
                                        )
                                      : inRange
                                      ? tokens.primarySoft.withValues(
                                          alpha: 0.24,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? tokens.primaryStrong.withValues(
                                            alpha: 0.46,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: active
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: !allowed
                                          ? tokens.badgeText.withValues(
                                              alpha: 0.28,
                                            )
                                          : inMonth
                                          ? tokens.primaryStrong
                                          : tokens.badgeText.withValues(
                                              alpha: 0.55,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        start == null
                            ? 'Selecciona fecha inicial'
                            : end == null
                            ? 'Selecciona fecha final'
                            : '${_formatTicketFilterDate(start!)} - ${_formatTicketFilterDate(end!)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: _comprasRedOutlinedButtonStyle(),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: _comprasRedOutlinedButtonStyle(),
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(_kClearedTicketDateRange),
                            child: const Text('Limpiar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: _comprasRedFilledButtonStyle(),
                            onPressed: start == null
                                ? null
                                : () => Navigator.of(
                                    dialogContext,
                                  ).pop(buildResult()),
                            child: const Text('Aplicar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _TicketPreviewCard extends StatelessWidget {
  final ComprasTicketRecord preview;

  const _TicketPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          _PreviewMetric(
            label: 'Neto',
            value: preview.netWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Peso pagable',
            value: preview.payableWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Tarifa final',
            value: '\$${(preview.price + preview.premium).toStringAsFixed(2)}',
          ),
          _PreviewMetric(
            label: 'Importe',
            value: '\$${preview.amount.toStringAsFixed(2)}',
          ),
          _PreviewMetric(
            label: 'Factura',
            value: comprasFacturaStatusLabel(preview.facturaStatus),
          ),
          _PreviewMetric(
            label: 'Pago',
            value: comprasPagoStatusLabel(preview.pagoStatus),
          ),
        ],
      ),
    );
  }
}

class _TicketFormSection extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _TicketFormSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: comprasAreaTokens.glassSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: comprasAreaTokens.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: comprasAreaTokens.onGlass,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kComprasMutedInk.withValues(alpha: 0.86),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 16, children: children),
        ],
      ),
    );
  }
}

class _TicketInlinePreviewCard extends StatelessWidget {
  final ComprasTicketRecord preview;

  const _TicketInlinePreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            comprasAreaTokens.fieldSurface.withValues(alpha: 0.92),
            comprasAreaTokens.glassSurface.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        children: [
          _PreviewMetric(
            label: 'Tarifa final',
            value: '\$${(preview.price + preview.premium).toStringAsFixed(2)}',
          ),
          _PreviewMetric(
            label: 'Neto',
            value: preview.netWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Peso pagable',
            value: preview.payableWeight.toStringAsFixed(2),
          ),
          _PreviewMetric(
            label: 'Importe',
            value: '\$${preview.amount.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kComprasMutedInk.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kComprasInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComprasTicketsEmptyState extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _ComprasTicketsEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 44,
              color: kComprasMutedInk,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay tickets registrados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kComprasInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Captura el primer ticket para empezar a construir cuenta por proveedor, facturación y pagos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kComprasMutedInk,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: _comprasRedFilledButtonStyle(),
              onPressed: () => unawaited(onCreate()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComprasTicketsSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessFinanzasArea;
  final ValueChanged<String> onNavigate;

  const _ComprasTicketsSidePanel({
    required this.canReturnToDirection,
    required this.canAccessFinanzasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compras Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _ComprasTicketsNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _ComprasTicketsSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _ComprasTicketsNavItem(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Tickets Compras',
                      subtitle: 'Captura y seguimiento operativo',
                      accented: true,
                      onTap: () async {},
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.tune_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTap: () async => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo Compras',
                      subtitle: 'Proveedores, materiales y precios',
                      onTap: () async => onNavigate('Catálogo Compras'),
                    ),
                    const SizedBox(height: 8),
                    _ComprasTicketsNavItem(
                      icon: Icons.badge_rounded,
                      title: 'Directorio Proveedores',
                      subtitle: 'Crédito, contacto y operación',
                      onTap: () async => onNavigate('Directorio Proveedores'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _ComprasTicketsSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _ComprasTicketsNavItem(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Dashboard Compras',
                subtitle: 'Vista general del área',
                onTap: () async => onNavigate('Dashboard Compras'),
              ),
              if (canAccessFinanzasArea) const SizedBox(height: 8),
              if (canAccessFinanzasArea)
                _ComprasTicketsNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Dashboard Finanzas',
                  subtitle: 'Pagos, liquidez y compromisos',
                  onTap: () async => onNavigate('Dashboard Finanzas'),
                ),
              if (canReturnToDirection) const SizedBox(height: 8),
              if (canReturnToDirection)
                _ComprasTicketsNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function() onTap;

  const _ComprasTicketsNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: accented
                ? tokens.primaryStrong.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accented
                  ? tokens.primaryStrong.withValues(alpha: 0.28)
                  : tokens.border.withValues(alpha: 0.46),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: accented ? tokens.primaryStrong : kComprasInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: accented ? tokens.primaryStrong : kComprasInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kComprasMutedInk,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComprasTicketsSectionHeader extends StatelessWidget {
  final String label;

  const _ComprasTicketsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
        color: comprasAreaTokens.primaryStrong.withValues(alpha: 0.74),
      ),
    );
  }
}

class _ComprasTicketsBackground extends StatelessWidget {
  const _ComprasTicketsBackground();

  @override
  Widget build(BuildContext context) {
    return const ComprasAreaBackground();
  }
}

class _TicketsPickerOption<T> {
  final T value;
  final String label;

  const _TicketsPickerOption({required this.value, required this.label});
}

class _TicketsPickerOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _TicketsPickerOptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? comprasAreaTokens.badgeBackground.withValues(alpha: 0.76)
        : highlighted
        ? comprasAreaTokens.glassSurface.withValues(alpha: 0.82)
        : comprasAreaTokens.fieldSurface.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: comprasAreaTokens.onGlass,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: comprasAreaTokens.primaryStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> _showTicketsSingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required T? initialValue,
  required List<_TicketsPickerOption<T>> options,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });
      final itemFocusNodes = <FocusNode>[];
      String query = '';
      int? focusedIndex;

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where((option) {
                final normalizedQuery = query.trim().toUpperCase();
                if (normalizedQuery.isEmpty) return true;
                return option.label.toUpperCase().contains(normalizedQuery);
              })
              .toList(growable: false);

          while (itemFocusNodes.length < filtered.length) {
            itemFocusNodes.add(FocusNode());
          }
          while (itemFocusNodes.length > filtered.length) {
            itemFocusNodes.removeLast().dispose();
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  filtered.isNotEmpty) {
                itemFocusNodes.first.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 560,
                ),
                child: ContractGlassCard(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: kComprasInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchC,
                        focusNode: searchFocus,
                        autofocus: true,
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Buscar',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) =>
                            setLocalState(() => query = value),
                      ),
                      if (allowClear) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            style: TextButton.styleFrom(
                              foregroundColor: comprasAreaTokens.onGlass,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            child: const Text('Limpiar selección'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('Sin resultados'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final option = filtered[i];
                                  final selected = option.value == initialValue;
                                  final highlighted = focusedIndex == i;
                                  return Focus(
                                    focusNode: itemFocusNodes[i],
                                    onFocusChange: (hasFocus) {
                                      if (hasFocus) {
                                        setLocalState(() => focusedIndex = i);
                                      } else if (focusedIndex == i) {
                                        setLocalState(
                                          () => focusedIndex = null,
                                        );
                                      }
                                    },
                                    onKeyEvent: (_, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowUp) {
                                        if (i == 0) {
                                          searchFocus.requestFocus();
                                        } else {
                                          itemFocusNodes[i - 1].requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey ==
                                              LogicalKeyboardKey.arrowDown &&
                                          i < itemFocusNodes.length - 1) {
                                        itemFocusNodes[i + 1].requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey ==
                                              LogicalKeyboardKey.enter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.numpadEnter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.space) {
                                        Navigator.of(
                                          dialogContext,
                                        ).pop(option.value);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: _TicketsPickerOptionTile(
                                      label: option.label,
                                      selected: selected,
                                      highlighted: highlighted,
                                      onTap: () => Navigator.of(
                                        dialogContext,
                                      ).pop(option.value),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

Future<Set<T>?> _showTicketsMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> initialValues,
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (dialogContext) {
      final selected = <T>{...initialValues};
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });
      String query = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedQuery = query.trim().toUpperCase();
          final filteredOptions = options
              .where((option) {
                if (normalizedQuery.isEmpty) return true;
                return option.toString().toUpperCase().contains(
                  normalizedQuery,
                );
              })
              .toList(growable: false);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
              child: ContractGlassCard(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kComprasInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchC,
                      focusNode: searchFocus,
                      autofocus: true,
                      decoration: contractGlassFieldDecoration(
                        context,
                        hintText: 'Buscar opción',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filteredOptions.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView(
                              children: [
                                for (final option in filteredOptions)
                                  CheckboxListTile(
                                    activeColor: comprasAreaTokens.accent,
                                    checkColor: const Color(0xFF0B0E12),
                                    value: selected.contains(option),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    title: Text(
                                      option.toString(),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selected.add(option);
                                        } else {
                                          selected.remove(option);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _comprasRedOutlinedButtonStyle(),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(null),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => selected.clear()),
                          style: TextButton.styleFrom(
                            foregroundColor: comprasAreaTokens.onGlass,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: const Text('Limpiar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: _comprasRedFilledButtonStyle(),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(selected),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
