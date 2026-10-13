import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../../shared/utils/file_download_save.dart';
import '../direction_theme.dart';
import '../expected_income/expected_income_forms.dart';
import 'profitability_engine.dart';
import 'profitability_material_units.dart';
import 'profitability_material_basis.dart';
import 'profitability_inference.dart' show profitMaterialFamily;
import 'profitability_export.dart';
import 'profitability_forms.dart';
import 'profitability_models.dart';
import 'profitability_repository.dart';
import 'profitability_parameters.dart';
import 'profitability_account_models.dart';
import 'profitability_pdf.dart';
import 'profitability_consolidated.dart';

part 'profitability_executive_view.dart';
part 'profitability_simple_view.dart';
part 'profitability_consolidated_view.dart';

/// Hybrid report tabs with a Mantenimiento-style navigable master/detail.
/// Auxiliary forms follow Dirección / Proyección; no editable transaction grid.
class ProfitabilityView extends StatefulWidget {
  final ProfitabilityRepository? repository;
  final ProfitPeriod? initialPeriod;
  final bool simple;
  const ProfitabilityView({
    super.key,
    this.repository,
    this.initialPeriod,
    this.simple = true,
  });
  @override
  State<ProfitabilityView> createState() => _ProfitabilityViewState();
}

class _ProfitabilityViewState extends State<ProfitabilityView> {
  late final _repo = widget.repository ?? ProfitabilityRepository();
  late ProfitPeriod _period = widget.initialPeriod ?? _presetPeriod(2);
  int _executiveTab = 0, _preset = 1, _sort = 0;
  bool _ascending = false;
  bool _advanced = false;
  String? _simpleSelected;
  bool _showBasis = false;
  int _simpleTab = 0;
  String? _consolidatedSelected;
  ProfitDecisionPlan _decisionPlan = ProfitDecisionPlan();
  bool _decisionShowAll = false;
  final _consolidatedScroll = ScrollController();
  String? _executiveSelected;
  void _redraw(VoidCallback action) => setState(action);
  final _search = TextEditingController();
  final _listFocus = FocusNode();
  final _listScroll = ScrollController();
  Timer? _timer;
  ProfitAnalysis? _analysis;
  String? _error, _selected;
  int _tab = 0, _generation = 0;
  bool _loading = false, _busy = false, _onlyPending = true;
  final Map<String, ProfitExitScenario> _scenarios = {};
  @override
  void initState() {
    super.initState();
    _advanced = !widget.simple;
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _search.dispose();
    _listFocus.dispose();
    _listScroll.dispose();
    _consolidatedScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || _loading) return;
    _loading = true;
    final generation = ++_generation;
    try {
      final bundle = await _repo.load(_period);
      final result = bundle.analysis;
      if (!mounted || generation != _generation) return;
      setState(() {
        _analysis = result;
        _error = null;
        if (!result.reportCompanies.any(
          (c) => c.account != null && c.entity.key == _consolidatedSelected,
        )) {
          _consolidatedSelected = ProfitConsolidated(
            result.reportCompanies,
          ).priorities.firstOrNull?.company.entity.key;
          _decisionPlan = ProfitDecisionPlan();
        }
        if (!result.reportCompanies.any(
          (c) => c.entity.key == _executiveSelected,
        )) {
          _executiveSelected = null;
        }
        if (!result.reportCompanies.any((c) => c.entity.key == _selected)) {
          _selected = result.reportCompanies.firstOrNull?.entity.key;
        }
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'No se pudo consolidar el corte. $e');
      }
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  bool get _enabled => !_busy && _error == null && _analysis != null;
  Future<void> _guard(Future<void> Function() action) async {
    if (!_enabled) return;
    setState(() {
      _busy = true;
      _generation++;
      _loading = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_load());
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _save(ProfitReview review) async {
    // Validate the complete proposed result before persisting configuration.
    analyzeProfitability(
      _analysis!.sources,
      review,
      master: _analysis!.master,
      inferOperations: true,
    );
    final saved = await _repo.save(_period, review);
    if (mounted) {
      setState(
        () => _analysis = analyzeProfitability(
          _analysis!.sources,
          saved,
          master: _analysis!.master,
          inferOperations: true,
        ),
      );
    }
  }

  Future<void> _change(ProfitPeriod period) async {
    if (_busy) return;
    setState(() {
      _period = period;
      _analysis = null;
      _error = null;
      _generation++;
      _loading = false;
      _scenarios.clear();
      _consolidatedSelected = null;
      _decisionPlan = ProfitDecisionPlan();
      _executiveSelected = null;
    });
    await _load();
  }

  Future<void> _pickPeriod() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _generation++;
      _loading = false;
    });
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _period.start, end: _period.end),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => incomeThemed(context, child!),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (range != null) {
      try {
        _preset = 3;
        await _change(ProfitPeriod(range.start, range.end));
      } catch (e) {
        if (mounted) _message('$e');
      }
    } else {
      unawaited(_load());
    }
  }

  String _money(double? value) =>
      value == null ? 'Pendiente' : '\$${value.toStringAsFixed(2)}';
  String _price(double? value) =>
      value == null ? 'Pendiente' : '\$${value.toStringAsFixed(4)}';
  String _qty(double value) => value.toStringAsFixed(2);
  Map<String, String> get _entityOptions => {
    for (final e in _analysis!.entities) e.key: '${e.label} · ${e.key}',
  };
  Widget _text(String text, {bool warning = false}) => Text(
    text,
    style: TextStyle(color: warning ? kDirectionWarning : kDirectionMutedText),
  );
  Widget _card(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ContractGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: kDirectionSurfaceText,
      ),
    ),
  );
  Widget _action(String label, VoidCallback callback, {IconData? icon}) =>
      OutlinedButton.icon(
        onPressed: _enabled ? callback : null,
        icon: Icon(icon ?? Icons.edit_outlined, size: 18),
        label: Text(label),
      );

  Future<void> _identity() => _guard(() async {
    await showIncomeForm(
      context,
      title: 'Equivalencia de empresa',
      description:
          'Une únicamente registros de la misma planta. Los nombres parecidos requieren confirmación. Elegir el mismo origen y destino elimina la equivalencia manual.',
      fields: [
        IncomeFormField(
          'origin',
          'Registro de origen',
          '',
          options: _entityOptions,
        ),
        IncomeFormField(
          'target',
          'Empresa / planta destino',
          '',
          options: _entityOptions,
        ),
      ],
      onSave: (v) async {
        final origin = profitText(v['origin']),
            target = profitText(v['target']);
        if (!_entityOptions.containsKey(origin) ||
            !_entityOptions.containsKey(target)) {
          throw StateError('Selecciona origen y destino.');
        }
        final identities = {..._analysis!.review.identities};
        if (origin == target) {
          identities.remove(origin);
        } else {
          identities[origin] = target;
        }
        await _save(_analysis!.review.copyWith(identities: identities));
      },
    );
  });
  Future<void> _recipe(ProfitMaterialResult material) => _guard(() async {
    final a = _analysis!;
    await showProfitDistribution(
      context,
      title: 'Valor recuperable · ${material.material}',
      description:
          'Selecciona salidas comercialmente comparables y su rendimiento por kg físico de entrada. La diferencia hasta 100% es merma. El promedio de venta usa los importes y pesos elegibles del mismo corte.',
      options: {
        for (final b in a.benchmarks.values)
          b.key:
              '${b.material} · ${b.source} · ${_price(b.price)}/kg · ${b.count} ventas',
      },
      values: {
        for (final o in material.recipe?.outputs ?? <ProfitOutputRule>[])
          o.benchmark: o.yieldFraction,
      },
      note: material.recipe?.note ?? '',
      complete: false,
      onSave: (values, note) => _save(
        a.review.copyWith(
          recipes: {
            ...a.review.recipes,
            material.key: ProfitRecipe(
              outputs: [
                for (final e in values.entries)
                  ProfitOutputRule(e.key, e.value),
              ],
              note: note,
            ),
          },
        ),
      ),
    );
  });
  Future<void> _cost(ProfitCostFact fact) => _guard(() async {
    final a = _analysis!, old = _analysis!.effectiveCostRules[fact.key];
    Map<String, dynamic>? chosen;
    final accepted = await showIncomeForm(
      context,
      title: 'Conciliar · ${fact.label}',
      description:
          '${fact.source} · ${profitDateText(fact.date)} · Documento ${_money(fact.amount)}. ${fact.payrollNet ? 'Registra el costo laboral completo; el neto publicado es solo referencia.' : 'Reconoce una sola vez el costo económico; vincula los demás comprobantes como evidencia.'}',
      fields: [
        IncomeFormField(
          'treatment',
          'Tratamiento',
          (old?.treatment ?? ProfitCostTreatment.include).name,
          options: {
            for (final v in ProfitCostTreatment.values) v.name: v.label,
          },
        ),
        IncomeFormField(
          'kind',
          'Tipo de costo',
          (old?.kind ?? fact.suggestedKind).name,
          options: {for (final v in ProfitCostKind.values) v.name: v.label},
        ),
        IncomeFormField(
          'amount',
          'Importe reconocido (vacío usa documento, excepto nómina)',
          old?.recognizedAmount,
          numeric: true,
          optional: true,
        ),
        IncomeFormField(
          'target',
          'Otro costo que reconoce este documento',
          old?.duplicateOf ?? '',
          options: {
            '': 'Sin vínculo',
            for (final c in a.costFacts.where((c) => c.key != fact.key))
              c.key: '${c.label} · ${c.source} · ${_money(c.amount)}',
          },
        ),
        IncomeFormField(
          'coverage_start',
          'Cobertura desde (AAAA-MM-DD)',
          profitDateText(
            old?.coverageStart ??
                (fact.payrollNet
                    ? profitPayrollPeriod(fact.label)?.start
                    : null) ??
                fact.date,
          ),
        ),
        IncomeFormField(
          'coverage_end',
          'Cobertura hasta (AAAA-MM-DD)',
          profitDateText(
            old?.coverageEnd ??
                (fact.payrollNet
                    ? profitPayrollPeriod(fact.label)?.end
                    : null) ??
                fact.date,
          ),
        ),
        IncomeFormField(
          'coverage_vehicle',
          'Unidad cubierta (vacío cubre todas las asignadas)',
          old?.coverageVehicle ?? '',
          options: {
            '': 'Todas las unidades de la asignación',
            for (final row in a.sources.rows('logistics_vehicle_profiles'))
              profitText(row['vehicle_id']): profitText(row['vehicle_code']),
          },
        ),
        IncomeFormField(
          'includes_maintenance',
          'Transporte incluye mantenimiento',
          old?.includesMaintenance ?? false,
        ),
        IncomeFormField(
          'estimated',
          'Importe o reparto estimado',
          old?.estimated ?? false,
        ),
        IncomeFormField(
          'note',
          'Fundamento / evidencia / periodo devengado',
          old?.note ?? '',
        ),
      ],
      onSave: (v) async {
        final treatment = ProfitCostTreatment.values.byName(v['treatment']);
        if (treatment == ProfitCostTreatment.include &&
            fact.payrollNet &&
            v['amount'] == null) {
          throw StateError('Captura el costo laboral conciliado.');
        }
        if (treatment == ProfitCostTreatment.duplicate &&
            profitText(v['target']).isEmpty) {
          throw StateError('Selecciona el costo reconocido.');
        }
        if (treatment == ProfitCostTreatment.include) {
          final start = _parameterDate(v['coverage_start']),
              end = _parameterDate(v['coverage_end']);
          if (end.isBefore(start) || end.difference(start).inDays > 365) {
            throw StateError('Cobertura inválida (máximo 366 días).');
          }
          if (v['includes_maintenance'] == true && v['kind'] != 'transport') {
            throw StateError('Solo transporte puede incluir mantenimiento.');
          }
        }
        chosen = Map.of(v);
        if (treatment != ProfitCostTreatment.include) {
          final rule = ProfitCostRule(
            treatment: treatment,
            kind: ProfitCostKind.values.byName(v['kind']),
            note: v['note'],
            sourceSignature: fact.signature,
            duplicateOf: profitText(v['target']),
            estimated: v['estimated'],
          );
          await _save(
            a.review.copyWith(costs: {...a.review.costs, fact.key: rule}),
          );
        }
      },
    );
    if (accepted != true ||
        chosen == null ||
        chosen!['treatment'] != 'include' ||
        !mounted) {
      return;
    }
    final v = chosen!;
    await showProfitDistribution(
      context,
      title: 'Asignar · ${fact.label}',
      description:
          'Distribuye ${_money(profitNumber(v['amount']) ?? fact.amount)} entre las empresas beneficiarias. El total debe ser 100%. Guardar confirma el tratamiento y el reparto juntos.',
      options: _entityOptions,
      values: old?.shares ?? {},
      note: v['note'],
      complete: true,
      onSave: (shares, note) => _save(
        a.review.copyWith(
          costs: {
            ...a.review.costs,
            fact.key: ProfitCostRule(
              treatment: ProfitCostTreatment.include,
              kind: ProfitCostKind.values.byName(v['kind']),
              shares: shares,
              recognizedAmount: profitNumber(v['amount']),
              note: note,
              sourceSignature: fact.signature,
              estimated: v['estimated'],
              coverageStart: _parameterDate(v['coverage_start']),
              coverageEnd: _parameterDate(v['coverage_end']),
              coverageVehicle: profitText(v['coverage_vehicle']),
              includesMaintenance: v['includes_maintenance'] == true,
            ),
          },
        ),
      ),
    );
  });
  Future<void> _review(ProfitCompanyResult c) => _guard(() async {
    final a = _analysis!, old = _analysis!.review.companies[c.entity.key];
    final current = old?.evidenceSignature == a.evidenceSignature;
    await showIncomeForm(
      context,
      title: 'Revisión · ${c.displayName}',
      description:
          'Confirma cobertura completa o ausencia justificada de cada costo. La revisión corresponde a estos datos y reglas; un cambio exige revisarla de nuevo. Los documentos y observaciones pendientes siguen bloqueando la conclusión.',
      fields: [
        IncomeFormField(
          'identity',
          'Misma empresa y planta; tickets sin duplicar',
          current && (old?.identity ?? false),
        ),
        IncomeFormField(
          'labor',
          'Costo laboral completo conciliado',
          current && (old?.labor ?? false),
        ),
        IncomeFormField(
          'fuel',
          'Combustible devengado y reparto conciliados',
          current && (old?.fuel ?? false),
        ),
        IncomeFormField(
          'process',
          'Rendimiento, proceso y merma sustentados',
          current && (old?.process ?? false),
        ),
        IncomeFormField(
          'expenses',
          'Otros gastos y estructura completos',
          current && (old?.expenses ?? false),
        ),
        IncomeFormField(
          'tax',
          'Importes comparables y misma base de impuestos',
          current && (old?.taxBasis ?? false),
        ),
        IncomeFormField(
          'note',
          'Evidencia y costos que no aplican',
          old?.note ?? '',
        ),
      ],
      onSave: (v) => _save(
        a.review.copyWith(
          companies: {
            ...a.review.companies,
            c.entity.key: ProfitCompanyReview(
              identity: v['identity'],
              labor: v['labor'],
              fuel: v['fuel'],
              process: v['process'],
              expenses: v['expenses'],
              taxBasis: v['tax'],
              note: v['note'],
              evidenceSignature: a.evidenceSignature,
            ),
          },
        ),
      ),
    );
  });
  Future<void> _exclude(ProfitPurchase p) => _guard(() async {
    await showIncomeForm(
      context,
      title: 'Excluir ticket ${p.reference}',
      description:
          'El ticket seguirá en su módulo original. La exclusión solo afecta este análisis y exige identificar la corrección o el ticket que ya representa la misma compra.',
      fields: const [IncomeFormField('note', 'Fundamento y referencia', '')],
      onSave: (v) => _save(
        _analysis!.review.copyWith(
          excludedPurchases: {
            ..._analysis!.review.excludedPurchases,
            p.key: {'signature': p.signature, 'note': v['note']},
          },
        ),
      ),
    );
  });
  Future<void> _scenario(ProfitCompanyResult c) => _guard(() async {
    final old = _scenarios[c.entity.key];
    await showIncomeForm(
      context,
      title: 'Simular salida · ${c.displayName}',
      description:
          'Escenario para un horizonte de ${_period.days} días. Captura solo costos que realmente desaparecerían. La estructura asignada no se convierte automáticamente en ahorro. Esta simulación no se guarda en el corte.',
      fields: [
        IncomeFormField(
          'lost',
          'Ingreso que se perdería',
          old?.lostRevenue,
          numeric: true,
        ),
        IncomeFormField(
          'purchase',
          'Compras que se evitarían',
          old?.avoidedPurchases,
          numeric: true,
        ),
        IncomeFormField(
          'ops',
          'Costos operativos que se evitarían',
          old?.avoidedOperations,
          numeric: true,
        ),
        IncomeFormField(
          'fixed',
          'Estructura que sí se eliminaría',
          old?.avoidedOverhead,
          numeric: true,
        ),
        IncomeFormField(
          'replacement',
          'Contribución de trabajo sustituto',
          old?.replacementContribution,
          numeric: true,
        ),
        IncomeFormField(
          'transition',
          'Costo de salida / transición',
          old?.transitionCost,
          numeric: true,
        ),
      ],
      onSave: (v) async {
        setState(
          () => _scenarios[c.entity.key] = ProfitExitScenario(
            lostRevenue: profitNumber(v['lost'])!,
            avoidedPurchases: profitNumber(v['purchase'])!,
            avoidedOperations: profitNumber(v['ops'])!,
            avoidedOverhead: profitNumber(v['fixed'])!,
            replacementContribution: profitNumber(v['replacement'])!,
            transitionCost: profitNumber(v['transition'])!,
          ),
        );
      },
    );
  });
  Future<void> _export(bool json) => _guard(() async {
    final a = _analysis!;
    final path = await saveBytesAs(
      bytes: Uint8List.fromList(
        utf8.encode(json ? a.toPrettyJson() : profitAccountCsv(a)),
      ),
      suggestedFileName: 'rentabilidad_${_period.key}.${json ? 'json' : 'csv'}',
      dialogTitle: 'Exportar análisis por empresa',
      throwOnPickerError: true,
    );
    if (mounted && path != null) _message('Análisis exportado.');
  });
  Future<void> _exportCompanyPdf(String companyKey) => _guard(() async {
    final data = ProfitabilityPdfData(_analysis!, companyKey);
    final bytes = await buildProfitabilityPdf(
      data,
      assetBundle: DefaultAssetBundle.of(context),
    );
    if (!mounted) return;
    final path = await saveBytesAs(
      bytes: bytes,
      suggestedFileName: data.fileName,
      dialogTitle: 'Guardar análisis de ${data.companyName}',
      throwOnPickerError: true,
    );
    if (mounted) {
      _message(
        path == null
            ? 'No se guardó el PDF.'
            : 'PDF de ${data.companyName} guardado.',
      );
    }
  });
  Future<void> _snapshot() => _guard(() async {
    await _repo.saveSnapshot(_analysis!);
    if (mounted) {
      _message('Corte guardado con sus reglas, evidencia y pendientes.');
    }
  });
  Future<void> _history() => _guard(() async {
    final rows = await _repo.history(_period);
    if (!mounted) return;
    await showIncomeForm(
      context,
      title: 'Cortes guardados',
      description: rows.isEmpty
          ? 'Todavía no hay cortes guardados para este periodo.'
          : 'Selecciona un corte para exportar su evidencia histórica. No se recalcula con datos actuales.',
      fields: [
        IncomeFormField(
          'cut',
          'Corte',
          '',
          options: {
            for (final r in rows)
              profitText(r['id']):
                  '${r['created_at']} · revisión ${r['review_revision']}',
          },
        ),
      ],
      onSave: (v) async {
        final match = rows.where((r) => r['id'] == v['cut']).firstOrNull;
        if (match == null) throw StateError('Selecciona un corte.');
        await saveBytesAs(
          bytes: Uint8List.fromList(
            utf8.encode(const JsonEncoder.withIndent('  ').convert(match)),
          ),
          suggestedFileName: 'corte_rentabilidad_${match['id']}.json',
          dialogTitle: 'Exportar corte histórico',
          throwOnPickerError: true,
        );
      },
    );
  });

  @override
  Widget build(BuildContext context) => !_advanced
      ? incomeThemed(context, _simpleView())
      : _advancedView(context);

  Widget _advancedView(BuildContext context) => incomeThemed(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _redraw(() => _advanced = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al análisis operativo'),
          ),
        ),
        _executiveNavigation(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._periodPresets(),
            IconButton(
              tooltip: 'Periodo anterior',
              onPressed: _busy
                  ? null
                  : () => _change(_period.shift(-_period.days)),
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _pickPeriod,
              child: Text(_period.label),
            ),
            IconButton(
              tooltip: 'Periodo siguiente',
              onPressed:
                  _busy ||
                      _period.shift(_period.days).end.isAfter(DateTime.now())
                  ? null
                  : () => _change(_period.shift(_period.days)),
              icon: const Icon(Icons.chevron_right),
            ),
            _action('CSV', () => _export(false), icon: Icons.download_outlined),
            _action(
              'Evidencia JSON',
              () => _export(true),
              icon: Icons.data_object,
            ),
            _action('Guardar corte', _snapshot, icon: Icons.lock_outline),
            _action('Historial', _history, icon: Icons.history),
          ],
        ),
        const SizedBox(height: 8),
        _text(
          'Rentabilidad operativa estimada · Importes parciales y supuestos visibles · No es utilidad contable realizada',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _text(
              '$_error\n${_analysis == null ? 'Reintentando automáticamente.' : 'Se conserva la última consulta; edición y exportación suspendidas.'}',
              warning: true,
            ),
          ),
        const SizedBox(height: 8),
        if (_executiveTab == 4)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? directionAreaTokens.primary.withValues(alpha: .18)
                      : directionAreaTokens.glassSurface,
                ),
                foregroundColor: WidgetStatePropertyAll(
                  directionAreaTokens.onGlass,
                ),
              ),
              segments: const [
                ButtonSegment(value: 0, label: Text('Detalle y evidencia')),
                ButtonSegment(value: 1, label: Text('Costos y conciliación')),
                ButtonSegment(value: 2, label: Text('Equivalencias')),
                ButtonSegment(value: 3, label: Text('Fuentes y cobertura')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.single),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _analysis == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : _text('Esperando una consulta completa.'),
                )
              : _executiveTab != 4
              ? _executiveContent()
              : switch (_tab) {
                  0 => _companies(),
                  1 => _costs(),
                  2 => _identities(),
                  _ => _sources(),
                },
        ),
      ],
    ),
  );
  List<ProfitCompanyResult> get _visibleCompanies => _analysis!.reportCompanies
      .where(
        (c) => profitKey(
          '${c.displayName} ${c.entity.source}',
        ).contains(profitKey(_search.text)),
      )
      .toList();
  Widget _companies() {
    final rows = _visibleCompanies;
    final selected =
        rows.where((c) => c.entity.key == _selected).firstOrNull ??
        rows.firstOrNull;
    final list = Column(
      children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Buscar empresa',
            prefixIcon: Icon(Icons.search),
          ),
          style: const TextStyle(color: kDirectionSurfaceText),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent || rows.isEmpty) {
                return KeyEventResult.ignored;
              }
              final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? 1
                  : event.logicalKey == LogicalKeyboardKey.arrowUp
                  ? -1
                  : 0;
              if (direction == 0) return KeyEventResult.ignored;
              final index = (rows.indexOf(selected!) + direction).clamp(
                0,
                rows.length - 1,
              );
              setState(() => _selected = rows[index].entity.key);
              if (_listScroll.hasClients) {
                _listScroll.animateTo(
                  (index * 100.0).clamp(
                    0,
                    _listScroll.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                );
              }
              return KeyEventResult.handled;
            },
            child: ListView.builder(
              controller: _listScroll,
              itemExtent: 100,
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final c = rows[i];
                return ListTile(
                  key: ValueKey('company:${c.entity.key}'),
                  selected: c == selected,
                  selectedTileColor: directionAreaTokens.primary.withValues(
                    alpha: .14,
                  ),
                  title: Text(
                    c.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kDirectionSurfaceText),
                  ),
                  subtitle: Text(
                    '${c.entity.source}\n${c.decision}',
                    maxLines: 3,
                    style: const TextStyle(color: kDirectionMutedText),
                  ),
                  onTap: () {
                    setState(() => _selected = c.entity.key);
                    _listFocus.requestFocus();
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
    final detail = selected == null
        ? Center(
            child: _text('Sin empresas con actividad visible en este corte.'),
          )
        : _detail(selected);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 320, child: list),
                const SizedBox(width: 16),
                Expanded(child: detail),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 220, child: list),
                const SizedBox(height: 12),
                Expanded(child: detail),
              ],
            ),
    );
  }

  Widget _detail(ProfitCompanyResult c) => ListView(
    key: PageStorageKey('detail:${c.entity.key}'),
    children: [
      _card([
        _heading(c.displayName),
        _text('${c.entity.source} · ${c.decision}', warning: !c.complete),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _metric('Compra', _money(c.purchases)),
            _metric('Valor recuperable estimado', _money(c.value)),
            _metric('Costos asignados', _money(c.operatingCosts)),
            _metric('Contribución revisada', _money(c.contribution)),
            _metric('Estructura asignada', _money(c.overhead)),
            _metric('Resultado revisado', _money(c.result)),
          ],
        ),
        const SizedBox(height: 12),
        _text(
          '${_qty(c.kg)} kg físicos · ${_qty(c.payableKg)} kg pagables · ${c.services} servicios completados',
        ),
        if (c.attributedKm != null)
          _text(
            '${_qty(c.attributedKm!)} km registrados en días con una sola empresa por unidad; asociación temporal.',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _action('Revisar cobertura', () => _review(c)),
            _action(
              'Simular salida',
              () => _scenario(c),
              icon: Icons.calculate_outlined,
            ),
          ],
        ),
        if (_scenarios[c.entity.key] case final scenario?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _text(
              'Escenario de ${_period.days} días: cambio en resultado al salir ${_money(scenario.improvement)}. Positivo mejora; negativo empeora. Supuestos manuales, sin guardar.',
            ),
          ),
      ]),
      if (c.issues.isNotEmpty)
        _card([
          _heading('Pendientes para concluir'),
          for (final issue in c.issues.toSet())
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _text('• $issue', warning: true),
            ),
        ]),
      for (final m in c.materials)
        _card([
          _heading(m.material),
          _text(
            '${m.purchases.length} tickets · ${_qty(m.physicalKg)} kg físicos · ${_qty(m.payableKg)} kg pagables${m.pieces > 0 ? ' · ${_qty(m.pieces)} piezas separadas de los kg' : ''}',
          ),
          _text(
            'Compra ponderada: ${_price(m.purchasePrice)}/kg pagable · Compra: ${_money(m.purchaseAmount)}',
          ),
          _text('Valor recuperable: ${_money(m.value)}'),
          if (m.recipe != null) ...[
            for (final output in m.recipe!.outputs)
              _text(
                '${_qty(output.yieldFraction * 100)}% × ${ProfitMaterialBasis(_analysis!.sources, profitMaterialFamily).outputPrice(_analysis!.benchmarks, output.benchmark, unit: m.purchases.first.unit).description}',
              ),
            _text('Fundamento: ${m.recipe!.note}'),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: _action('Definir salidas y rendimiento', () => _recipe(m)),
          ),
          ExpansionTile(
            title: const Text('Tickets de origen'),
            children: [
              for (final p in m.purchases)
                ListTile(
                  title: Text('${p.reference} · ${profitDateText(p.date)}'),
                  subtitle: Text(
                    '${p.source} · ${_qty(p.quantity)} ${profitUnitLabel(p.unit)} · ${_money(p.amount)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Excluir del análisis',
                    onPressed: _enabled ? () => _exclude(p) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ),
            ],
          ),
        ]),
      _card([
        _heading('Costos reconocidos'),
        for (final kind in ProfitCostKind.values)
          _text(
            '${kind.label}: ${c.costs.containsKey(kind) ? _money(c.costs[kind]) : 'Sin asignar / requiere revisión'}',
          ),
        for (final id in c.costIds.toSet())
          ListTile(
            title: Text(
              _analysis!.costFacts.firstWhere((f) => f.key == id).label,
            ),
            subtitle: Text(
              '${_analysis!.review.costs[id]!.estimated ? 'Estimado · ' : ''}${_analysis!.review.costs[id]!.note}',
            ),
            onTap: _enabled
                ? () =>
                      _cost(_analysis!.costFacts.firstWhere((f) => f.key == id))
                : null,
          ),
      ]),
    ],
  );
  Widget _metric(String label, String value) => SizedBox(
    width: 195,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(label),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kDirectionSurfaceText,
          ),
        ),
      ],
    ),
  );
  Widget _costs() {
    final a = _analysis!,
        facts = _analysis!.costFacts
            .where(
              (f) =>
                  !_onlyPending || _analysis!.pendingCosts.containsKey(f.key),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          '${a.pendingCosts.length} documentos pendientes · ${_money(a.assignedCosts)} asignados. Los importes de documentos pueden superponerse; no son gastos sumables.',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar solo pendientes'),
          value: _onlyPending,
          onChanged: (v) => setState(() => _onlyPending = v ?? true),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: facts.length,
            itemBuilder: (context, i) {
              final f = facts[i], rule = a.review.costs[facts[i].key];
              return _card([
                _heading(f.label),
                _text(
                  '${profitDateText(f.date)} · ${f.source} · Documento ${_money(f.amount)}',
                ),
                if (f.vehicleId.isNotEmpty) _text('Unidad: ${f.vehicleId}'),
                _text(
                  a.pendingCosts[f.key] ??
                      '${rule?.treatment.label} · ${rule?.kind.label}',
                  warning: a.pendingCosts.containsKey(f.key),
                ),
                if (rule != null) _text(rule.note),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _action('Conciliar y asignar', () => _cost(f)),
                ),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _identities() {
    final a = _analysis!, labels = _entityOptions;
    return ListView(
      children: [
        _card([
          _heading('Misma empresa, misma planta'),
          _text(
            'Los IDs de cada módulo se conservan. Solo se unen por un vínculo explícito de Menudeo a Operación o por una equivalencia confirmada. Los homónimos permanecen separados.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _action(
                  'Maestro con vigencia',
                  () => _redraw(() => _executiveTab = 3),
                ),
                _action('Equivalencia solo de este corte', _identity),
              ],
            ),
          ),
        ]),
        for (final rule in a.master.rules.where(
          (r) => r.kind == ProfitParameterKind.identity,
        ))
          _card([
            _text(
              '${_parameterLabel(rule)} · ${profitDateText(rule.from)} → ${rule.to == null ? 'sin fin' : profitDateText(rule.to!)}',
            ),
            _text(rule.note),
            Align(
              alignment: Alignment.centerLeft,
              child: _action(
                'Corregir maestro',
                () => _editParameter(rule.kind, old: rule),
              ),
            ),
          ]),
        for (final entry in a.review.identities.entries)
          _card([
            _text(
              '${labels[entry.key] ?? entry.key}\n→ ${labels[entry.value] ?? entry.value}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _action(
                'Quitar equivalencia',
                () => _guard(() async {
                  final next = {...a.review.identities}..remove(entry.key);
                  await _save(a.review.copyWith(identities: next));
                }),
              ),
            ),
          ]),
        for (final row
            in a.sources
                .rows('men_counterparties')
                .where((r) => profitText(r['site_id']).isNotEmpty))
          _card([
            _text(
              '${row['name']} · Menudeo → ${labels['site:${row['site_id']}'] ?? row['site_id']}',
            ),
            _text('Vínculo guardado en el catálogo de origen.'),
          ]),
        for (final entry in a.review.excludedPurchases.entries)
          _card([
            _text('Ticket excluido: ${entry.key} · ${entry.value['note']}'),
            Align(
              alignment: Alignment.centerLeft,
              child: _action(
                'Restaurar ticket',
                () => _guard(() async {
                  final next = {...a.review.excludedPurchases}
                    ..remove(entry.key);
                  await _save(a.review.copyWith(excludedPurchases: next));
                }),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _sources() {
    final a = _analysis!;
    final diesel = a.sources.rows('logistics_diesel_consumption'),
        gasoline = a.sources.rows('logistics_gasoline_control');
    return ListView(
      children: [
        _card([
          _heading('Cobertura del corte'),
          _text(
            'Consulta: ${a.sources.readAt} · reglas revisión ${a.review.revision}',
          ),
          _text(
            '${a.reportCompanies.where((c) => c.complete).length} de ${a.reportCompanies.length} empresas con revisión completa. ${a.excludedSales} ventas no elegibles para promedio; ${a.excludedPurchases} compras excluidas.',
          ),
          _text(
            'Consultas paginadas de registros visibles para esta sesión. El cierre requiere confirmar cobertura y base de impuestos. Un corte guardado conserva lo consultado; no bloquea cambios en los módulos originales.',
          ),
          for (final issue in a.issues) _text('• $issue', warning: true),
        ]),
        _card([
          _heading('Combustible registrado'),
          _text(
            'Diésel: ${diesel.length} registros · ${_qty(diesel.fold<double>(0, (s, r) => s + (profitNumber(r['liters_requested']) ?? 0)))} litros solicitados. Gasolina: ${gasoline.length} registros · ${_qty(gasoline.fold<double>(0, (s, r) => s + (profitNumber(r['liters_loaded']) ?? 0)))} litros cargados.',
          ),
          _text(
            'Una carga no equivale al consumo de los viajes del día. El costo monetario se concilia desde sus comprobantes y se reparte con evidencia.',
          ),
          ExpansionTile(
            title: const Text('Detalle por fecha y unidad'),
            children: [
              for (final r
                  in [...diesel, ...gasoline]..sort(
                    (a, b) => profitText(
                      b['entry_date'],
                    ).compareTo(profitText(a['entry_date'])),
                  ))
                ListTile(
                  title: Text('${r['entry_date']} · unidad ${r['vehicle_id']}'),
                  subtitle: Text(
                    '${r['liters_requested'] ?? r['liters_loaded']} litros · ${r['load_origin']}',
                  ),
                ),
            ],
          ),
        ]),
        _card([
          _heading('Precios de venta por material y unidad'),
          for (final b in a.benchmarks.values)
            ListTile(
              title: Text('${b.material} · ${b.source}'),
              subtitle: Text(
                '${b.count} ventas · ${_qty(b.quantity)} ${profitUnitLabel(b.unit)} · ${_money(b.amount)} / ${_qty(b.quantity)} = ${_price(b.price)}/${profitUnitLabel(b.unit)}',
              ),
            ),
        ]),
        _card([
          _heading('Registros consultados'),
          for (final entry in a.sources.counts.entries)
            _text('${entry.key}: ${entry.value}'),
        ]),
      ],
    );
  }
}
