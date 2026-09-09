part of '../human_resources_prenomina_page.dart';

class _HrPrenominaEditDialog extends StatefulWidget {
  final _HrPrenominaSummaryRow row;
  final String periodLabel;
  final List<_HrPrenominaAttendanceRecord> attendance;
  final _HrPrenominaSummaryRow Function(_HrPrenominaDraftDraft) preview;
  final bool canGoPrevious;
  final bool canGoNext;

  const _HrPrenominaEditDialog({
    required this.row,
    required this.attendance,
    required this.preview,
    required this.periodLabel,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  State<_HrPrenominaEditDialog> createState() => _HrPrenominaEditDialogState();
}

class _HrPrenominaEditDialogState extends State<_HrPrenominaEditDialog> {
  final FocusNode _dialogFocusNode = FocusNode(debugLabel: 'hrPrenominaDialog');
  late final _HrPrenominaDraftDraft _draft =
      _HrPrenominaDraftDraft.fromSummaryRow(widget.row);
  String? _moneyValidationMessage;
  _PrenominaSection _section = _PrenominaSection.resumen;
  late _HrPrenominaSummaryRow _preview = widget.row;

  void _changed() {
    setState(() {
      if (_draft.firstInvalidMoneyFieldLabel == null) {
        _preview = widget.preview(_draft);
        _moneyValidationMessage = null;
      }
    });
  }

  Widget _money(
    String id,
    String label,
    String value,
    ValueChanged<String> write,
  ) {
    return SizedBox(
      width: 240,
      child: TextFormField(
        key: ValueKey(id),
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: _prenominaInputDecoration(label),
        onChanged: (text) {
          write(text);
          _changed();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  bool _hasEditableTextFocus() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _save([_HrPrenominaEditAction action = _HrPrenominaEditAction.save]) {
    final invalidField = _draft.firstInvalidMoneyFieldLabel;
    if (invalidField != null) {
      setState(() {
        _moneyValidationMessage =
            'Revisa "$invalidField". Captura un monto válido, por ejemplo 1250.50.';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_HrPrenominaEditResult(action: action, draft: _draft));
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: Focus(
        autofocus: true,
        focusNode: _dialogFocusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (!_hasEditableTextFocus() &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _save();
            return KeyEventResult.handled;
          }
          if (!_hasEditableTextFocus() &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.canGoPrevious) {
            _save(_HrPrenominaEditAction.previous);
            return KeyEventResult.handled;
          }
          if (!_hasEditableTextFocus() &&
              event.logicalKey == LogicalKeyboardKey.arrowRight &&
              widget.canGoNext) {
            _save(_HrPrenominaEditAction.next);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ContractDialogShell(
          insetPadding: const EdgeInsets.all(20),
          child: Theme(
            data: Theme.of(context).copyWith(
              brightness: Brightness.dark,
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: humanResourcesAreaTokens.onGlass,
                displayColor: humanResourcesAreaTokens.onGlass,
              ),
              iconTheme: IconThemeData(color: humanResourcesAreaTokens.onGlass),
              colorScheme: ColorScheme.dark(
                primary: humanResourcesAreaTokens.accent,
                surface: humanResourcesAreaTokens.glassSurface,
                onSurface: humanResourcesAreaTokens.onGlass,
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: humanResourcesAreaTokens.onGlass),
              child: Container(
                width: 1200,
                height: MediaQuery.sizeOf(context).height - 40,
                padding: const EdgeInsets.all(20),
                color: humanResourcesAreaTokens.glassSurface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Prenómina',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width < 900
                                ? 210
                                : 252,
                            child: _PrenominaEmployeeSidebar(
                              row: _preview,
                              attendance: widget.attendance,
                              period: widget.periodLabel,
                              section: _section,
                              notes: _draft.notes,
                              onSelect: (section) =>
                                  setState(() => _section = section),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PrenominaTotals(row: _preview),
                                if (_moneyValidationMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _moneyValidationMessage!,
                                      style: TextStyle(
                                        color: humanResourcesAreaTokens.accent,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    key: ValueKey(_section),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          _section.label,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _sectionContent(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (widget.canGoPrevious)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _save(_HrPrenominaEditAction.previous),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Anterior'),
                          ),
                        if (widget.canGoNext)
                          OutlinedButton.icon(
                            onPressed: () => _save(_HrPrenominaEditAction.next),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Siguiente'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: _save,
                          child: Text(
                            _draft.draftStatus ==
                                    _HrPrenominaDraftStatus.publicado
                                ? 'Guardar y publicar'
                                : 'Guardar borrador',
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

  Widget _sectionContent() {
    switch (_section) {
      case _PrenominaSection.resumen:
        return _PrenominaSummary(row: _preview, attendance: widget.attendance);
      case _PrenominaSection.asistencia:
        return _PrenominaAttendance(
          row: _preview,
          attendance: widget.attendance,
        );
      case _PrenominaSection.vacaciones:
        return _PrenominaVacationsPermissions(row: _preview);
      case _PrenominaSection.percepciones:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrenominaPanel(
              title: 'Fiscal · editable por RH',
              children: [
                const Text(
                  'El neto fiscal ya incluye las deducciones de CONTPAQ.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _money(
                      'fiscalNetAmount',
                      'Neto fiscal',
                      _draft.fiscalNetAmountText,
                      (v) {
                        _draft.fiscalNetAmountText = v;
                      },
                    ),
                    _money(
                      'fiscalVacationAmount',
                      'Vacaciones fiscales',
                      _draft.fiscalVacationAmountText,
                      (v) {
                        _draft.fiscalVacationAmountText = v;
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PrenominaPanel(
              title: 'Flujo · editable por RH',
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _money(
                      'cashSalaryAmount',
                      'Complemento en Flujo',
                      _draft.cashSalaryAmountText,
                      (v) {
                        _draft.cashSalaryAmountText = v;
                        _draft.cashSalaryIsManual = true;
                      },
                    ),
                    _money(
                      'cashVacationAmount',
                      'Vacaciones en Flujo',
                      _draft.cashVacationAmountText,
                      (v) {
                        _draft.cashVacationAmountText = v;
                      },
                    ),
                    _money(
                      'transportSupportAmount',
                      'Transporte',
                      _draft.transportSupportAmountText,
                      (v) {
                        _draft.transportSupportAmountText = v;
                      },
                    ),
                    _money(
                      'holidayAmount',
                      'Festivo',
                      _draft.holidayAmountText,
                      (v) {
                        _draft.holidayAmountText = v;
                      },
                    ),
                    _money(
                      'overtimeMonetizedAmount',
                      'Horas extra',
                      _draft.overtimeMonetizedAmountText,
                      (v) {
                        _draft.overtimeMonetizedAmountText = v;
                        _draft.sourceSnapshot['overtime_is_manual'] = true;
                      },
                    ),
                    _money(
                      'manualBonusAmount',
                      'Bonos',
                      _draft.manualBonusAmountText,
                      (v) {
                        _draft.manualBonusAmountText = v;
                      },
                    ),
                    _money(
                      'paymentOutsideAmount',
                      'Pago por fuera',
                      _draft.paymentOutsideAmountText,
                      (v) {
                        _draft.paymentOutsideAmountText = v;
                      },
                    ),
                    _money(
                      'manualAdjustmentAmount',
                      'Ajuste RH (+ / −)',
                      _draft.manualAdjustmentAmountText,
                      (v) {
                        _draft.manualAdjustmentAmountText = v;
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PrenominaPanel(
              title: 'Referencias de origen · lectura',
              children: [
                _PrenominaAmount(
                  label: 'Base semanal · Personal',
                  amount: _preview.salaryWeekly,
                ),
                _PrenominaAmount(
                  label: 'Total semanal · Personal',
                  amount: _preview.salaryPerceivedWeekly,
                ),
                _PrenominaAmount(
                  label: 'Flujo semanal · Personal',
                  amount: _preview.calculatedCashSalaryAmount,
                ),
                _PrenominaAmount(
                  label: 'Tarifa hora extra · Personal',
                  amount: _preview.overtimeHourlyRate,
                ),
                Text('Medio fiscal: ${_preview.fiscalDeliveryLabel}'),
                _PrenominaAmount(
                  label: 'Sueldo CONTPAQ',
                  amount: _preview.contpaqSalaryAmount,
                ),
                _PrenominaAmount(
                  label: 'Neto CONTPAQ',
                  amount: _preview.contpaqNetAmount,
                ),
                _PrenominaAmount(
                  label: 'Horas extra CONTPAQ',
                  amount: _preview.contpaqOvertimeAmount,
                ),
                _PrenominaAmount(
                  label: 'Vacaciones CONTPAQ',
                  amount: _preview.contpaqVacationAmount,
                ),
              ],
            ),
          ],
        );
      case _PrenominaSection.descuentos:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrenominaPanel(
              title: 'Descuentos fiscales · editable por RH',
              children: [
                const Text(
                  'IMSS, INFONAVIT, FONACOT y faltas son referencias incluidas en el neto. El retardo se aplica adicionalmente.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _money(
                      'fiscalImssAmount',
                      'IMSS',
                      _draft.fiscalImssAmountText,
                      (v) {
                        _draft.fiscalImssAmountText = v;
                      },
                    ),
                    _money(
                      'fiscalInfonavitAmount',
                      'INFONAVIT fiscal',
                      _draft.fiscalInfonavitAmountText,
                      (v) {
                        _draft.fiscalInfonavitAmountText = v;
                      },
                    ),
                    _money(
                      'fiscalFonacotAmount',
                      'FONACOT fiscal',
                      _draft.fiscalFonacotAmountText,
                      (v) {
                        _draft.fiscalFonacotAmountText = v;
                      },
                    ),
                    _money(
                      'fiscalAbsenceAmount',
                      'Faltas fiscales',
                      _draft.fiscalAbsenceAmountText,
                      (v) {
                        _draft.fiscalAbsenceAmountText = v;
                      },
                    ),
                    _money(
                      'fiscalLateDeductionAmount',
                      'Retardo fiscal · informativo',
                      _draft.fiscalLateDeductionAmountText,
                      (v) {
                        _draft.fiscalLateDeductionAmountText = v;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PrenominaAmount(
                  label: 'Total descuentos fiscales registrados',
                  amount: _prenominaFiscalDeductions(_preview),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PrenominaPanel(
              title: 'Descuentos en Flujo · editable por RH',
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _money(
                      'cashIsrAmount',
                      'ISR en Flujo',
                      _draft.cashIsrAmountText,
                      (v) {
                        _draft.cashIsrAmountText = v;
                      },
                    ),
                    _money(
                      'cashAbsenceDeductionAmount',
                      'Faltas en Flujo',
                      _draft.cashAbsenceDeductionAmountText,
                      (v) {
                        _draft.cashAbsenceDeductionAmountText = v;
                      },
                    ),
                    _money(
                      'cashInfonavitDeductionAmount',
                      'INFONAVIT en Flujo',
                      _draft.cashInfonavitDeductionAmountText,
                      (v) {
                        _draft.cashInfonavitDeductionAmountText = v;
                      },
                    ),
                    _money(
                      'cashFonacotDeductionAmount',
                      'FONACOT en Flujo',
                      _draft.cashFonacotDeductionAmountText,
                      (v) {
                        _draft.cashFonacotDeductionAmountText = v;
                      },
                    ),
                    _money(
                      'loanDeductionAmount',
                      'Préstamo',
                      _draft.loanDeductionAmountText,
                      (v) {
                        _draft.loanDeductionAmountText = v;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PrenominaAmount(
                  label: 'Total descuentos en Flujo',
                  amount: _preview.operationalCashDeductionsTotalAmount,
                  strong: true,
                ),
              ],
            ),
          ],
        );
      case _PrenominaSection.notas:
        return _PrenominaPanel(
          title: 'Administración del borrador',
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                _PrenominaPicker<_HrPrenominaDraftStatus>(
                  label: 'Estatus',
                  value: _draft.draftStatus,
                  values: _HrPrenominaDraftStatus.values,
                  labelOf: (v) => v.label,
                  onChanged: (v) {
                    _draft.draftStatus = v;
                    _changed();
                  },
                ),
                _PrenominaPicker<_HrPrenominaPaymentChannel>(
                  label: 'Canal de pago',
                  value: _draft.paymentChannel,
                  values: _HrPrenominaPaymentChannel.values,
                  labelOf: _prenominaChannelLabel,
                  onChanged: (v) {
                    _draft.paymentChannel = v;
                    _draft.sourceSnapshot['fiscal_payment_is_manual'] = true;
                    _changed();
                  },
                ),
                _money(
                  'checkAmount',
                  'Fiscal en cheque / efectivo',
                  _draft.checkAmountText,
                  (v) {
                    _draft.checkAmountText = v;
                    _draft.sourceSnapshot['fiscal_payment_is_manual'] = true;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('paymentReference'),
              initialValue: _draft.paymentReference,
              decoration: _prenominaInputDecoration('Referencia de pago'),
              onChanged: (v) {
                _draft.paymentReference = v;
                _changed();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('notes'),
              initialValue: _draft.notes,
              decoration: _prenominaInputDecoration('Notas RH'),
              minLines: 3,
              maxLines: 5,
              onChanged: (v) {
                _draft.notes = v;
                _changed();
              },
            ),
            const SizedBox(height: 16),
            _PrenominaAmount(
              label: 'Fiscal depositado',
              amount: _preview.fiscalDepositedAmount,
            ),
            _PrenominaAmount(
              label: 'Fiscal en cheque / efectivo',
              amount: _preview.fiscalCashAmount,
            ),
            const Text(
              'La distribución del fiscal no incrementa el pago en Flujo.',
            ),
            if (_draftNeedsOperationalNote(_preview)) ...[
              const SizedBox(height: 12),
              Text(_draftOperationalNote(_preview)),
            ],
          ],
        );
    }
  }
}
