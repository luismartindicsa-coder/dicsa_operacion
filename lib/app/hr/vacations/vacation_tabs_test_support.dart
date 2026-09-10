part of '../human_resources_vacations_page.dart';

@visibleForTesting
Widget hrVacationTabsForTesting({
  required List<Map<String, dynamic>> events,
  required List<String> periods,
  required ValueChanged<Map<String, dynamic>> onSave,
  Map<String, dynamic>? employee,
  Map<String, dynamic>? balance,
}) {
  final row = _buildVacationSummaryRow(
    employee: _HrVacationEmployeeMaster.fromRow(
      employee ??
          {
            'id': '8',
            'nombre': 'COLABORADORA DE PRUEBA',
            'salario': 2100,
            'salario_real_percibido': 3500,
            'fecha_ingreso': '2020-01-01',
          },
    ),
    balance: balance == null ? null : _HrVacationBalanceRecord.fromRow(balance),
    events: events.map(_HrVacationEventRecord.fromRow).toList(),
    rules: [],
    exerciseYear: 2026,
  );
  return Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () async {
          final result = await showDialog<_HrVacationEditResult>(
            context: context,
            builder: (_) => _HrVacationEditDialog(
              row: row,
              rules: [],
              calculations: [],
              canGoPrevious: false,
              canGoNext: false,
              periodOptions: periods,
            ),
          );
          if (result == null) return;
          onSave({
            'action': result.action.name,
            'paid': result.balance.daysPaid,
            'enjoyed': result.balance.daysEnjoyed,
            'manual_date': _vacationDbDate(result.balance.baseManualDate),
            'import_sources': {
              for (final e in result.events) e.localId: e.importSource,
            },
            'events': [
              for (final e in result.events)
                e.toRow(
                  balanceId: null,
                  employeeId: '8',
                  employeeName: row.displayName,
                  exerciseYear: 2026,
                ),
            ],
          });
        },
        child: const Text('Abrir expediente'),
      ),
    ),
  );
}

@visibleForTesting
Map<String, dynamic> hrVacationReloadForTesting(Map<String, dynamic> event) {
  final draft = _HrVacationEventDraft.fromRecord(
    _HrVacationEventRecord.fromRow(event),
  );
  _normalizeVacationEventDraft(draft, forceDays: !draft.daysManuallyEdited);
  final totals = _summarizeVacationDraftEvents([draft]);
  return {
    'days': draft.daysApplied,
    'extra': draft.additionalPaidDays,
    'period': draft.attendancePeriodLabel,
    'paid': totals.daysPaid,
    'enjoyed': totals.daysEnjoyed,
    'payroll_payment': _vacationEventHasPayrollFootprint(draft),
  };
}

@visibleForTesting
List<Map<String, dynamic>> hrVacationCalculationsForTesting(
  Map<String, dynamic> event, {
  Map<String, dynamic>? employee,
  Map<String, dynamic>? balance,
}) {
  final record = _HrVacationEventRecord.fromRow(event);
  final row = _buildVacationSummaryRow(
    employee: _HrVacationEmployeeMaster.fromRow(
      employee ??
          {
            'id': '8',
            'nombre': 'PRUEBA',
            'salario': 2100,
            'salario_real_percibido': 3500,
            'fecha_ingreso': '2020-01-01',
          },
    ),
    balance: balance == null ? null : _HrVacationBalanceRecord.fromRow(balance),
    events: [record],
    rules: [],
    exerciseYear: 2026,
  );
  final draft = _HrVacationEventDraft.fromRecord(record);
  _normalizeVacationEventDraft(draft);
  return _buildVacationCalculationPayloads(
    eventId: record.id,
    employeeId: record.employeeId,
    exerciseYear: 2026,
    event: draft,
    balance: _HrVacationBalanceDraft.fromSummaryRow(row),
  );
}
