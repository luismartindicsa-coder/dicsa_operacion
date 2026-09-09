part of '../human_resources_nomina_page.dart';

class _HrNominaDetailDialog extends StatefulWidget {
  final _HrNominaSummaryRow row;
  final _HrNominaDraftRecord? draft;
  final String activePeriodLabel;
  final bool canGenerateReceipt;
  final Future<void> Function(_HrNominaSummaryRow) onGenerateReceipt;
  final Future<void> Function() onOpenPrenomina, onExportPeriodReport;
  const _HrNominaDetailDialog({
    required this.row,
    required this.draft,
    required this.activePeriodLabel,
    required this.canGenerateReceipt,
    required this.onGenerateReceipt,
    required this.onOpenPrenomina,
    required this.onExportPeriodReport,
  });
  @override
  State<_HrNominaDetailDialog> createState() => _HrNominaDetailDialogState();
}

class _HrNominaDetailDialogState extends State<_HrNominaDetailDialog> {
  int _section = 0;
  static const _sections = [
    'Resumen',
    'Percepciones',
    'Deducciones',
    'Flujo',
    'Pago y depósito',
    'Historial',
    'Notas',
  ];
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: _NominaTheme(
        dark: true,
        child: ContractDialogShell(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
            child: Container(
              padding: const EdgeInsets.all(20),
              color: humanResourcesAreaTokens.glassSurface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detalle de nómina',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.canGenerateReceipt
                                  ? 'Vista del periodo cerrado desde Prenómina · Sólo lectura'
                                  : 'Periodo sin cerrar · Sólo lectura',
                              style: TextStyle(
                                fontSize: 12,
                                color: humanResourcesAreaTokens.badgeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onExportPeriodReport,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF del periodo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenPrenomina,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Ver prenómina'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('nomina-receipt'),
                        onPressed: row.isPublished && widget.canGenerateReceipt
                            ? () => widget.onGenerateReceipt(row)
                            : null,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Abrir / generar recibo'),
                      ),
                    ],
                  ),
                  if (!row.isPublished || !widget.canGenerateReceipt)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'El recibo requiere un periodo cerrado y un colaborador publicado.',
                        style: TextStyle(
                          fontSize: 12,
                          color: humanResourcesAreaTokens.badgeText,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 235,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  row.employeeName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ID ${row.employeeId} · ${row.empresa}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: humanResourcesAreaTokens.badgeText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _HrNominaStatusBadge(
                                    label: row.statusLabel,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _HrNominaSideData(
                                  label: 'Periodo',
                                  value: widget.activePeriodLabel,
                                ),
                                _HrNominaSideData(
                                  label: 'Canal de pago',
                                  value: _nominaChannel(
                                    row.paymentChannelLabel,
                                  ),
                                ),
                                _HrNominaSideData(
                                  label: 'Referencia',
                                  value: row.paymentReference.isEmpty
                                      ? 'Sin referencia'
                                      : row.paymentReference,
                                ),
                                const Divider(),
                                for (var i = 0; i < _sections.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: _section == i
                                          ? humanResourcesAreaTokens
                                                .primaryStrong
                                          : humanResourcesAreaTokens.primarySoft
                                                .withValues(alpha: .05),
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListTile(
                                        key: ValueKey('nomina-tab-$i'),
                                        dense: true,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        selected: _section == i,
                                        selectedColor:
                                            humanResourcesAreaTokens.onGlass,
                                        leading: Icon(
                                          const [
                                            Icons.dashboard_outlined,
                                            Icons.add_card_outlined,
                                            Icons.remove_circle_outline,
                                            Icons.payments_outlined,
                                            Icons.account_balance_outlined,
                                            Icons.history,
                                            Icons.notes_outlined,
                                          ][i],
                                          size: 19,
                                          color:
                                              humanResourcesAreaTokens.accent,
                                        ),
                                        minLeadingWidth: 19,
                                        horizontalTitleGap: 10,
                                        title: Text(
                                          _sections[i],
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color:
                                              humanResourcesAreaTokens.accent,
                                        ),
                                        onTap: () =>
                                            setState(() => _section = i),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NominaDetailTotals(row: row),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  key: ValueKey('nomina-section-$_section'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _section == 0
                                            ? 'Resumen general'
                                            : _sections[_section],
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ..._content(),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _HrNominaDetailLine _amount(
    String label,
    double value, {
    bool strong = false,
  }) => _HrNominaDetailLine(
    label: label,
    value: _fmtHrNominaMoney(value),
    emphasized: strong,
  );
  Widget _fiscal() {
    final r = widget.row;
    return _HrNominaDetailBlock(
      title: 'Fiscal',
      rows: [
        if (widget.draft != null)
          _amount('Fiscal antes de retardo', widget.draft!.fiscalNetAmount),
        _amount(
          r.incidencesInformational
              ? 'Retardos · informativo'
              : 'Retardos fiscales',
          r.fiscalLateDeductionAmount,
        ),
        _amount('Fiscal total', r.fiscalAmount, strong: true),
        _amount('Fiscal depositado', r.fiscalDepositedAmount),
        _amount('Fiscal sin depósito', r.fiscalCashAmount),
      ],
    );
  }

  Widget _flow() {
    final r = widget.row;
    return _HrNominaDetailBlock(
      title: 'Flujo · desglose',
      rows: [
        _amount('Sueldo flujo', r.cashSalaryAmount),
        _amount('Vacaciones flujo', r.cashVacationAmount),
        _amount('Apoyo transporte', r.transportSupportAmount),
        _amount('Festivo', r.holidayAmount),
        _amount('Horas extra', r.overtimeMonetizedAmount),
        _amount('Bono', r.manualBonusAmount),
        _amount('Ajuste RH', r.manualAdjustmentAmount),
        _amount('Complementos antes de deducciones', r.complementsAmount),
        _amount('Pago por fuera', r.paymentOutsideAmount),
        _amount('Deducciones de flujo', r.deductionsAmount),
        _amount('Flujo final', _nominaFlow(r), strong: true),
      ],
    );
  }

  List<Widget> _content() {
    final r = widget.row;
    switch (_section) {
      case 0:
        return [
          _HrNominaDetailBlock(
            title: 'Deducciones · ya incluidas en flujo',
            rows: [_amount('Deducciones', r.deductionsAmount, strong: true)],
          ),
          const SizedBox(height: 18),
          Text(
            widget.canGenerateReceipt
                ? 'Este periodo fue cerrado desde Prenómina. Para modificar incidencias o conceptos, regresa a Prenómina.'
                : 'Este periodo aún no está cerrado. Para modificar incidencias o conceptos, regresa a Prenómina.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onOpenPrenomina,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Ir a prenómina'),
            ),
          ),
          _fiscal(),
        ];
      case 1:
        return [_fiscal(), _flow()];
      case 2:
        return [
          _HrNominaDetailBlock(
            title: 'Deducciones fiscales disponibles',
            rows: [
              _amount(
                r.incidencesInformational
                    ? 'Retardos · informativo'
                    : 'Retardos fiscales',
                r.fiscalLateDeductionAmount,
              ),
            ],
          ),
          _HrNominaDetailBlock(
            title: 'Deducciones de flujo',
            rows: [
              _amount('ISR flujo', r.cashIsrAmount),
              _amount(
                r.incidencesInformational
                    ? 'Faltas · informativo'
                    : 'Faltas flujo',
                r.cashAbsenceDeductionAmount,
              ),
              _amount('INFONAVIT flujo', r.cashInfonavitDeductionAmount),
              _amount('FONACOT flujo', r.cashFonacotDeductionAmount),
              _amount('Préstamos', r.loanDeductionAmount),
              _amount(
                'Total deducciones de flujo',
                r.deductionsAmount,
                strong: true,
              ),
            ],
          ),
        ];
      case 3:
        return [_flow()];
      case 4:
        return [
          _HrNominaDetailBlock(
            title: 'Distribución del pago',
            rows: [
              _HrNominaDetailLine(
                label: 'Canal',
                value: _nominaChannel(r.paymentChannelLabel),
              ),
              _HrNominaDetailLine(
                label: 'Referencia',
                value: r.paymentReference.isEmpty
                    ? 'Sin referencia'
                    : r.paymentReference,
              ),
              _amount('Fiscal depositado', r.fiscalDepositedAmount),
              _amount('Fiscal sin depósito', r.fiscalCashAmount),
              _amount('Flujo', _nominaFlow(r)),
              _amount('Total', r.totalAmount, strong: true),
              _HrNominaDetailLine(label: 'Estado', value: r.statusLabel),
            ],
          ),
        ];
      case 5:
        final receipt = _HrNominaReceiptSnapshot.tryFromJson(
          widget.draft?.sourceSnapshot['payroll_receipt'],
        );
        return [
          const Text(
            'Los importes de esta vista provienen del registro de Prenómina. El PDF individual conserva el snapshot del recibo emitido.',
          ),
          const SizedBox(height: 14),
          _HrNominaDetailBlock(
            title: 'Trazabilidad disponible',
            rows: [
              if (widget.draft?.createdAt != null)
                _HrNominaDetailLine(
                  label: 'Registro del borrador',
                  value: _nominaDate(widget.draft!.createdAt),
                ),
              _HrNominaDetailLine(
                label: 'Periodo',
                value: widget.canGenerateReceipt ? 'Cerrado' : 'Sin cerrar',
              ),
              if (receipt != null) ...[
                _HrNominaDetailLine(
                  label: 'Recibo emitido',
                  value: _nominaDate(receipt.issuedAt),
                ),
                _HrNominaDetailLine(
                  label: 'Versión del recibo',
                  value: '${receipt.version}',
                ),
                _amount('Total del recibo emitido', receipt.totalAmount),
              ] else
                const _HrNominaDetailLine(
                  label: 'Recibo',
                  value: 'Sin snapshot de recibo disponible',
                ),
            ],
          ),
        ];
      default:
        return [
          Text(
            r.notes.isEmpty ? 'Sin notas registradas en Prenómina.' : r.notes,
          ),
        ];
    }
  }
}
