part of '../human_resources_terminations_page.dart';

/// The editor owns its controllers. Recalculation never replaces typed text.
class HrTerminationEditor extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Map<String, List<Map<String, dynamic>>> antecedents;
  final String? antecedentsError;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) onSave;
  final Future<List<Map<String, dynamic>>> Function() onHistory;
  final ValueChanged<bool> onDirty;
  final ValueChanged<bool>? onBusy;
  final Map<String, dynamic>? initialInputs;
  const HrTerminationEditor({
    super.key,
    required this.employee,
    required this.antecedents,
    this.antecedentsError,
    required this.onSave,
    required this.onHistory,
    required this.onDirty,
    this.onBusy,
    this.initialInputs,
  });
  @override
  State<HrTerminationEditor> createState() => _TerminationEditorState();
}

class _TerminationEditorState extends State<HrTerminationEditor> {
  final _controllers = <String, TextEditingController>{};
  final _scroll = ScrollController();
  HrTerminationMode _mode = HrTerminationMode.finiquito;
  bool _inclusive = false,
      _historyReviewed = false,
      _separationReviewed = false;
  bool _busy = false;
  bool _editorDirty = false;
  int _tab = 0;
  String? _savedFingerprint, _sourceId;
  Map<String, dynamic>? _saved;
  static const _muted = Color(0xFFC79CFF);
  static const _white = TextStyle(color: Colors.white);

  static String _iso(DateTime date) => date.toIso8601String().split('T').first;
  static String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    return date == null
        ? 'Seleccionar fecha'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _money(num? amount) => hrTerminationCurrency(amount);
  TextEditingController _c(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController());
  double _n(String key) => double.tryParse(_c(key).text) ?? 0;

  @override
  void initState() {
    super.initState();
    _replace(widget.initialInputs ?? _defaults(widget.employee));
  }

  @override
  void didUpdateWidget(covariant HrTerminationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee['id'] != widget.employee['id']) {
      _replace(_defaults(widget.employee));
      _saved = null;
      _savedFingerprint = null;
      _sourceId = null;
      _editorDirty = false;
      _tab = 0;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> _defaults(Map<String, dynamic> employee) {
    final end = hrTerminationDate(
      DateTime.tryParse('${employee['termination_date']}') ?? DateTime.now(),
    );
    final start = DateTime.tryParse('${employee['fecha_ingreso']}');
    final salary = HrEmployeeCompensation.fromRow(employee);
    final anniversary = start == null
        ? null
        : hrTerminationLastAnniversary(start, end);
    final years = start == null || start.isAfter(end)
        ? 1
        : hrTerminationServiceYears(start, end).floor() + 1;
    final vacationDays = years <= 1
        ? 12
        : years <= 5
        ? 10 + years * 2
        : 22 + ((years - 6) ~/ 5) * 2;
    final jan = DateTime.utc(end.year);
    return {
      'mode': 'finiquito',
      'start_date': start == null ? '' : _iso(start),
      'end_date': _iso(end),
      'aguinaldo_start': _iso(
        start != null && start.isAfter(jan) ? start : jan,
      ),
      'vacation_start': anniversary == null ? '' : _iso(anniversary),
      'weekly_base': salary.base,
      'weekly_flow': salary.flow,
      'aguinaldo_days': 15,
      'vacation_days': vacationDays,
      'premium_percent': 25,
      'unpaid_days': 0,
      'prior_vacation_days': 0,
      'minimum_daily': end.year == 2026
          ? 315.04
          : end.year == 2025
          ? 278.80
          : '',
      'official_isr': '',
      'imss': 0,
      'other_fiscal_deductions': 0,
      'flow_deductions': 0,
      'reason': employee['termination_reason'] ?? '',
      for (final prefix in [
        'savings',
        'commissions',
        'night_bonus',
        'attendance_bonus',
        'paid_aguinaldo',
        'paid_vacation',
        'paid_premium',
      ])
        for (final channel in ['base', 'flow']) '${prefix}_$channel': 0,
    };
  }

  void _replace(Map<String, dynamic> values) {
    for (final c in _controllers.values) {
      c.text = '';
    }
    final complete = {
      ..._defaults(widget.employee),
      for (final key in [
        'salary_reference',
        'isr_reference',
        'integration_reference',
        'integrated_daily_base',
        'integrated_daily_total',
        'prior_payment_reference',
        'deductions_reference',
        'notes',
      ])
        key: '',
      ...values,
    };
    for (final entry in complete.entries) {
      if (entry.value is! bool) _c(entry.key).text = '${entry.value ?? ''}';
    }
    _mode = HrTerminationMode.values.firstWhere(
      (m) => m.name == values['mode'],
      orElse: () => HrTerminationMode.finiquito,
    );
    _inclusive = values['inclusive_dates'] == true;
    _historyReviewed = values['history_reviewed'] == true;
    _separationReviewed = values['separation_reviewed'] == true;
  }

  Map<String, dynamic> get _values => {
    for (final e in _controllers.entries) e.key: e.value.text.trim(),
    'salary_changed_from_personal':
        _n('weekly_base') !=
            HrEmployeeCompensation.fromRow(widget.employee).base ||
        _n('weekly_flow') !=
            HrEmployeeCompensation.fromRow(widget.employee).flow,
    'mode': _mode.name,
    'inclusive_dates': _inclusive,
    'history_reviewed': _historyReviewed,
    'separation_reviewed': _separationReviewed,
  };
  void _changed() {
    _editorDirty = true;
    setState(() {});
    widget.onDirty(true);
  }

  Future<void> _date(String key) async {
    final initial = DateTime.tryParse(_c(key).text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB68CFF),
            surface: Color(0xFF25163A),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    _c(key).text = _iso(selected);
    _changed();
  }

  Widget _field(
    String key,
    String label, {
    bool numeric = true,
    double width = 240,
    String? hint,
  }) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          key: ValueKey('termination_$key'),
          controller: _c(key),
          enabled: !_busy,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: _white,
          decoration: contractGlassFieldDecoration(context, hintText: hint),
          onChanged: (_) => _changed(),
        ),
      ],
    ),
  );
  Widget _dateField(String key, String label) => SizedBox(
    width: 240,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _date(key),
          icon: const Icon(Icons.calendar_month),
          label: Text(_dateLabel(_c(key).text)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(240, 48),
          ),
        ),
      ],
    ),
  );
  Widget _section(String title, List<Widget> children, {String? description}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ContractGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    description,
                    style: const TextStyle(color: _muted),
                  ),
                ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 18, runSpacing: 16, children: children);
  Widget _check(
    String title,
    bool value,
    ValueChanged<bool> changed, {
    bool enabled = true,
  }) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: _white),
    value: value,
    controlAffinity: ListTileControlAffinity.leading,
    onChanged: !enabled || _busy
        ? null
        : (v) {
            changed(v ?? false);
            _changed();
          },
  );
  Widget _splitFields(String prefix, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _wrap([
      SizedBox(
        width: 270,
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(label, style: _white),
        ),
      ),
      _field('${prefix}_base', 'Base / Fiscal', width: 210),
      _field('${prefix}_flow', 'Flujo', width: 210),
    ]),
  );

  List<Widget> _data() => [
    _section(
      'Relación laboral',
      [
        _wrap([
          _dateField('start_date', 'Fecha de ingreso'),
          _dateField('end_date', 'Último día de trabajo'),
          _field('reason', 'Causa de separación', numeric: false, width: 360),
        ]),
        const SizedBox(height: 16),
        Text('Antigüedad: ${_serviceLabel()}', style: _white),
      ],
      description:
          'Las fechas y salarios se toman de Personal. Confirma los valores que aplicaban a la fecha de separación.',
    ),
    _section('Salario semanal', [
      _wrap([
        _field('weekly_base', 'Base'),
        _field('weekly_flow', 'Flujo'),
        SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total · Base + Flujo',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              Text(
                _money(_n('weekly_base') + _n('weekly_flow')),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text(
        'Diario Base ${_money(_n('weekly_base') / 7)} · Flujo ${_money(_n('weekly_flow') / 7)} · Total ${_money((_n('weekly_base') + _n('weekly_flow')) / 7)}',
        style: const TextStyle(color: _muted),
      ),
      const SizedBox(height: 14),
      _field(
        'salary_reference',
        'Referencia o motivo del salario usado',
        numeric: false,
        width: 700,
      ),
    ]),
    _section('Periodos y prestaciones', [
      _wrap([
        _dateField('aguinaldo_start', 'Devengo de aguinaldo desde'),
        _dateField('vacation_start', 'Devengo de vacaciones desde'),
        _field('aguinaldo_days', 'Días de aguinaldo al año'),
        _field('vacation_days', 'Días de vacaciones al año'),
        _field('premium_percent', 'Prima vacacional (%)'),
        _field('unpaid_days', 'Días de sueldo pendientes'),
        _field('prior_vacation_days', 'Vacaciones anteriores sin pagar'),
      ]),
      _check(
        'Incluir ambos extremos del periodo de devengo',
        _inclusive,
        (v) => _inclusive = v,
      ),
      const Text(
        'El Excel usa fecha final menos fecha inicial, con divisor 365. Los días anteriores sólo incluyen derechos que aún no se han pagado.',
        style: TextStyle(color: _muted),
      ),
    ]),
    if (_mode != HrTerminationMode.finiquito)
      _section('Liquidación · 12 días por año', [
        _wrap([_field('minimum_daily', 'Salario mínimo diario aplicable')]),
        const SizedBox(height: 12),
        const Text(
          'Prima de antigüedad: 12 días por año y proporción. Se aplica el tope de dos salarios mínimos al salario diario; confirma zona, fecha y procedencia.',
          style: TextStyle(color: _muted),
        ),
      ]),
    if (_mode == HrTerminationMode.indemnizacion)
      _section(
        'Indemnización · 90 días',
        [
          _wrap([
            _field('integrated_daily_base', 'Integrado laboral diario Base'),
            _field('integrated_daily_total', 'Integrado laboral diario Total'),
            _field(
              'integration_reference',
              'Referencia de la integración',
              numeric: false,
              width: 420,
            ),
          ]),
        ],
        description:
            'Confirma el salario integrado laboral para indemnización. El SDI informativo de la plantilla no sustituye esta base.',
      ),
    if (_mode != HrTerminationMode.finiquito)
      _check(
        'RH confirmó la procedencia, antigüedad y bases de esta modalidad',
        _separationReviewed,
        (v) => _separationReviewed = v,
      ),
  ];
  String _serviceLabel() {
    try {
      return '${HrTerminationInput(_values).serviceYears.toStringAsFixed(4)} años';
    } catch (_) {
      return 'Pendiente de fechas';
    }
  }

  List<Widget> _adjustments() => [
    _section('Saldos adicionales por pagar', [
      _splitFields('savings', 'Fondo de ahorro'),
      _splitFields('commissions', 'Comisiones'),
      _splitFields('night_bonus', 'Bono nocturno'),
      _splitFields('attendance_bonus', 'Asistencia y puntualidad'),
    ]),
    _section(
      'Pagos previos del mismo devengo',
      [
        _splitFields('paid_aguinaldo', 'Aguinaldo ya pagado'),
        _splitFields('paid_vacation', 'Vacaciones ya pagadas'),
        _splitFields('paid_premium', 'Prima vacacional ya pagada'),
        _field(
          'prior_payment_reference',
          'Recibos y periodos de los pagos previos',
          numeric: false,
          width: 700,
        ),
      ],
      description:
          'Estos importes se restan una sola vez de su prestación. Confirma en Antecedentes el devengo al que pertenece cada pago.',
    ),
    _section(
      'Deducciones confirmadas',
      [
        _wrap([
          _field(
            'official_isr',
            'ISR oficial CONTPAQ',
            hint: 'Capturar; cero si corresponde',
          ),
          _field(
            'isr_reference',
            'Referencia CONTPAQ del finiquito',
            numeric: false,
            width: 460,
          ),
          _field('imss', 'IMSS'),
          _field('other_fiscal_deductions', 'Otras deducciones fiscales'),
          _field('flow_deductions', 'Deducciones en Flujo'),
        ]),
        const SizedBox(height: 14),
        _field(
          'deductions_reference',
          'Conceptos y referencias de deducciones',
          numeric: false,
          width: 700,
        ),
      ],
      description:
          'Captura el ISR de este finiquito emitido por CONTPAQ. El flujo salarial no aumenta para compensar retenciones.',
    ),
    _section('Notas de RH', [
      _field('notes', 'Observaciones del cálculo', numeric: false, width: 700),
    ]),
  ];
  List<Widget> _historySource() => [
    if (widget.antecedentsError != null)
      Text(
        widget.antecedentsError!,
        style: const TextStyle(color: Colors.orangeAccent),
      ),
    if (widget.antecedents.isEmpty && widget.antecedentsError == null)
      const LinearProgressIndicator(),
    _section('Vacaciones · eventos del colaborador', [
      for (final e in widget.antecedents['events'] ?? <Map<String, dynamic>>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${e['event_type']} · ${_dateLabel('${e['start_date']}')} a ${_dateLabel('${e['end_date']}')} · ${e['days_applied']} días · ${e['status']}',
            style: _white,
          ),
        ),
      if ((widget.antecedents['events'] ?? []).isEmpty)
        const Text('Sin eventos cargados.', style: TextStyle(color: _muted)),
    ]),
    _section(
      'Pagos de vacaciones y prima',
      [
        for (final p
            in widget.antecedents['vacation_payments'] ??
                <Map<String, dynamic>>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(
              '${p['days_paid']} días · Vacaciones ${_money(_value(p['vacation_pay']))} · Prima ${_money(_value(p['vacation_bonus_pay']))}\nFiscal ${_money(_value(p['transfer_component']))} · Flujo ${_money(_value(p['cash_component']))} · ${p['status']}${p['is_final'] == true ? ' · final' : ''}\n${_paymentPeriod(p)}',
              style: _white,
            ),
          ),
        if ((widget.antecedents['vacation_payments'] ?? []).isEmpty)
          const Text('Sin cálculos cargados.', style: TextStyle(color: _muted)),
      ],
      description:
          'Incluye versiones de referencia; sólo descuenta pagos comprobados del mismo devengo, una vez.',
    ),
    _section('Prenóminas registradas · referencia fiscal', [
      for (final p
          in widget.antecedents['payrolls'] ?? <Map<String, dynamic>>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${p['period_label']} · ${p['draft_status']} · ${_money(_value(p['fiscal_net_amount']))}',
            style: _white,
          ),
        ),
      if ((widget.antecedents['payrolls'] ?? []).isEmpty)
        const Text('Sin prenóminas cargadas.', style: TextStyle(color: _muted)),
    ]),
    _check(
      'Revisé nóminas, saldos y pagos previos; capturé los que corresponden a este devengo',
      _historyReviewed,
      (v) => _historyReviewed = v,
      enabled: widget.antecedents.isNotEmpty && widget.antecedentsError == null,
    ),
  ];
  String _paymentPeriod(Map<String, dynamic> payment) {
    final events = widget.antecedents['events'] ?? [];
    final linked = events
        .where((e) => e['id'] == payment['vacation_event_id'])
        .firstOrNull;
    return 'Ejercicio ${payment['exercise_year'] ?? '-'} · ${linked == null ? 'Evento no disponible' : '${_dateLabel('${linked['start_date']}')} a ${_dateLabel('${linked['end_date']}')} · ${linked['attendance_period_label']}'}';
  }

  double _value(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  Widget _amountRow(
    String label,
    HrTerminationSplit amount, {
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        for (final v in [amount.base, amount.flow, amount.total])
          Expanded(
            flex: 2,
            child: Text(
              _money(v),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ],
    ),
  );
  List<Widget> _result(HrTerminationResult? result, String? error) => [
    if (error != null)
      _section('Completa los datos', [Text(error, style: _white)]),
    if (result != null)
      _section('Desglose del cálculo', [
        Row(
          children: [
            const Expanded(
              flex: 4,
              child: Text('Concepto', style: TextStyle(color: _muted)),
            ),
            for (final label in ['Base / Fiscal', 'Flujo', 'Total'])
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _muted),
                ),
              ),
          ],
        ),
        for (final l in result.lines.where((l) => !l.deduction))
          _amountRow(l.label, l.amount),
        const Divider(),
        _amountRow('Bruto', result.gross, bold: true),
        for (final l in result.lines.where((l) => l.deduction))
          _amountRow(l.label, l.amount),
        const Divider(),
        _amountRow('Total deducciones', result.deductions, bold: true),
        if (result.net != null) _amountRow('Neto', result.net!, bold: true),
        if (result.net == null)
          const Text(
            'Neto pendiente de ISR oficial.',
            style: TextStyle(color: Colors.orangeAccent),
          ),
      ]),
    if (result != null && result.pending.isNotEmpty)
      _section('Pendientes para revisión', [
        for (final p in result.pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• $p', style: _white),
          ),
      ]),
    if (result != null)
      _section('Fórmulas utilizadas', [
        for (final l in result.lines.where((l) => !l.deduction))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${l.label}\n${l.formula}',
              style: const TextStyle(color: _muted),
            ),
          ),
      ]),
  ];

  Map<String, dynamic> _record(String status) {
    final input = HrTerminationInput(_values);
    final result = HrTerminationResult.calculate(input);
    if (status == 'revisado' && !result.canReview) {
      throw const FormatException(
        'Completa los pendientes antes de marcar como revisado.',
      );
    }
    return {
      'employee_id': widget.employee['id'],
      'employee_name': widget.employee['nombre'],
      'empresa': widget.employee['empresa'] ?? '',
      'mode': _mode.name,
      'status': status,
      'start_date': input.text('start_date'),
      'end_date': input.text('end_date'),
      'formula_version': HrTerminationInput.version,
      'inputs': input.toJson(),
      'result': result.toJson(),
      'source_snapshot': {
        'personal': widget.employee,
        'antecedents': widget.antecedents,
        'antecedents_error': widget.antecedentsError,
        'copied_from': _sourceId,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _setBusy(bool value) {
    setState(() => _busy = value);
    widget.onBusy?.call(value);
  }

  Future<void> _save(String status) async {
    try {
      final fingerprint = jsonEncode(_values);
      final record = _record(status);
      _setBusy(true);
      final saved = await widget.onSave(record);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _savedFingerprint = fingerprint;
      });
      _editorDirty = false;
      widget.onDirty(false);
      _message(
        'Versión ${saved['revision'] ?? ''} guardada · ${status == 'revisado' ? 'Revisado' : 'Borrador'}',
      );
    } catch (e) {
      _message('No se guardó el cálculo: $e');
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _export([Map<String, dynamic>? snapshot]) async {
    try {
      final record =
          snapshot ??
          (_savedFingerprint == jsonEncode(_values) && _saved != null
              ? _saved!
              : _record('borrador'));
      final bytes = await buildHrTerminationPdf(
        record,
        generatedAt: DateTime.now(),
      );
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName:
            'finiquito_${record['employee_id']}_${record['end_date']}.pdf',
      );
      if (path != null) _message('PDF guardado.');
    } catch (e) {
      _message('No se pudo exportar: $e');
    }
  }

  Future<void> _history() async {
    _setBusy(true);
    try {
      final history = await widget.onHistory();
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AreaThemeScope(
          tokens: humanResourcesAreaTokens,
          child: ContractDialogShell(
            child: SizedBox(
              width: 860,
              height: 540,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Versiones guardadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Cada versión conserva los datos y resultados usados en ese momento.',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: history.isEmpty
                          ? const Center(
                              child: Text(
                                'Aún no hay versiones guardadas.',
                                style: _white,
                              ),
                            )
                          : ListView(
                              children: [
                                for (final record in history)
                                  ListTile(
                                    title: Text(
                                      'Versión ${record['revision']} · ${record['mode']} · ${record['status']}',
                                      style: _white,
                                    ),
                                    subtitle: Text(
                                      '${record['end_date']} · Guardado ${record['created_at']}',
                                      style: const TextStyle(color: _muted),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, record),
                                          child: const Text('Abrir copia'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _export(record),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                          ),
                                          label: const Text('PDF'),
                                        ),
                                      ],
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
        ),
      );
      if (selected != null && mounted) {
        bool discard = !_editorDirty;
        if (!discard) {
          discard =
              await showDialog<bool>(
                context: context,
                builder: (context) => AreaThemeScope(
                  tokens: humanResourcesAreaTokens,
                  child: ContractDialogShell(
                    child: SizedBox(
                      width: 450,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '¿Reemplazar los cambios actuales con una copia de esta versión?',
                              style: _white,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Abrir copia'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ) ??
              false;
        }
        if (discard &&
            mounted &&
            selected['employee_id'] == widget.employee['id']) {
          setState(() {
            _replace(Map<String, dynamic>.from(selected['inputs'] as Map));
            _historyReviewed = false;
            _separationReviewed = false;
            _sourceId = selected['id']?.toString();
            _saved = null;
            _savedFingerprint = null;
            _tab = 0;
          });
          _changed();
        }
      }
    } catch (e) {
      _message('No se pudo consultar el historial: $e');
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    HrTerminationResult? result;
    String? error;
    try {
      result = HrTerminationResult.calculate(HrTerminationInput(_values));
    } on FormatException catch (e) {
      error = e.message;
    }
    final net = result?.net;
    final tabs = [
      'Datos',
      'Prestaciones y ajustes',
      'Antecedentes',
      'Resultado',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.employee['nombre']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID ${widget.employee['id']} · ${widget.employee['empresa']} · Fiscal: ${widget.employee['fiscal_payment_mode'] == 'cheque' ? 'cheque' : 'depósito'}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<HrTerminationMode>(
                    value: _mode,
                    dropdownColor: const Color(0xFF34204E),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    items: [
                      for (final mode in HrTerminationMode.values)
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                    ],
                    onChanged: _busy
                        ? null
                        : (m) {
                            _mode = m!;
                            _separationReviewed = false;
                            _changed();
                          },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final pair in [
                    ('Fiscal', net?.base),
                    ('Flujo', net?.flow),
                    ('Total', net?.total),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B114F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF704D97)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pair.$1,
                              style: const TextStyle(
                                color: _muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _money(pair.$2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 27,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(switch (_mode) {
                HrTerminationMode.finiquito =>
                  'Proporcionales y saldos pendientes.',
                HrTerminationMode.liquidacion =>
                  'Finiquito + 12 días por año de servicio.',
                HrTerminationMode.indemnizacion =>
                  'Finiquito + 12 días por año + 90 días de indemnización.',
              }, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var i = 0; i < tabs.length; i++)
              ChoiceChip(
                label: Text(tabs[i]),
                selectedColor: humanResourcesAreaTokens.primaryStrong,
                backgroundColor: humanResourcesAreaTokens.badgeBackground,
                labelStyle: const TextStyle(color: Colors.white),
                selected: _tab == i,
                onSelected: (_) {
                  setState(() => _tab = i);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(right: 8),
            children: switch (_tab) {
              0 => _data(),
              1 => _adjustments(),
              2 => _historySource(),
              _ => _result(result, error),
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (_busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _history,
              icon: const Icon(Icons.history),
              label: const Text('Historial'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || result == null ? null : () => _export(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exportar cálculo'),
            ),
            OutlinedButton(
              onPressed: _busy || result == null
                  ? null
                  : () => _save('borrador'),
              child: const Text('Guardar borrador'),
            ),
            FilledButton(
              onPressed: _busy || result?.canReview != true
                  ? null
                  : () => _save('revisado'),
              style: FilledButton.styleFrom(
                backgroundColor: humanResourcesAreaTokens.accent,
                foregroundColor: humanResourcesAreaTokens.primaryStrong,
              ),
              child: const Text('Guardar revisado'),
            ),
          ],
        ),
      ],
    );
  }
}
