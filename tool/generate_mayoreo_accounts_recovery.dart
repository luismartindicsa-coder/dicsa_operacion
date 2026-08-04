import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final config = _parseArgs(args);
  final snapshotDir = Directory(config.snapshotDir);
  if (!snapshotDir.existsSync()) {
    stderr.writeln('No existe snapshot-dir: ${snapshotDir.path}');
    exitCode = 2;
    return;
  }

  final outDir = Directory(config.outDir)..createSync(recursive: true);
  final upsertsDir = Directory('${outDir.path}/upserts')
    ..createSync(recursive: true);
  final highConfidenceUpsertsDir = Directory(
    '${outDir.path}/upserts_high_confidence',
  )..createSync(recursive: true);
  final mediumConfidenceUpsertsDir = Directory(
    '${outDir.path}/upserts_medium_confidence',
  )..createSync(recursive: true);

  final accounts = _readRows(
    File('${snapshotDir.path}/mayoreo_accounts.json'),
  ).map(MayoreoAccountRecord.fromJson).toList(growable: false);
  final bankMovements = _readRows(
    File('${snapshotDir.path}/finanzas_bank_movements.json'),
  ).map(BankMovementRecord.fromJson).toList(growable: false);
  final palomarMovements = _readRows(
    File('${snapshotDir.path}/mayoreo_palomar_movements.json'),
  ).map(PalomarMovementRecord.fromJson).toList(growable: false);

  final bankByAccountId = <String, _BankAccountRecovery>{};
  for (final movement in bankMovements) {
    if (movement.sourceType != 'VENTA_FACTURA') continue;
    final accountId = movement.linkedExternalRef.trim();
    if (accountId.isEmpty) continue;
    final next = bankByAccountId.putIfAbsent(
      accountId,
      () => _BankAccountRecovery(accountId: accountId),
    );
    next.totalCredit += movement.creditAmount;
    if (movement.movementDate != null) {
      if (next.latestMovementDate == null ||
          movement.movementDate!.isAfter(next.latestMovementDate!)) {
        next.latestMovementDate = movement.movementDate;
      }
    }
    if (movement.reference.trim().isNotEmpty) {
      next.references.add(_normalizeDocumentValue(movement.reference));
    }
  }

  final palomarAppliedByAccountId = <String, PalomarMovementRecord>{};
  for (final movement in palomarMovements) {
    if (movement.type != 'remisionAplicada') continue;
    final accountId = movement.sourceReportId.trim();
    if (accountId.isEmpty) continue;
    palomarAppliedByAccountId[accountId] = movement;
  }

  final reports = <RecoveryCandidate>[];
  final upserts = <Map<String, dynamic>>[];
  final highConfidenceUpserts = <Map<String, dynamic>>[];
  final mediumConfidenceUpserts = <Map<String, dynamic>>[];
  final totals = _RecoverySummaryBuckets();

  for (final account in accounts) {
    final candidate = _buildCandidate(
      account: account,
      bankRecovery: bankByAccountId[account.id],
      palomarApplied: palomarAppliedByAccountId[account.id],
    );
    if (candidate == null) continue;
    reports.add(candidate);
    upserts.add(candidate.toUpsertRow());
    switch (candidate.confidence) {
      case 'high':
        highConfidenceUpserts.add(candidate.toUpsertRow());
        break;
      case 'medium':
        mediumConfidenceUpserts.add(candidate.toUpsertRow());
        break;
    }
    totals.add(candidate);
  }

  reports.sort((a, b) {
    final confidenceOrder = _confidenceRank(
      a.confidence,
    ).compareTo(_confidenceRank(b.confidence));
    if (confidenceOrder != 0) return confidenceOrder;
    final typeOrder = a.recoveryType.compareTo(b.recoveryType);
    if (typeOrder != 0) return typeOrder;
    return a.id.compareTo(b.id);
  });

  final reportFile = File('${outDir.path}/report.json');
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(reports.map((row) => row.toJson()).toList(growable: false)),
  );

  final upsertsFile = File('${upsertsDir.path}/mayoreo_accounts.json');
  upsertsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(upserts),
  );
  final highConfidenceUpsertsFile = File(
    '${highConfidenceUpsertsDir.path}/mayoreo_accounts.json',
  );
  highConfidenceUpsertsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(highConfidenceUpserts),
  );
  final mediumConfidenceUpsertsFile = File(
    '${mediumConfidenceUpsertsDir.path}/mayoreo_accounts.json',
  );
  mediumConfidenceUpsertsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(mediumConfidenceUpserts),
  );

  final summaryFile = File('${outDir.path}/summary.json');
  summaryFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(totals.toJson()),
  );

  final csvFile = File('${outDir.path}/report.csv');
  csvFile.writeAsStringSync(_buildCsv(reports));

  stdout.writeln('Recuperacion generada en ${outDir.path}');
  stdout.writeln('Candidatos: ${reports.length}');
  stdout.writeln(
    'Alta confianza: ${totals.highConfidenceCount} '
    '(${_formatMoney(totals.highConfidenceAmount)})',
  );
  stdout.writeln(
    'Confianza media: ${totals.mediumConfidenceCount} '
    '(${_formatMoney(totals.mediumConfidenceAmount)})',
  );
}

Config _parseArgs(List<String> args) {
  var snapshotDir = 'backups/restore_20260803_pre_restore/full_public_snapshot';
  var outDir = 'backups/mayoreo_accounts_recovery_20260803';
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') || i + 1 >= args.length) continue;
    final value = args[i + 1];
    switch (arg) {
      case '--snapshot-dir':
        snapshotDir = value;
        break;
      case '--out-dir':
        outDir = value;
        break;
    }
    i += 1;
  }
  return Config(snapshotDir: snapshotDir, outDir: outDir);
}

RecoveryCandidate? _buildCandidate({
  required MayoreoAccountRecord account,
  required _BankAccountRecovery? bankRecovery,
  required PalomarMovementRecord? palomarApplied,
}) {
  const tolerance = 0.5;
  if (account.operationType == 'factura') {
    final effectivePaidAmount = bankRecovery?.totalCredit ?? account.paidAmount;
    final uniqueReference = bankRecovery?.singleReference ?? '';
    final observedReference = _extractObservedDocumentReference(
      account.saleNotes,
    );
    final recoveredDocumentNumber = account.documentNumber.isNotEmpty
        ? account.documentNumber
        : uniqueReference.isNotEmpty
        ? uniqueReference
        : observedReference;
    final recoveredSettlementDate =
        bankRecovery?.latestMovementDate ?? account.settlementDate;
    if (effectivePaidAmount > tolerance) {
      final recoveredStatus =
          effectivePaidAmount >= account.approvedAmount - tolerance
          ? 'pagada'
          : 'pagoParcial';
      final changes = <String, dynamic>{'id': account.id};
      var changed = false;
      if ((effectivePaidAmount - account.paidAmount).abs() > 0.009) {
        changes['paid_amount'] = _normalizeAmount(effectivePaidAmount);
        changed = true;
      }
      if (account.status != recoveredStatus) {
        changes['status'] = recoveredStatus;
        changed = true;
      }
      if (recoveredSettlementDate != null &&
          !_sameDateTime(account.settlementDate, recoveredSettlementDate)) {
        changes['settlement_date'] = recoveredSettlementDate.toIso8601String();
        changed = true;
      }
      if (account.documentNumber.isEmpty &&
          recoveredDocumentNumber.isNotEmpty) {
        changes['document_number'] = recoveredDocumentNumber;
        changed = true;
      }
      if (!changed) return null;
      return RecoveryCandidate(
        id: account.id,
        clientName: account.clientName,
        operationType: account.operationType,
        recoveryType: 'factura_pagada_por_banco',
        confidence: 'high',
        currentStatus: account.status,
        recoveredStatus: recoveredStatus,
        currentApprovedAmount: account.approvedAmount,
        recoveredApprovedAmount: account.approvedAmount,
        currentPaidAmount: account.paidAmount,
        recoveredPaidAmount: effectivePaidAmount,
        currentDocumentNumber: account.documentNumber,
        recoveredDocumentNumber: recoveredDocumentNumber,
        currentSettlementDate: account.settlementDate,
        recoveredSettlementDate: recoveredSettlementDate,
        evidence: <String>[
          'finanzas_bank_movements:VENTA_FACTURA',
          if (uniqueReference.isNotEmpty) 'bank_reference:$uniqueReference',
        ],
        changes: changes,
      );
    }

    if (account.status == 'pendienteFactura' &&
        recoveredDocumentNumber.isNotEmpty) {
      final changes = <String, dynamic>{
        'id': account.id,
        'status': 'facturadaPendientePago',
      };
      if (account.documentNumber.isEmpty) {
        changes['document_number'] = recoveredDocumentNumber;
      }
      return RecoveryCandidate(
        id: account.id,
        clientName: account.clientName,
        operationType: account.operationType,
        recoveryType: 'factura_con_folio_en_observaciones',
        confidence: 'medium',
        currentStatus: account.status,
        recoveredStatus: 'facturadaPendientePago',
        currentApprovedAmount: account.approvedAmount,
        recoveredApprovedAmount: account.approvedAmount,
        currentPaidAmount: account.paidAmount,
        recoveredPaidAmount: account.paidAmount,
        currentDocumentNumber: account.documentNumber,
        recoveredDocumentNumber: recoveredDocumentNumber,
        currentSettlementDate: account.settlementDate,
        recoveredSettlementDate: account.settlementDate,
        evidence: <String>['sale_notes:${account.saleNotes}'],
        changes: changes,
      );
    }
    return null;
  }

  if (palomarApplied != null) {
    final changes = <String, dynamic>{'id': account.id};
    var changed = false;
    if (account.status != 'chequeCanjeado') {
      changes['status'] = 'chequeCanjeado';
      changed = true;
    }
    if ((account.paidAmount - account.approvedAmount).abs() > 0.009) {
      changes['paid_amount'] = _normalizeAmount(account.approvedAmount);
      changed = true;
    }
    if (!_sameDateTime(account.settlementDate, palomarApplied.date)) {
      changes['settlement_date'] = palomarApplied.date.toIso8601String();
      changed = true;
    }
    if (!changed) return null;
    return RecoveryCandidate(
      id: account.id,
      clientName: account.clientName,
      operationType: account.operationType,
      recoveryType: 'cheque_canjeado_palomar',
      confidence: 'high',
      currentStatus: account.status,
      recoveredStatus: 'chequeCanjeado',
      currentApprovedAmount: account.approvedAmount,
      recoveredApprovedAmount: account.approvedAmount,
      currentPaidAmount: account.paidAmount,
      recoveredPaidAmount: account.approvedAmount,
      currentDocumentNumber: account.documentNumber,
      recoveredDocumentNumber: account.documentNumber,
      currentSettlementDate: account.settlementDate,
      recoveredSettlementDate: palomarApplied.date,
      evidence: <String>[
        'mayoreo_palomar_movements:remisionAplicada',
        'source_report_id:${palomarApplied.sourceReportId}',
      ],
      changes: changes,
    );
  }

  return null;
}

int _confidenceRank(String value) {
  return switch (value) {
    'high' => 0,
    'medium' => 1,
    _ => 9,
  };
}

String _extractObservedDocumentReference(String input) {
  final normalized = input.trim().toUpperCase();
  if (normalized.isEmpty) return '';
  final match = RegExp(
    r'\b(?:FACT(?:URA)?\.?\s*)([A-Z]-?\d+)\b',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) return '';
  return _normalizeDocumentValue(match.group(1) ?? '');
}

String _normalizeDocumentValue(String value) {
  return value.trim().toUpperCase().replaceAll(' ', '');
}

double _normalizeAmount(double value) {
  return (value * 100).roundToDouble() / 100;
}

bool _sameDateTime(DateTime? left, DateTime? right) {
  if (left == null && right == null) return true;
  if (left == null || right == null) return false;
  return left.toUtc() == right.toUtc();
}

List<Map<String, dynamic>> _readRows(File file) {
  if (!file.existsSync()) {
    stderr.writeln('No existe ${file.path}');
    exit(2);
  }
  final raw = file.readAsStringSync().trim();
  if (raw.isEmpty) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    stderr.writeln('Se esperaba una lista JSON en ${file.path}');
    exit(2);
  }
  return decoded
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row.cast<String, dynamic>()))
      .toList(growable: false);
}

String _buildCsv(List<RecoveryCandidate> rows) {
  final buffer = StringBuffer();
  final headers = <String>[
    'id',
    'cliente',
    'tipo',
    'recovery_type',
    'confidence',
    'current_status',
    'recovered_status',
    'approved_amount',
    'current_paid_amount',
    'recovered_paid_amount',
    'current_document_number',
    'recovered_document_number',
    'current_settlement_date',
    'recovered_settlement_date',
    'evidence',
  ];
  buffer.writeln(headers.map(_csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(
      <String>[
        row.id,
        row.clientName,
        row.operationType,
        row.recoveryType,
        row.confidence,
        row.currentStatus,
        row.recoveredStatus,
        _formatMoney(row.currentApprovedAmount),
        _formatMoney(row.currentPaidAmount),
        _formatMoney(row.recoveredPaidAmount),
        row.currentDocumentNumber,
        row.recoveredDocumentNumber,
        row.currentSettlementDate?.toIso8601String() ?? '',
        row.recoveredSettlementDate?.toIso8601String() ?? '',
        row.evidence.join(' | '),
      ].map(_csvCell).join(','),
    );
  }
  return buffer.toString();
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _formatMoney(double value) => value.toStringAsFixed(2);

class Config {
  const Config({required this.snapshotDir, required this.outDir});

  final String snapshotDir;
  final String outDir;
}

class MayoreoAccountRecord {
  const MayoreoAccountRecord({
    required this.id,
    required this.operationType,
    required this.status,
    required this.clientName,
    required this.approvedAmount,
    required this.paidAmount,
    required this.documentNumber,
    required this.saleNotes,
    required this.settlementDate,
  });

  factory MayoreoAccountRecord.fromJson(Map<String, dynamic> json) {
    return MayoreoAccountRecord(
      id: (json['id'] as String?)?.trim() ?? '',
      operationType: (json['operation_type'] as String?)?.trim() ?? 'factura',
      status: (json['status'] as String?)?.trim() ?? 'porRevisar',
      clientName: (json['client_name_snapshot'] as String?)?.trim() ?? '',
      approvedAmount: ((json['approved_amount'] as num?) ?? 0).toDouble(),
      paidAmount: ((json['paid_amount'] as num?) ?? 0).toDouble(),
      documentNumber: _normalizeDocumentValue(
        (json['document_number'] as String?) ?? '',
      ),
      saleNotes: (json['sale_notes'] as String?)?.trim() ?? '',
      settlementDate: _tryParseDateTime(json['settlement_date'] as String?),
    );
  }

  final String id;
  final String operationType;
  final String status;
  final String clientName;
  final double approvedAmount;
  final double paidAmount;
  final String documentNumber;
  final String saleNotes;
  final DateTime? settlementDate;
}

class BankMovementRecord {
  const BankMovementRecord({
    required this.sourceType,
    required this.linkedExternalRef,
    required this.creditAmount,
    required this.reference,
    required this.movementDate,
  });

  factory BankMovementRecord.fromJson(Map<String, dynamic> json) {
    return BankMovementRecord(
      sourceType: (json['source_type'] as String?)?.trim() ?? '',
      linkedExternalRef: (json['linked_external_ref'] as String?)?.trim() ?? '',
      creditAmount: ((json['credit_amount'] as num?) ?? 0).toDouble(),
      reference: (json['reference'] as String?)?.trim() ?? '',
      movementDate: _tryParseDateTime(json['movement_date'] as String?),
    );
  }

  final String sourceType;
  final String linkedExternalRef;
  final double creditAmount;
  final String reference;
  final DateTime? movementDate;
}

class PalomarMovementRecord {
  const PalomarMovementRecord({
    required this.type,
    required this.sourceReportId,
    required this.date,
  });

  factory PalomarMovementRecord.fromJson(Map<String, dynamic> json) {
    return PalomarMovementRecord(
      type: (json['type'] as String?)?.trim() ?? '',
      sourceReportId: (json['source_report_id'] as String?)?.trim() ?? '',
      date: _tryParseDateTime(json['date'] as String?) ?? DateTime.now(),
    );
  }

  final String type;
  final String sourceReportId;
  final DateTime date;
}

class _BankAccountRecovery {
  _BankAccountRecovery({required this.accountId});

  final String accountId;
  double totalCredit = 0;
  DateTime? latestMovementDate;
  final Set<String> references = <String>{};

  String get singleReference => references.length == 1 ? references.first : '';
}

class RecoveryCandidate {
  const RecoveryCandidate({
    required this.id,
    required this.clientName,
    required this.operationType,
    required this.recoveryType,
    required this.confidence,
    required this.currentStatus,
    required this.recoveredStatus,
    required this.currentApprovedAmount,
    required this.recoveredApprovedAmount,
    required this.currentPaidAmount,
    required this.recoveredPaidAmount,
    required this.currentDocumentNumber,
    required this.recoveredDocumentNumber,
    required this.currentSettlementDate,
    required this.recoveredSettlementDate,
    required this.evidence,
    required this.changes,
  });

  final String id;
  final String clientName;
  final String operationType;
  final String recoveryType;
  final String confidence;
  final String currentStatus;
  final String recoveredStatus;
  final double currentApprovedAmount;
  final double recoveredApprovedAmount;
  final double currentPaidAmount;
  final double recoveredPaidAmount;
  final String currentDocumentNumber;
  final String recoveredDocumentNumber;
  final DateTime? currentSettlementDate;
  final DateTime? recoveredSettlementDate;
  final List<String> evidence;
  final Map<String, dynamic> changes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'clientName': clientName,
      'operationType': operationType,
      'recoveryType': recoveryType,
      'confidence': confidence,
      'currentStatus': currentStatus,
      'recoveredStatus': recoveredStatus,
      'currentApprovedAmount': _normalizeAmount(currentApprovedAmount),
      'recoveredApprovedAmount': _normalizeAmount(recoveredApprovedAmount),
      'currentPaidAmount': _normalizeAmount(currentPaidAmount),
      'recoveredPaidAmount': _normalizeAmount(recoveredPaidAmount),
      'currentDocumentNumber': currentDocumentNumber,
      'recoveredDocumentNumber': recoveredDocumentNumber,
      'currentSettlementDate': currentSettlementDate?.toIso8601String(),
      'recoveredSettlementDate': recoveredSettlementDate?.toIso8601String(),
      'evidence': evidence,
      'changes': changes,
    };
  }

  Map<String, dynamic> toUpsertRow() => changes;
}

class _RecoverySummaryBuckets {
  int totalCount = 0;
  double totalAmount = 0;
  int highConfidenceCount = 0;
  double highConfidenceAmount = 0;
  int mediumConfidenceCount = 0;
  double mediumConfidenceAmount = 0;
  final Map<String, int> countByType = <String, int>{};
  final Map<String, double> amountByType = <String, double>{};

  void add(RecoveryCandidate candidate) {
    totalCount += 1;
    totalAmount += candidate.currentApprovedAmount;
    countByType.update(
      candidate.recoveryType,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    amountByType.update(
      candidate.recoveryType,
      (value) => value + candidate.currentApprovedAmount,
      ifAbsent: () => candidate.currentApprovedAmount,
    );
    if (candidate.confidence == 'high') {
      highConfidenceCount += 1;
      highConfidenceAmount += candidate.currentApprovedAmount;
    } else if (candidate.confidence == 'medium') {
      mediumConfidenceCount += 1;
      mediumConfidenceAmount += candidate.currentApprovedAmount;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'totalCount': totalCount,
      'totalAmount': _normalizeAmount(totalAmount),
      'highConfidenceCount': highConfidenceCount,
      'highConfidenceAmount': _normalizeAmount(highConfidenceAmount),
      'mediumConfidenceCount': mediumConfidenceCount,
      'mediumConfidenceAmount': _normalizeAmount(mediumConfidenceAmount),
      'countByType': countByType,
      'amountByType': amountByType.map(
        (key, value) => MapEntry(key, _normalizeAmount(value)),
      ),
    };
  }
}

DateTime? _tryParseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}
