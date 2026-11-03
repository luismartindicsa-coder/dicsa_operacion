import 'dart:convert';
import 'package:crypto/crypto.dart';

typedef StatementRow = Map<String, dynamic>;

String stText(dynamic v) => (v ?? '').toString().trim();
double stNumber(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(stText(v)) ?? 0;
String stKey(dynamic v) => stText(v)
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll(RegExp(r'\s+'), ' ');

/// These database values describe an operating calendar day, even when older
/// captures serialized midnight with a UTC suffix. Never shift them to local time.
DateTime? stDate(dynamic v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(stText(v));
  if (m == null) return null;
  final y = int.parse(m[1]!), month = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, month, d);
  return date.year == y && date.month == month && date.day == d ? date : null;
}

String stDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String stSignature(dynamic value) {
  dynamic canonical(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}

class StatementPeriod {
  final DateTime start, end;
  StatementPeriod(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (this.end.isBefore(this.start) ||
        this.end.difference(this.start).inDays > 365) {
      throw ArgumentError('Selecciona un periodo de hasta 366 días.');
    }
  }
  String get key => '${stDay(start)}:${stDay(end)}';
  bool contains(DateTime? d) =>
      d != null && !d.isBefore(start) && !d.isAfter(end);
  bool includes(dynamic d) => contains(stDate(d));
}

enum StatementAccount {
  sales('Venta neta'),
  otherIncome('Otro ingreso real'),
  cost('Costo de ventas'),
  operating('Gasto operativo'),
  administrative('Gasto administrativo'),
  payroll('Costo laboral'),
  financial('Resultado financiero neto'),
  depreciation('Depreciación y amortización'),
  incomeTax('Impuesto a la utilidad'),
  balance('Activo, pasivo, capital o traspaso'),
  duplicate('Liquidación u operación ya reconocida'),
  pending('Pendiente de aclarar');

  final String label;
  const StatementAccount(this.label);
  bool get income => this == sales || this == otherIncome;
  bool get expense => [
    cost,
    operating,
    administrative,
    payroll,
    financial,
    depreciation,
    incomeTax,
  ].contains(this);
  bool get affectsResult => income || expense;
}

class StatementFact {
  final String id, source, label, detail, signature;
  final String automaticRule;
  final DateTime? date;
  final double amount;
  final StatementAccount account;
  final bool estimated, reviewRequired, includeWhilePending;
  final List<String> references;
  StatementFact({
    required this.id,
    required this.source,
    required this.label,
    required this.date,
    required this.amount,
    required this.account,
    required this.detail,
    required dynamic evidence,
    this.automaticRule = '',
    this.estimated = false,
    this.reviewRequired = false,
    this.includeWhilePending = false,
    this.references = const [],
  }) : signature = stSignature(evidence);
}

class StatementDecision {
  final String id, signature, note, duplicateOf;
  final int revision;
  final StatementAccount account;
  final double amount;
  final bool estimated;
  final DateTime? economicDate;
  const StatementDecision({
    required this.id,
    required this.signature,
    required this.note,
    required this.account,
    required this.amount,
    this.duplicateOf = '',
    this.revision = 0,
    this.estimated = false,
    this.economicDate,
  });
  factory StatementDecision.fromRow(StatementRow r) => StatementDecision(
    id: stText(r['id']),
    signature: stText(r['source_signature']),
    note: stText(r['note']),
    account: StatementAccount.values.byName(stText(r['account'])),
    amount: stNumber(r['amount']),
    duplicateOf: stText(r['duplicate_of']),
    revision: (r['revision'] as num).toInt(),
    estimated: r['estimated'] == true,
    economicDate: stDate(r['economic_date']),
  );
  StatementRow toRow() => {
    'id': id,
    'source_signature': signature,
    'note': note,
    'account': account.name,
    'amount': amount,
    'duplicate_of': duplicateOf,
    'estimated': estimated,
    'economic_date': economicDate == null ? null : stDay(economicDate!),
  };
  void validate() {
    if (id.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(signature) ||
        note.trim().isEmpty ||
        !amount.isFinite ||
        amount.abs() > 1e12) {
      throw StateError('Completa importe y fundamento de la clasificación.');
    }
    if (account == StatementAccount.duplicate &&
        (duplicateOf.isEmpty || duplicateOf == id)) {
      throw StateError('Vincula la operación que ya reconoce este importe.');
    }
    final periodKey = RegExp(
      r'^(?:cost|payroll|payroll-coverage|payroll-payments|service-coverage|fuel-coverage):(\d{4}-\d{2}-\d{2}):(\d{4}-\d{2}-\d{2})',
    ).firstMatch(id);
    if (periodKey != null &&
        economicDate != null &&
        !StatementPeriod(
          stDate(periodKey[1])!,
          stDate(periodKey[2])!,
        ).contains(economicDate)) {
      throw StateError(
        'Un cálculo del periodo debe permanecer dentro de sus fechas. Registra un ajuste documentado para otro periodo.',
      );
    }
  }
}

class StatementEntry {
  final StatementFact fact;
  final StatementDecision? decision;
  final String? issue;
  const StatementEntry(this.fact, this.decision, [this.issue]);
  bool get pending =>
      issue != null ||
      (decision == null &&
          (fact.reviewRequired || fact.account == StatementAccount.pending)) ||
      decision?.account == StatementAccount.pending;
  bool get includedPending =>
      pending &&
      issue == null &&
      decision == null &&
      fact.includeWhilePending &&
      fact.estimated &&
      fact.account.expense &&
      fact.date != null;
  StatementAccount get account => pending && !includedPending
      ? StatementAccount.pending
      : decision?.account ?? fact.account;
  double get amount => decision?.amount ?? fact.amount;
  bool get estimated => decision?.estimated ?? fact.estimated;
  bool get automatic =>
      (!pending || includedPending) &&
      decision == null &&
      fact.automaticRule.isNotEmpty;
  double get impact => account.income
      ? amount
      : account.expense
      ? -amount
      : 0;
}

const statementClosingChecks = <String, String>{
  'scope': 'Razones sociales y operaciones entre empresas conciliadas',
  'sales': 'Entregas, devoluciones y servicios del periodo completos',
  'material': 'Entradas y Salidas, apertura, rendimientos y costo conciliados',
  'expenses': 'Facturas, vales, mantenimiento y combustible sin duplicaciones',
  'payroll': 'Nómina devengada, retenciones y cargas patronales completas',
  'tax': 'Bases sin IVA, retenciones e impuesto a la utilidad revisados',
  'accruals': 'Depreciación, provisiones y obligaciones pendientes registradas',
  'cash': 'Bancos, cajas y cuentas por cobrar y pagar conciliados',
};

class StatementClosing {
  final int revision;
  final String signature, note;
  final Set<String> checks;
  final List<StatementRow> adjustments;
  final StatementRow snapshot;
  const StatementClosing({
    this.revision = 0,
    this.signature = '',
    this.note = '',
    this.checks = const {},
    this.adjustments = const [],
    this.snapshot = const {},
  });
  factory StatementClosing.fromRow(StatementRow r) {
    final p = Map<String, dynamic>.from(r['payload'] as Map);
    return StatementClosing(
      revision: (r['revision'] as num).toInt(),
      signature: stText(p['signature']),
      note: stText(p['note']),
      checks: (p['checks'] as List? ?? []).map(stText).toSet(),
      adjustments: (p['adjustments'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      snapshot: Map<String, dynamic>.from(p['snapshot'] as Map? ?? {}),
    );
  }
  StatementRow toJson() => {
    'signature': signature,
    'note': note,
    'checks': checks.toList()..sort(),
    'adjustments': adjustments,
    'snapshot': snapshot,
  };
}

class StatementMaterial {
  final String key, label;
  double purchasedKg = 0,
      purchases = 0,
      receivedKg = 0,
      dispatchedKg = 0,
      soldKg = 0;
  int recoveries = 0;
  StatementMaterial(this.key, this.label);
  double? get average => purchasedKg > 0 ? purchases / purchasedKg : null;
  double? get estimatedCost => average == null ? null : dispatchedKg * average!;
  StatementRow toJson() => {
    'family': key,
    'purchased_kg': purchasedKg,
    'purchases': purchases,
    'received_kg': receivedKg,
    'dispatched_kg': dispatchedKg,
    'sold_kg': soldKg,
    'recoveries': recoveries,
  };
}

class StatementBundle {
  final StatementPeriod period;
  final Map<String, List<StatementRow>> tables;
  final Map<String, StatementDecision> decisions;
  final StatementClosing closing;
  final bool canManage;
  const StatementBundle({
    required this.period,
    required this.tables,
    this.decisions = const {},
    this.closing = const StatementClosing(),
    this.canManage = false,
  });
  List<StatementRow> rows(String table) => tables[table] ?? const [];
}

class StatementAnalysis {
  final StatementBundle bundle;
  final List<StatementEntry> entries;
  final List<StatementMaterial> materials;
  final List<String> warnings;
  final String signature;
  const StatementAnalysis({
    required this.bundle,
    required this.entries,
    required this.materials,
    required this.warnings,
    required this.signature,
  });
  double total(StatementAccount a) =>
      entries.where((e) => e.account == a).fold(0, (s, e) => s + e.amount);
  double get result => entries.fold(0, (s, e) => s + e.impact);
  List<StatementEntry> get pending => entries.where((e) => e.pending).toList();
  int get automaticCount => entries.where((e) => e.automatic).length;
  double get pendingAmount =>
      pending.fold(0, (s, e) => s + e.fact.amount.abs());
  bool get estimated =>
      entries.any((e) => e.account.affectsResult && e.estimated);
  bool get closingCurrent =>
      bundle.closing.signature == signature &&
      bundle.closing.snapshot['source_signature'] == signature &&
      bundle.closing.snapshot['engine_version'] == 1 &&
      bundle.closing.snapshot['pending_count'] == 0 &&
      bundle.closing.snapshot['estimated'] == false &&
      bundle.closing.note.trim().isNotEmpty &&
      statementClosingChecks.keys.every(bundle.closing.checks.contains);
  bool get complete =>
      pending.isEmpty && warnings.isEmpty && !estimated && closingCurrent;
  String get resultLabel => complete
      ? 'Utilidad neta revisada'
      : 'Resultado provisional · no es utilidad neta';
  String get status => complete
      ? 'Cierre revisado'
      : pending.isNotEmpty || warnings.isNotEmpty
      ? 'Conciliación pendiente'
      : estimated
      ? 'Costos estimados'
      : 'Cierre pendiente';

  StatementRow toSnapshot() => {
    'engine_version': 1,
    'period_start': stDay(bundle.period.start),
    'period_end': stDay(bundle.period.end),
    'source_signature': signature,
    'result': result,
    'pending_count': pending.length,
    'estimated': estimated,
    'entries': [
      for (final e in entries)
        {
          'id': e.fact.id,
          'source': e.fact.source,
          'label': e.fact.label,
          'signature': e.fact.signature,
          'account': e.account.name,
          'amount': e.amount,
          'estimated': e.estimated,
          'pending': e.pending,
          'included_pending': e.includedPending,
          'date': (e.decision?.economicDate ?? e.fact.date) == null
              ? null
              : stDay((e.decision?.economicDate ?? e.fact.date)!),
          'note': e.decision?.note ?? e.fact.detail,
          if (e.automatic) 'automatic_rule': e.fact.automaticRule,
        },
    ],
    'materials': materials.map((m) => m.toJson()).toList(),
  };
}
