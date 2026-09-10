part of '../human_resources_nomina_page.dart';

/// Uses the actual page and modal while replacing only external I/O.
@visibleForTesting
Widget hrNominaForTesting({
  required List<Map<String, dynamic>> drafts,
  required String period,
  bool closed = true,
  Map<String, String> personalFiscalModes = const {},
  required ValueChanged<Map<String, dynamic>> onSnapshot,
  required ValueChanged<String> onAction,
}) => _NominaFixture(
  drafts: drafts,
  period: period,
  closed: closed,
  personalFiscalModes: personalFiscalModes,
  onSnapshot: onSnapshot,
  onAction: onAction,
);

class _NominaFixture extends HumanResourcesNominaPage {
  final List<Map<String, dynamic>> drafts;
  final String period;
  final bool closed;
  final Map<String, String> personalFiscalModes;
  final ValueChanged<Map<String, dynamic>> onSnapshot;
  final ValueChanged<String> onAction;
  const _NominaFixture({
    required this.drafts,
    required this.period,
    required this.closed,
    required this.personalFiscalModes,
    required this.onSnapshot,
    required this.onAction,
  }) : super(instantOpen: true);
  @override
  State<HumanResourcesNominaPage> createState() => _NominaFixtureState();
}

class _NominaFixtureState extends _HumanResourcesNominaPageState {
  _NominaFixture get fixture => widget as _NominaFixture;
  @override
  Future<void> _resolveNavigationAccess() async {}
  @override
  Future<void> _loadData() async {
    _activePeriodLabel = fixture.period;
    _periodOptions = [fixture.period];
    _draftRows = fixture.drafts.map(_HrNominaDraftRecord.fromRow).toList();
    _periodClosures = [
      _HrNominaPeriodClosure(
        id: 'closure',
        periodLabel: fixture.period,
        status: fixture.closed ? 'cerrado' : 'abierto',
      ),
    ];
    _allRows = _buildNominaRows(
      draftRows: _draftRows,
      activePeriodLabel: fixture.period,
      personalFiscalModes: fixture.personalFiscalModes,
      isPeriodClosed: fixture.closed,
    );
    _rebuildVisibleRows();
  }

  @override
  void _rebuildVisibleRows() {
    super._rebuildVisibleRows();
    final metrics = _HrNominaMetrics.fromRows(_allRows);
    fixture.onSnapshot({
      'count': _allRows.length,
      'filtered': _filteredRows.length,
      'visible': _visibleRows.length,
      'page': _currentPage,
      'fiscal': metrics.fiscal,
      'deposit': metrics.fiscalDeposited,
      'cheque': metrics.fiscalCash,
      'flow': metrics.total - metrics.fiscal,
      'total': metrics.total,
      'rows': [
        for (final r in _allRows)
          {
            'id': r.employeeId,
            'fiscal': r.fiscalAmount,
            'flow': _nominaFlow(r),
            'deductions': r.deductionsAmount,
            'total': r.totalAmount,
            'status': r.statusLabel,
          },
      ],
    });
  }

  @override
  Future<void> _exportPeriodPayrollReportPdf() async {
    fixture.onAction('period-pdf');
  }

  @override
  Future<void> _openPrenomina() async {
    fixture.onAction('prenomina');
  }

  @override
  Future<void> _generatePayrollReceipt(_HrNominaSummaryRow row) async {
    fixture.onAction('receipt:${row.employeeId}');
  }
}

@visibleForTesting
Map<String, dynamic> hrNominaOfficialNetForTesting(Map<String, dynamic> draft) {
  final period = draft['period_label'] as String;
  final row = _buildNominaRows(
    draftRows: [_HrNominaDraftRecord.fromRow(draft)],
    activePeriodLabel: period,
  ).single;
  final receipt = _HrNominaReceiptSnapshot.fromSummaryRow(
    row: row,
    periodLabel: period,
    issuedAt: DateTime(2026, 9, 8),
    version: 1,
  );
  return {
    'fiscal': row.fiscalAmount,
    'total': row.totalAmount,
    'receipt_total': receipt.totalAmount,
    'receipt_deductions': receipt.deductions,
    'informational': receipt.incidencesInformational,
  };
}

@visibleForTesting
Map<String, dynamic> hrNominaFiscalTotalsForTesting({
  required List<Map<String, dynamic>> drafts,
  required String period,
  Map<String, String> personalFiscalModes = const {},
  bool closed = false,
}) {
  final rows = _buildNominaRows(
    draftRows: drafts.map(_HrNominaDraftRecord.fromRow).toList(),
    activePeriodLabel: period,
    personalFiscalModes: personalFiscalModes,
    isPeriodClosed: closed,
  );
  final metrics = _HrNominaMetrics.fromRows(rows);
  return {
    'fiscal': metrics.fiscal,
    'deposit': metrics.fiscalDeposited,
    'cheque': metrics.fiscalCash,
    'total': metrics.total,
    'rows': [
      for (final row in rows)
        {
          'id': row.employeeId,
          'fiscal': row.fiscalAmount,
          'deposit': row.fiscalDepositedAmount,
          'cheque': row.fiscalCashAmount,
          'channel': row.paymentChannelLabel,
          'total': row.totalAmount,
        },
    ],
  };
}

@visibleForTesting
Future<Uint8List> hrNominaPeriodReportPdfForTesting({
  required List<Map<String, dynamic>> drafts,
  required String period,
  Map<String, String> personalFiscalModes = const {},
  bool closed = false,
  DateTime? generatedAt,
}) {
  final rows = _buildNominaRows(
    draftRows: drafts.map(_HrNominaDraftRecord.fromRow).toList(),
    activePeriodLabel: period,
    personalFiscalModes: personalFiscalModes,
    isPeriodClosed: closed,
  );
  return _buildHrNominaPeriodReportPdf(
    rows: rows,
    metrics: _HrNominaMetrics.fromRows(rows),
    periodLabel: period,
    generatedAt: generatedAt ?? DateTime(2026, 9, 8),
    isPeriodClosed: closed,
  );
}

@visibleForTesting
Future<Uint8List> hrNominaManualFiscalReceiptForTesting(
  Map<String, dynamic> draft,
) {
  final period = draft['period_label'] as String;
  final row = _buildNominaRows(
    draftRows: [_HrNominaDraftRecord.fromRow(draft)],
    activePeriodLabel: period,
  ).single;
  final snapshot = _HrNominaReceiptSnapshot.fromSummaryRow(
    row: row,
    periodLabel: period,
    issuedAt: DateTime(2026, 9, 10),
    version: 1,
  );
  return _buildHrNominaReceiptPdf(
    _HrNominaReceiptSnapshot.tryFromJson(snapshot.toJson())!,
  );
}
