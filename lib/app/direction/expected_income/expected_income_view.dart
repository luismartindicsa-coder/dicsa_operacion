import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../mayoreo/mayoreo_expected_collections.dart';

import '../../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../../shared/archetypes/grid_editable/grid_scroll_visibility_coordinator.dart';
import '../../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../../shared/utils/number_formatters.dart';
import '../../shared/utils/file_download_save.dart';
import '../direction_shipments_store.dart';
import '../direction_theme.dart';
import '../operating_program/operating_program_models.dart';
import 'expected_income_engine.dart';
import 'expected_income_forms.dart';
import 'expected_income_models.dart';
import 'expected_income_pdf.dart';
import 'expected_income_repository.dart';
import 'palomar_coverage_view.dart';

/// Executive read-only report. Editing operational rows stays in Embarques;
/// configuration uses the shared Dirección modal/focus contract.
class ExpectedIncomeView extends StatefulWidget {
  final DirectionShipmentPlanningBundle bundle;
  final Future<void> Function(DateTime) onWeekChanged;
  final ExpectedIncomeRepository? repository;
  final bool active;
  final DateTime Function()? clock;
  final String? referenceError;
  const ExpectedIncomeView({
    super.key,
    required this.bundle,
    required this.onWeekChanged,
    this.repository,
    this.active = true,
    this.clock,
    this.referenceError,
  });
  @override
  State<ExpectedIncomeView> createState() => _ExpectedIncomeViewState();
}

class _ExpectedIncomeViewState extends State<ExpectedIncomeView> {
  late final _repository = widget.repository ?? ExpectedIncomeRepository();
  final _selection = GridSelectionController();
  final _navigation = GridNavigationController();
  final _visibility = GridScrollVisibilityCoordinator();
  ExpectedIncomeData? _data;
  DirectionShipmentPlanningBundle? _reference;
  Timer? _timer;
  bool _loading = false, _editing = false, _exporting = false;
  bool _exportFailed = false;
  String? _exportMessage;
  bool get _busy => _editing || _exporting || widget.referenceError != null;
  int _request = 0;
  String? _error;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant ExpectedIncomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.weekStartDate != widget.bundle.weekStartDate) {
      _data = null;
      _reference = null;
      _selection.clear();
      _request++;
      _loading = false;
      _exportMessage = null;
    }
    if (widget.active &&
        (!oldWidget.active || oldWidget.bundle != widget.bundle)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _selection.dispose();
    _navigation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _loading) return;
    final request = ++_request;
    final reference = widget.bundle;
    setState(() => _loading = true);
    try {
      final data = await _repository.load(reference, now: _now);
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _reference = reference;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = 'No se pudo actualizar Ingresos esperados. $e');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Future<void> Function() action) async {
    if (_busy) return;
    _request++; // An in-flight refresh must not replace the form's reference.
    setState(() {
      _editing = true;
      _loading = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar. $e');
    } finally {
      if (mounted) {
        setState(() => _editing = false);
        await _load();
      }
    }
  }

  Future<void> _exportPdf() async {
    final data = _data;
    final reference = _reference;
    if (_busy ||
        _loading ||
        _error != null ||
        data == null ||
        reference == null) {
      return;
    }
    final snapshot = ExpectedIncomePrintData(
      bundle: reference,
      data: data,
      generatedAt: _now,
    );
    setState(() {
      _exporting = true;
      _exportFailed = false;
      _exportMessage = 'Generando PDF…';
    });
    try {
      final bytes = await buildExpectedIncomePdf(
        snapshot,
        assetBundle: DefaultAssetBundle.of(context),
      );
      if (!mounted) return;
      setState(() => _exportMessage = 'Elige dónde guardar el PDF.');
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: snapshot.fileName,
        dialogTitle: 'Guardar ingreso proyectado por embarque semanal',
        throwOnPickerError: true,
      );
      if (!mounted) return;
      _showExportResult(
        path == null
            ? 'No se guardó el PDF: no se eligió un archivo de destino.'
            : 'PDF guardado en $path',
      );
    } catch (error) {
      if (mounted) {
        _showExportResult(
          'No se pudo generar o guardar el PDF. $error',
          failed: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
        if (widget.active && _reference != widget.bundle) unawaited(_load());
      }
    }
  }

  void _showExportResult(String message, {bool failed = false}) {
    setState(() {
      _exportMessage = message;
      _exportFailed = failed;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _materials() => _edit(() async {
    final rules = [..._data!.materials]
      ..sort(
        (a, b) => incomeMaterialName(
          a.material,
        ).compareTo(incomeMaterialName(b.material)),
      );
    final material = await showSearchablePickerDialog<String>(
      context,
      title: 'Peso y precio por material',
      options: [
        for (final rule in rules)
          SearchablePickerOption(
            value: rule.material,
            label: incomeMaterialName(rule.material),
          ),
      ],
    );
    if (material != null && mounted) {
      await editIncomeMaterial(
        context,
        rules.firstWhere((r) => r.material == material),
        _repository,
      );
    }
  });
  Future<void> _clients() => _edit(() async {
    final names = <String>{
      ..._data!.clients.map((c) => c.name),
      ..._data!.catalogClients
          .where((c) => c['is_active'] == true)
          .map((c) => '${c['name']}'),
      ...widget.bundle.shipments.map((s) => s.clientName),
    }.toList()..sort();
    final name = await showSearchablePickerDialog<String>(
      context,
      title: 'Condiciones comerciales por cliente',
      options: [
        for (final name in names)
          SearchablePickerOption(value: name, label: name),
      ],
    );
    if (name != null && mounted) {
      await editIncomeClient(context, name, _data!, _repository);
    }
  });
  Future<void> _distribute(List<ExpectedIncomeRow> rows) => _edit(() async {
    final choices = rows.where((r) => r.canAllocate).toList()
      ..sort((a, b) {
        final date = b.shipment.shipDate.compareTo(a.shipment.shipDate);
        return date != 0
            ? date
            : a.shipment.clientName.compareTo(b.shipment.clientName);
      });
    if (choices.isEmpty) return;
    final id = choices.length == 1
        ? choices.single.shipment.id
        : await showSearchablePickerDialog<String>(
            context,
            title: 'Distribuir ingresos mixtos',
            options: [
              for (final r in choices)
                SearchablePickerOption(
                  value: r.shipment.id,
                  label:
                      '${programDate(r.shipment.shipDate)} · ${r.shipment.clientName} · ${incomeMaterialName(r.shipment.materialCode)} · ${_money(r.pendingCents)}${r.allocationApplied ? ' · Distribuido' : ' · Por distribuir'}',
                ),
            ],
          );
    if (id == null || !mounted) return;
    final row = choices.firstWhere((r) => r.shipment.id == id);
    await showIncomeForm(
      context,
      title: 'Distribuir ingreso mixto',
      description:
          '${row.shipment.clientName} · ${programDate(row.shipment.shipDate)}\n'
          'Por distribuir: ${_money(row.pendingCents)}. Efectivo y Fiscal deben sumar este importe pendiente de cobro.'
          '${row.allocationStale ? '\nEl importe o la venta cambió. Confirma una nueva distribución.' : ''}',
      fields: [
        IncomeFormField(
          'allocationCash',
          'Efectivo',
          row.allocationApplied
              ? (row.allocation!.cashCents / 100).toStringAsFixed(2)
              : null,
          numeric: true,
          max: row.pendingCents / 100,
        ),
        IncomeFormField(
          'allocationFiscal',
          'Fiscal',
          row.allocationApplied
              ? (row.allocation!.fiscalCents / 100).toStringAsFixed(2)
              : null,
          numeric: true,
          max: row.pendingCents / 100,
        ),
      ],
      onSave: (values) async {
        int cents(String key) {
          final amount = (values[key] as num).toDouble();
          final value = incomeCents(amount);
          if ((amount * 100 - value).abs() > 0.00001) {
            throw ArgumentError('Captura importes con máximo dos decimales.');
          }
          return value;
        }

        await _repository.saveAllocation(
          row.distribute(
            cashCents: cents('allocationCash'),
            fiscalCents: cents('allocationFiscal'),
          ),
        );
      },
    );
  });

  Future<void> _link(ExpectedIncomeRow row) => _edit(() async {
    final data = _data!;
    final used = {
      ...data.externallyLinkedSales,
      for (final e in data.links.entries)
        if (e.key != row.shipment.id) e.value,
    };
    final sales =
        data.sales
            .where(
              (s) => !used.contains(s.id) && data.saleMatches(row.shipment, s),
            )
            .toList()
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            return date != 0 ? date : a.ticket.compareTo(b.ticket);
          });
    final result = await showSearchablePickerDialog<String>(
      context,
      title: 'Vincular venta · ${row.shipment.clientName}',
      options: [
        if (data.links.containsKey(row.shipment.id))
          const SearchablePickerOption(
            value: '',
            label: 'Quitar vínculo guardado',
          ),
        for (final sale in sales)
          SearchablePickerOption(
            value: sale.id,
            label:
                '${programDate(sale.date)} · ${sale.ticket} · ${sale.client} · ${sale.weight ?? '—'} kg',
          ),
      ],
      initialValue: data.links[row.shipment.id],
    );
    if (result != null) {
      await _repository.linkSale(
        row.shipment.id,
        result.isEmpty ? null : result,
      );
    }
  });
  Future<void> _adjustment() => _edit(() async {
    final week = widget.bundle.weekStartDate;
    await showIncomeForm(
      context,
      title: 'Compensación prevista · El Palomar',
      description:
          'Solo proyección. Al registrar este movimiento en la cuenta real, retira la previsión para no duplicarlo.',
      fields: [
        IncomeFormField(
          'date',
          'Fecha prevista',
          programDate(week.add(const Duration(days: 4))),
          options: {
            for (var d = 0; d < 7; d++)
              programDate(week.add(Duration(days: d))): programDate(
                week.add(Duration(days: d)),
              ),
          },
        ),
        const IncomeFormField(
          'concept',
          'Concepto',
          'ABONO',
          options: {
            'ABONO': 'Abono',
            'PESADO': 'Pesado',
            'RETORNO': 'Retorno',
            'MIXTO': 'Mixto',
            'REBABA': 'Rebaba',
            'OTRO': 'Otro',
          },
        ),
        const IncomeFormField(
          'effect',
          'Efecto',
          '-1',
          options: {
            '-1': 'Reduce saldo por cubrir',
            '1': 'Aumenta saldo por cubrir',
          },
        ),
        const IncomeFormField(
          'amount',
          'Importe (MXN)',
          null,
          numeric: true,
          min: 0.01,
        ),
        const IncomeFormField('notes', 'Referencia', '', optional: true),
      ],
      onSave: (v) => _repository.saveAdjustment({
        'id': const Uuid().v4(),
        'expected_date': v['date'],
        'concept': v['concept'],
        'effect': int.parse(v['effect'] as String),
        'amount': v['amount'],
        'notes': v['notes'],
      }),
    );
  });
  Future<void> _removeAdjustment(
    PalomarIncomeMovement movement,
  ) => _edit(() async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Retirar previsión',
      content:
          'Retirar ${movement.concept} por ${_money(movement.signedCents)} de la proyección. La cuenta real se conserva.',
      confirmText: 'Retirar',
      tokens: directionAreaTokens,
    );
    if (confirmed == true) await _repository.deleteAdjustment(movement.id);
  });

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: kDirectionDanger))
            : const CircularProgressIndicator(),
      );
    }
    final data = _data!;
    final projection = projectExpectedIncome(
      bundle: _reference ?? widget.bundle,
      data: data,
      now: _now,
    );
    final week = widget.bundle.weekStartDate;
    final rows = [...projection.rows]
      ..sort((a, b) {
        final date = b.shipment.shipDate.compareTo(a.shipment.shipDate);
        return date != 0 ? date : a.shipment.id.compareTo(b.shipment.id);
      });
    _navigation.configure(
      insertColumnCount: 0,
      gridColumnCount: 1,
      rowCount: rows.length,
    );
    return incomeThemed(
      context,
      GridKeyboardShell(
        navigationController: _navigation,
        onEscape: () => setState(_selection.clear),
        onConfirm: () {
          final index = _navigation.active.rowIndex;
          if (index >= 0 && index < rows.length) unawaited(_link(rows[index]));
        },
        onNavigated: (position) {
          if (position.rowIndex < 0 || position.rowIndex >= rows.length) return;
          setState(
            () => _selection.selectSingle(
              rows[position.rowIndex].shipment.id,
              rowIndex: position.rowIndex,
            ),
          );
          _visibility.ensureGridRowVisible(position.rowIndex);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContractGlassCard(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'INGRESOS ESPERADOS',
                      style: TextStyle(
                        color: kDirectionSurfaceText,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Semana anterior',
                      onPressed: _busy
                          ? null
                          : () => widget.onWeekChanged(
                              week.subtract(const Duration(days: 7)),
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${programDate(week)} – ${programDate(week.add(const Duration(days: 6)))}',
                      style: const TextStyle(color: kDirectionSurfaceText),
                    ),
                    IconButton(
                      tooltip: 'Semana siguiente',
                      onPressed: _busy
                          ? null
                          : () => widget.onWeekChanged(
                              week.add(const Duration(days: 7)),
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _materials,
                      icon: const Icon(Icons.scale_outlined),
                      label: const Text('Pesos y precios'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _clients,
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Condiciones comerciales'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('export-expected-income'),
                      onPressed: _busy || _loading || _error != null
                          ? null
                          : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _exporting ? 'Generando PDF…' : 'PDF de ingresos',
                      ),
                    ),
                    if (rows.any((r) => r.canAllocate))
                      OutlinedButton.icon(
                        onPressed: _busy || _loading || _error != null
                            ? null
                            : () => _distribute(rows),
                        icon: const Icon(Icons.call_split),
                        label: const Text('Distribuir ingresos mixtos'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_exportMessage != null)
                _text(_exportMessage!, warning: _exportFailed),
              _text(
                'Flujo esperado en MXN: cobros de embarques y Ventas Mayoreo + disposición posible de El Palomar en la semana consultada.',
              ),
              if (_error != null)
                _text(
                  '$_error Se conserva la última lectura; los importes pueden estar desactualizados.',
                  warning: true,
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final bucket in [
                      ('Esta semana', projection.current),
                      ('Próxima semana', projection.next),
                      ('Posterior', projection.later),
                    ])
                      SizedBox(
                        width: constraints.maxWidth >= 900
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth,
                        child: _bucket(
                          bucket.$1,
                          bucket.$2,
                          palomar: identical(bucket.$2, projection.current)
                              ? projection.palomar
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _panel(
                'Origen y certeza del ingreso',
                Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _metric('Valor de los embarques', projection.generated),
                    _metric('Por embarcar', projection.projected),
                    _metric('Embarcado / por cobrar', projection.committed),
                    _metric('Cobrado de estos embarques', projection.collected),
                    if (projection.palomar.availableDraw > 0)
                      _metric(
                        'Financiamiento · El Palomar',
                        projection.palomar.availableDraw,
                      ),
                    if (projection.undated.total > 0)
                      _metric(
                        'Sin fecha o clasificación',
                        projection.undated.total,
                      ),
                    if (projection.overdue.total > 0)
                      _metric(
                        'Fecha anterior a esta semana',
                        projection.overdue.total,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _panel(
                'Calendario del flujo esperado',
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    for (var d = 0; d < 7; d++)
                      _metric(
                        '${const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][d]} ${week.add(Duration(days: d)).day}',
                        projection
                                .timeline[incomeDay(
                                  week.add(Duration(days: d)),
                                )]
                                ?.total ??
                            0,
                      ),
                    _metric('Próxima semana', projection.next.total),
                    if (projection.palomar.undatedDraw > 0)
                      _metric(
                        'Sin fecha · El Palomar',
                        projection.palomar.undatedDraw,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _panel(
                'Embarques que generan el flujo',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _text(
                      'Vincula una venta para consultar sus datos reales y cobros. Edita fechas y cantidades en Embarques.',
                    ),
                    const SizedBox(height: 10),
                    if (rows.isEmpty)
                      _text(
                        'No hay embarques de pacas de cartón guardados para esta semana.',
                      ),
                    if (rows.isNotEmpty) _table(rows),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _panel(
                'Disponibilidad de material',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(data.productionSource),
                    const SizedBox(height: 8),
                    for (final material in programMaterials)
                      _availability(material, projection, data),
                    _text(
                      'El turno noche queda disponible al día siguiente. La producción pendiente no genera ingreso por sí sola.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _panel(
                'Concentración del flujo esperado',
                Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _groups('Por cliente / fuente', projection.byClient),
                    _groups('Por material · ventas', projection.byMaterial),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _collections(projection.collections),
              const SizedBox(height: 12),
              _palomar(projection.palomar, data),
              const SizedBox(height: 12),
              _panel(
                'Riesgos para el ingreso',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final warning in projection.warnings)
                      _text(warning, warning: true),
                    for (final collection in projection.collections.where(
                      (c) => c.dueDate.isBefore(incomeDay(_now)),
                    ))
                      _text(
                        '${collection.client} · ${collection.document}: cobranza vencida desde ${programDate(collection.dueDate)} por ${_money(collection.pendingCents)}.',
                        warning: true,
                      ),
                    for (final row in rows.where((r) => r.risks.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _text(
                          '${programDate(row.shipment.shipDate)} · ${row.shipment.clientName} · ${incomeMaterialName(row.shipment.materialCode)}: ${row.risks.join(' ')}',
                          warning: row.missingBales > 0,
                        ),
                      ),
                    if (projection.palomar.toCover > 0)
                      _text(
                        'El Palomar: faltan ${_money(projection.palomar.toCover)} para cubrir la cuenta.',
                        warning: true,
                      ),
                    if (projection.warnings.isEmpty &&
                        rows.every((r) => r.risks.isEmpty) &&
                        projection.collections.every(
                          (c) => !c.dueDate.isBefore(incomeDay(_now)),
                        ) &&
                        projection.palomar.toCover == 0)
                      _text('Sin riesgos detectados en los datos consultados.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _table(List<ExpectedIncomeRow> rows) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(1260, constraints.maxWidth),
        child: Column(
          children: [
            _tableRow(const [
              'Cliente',
              'Embarque',
              'Material',
              'Pacas',
              r'Kg / $ por kg',
              'Valor',
              'Pago',
              'Cobro previsto',
              'Estado',
              'Venta',
            ]),
            const Divider(),
            for (var i = 0; i < rows.length; i++)
              _shipmentRow(rows[i], i, rows),
          ],
        ),
      ),
    ),
  );
  Widget _shipmentRow(
    ExpectedIncomeRow row,
    int index,
    List<ExpectedIncomeRow> rows,
  ) => Card(
    key: _visibility.keyForCell(
      zone: GridNavigationZone.grid,
      rowIndex: index,
      columnIndex: 0,
    ),
    margin: const EdgeInsets.only(bottom: 5),
    color: _selection.isSelected(row.shipment.id)
        ? kDirectionInteractiveSelected
        : directionAreaTokens.glassSurface,
    child: InkWell(
      onTap: () => setState(() {
        _selection.handlePointerSelection(
          id: row.shipment.id,
          rowIndex: index,
          resolveRangeIds: (a, b) =>
              rows.getRange(a, b + 1).map((r) => r.shipment.id),
        );
        _navigation.focusGridCell(rowIndex: index, columnIndex: 0);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: _tableRow(
          [
            row.shipment.clientName,
            programDate(row.shipment.shipDate),
            incomeMaterialName(row.shipment.materialCode),
            '${row.shipment.plannedQuantity}',
            '${row.kilograms == null ? '—' : formatDecimal(row.kilograms!, decimals: 0)} / ${row.price == null ? '—' : formatMoney(row.price!)}',
            row.valueCents == null ? 'Sin precio' : _money(row.valueCents!),
            row.paymentType ?? 'Sin definir',
            row.revolving
                ? 'Cuenta revolvente'
                : row.collectionDate == null
                ? 'Sin fecha'
                : programDate(row.collectionDate!),
            row.state.label,
            '',
          ],
          payment: row.canAllocate
              ? TextButton(
                  key: ValueKey('distribute-income-${row.shipment.id}'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                  ),
                  onPressed: _busy || _loading || _error != null
                      ? null
                      : () => _distribute([row]),
                  child: Text(
                    row.allocationApplied
                        ? 'Efectivo ${_money(row.allocation!.cashCents)}\nFiscal ${_money(row.allocation!.fiscalCents)}'
                        : 'Mixto · ${row.allocationStale ? 'revisar reparto' : 'por distribuir'}',
                  ),
                )
              : null,
          action: IconButton(
            tooltip: row.sale == null
                ? 'Vincular venta real'
                : 'Venta ${row.sale!.ticket} · revisar vínculo',
            onPressed: _busy ? null : () => _link(row),
            icon: Icon(row.sale == null ? Icons.link : Icons.link_rounded),
          ),
        ),
      ),
    ),
  );
  Widget _tableRow(List<String> values, {Widget? action, Widget? payment}) {
    const widths = <double>[185, 100, 90, 55, 145, 110, 90, 120, 160, 55];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ContractGridScaledRow(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < values.length; i++)
              SizedBox(
                width: widths[i],
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: i == values.length - 1 && action != null
                      ? action
                      : i == 6 && payment != null
                      ? payment
                      : Text(
                          values[i],
                          style: const TextStyle(
                            color: kDirectionSurfaceText,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _availability(
    String material,
    ExpectedIncomeProjection p,
    ExpectedIncomeData data,
  ) {
    final stock =
        (_reference ?? widget.bundle)
            .suggestionReport
            ?.currentFloorByMaterial[material] ??
        (_reference ?? widget.bundle).floorCountByMaterial[material] ??
        0;
    final production = data.supplies
        .where(
          (s) =>
              s.material == material &&
              s.availableDate.isBefore(
                widget.bundle.weekStartDate.add(const Duration(days: 7)),
              ),
        )
        .fold(0, (v, s) => v + s.bales);
    final demand = p.rows
        .where(
          (r) =>
              r.shipment.materialCode == material &&
              (r.state == IncomeState.projected ||
                  r.state == IncomeState.ready),
        )
        .fold(0, (v, r) => v + r.shipment.plannedQuantity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _text(
        '${incomeMaterialName(material)}: $stock en piso + $production por producir − $demand por embarcar = ${stock + production - demand} pacas al cierre.',
        warning: stock + production < demand,
      ),
    );
  }

  Widget _palomar(PalomarIncomeProjection p, ExpectedIncomeData data) => _panel(
    'El Palomar · cuenta revolvente',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _edit(() async {
                      await editPalomarConfig(
                        context,
                        data.palomarConfig,
                        _repository,
                      );
                    }),
              child: const Text('Configurar disposición'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _edit(() async {
                      await editPalomarSchedule(
                        context,
                        data.palomarSchedule ??
                            PalomarReceiptSchedule(
                              week: widget.bundle.weekStartDate,
                            ),
                        _repository,
                      );
                    }),
              child: const Text('Fecha de recepción'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _adjustment,
              child: const Text('Compensación prevista'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _metric('Saldo inicial', p.opening),
            _metric('Cargos de la semana', p.charges),
            _metric('Remisiones / abonos', p.credits),
            _metric('Saldo proyectado', p.closing),
            _metric('Por cubrir', p.toCover),
            _metric('Disposición posible', p.availableDraw),
            _metric('Efectivo posible', p.cash),
            _metric('Fiscal posible', p.fiscal),
          ],
        ),
        const SizedBox(height: 12),
        _text(
          !p.complete
              ? 'Falta valuar un embarque; disposición pendiente de calcular.'
              : !p.configured
              ? 'Configura el límite vigente y el monto a disponer.'
              : p.availableDraw > 0
              ? 'Cuenta lista para disposición si se cumplen las remisiones y compensaciones previstas.'
              : 'Sin disposición disponible con las condiciones actuales.',
          warning: !p.configured || !p.complete,
        ),
        _text(
          'La disposición posible se incluye una sola vez en Esta semana como financiamiento, con su reparto efectivo/fiscal. Las remisiones ya aplicadas no se vuelven a descontar.',
        ),
        for (final type in ['EFECTIVO', 'FISCAL'])
          _text(
            'Recepción $type: ${p.dateFor(type) == null ? 'Sin fecha' : programDate(p.dateFor(type)!)}',
          ),
        if ([
          p.cashDate,
          p.fiscalDate,
        ].any((date) => date != null && date.isBefore(incomeDay(_now))))
          _text(
            'Hay una fecha de recepción anterior a hoy. Si el dinero sigue pendiente, actualiza la fecha; si ya lo recibiste, considéralo en el saldo inicial disponible.',
            warning: true,
          ),
        for (final movement in data.palomarMovements.where((m) => m.projected))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: _text(
              '${programDate(movement.date)} · ${movement.concept} · ${_money(movement.signedCents)}',
            ),
            trailing: IconButton(
              tooltip: 'Retirar previsión',
              onPressed: () => _removeAdjustment(movement),
              icon: const Icon(Icons.close),
            ),
          ),
        PalomarCoverageView(
          data: data,
          bundle: _reference ?? widget.bundle,
          now: _now,
        ),
      ],
    ),
  );
  Widget _collections(List<MayoreoExpectedCollection> source) {
    final rows = [...source]
      ..sort((a, b) {
        final date = b.dueDate.compareTo(a.dueDate);
        return date != 0 ? date : a.document.compareTo(b.document);
      });
    final week = widget.bundle.weekStartDate;
    final dueThisWeek = rows
        .where(
          (c) =>
              !c.dueDate.isBefore(week) &&
              c.dueDate.isBefore(week.add(const Duration(days: 7))),
        )
        .fold(0, (sum, c) => sum + c.pendingCents);
    Widget row(List<String> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ContractGridScaledRow(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cells.length; i++)
              SizedBox(
                width: const <double>[210, 130, 130, 160, 130, 150][i],
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _text(cells[i]),
                ),
              ),
          ],
        ),
      ),
    );
    return _panel(
      'Cobranza de Ventas Mayoreo',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text(
            'Adicional por cobrar esta semana: ${_money(dueThisWeek)} · Fiscal. Incluye ventas de semanas anteriores. Las cuentas vinculadas a los embarques de arriba ya están contempladas allí.',
          ),
          if (rows.isEmpty) _text('Sin cobranza adicional programada.'),
          if (rows.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(1000, constraints.maxWidth),
                  child: Column(
                    children: [
                      row(const [
                        'Cliente',
                        'Venta original',
                        'Documento',
                        'Material',
                        'Cobro previsto',
                        'Saldo por cobrar',
                      ]),
                      SizedBox(
                        height: math.min(360, rows.length * 66.0),
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final c = rows[i];
                            return row([
                              c.client,
                              programDate(c.saleDate),
                              c.document.isEmpty ? 'Sin número' : c.document,
                              c.material,
                              programDate(c.dueDate),
                              _money(c.pendingCents),
                            ]);
                          },
                        ),
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

  Widget _groups(String title, Map<String, int> groups) {
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(title),
        for (final entry in entries)
          _text('${entry.key}: ${_money(entry.value)}'),
      ],
    );
  }

  Widget _bucket(
    String label,
    IncomeTotals total, {
    PalomarIncomeProjection? palomar,
  }) => KeyedSubtree(
    key: ValueKey('income-bucket-$label'),
    child: _panel(
      label,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _money(total.total),
            style: const TextStyle(
              color: kDirectionIvory,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final type in ['EFECTIVO', 'FISCAL', 'MIXTO'])
            _text(
              '${type == 'MIXTO' ? 'Por distribuir' : type}: ${_money(total.byType[type] ?? 0)}',
            ),
          if (palomar != null) ...[
            const Divider(),
            _text('Cobros por ventas: ${_money(total.salesTotal)}'),
            _text('Disposición El Palomar: ${_money(total.financingTotal)}'),
            if (palomar.availableDraw > 0)
              _text(
                'Recepción según las fechas de El Palomar; sujeta a cumplir las condiciones de la cuenta.',
              )
            else if (!palomar.configured)
              _text('El Palomar: falta configurar límite y monto.')
            else if (!palomar.complete)
              _text('El Palomar: falta valuar embarques.', warning: true)
            else if (palomar.toCover > 0)
              _text(
                'El Palomar: faltan ${_money(palomar.toCover)} por cubrir.',
                warning: true,
              )
            else
              _text(
                'El Palomar: sin disposición disponible con los límites configurados.',
              ),
          ],
        ],
      ),
    ),
  );
  Widget _metric(String label, int cents) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _text(label),
      Text(
        _money(cents),
        style: const TextStyle(
          color: kDirectionSurfaceText,
          fontWeight: FontWeight.w800,
          fontSize: 19,
        ),
      ),
    ],
  );
  Widget _panel(String title, Widget child) => ContractGlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
  Widget _text(String text, {bool warning = false}) => Text(
    text,
    style: TextStyle(color: warning ? kDirectionWarning : kDirectionMutedText),
  );
  String _money(int cents) => formatMoney(cents / 100);
}
