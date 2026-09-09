part of '../human_resources_prenomina_page.dart';

enum _PrenominaSection {
  resumen('Resumen', Icons.dashboard_outlined),
  asistencia('Asistencia', Icons.event_available_outlined),
  vacaciones('Vacaciones y permisos', Icons.beach_access_outlined),
  percepciones('Percepciones', Icons.add_card_outlined),
  descuentos('Descuentos', Icons.remove_circle_outline),
  notas('Notas', Icons.notes_outlined);

  final String label;
  final IconData icon;
  const _PrenominaSection(this.label, this.icon);
}

class _PrenominaEmployeeSidebar extends StatelessWidget {
  final _HrPrenominaSummaryRow row;
  final List<_HrPrenominaAttendanceRecord> attendance;
  final String period;
  final String notes;
  final _PrenominaSection section;
  final ValueChanged<_PrenominaSection> onSelect;
  const _PrenominaEmployeeSidebar({
    required this.row,
    required this.attendance,
    required this.period,
    required this.notes,
    required this.section,
    required this.onSelect,
  });

  String _diagnostic(_PrenominaSection item) => switch (item) {
    _PrenominaSection.resumen => row.statusLabel,
    _PrenominaSection.asistencia =>
      '${attendance.where((r) => r.status == _HrPrenominaAttendanceStatus.laboro).length} trabajados · ${attendance.where((r) => r.status == _HrPrenominaAttendanceStatus.falto).length} faltas\n${_formatPrenominaMinutesAsHourRatio(row.lateMinutesSum)} retardo',
    _PrenominaSection.vacaciones =>
      '${_prenominaCount(row.vacationTotalDays)} d vacaciones · ${_prenominaCount(row.permissionWithPayDays + row.permissionWithoutPayDays)} d permisos\n${_prenominaCount(row.permissionWithPayHours + row.permissionWithoutPayHours)} h permisos · ${_prenominaCount(row.disabilityDays)} d / ${_prenominaCount(row.disabilityHours)} h incap.',
    _PrenominaSection.percepciones =>
      'Fiscal ${_formatPrenominaMoneyZero(row.fiscalNetAmount + row.fiscalVacationAmount)}\nFlujo ${_formatPrenominaMoneyZero(row.operationalCashSubtotalAmount + row.paymentOutsideAmount + row.manualAdjustmentAmount)}',
    _PrenominaSection.descuentos =>
      'Fiscal ${_formatPrenominaMoneyZero(_prenominaFiscalDeductions(row))}\nFlujo ${_formatPrenominaMoneyZero(row.operationalCashDeductionsTotalAmount)}',
    _PrenominaSection.notas => notes.trim().isEmpty ? 'Sin notas' : '1 nota RH',
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          row.displayName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'ID #${row.employeeId} · ${row.empresa}',
          style: TextStyle(
            color: humanResourcesAreaTokens.badgeText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          period.isEmpty ? 'Sin periodo activo' : period,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        for (final item in _PrenominaSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              selected: item == section,
              button: true,
              child: Material(
                color: item == section
                    ? humanResourcesAreaTokens.primaryStrong
                    : humanResourcesAreaTokens.primarySoft.withValues(
                        alpha: .05,
                      ),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('section-${item.name}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.icon,
                          size: 19,
                          color: humanResourcesAreaTokens.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _diagnostic(item),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: humanResourcesAreaTokens.badgeText,
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
          ),
      ],
    ),
  );
}
