import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'menudeo_analysis_models.dart';

class MenudeoAnalysisRepository {
  MenudeoAnalysisRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MenudeoMarketDataset> loadMarketDataset({
    int windowDays = 30,
    DateTimeRange? dateRange,
  }) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('vw_men_price_audit_catalog')
          .select(
            'counterparty_name,group_code,material_label_snapshot,final_price,last_changed_at,direction,price_id',
          )
          .order('counterparty_name')
          .order('material_label_snapshot'),
      _client
          .from('vw_men_tickets_grid')
          .select(
            'ticket_date,direction,status,payable_weight,amount_total,counterparty_name_snapshot,material_label_snapshot',
          )
          .order('ticket_date', ascending: false),
      _client
          .from('vw_men_effective_prices')
          .select('material_label_snapshot,final_price,direction')
          .order('material_label_snapshot')
          .order('final_price'),
      _client
          .from('vw_men_price_adjustment_history')
          .select(
            'id,price_id,created_at,counterparty_name,group_code,material_label_snapshot,direction,previous_price,new_price,reason,event_kind,adjustment_mode,applied_by',
          )
          .order('created_at', ascending: false)
          .limit(300),
    ]);

    final priceRows = (results[0] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final ticketRows = (results[1] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final spreadRows = (results[2] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final historyRows = (results[3] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);

    final opportunities = _buildOpportunities(
      priceRows,
      ticketRows,
      windowDays: windowDays,
      dateRange: dateRange,
    );
    final spreads = _buildSpreads(
      spreadRows,
      ticketRows,
      windowDays: windowDays,
      dateRange: dateRange,
    );
    final alerts = _buildAlerts(opportunities, spreads);
    final history = _buildHistory(
      historyRows,
      windowDays: windowDays,
      dateRange: dateRange,
    );

    final materials =
        opportunities.map((row) => row.material).toSet().toList(growable: false)
          ..sort();
    final counterparties =
        opportunities
            .map((row) => row.counterparty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final groupCodes =
        opportunities
            .map((row) => row.groupCode)
            .where((row) => row.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    return MenudeoMarketDataset(
      opportunities: opportunities,
      spreads: spreads,
      alerts: alerts,
      history: history,
      materials: materials,
      counterparties: counterparties,
      groupCodes: groupCodes,
    );
  }

  Future<MenudeoCashDataset> loadCashDataset({
    int windowDays = 30,
    DateTimeRange? dateRange,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final results = await Future.wait<dynamic>([
      _client
          .from('vw_men_cash_vouchers_grid')
          .select(
            'id,voucher_date,voucher_type,person_label,rubric,total_amount,cash_cut_id',
          )
          .order('voucher_date', ascending: false),
      _client
          .from('vw_men_cash_cuts_grid')
          .select('id,opened_at,cut_date,difference_total,pending_checks_count')
          .order('opened_at', ascending: false),
    ]);

    final voucherRows = (results[0] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false)
        .where((row) {
          final rawDate =
              DateTime.tryParse(_text(row['voucher_date'])) ??
              DateTime.tryParse(_text(row['created_at']));
          return _withinDateWindow(rawDate, cutoff: cutoff, range: dateRange);
        })
        .toList(growable: false);
    final cutRows = (results[1] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false)
        .where((row) {
          final rawDate =
              DateTime.tryParse(_text(row['opened_at'])) ??
              DateTime.tryParse(_text(row['cut_date']));
          return _withinDateWindow(rawDate, cutoff: cutoff, range: dateRange);
        })
        .toList(growable: false);

    final voucherIds = voucherRows
        .map((row) => _text(row['id']))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final lineRows = voucherIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('men_cash_voucher_lines')
              .select('voucher_id,concept,subconcept,unit,driver,amount')
              .inFilter('voucher_id', voucherIds)
              .order('voucher_id')
              .then(
                (rows) => (rows as List)
                    .map((row) => Map<String, dynamic>.from(row as Map))
                    .toList(growable: false),
              );

    final conceptsByVoucher = <String, List<String>>{};
    for (final row in lineRows) {
      final voucherId = _text(row['voucher_id']);
      final concept = _text(row['concept']);
      if (voucherId.isEmpty || concept.isEmpty) continue;
      conceptsByVoucher.putIfAbsent(voucherId, () => <String>[]).add(concept);
    }

    var deposits = 0.0;
    var expenses = 0.0;
    var analysisExpenses = 0.0;
    var cutsWithDifference = 0;
    var pendingChecks = 0;
    final timelineTotals = <DateTime, ({double deposits, double expenses})>{};

    final rubricTotals = <String, ({double total, int count})>{};
    final conceptTotals = <String, ({double total, int count})>{};
    final subconceptTotals = <String, ({double total, int count})>{};
    final personTotals = <String, ({double total, int count})>{};
    final fuelTotals = <String, ({double total, int count})>{};
    final maintenanceTotals = <String, ({double total, int count})>{};
    final travelTotals = <String, ({double total, int count})>{};
    final logisticsUnitTotals = <String, ({double total, int count})>{};
    final logisticsDriverTotals = <String, ({double total, int count})>{};
    final logisticsUnitDetails =
        <
          String,
          ({
            double fuel,
            double maintenance,
            double travel,
            double total,
            int count,
          })
        >{};
    final logisticsDriverDetails =
        <
          String,
          ({
            double fuel,
            double maintenance,
            double travel,
            double total,
            int count,
          })
        >{};
    final rubrics = <String>{};
    final people = <String>{};

    for (final row in voucherRows) {
      final voucherId = _text(row['id']);
      final type = _text(row['voucher_type']);
      final rubric = _text(row['rubric']);
      final person = _text(row['person_label']);
      final total = _num(row['total_amount']);
      if (type == 'deposit') {
        deposits += total;
      } else if (type == 'expense') {
        expenses += total;
      }
      final concepts = conceptsByVoucher[voucherId] ?? const <String>[];
      if (_isInternalCashMovement(rubric: rubric, concepts: concepts)) {
        continue;
      }
      final voucherDate = _dateOnly(
        DateTime.tryParse(_text(row['voucher_date'])) ??
            DateTime.tryParse(_text(row['created_at'])),
      );
      if (voucherDate != null) {
        final current =
            timelineTotals[voucherDate] ?? (deposits: 0.0, expenses: 0.0);
        timelineTotals[voucherDate] = (
          deposits: current.deposits + (type == 'deposit' ? total : 0.0),
          expenses: current.expenses + (type == 'expense' ? total : 0.0),
        );
      }
      if (type == 'expense') {
        analysisExpenses += total;
      }
      if (rubric.isNotEmpty) {
        final current = rubricTotals[rubric] ?? (total: 0.0, count: 0);
        rubricTotals[rubric] = (
          total: current.total + total,
          count: current.count + 1,
        );
        rubrics.add(rubric);
      }
      if (person.isNotEmpty) {
        final current = personTotals[person] ?? (total: 0.0, count: 0);
        personTotals[person] = (
          total: current.total + total,
          count: current.count + 1,
        );
        people.add(person);
      }
    }

    for (final row in lineRows) {
      final voucherId = _text(row['voucher_id']);
      final parentVoucher = voucherRows.firstWhere(
        (voucher) => _text(voucher['id']) == voucherId,
        orElse: () => const <String, dynamic>{},
      );
      if (parentVoucher.isNotEmpty &&
          _isInternalCashMovement(
            rubric: _text(parentVoucher['rubric']),
            concepts: conceptsByVoucher[voucherId] ?? const <String>[],
          )) {
        continue;
      }
      final concept = _text(row['concept']);
      final subconcept = _text(row['subconcept']);
      final unit = _text(row['unit']);
      final driver = _text(row['driver']);
      final amount = _num(row['amount']);
      var fuelAmount = 0.0;
      var maintenanceAmount = 0.0;
      var travelAmount = 0.0;
      if (concept.isNotEmpty) {
        final current = conceptTotals[concept] ?? (total: 0.0, count: 0);
        conceptTotals[concept] = (
          total: current.total + amount,
          count: current.count + 1,
        );
      }
      if (subconcept.isNotEmpty) {
        final current = subconceptTotals[subconcept] ?? (total: 0.0, count: 0);
        subconceptTotals[subconcept] = (
          total: current.total + amount,
          count: current.count + 1,
        );
      }
      final normalizedConcept = _normalizeToken(concept);
      final normalizedSubconcept = _normalizeToken(subconcept);
      if (normalizedConcept == 'COMBUSTIBLE' ||
          normalizedSubconcept == 'COMBUSTIBLE' ||
          normalizedConcept == 'GASOLINA') {
        fuelAmount = amount;
        final label = subconcept.isNotEmpty ? subconcept : concept;
        if (label.isNotEmpty) {
          final current = fuelTotals[label] ?? (total: 0.0, count: 0);
          fuelTotals[label] = (
            total: current.total + amount,
            count: current.count + 1,
          );
        }
      }
      if (normalizedConcept == 'MANTENIMIENTO') {
        maintenanceAmount = amount;
        final label = subconcept.isNotEmpty ? subconcept : concept;
        if (label.isNotEmpty) {
          final current = maintenanceTotals[label] ?? (total: 0.0, count: 0);
          maintenanceTotals[label] = (
            total: current.total + amount,
            count: current.count + 1,
          );
        }
      }
      if (normalizedConcept == 'VIAJES') {
        travelAmount = amount;
        final label = subconcept.isNotEmpty ? subconcept : concept;
        if (label.isNotEmpty) {
          final current = travelTotals[label] ?? (total: 0.0, count: 0);
          travelTotals[label] = (
            total: current.total + amount,
            count: current.count + 1,
          );
        }
      }
      final isMobilityExpense =
          normalizedConcept == 'COMBUSTIBLE' ||
          normalizedConcept == 'GASOLINA' ||
          normalizedConcept == 'MANTENIMIENTO' ||
          normalizedConcept == 'VIAJES' ||
          normalizedSubconcept == 'COMBUSTIBLE';
      if (isMobilityExpense && unit.isNotEmpty) {
        final current = logisticsUnitTotals[unit] ?? (total: 0.0, count: 0);
        logisticsUnitTotals[unit] = (
          total: current.total + amount,
          count: current.count + 1,
        );
        final detail =
            logisticsUnitDetails[unit] ??
            (fuel: 0.0, maintenance: 0.0, travel: 0.0, total: 0.0, count: 0);
        logisticsUnitDetails[unit] = (
          fuel: detail.fuel + fuelAmount,
          maintenance: detail.maintenance + maintenanceAmount,
          travel: detail.travel + travelAmount,
          total: detail.total + amount,
          count: detail.count + 1,
        );
      }
      if (isMobilityExpense && driver.isNotEmpty) {
        final current = logisticsDriverTotals[driver] ?? (total: 0.0, count: 0);
        logisticsDriverTotals[driver] = (
          total: current.total + amount,
          count: current.count + 1,
        );
        final detail =
            logisticsDriverDetails[driver] ??
            (fuel: 0.0, maintenance: 0.0, travel: 0.0, total: 0.0, count: 0);
        logisticsDriverDetails[driver] = (
          fuel: detail.fuel + fuelAmount,
          maintenance: detail.maintenance + maintenanceAmount,
          travel: detail.travel + travelAmount,
          total: detail.total + amount,
          count: detail.count + 1,
        );
      }
    }

    for (final row in cutRows) {
      final difference = _num(row['difference_total']);
      if (difference.abs() > 0.009) cutsWithDifference++;
      pendingChecks += int.tryParse(_text(row['pending_checks_count'])) ?? 0;
    }

    final expenseBase = analysisExpenses <= 0 ? 1.0 : analysisExpenses;
    final rubricRows =
        rubricTotals.entries
            .map(
              (entry) => MenudeoCashBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / expenseBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    final conceptRows =
        conceptTotals.entries
            .map(
              (entry) => MenudeoCashBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / expenseBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    final subconceptRows =
        subconceptTotals.entries
            .map(
              (entry) => MenudeoCashBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / expenseBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    final personRows =
        personTotals.entries
            .map(
              (entry) => MenudeoCashBreakdownRow(
                label: entry.key,
                total: entry.value.total,
                count: entry.value.count,
                share: entry.value.total / expenseBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.total.compareTo(a.total));
    final fuelRows = _buildFocusedBreakdownRows(fuelTotals, expenseBase);
    final maintenanceRows = _buildFocusedBreakdownRows(
      maintenanceTotals,
      expenseBase,
    );
    final travelRows = _buildFocusedBreakdownRows(travelTotals, expenseBase);
    final logisticsUnitRows = _buildFocusedBreakdownRows(
      logisticsUnitTotals,
      expenseBase,
    );
    final logisticsDriverRows = _buildFocusedBreakdownRows(
      logisticsDriverTotals,
      expenseBase,
    );
    final logisticsUnitDetailRows = _buildLogisticsRows(
      logisticsUnitDetails,
      expenseBase,
    );
    final logisticsDriverDetailRows = _buildLogisticsRows(
      logisticsDriverDetails,
      expenseBase,
    );
    final timeline =
        timelineTotals.entries
            .map(
              (entry) => MenudeoCashTimelinePoint(
                date: entry.key,
                deposits: entry.value.deposits,
                expenses: entry.value.expenses,
                net: entry.value.deposits - entry.value.expenses,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    final alerts = <MenudeoCashAlert>[];
    if (cutsWithDifference > 0) {
      alerts.add(
        MenudeoCashAlert(
          id: 'cuts-diff',
          severity: cutsWithDifference >= 3
              ? MenudeoOpportunitySeverity.critical
              : MenudeoOpportunitySeverity.outOfRange,
          title: 'Cortes con diferencia detectados',
          detail:
              '$cutsWithDifference cortes del periodo presentan diferencia contra el efectivo teórico.',
        ),
      );
    }
    if (pendingChecks > 0) {
      alerts.add(
        MenudeoCashAlert(
          id: 'pending-checks',
          severity: pendingChecks >= 5
              ? MenudeoOpportunitySeverity.critical
              : MenudeoOpportunitySeverity.watch,
          title: 'Checks pendientes de conciliación',
          detail:
              'Hay $pendingChecks movimientos con observación pendiente en cortes de caja.',
        ),
      );
    }
    if (personRows.isNotEmpty && personRows.first.share >= 0.25) {
      alerts.add(
        MenudeoCashAlert(
          id: 'person-concentration',
          severity: personRows.first.share >= 0.40
              ? MenudeoOpportunitySeverity.critical
              : MenudeoOpportunitySeverity.outOfRange,
          title: 'Alta concentración por persona',
          detail:
              '${personRows.first.label} concentra ${_percent(personRows.first.share)} del efectivo analizado.',
        ),
      );
    }
    if (rubricRows.isNotEmpty && rubricRows.first.share >= 0.30) {
      alerts.add(
        MenudeoCashAlert(
          id: 'rubric-concentration',
          severity: rubricRows.first.share >= 0.45
              ? MenudeoOpportunitySeverity.outOfRange
              : MenudeoOpportunitySeverity.watch,
          title: 'Rubro dominante en efectivo',
          detail:
              '${rubricRows.first.label} representa ${_percent(rubricRows.first.share)} del gasto del periodo.',
        ),
      );
    }

    return MenudeoCashDataset(
      snapshot: MenudeoCashSnapshot(
        deposits: deposits,
        expenses: expenses,
        netFlow: deposits - expenses,
        cutsWithDifference: cutsWithDifference,
        pendingChecks: pendingChecks,
      ),
      timeline: timeline,
      rubricRows: rubricRows,
      conceptRows: conceptRows,
      subconceptRows: subconceptRows,
      personRows: personRows,
      fuelBreakdown: MenudeoCashFocusedBreakdown(
        title: 'Combustible',
        total: fuelRows.fold<double>(0, (sum, row) => sum + row.total),
        rows: fuelRows,
      ),
      maintenanceBreakdown: MenudeoCashFocusedBreakdown(
        title: 'Mantenimiento',
        total: maintenanceRows.fold<double>(0, (sum, row) => sum + row.total),
        rows: maintenanceRows,
      ),
      travelBreakdown: MenudeoCashFocusedBreakdown(
        title: 'Viajes',
        total: travelRows.fold<double>(0, (sum, row) => sum + row.total),
        rows: travelRows,
      ),
      logisticsUnitBreakdown: MenudeoCashFocusedBreakdown(
        title: 'Por unidad',
        total: logisticsUnitRows.fold<double>(0, (sum, row) => sum + row.total),
        rows: logisticsUnitRows,
      ),
      logisticsDriverBreakdown: MenudeoCashFocusedBreakdown(
        title: 'Por chofer',
        total: logisticsDriverRows.fold<double>(
          0,
          (sum, row) => sum + row.total,
        ),
        rows: logisticsDriverRows,
      ),
      logisticsUnitRows: logisticsUnitDetailRows,
      logisticsDriverRows: logisticsDriverDetailRows,
      alerts: alerts,
      rubrics: rubrics.toList(growable: false)..sort(),
      people: people.toList(growable: false)..sort(),
    );
  }

  Future<MenudeoOperationDataset> loadOperationDataset({
    int windowDays = 30,
    DateTimeRange? dateRange,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final results = await Future.wait<dynamic>([
      _client
          .from('vw_men_tickets_grid')
          .select(
            'id,ticket_date,ticket_number,direction,status,payable_weight,amount_total,counterparty_name_snapshot,material_label_snapshot',
          )
          .order('ticket_date', ascending: false),
      _client
          .from('vw_men_cash_cuts_grid')
          .select('id,opened_at,cut_date,pending_checks_count')
          .order('opened_at', ascending: false),
    ]);

    final ticketRows = (results[0] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false)
        .where((row) {
          final rawDate = DateTime.tryParse(_text(row['ticket_date']));
          return _withinDateWindow(rawDate, cutoff: cutoff, range: dateRange);
        })
        .toList(growable: false);
    final cutRows = (results[1] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false)
        .where((row) {
          final rawDate =
              DateTime.tryParse(_text(row['opened_at'])) ??
              DateTime.tryParse(_text(row['cut_date']));
          return _withinDateWindow(rawDate, cutoff: cutoff, range: dateRange);
        })
        .toList(growable: false);

    var purchaseAmount = 0.0;
    var saleAmount = 0.0;
    var paidTickets = 0;
    var pendingTickets = 0;
    var pendingChecks = 0;
    final timelineTotals =
        <DateTime, ({double purchase, double sale, int tickets})>{};

    final materialTotals =
        <String, ({double amount, double weight, int count})>{};
    final counterpartyTotals =
        <String, ({double amount, double weight, int count})>{};
    final pendingRows = <MenudeoPendingTicketRow>[];
    final materials = <String>{};
    final counterparties = <String>{};

    for (final row in ticketRows) {
      final status = _text(row['status']).toUpperCase();
      final flow = _parseFlow(row['direction']);
      if (flow == MenudeoAnalysisFlow.all) continue;

      final amount = _num(row['amount_total']);
      final weight = _num(row['payable_weight']);
      final material = _text(row['material_label_snapshot']);
      final counterparty = _text(row['counterparty_name_snapshot']);

      if (material.isNotEmpty) materials.add(material);
      if (counterparty.isNotEmpty) counterparties.add(counterparty);

      if (status == 'PAGADO') {
        paidTickets++;
        if (flow == MenudeoAnalysisFlow.purchase) {
          purchaseAmount += amount;
        } else if (flow == MenudeoAnalysisFlow.sale) {
          saleAmount += amount;
        }
        final ticketDate = _dateOnly(
          DateTime.tryParse(_text(row['ticket_date'])),
        );
        if (ticketDate != null) {
          final current =
              timelineTotals[ticketDate] ??
              (purchase: 0.0, sale: 0.0, tickets: 0);
          timelineTotals[ticketDate] = (
            purchase:
                current.purchase +
                (flow == MenudeoAnalysisFlow.purchase ? amount : 0.0),
            sale:
                current.sale +
                (flow == MenudeoAnalysisFlow.sale ? amount : 0.0),
            tickets: current.tickets + 1,
          );
        }

        if (material.isNotEmpty) {
          final current =
              materialTotals[material] ?? (amount: 0.0, weight: 0.0, count: 0);
          materialTotals[material] = (
            amount: current.amount + amount,
            weight: current.weight + weight,
            count: current.count + 1,
          );
        }
        if (counterparty.isNotEmpty) {
          final current =
              counterpartyTotals[counterparty] ??
              (amount: 0.0, weight: 0.0, count: 0);
          counterpartyTotals[counterparty] = (
            amount: current.amount + amount,
            weight: current.weight + weight,
            count: current.count + 1,
          );
        }
        continue;
      }

      if (status == 'PENDIENTE' || status == 'EN_CONCILIACION') {
        pendingTickets++;
        pendingRows.add(
          MenudeoPendingTicketRow(
            id: _text(row['id']),
            ticketDate: DateTime.tryParse(_text(row['ticket_date'])),
            ticketNumber: _text(row['ticket_number']),
            counterparty: counterparty,
            material: material,
            flow: flow,
            status: status,
            amount: amount,
            weight: weight,
          ),
        );
      }
    }

    for (final row in cutRows) {
      pendingChecks += int.tryParse(_text(row['pending_checks_count'])) ?? 0;
    }

    final commercialBase = (purchaseAmount + saleAmount) <= 0
        ? 1.0
        : (purchaseAmount + saleAmount);
    final materialRows =
        materialTotals.entries
            .map(
              (entry) => MenudeoOperationBreakdownRow(
                label: entry.key,
                amount: entry.value.amount,
                weight: entry.value.weight,
                count: entry.value.count,
                share: entry.value.amount / commercialBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final counterpartyRows =
        counterpartyTotals.entries
            .map(
              (entry) => MenudeoOperationBreakdownRow(
                label: entry.key,
                amount: entry.value.amount,
                weight: entry.value.weight,
                count: entry.value.count,
                share: entry.value.amount / commercialBase,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final timeline =
        timelineTotals.entries
            .map(
              (entry) => MenudeoOperationTimelinePoint(
                date: entry.key,
                purchaseAmount: entry.value.purchase,
                saleAmount: entry.value.sale,
                netAmount: entry.value.sale - entry.value.purchase,
                paidTickets: entry.value.tickets,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    final alerts = <MenudeoOperationAlert>[];
    if (pendingTickets > 0) {
      alerts.add(
        MenudeoOperationAlert(
          id: 'pending-tickets',
          severity: pendingTickets >= 6
              ? MenudeoOpportunitySeverity.critical
              : MenudeoOpportunitySeverity.watch,
          title: 'Tickets pendientes en operación',
          detail:
              'Hay $pendingTickets tickets todavía sin cierre operativo completo en la ventana analizada.',
        ),
      );
    }
    if (pendingChecks > 0) {
      alerts.add(
        MenudeoOperationAlert(
          id: 'operation-pending-checks',
          severity: pendingChecks >= 5
              ? MenudeoOpportunitySeverity.outOfRange
              : MenudeoOpportunitySeverity.watch,
          title: 'Checks pendientes ligados a cortes',
          detail:
              'Se detectaron $pendingChecks movimientos con observación pendiente en cortes de caja.',
        ),
      );
    }
    if (materialRows.isNotEmpty && materialRows.first.share >= 0.30) {
      alerts.add(
        MenudeoOperationAlert(
          id: 'material-concentration',
          severity: materialRows.first.share >= 0.45
              ? MenudeoOpportunitySeverity.outOfRange
              : MenudeoOpportunitySeverity.watch,
          title: 'Alta concentración por material',
          detail:
              '${materialRows.first.label} concentra ${_percent(materialRows.first.share)} del flujo comercial pagado.',
        ),
      );
    }
    if (counterpartyRows.isNotEmpty && counterpartyRows.first.share >= 0.28) {
      alerts.add(
        MenudeoOperationAlert(
          id: 'counterparty-concentration',
          severity: counterpartyRows.first.share >= 0.42
              ? MenudeoOpportunitySeverity.outOfRange
              : MenudeoOpportunitySeverity.watch,
          title: 'Alta concentración por contraparte',
          detail:
              '${counterpartyRows.first.label} representa ${_percent(counterpartyRows.first.share)} del monto operado pagado.',
        ),
      );
    }

    return MenudeoOperationDataset(
      snapshot: MenudeoOperationSnapshot(
        purchaseAmount: purchaseAmount,
        saleAmount: saleAmount,
        netCommercialFlow: saleAmount - purchaseAmount,
        paidTickets: paidTickets,
        pendingTickets: pendingTickets,
        pendingChecks: pendingChecks,
      ),
      timeline: timeline,
      materialRows: materialRows,
      counterpartyRows: counterpartyRows,
      pendingRows: pendingRows
        ..sort((a, b) {
          final aDate = a.ticketDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.ticketDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        }),
      alerts: alerts,
      materials: materials.toList(growable: false)..sort(),
      counterparties: counterparties.toList(growable: false)..sort(),
    );
  }

  List<MenudeoPriceOpportunity> _buildOpportunities(
    List<Map<String, dynamic>> priceRows,
    List<Map<String, dynamic>> ticketRows, {
    required int windowDays,
    DateTimeRange? dateRange,
  }) {
    final benchmarks = <String, double>{};
    final priceGroups = <String, List<double>>{};
    final ticketSignals =
        <String, ({double weight, double amount, int count})>{};
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));

    for (final row in priceRows) {
      final direction = _parseFlow(row['direction']);
      if (direction == MenudeoAnalysisFlow.all) continue;
      final material = _text(row['material_label_snapshot']);
      if (material.isEmpty) continue;
      final price = _num(row['final_price']);
      if (price <= 0) continue;
      final key = '${direction.name}|$material';
      priceGroups.putIfAbsent(key, () => <double>[]).add(price);
    }
    for (final entry in priceGroups.entries) {
      benchmarks[entry.key] = _median(entry.value);
    }

    for (final row in ticketRows) {
      final ticketDate = DateTime.tryParse(_text(row['ticket_date']));
      if (!_withinDateWindow(ticketDate, cutoff: cutoff, range: dateRange)) {
        continue;
      }
      final status = _text(row['status']).toUpperCase();
      if (status != 'PAGADO') continue;
      final direction = _parseFlow(row['direction']);
      if (direction == MenudeoAnalysisFlow.all) continue;
      final material = _text(row['material_label_snapshot']);
      final counterparty = _text(row['counterparty_name_snapshot']);
      if (material.isEmpty || counterparty.isEmpty) continue;
      final key = '${direction.name}|$counterparty|$material';
      final current =
          ticketSignals[key] ?? (weight: 0.0, amount: 0.0, count: 0);
      ticketSignals[key] = (
        weight: current.weight + _num(row['payable_weight']),
        amount: current.amount + _num(row['amount_total']),
        count: current.count + 1,
      );
    }

    final opportunities = <MenudeoPriceOpportunity>[];
    for (final row in priceRows) {
      final flow = _parseFlow(row['direction']);
      if (flow == MenudeoAnalysisFlow.all) continue;
      final material = _text(row['material_label_snapshot']);
      final counterparty = _text(row['counterparty_name']);
      if (material.isEmpty || counterparty.isEmpty) continue;
      final currentPrice = _num(row['final_price']);
      final referencePrice =
          benchmarks['${flow.name}|$material'] ?? currentPrice;
      if (referencePrice <= 0) continue;
      final deviation = (currentPrice - referencePrice) / referencePrice;
      final signal =
          ticketSignals['${flow.name}|$counterparty|$material'] ??
          (weight: 0.0, amount: 0.0, count: 0);
      final severity = _severityFor(flow, deviation);
      final action = _actionFor(flow, severity);
      final suggestedDelta = _suggestedDeltaFor(
        flow: flow,
        currentPrice: currentPrice,
        referencePrice: referencePrice,
        action: action,
      );
      opportunities.add(
        MenudeoPriceOpportunity(
          id: _text(row['price_id']).isNotEmpty
              ? _text(row['price_id'])
              : '${flow.name}|$counterparty|$material',
          counterparty: counterparty,
          groupCode: _text(row['group_code']),
          material: material,
          flow: flow,
          currentPrice: currentPrice,
          referencePrice: referencePrice,
          suggestedDelta: suggestedDelta,
          impactEstimate: suggestedDelta.abs() * signal.weight,
          deviationPercent: deviation,
          recentWeight: signal.weight,
          recentAmount: signal.amount,
          recentTickets: signal.count,
          severity: severity,
          action: action,
          lastChangedAt: DateTime.tryParse(_text(row['last_changed_at'])),
        ),
      );
    }

    opportunities.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;
      final impactCompare = b.impactEstimate.compareTo(a.impactEstimate);
      if (impactCompare != 0) return impactCompare;
      final materialCompare = a.material.compareTo(b.material);
      if (materialCompare != 0) return materialCompare;
      return a.counterparty.compareTo(b.counterparty);
    });
    return opportunities;
  }

  List<MenudeoSpreadRow> _buildSpreads(
    List<Map<String, dynamic>> spreadRows,
    List<Map<String, dynamic>> ticketRows, {
    required int windowDays,
    DateTimeRange? dateRange,
  }) {
    final groupedPrices = <String, Map<MenudeoAnalysisFlow, List<double>>>{};
    final groupedWeights = <String, Map<MenudeoAnalysisFlow, double>>{};
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));

    for (final row in spreadRows) {
      final material = _text(row['material_label_snapshot']);
      final direction = _parseFlow(row['direction']);
      if (material.isEmpty || direction == MenudeoAnalysisFlow.all) continue;
      groupedPrices
          .putIfAbsent(material, () => <MenudeoAnalysisFlow, List<double>>{})
          .putIfAbsent(direction, () => <double>[])
          .add(_num(row['final_price']));
    }
    for (final row in ticketRows) {
      final ticketDate = DateTime.tryParse(_text(row['ticket_date']));
      if (!_withinDateWindow(ticketDate, cutoff: cutoff, range: dateRange)) {
        continue;
      }
      final status = _text(row['status']).toUpperCase();
      if (status != 'PAGADO') continue;
      final material = _text(row['material_label_snapshot']);
      final direction = _parseFlow(row['direction']);
      if (material.isEmpty || direction == MenudeoAnalysisFlow.all) continue;
      groupedWeights.putIfAbsent(
        material,
        () => <MenudeoAnalysisFlow, double>{},
      )[direction] = (groupedWeights[material]?[direction] ?? 0) +
          _num(row['payable_weight']);
    }

    final materials = groupedPrices.keys.toList(growable: false)..sort();
    final rows = <MenudeoSpreadRow>[];
    for (final material in materials) {
      final purchase = _median(
        groupedPrices[material]?[MenudeoAnalysisFlow.purchase] ??
            const <double>[],
      );
      final sale = _median(
        groupedPrices[material]?[MenudeoAnalysisFlow.sale] ?? const <double>[],
      );
      if (purchase <= 0 && sale <= 0) continue;
      rows.add(
        MenudeoSpreadRow(
          material: material,
          purchasePrice: purchase > 0 ? purchase : null,
          salePrice: sale > 0 ? sale : null,
          spread: sale > 0 && purchase > 0 ? sale - purchase : 0,
          purchaseWeight:
              groupedWeights[material]?[MenudeoAnalysisFlow.purchase] ?? 0,
          saleWeight: groupedWeights[material]?[MenudeoAnalysisFlow.sale] ?? 0,
        ),
      );
    }
    rows.sort((a, b) {
      final weightCompare = (b.purchaseWeight + b.saleWeight).compareTo(
        a.purchaseWeight + a.saleWeight,
      );
      if (weightCompare != 0) return weightCompare;
      return a.material.compareTo(b.material);
    });
    return rows;
  }

  List<MenudeoMarketAlert> _buildAlerts(
    List<MenudeoPriceOpportunity> opportunities,
    List<MenudeoSpreadRow> spreads,
  ) {
    final alerts = <MenudeoMarketAlert>[];
    for (final opportunity in opportunities.take(8)) {
      if (!opportunity.isActionable) continue;
      final actionLabel = menudeoActionLabel(opportunity.action);
      alerts.add(
        MenudeoMarketAlert(
          id: 'opportunity-${opportunity.id}',
          severity: opportunity.severity,
          title:
              '$actionLabel ${opportunity.flow == MenudeoAnalysisFlow.purchase ? 'compra' : 'venta'} en ${opportunity.material}',
          detail:
              '${opportunity.counterparty} está ${_percent(opportunity.deviationPercent.abs())} ${opportunity.flow == MenudeoAnalysisFlow.purchase ? 'arriba' : 'abajo'} de su referencia interna.',
          material: opportunity.material,
          counterparty: opportunity.counterparty,
        ),
      );
    }
    for (final spread in spreads.where((row) => row.isPressured).take(4)) {
      alerts.add(
        MenudeoMarketAlert(
          id: 'spread-${spread.material}',
          severity: MenudeoOpportunitySeverity.critical,
          title: 'Spread crítico en ${spread.material}',
          detail:
              'El spread vigente está en ${spread.spread.toStringAsFixed(2)} y requiere revisión inmediata.',
          material: spread.material,
          counterparty: '',
        ),
      );
    }
    return alerts.take(8).toList(growable: false);
  }

  List<MenudeoMarketHistoryEvent> _buildHistory(
    List<Map<String, dynamic>> rows, {
    required int windowDays,
    DateTimeRange? dateRange,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    return rows
        .where((row) {
          final createdAt = DateTime.tryParse(_text(row['created_at']));
          return _withinDateWindow(createdAt, cutoff: cutoff, range: dateRange);
        })
        .map((row) {
          return MenudeoMarketHistoryEvent(
            id: _text(row['id']),
            priceId: _text(row['price_id']),
            createdAt: DateTime.tryParse(_text(row['created_at'])),
            counterparty: _text(row['counterparty_name']),
            groupCode: _text(row['group_code']),
            material: _text(row['material_label_snapshot']),
            flow: _parseFlow(row['direction']),
            previousPrice: _num(row['previous_price']),
            newPrice: _num(row['new_price']),
            reason: _text(row['reason']),
            eventKind: _text(row['event_kind']),
            adjustmentMode: _text(row['adjustment_mode']),
            appliedBy: _text(row['applied_by']),
          );
        })
        .toList(growable: false);
  }

  MenudeoAnalysisFlow _parseFlow(dynamic value) {
    switch (_text(value).toLowerCase()) {
      case 'purchase':
        return MenudeoAnalysisFlow.purchase;
      case 'sale':
        return MenudeoAnalysisFlow.sale;
      default:
        return MenudeoAnalysisFlow.all;
    }
  }

  MenudeoOpportunitySeverity _severityFor(
    MenudeoAnalysisFlow flow,
    double deviation,
  ) {
    if (flow == MenudeoAnalysisFlow.purchase) {
      if (deviation >= 0.08) return MenudeoOpportunitySeverity.critical;
      if (deviation >= 0.04) return MenudeoOpportunitySeverity.outOfRange;
      if (deviation >= 0.015) return MenudeoOpportunitySeverity.watch;
      return MenudeoOpportunitySeverity.healthy;
    }
    if (deviation <= -0.08) return MenudeoOpportunitySeverity.critical;
    if (deviation <= -0.04) return MenudeoOpportunitySeverity.outOfRange;
    if (deviation <= -0.015) return MenudeoOpportunitySeverity.watch;
    return MenudeoOpportunitySeverity.healthy;
  }

  MenudeoOpportunityAction _actionFor(
    MenudeoAnalysisFlow flow,
    MenudeoOpportunitySeverity severity,
  ) {
    if (severity == MenudeoOpportunitySeverity.healthy) {
      return MenudeoOpportunityAction.hold;
    }
    return flow == MenudeoAnalysisFlow.purchase
        ? MenudeoOpportunityAction.lowerPrice
        : MenudeoOpportunityAction.raisePrice;
  }

  double _suggestedDeltaFor({
    required MenudeoAnalysisFlow flow,
    required double currentPrice,
    required double referencePrice,
    required MenudeoOpportunityAction action,
  }) {
    if (action == MenudeoOpportunityAction.hold) return 0;
    if (flow == MenudeoAnalysisFlow.purchase) {
      return currentPrice - referencePrice;
    }
    return referencePrice - currentPrice;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final ordered = List<double>.from(values)..sort();
    final middle = ordered.length ~/ 2;
    if (ordered.length.isOdd) return ordered[middle];
    return (ordered[middle - 1] + ordered[middle]) / 2;
  }

  double _num(dynamic value) => double.tryParse((value ?? '').toString()) ?? 0;

  List<MenudeoCashBreakdownRow> _buildFocusedBreakdownRows(
    Map<String, ({double total, int count})> totals,
    double expenseBase,
  ) {
    return totals.entries
        .map(
          (entry) => MenudeoCashBreakdownRow(
            label: entry.key,
            total: entry.value.total,
            count: entry.value.count,
            share: entry.value.total / expenseBase,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  List<MenudeoCashLogisticsRow> _buildLogisticsRows(
    Map<
      String,
      ({
        double fuel,
        double maintenance,
        double travel,
        double total,
        int count,
      })
    >
    totals,
    double expenseBase,
  ) {
    return totals.entries
        .map(
          (entry) => MenudeoCashLogisticsRow(
            label: entry.key,
            total: entry.value.total,
            fuelTotal: entry.value.fuel,
            maintenanceTotal: entry.value.maintenance,
            travelTotal: entry.value.travel,
            count: entry.value.count,
            share: entry.value.total / expenseBase,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  DateTime? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  bool _withinDateWindow(
    DateTime? value, {
    required DateTime cutoff,
    required DateTimeRange? range,
  }) {
    if (value == null) return false;
    if (range == null) return !value.isBefore(cutoff);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );
    return !value.isBefore(start) && !value.isAfter(end);
  }

  bool _isInternalCashMovement({
    required String rubric,
    required List<String> concepts,
  }) {
    final normalizedRubric = _normalizeToken(rubric);
    if (normalizedRubric == 'REPOSICION DE FONDO') return true;
    if (normalizedRubric == 'MOVIMIENTOS INTERNOS') return true;

    for (final concept in concepts) {
      final normalizedConcept = _normalizeToken(concept);
      if (normalizedConcept == 'BOVEDA') return true;
      if (normalizedConcept == 'CAJA GRANDE') return true;
      if (normalizedConcept.contains('TRANSFERENCIA')) return true;
      if (normalizedConcept.contains('INTERNO')) return true;
    }
    return false;
  }

  String _normalizeToken(String value) {
    const accents = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'á': 'A',
      'à': 'A',
      'ä': 'A',
      'â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'é': 'E',
      'è': 'E',
      'ë': 'E',
      'ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'í': 'I',
      'ì': 'I',
      'ï': 'I',
      'î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ó': 'O',
      'ò': 'O',
      'ö': 'O',
      'ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ú': 'U',
      'ù': 'U',
      'ü': 'U',
      'û': 'U',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(accents[char] ?? char);
    }
    return buffer
        .toString()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
