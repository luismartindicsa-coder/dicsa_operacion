import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_dashboard_preview_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

class MayoreoPriceAdjustmentsPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoPriceAdjustmentsPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoPriceAdjustmentsPage> createState() =>
      _MayoreoPriceAdjustmentsPageState();
}

class _MayoreoPriceAdjustmentsPageState
    extends State<MayoreoPriceAdjustmentsPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  String _historyMovementFilter = 'todos';
  String? _historyCompanyFilter;
  String? _historyMaterialFilter;
  late List<_MayoreoSalePriceRow> _rows;
  late List<_MayoreoPriceHistoryRow> _historyRows;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    _rows = _seedPriceRows();
    _historyRows = _seedHistoryRows();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoDashboardPreviewPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openSalesReports() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoSalesReportPage(instantOpen: true)),
    );
  }

  Future<void> _exportClientPdfReport() async {
    final historyRows = _filteredHistoryRows;
    if (historyRows.isEmpty) {
      _toast('No hay movimientos para exportar en PDF.');
      return;
    }

    try {
      if (kIsWeb) {
        _toast('La exportación PDF en web no está habilitada aquí');
        return;
      }

      final baseDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccionar carpeta base para reportes de Mayoreo',
        lockParentWindow: true,
      );
      if (baseDirectory == null || baseDirectory.trim().isEmpty) {
        _toast('Guardado cancelado');
        return;
      }

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final orderedRows = List<_MayoreoPriceHistoryRow>.from(historyRows)
        ..sort((a, b) {
          final byCompany = a.companyName.compareTo(b.companyName);
          if (byCompany != 0) return byCompany;
          return a.materialName.compareTo(b.materialName);
        });
      final groupedHistory = <String, List<_MayoreoPriceHistoryRow>>{};
      for (final row in orderedRows) {
        groupedHistory
            .putIfAbsent(row.companyName, () => <_MayoreoPriceHistoryRow>[])
            .add(row);
      }

      final visibleCompanies = groupedHistory.keys.toSet();
      final currentRows = _rows
          .where((row) {
            if (!visibleCompanies.contains(row.companyName)) return false;
            if (_historyMaterialFilter != null &&
                row.materialName != _historyMaterialFilter) {
              return false;
            }
            return true;
          })
          .toList(growable: false);

      final now = DateTime.now();
      final dateLabel =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final dateSuffix =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${(now.year % 100).toString().padLeft(2, '0')}';
      final reportsRoot = Directory(
        '$baseDirectory${Platform.pathSeparator}Precios mayoreo $dateSuffix',
      );
      await reportsRoot.create(recursive: true);

      final accent = const PdfColor.fromInt(0xFF9A6A00);
      final softAccent = const PdfColor.fromInt(0xFFFFF4CC);
      final border = const PdfColor.fromInt(0xFFE7C96B);
      final text = const PdfColor.fromInt(0xFF3A2F1B);
      var writtenCount = 0;

      final companyNames = groupedHistory.keys.toList()..sort();
      for (final companyName in companyNames) {
        final companyHistoryRows = groupedHistory[companyName]!
          ..sort((a, b) {
            final byMaterial = a.materialName.compareTo(b.materialName);
            if (byMaterial != 0) return byMaterial;
            return b.createdAt.compareTo(a.createdAt);
          });
        final companyCurrentRows =
            currentRows
                .where((row) => row.companyName == companyName)
                .toList(growable: false)
              ..sort((a, b) => a.materialName.compareTo(b.materialName));
        final lastAdjustmentAt = companyHistoryRows
            .map((row) => row.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final totalCurrent = companyCurrentRows.fold<double>(
          0,
          (sum, row) => sum + row.currentPrice,
        );
        final avgCurrent = companyCurrentRows.isEmpty
            ? 0.0
            : totalCurrent / companyCurrentRows.length;
        final latestHistoryByMaterial = <String, _MayoreoPriceHistoryRow>{};
        for (final row in companyHistoryRows) {
          latestHistoryByMaterial.putIfAbsent(row.materialName, () => row);
        }
        final latestHistoryRows = latestHistoryByMaterial.values.toList(
          growable: false,
        )..sort((a, b) => a.materialName.compareTo(b.materialName));

        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageTheme: pw.PageTheme(
              margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
            ),
            build: (_) => [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(18),
                  border: pw.Border.all(color: border, width: 1.2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 56,
                          height: 56,
                          decoration: pw.BoxDecoration(
                            color: softAccent,
                            borderRadius: pw.BorderRadius.circular(14),
                          ),
                          child: logoImage != null
                              ? pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Image(logoImage),
                                )
                              : pw.Center(
                                  child: pw.Text(
                                    'D',
                                    style: pw.TextStyle(
                                      color: accent,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'LISTA DE PRECIOS FINALES',
                                style: pw.TextStyle(
                                  color: accent,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: pw.BoxDecoration(
                            color: softAccent,
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Text(
                            'VIGENCIA $dateLabel',
                            style: pw.TextStyle(
                              color: accent,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: pw.BoxDecoration(
                        color: softAccent,
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            companyName,
                            style: pw.TextStyle(
                              color: accent,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'MAYOREO · ${_movementFilterLabel(_historyMovementFilter)}',
                            style: pw.TextStyle(
                              color: text,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      children: [
                        _pdfSummaryTile(
                          label: 'MATERIALES VIGENTES',
                          value: companyCurrentRows.length.toString(),
                          accent: accent,
                          softAccent: softAccent,
                        ),
                        pw.SizedBox(width: 10),
                        _pdfSummaryTile(
                          label: 'PROMEDIO FINAL',
                          value: formatMoney(avgCurrent),
                          accent: accent,
                          softAccent: softAccent,
                        ),
                        pw.SizedBox(width: 10),
                        _pdfSummaryTile(
                          label: 'ULTIMO CAMBIO',
                          value: _formatDateTime(lastAdjustmentAt),
                          accent: accent,
                          softAccent: softAccent,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(16),
                        border: pw.Border.all(color: border, width: 1),
                      ),
                      child: pw.TableHelper.fromTextArray(
                        headers: const ['MATERIAL', 'PRECIO FINAL'],
                        data: companyCurrentRows
                            .map(
                              (row) => [
                                row.materialName.toUpperCase(),
                                formatMoney(row.currentPrice),
                              ],
                            )
                            .toList(growable: false),
                        cellAlignment: pw.Alignment.centerLeft,
                        headerStyle: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                        cellStyle: pw.TextStyle(color: text, fontSize: 10),
                        headerDecoration: pw.BoxDecoration(
                          color: accent,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(15),
                            topRight: pw.Radius.circular(15),
                          ),
                        ),
                        rowDecoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                        ),
                        oddRowDecoration: pw.BoxDecoration(color: softAccent),
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                            color: border,
                            width: 0.7,
                          ),
                        ),
                        headerPadding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        cellPadding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        columnWidths: <int, pw.TableColumnWidth>{
                          0: const pw.FlexColumnWidth(4),
                          1: const pw.FlexColumnWidth(1.5),
                        },
                      ),
                    ),
                    if (companyHistoryRows.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'HISTORIAL RECIENTE POR MATERIAL',
                        style: pw.TextStyle(
                          color: accent,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(16),
                          border: pw.Border.all(color: border, width: 1),
                        ),
                        child: pw.TableHelper.fromTextArray(
                          headers: const [
                            'FECHA',
                            'MATERIAL',
                            'ANTERIOR',
                            'NUEVO',
                            'PRECIO FINAL',
                          ],
                          data: latestHistoryRows
                              .map(
                                (row) => [
                                  _formatDateTime(row.createdAt),
                                  row.materialName.toUpperCase(),
                                  formatMoney(row.previousPrice),
                                  formatMoney(row.newPrice),
                                  formatMoney(row.newPrice),
                                ],
                              )
                              .toList(growable: false),
                          cellAlignment: pw.Alignment.centerLeft,
                          headerStyle: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9.6,
                          ),
                          cellStyle: pw.TextStyle(color: text, fontSize: 9.3),
                          headerDecoration: pw.BoxDecoration(
                            color: accent,
                            borderRadius: const pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(15),
                              topRight: pw.Radius.circular(15),
                            ),
                          ),
                          rowDecoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                          ),
                          oddRowDecoration: pw.BoxDecoration(color: softAccent),
                          border: pw.TableBorder(
                            horizontalInside: pw.BorderSide(
                              color: border,
                              width: 0.7,
                            ),
                          ),
                          headerPadding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          cellPadding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          columnWidths: <int, pw.TableColumnWidth>{
                            0: const pw.FlexColumnWidth(1.6),
                            1: const pw.FlexColumnWidth(2.7),
                            2: const pw.FlexColumnWidth(1.2),
                            3: const pw.FlexColumnWidth(1.2),
                            4: const pw.FlexColumnWidth(1.3),
                          },
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Este documento refleja los precios finales vigentes al momento de su emision.',
                        style: pw.TextStyle(color: text, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

        final companyDir = Directory(
          '${reportsRoot.path}${Platform.pathSeparator}${_sanitizePathSegment(companyName)}',
        );
        await companyDir.create(recursive: true);
        final fileName = '${_sanitizePathSegment(companyName)} $dateSuffix.pdf';
        final file = File(
          '${companyDir.path}${Platform.pathSeparator}$fileName',
        );
        await file.writeAsBytes(await doc.save(), flush: true);
        writtenCount += 1;
      }

      _toast('Se generaron $writtenCount PDF(s) en ${reportsRoot.path}');
    } catch (e) {
      _toast('No se pudo generar PDF: $e');
    }
  }

  void _showStub(String label) {
    _toast('$label quedará conectado en la siguiente fase de Mayoreo.');
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Mayoreo':
        unawaited(_openDashboard());
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesReports());
        return;
      case 'Descargar PDF':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_exportClientPdfReport());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _showStub(label);
    }
  }

  List<String> get _availableCompanies {
    final values =
        _rows.map((row) => row.companyName).toSet().toList(growable: false)
          ..sort();
    return values;
  }

  List<String> get _availableMaterials {
    final values =
        _rows
            .where((row) {
              if (_historyCompanyFilter == null) return true;
              return row.companyName == _historyCompanyFilter;
            })
            .map((row) => row.materialName)
            .toSet()
            .toList(growable: false)
          ..sort();
    return values;
  }

  List<_MayoreoPriceHistoryRow> get _filteredHistoryRows {
    return _historyRows
        .where((row) {
          if (_historyMovementFilter != 'todos') {
            switch (_historyMovementFilter) {
              case 'altas':
                if (row.movementLabel != 'SUBE') return false;
                break;
              case 'bajas':
                if (row.movementLabel != 'BAJA') return false;
                break;
              case 'sin_cambio':
                if (row.movementLabel != 'IGUAL') return false;
                break;
            }
          }
          if (_historyCompanyFilter != null &&
              row.companyName != _historyCompanyFilter) {
            return false;
          }
          if (_historyMaterialFilter != null &&
              row.materialName != _historyMaterialFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _showAdjustmentDialog() async {
    final dialogRowsScrollController = ScrollController();
    final adjustmentValueC = TextEditingController();
    final reasonC = TextEditingController();
    String? selectedCompany;
    String? selectedMaterial;
    int deltaDirection = 1;
    String? activePriceId;
    String? anchorPriceId;
    final Set<String> selectedPriceIds = <String>{};

    double computeNewPrice(double current) {
      final raw = double.tryParse(adjustmentValueC.text.trim()) ?? 0;
      return current + (raw * deltaDirection);
    }

    List<_MayoreoSalePriceRow> filteredRows() {
      return _rows
          .where((row) {
            if (!row.active) return false;
            if (selectedCompany != null && row.companyName != selectedCompany) {
              return false;
            }
            if (selectedMaterial != null &&
                row.materialName != selectedMaterial) {
              return false;
            }
            return true;
          })
          .toList(growable: false);
    }

    List<String> availableMaterials() {
      final values =
          _rows
              .where((row) {
                if (!row.active) return false;
                if (selectedCompany != null &&
                    row.companyName != selectedCompany) {
                  return false;
                }
                return true;
              })
              .map((row) => row.materialName)
              .toSet()
              .toList(growable: false)
            ..sort();
      return values;
    }

    void activateRow(
      StateSetter setLocal,
      String priceId, {
      bool extend = false,
      bool toggle = false,
    }) {
      final visible = filteredRows();
      setLocal(() {
        activePriceId = priceId;
        if (toggle) {
          if (selectedPriceIds.contains(priceId)) {
            selectedPriceIds.remove(priceId);
          } else {
            selectedPriceIds.add(priceId);
          }
          anchorPriceId ??= priceId;
          return;
        }
        if (extend && anchorPriceId != null) {
          final start = visible.indexWhere((row) => row.id == anchorPriceId);
          final end = visible.indexWhere((row) => row.id == priceId);
          if (start != -1 && end != -1) {
            final low = start < end ? start : end;
            final high = start < end ? end : start;
            selectedPriceIds
              ..clear()
              ..addAll(
                visible
                    .sublist(low, high + 1)
                    .map((row) => row.id)
                    .toList(growable: false),
              );
            return;
          }
        }
        selectedPriceIds
          ..clear()
          ..add(priceId);
        anchorPriceId = priceId;
      });
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AreaThemeScope(
            tokens: mayoreoAreaTokens,
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                void applySelection() {
                  final raw = double.tryParse(adjustmentValueC.text.trim());
                  if (raw == null) {
                    _toast('Ingresa un valor de ajuste válido');
                    return;
                  }
                  if (raw == 0) {
                    _toast('El ajuste no puede ser cero');
                    return;
                  }
                  final selectedRows = _rows
                      .where((row) => selectedPriceIds.contains(row.id))
                      .toList(growable: false);
                  if (selectedRows.any(
                    (row) => computeNewPrice(row.currentPrice) < 0,
                  )) {
                    _toast('El ajuste genera al menos un precio negativo');
                    return;
                  }
                  final reason = reasonC.text.trim();
                  if (reason.isEmpty) {
                    _toast('Ingresa el motivo del ajuste');
                    return;
                  }
                  final now = DateTime.now();
                  setState(() {
                    _rows = _rows
                        .map((row) {
                          if (!selectedPriceIds.contains(row.id)) {
                            return row;
                          }
                          final nextPrice = computeNewPrice(row.currentPrice);
                          return row.copyWith(
                            currentPrice: nextPrice,
                            updatedAt: now,
                            notes: reason,
                          );
                        })
                        .toList(growable: false);
                    _historyRows = [
                      ...selectedRows.map(
                        (row) => _MayoreoPriceHistoryRow(
                          id: '${row.id}-${now.microsecondsSinceEpoch}',
                          companyName: row.companyName,
                          materialName: row.materialName,
                          previousPrice: row.currentPrice,
                          newPrice: computeNewPrice(row.currentPrice),
                          reason: reason,
                          createdAt: now,
                        ),
                      ),
                      ..._historyRows,
                    ];
                  });
                  Navigator.of(dialogContext).pop();
                  _toast(
                    'Ajuste aplicado a ${selectedPriceIds.length} precio(s)',
                  );
                }

                final visibleRows = filteredRows();
                return Focus(
                  autofocus: true,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.of(dialogContext).pop();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter &&
                        selectedPriceIds.isNotEmpty &&
                        reasonC.text.trim().isNotEmpty &&
                        adjustmentValueC.text.trim().isNotEmpty) {
                      final raw = double.tryParse(adjustmentValueC.text.trim());
                      if (raw == null || raw == 0) {
                        return KeyEventResult.handled;
                      }
                      applySelection();
                      return KeyEventResult.handled;
                    }
                    if (visibleRows.isEmpty) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final currentIndex = visibleRows.indexWhere(
                        (row) => row.id == activePriceId,
                      );
                      final nextIndex = currentIndex < 0
                          ? 0
                          : (currentIndex + 1).clamp(0, visibleRows.length - 1);
                      activateRow(
                        setLocalState,
                        visibleRows[nextIndex].id,
                        extend: HardwareKeyboard.instance.isShiftPressed,
                      );
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final currentIndex = visibleRows.indexWhere(
                        (row) => row.id == activePriceId,
                      );
                      final nextIndex = currentIndex < 0
                          ? 0
                          : (currentIndex - 1).clamp(0, visibleRows.length - 1);
                      activateRow(
                        setLocalState,
                        visibleRows[nextIndex].id,
                        extend: HardwareKeyboard.instance.isShiftPressed,
                      );
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: ContractPopupSurface(
                      constraints: const BoxConstraints(
                        maxWidth: 980,
                        maxHeight: 860,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: SingleChildScrollView(
                        child: _MayoreoAdjustmentWorkspaceCard(
                          rows: visibleRows,
                          selectedRows: _rows
                              .where((row) => selectedPriceIds.contains(row.id))
                              .toList(growable: false),
                          selectedCompany: selectedCompany,
                          selectedMaterial: selectedMaterial,
                          availableCompanies: _availableCompanies,
                          availableMaterials: availableMaterials(),
                          activePriceId: activePriceId,
                          adjustmentValueC: adjustmentValueC,
                          reasonC: reasonC,
                          deltaDirection: deltaDirection,
                          computeNewPrice: computeNewPrice,
                          rowsScrollController: dialogRowsScrollController,
                          onClose: () => Navigator.of(dialogContext).pop(),
                          onCompanyChanged: (value) {
                            setLocalState(() {
                              selectedCompany = value;
                              if (selectedMaterial != null &&
                                  !availableMaterials().contains(
                                    selectedMaterial,
                                  )) {
                                selectedMaterial = null;
                              }
                            });
                          },
                          onMaterialChanged: (value) {
                            setLocalState(() => selectedMaterial = value);
                          },
                          onDirectionChanged: (value) {
                            setLocalState(() => deltaDirection = value);
                          },
                          onRefreshPreview: () => setLocalState(() {}),
                          onSelectAllVisible: visibleRows.isEmpty
                              ? null
                              : () => setLocalState(() {
                                  final firstId = visibleRows.first.id;
                                  activePriceId = firstId;
                                  anchorPriceId = firstId;
                                  selectedPriceIds
                                    ..clear()
                                    ..addAll(visibleRows.map((row) => row.id));
                                }),
                          onClearSelection: selectedPriceIds.isEmpty
                              ? null
                              : () => setLocalState(() {
                                  selectedPriceIds.clear();
                                  activePriceId = null;
                                  anchorPriceId = null;
                                }),
                          onToggleRow: (rowId) {
                            activateRow(setLocalState, rowId, toggle: true);
                          },
                          onActivateRow: (rowId) {
                            final keyboard = HardwareKeyboard.instance;
                            activateRow(
                              setLocalState,
                              rowId,
                              extend: keyboard.isShiftPressed,
                              toggle:
                                  keyboard.isControlPressed ||
                                  keyboard.isMetaPressed,
                            );
                          },
                          onApply: selectedPriceIds.isEmpty
                              ? null
                              : applySelection,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } finally {
      dialogRowsScrollController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
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
          background: const _MayoreoPriceAdjustmentsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _MayoreoPriceHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _MayoreoPriceBrand(),
          trailingBuilder: (_, _) => _MayoreoPriceHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: () async {},
          ),
          child: Stack(
            children: [
              _MayoreoPriceAdjustmentsBody(
                historyRows: _filteredHistoryRows,
                allHistoryRows: _historyRows,
                movementFilter: _historyMovementFilter,
                companyFilter: _historyCompanyFilter,
                materialFilter: _historyMaterialFilter,
                availableCompanies: _availableCompanies,
                availableMaterials: _availableMaterials,
                onMovementChanged: (value) =>
                    setState(() => _historyMovementFilter = value),
                onCompanyChanged: (value) => setState(() {
                  _historyCompanyFilter = value;
                  if (_historyMaterialFilter != null &&
                      !_availableMaterials.contains(_historyMaterialFilter)) {
                    _historyMaterialFilter = null;
                  }
                }),
                onMaterialChanged: (value) =>
                    setState(() => _historyMaterialFilter = value),
                onClearFilters: () => setState(() {
                  _historyMovementFilter = 'todos';
                  _historyCompanyFilter = null;
                  _historyMaterialFilter = null;
                }),
                onOpenAdjustmentDialog: _showAdjustmentDialog,
                onExportPdf: _exportClientPdfReport,
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
                  child: _MayoreoPriceSidePanel(
                    canReturnToDirection: _canReturnToDirection,
                    onNavigate: _handleNavigationAction,
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

class _MayoreoPriceAdjustmentsBackground extends StatelessWidget {
  const _MayoreoPriceAdjustmentsBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                const Color(0xFFFFF0B4),
                tokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -220,
          top: -110,
          child: _backgroundCircle(
            700,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.86),
                const Color(0xFFFFECA0),
              ],
            ),
          ),
        ),
        Positioned(
          right: -160,
          top: -60,
          child: _backgroundCircle(
            540,
            LinearGradient(
              colors: [
                const Color(0xFFFFEA3F).withValues(alpha: 0.74),
                const Color(0xFFF39C12).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, Gradient gradient) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _MayoreoPriceBrand extends StatelessWidget {
  const _MayoreoPriceBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        const Text(
          'Ajuste de precios',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MayoreoAdjustmentWorkspaceCard extends StatelessWidget {
  final List<_MayoreoSalePriceRow> rows;
  final List<_MayoreoSalePriceRow> selectedRows;
  final String? selectedCompany;
  final String? selectedMaterial;
  final List<String> availableCompanies;
  final List<String> availableMaterials;
  final String? activePriceId;
  final TextEditingController adjustmentValueC;
  final TextEditingController reasonC;
  final int deltaDirection;
  final double Function(double current) computeNewPrice;
  final ScrollController rowsScrollController;
  final VoidCallback onClose;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<int> onDirectionChanged;
  final VoidCallback onRefreshPreview;
  final VoidCallback? onSelectAllVisible;
  final VoidCallback? onClearSelection;
  final ValueChanged<String> onToggleRow;
  final ValueChanged<String> onActivateRow;
  final VoidCallback? onApply;

  const _MayoreoAdjustmentWorkspaceCard({
    required this.rows,
    required this.selectedRows,
    required this.selectedCompany,
    required this.selectedMaterial,
    required this.availableCompanies,
    required this.availableMaterials,
    required this.activePriceId,
    required this.adjustmentValueC,
    required this.reasonC,
    required this.deltaDirection,
    required this.computeNewPrice,
    required this.rowsScrollController,
    required this.onClose,
    required this.onCompanyChanged,
    required this.onMaterialChanged,
    required this.onDirectionChanged,
    required this.onRefreshPreview,
    required this.onSelectAllVisible,
    required this.onClearSelection,
    required this.onToggleRow,
    required this.onActivateRow,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuevo ajuste',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: mayoreoAreaTokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 12),
          const _AdjustmentSectionTitle('1. Empresa y material'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdjustmentFilterField(
                  label: 'Empresa',
                  value: selectedCompany,
                  items: availableCompanies,
                  onChanged: onCompanyChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdjustmentFilterField(
                  label: 'Material',
                  value: selectedMaterial,
                  items: availableMaterials,
                  onChanged: onMaterialChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _AdjustmentSectionTitle('2. Seleccion'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: onSelectAllVisible,
                icon: const Icon(Icons.select_all_rounded),
                label: const Text('Seleccionar visibles'),
              ),
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: onClearSelection,
                icon: const Icon(Icons.deselect_rounded),
                label: const Text('Limpiar'),
              ),
              _AdjustmentMiniPill(label: '${rows.length} visibles'),
              _AdjustmentMiniPill(
                label: '${selectedRows.length} seleccionados',
                highlighted: selectedRows.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.76),
              ),
            ),
            child: rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay precios de venta para ese criterio.'),
                    ),
                  )
                : ListView.separated(
                    controller: rowsScrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final selected = selectedRows.any(
                        (selectedRow) => selectedRow.id == row.id,
                      );
                      final nextPrice = selected
                          ? computeNewPrice(row.currentPrice)
                          : row.currentPrice;
                      return _MayoreoAdjustmentUniverseRow(
                        row: row,
                        active: activePriceId == row.id,
                        selected: selected,
                        currentPriceText: formatMoney(row.currentPrice),
                        nextPriceText: nextPrice < 0
                            ? 'INVALIDO'
                            : formatMoney(nextPrice),
                        onTap: () => onActivateRow(row.id),
                        onCheckboxChanged: (_) => onToggleRow(row.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          const _AdjustmentSectionTitle('3. Sube o baja'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdjustmentTag(
                  label: 'SUBIR',
                  selected: deltaDirection > 0,
                  onTap: () => onDirectionChanged(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdjustmentTag(
                  label: 'BAJAR',
                  selected: deltaDirection < 0,
                  onTap: () => onDirectionChanged(-1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: adjustmentValueC,
            onChanged: (_) => onRefreshPreview(),
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: true,
            ),
            decoration: _adjustmentFieldDecoration(
              context,
              hintText: 'Cantidad · Ej. 150.00',
              prefixIcon: Icon(
                deltaDirection > 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonC,
            onChanged: (_) => onRefreshPreview(),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final normalized = newValue.text
                    .toUpperCase()
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trimLeft();
                final offset = newValue.selection.baseOffset.clamp(
                  0,
                  normalized.length,
                );
                return TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: offset),
                );
              }),
            ],
            decoration: _adjustmentFieldDecoration(
              context,
              hintText: 'Referencia opcional',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          const _AdjustmentSectionTitle('4. Antes y despues'),
          const SizedBox(height: 12),
          _AdjustmentPreviewSurface(
            rows: rows,
            selectedRows: selectedRows,
            adjustmentValueText: adjustmentValueC.text,
            deltaDirection: deltaDirection,
            computeNewPrice: computeNewPrice,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedRows.isEmpty
                      ? 'Selecciona al menos un precio para aplicar el ajuste.'
                      : 'El ajuste absorbe al precio vigente actual y se convierte en la nueva base operativa.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kMayoreoMutedInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: onClose,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: contractPrimaryButtonStyle(context),
                onPressed: onApply,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(
                  selectedRows.isEmpty
                      ? 'Aplicar'
                      : 'Aplicar a ${selectedRows.length} precio(s)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _adjustmentFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  return contractGlassFieldDecoration(
    context,
    hintText: hintText,
    prefixIcon: prefixIcon,
  ).copyWith(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _AdjustmentSectionTitle extends StatelessWidget {
  final String label;

  const _AdjustmentSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: mayoreoAreaTokens.primaryStrong,
      ),
    );
  }
}

class _AdjustmentTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdjustmentTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.14)
              : mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.36)
                : mayoreoAreaTokens.border.withValues(alpha: 0.76),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: mayoreoAreaTokens.primaryStrong,
          ),
        ),
      ),
    );
  }
}

class _AdjustmentMiniPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _AdjustmentMiniPill({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final background = highlighted
        ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.12)
        : mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.74);
    final foreground = highlighted
        ? mayoreoAreaTokens.primaryStrong
        : mayoreoAreaTokens.badgeText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.84),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }
}

class _AdjustmentPreviewSurface extends StatelessWidget {
  final List<_MayoreoSalePriceRow> rows;
  final List<_MayoreoSalePriceRow> selectedRows;
  final String adjustmentValueText;
  final int deltaDirection;
  final double Function(double current) computeNewPrice;

  const _AdjustmentPreviewSurface({
    required this.rows,
    required this.selectedRows,
    required this.adjustmentValueText,
    required this.deltaDirection,
    required this.computeNewPrice,
  });

  @override
  Widget build(BuildContext context) {
    final sample = selectedRows.isNotEmpty ? selectedRows.first : null;
    final sampleCurrent = sample?.currentPrice;
    final sampleNext = sampleCurrent == null
        ? null
        : computeNewPrice(sampleCurrent);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.76),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdjustmentPreviewRow(
            label: 'Precios visibles / seleccionados',
            value: '${rows.length} / ${selectedRows.length}',
          ),
          const SizedBox(height: 10),
          _AdjustmentPreviewRow(
            label: 'Cambio aplicado',
            value:
                '${deltaDirection > 0 ? 'SUBE' : 'BAJA'}${adjustmentValueText.trim().isEmpty ? '' : ' · $adjustmentValueText'}',
          ),
          const SizedBox(height: 12),
          _AdjustmentPreviewRow(
            label: 'Precio actual',
            value: sampleCurrent == null
                ? 'Selecciona una fila'
                : formatMoney(sampleCurrent),
          ),
          const SizedBox(height: 10),
          _AdjustmentPreviewRow(
            label: 'Precio final',
            value: sampleNext == null
                ? 'Sin vista previa'
                : formatMoney(sampleNext),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _AdjustmentPreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AdjustmentPreviewRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mayoreoAreaTokens.badgeText,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 14,
            fontWeight: FontWeight.w900,
            color: emphasized
                ? mayoreoAreaTokens.primaryStrong
                : const Color(0xFF1F262B),
          ),
        ),
      ],
    );
  }
}

class _MayoreoPriceAdjustmentsBody extends StatelessWidget {
  final List<_MayoreoPriceHistoryRow> historyRows;
  final List<_MayoreoPriceHistoryRow> allHistoryRows;
  final String movementFilter;
  final String? companyFilter;
  final String? materialFilter;
  final List<String> availableCompanies;
  final List<String> availableMaterials;
  final ValueChanged<String> onMovementChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final VoidCallback onClearFilters;
  final Future<void> Function() onOpenAdjustmentDialog;
  final Future<void> Function() onExportPdf;

  const _MayoreoPriceAdjustmentsBody({
    required this.historyRows,
    required this.allHistoryRows,
    required this.movementFilter,
    required this.companyFilter,
    required this.materialFilter,
    required this.availableCompanies,
    required this.availableMaterials,
    required this.onMovementChanged,
    required this.onCompanyChanged,
    required this.onMaterialChanged,
    required this.onClearFilters,
    required this.onOpenAdjustmentDialog,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGlassToolbarPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: contractPrimaryButtonStyle(context),
                      onPressed: onOpenAdjustmentDialog,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Nuevo ajuste'),
                    ),
                    OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: onExportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Descargar PDF'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _MayoreoHistoryWorkspaceCard(
                  historyRows: historyRows,
                  allHistoryRows: allHistoryRows,
                  availableCompanies: availableCompanies,
                  availableMaterials: availableMaterials,
                  movementFilter: movementFilter,
                  companyFilter: companyFilter,
                  materialFilter: materialFilter,
                  onMovementChanged: onMovementChanged,
                  onCompanyChanged: onCompanyChanged,
                  onMaterialChanged: onMaterialChanged,
                  onClearFilters: onClearFilters,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoHistoryWorkspaceCard extends StatelessWidget {
  final List<_MayoreoPriceHistoryRow> historyRows;
  final List<_MayoreoPriceHistoryRow> allHistoryRows;
  final List<String> availableCompanies;
  final List<String> availableMaterials;
  final String movementFilter;
  final String? companyFilter;
  final String? materialFilter;
  final ValueChanged<String> onMovementChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final VoidCallback onClearFilters;

  const _MayoreoHistoryWorkspaceCard({
    required this.historyRows,
    required this.allHistoryRows,
    required this.availableCompanies,
    required this.availableMaterials,
    required this.movementFilter,
    required this.companyFilter,
    required this.materialFilter,
    required this.onMovementChanged,
    required this.onCompanyChanged,
    required this.onMaterialChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final filteredPairs = historyRows
        .map((row) => '${row.companyName}|${row.materialName}')
        .toSet();
    final summary = historyRows.isEmpty ? null : historyRows.first;
    final showSingleTrend = filteredPairs.length == 1 && summary != null;
    final clearVisible =
        companyFilter != null ||
        materialFilter != null ||
        movementFilter != 'todos';

    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movimientos recientes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: mayoreoAreaTokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa los filtros para revisar qué cambió y abre un ajuste nuevo solo cuando ya tengas claro el universo.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: mayoreoAreaTokens.badgeText.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 980) {
                return Row(
                  children: [
                    Expanded(
                      child: _AdjustmentFilterField(
                        label: 'Empresa',
                        value: companyFilter,
                        items: availableCompanies,
                        onChanged: onCompanyChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AdjustmentFilterField(
                        label: 'Material',
                        value: materialFilter,
                        items: availableMaterials,
                        onChanged: onMaterialChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HistoryMovementField(
                        value: movementFilter,
                        onChanged: onMovementChanged,
                      ),
                    ),
                    if (clearVisible) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: onClearFilters,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Limpiar filtros'),
                      ),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 220,
                    child: _AdjustmentFilterField(
                      label: 'Empresa',
                      value: companyFilter,
                      items: availableCompanies,
                      onChanged: onCompanyChanged,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _AdjustmentFilterField(
                      label: 'Material',
                      value: materialFilter,
                      items: availableMaterials,
                      onChanged: onMaterialChanged,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _HistoryMovementField(
                      value: movementFilter,
                      onChanged: onMovementChanged,
                    ),
                  ),
                  if (clearVisible)
                    OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: onClearFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Limpiar filtros'),
                    ),
                ],
              );
            },
          ),
          if (showSingleTrend) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: mayoreoAreaTokens.border.withValues(alpha: 0.74),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.companyName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.materialName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HistoryTrendStrip(
                    points: _buildHistoryTrendPoints(historyRows),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: mayoreoAreaTokens.border.withValues(alpha: 0.76),
                ),
              ),
              child: historyRows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay movimientos para ese filtro.'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: historyRows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _MayoreoHistoryRow(row: historyRows[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MayoreoHistoryRow extends StatelessWidget {
  final _MayoreoPriceHistoryRow row;

  const _MayoreoHistoryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.68),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 124,
            child: Text(
              _formatDateTime(row.createdAt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: mayoreoAreaTokens.badgeText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              row.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: mayoreoAreaTokens.primaryStrong,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              row.materialName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: mayoreoAreaTokens.badgeText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              formatMoney(row.previousPrice),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: mayoreoAreaTokens.badgeText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              formatMoney(row.newPrice),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: mayoreoAreaTokens.primaryStrong,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _AdjustmentMiniPill(
            label: row.movementLabel,
            highlighted:
                row.movementLabel == 'SUBE' || row.movementLabel == 'BAJA',
          ),
        ],
      ),
    );
  }
}

class _HistoryMovementField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _HistoryMovementField({required this.value, required this.onChanged});

  static const _items = <(String, String)>[
    ('todos', 'TODOS'),
    ('altas', 'ALTAS'),
    ('bajas', 'BAJAS'),
    ('sin_cambio', 'SIN CAMBIO'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLabel = _items
        .firstWhere((item) => item.$1 == value, orElse: () => _items.first)
        .$2;
    return _HistoryCompactPickerField(
      label: 'Movimiento',
      value: currentLabel,
      items: _items.map((item) => item.$2).toList(growable: false),
      onChanged: (label) {
        final mapped = _items.firstWhere(
          (item) => item.$2 == label,
          orElse: () => _items.first,
        );
        onChanged(mapped.$1);
      },
    );
  }
}

class _HistoryCompactPickerField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _HistoryCompactPickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_HistoryCompactPickerField> createState() =>
      _HistoryCompactPickerFieldState();
}

class _HistoryCompactPickerFieldState
    extends State<_HistoryCompactPickerField> {
  Future<void> _openPicker() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: mayoreoAreaTokens,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: ContractPopupSurface(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtro: ${widget.label.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = widget.items[index];
                        return _AdjustmentPickerOption(
                          label: item,
                          selected: widget.value == item,
                          onTap: () => Navigator.of(dialogContext).pop(item),
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
    );
    if (!mounted || selected == null || selected == widget.value) return;
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: mayoreoAreaTokens.badgeText,
              letterSpacing: 0.4,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openPicker,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.78),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: mayoreoAreaTokens.primaryStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: mayoreoAreaTokens.primaryStrong,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTrendPoint {
  final double price;
  final String label;

  const _HistoryTrendPoint({required this.price, required this.label});
}

List<_HistoryTrendPoint> _buildHistoryTrendPoints(
  List<_MayoreoPriceHistoryRow> rows,
) {
  if (rows.isEmpty) return const <_HistoryTrendPoint>[];
  final ordered = List<_MayoreoPriceHistoryRow>.from(rows)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final points = <_HistoryTrendPoint>[
    _HistoryTrendPoint(
      price: ordered.first.previousPrice,
      label: _trendLabel(ordered.first.createdAt),
    ),
  ];
  for (final row in ordered) {
    points.add(
      _HistoryTrendPoint(
        price: row.newPrice,
        label: _trendLabel(row.createdAt),
      ),
    );
  }
  return points;
}

String _trendLabel(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$dd/$mm\n$hh:$min';
}

class _HistoryTrendStrip extends StatelessWidget {
  final List<_HistoryTrendPoint> points;

  const _HistoryTrendStrip({required this.points});

  String _money(double value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    final prices = points.map((point) => point.price).toList(growable: false);
    final minValue = prices.reduce((a, b) => a < b ? a : b);
    final maxValue = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();
    final paddedMin = range < 0.12
        ? minValue - 0.08
        : minValue - (range * 0.18);
    final paddedMax = range < 0.12
        ? maxValue + 0.08
        : maxValue + (range * 0.18);
    final axisIndices = <int>{
      0,
      if (points.length > 2) (points.length / 2).floor(),
      points.length - 1,
    }.toList()..sort();
    return Container(
      height: 138,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.68)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolución reciente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Precio por fecha',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                final chartHeight = constraints.maxHeight - 28;

                double xFor(int index) {
                  if (points.length == 1) return chartWidth / 2;
                  return (chartWidth / (points.length - 1)) * index;
                }

                double yFor(double price) {
                  final normalized =
                      (price - paddedMin) /
                      ((paddedMax - paddedMin).abs() < 0.001
                          ? 1.0
                          : (paddedMax - paddedMin));
                  return chartHeight - (normalized * (chartHeight - 12)) - 6;
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: CustomPaint(
                          painter: _TrendLinePainter(
                            values: prices,
                            color: tokens.primaryStrong,
                            guideColor: tokens.border.withValues(alpha: 0.28),
                            minOverride: paddedMin,
                            maxOverride: paddedMax,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    ...List<Widget>.generate(points.length, (index) {
                      final point = points[index];
                      return Positioned(
                        left: xFor(index) - 16,
                        top: yFor(point.price) - 16,
                        child: Tooltip(
                          message:
                              '${point.label.replaceFirst('\n', ' ')} · ${_money(point.price)}',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.precise,
                            child: Container(
                              width: 32,
                              height: 32,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      );
                    }),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: List<Widget>.generate(points.length, (index) {
                          final showLabel = axisIndices.contains(index);
                          return Expanded(
                            child: Text(
                              showLabel ? points[index].label : '',
                              textAlign: index == 0
                                  ? TextAlign.left
                                  : index == points.length - 1
                                  ? TextAlign.right
                                  : TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.6,
                                fontWeight: FontWeight.w800,
                                color: tokens.badgeText.withValues(alpha: 0.82),
                                height: 1.15,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color guideColor;
  final double? minOverride;
  final double? maxOverride;

  const _TrendLinePainter({
    required this.values,
    required this.color,
    required this.guideColor,
    this.minOverride,
    this.maxOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = maxOverride ?? values.reduce((a, b) => a > b ? a : b);
    final minValue = minOverride ?? values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;
    final chartHeight = size.height - 8;
    final chartWidth = size.width;

    final guidePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), guidePaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? chartWidth / 2
          : (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final dy = chartHeight - (normalized * (chartHeight - 12)) - 6;
      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, chartHeight);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }
    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? chartWidth / 2
          : (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final dy = chartHeight - (normalized * (chartHeight - 12)) - 6;
      canvas.drawCircle(Offset(dx, dy), 4.2, pointPaint);
      canvas.drawCircle(
        Offset(dx, dy),
        7,
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.minOverride != minOverride ||
        oldDelegate.maxOverride != maxOverride;
  }
}

class _AdjustmentFilterField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _AdjustmentFilterField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_AdjustmentFilterField> createState() => _AdjustmentFilterFieldState();
}

class _AdjustmentFilterFieldState extends State<_AdjustmentFilterField> {
  Future<void> _openPicker() async {
    final searchC = TextEditingController();
    String query = '';
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: mayoreoAreaTokens,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              final filtered = widget.items
                  .where((item) => item.contains(query.toUpperCase()))
                  .toList(growable: false);
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    maxHeight: 460,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtro: ${widget.label.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: mayoreoAreaTokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchC,
                        decoration: _adjustmentFieldDecoration(
                          context,
                          hintText: 'Buscar',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: mayoreoAreaTokens.primaryStrong,
                        ),
                        onChanged: (value) => setLocalState(() {
                          query = value.trim().toUpperCase();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            if (index == 0) {
                              return _AdjustmentPickerOption(
                                label: 'TODOS',
                                selected: widget.value == null,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(null),
                              );
                            }
                            final item = filtered[index - 1];
                            return _AdjustmentPickerOption(
                              label: item,
                              selected: widget.value == item,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(item),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(dialogContext),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(dialogContext),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            child: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    searchC.dispose();
    if (!mounted) return;
    if (selected != widget.value) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: mayoreoAreaTokens.badgeText,
              letterSpacing: 0.4,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openPicker,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.78),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: mayoreoAreaTokens.primaryStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.value ?? 'TODOS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: widget.value == null
                          ? mayoreoAreaTokens.badgeText.withValues(alpha: 0.72)
                          : mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: mayoreoAreaTokens.primaryStrong,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdjustmentPickerOption extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdjustmentPickerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AdjustmentPickerOption> createState() =>
      _AdjustmentPickerOptionState();
}

class _AdjustmentPickerOptionState extends State<_AdjustmentPickerOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.12)
                  : mayoreoAreaTokens.surfaceTint.withValues(
                      alpha: _hovered ? 0.9 : 0.76,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.36)
                    : mayoreoAreaTokens.border.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: mayoreoAreaTokens.primaryStrong,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: mayoreoAreaTokens.primaryStrong,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoAdjustmentUniverseRow extends StatefulWidget {
  final _MayoreoSalePriceRow row;
  final bool active;
  final bool selected;
  final String currentPriceText;
  final String nextPriceText;
  final VoidCallback onTap;
  final ValueChanged<bool?> onCheckboxChanged;

  const _MayoreoAdjustmentUniverseRow({
    required this.row,
    required this.active,
    required this.selected,
    required this.currentPriceText,
    required this.nextPriceText,
    required this.onTap,
    required this.onCheckboxChanged,
  });

  @override
  State<_MayoreoAdjustmentUniverseRow> createState() =>
      _MayoreoAdjustmentUniverseRowState();
}

class _MayoreoAdjustmentUniverseRowState
    extends State<_MayoreoAdjustmentUniverseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasChange = widget.currentPriceText != widget.nextPriceText;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.active
              ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.14)
              : widget.selected
              ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.10)
              : mayoreoAreaTokens.surfaceTint.withValues(
                  alpha: _hovered ? 0.90 : 0.76,
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.active
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.52)
                : widget.selected
                ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.34)
                : mayoreoAreaTokens.border.withValues(
                    alpha: _hovered ? 0.90 : 0.70,
                  ),
            width: widget.active ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: mayoreoAreaTokens.primaryStrong.withValues(
                alpha: widget.active
                    ? 0.18
                    : widget.selected
                    ? 0.12
                    : (_hovered ? 0.08 : 0.04),
              ),
              blurRadius: widget.active
                  ? 24
                  : widget.selected
                  ? 20
                  : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => widget.onCheckboxChanged(!widget.selected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? mayoreoAreaTokens.primaryStrong.withValues(
                              alpha: 0.18,
                            )
                          : mayoreoAreaTokens.badgeBackground.withValues(
                              alpha: 0.92,
                            ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: widget.selected
                            ? mayoreoAreaTokens.primaryStrong.withValues(
                                alpha: 0.44,
                              )
                            : mayoreoAreaTokens.border.withValues(alpha: 0.78),
                        width: widget.selected ? 1.4 : 1,
                      ),
                    ),
                    child: Icon(
                      widget.selected
                          ? Icons.check_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 28,
                      color: widget.selected
                          ? mayoreoAreaTokens.primaryStrong
                          : mayoreoAreaTokens.primaryStrong.withValues(
                              alpha: 0.52,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.row.companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: mayoreoAreaTokens.primaryStrong,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.row.materialName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: mayoreoAreaTokens.badgeText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _AdjustmentMiniPill(
                            label: 'VENTA',
                            highlighted: widget.selected,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _AdjustmentPriceChip(
                                    label: 'Actual',
                                    value: widget.currentPriceText,
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: hasChange
                                        ? mayoreoAreaTokens.primaryStrong
                                        : mayoreoAreaTokens.badgeText
                                              .withValues(alpha: 0.6),
                                  ),
                                  _AdjustmentPriceChip(
                                    label: 'Final',
                                    value: widget.nextPriceText,
                                    highlighted: hasChange,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentPriceChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _AdjustmentPriceChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.34)
              : mayoreoAreaTokens.border.withValues(alpha: 0.76),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: mayoreoAreaTokens.badgeText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: highlighted
                  ? mayoreoAreaTokens.primaryStrong
                  : kMayoreoInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _MayoreoPriceHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MayoreoPriceHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_MayoreoPriceHeaderButton> createState() =>
      _MayoreoPriceHeaderButtonState();
}

class _MayoreoPriceHeaderButtonState extends State<_MayoreoPriceHeaderButton> {
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

class _MayoreoPriceSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _MayoreoPriceSidePanel({
    required this.canReturnToDirection,
    required this.onNavigate,
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
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _MayoreoPriceNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _MayoreoPriceSectionHeader(label: 'MENU'),
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
                    _MayoreoPriceNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Pedidos y cierre comercial',
                      onTapSync: () => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoPriceNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoPriceNavItem(
                      icon: Icons.picture_as_pdf_rounded,
                      title: 'Descargar PDF',
                      subtitle: 'Reporte agrupado por cliente',
                      onTapSync: () => onNavigate('Descargar PDF'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _MayoreoPriceSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _MayoreoPriceNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _MayoreoPriceNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Mayoreo',
                subtitle: 'Vista general del área',
                onTapSync: () => onNavigate('Dashboard Mayoreo'),
              ),
              const SizedBox(height: 8),
              const _MayoreoPriceNavItem(
                icon: Icons.auto_graph_rounded,
                title: 'Ajuste de precios',
                subtitle: 'Vista activa del módulo',
                accented: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoPriceSectionHeader extends StatelessWidget {
  final String label;

  const _MayoreoPriceSectionHeader({required this.label});

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
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _MayoreoPriceNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _MayoreoPriceNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTapSync,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented ? kMayoreoHeroGradient : kMayoreoPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: mayoreoAreaTokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primaryStrong,
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
                          color: accented ? Colors.white : tokens.primaryStrong,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accented
                                ? Colors.white.withValues(alpha: 0.92)
                                : tokens.badgeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.badgeText,
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

class _MayoreoSalePriceRow {
  final String id;
  final String companyName;
  final String materialName;
  final double currentPrice;
  final bool active;
  final String notes;
  final DateTime updatedAt;

  const _MayoreoSalePriceRow({
    required this.id,
    required this.companyName,
    required this.materialName,
    required this.currentPrice,
    required this.active,
    required this.notes,
    required this.updatedAt,
  });

  _MayoreoSalePriceRow copyWith({
    double? currentPrice,
    bool? active,
    String? notes,
    DateTime? updatedAt,
  }) {
    return _MayoreoSalePriceRow(
      id: id,
      companyName: companyName,
      materialName: materialName,
      currentPrice: currentPrice ?? this.currentPrice,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _MayoreoPriceHistoryRow {
  final String id;
  final String companyName;
  final String materialName;
  final double previousPrice;
  final double newPrice;
  final String reason;
  final DateTime createdAt;

  const _MayoreoPriceHistoryRow({
    required this.id,
    required this.companyName,
    required this.materialName,
    required this.previousPrice,
    required this.newPrice,
    required this.reason,
    required this.createdAt,
  });

  String get movementLabel {
    if (newPrice > previousPrice) return 'SUBE';
    if (newPrice < previousPrice) return 'BAJA';
    return 'IGUAL';
  }
}

List<_MayoreoSalePriceRow> _seedPriceRows() {
  final now = DateTime.now();
  return [
    _MayoreoSalePriceRow(
      id: 'price-1',
      companyName: 'ACEROS DEL BAJIO',
      materialName: 'VARILLA 3/8 GRADO 42',
      currentPrice: 19850,
      active: true,
      notes: 'LISTA PREFERENTE POR VOLUMEN',
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    _MayoreoSalePriceRow(
      id: 'price-2',
      companyName: 'CONSTRUCTORA NOVA',
      materialName: 'LAMINA LISA CAL 20',
      currentPrice: 842,
      active: true,
      notes: 'NEGOCIACION VIGENTE DE QUINCENA',
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    _MayoreoSalePriceRow(
      id: 'price-3',
      companyName: 'FERRETODO CENTRO',
      materialName: 'LAMINA LISA CAL 20',
      currentPrice: 624,
      active: true,
      notes: 'PROMOCION DE INTRODUCCION',
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    _MayoreoSalePriceRow(
      id: 'price-4',
      companyName: 'RECICLADOS PALMIRA',
      materialName: 'CH MIXTA',
      currentPrice: 4350,
      active: true,
      notes: 'PRECIO GUIA DE CHATARRA',
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    _MayoreoSalePriceRow(
      id: 'price-5',
      companyName: 'INDUSTRIAS DEL NORTE',
      materialName: 'COBRE',
      currentPrice: 118000,
      active: true,
      notes: 'AJUSTE SUJETO A MERCADO',
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
  ];
}

List<_MayoreoPriceHistoryRow> _seedHistoryRows() {
  final now = DateTime.now();
  return [
    _MayoreoPriceHistoryRow(
      id: 'hist-1',
      companyName: 'ACEROS DEL BAJIO',
      materialName: 'VARILLA 3/8 GRADO 42',
      previousPrice: 19400,
      newPrice: 19850,
      reason: 'ALZA COMERCIAL DE SEMANA',
      createdAt: now.subtract(const Duration(hours: 12)),
    ),
    _MayoreoPriceHistoryRow(
      id: 'hist-2',
      companyName: 'CONSTRUCTORA NOVA',
      materialName: 'LAMINA LISA CAL 20',
      previousPrice: 790,
      newPrice: 842,
      reason: 'AJUSTE POR NEGOCIACION DE QUINCENA',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    _MayoreoPriceHistoryRow(
      id: 'hist-3',
      companyName: 'RECICLADOS PALMIRA',
      materialName: 'CH MIXTA',
      previousPrice: 4200,
      newPrice: 4350,
      reason: 'ALZA DE REFERENCIA EN CHATARRA',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}

String _movementFilterLabel(String value) {
  switch (value) {
    case 'altas':
      return 'ALTAS';
    case 'bajas':
      return 'BAJAS';
    case 'sin_cambio':
      return 'SIN CAMBIO';
    default:
      return 'TODOS';
  }
}

String _sanitizePathSegment(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'SIN NOMBRE';
  return cleaned;
}

pw.Widget _pdfSummaryTile({
  required String label,
  required String value,
  required PdfColor accent,
  required PdfColor softAccent,
}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: pw.BoxDecoration(
        color: softAccent,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    ),
  );
}
