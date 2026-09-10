part of '../human_resources_prenomina_page.dart';

class _PrenominaSummary extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final List<_HrPrenominaAttendanceRecord> attendance;
  const _PrenominaSummary({required this.row, required this.attendance});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PrenominaIndicators(row: row, attendance: attendance),
      const SizedBox(height: 12),
      _PrenominaPanel(
        title: 'Incidencias RH · referencia sobre salario base',
        children: [
          const Text(
            'Importes informativos. No modifican el neto fiscal ni se descuentan nuevamente del total.',
          ),
          _PrenominaAmount(
            label: 'Salario base semanal',
            amount: row.salaryWeekly,
          ),
          _PrenominaAmount(
            label: 'Faltas',
            amount: _parsePrenominaNumber(
              row.sourceSnapshot['attendance_absence_reference'],
            ),
          ),
          _PrenominaAmount(
            label: 'Retardos',
            amount: _parsePrenominaNumber(
              row.sourceSnapshot['attendance_late_reference'],
            ),
          ),
          _PrenominaAmount(
            label: 'Permisos sin goce',
            amount: _parsePrenominaNumber(
              row.sourceSnapshot['permission_reference'],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final fiscal = _PrenominaPanel(
            title: 'PAGO EN FISCAL',
            children: [
              _PrenominaAmount(
                label: 'Neto fiscal oficial',
                amount: row.fiscalNetAmount,
              ),
              _PrenominaAmount(
                label: 'Vacaciones',
                amount: row.fiscalVacationAmount,
              ),
              const Divider(),
              Text(
                'Desglose informativo · no se vuelve a descontar',
                style: TextStyle(
                  fontSize: 12,
                  color: humanResourcesAreaTokens.badgeText,
                ),
              ),
              _PrenominaAmount(label: 'IMSS', amount: row.fiscalImssAmount),
              _PrenominaAmount(
                label: 'INFONAVIT',
                amount: row.fiscalInfonavitAmount,
              ),
              _PrenominaAmount(
                label: 'FONACOT',
                amount: row.fiscalFonacotAmount,
              ),
              _PrenominaAmount(
                label: 'Faltas',
                amount: row.fiscalAbsenceAmount,
              ),
              _PrenominaAmount(
                label: 'Retardos · referencia',
                amount: row.fiscalLateDeductionAmount,
              ),
              if (HrLoanPayrollPlan.fromSnapshot(
                    row.sourceSnapshot,
                  ).fiscalCents >
                  0)
                _PrenominaAmount(
                  label: 'Préstamo fiscal · incluido en CONTPAQ',
                  amount:
                      HrLoanPayrollPlan.fromSnapshot(
                        row.sourceSnapshot,
                      ).fiscalCents /
                      100,
                ),
              _PrenominaAmount(
                label: 'Total descuentos registrados',
                amount: _prenominaFiscalDeductions(row),
                strong: true,
              ),
              const Divider(),

              if (row.prepaidVacation.days > 0)
                _PrenominaAmount(
                  label: 'Vacaciones ya pagadas · descuento fiscal',
                  amount: row.prepaidVacation.fiscal,
                ),
              if (row.fiscalManualDeductionAmount > 0) ...[
                _PrenominaAmount(
                  label: 'Descuento fiscal manual',
                  amount: row.fiscalManualDeductionAmount,
                ),
                Text(
                  row.fiscalManualDeductionReason,
                  style: TextStyle(
                    fontSize: 12,
                    color: humanResourcesAreaTokens.badgeText,
                  ),
                ),
              ],
              _PrenominaAmount(
                label: 'Total a pagar en Fiscal',
                amount: row.fiscalTotalAmount,
                strong: true,
              ),
              const Divider(),
              _PrenominaAmount(
                label: 'Depósito fiscal',
                amount: row.fiscalDepositedAmount,
              ),
              _PrenominaAmount(
                label: 'Cheque · fiscal en efectivo',
                amount: row.fiscalCashAmount,
              ),
            ],
          );
          final flow = _PrenominaPanel(
            title: 'PAGO EN FLUJO',
            children: [
              _PrenominaAmount(
                label: 'Complemento',
                amount: row.cashSalaryAmount,
              ),
              _PrenominaAmount(
                label: 'Vacaciones',
                amount: row.cashVacationAmount,
              ),
              _PrenominaAmount(
                label: 'Transporte',
                amount: row.transportSupportAmount,
              ),
              _PrenominaAmount(label: 'Festivo', amount: row.holidayAmount),
              _PrenominaAmount(
                label: 'Horas extra',
                amount: row.overtimeMonetizedAmount,
              ),
              _PrenominaAmount(label: 'Bonos', amount: row.manualBonusAmount),
              _PrenominaAmount(
                label: 'Subtotal operativo',
                amount: row.operationalCashSubtotalAmount,
                strong: true,
              ),
              const Divider(),
              if (row.prepaidVacation.days > 0)
                _PrenominaAmount(
                  label: 'Vacaciones ya pagadas · descuento flujo',
                  amount: row.prepaidVacation.flow,
                ),
              _PrenominaAmount(label: 'ISR', amount: row.cashIsrAmount),
              _PrenominaAmount(
                label: 'Faltas · sólo referencia',
                amount: row.cashAbsenceDeductionAmount,
              ),
              _PrenominaAmount(
                label: 'INFONAVIT',
                amount: row.cashInfonavitDeductionAmount,
              ),
              _PrenominaAmount(
                label: 'FONACOT',
                amount: row.cashFonacotDeductionAmount,
              ),
              _PrenominaAmount(
                label: 'Préstamo',
                amount: row.loanDeductionAmount,
              ),
              _PrenominaAmount(
                label: 'Total descuentos',
                amount: row.operationalCashDeductionsTotalAmount,
                strong: true,
              ),
              const Divider(),
              _PrenominaAmount(
                label: 'Pago por fuera',
                amount: row.paymentOutsideAmount,
              ),
              _PrenominaAmount(
                label: 'Ajuste RH',
                amount: row.manualAdjustmentAmount,
              ),
              _PrenominaAmount(
                label: 'Total a pagar en Flujo',
                amount: row.weeklyPaymentVisibleAmount - row.fiscalTotalAmount,
                strong: true,
              ),
            ],
          );
          if (constraints.maxWidth < 640) {
            return Column(children: [fiscal, const SizedBox(height: 12), flow]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fiscal),
              const SizedBox(width: 12),
              Expanded(child: flow),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      _PrenominaPanel(
        title: 'TOTAL A PAGAR AL COLABORADOR',
        children: [
          _PrenominaAmount(
            label: 'Fiscal + Flujo',
            amount: row.weeklyPaymentVisibleAmount,
            strong: true,
          ),
        ],
      ),
    ],
  );
}

class _PrenominaAttendance extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final List<_HrPrenominaAttendanceRecord> attendance;
  const _PrenominaAttendance({required this.row, required this.attendance});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PrenominaIndicators(row: row, attendance: attendance),
      const SizedBox(height: 12),
      _PrenominaPanel(
        title: 'Asistencia del periodo · lectura',
        children: [
          Text(
            '${row.attendanceReadyDays} listas · ${row.attendanceReviewDays} por revisar',
          ),
          Text(
            'Retardo: ${row.lateMinutesSum} min · Extra: ${row.overtimeMinutesSum} min',
          ),
          const SizedBox(height: 12),
          if (attendance.isEmpty)
            const Text('Sin capturas de asistencia en este periodo.'),
          for (final record in attendance) ...[
            const Divider(),
            Text(
              '${record.sourceDate} · ${switch (record.status) {
                _HrPrenominaAttendanceStatus.laboro => 'Laboró',
                _HrPrenominaAttendanceStatus.falto => 'Faltó',
                _HrPrenominaAttendanceStatus.noAplica => 'Sin clasificación laboró/faltó',
              }}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Retardo ${record.lateMinutes} min · Extra ${record.overtimeMinutes} min',
              style: const TextStyle(fontSize: 12),
            ),
            if (record.notes.trim().isNotEmpty)
              Text(
                record.notes,
                style: TextStyle(
                  color: humanResourcesAreaTokens.badgeText,
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    ],
  );
}

class _PrenominaVacationsPermissions extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  const _PrenominaVacationsPermissions({required this.row});
  Widget _days(String label, double days, [double hours = 0]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text(
      '$label: ${_prenominaCount(days)} d${hours == 0 ? '' : ' · ${_prenominaCount(hours)} h'}',
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PrenominaPanel(
        title: 'Vacaciones · lectura',
        children: [
          _days('Total', row.vacationTotalDays),
          _days('Pagadas', row.vacationPaidDays),
          _days('Disfrutadas', row.vacationEnjoyedDays),
          _days('Reservadas', row.vacationReservedDays),
          if (row.prepaidVacation.days > 0) ...[
            _days(
              'Disfrutadas ya pagadas por anticipado',
              row.prepaidVacation.days,
            ),
            _PrenominaAmount(
              label: 'Sueldo cubierto por el anticipo',
              amount: -row.prepaidVacation.total,
            ),
            _PrenominaAmount(
              label: 'Compensación fiscal',
              amount: -row.prepaidVacation.fiscal,
            ),
            _PrenominaAmount(
              label: 'Compensación flujo',
              amount: -row.prepaidVacation.flow,
            ),
            const Text(
              'Estos días ya se pagaron: se descuentan del sueldo de este periodo. Los días trabajados conservan su pago.',
            ),
          ],
          _PrenominaAmount(
            label: 'Importe calculado',
            amount: row.vacationCalculatedAmount,
          ),
          Text(
            row.hasFiscalVacationFootprint
                ? 'Con huella fiscal CONTPAQ'
                : 'Sin huella fiscal CONTPAQ',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _PrenominaPanel(
        title: 'Permisos e incapacidades · lectura',
        children: [
          _days(
            'Con goce',
            row.permissionWithPayDays,
            row.permissionWithPayHours,
          ),
          _days(
            'Sin goce',
            row.permissionWithoutPayDays,
            row.permissionWithoutPayHours,
          ),
          _days('Incapacidad', row.disabilityDays, row.disabilityHours),
          Text(
            '${row.permissionPendingPrenominaCount} pendientes de aplicar a prenómina',
          ),
        ],
      ),
    ],
  );
}
