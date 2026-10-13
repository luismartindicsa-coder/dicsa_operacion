import 'dart:math' as math;

import '../direction_shipments_store.dart';
import 'expected_income_models.dart';

DateTime _weekStart(DateTime date) =>
    incomeDay(date).subtract(Duration(days: date.weekday - 1));

class PalomarCoverageWeek {
  final DateTime week;
  final int opening, charges, credits;
  const PalomarCoverageWeek(
    this.week,
    this.opening,
    this.charges,
    this.credits,
  );
  int get closing => opening + charges - credits;
}

class PalomarCoverageEvent {
  final DateTime date;
  final int? signedCents;
  final String description;
  final String? material;
  final int? quantity;
  final String unit;
  final bool alreadyShipped;
  const PalomarCoverageEvent(
    this.date,
    this.signedCents,
    this.description, {
    this.material,
    this.quantity,
    this.unit = '',
    this.alreadyShipped = false,
  });
}

class PalomarCoverageSend {
  final DateTime date;
  final String? material;
  final int? quantity, amount;
  final String unit;
  final String status;
  final bool additional;
  const PalomarCoverageSend({
    required this.date,
    required this.material,
    required this.quantity,
    this.unit = '',
    required this.amount,
    required this.status,
    required this.additional,
  });
}

class PalomarCoverageNeed {
  final DateTime week, sendBy;
  final int amount;
  const PalomarCoverageNeed(this.week, this.sendBy, this.amount);
}

class PalomarCoverage {
  final DateTime cutoff;
  final DateTime? deadline;
  final int balance, projectedBalance;
  final List<PalomarCoverageWeek> history;
  final List<PalomarCoverageEvent> events;
  final List<PalomarCoverageNeed> needs;
  final List<String> warnings;
  final Map<String, PalomarMaterialQuote> quotes;
  final String? preferredMaterial;
  final bool complete;
  const PalomarCoverage({
    required this.cutoff,
    required this.deadline,
    required this.balance,
    required this.projectedBalance,
    required this.history,
    required this.events,
    required this.needs,
    required this.warnings,
    required this.quotes,
    required this.preferredMaterial,
    required this.complete,
  });
  int get remaining => math.max(0, projectedBalance);

  List<String> get selectableMaterials =>
      quotes.entries.where((e) => e.value.usable).map((e) => e.key).toList();
  String materialLabel(String? code) =>
      quotes[code]?.label ??
      (code == null
          ? 'Por definir'
          : directionShipmentMaterialByCode(code)?.label ?? code);

  /// Only goods still to send. Posted remittances and goods already shipped
  /// remain in the account balance, not in the dispatch checklist.
  List<PalomarCoverageSend> sends(String? material) {
    final quote = quotes[material];
    return [
      for (final e in events)
        if (e.material != null && !e.alreadyShipped)
          PalomarCoverageSend(
            date: e.date,
            material: e.material,
            quantity: e.quantity,
            unit: e.unit,
            amount: e.signedCents?.abs(),
            status: e.description,
            additional: false,
          ),
      for (final need in needs)
        PalomarCoverageSend(
          date: need.sendBy,
          material: material,
          quantity: quote?.quantityFor(need.amount),
          unit: quote?.unit ?? '',
          amount: quote?.usable == true
              ? quote!.amount(quote.quantityFor(need.amount)!)
              : null,
          status: 'Adicional por programar',
          additional: true,
        ),
    ]..sort((a, b) {
      final date = b.date.compareTo(a.date);
      if (date != 0) return date;
      final name = (a.material ?? '').compareTo(b.material ?? '');
      return name != 0
          ? name
          : (a.additional ? 1 : 0).compareTo(b.additional ? 1 : 0);
    });
  }

  int? balanceWithSends(String? material) {
    final extra = sends(material).where((s) => s.additional);
    if (!complete || extra.any((s) => s.amount == null)) return null;
    return projectedBalance - extra.fold<int>(0, (sum, s) => sum + s.amount!);
  }
}

/// Account history is posted ledger only. Future coverage is an explicit
/// scenario; it never writes shipments or adds a second draw to weekly income.
PalomarCoverage projectPalomarCoverage({
  required ExpectedIncomeData data,
  required DirectionShipmentPlanningBundle bundle,
  required DateTime now,
  // The informational material table covers the posted balance. Forecast mode
  // additionally reconciles the agenda and expected adjustments.
  bool includeForecast = true,
}) {
  final today = incomeDay(now);
  final week = bundle.weekStartDate;
  final schedule = data.palomarSchedule;
  final dates = schedule != null && schedule.valid && schedule.week == week
      ? [schedule.cashDate, schedule.fiscalDate].whereType<DateTime>().toList()
      : <DateTime>[];
  dates.sort();
  final deadline = dates.firstOrNull;
  final limit = deadline ?? week.add(const Duration(days: 6));
  final cutoff = today.isBefore(limit) ? today : limit;
  final ledger =
      data.palomarMovements
          .where((m) => !m.projected && !m.date.isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final history = <PalomarCoverageWeek>[];
  var balance = 0;
  if (ledger.isNotEmpty) {
    for (
      var date = _weekStart(ledger.first.date);
      !date.isAfter(cutoff);
      date = date.add(const Duration(days: 7))
    ) {
      final next = date.add(const Duration(days: 7));
      var charges = 0, credits = 0;
      for (final m in ledger.where(
        (m) => !m.date.isBefore(date) && m.date.isBefore(next),
      )) {
        if (m.signedCents > 0) {
          charges += m.signedCents;
        } else {
          credits -= m.signedCents;
        }
      }
      final row = PalomarCoverageWeek(date, balance, charges, credits);
      history.add(row);
      balance = row.closing;
    }
  }
  final rule = data.ruleFor('EL PALOMAR');
  final quotes = <String, PalomarMaterialQuote>{
    for (final quote in data.palomarCoverageMaterials) quote.code: quote,
  };
  // Existing carton prices are per kg; convert only with configured bale weight.
  for (final m in data.materials) {
    final price =
        data.clientMaterialPrices['${rule?.key}|${m.material}'] ??
        rule?.price ??
        m.price;
    if (rule?.active == true &&
        rule?.revolving == true &&
        m.kgPerBale > 0 &&
        (quotes[m.material] == null || quotes[m.material]!.unit == 'kg')) {
      quotes[m.material] = PalomarMaterialQuote(
        m.material,
        incomeMaterialName(m.material),
        'pacas',
        price == null ? null : price * m.kgPerBale,
      );
    }
  }
  final events = <PalomarCoverageEvent>[];
  final warnings = <String>[];
  var complete = true;
  if (includeForecast && deadline != null && !deadline.isBefore(today)) {
    // Applied references include future-dated postings: those are counted on
    // their ledger date, never once as a plan and again as a remittance.
    final applied = {
      for (final m in data.palomarMovements.where((m) => !m.projected))
        if (m.reportId != null) m.reportId!,
    };
    for (final m in data.palomarMovements.where(
      (m) =>
          !m.date.isAfter(deadline) &&
          (m.projected ? !m.date.isBefore(cutoff) : m.date.isAfter(cutoff)),
    )) {
      if (m.signedCents == 0) continue;
      events.add(
        PalomarCoverageEvent(
          m.date,
          m.signedCents,
          '${m.projected ? 'Compensación prevista' : 'Movimiento con fecha futura'} · ${m.concept}',
        ),
      );
    }
    final shipments =
        {
              for (final s in data.palomarCoverageShipments) s.id: s,
              for (final s in bundle.shipments) s.id: s,
            }.values
            .where(
              (s) =>
                  data.ruleFor(s.clientName)?.key == rule?.key &&
                  rule != null &&
                  s.status != 'cancelado',
            )
            .toList();
    final links = {...data.palomarCoverageLinks, ...data.links};
    final sales = {for (final sale in data.sales) sale.id: sale};
    final claimed = links.values.toSet();
    final candidates = <String, List<IncomeSale>>{
      for (final s in shipments.where((s) => !links.containsKey(s.id)))
        s.id: data.sales
            .where(
              (sale) =>
                  !sale.cancelled &&
                  !claimed.contains(sale.id) &&
                  data.saleMatches(s, sale) &&
                  sale.date == s.shipDate,
            )
            .toList(),
    };
    var overdue = 0, afterDeadline = 0;
    final usedSales = <String>{};
    for (final s in shipments) {
      final linked = links[s.id];
      var sale = linked == null ? null : sales[linked];
      final invalidLink =
          linked != null && (sale == null || !data.saleMatches(s, sale));
      if (invalidLink) sale = null;
      final possible = candidates[s.id] ?? [];
      if (linked == null &&
          possible.length == 1 &&
          candidates.values
                  .where((list) => list.any((x) => x.id == possible.single.id))
                  .length ==
              1) {
        sale = possible.single;
      }
      if (sale?.cancelled == true) continue;
      if (sale != null &&
          (applied.contains(sale.id) || !usedSales.add(sale.id))) {
        continue;
      }
      final shipped = s.isShipped || sale != null;
      final originalDate = sale?.date ?? s.shipDate;
      if (!shipped && originalDate.isBefore(today)) {
        overdue++;
        continue;
      }
      final date = originalDate.isBefore(today) ? today : originalDate;
      if (date.isAfter(deadline)) {
        afterDeadline++;
        continue;
      }
      final unit = s.quantityUnit == DirectionShipmentQuantityUnit.bales
          ? 'pacas'
          : 'kg';
      final quote = quotes[s.materialCode];
      final uncertain =
          rule?.revolving != true ||
          rule?.active != true ||
          invalidLink ||
          (sale == null &&
              data.sales.any(
                (r) =>
                    !r.cancelled &&
                    data.saleMatches(s, r) &&
                    r.date == s.shipDate,
              )) ||
          (sale == null &&
              data.palomarMovements.any(
                (m) =>
                    !m.projected &&
                    m.reportId == null &&
                    m.concept.startsWith('remisionAplicada') &&
                    m.date == s.shipDate,
              ));
      final value = uncertain
          ? null
          : sale?.approvedCents ??
                (sale?.weight != null && sale?.price != null
                    ? incomeCents(sale!.weight! * sale.price!)
                    : quote?.unit == unit
                    ? quote!.amount(s.plannedQuantity)
                    : null);
      if (value == null) complete = false;
      events.add(
        PalomarCoverageEvent(
          date,
          value == null ? null : -value,
          shipped
              ? 'Embarcado · pendiente de aplicar a la cuenta'
              : s.status == 'planeado'
              ? 'En agenda · pendiente de aceptar'
              : 'En agenda · confirmado',
          material: s.materialCode,
          quantity: s.plannedQuantity,
          unit: unit,
          alreadyShipped: shipped,
        ),
      );
    }
    if (overdue > 0) {
      warnings.add(
        '$overdue embarques vencidos sin realizar: reprogramarlos para contar con su cobertura.',
      );
    }
    if (afterDeadline > 0) {
      warnings.add(
        '$afterDeadline embarques posteriores a la recepción no cubren esta fecha.',
      );
    }
    if (!complete) {
      warnings.add(
        'Hay embarques sin valuar o con vínculo por revisar. El faltante es provisional.',
      );
    }
    if (rule?.active != true || rule?.revolving != true) {
      complete = false;
      warnings.add(
        'Revisar las condiciones comerciales de El Palomar para calcular envíos.',
      );
    }
  }
  events.sort((a, b) => a.date.compareTo(b.date));
  final projectedBalance =
      balance + events.fold<int>(0, (s, e) => s + (e.signedCents ?? 0));
  final needs = <PalomarCoverageNeed>[];
  if (deadline != null &&
      !deadline.isBefore(today) &&
      projectedBalance > 0 &&
      complete) {
    final days = <DateTime>[];
    for (
      var d = today.isAfter(week) ? today : week;
      !d.isAfter(deadline);
      d = d.add(const Duration(days: 1))
    ) {
      if (d.weekday != DateTime.sunday) days.add(d);
    }
    final weekDays = <DateTime, List<DateTime>>{};
    for (final d in days) {
      weekDays.putIfAbsent(_weekStart(d), () => []).add(d);
    }
    var assigned = 0, remainingDays = days.length;
    for (final entry in weekDays.entries) {
      final amount =
          (projectedBalance - assigned) * entry.value.length ~/ remainingDays;
      needs.add(PalomarCoverageNeed(entry.key, entry.value.last, amount));
      assigned += amount;
      remainingDays -= entry.value.length;
    }
    if (days.isEmpty) {
      warnings.add(
        'No quedan días de embarque de lunes a sábado antes de la recepción.',
      );
    }
  }
  return PalomarCoverage(
    cutoff: cutoff,
    deadline: deadline,
    balance: balance,
    projectedBalance: projectedBalance,
    history: history,
    events: events,
    needs: needs,
    warnings: warnings,
    quotes: quotes,
    preferredMaterial: quotes[rule?.usualMaterial]?.usable == true
        ? rule!.usualMaterial
        : quotes['PACA_NACIONAL']?.usable == true
        ? 'PACA_NACIONAL'
        : quotes.values.where((q) => q.usable).firstOrNull?.code,
    complete: complete,
  );
}
