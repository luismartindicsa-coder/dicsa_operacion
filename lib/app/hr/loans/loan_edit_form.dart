part of '../human_resources_loans_page.dart';

class _HrLoanEditDialog extends StatefulWidget {
  final HrLoan loan;
  final HrLoanFundState fund;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _HrLoanEditDialog({
    required this.loan,
    required this.fund,
    required this.onSave,
  });
  @override
  State<_HrLoanEditDialog> createState() => _HrLoanEditDialogState();
}

class _HrLoanEditDialogState extends State<_HrLoanEditDialog> {
  late final _amount = TextEditingController(
    text: (widget.loan.principalCents / 100).toStringAsFixed(2),
  );
  late final _paid = TextEditingController(
    text: (widget.fund.paidCents(widget.loan) / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.loan.notes);
  late DateTime _date = widget.loan.displayDate,
      _first = widget.loan.firstDueOn;
  final _requestId = _loanRequestId();
  bool _busy = false;
  String? _error;

  void _changed(String _) => setState(() => _error = null);

  @override
  void dispose() {
    _amount.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final amount = _loanInputCents(_amount.text);
    final paid = _loanInputCents(_paid.text);
    final confirmed = widget.fund.payments
        .where((p) => p.loanId == widget.loan.id && p.method == 'nomina')
        .fold<int>(0, (sum, p) => sum + p.cents);
    String? error;
    if (amount == null ||
        amount <= 0 ||
        paid == null ||
        paid < 0 ||
        paid > amount) {
      error =
          'Revisa el monto y lo aportado: usa dos decimales y un aportado entre cero y el monto.';
    } else if (paid < confirmed) {
      error =
          'Lo aportado no puede ser menor a ${_loanMoney(confirmed)} descontados en nóminas cerradas.';
    } else if (amount < widget.loan.openingPaidCents) {
      error =
          'El monto no puede ser menor a ${_loanMoney(widget.loan.openingPaidCents)} de abonos históricos documentados.';
    } else if (_first.isBefore(_date) ||
        (widget.loan.isHistorical &&
            (_first.isBefore(widget.loan.issuedOn) ||
                _date.isAfter(widget.loan.issuedOn)))) {
      error =
          'Revisa las fechas de entrega, saldo inicial y primer vencimiento.';
    } else if (amount - paid > widget.fund.balanceCents(widget.loan) &&
        amount - paid - widget.fund.balanceCents(widget.loan) >
            widget.fund.availableCents) {
      error = 'La corrección supera el saldo disponible del fondo.';
    }
    if (error != null) {
      setState(() => _error = error);
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
        'p_expected_revision': widget.loan.revision,
        'p_expected_paid': widget.fund.paidCents(widget.loan) / 100,
        'p_principal': amount! / 100,
        'p_paid_amount': paid! / 100,
        'p_requested_on': hrLoanDate(_date),
        'p_first_due_on': hrLoanDate(_first),
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

  Future<void> _pickDate(bool first) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = first ? _first : _date;
    final picked = await showContractDatePickerSurface(
      context,
      initialDate: selected,
      firstDate: DateTime(math.min(2000, selected.year)),
      lastDate: first
          ? DateTime(math.max(today.year + 10, selected.year), 12, 31)
          : today,
      title: first ? 'Primer vencimiento' : 'Fecha del préstamo',
      tokens: humanResourcesAreaTokens,
    );
    if (picked != null && mounted) {
      setState(() {
        _error = null;
        if (first) {
          _first = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _loanInputCents(_amount.text);
    final paid = _loanInputCents(_paid.text);
    return _LoanFormShell(
      title: 'Editar préstamo PR-${widget.loan.folio}',
      busy: _busy,
      error: _error,
      submitLabel: 'Guardar cambios',
      onSubmit: _save,
      children: [
        Text(widget.loan.employeeName, style: _loanText(16, strong: true)),
        Row(
          children: [
            Expanded(
              child: _loanField(
                _amount,
                'Monto del préstamo',
                money: true,
                autofocus: true,
                enabled: !_busy,
                onChanged: _changed,
                onSubmitted: _save,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _loanField(
                _paid,
                'Total aportado',
                money: true,
                enabled: !_busy,
                onChanged: _changed,
                onSubmitted: _save,
              ),
            ),
          ],
        ),
        if (amount != null && paid != null && amount >= paid)
          Text(
            'Saldo pendiente: ${_loanMoney(amount - paid)}',
            style: _loanText(17, strong: true),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _busy ? null : () => _pickDate(false),
              icon: const Icon(Icons.event_outlined),
              label: Text('Fecha del préstamo: ${hrLoanDate(_date)}'),
            ),
            OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _busy ? null : () => _pickDate(true),
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text('Primer vencimiento: ${hrLoanDate(_first)}'),
            ),
          ],
        ),
        Text(
          'Cuota habitual: ${_loanMoney(widget.loan.regularInstallmentCents)} · ${widget.loan.frequencyLabel}',
          style: _loanText(14, strong: true),
        ),
        Text(
          'Al aumentar lo aportado se reduce el saldo y se termina antes de pagar; la cuota habitual se conserva.',
          style: _loanText(13, muted: true),
        ),
        _loanField(
          _notes,
          'Comentarios',
          maxLines: 3,
          enabled: !_busy,
          onChanged: _changed,
        ),
        Text(
          'Lo aportado es el total acumulado. Para registrar un nuevo pago con fecha propia, usa «Abono en efectivo». Las correcciones quedan en el historial y conservan los descuentos de nóminas cerradas.',
          style: _loanText(12, muted: true),
        ),
      ],
    );
  }
}
