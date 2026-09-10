part of '../human_resources_prenomina_page.dart';

InputDecoration _prenominaInputDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: humanResourcesAreaTokens.fieldSurface,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: humanResourcesAreaTokens.border.withValues(alpha: .4),
    ),
  ),
);

String _prenominaChannelLabel(_HrPrenominaPaymentChannel channel) =>
    switch (channel) {
      _HrPrenominaPaymentChannel.efectivo => 'Flujo',
      _HrPrenominaPaymentChannel.cheque => 'Fiscal sin depósito',
      _ => channel.label,
    };

String _prenominaCount(double value) =>
    value == 0 ? '0' : _formatPrenominaDays(value);

// Presentation grouping only. The payable totals remain the existing row getters.
double _prenominaFiscalDeductions(_HrPrenominaSummaryRow row) =>
    row.fiscalImssAmount +
    row.fiscalInfonavitAmount +
    row.fiscalFonacotAmount +
    row.fiscalAbsenceAmount +
    row.fiscalLateDeductionAmount +
    HrLoanPayrollPlan.fromSnapshot(row.sourceSnapshot).fiscalCents / 100;

class _PrenominaPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PrenominaPanel({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: humanResourcesAreaTokens.primarySoft.withValues(alpha: .06),
      border: Border.all(
        color: humanResourcesAreaTokens.border.withValues(alpha: .25),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: humanResourcesAreaTokens.badgeText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _PrenominaAmount extends StatelessWidget {
  final String label;
  final double amount;
  final bool strong;
  const _PrenominaAmount({
    required this.label,
    required this.amount,
    this.strong = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatPrenominaMoneyZero(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _PrenominaTotals extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  const _PrenominaTotals({required this.row});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in [
        ('Fiscal', row.fiscalTotalAmount),
        ('Flujo', row.weeklyPaymentVisibleAmount - row.fiscalTotalAmount),
        ('Total', row.weeklyPaymentVisibleAmount),
      ])
        Expanded(
          child: Container(
            margin: EdgeInsets.only(right: item.$1 == 'Total' ? 0 : 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.$1 == 'Total'
                  ? humanResourcesAreaTokens.primaryStrong
                  : humanResourcesAreaTokens.primarySoft.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: humanResourcesAreaTokens.border.withValues(
                  alpha: item.$1 == 'Total' ? .8 : .25,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: TextStyle(
                    color: humanResourcesAreaTokens.badgeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatPrenominaMoneyZero(item.$2),
                    key: ValueKey('total-${item.$1}'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _PrenominaIndicators extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final List<_HrPrenominaAttendanceRecord> attendance;
  const _PrenominaIndicators({required this.row, required this.attendance});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final text in [
        '${attendance.where((r) => r.status == _HrPrenominaAttendanceStatus.laboro).length} trabajados',
        '${attendance.where((r) => r.status == _HrPrenominaAttendanceStatus.falto).length} faltas',
        '${attendance.where((r) => r.lateMinutes > 0).length} retardos · ${_formatPrenominaMinutesAsHourRatio(row.lateMinutesSum)}',
        '${_formatPrenominaMinutesAsHourRatio(row.overtimeMinutesSum)} extra',
        '${_prenominaCount(row.vacationTotalDays)} d vacaciones',
        '${_prenominaCount(row.permissionWithPayDays + row.permissionWithoutPayDays)} d permisos',
        '${_prenominaCount(row.permissionWithPayHours + row.permissionWithoutPayHours)} h permisos',
        '${row.attendanceReviewDays} por revisar',
      ])
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: humanResourcesAreaTokens.badgeBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: humanResourcesAreaTokens.badgeText,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}

class _PrenominaPicker<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  const _PrenominaPicker({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: InkWell(
      key: ValueKey('picker-$label'),
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showSearchablePickerDialog<T>(
          context,
          title: label,
          initialValue: value,
          options: values
              .map(
                (item) =>
                    SearchablePickerOption(value: item, label: labelOf(item)),
              )
              .toList(),
        );
        if (selected != null && context.mounted) onChanged(selected);
      },
      child: InputDecorator(
        decoration: _prenominaInputDecoration(label),
        child: Row(
          children: [
            Expanded(
              child: Text(labelOf(value), overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    ),
  );
}
