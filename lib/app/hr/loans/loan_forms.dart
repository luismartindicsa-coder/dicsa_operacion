part of '../human_resources_loans_page.dart';

class _HrLoanCreateDialog extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final int availableCents;
  final Future<String> Function(Map<String, dynamic>) onSave;
  const _HrLoanCreateDialog({
    required this.employees,
    required this.availableCents,
    required this.onSave,
  });
  @override
  State<_HrLoanCreateDialog> createState() => _HrLoanCreateDialogState();
}

class _HrLoanCreateDialogState extends State<_HrLoanCreateDialog> {
  final _amount = TextEditingController(),
      _installment = TextEditingController(),
      _terms = TextEditingController(text: '4'),
      _notes = TextEditingController();
  final _requestId = _loanRequestId();
  Map<String, dynamic>? _employee;
  String _method = 'nomina', _frequency = 'semanal';
  String _channel = 'flujo';
  late DateTime _issued = DateUtils.dateOnly(DateTime.now());
  late DateTime _first = _issued.add(const Duration(days: 7));
  bool _busy = false;
  String? _error;
  void _updateSchedule(String _) {
    final cents = _loanInputCents(_amount.text);
    final fixed = _loanInputCents(_installment.text);
    if (cents != null && fixed != null && fixed > 0) {
      _terms.text = '${(cents + fixed - 1) ~/ fixed}';
    }
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _amount.dispose();
    _installment.dispose();
    _terms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseEmployee() async {
    final id = await showSearchablePickerDialog<String>(
      context,
      title: 'Buscar colaborador',
      initialValue: _employee?['id'].toString(),
      options: [
        for (final employee in widget.employees)
          SearchablePickerOption(
            value: '${employee['id']}',
            label:
                '${employee['nombre']} · ID #${employee['id']} · ${employee['empresa']}',
          ),
      ],
    );
    if (id != null && mounted) {
      setState(
        () =>
            _employee = widget.employees.firstWhere((e) => '${e['id']}' == id),
      );
    }
  }

  Future<void> _date(bool first) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showContractDatePickerSurface(
      context,
      initialDate: first ? _first : _issued,
      firstDate: first ? _issued : DateTime(2020),
      lastDate: first ? DateTime(today.year + 5, 12, 31) : today,
      title: first ? 'Primer abono' : 'Fecha de entrega',
      tokens: humanResourcesAreaTokens,
    );
    if (picked != null && mounted) {
      setState(() {
        if (first) {
          _first = picked;
        } else {
          _issued = picked;
          if (_first.isBefore(picked)) _first = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final cents = _loanInputCents(_amount.text);
    final fixed = _loanInputCents(_installment.text);
    final terms = _installment.text.trim().isEmpty
        ? int.tryParse(_terms.text)
        : cents != null && fixed != null && fixed > 0
        ? (cents + fixed - 1) ~/ fixed
        : null;
    if (_employee == null ||
        cents == null ||
        cents <= 0 ||
        cents > widget.availableCents ||
        terms == null ||
        terms < 1 ||
        terms > 260 ||
        terms > cents ||
        (fixed != null && fixed > cents) ||
        _first.isBefore(_issued)) {
      setState(
        () => _error =
            'Selecciona al colaborador, un importe dentro del fondo y de 1 a 260 cuotas. Cada cuota debe ser de al menos un centavo.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.onSave({
        'p_request_id': _requestId,
        'p_employee_id': '${_employee!['id']}',
        'p_principal': cents / 100,
        'p_installment_count': terms,
        'p_repayment_method': _method,
        'p_frequency': _frequency,
        'p_issued_on': hrLoanDate(_issued),
        'p_first_due_on': hrLoanDate(_first),
        'p_notes': _notes.text.trim(),
        'p_payroll_channel': _method == 'nomina' ? _channel : 'flujo',
        if (fixed != null) 'p_installment_amount': fixed / 100,
      });
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _loanError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cents = _loanInputCents(_amount.text) ?? 0;
    final fixed = _loanInputCents(_installment.text);
    final terms = _installment.text.trim().isEmpty
        ? int.tryParse(_terms.text) ?? 0
        : fixed != null && fixed > 0
        ? (cents + fixed - 1) ~/ fixed
        : 0;
    final regular = fixed ?? (terms > 0 ? cents ~/ terms : 0);
    return _LoanFormShell(
      title: 'Nuevo préstamo',
      busy: _busy,
      error: _error,
      submitLabel: 'Registrar entrega',
      onSubmit: _save,
      children: [
        Text(
          'Disponible: ${_loanMoney(widget.availableCents)} · Sin intereses',
          style: _loanText(15, strong: true),
        ),
        Text(
          'Registra una entrega realizada. Su importe se resta del fondo.',
          style: _loanText(12, muted: true),
        ),
        OutlinedButton.icon(
          style: contractSecondaryButtonStyle(context),
          onPressed: _busy ? null : _chooseEmployee,
          icon: const Icon(Icons.person_search_outlined),
          label: Text(
            _employee == null
                ? 'Seleccionar colaborador'
                : '${_employee!['nombre']}',
            maxLines: 2,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _loanField(
                _amount,
                'Importe del préstamo',
                money: true,
                enabled: !_busy,
                onChanged: _updateSchedule,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _loanField(
                _terms,
                'Número de cuotas',
                integer: true,
                enabled: !_busy && _installment.text.trim().isEmpty,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
          ],
        ),
        _loanField(
          _installment,
          'Monto por abono (opcional)',
          money: true,
          enabled: !_busy,
          onChanged: _updateSchedule,
        ),
        Row(
          children: [
            Expanded(
              child: _loanDropdown(
                'Forma de pago',
                _method,
                const {'nomina': 'Descuento de nómina', 'efectivo': 'Efectivo'},
                _busy ? null : (v) => setState(() => _method = v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _loanDropdown(
                'Frecuencia',
                _frequency,
                const {
                  'semanal': 'Semanal',
                  'quincenal': 'Cada 14 días',
                  'mensual': 'Mensual',
                },
                _busy ? null : (v) => setState(() => _frequency = v),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _busy ? null : () => _date(false),
              icon: const Icon(Icons.event_outlined),
              label: Text('Entrega: ${hrLoanDate(_issued)}'),
            ),
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _busy ? null : () => _date(true),
              icon: const Icon(Icons.event_available_outlined),
              label: Text('Primer abono: ${hrLoanDate(_first)}'),
            ),
          ],
        ),
        if (_method == 'nomina')
          _loanChannelChoice(
            _channel,
            _busy ? null : (value) => setState(() => _channel = value),
          ),
        if (cents > 0 && terms > 0)
          Text(
            '$terms cuotas · Abono: ${_loanMoney(regular)} · Última cuota: ${_loanMoney(cents - regular * (terms - 1))}',
            style: _loanText(14, strong: true),
          ),
        if (_method == 'nomina')
          Text(
            _loanChannelExplanation(_channel),
            style: _loanText(12, muted: true),
          ),
        _loanField(
          _notes,
          'Observaciones / referencia de entrega',
          enabled: !_busy,
          maxLines: 2,
        ),
      ],
    );
  }
}

String _loanChannelExplanation(String channel) => channel == 'fiscal'
    ? 'RH debe incluir la cuota en CONTPAQ. Prenómina la mostrará como informativa y conservará el neto importado. El cierre confirmará el abono al fondo.'
    : 'La cuota se descuenta del flujo disponible en la app. Si no alcanza, RH puede cambiar el cobro a Fiscal después de ajustar CONTPAQ. El cierre confirmará el abono al fondo.';

Widget _loanChannelChoice(String value, ValueChanged<String>? onChanged) =>
    Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Descontar préstamo de', style: _loanText(13, muted: true)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? humanResourcesAreaTokens.primaryStrong
                    : humanResourcesAreaTokens.onGlass,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? humanResourcesAreaTokens.accent
                    : humanResourcesAreaTokens.fieldSurface,
              ),
            ),
            segments: const [
              ButtonSegment(
                value: 'flujo',
                label: Text('Flujo'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: 'fiscal',
                label: Text('Fiscal · CONTPAQ'),
                icon: Icon(Icons.receipt_long_outlined),
              ),
            ],
            selected: {value},
            onSelectionChanged: onChanged == null
                ? null
                : (selection) => onChanged(selection.single),
          ),
        ],
      ),
    );

class _HrLoanChannelDialog extends StatefulWidget {
  final HrLoan loan;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _HrLoanChannelDialog({required this.loan, required this.onSave});
  @override
  State<_HrLoanChannelDialog> createState() => _HrLoanChannelDialogState();
}

class _HrLoanChannelDialogState extends State<_HrLoanChannelDialog> {
  late String _channel = widget.loan.payrollChannel;
  final _notes = TextEditingController();
  final _requestId = _loanRequestId();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_channel == widget.loan.payrollChannel) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'p_request_id': _requestId,
        'p_loan_id': widget.loan.id,
        'p_expected_channel': widget.loan.payrollChannel,
        'p_channel': _channel,
        'p_notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _loanError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _LoanFormShell(
    title: 'Cobro de PR-${widget.loan.folio}',
    busy: _busy,
    error: _error,
    submitLabel: 'Guardar forma de cobro',
    onSubmit: _save,
    children: [
      Text(widget.loan.employeeName, style: _loanText(16, strong: true)),
      _loanChannelChoice(
        _channel,
        _busy ? null : (value) => setState(() => _channel = value),
      ),
      Text(
        _loanChannelExplanation(_channel),
        style: _loanText(13, muted: true),
      ),
      Text(
        'Se usará para los abonos pendientes. Actualiza y guarda los borradores de prenómina antes de cerrar.',
        style: _loanText(13, muted: true),
      ),
      _loanField(
        _notes,
        'Motivo / referencia de RH',
        enabled: !_busy,
        maxLines: 2,
      ),
    ],
  );
}

class _HrLoanCashDialog extends StatefulWidget {
  final HrLoan loan;
  final int balanceCents;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _HrLoanCashDialog({
    required this.loan,
    required this.balanceCents,
    required this.onSave,
  });
  @override
  State<_HrLoanCashDialog> createState() => _HrLoanCashDialogState();
}

class _HrLoanCashDialogState extends State<_HrLoanCashDialog> {
  final _amount = TextEditingController(), _notes = TextEditingController();
  final _requestId = _loanRequestId();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = _loanInputCents(_amount.text);
    if (cents == null || cents <= 0 || cents > widget.balanceCents) {
      setState(
        () => _error =
            'Captura un abono positivo que no supere el saldo pendiente.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'p_request_id': _requestId,
        'p_loan_id': widget.loan.id,
        'p_amount': cents / 100,
        'p_paid_on': hrLoanDate(_date),
        'p_notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _loanError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _LoanFormShell(
    title: 'Abono en efectivo',
    busy: _busy,
    error: _error,
    submitLabel: 'Registrar abono recibido',
    onSubmit: _save,
    children: [
      Text(
        'PR-${widget.loan.folio} · ${widget.loan.employeeName}',
        style: _loanText(16, strong: true),
      ),
      Text(
        'Saldo pendiente: ${_loanMoney(widget.balanceCents)}',
        style: _loanText(15, muted: true),
      ),
      _loanField(
        _amount,
        'Importe recibido',
        money: true,
        enabled: !_busy,
        autofocus: true,
      ),
      OutlinedButton.icon(
        style: contractSecondaryButtonStyle(context),
        onPressed: _busy
            ? null
            : () async {
                final picked = await showContractDatePickerSurface(
                  context,
                  initialDate: _date,
                  firstDate: widget.loan.issuedOn,
                  lastDate: DateUtils.dateOnly(DateTime.now()),
                  title: 'Fecha del abono',
                  tokens: humanResourcesAreaTokens,
                );
                if (picked != null && mounted) setState(() => _date = picked);
              },
        icon: const Icon(Icons.event_outlined),
        label: Text(hrLoanDate(_date)),
      ),
      _loanField(
        _notes,
        'Observaciones / referencia',
        maxLines: 2,
        enabled: !_busy,
      ),
      Text(
        'Este registro confirma efectivo recibido y lo devuelve al fondo. También reduce lo pendiente para los próximos descuentos de nómina.',
        style: _loanText(12, muted: true),
      ),
    ],
  );
}

class _LoanFormShell extends StatelessWidget {
  final String title, submitLabel;
  final bool busy;
  final String? error;
  final List<Widget> children;
  final Future<void> Function() onSubmit;
  const _LoanFormShell({
    required this.title,
    required this.submitLabel,
    required this.busy,
    required this.error,
    required this.children,
    required this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: ContractDialogShell(
      child: SizedBox(
        width: 680,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: _loanText(23, strong: true)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: humanResourcesAreaTokens.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in children)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: child,
                        ),
                    ],
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, style: _loanText(13)),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: busy ? null : onSubmit,
                    child: Text(busy ? 'Guardando…' : submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _loanField(
  TextEditingController controller,
  String label, {
  bool money = false,
  bool integer = false,
  bool enabled = true,
  bool autofocus = false,
  int maxLines = 1,
  ValueChanged<String>? onChanged,
}) => TextField(
  controller: controller,
  enabled: enabled,
  autofocus: autofocus,
  maxLines: maxLines,
  style: _loanText(15),
  onChanged: onChanged,
  keyboardType: money || integer
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.text,
  inputFormatters: integer ? [FilteringTextInputFormatter.digitsOnly] : null,
  decoration: InputDecoration(
    labelText: label,
    labelStyle: _loanText(13, muted: true),
    prefixText: money ? r'$ ' : null,
    prefixStyle: _loanText(14, muted: true),
    filled: true,
    fillColor: humanResourcesAreaTokens.fieldSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: humanResourcesAreaTokens.border),
    ),
  ),
);

Widget _loanDropdown(
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String>? onChanged,
) => Builder(
  builder: (context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    dropdownColor: humanResourcesAreaTokens.glassSurface,
    style: Theme.of(context).textTheme.bodyMedium?.merge(_loanText(14)),
    iconEnabledColor: humanResourcesAreaTokens.accent,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: _loanText(13, muted: true),
    ),
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: onChanged == null
        ? null
        : (value) {
            if (value != null) onChanged(value);
          },
  ),
);

int? _loanInputCents(String input) {
  final text = input.trim();
  if (text.length > 18 ||
      !RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  return hrLoanCents(text.replaceAll(',', ''));
}
