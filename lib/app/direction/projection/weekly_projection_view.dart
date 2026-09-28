import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../management_reports/finance_weekly_budget_analysis.dart';
import '../../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/utils/number_formatters.dart';
import '../../shared/utils/file_download_save.dart';
import '../direction_shipments_store.dart';
import '../direction_theme.dart';
import '../expected_income/expected_income_engine.dart';
import '../expected_income/expected_income_forms.dart';
import '../expected_income/expected_income_models.dart';
import '../expected_income/expected_income_repository.dart';
import '../operating_program/operating_program_models.dart';
import 'weekly_projection_models.dart';
import 'weekly_projection_payment_catalog.dart';
import 'weekly_expenses_pdf.dart';
import 'weekly_projection_pdf.dart';
import 'weekly_projection_repository.dart';
import 'menudeo_expense_projection.dart';

/// Hybrid report with an auxiliary payment editor: Dirección shell and income
/// report cards; shared modal/picker owns focus, Enter/Esc and deferred refresh.
/// Operational invoices and executed payments stay in Finanzas.
class WeeklyProjectionView extends StatefulWidget {
  final DirectionShipmentPlanningBundle bundle;
  final Future<void> Function(DateTime) onWeekChanged;
  final bool active, flow;
  final WeeklyProjectionRepository? repository;
  final ExpectedIncomeRepository? incomeRepository;
  final DateTime Function()? clock;
  final String? referenceError;
  const WeeklyProjectionView({
    super.key,
    required this.bundle,
    required this.onWeekChanged,
    required this.active,
    required this.flow,
    this.repository,
    this.incomeRepository,
    this.clock,
    this.referenceError,
  });
  @override
  State<WeeklyProjectionView> createState() => _WeeklyProjectionViewState();
}

class _WeeklyProjectionViewState extends State<WeeklyProjectionView> {
  late final _repository = widget.repository ?? WeeklyProjectionRepository();
  late final _incomeRepository =
      widget.incomeRepository ?? ExpectedIncomeRepository();
  WeeklyExpensePlan? _saved;
  FinanceWeeklyBudgetAnalysis? _analysis;
  ExpectedIncomeProjection? _income;
  MenudeoExpenseHistory? _menudeoHistory;
  MenudeoExpenseEstimate? get _menudeo =>
      _saved == null || _menudeoHistory == null
      ? null
      : MenudeoExpenseEstimate(
          week: widget.bundle.weekStartDate,
          now: _readAt ?? _now,
          history: _menudeoHistory!,
          settings: _saved!.menudeo,
        );
  bool _loading = false, _editing = false, _exporting = false;
  String? _error, _notice;
  int _request = 0;
  bool _onlyIncluded = true;
  String _search = '';
  Timer? _timer;
  bool _pendingReload = false;
  DateTime? _readAt;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  bool get _busy => _editing || _exporting || widget.referenceError != null;
  List<ProjectedPayment> get _proposal =>
      _analysis == null ? [] : paymentProposal(_analysis!);
  ProjectionPaymentCatalog? get _catalog =>
      _analysis == null ? null : ProjectionPaymentCatalog(_analysis!);
  WeeklyExpensePlan? get _effective => _saved?.copyWith(
    payments: reconcilePayments(
      _saved!.payments,
      _catalog?.byId.values.toList() ?? [],
    ),
    menudeoPayments: _menudeo?.payments ?? [],
    menudeoWarnings: _menudeo?.warnings ?? [],
  );
  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant WeeklyProjectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.weekStartDate != widget.bundle.weekStartDate) {
      _request++;
      _loading = false;
      _saved = null;
      _analysis = null;
      _income = null;
      _menudeoHistory = null;
      _notice = null;
    }
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.flow != widget.flow ||
            oldWidget.bundle != widget.bundle)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _loading) {
      _pendingReload = true;
      return;
    }
    _pendingReload = false;
    final request = ++_request;
    final bundle = widget.bundle;
    final now = _now;
    final readIncome = widget.flow;
    setState(() => _loading = true);
    try {
      final values = await Future.wait<Object>([
        _repository.load(bundle.weekStartDate),
        _repository.proposal(bundle.weekStartDate, now),
        _repository.menudeoHistory(bundle.weekStartDate, now),
        if (readIncome) _incomeRepository.load(bundle, now: now),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _saved = values[0] as WeeklyExpensePlan;
        _analysis = values[1] as FinanceWeeklyBudgetAnalysis;
        _menudeoHistory = values[2] as MenudeoExpenseHistory;
        if (readIncome) {
          _income = projectExpectedIncome(
            bundle: bundle,
            data: values[3] as ExpectedIncomeData,
            now: now,
          );
        }
        _readAt = now;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = 'No se pudo actualizar la proyección. $e');
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
        if (_pendingReload && widget.active && !_busy) unawaited(_load());
      }
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy || _loading || _error != null || _effective == null) return;
    _request++;
    setState(() {
      _editing = true;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _notice = 'No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _editing = false);
        await _load();
      }
    }
  }

  Future<void> _save(WeeklyExpensePlan plan) async {
    if (widget.referenceError != null) {
      throw StateError('La referencia de la semana no está actualizada.');
    }
    final saved = await _repository.save(plan);
    if (mounted) {
      setState(() {
        _saved = saved;
        _notice = 'Proyección guardada · versión ${saved.revision}';
      });
    }
  }

  Future<void> _generate({bool resetFinance = false}) => _mutate(() async {
    final plan = _effective!;
    final analysis = await _repository.proposal(plan.week, _now);
    final current = paymentProposal(analysis);
    if (!mounted || widget.bundle.weekStartDate != plan.week) return;
    if (resetFinance) {
      final recommended = current.where((r) => r.included && !r.removed);
      final confirmed = await showContractConfirmationDialog(
        context,
        title: 'Restablecer propuesta de Finanzas',
        content:
            'Semana del ${programDate(plan.week)}\n'
            'Propuesta actual de Finanzas: ${recommended.length} pagos incluidos '
            'por ${_money(recommended.fold<int>(0, (s, r) => s + r.total))}.\n\n'
            'Se reemplazarán los importes, fechas, clasificaciones, notas, '
            'exclusiones y borrados de los pagos vinculados a Finanzas por '
            'la selección actual de Generar viernes. Los pagos recomendados '
            'volverán a aparecer incluidos.\n\n'
            'Se conservan tus egresos manuales, saldos iniciales y ajustes '
            'de Menudeo. Solo cambia esta semana; no se ejecutan pagos.',
        confirmText: 'Restablecer propuesta',
      );
      if (confirmed != true ||
          !mounted ||
          widget.bundle.weekStartDate != plan.week) {
        return;
      }
    }
    final payments = resetFinance
        ? resetFinanceProposal(plan.payments, current)
        : incorporateFinanceProposal(plan.payments, current);
    await _save(plan.copyWith(generated: true, payments: payments));
    if (!mounted) return;
    final included = payments
        .where((r) => r.source != 'manual' && r.included && !r.removed)
        .toList();
    final protected = payments
        .where(
          (r) =>
              r.source != 'manual' &&
              (r.removed || !r.included && !r.selectionAutomatic),
        )
        .length;
    setState(() {
      _analysis = analysis;
      if (resetFinance) _onlyIncluded = true;
      _notice =
          '${resetFinance ? 'Propuesta de Finanzas restablecida' : 'Proyección actualizada desde Finanzas'} · ${included.length} pagos incluidos · ${_money(included.fold<int>(0, (s, r) => s + r.total))}.'
          '${protected > 0 ? ' Se conservaron $protected exclusiones o borrados.' : ''}';
    });
  });

  Future<void> _opening() => _mutate(() async {
    final plan = _effective!;
    await showIncomeForm(
      context,
      title: 'Saldo inicial · ${programDate(plan.week)}',
      description:
          'Captura el saldo disponible para esta proyección. El flujo suma cobros pendientes y resta pagos pendientes; si la semana ya inició, usa el saldo disponible actualizado para no volver a contar movimientos realizados.',
      fields: [
        IncomeFormField(
          'cash',
          'Efectivo (MXN)',
          plan.openingCash == null ? null : plan.openingCash! / 100,
          numeric: true,
          min: -1e12,
        ),
        IncomeFormField(
          'fiscal',
          'Fiscal (MXN)',
          plan.openingFiscal == null ? null : plan.openingFiscal! / 100,
          numeric: true,
          min: -1e12,
        ),
      ],
      onSave: (v) => _save(
        plan.copyWith(
          openingCash: ((v['cash'] as num) * 100).round(),
          openingFiscal: ((v['fiscal'] as num) * 100).round(),
        ),
      ),
    );
  });

  Future<void> _editMenudeo() => _mutate(() async {
    final plan = _effective!;
    await showIncomeForm(
      context,
      title: 'Estimación de efectivo · Menudeo',
      description:
          'Ajusta los importes de la semana completa. Deja un campo vacío para usar el promedio histórico. El flujo toma únicamente hoy y los días restantes, descontando lo registrado hoy. Un cero explícito elimina la estimación de ese concepto. Si un gasto ya está programado en Finanzas, descuéntalo aquí.',
      fields: [
        IncomeFormField(
          'menudeoPurchases',
          'Compras previstas (MXN / semana)',
          plan.menudeo.purchases == null ? null : plan.menudeo.purchases! / 100,
          numeric: true,
          optional: true,
        ),
        IncomeFormField(
          'menudeoExpenses',
          'Gastos previstos (MXN / semana)',
          plan.menudeo.expenses == null ? null : plan.menudeo.expenses! / 100,
          numeric: true,
          optional: true,
        ),
        IncomeFormField(
          'menudeoIncluded',
          'Incluir estimación de Menudeo en el flujo',
          plan.menudeo.included,
        ),
      ],
      onSave: (v) {
        int? cents(String key) {
          if (v[key] == null) return null;
          final raw = (v[key] as num).toDouble() * 100;
          if ((raw - raw.round()).abs() > 0.00001) {
            throw ArgumentError('Captura importes con máximo dos decimales.');
          }
          return raw.round();
        }

        return _save(
          plan.copyWith(
            menudeo: MenudeoExpenseSettings(
              purchases: cents('menudeoPurchases'),
              expenses: cents('menudeoExpenses'),
              included: v['menudeoIncluded'] as bool,
            ),
          ),
        );
      },
    );
  });

  Future<void> _addExpense() => _mutate(() async {
    final plan = _effective!;
    final catalog = _catalog!;
    final savedById = {for (final row in plan.activePayments) row.id: row};
    final candidates = {
      for (final row in catalog.byId.values)
        if (row.source == 'invoice' ||
            (row.source == 'agreement' && row.available > 0))
          row.id:
              savedById[row.id] ??
              row.copyWith(amount: row.available, included: false),
    };
    const manual = 'manual';
    final options = [
      const SearchablePickerOption(
        value: manual,
        label: 'Capturar egreso manual',
      ),
      for (final row in candidates.values)
        SearchablePickerOption(
          value: row.id,
          label:
              '${row.source == 'invoice' ? '${row.reference} · ${row.payee}' : '${row.payee} · ${row.reference}'}'
              '${row.account.isEmpty ? '' : ' · ${row.account.replaceAll('|', ' / ')}'}\n'
              '${row.available > 0
                  ? 'Saldo ${_money(row.available)} · Pago ${programDate(row.date)} · ${projectionPaymentTypes[row.paymentType]}'
                  : catalog.commitmentsFor(row.id).isNotEmpty
                  ? 'Programar mediante su convenio'
                  : 'No disponible · ${row.warning}'}'
              '${row.included || catalog.commitmentsFor(row.id).any((p) => savedById[p.id]?.included == true) ? ' · Ya programado' : ''}',
        ),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final selected = await showSearchablePickerDialog<String>(
      context,
      title: candidates.isEmpty
          ? 'Agregar egreso · Sin facturas o convenios disponibles'
          : 'Agregar egreso · Facturas y convenios de Finanzas',
      options: options,
    );
    if (!mounted || selected == null) return;
    if (selected == manual) {
      await _showPaymentEditor(null);
    } else {
      final row = candidates[selected]!;
      await _openPayment(row, include: true);
    }
  });

  Future<void> _editPayment(ProjectedPayment payment) =>
      _mutate(() => _openPayment(payment));

  Future<void> _openPayment(
    ProjectedPayment row, {
    bool include = false,
  }) async {
    if (row.available > 0) {
      await _showPaymentEditor(
        row.copyWith(
          amount: row.amount > 0 ? row.amount : row.available,
          included: include || row.included || row.amount == 0,
        ),
      );
      return;
    }
    final targets = _catalog!.commitmentsFor(row.id);
    if (targets.isNotEmpty) {
      var target = targets.first;
      if (targets.length > 1) {
        final selected = await showSearchablePickerDialog<String>(
          context,
          title: '${row.reference} · Cuotas pendientes',
          options: [
            for (final payment in targets)
              SearchablePickerOption(
                value: payment.id,
                label:
                    '${payment.reference} · Saldo ${_money(payment.available)}',
              ),
          ]..sort((a, b) => a.label.compareTo(b.label)),
        );
        if (!mounted || selected == null) return;
        target = targets.firstWhere((p) => p.id == selected);
      }
      final plan = _effective!;
      final saved = plan.activePayments.where((p) => p.id == target.id);
      final payment = saved.isEmpty ? target : saved.single;
      await _showPaymentEditor(
        payment.copyWith(
          amount: payment.amount > 0 ? payment.amount : payment.available,
          included: include || payment.included || payment.amount == 0,
        ),
        contextDescription:
            '${row.reference} · ${row.payee}\n'
            'Este pago corresponde a la cuota del convenio. '
            'Puedes programarla en esta semana aunque esté vencida. '
            'Si la cuota agrupa varias facturas, el importe corresponde a toda la cuota.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AreaThemeScope(
        tokens: directionAreaTokens,
        child: incomeThemed(
          context,
          ContractDialogShell(
            child: SizedBox(
              width: 560,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        Navigator.pop(dialogContext),
                    const SingleActivator(LogicalKeyboardKey.enter): () =>
                        Navigator.pop(dialogContext),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _text(
                          'Disponibilidad del egreso',
                          bold: true,
                          size: 20,
                        ),
                        const SizedBox(height: 12),
                        _text('${row.payee} · ${row.reference}'),
                        const SizedBox(height: 12),
                        _text(
                          row.warning ??
                              'No hay saldo pendiente disponible en Finanzas.',
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cerrar'),
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
      ),
    );
  }

  Future<void> _showPaymentEditor(
    ProjectedPayment? payment, {
    String? contextDescription,
  }) async {
    final plan = _effective!;
    final row =
        payment ??
        ProjectedPayment(
          id: 'manual:${const Uuid().v4()}',
          source: 'manual',
          payee: '',
          reference: 'Egreso adicional',
          account: '',
          date: plan.week,
          amount: 0,
          available: 100000000000000,
        );
    final newRow = payment == null;
    await showIncomeForm(
      context,
      title: newRow ? 'Agregar egreso' : 'Programar pago',
      description: newRow
          ? 'Incluye un gasto adicional que no esté ya en la propuesta.'
          : '${contextDescription == null ? '' : '$contextDescription\n\n'}${row.payee} · ${row.reference}\nSaldo pendiente: ${_money(row.available)}${row.warning == null ? '' : '\n${row.warning}'}',
      fields: [
        if (newRow)
          const IncomeFormField('payee', 'Beneficiario / concepto', ''),
        IncomeFormField(
          'amount',
          'Importe programado (MXN)',
          row.amount > 0 ? row.amount / 100 : null,
          numeric: true,
          min: 0.01,
          max: row.available / 100,
        ),
        IncomeFormField(
          'date',
          'Fecha de pago',
          programDate(row.date),
          options: {
            for (var d = 0; d < 7; d++)
              programDate(
                plan.week.add(Duration(days: d)),
              ): '${programDate(plan.week.add(Duration(days: d)))} · ${const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][d]}',
          },
        ),
        IncomeFormField(
          'type',
          'Tipo de salida',
          row.paymentType,
          options: projectionPaymentTypes,
        ),
        IncomeFormField(
          'included',
          'Incluir en el flujo de la semana',
          newRow || row.included || row.amount == 0,
        ),
        IncomeFormField(
          'notes',
          'Nota de programación',
          row.notes,
          optional: true,
        ),
      ],
      onSave: (v) async {
        final updated = ProjectedPayment(
          id: row.id,
          source: row.source,
          payee: newRow
              ? (v['payee'] as String).trim().toUpperCase()
              : row.payee,
          reference: row.reference,
          account: row.account,
          date: DateTime.parse(v['date'] as String),
          amount: ((v['amount'] as num) * 100).round(),
          available: row.available,
          paymentType: v['type'] as String,
          paymentTypeAutomatic:
              row.paymentTypeAutomatic && v['type'] == row.paymentType,
          selectionAutomatic: false,
          included: v['included'] as bool,
          notes: v['notes'] as String,
        );
        if (updated.amount <= 0) {
          throw StateError(r'El importe mínimo es $0.01.');
        }
        await _save(
          plan.copyWith(
            payments: [
              for (final r in plan.payments)
                if (r.id != row.id) r else updated,
              if (!plan.payments.any((r) => r.id == row.id)) updated,
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggle(ProjectedPayment row) => _mutate(() async {
    if (row.amount <= 0 || row.available <= 0) {
      await _openPayment(row, include: true);
      return;
    }
    final plan = _effective!;
    await _save(
      plan.copyWith(
        payments: [
          for (final r in plan.payments)
            if (r.id == row.id)
              r.copyWith(included: !r.included, selectionAutomatic: false)
            else
              r,
        ],
      ),
    );
  });

  Future<void> _deletePayment(ProjectedPayment row) => _mutate(() async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Borrar egreso de esta semana',
      content:
          '${row.payee} · ${row.reference}\n${_money(row.amount)}\n\n'
          'Se quitará de la proyección y del flujo de esta semana. '
          'Los registros originales de Finanzas se conservan.',
      confirmText: 'Borrar egreso',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final plan = _effective!;
    await _save(
      plan.copyWith(
        payments: [
          for (final r in plan.payments)
            if (r.id != row.id)
              r
            else if (r.source != 'manual')
              r.copyWith(
                removed: true,
                included: false,
                selectionAutomatic: false,
              ),
        ],
      ),
    );
  });

  Future<void> _exportExpenses() => _export(expenses: true);

  Future<void> _export({bool expenses = false}) async {
    if (_busy ||
        _loading ||
        _error != null ||
        (!expenses && _income == null) ||
        _effective == null) {
      return;
    }
    final plan = _effective!;
    setState(() {
      _exporting = true;
      _notice = 'Generando PDF…';
    });
    try {
      final assets = DefaultAssetBundle.of(context);
      final bytes = expenses
          ? await buildWeeklyExpensesPdf(
              plan,
              generatedAt: _readAt!,
              assetBundle: assets,
            )
          : await buildWeeklyCashFlowPdf(
              _income!,
              plan,
              generatedAt: _readAt!,
              assetBundle: assets,
            );
      if (!mounted) return;
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName:
            '${expenses ? 'egresos_proyectados' : 'flujo_semanal_proyectado'}_${programDate(plan.week)}.pdf',
        dialogTitle: expenses
            ? 'Guardar egresos proyectados'
            : 'Guardar flujo semanal proyectado',
        throwOnPickerError: true,
      );
      if (mounted) {
        setState(
          () => _notice = path == null
              ? 'No se guardó el PDF: se canceló la selección.'
              : 'PDF guardado en $path',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _notice = 'No se pudo generar o guardar el PDF. $e');
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _effective;
    final disabled = _busy || _loading || _error != null;
    final week = widget.bundle.weekStartDate;
    return incomeThemed(
      context,
      SingleChildScrollView(
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
                  _text(
                    widget.flow
                        ? 'FLUJO SEMANAL PROYECTADO'
                        : 'EGRESOS PROYECTADOS',
                    bold: true,
                    size: 22,
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
                  _text(
                    '${programDate(week)} – ${programDate(week.add(const Duration(days: 6)))}',
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
                  if (!widget.flow) ...[
                    FilledButton.icon(
                      key: const ValueKey('generate-projected-payments'),
                      onPressed: disabled || plan == null
                          ? null
                          : () => _generate(),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generar propuesta de pagos'),
                    ),
                    if (plan?.generated == true)
                      OutlinedButton.icon(
                        key: const ValueKey('reset-projected-payments'),
                        onPressed: disabled
                            ? null
                            : () => _generate(resetFinance: true),
                        icon: const Icon(Icons.restore),
                        label: const Text('Restablecer propuesta de Finanzas'),
                      ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-projected-expense'),
                      onPressed: disabled || plan == null ? null : _addExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar egreso'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('export-weekly-expenses'),
                      onPressed: disabled || plan == null
                          ? null
                          : _exportExpenses,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF de egresos'),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      key: const ValueKey('projection-opening'),
                      onPressed: disabled || plan == null ? null : _opening,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Saldo inicial'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('export-weekly-flow'),
                      onPressed: disabled || _income == null || plan == null
                          ? null
                          : _export,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF de flujo'),
                    ),
                  ],
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: _text(
                  '$_error\nSe conserva la última lectura; edición y exportación suspendidas.',
                  color: kDirectionDanger,
                ),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: _text(_notice!),
              ),
            if (plan != null) ...[
              const SizedBox(height: 14),
              if (widget.flow && _income != null)
                _flow(WeeklyCashFlow(_income!.current, plan))
              else if (widget.flow)
                const Center(child: Text('Cargando ingresos de la semana…'))
              else
                _expenses(plan, disabled),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expenses(WeeklyExpensePlan plan, bool disabled) {
    final catalog = _catalog!;
    final payments = [...plan.activePayments]
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date != 0 ? date : a.payee.compareTo(b.payee);
      });
    final total = plan.total;
    final ids = plan.payments.map((r) => r.id).toSet();
    final newCount = _proposal.where((r) => !ids.contains(r.id)).length;
    final visible = payments
        .where(
          (r) =>
              (!_onlyIncluded || r.included) &&
              '${r.payee} ${r.reference} ${r.account}'.toLowerCase().contains(
                _search.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'PAGOS PROGRAMADOS',
              _money(total),
              'Finanzas + efectivo estimado de Menudeo',
            ),
            for (final type in projectionPaymentTypes.entries)
              _metric(
                type.value.toUpperCase(),
                _money(plan.totalForType(type.key)),
                'Egresos de la semana',
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_menudeo != null) ...[
          _menudeoSection(_menudeo!, disabled),
          const SizedBox(height: 14),
        ],
        ContractGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _text(
                'Propuesta de Generar viernes · tope de referencia ${_money(FinanceWeeklyBudgetAnalysis.weeklyLimit)}. Puedes ajustar importes, fechas y tipo de salida. Cada cambio se guarda en esta semana.',
              ),
              _text(
                'Programar aquí no ejecuta pagos. Los saldos pendientes se actualizan desde Finanzas.',
              ),
              _text(
                'Generar propuesta de pagos calcula la propuesta de Finanzas. Si ya existe, actualiza los pendientes automáticos y agrega los nuevos. Conserva tus ajustes, exclusiones y borrados.',
              ),
              if (plan.generated)
                _text(
                  'Si borraste la propuesta y quieres recuperar los pagos incluidos, usa Restablecer propuesta de Finanzas.',
                ),
              _text(
                'Clasificación de Finanzas: facturas → Fiscal; tickets sin factura → Efectivo. Para programar tickets, muestra también los pagos no incluidos.',
              ),
              if (payments.fold<int>(0, (s, r) => s + r.total) >
                  FinanceWeeklyBudgetAnalysis.weeklyLimit)
                _text(
                  'La programación de Finanzas supera el tope de referencia por ${_money(payments.fold<int>(0, (s, r) => s + r.total) - FinanceWeeklyBudgetAnalysis.weeklyLimit)}.',
                  color: kDirectionWarning,
                ),
              if (newCount > 0)
                _text(
                  '$newCount obligaciones disponibles para incorporar; se conservan los ajustes existentes.',
                ),
              if (!plan.generated)
                _text(
                  'Aún no se ha generado la propuesta de esta semana.',
                  color: kDirectionWarning,
                ),
              for (final warning in _analysis!.warnings)
                _text(warning, color: kDirectionWarning),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('payment-search'),
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  labelText: 'Buscar beneficiario, factura o cuenta',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: _text('Mostrar solo pagos incluidos'),
                value: _onlyIncluded,
                onChanged: (v) => setState(() => _onlyIncluded = v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          ContractGlassCard(
            child: _text(
              'No hay pagos en esta selección. Genera la propuesta o muestra también los pendientes.',
            ),
          ),
        for (final row in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ContractGlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (catalog.commitmentsFor(row.id).isNotEmpty)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.account_tree_outlined),
                    )
                  else
                    Checkbox(
                      key: ValueKey('include-payment-${row.id}'),
                      value: row.included,
                      onChanged: disabled || row.available <= 0
                          ? null
                          : (_) => _toggle(row),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(
                          '${programDate(row.date)} · ${row.payee}',
                          bold: true,
                        ),
                        _text(
                          '${row.reference}${row.account.isEmpty ? '' : ' · ${row.account.replaceAll('|', ' / ')}'}',
                        ),
                        _text(
                          catalog.commitmentsFor(row.id).isNotEmpty
                              ? '${projectionPaymentTypes[row.paymentType]} · Programación mediante convenio'
                              : '${_money(row.amount)} · ${projectionPaymentTypes[row.paymentType]}${row.included ? '' : ' · Excluido'}',
                          bold: true,
                        ),
                        if (row.available > 0 && row.source != 'manual')
                          _text('Saldo disponible: ${_money(row.available)}'),
                        if (catalog.commitmentsFor(row.id).isNotEmpty)
                          TextButton(
                            key: ValueKey('agreement-payment-${row.id}'),
                            onPressed: disabled
                                ? null
                                : () => _editPayment(row),
                            child: Text(
                              catalog
                                      .commitmentsFor(row.id)
                                      .any(
                                        (p) => plan.activePayments.any(
                                          (saved) =>
                                              saved.id == p.id &&
                                              saved.included,
                                        ),
                                      )
                                  ? 'Editar pago del convenio'
                                  : 'Programar convenio',
                            ),
                          ),
                        if (row.notes.isNotEmpty) _text(row.notes),
                        if (row.warning != null)
                          _text(row.warning!, color: kDirectionWarning),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('edit-payment-${row.id}'),
                    tooltip: row.available > 0
                        ? 'Editar programación'
                        : catalog.commitmentsFor(row.id).isNotEmpty
                        ? 'Programar convenio'
                        : 'Ver disponibilidad',
                    onPressed: disabled ? null : () => _editPayment(row),
                    icon: Icon(
                      row.available > 0 ||
                              catalog.commitmentsFor(row.id).isNotEmpty
                          ? Icons.edit_outlined
                          : Icons.info_outline,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('delete-payment-${row.id}'),
                    tooltip: 'Borrar egreso de esta semana',
                    onPressed: disabled ? null : () => _deletePayment(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _menudeoSection(
    MenudeoExpenseEstimate estimate,
    bool disabled,
  ) => ContractGlassCard(
    key: const ValueKey('menudeo-expense-section'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _text('Menudeo · efectivo estimado', bold: true, size: 20),
            OutlinedButton.icon(
              key: const ValueKey('edit-menudeo-estimate'),
              onPressed: disabled ? null : _editMenudeo,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ajustar estimación'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _text(estimate.period),
        _text(
          'Promedio por día de la semana de compras pagadas y gastos. Excluye depósitos y movimientos internos. ${estimate.excludedInternal} movimientos internos omitidos.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            for (final purchase in [true, false])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(
                    purchase ? 'Compras de Menudeo' : 'Gastos de Menudeo',
                    bold: true,
                  ),
                  _text(
                    'Promedio semanal: ${_money(estimate.sum(purchase ? estimate.averagePurchases : estimate.averageExpenses))}',
                  ),
                  _text(
                    'Base de la semana: ${_money(estimate.sum(estimate.budget(purchase)))}${(purchase ? estimate.settings.purchases : estimate.settings.expenses) == null ? ' · Automática' : ' · Ajustada'}',
                  ),
                  _text(
                    'Registrado: ${_money(estimate.sum(purchase ? estimate.actualPurchases : estimate.actualExpenses))}',
                  ),
                  _text(
                    'Por gastar: ${_money(estimate.sum(estimate.remaining(purchase)))}',
                    bold: true,
                  ),
                ],
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(
                  'Total previsto al cierre: ${_money(estimate.actual + estimate.pending)}',
                  bold: true,
                ),
                _text(
                  'Incluido en flujo: ${_money(estimate.settings.included ? estimate.pending : 0)} · Efectivo',
                  bold: true,
                ),
                if (!estimate.settings.included)
                  _text(
                    'Estimación excluida del flujo.',
                    color: kDirectionWarning,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _text(
          'El flujo incluye lo pendiente desde hoy; los días transcurridos y los gastos ya registrados no se vuelven a restar. Los ajustes se guardan para esta semana.',
        ),
        for (final warning in estimate.warnings)
          _text(warning, color: kDirectionWarning),
      ],
    ),
  );

  Widget _flow(WeeklyCashFlow flow) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric(
            'ENTRADAS PREVISTAS',
            _money(flow.income.total),
            'Cobros + disposición de El Palomar',
          ),
          _metric(
            'EGRESOS PROGRAMADOS',
            _money(flow.expenses),
            'Finanzas + efectivo estimado de Menudeo',
          ),
          _metric('FLUJO NETO', _money(flow.net), 'Entradas menos egresos'),
          _metric(
            'SALDO FINAL',
            flow.closing == null ? 'Sin saldo inicial' : _money(flow.closing!),
            'Saldo inicial + flujo neto',
          ),
        ],
      ),
      const SizedBox(height: 14),
      ContractGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _text('Resumen de la semana · MXN', bold: true, size: 20),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                _tableRow([
                  'Concepto',
                  'Efectivo',
                  'Fiscal',
                  'Sin distribuir',
                  'Total',
                ], heading: true),
                _tableRow([
                  'Saldo inicial',
                  _optional(flow.plan.openingCash),
                  _optional(flow.plan.openingFiscal),
                  '—',
                  _optional(flow.opening),
                ]),
                _tableRow([
                  'Cobros por ventas',
                  for (final t in ['EFECTIVO', 'FISCAL', 'MIXTO'])
                    _money(
                      (flow.income.byType[t] ?? 0) -
                          (flow.income.financingByType[t] ?? 0),
                    ),
                  _money(flow.income.salesTotal),
                ]),
                _tableRow([
                  'Disposición El Palomar',
                  for (final t in ['EFECTIVO', 'FISCAL', 'MIXTO'])
                    _money(flow.income.financingByType[t] ?? 0),
                  _money(flow.income.financingTotal),
                ]),
                _tableRow([
                  'Egresos programados',
                  for (final t in ['EFECTIVO', 'FISCAL', 'SIN_CLASIFICAR'])
                    _money(flow.expense(t)),
                  _money(flow.expenses),
                ]),
                if (flow.plan.menudeoPayments.isNotEmpty)
                  _tableRow([
                    'De los cuales: Menudeo estimado',
                    _money(
                      flow.plan.menudeoPayments.fold<int>(
                        0,
                        (s, r) => s + r.total,
                      ),
                    ),
                    _money(0),
                    _money(0),
                    _money(
                      flow.plan.menudeoPayments.fold<int>(
                        0,
                        (s, r) => s + r.total,
                      ),
                    ),
                  ]),
                _tableRow([
                  'Flujo neto',
                  for (final t in ['EFECTIVO', 'FISCAL'])
                    _money((flow.income.byType[t] ?? 0) - flow.expense(t)),
                  _money(
                    (flow.income.byType['MIXTO'] ?? 0) -
                        flow.expense('SIN_CLASIFICAR'),
                  ),
                  _money(flow.net),
                ]),
                _tableRow([
                  'Saldo final',
                  flow.classified
                      ? _optional(flow.closingFor('EFECTIVO'))
                      : 'Por distribuir',
                  flow.classified
                      ? _optional(flow.closingFor('FISCAL'))
                      : 'Por distribuir',
                  '—',
                  _optional(flow.closing),
                ], heading: true),
              ],
            ),
            const SizedBox(height: 14),
            _text(
              'Cobros y pagos pendientes de la semana consultada. Para semanas en curso, captura como saldo inicial el disponible actualizado.',
            ),
            if (!flow.plan.generated)
              _text(
                'Falta generar la propuesta de egresos; el flujo está incompleto.',
                color: kDirectionWarning,
              ),
            if (!flow.classified)
              _text(
                'Hay ingresos mixtos o egresos sin clasificar. El saldo final por Efectivo/Fiscal queda pendiente de distribución.',
                color: kDirectionWarning,
              ),
            if (_menudeo != null)
              for (final warning in _menudeo!.warnings)
                _text(warning, color: kDirectionWarning),
            if (flow.closing != null && flow.closing! < 0)
              _text(
                'Faltante proyectado total: ${_money(-flow.closing!)}',
                color: kDirectionDanger,
              ),
            for (final t in ['EFECTIVO', 'FISCAL'])
              if ((flow.closingFor(t) ?? 0) < 0)
                _text(
                  'Faltante en ${projectionPaymentTypes[t]}: ${_money(-flow.closingFor(t)!)}',
                  color: kDirectionDanger,
                ),
            _text(
              'Los ingresos sin fecha y la cobranza vencida de otras semanas se consultan en Ingresos; no se suman automáticamente a esta semana.',
            ),
            if (_income!.warnings.isNotEmpty)
              _text(
                '${_income!.warnings.length} avisos de las fuentes de ingreso; revisar Ingresos antes de decidir.',
                color: kDirectionWarning,
              ),
            _text(
              'Versión de egresos ${flow.plan.revision} · Lectura ${_readAt == null ? '' : programDate(_readAt!)}',
            ),
          ],
        ),
      ),
    ],
  );

  TableRow _tableRow(List<String> values, {bool heading = false}) => TableRow(
    children: [
      for (final v in values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: _text(v, bold: heading),
        ),
    ],
  );
  Widget _metric(String label, String value, String detail) => SizedBox(
    width: 285,
    child: DirectionMetricCard(
      icon: Icons.account_balance_wallet_outlined,
      title: label,
      value: value,
      detail: detail,
      accent: kDirectionGoldAccent,
    ),
  );
  Widget _text(
    String s, {
    bool bold = false,
    double size = 14,
    Color color = kDirectionSurfaceText,
  }) => Text(
    s,
    style: TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: size,
    ),
  );
  String _optional(int? value) =>
      value == null ? 'Por capturar' : _money(value);
}

String _money(int cents) => formatMoney(cents / 100);
