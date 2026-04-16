import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../dashboard/dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import 'menudeo_demo_mode.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_cash_cuts_page.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_tickets_page.dart';
import 'menudeo_theme.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';

class MenudeoDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoDashboardPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoDashboardPage> createState() => _MenudeoDashboardPageState();
}

class _MenudeoDashboardPageState extends State<MenudeoDashboardPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _menuOpen = false;
  bool _loadingDashboard = true;
  bool _canReturnToDirection = false;
  _MenudeoCashCutDraft? _todayCut;
  List<_PendingCashCheck> _pendingChecks = const <_PendingCashCheck>[];
  double _salesToday = 0;
  double _purchasesToday = 0;
  double _depositsToday = 0;
  double _expensesToday = 0;
  int _salesCount = 0;
  int _purchasesCount = 0;
  List<_DashboardWeightRow> _purchaseMaterialRows =
      const <_DashboardWeightRow>[];
  List<_DashboardWeightRow> _purchaseProviderRows =
      const <_DashboardWeightRow>[];
  List<_DashboardPriceReferenceRow> _priceReferenceRows =
      const <_DashboardPriceReferenceRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDashboardData());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loadingDashboard = true);
    final today = DateTime.now();
    if (kMenudeoForceDemoMode) {
      _applyMockDashboardData(today, const <Map<String, dynamic>>[]);
      return;
    }
    final todayIso = _toIsoDate(today);
    try {
      final results = await Future.wait<dynamic>([
        _supa
            .from('vw_men_tickets_grid')
            .select(
              'amount_total,direction,status,payable_weight,material_label_snapshot,counterparty_name_snapshot',
            )
            .eq('ticket_date', todayIso),
        _supa
            .from('vw_men_cash_vouchers_grid')
            .select('total_amount,voucher_type')
            .eq('voucher_date', todayIso),
        _supa
            .from('vw_men_cash_cuts_grid')
            .select('*')
            .eq('cut_date', todayIso)
            .limit(1),
        _supa
            .from('men_cash_cut_checks')
            .select(
              'id,source_type,source_folio,reason,is_verified,men_cash_cuts!inner(cut_date)',
            )
            .eq('is_verified', false)
            .order('created_at'),
        _loadDashboardPriceRows(),
      ]);

      final ticketRows = (results[0] as List).cast<Map<String, dynamic>>();
      final voucherRows = (results[1] as List).cast<Map<String, dynamic>>();
      final cutRows = (results[2] as List).cast<Map<String, dynamic>>();
      final pendingRows = (results[3] as List).cast<Map<String, dynamic>>();
      final priceRows = (results[4] as List).cast<Map<String, dynamic>>();

      double sales = 0;
      double purchases = 0;
      double deposits = 0;
      double expenses = 0;
      int salesCount = 0;
      int purchasesCount = 0;

      for (final row in ticketRows) {
        final amount =
            double.tryParse((row['amount_total'] ?? '').toString()) ?? 0;
        final direction = (row['direction'] ?? '').toString();
        final status = (row['status'] ?? '').toString().toUpperCase();
        if (status != 'PAGADO') continue;
        if (direction == 'sale') {
          sales += amount;
          salesCount++;
        } else {
          purchases += amount;
          purchasesCount++;
        }
      }

      for (final row in voucherRows) {
        final amount =
            double.tryParse((row['total_amount'] ?? '').toString()) ?? 0;
        final type = (row['voucher_type'] ?? '').toString();
        if (type == 'deposit') {
          deposits += amount;
        } else if (type == 'expense') {
          expenses += amount;
        }
      }

      if (!mounted) return;
      final shouldUseMock =
          ticketRows.isEmpty && voucherRows.isEmpty && cutRows.isEmpty;
      if (shouldUseMock) {
        _applyMockDashboardData(today, pendingRows);
        return;
      }
      final baseCut = cutRows.isEmpty
          ? _MenudeoCashCutDraft.forDate(today)
          : _MenudeoCashCutDraft.fromMap(cutRows.first);
      final purchaseMaterialRows = _buildTopWeightRows(
        ticketRows: ticketRows,
        labelField: 'material_label_snapshot',
      );
      final purchaseProviderRows = _buildTopWeightRows(
        ticketRows: ticketRows,
        labelField: 'counterparty_name_snapshot',
      );
      final priceReferenceRows = _buildPriceReferenceRows(priceRows);
      setState(() {
        _salesToday = sales;
        _purchasesToday = purchases;
        _depositsToday = deposits;
        _expensesToday = expenses;
        _salesCount = salesCount;
        _purchasesCount = purchasesCount;
        _todayCut = baseCut.copyWith(
          salesTotal: sales,
          purchasesTotal: purchases,
          depositsTotal: deposits,
          expensesTotal: expenses,
        );
        _pendingChecks = pendingRows
            .map(_PendingCashCheck.fromMap)
            .toList(growable: false);
        _purchaseMaterialRows = purchaseMaterialRows;
        _purchaseProviderRows = purchaseProviderRows;
        _priceReferenceRows = priceReferenceRows;
        _loadingDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      _applyMockDashboardData(today, const <Map<String, dynamic>>[]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el dashboard real. Se muestran totales demo para revisar el flujo: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyMockDashboardData(
    DateTime today,
    List<Map<String, dynamic>> pendingRows,
  ) {
    if (!mounted) return;
    setState(() {
      _salesToday = 1695.90;
      _purchasesToday = 1755.54;
      _depositsToday = 26350.00;
      _expensesToday = 13297.06;
      _salesCount = 6;
      _purchasesCount = 7;
      _purchaseMaterialRows = const <_DashboardWeightRow>[
        _DashboardWeightRow(label: 'CARTÓN AMERICANO', weight: 232),
        _DashboardWeightRow(label: 'CARTÓN REVUELTO', weight: 186),
        _DashboardWeightRow(label: 'PET', weight: 138),
        _DashboardWeightRow(label: 'CHATARRA', weight: 116),
        _DashboardWeightRow(label: 'ALUMINIO', weight: 94),
      ];
      _purchaseProviderRows = const <_DashboardWeightRow>[
        _DashboardWeightRow(label: 'MAURICIO ALCALA', weight: 232),
        _DashboardWeightRow(label: 'AMBROCIO PEÑAFLOR', weight: 186),
        _DashboardWeightRow(label: 'ANTONIO MORALES', weight: 138),
        _DashboardWeightRow(label: 'TRICICLOS', weight: 116),
        _DashboardWeightRow(label: 'SAN PABLO', weight: 94),
      ];
      _priceReferenceRows = const <_DashboardPriceReferenceRow>[
        _DashboardPriceReferenceRow(
          material: 'CARTÓN AMERICANO',
          purchasePrice: 2.50,
          salePrice: 3.10,
        ),
        _DashboardPriceReferenceRow(
          material: 'CARTÓN REVUELTO',
          purchasePrice: 2.20,
          salePrice: 2.85,
        ),
        _DashboardPriceReferenceRow(
          material: 'PET',
          purchasePrice: 5.30,
          salePrice: 6.10,
        ),
        _DashboardPriceReferenceRow(
          material: 'CHATARRA',
          purchasePrice: 3.10,
          salePrice: 3.95,
        ),
        _DashboardPriceReferenceRow(
          material: 'ALUMINIO',
          purchasePrice: 19.50,
          salePrice: 22.00,
        ),
        _DashboardPriceReferenceRow(
          material: 'COBRE',
          purchasePrice: 88.00,
          salePrice: 94.50,
        ),
      ];
      _todayCut = _MenudeoCashCutDraft.forDate(today).copyWith(
        openingCash: 12000,
        salesTotal: _salesToday,
        purchasesTotal: _purchasesToday,
        depositsTotal: _depositsToday,
        expensesTotal: _expensesToday,
        countedCashTotal: 25000,
        pendingChecksCount: pendingRows.length,
        status: pendingRows.isEmpty ? 'ABIERTO' : 'CON_PENDIENTES',
      );
      _pendingChecks = pendingRows
          .map(_PendingCashCheck.fromMap)
          .toList(growable: false);
      _loadingDashboard = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadDashboardPriceRows() async {
    try {
      final rows = await _supa
          .from('vw_men_effective_prices')
          .select('material_label_snapshot,final_price,direction')
          .order('material_label_snapshot')
          .order('final_price');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        final rows = await _supa
            .from('vw_men_effective_prices')
            .select('material_label_snapshot,final_price');
        final mapped = (rows as List)
            .cast<Map<String, dynamic>>()
            .map((row) => <String, dynamic>{...row, 'direction': 'purchase'})
            .toList(growable: false);
        return mapped;
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
  }

  List<_DashboardWeightRow> _buildTopWeightRows({
    required List<Map<String, dynamic>> ticketRows,
    required String labelField,
  }) {
    final totals = <String, double>{};
    for (final row in ticketRows) {
      final direction = (row['direction'] ?? '').toString();
      if (direction != 'purchase') continue;
      final status = (row['status'] ?? '').toString().toUpperCase();
      if (status == 'CANCELADO') continue;
      final label = (row[labelField] ?? '').toString().trim();
      if (label.isEmpty) continue;
      final weight =
          double.tryParse((row['payable_weight'] ?? '').toString()) ?? 0;
      if (weight <= 0) continue;
      totals[label] = (totals[label] ?? 0) + weight;
    }
    final rows =
        totals.entries
            .map(
              (entry) =>
                  _DashboardWeightRow(label: entry.key, weight: entry.value),
            )
            .toList(growable: false)
          ..sort((a, b) => b.weight.compareTo(a.weight));
    return rows.take(6).toList(growable: false);
  }

  List<_DashboardPriceReferenceRow> _buildPriceReferenceRows(
    List<Map<String, dynamic>> priceRows,
  ) {
    const preferredOrder = <String>[
      'CARTÓN AMERICANO',
      'CARTÓN REVUELTO',
      'ARCHIVO',
      'PET',
      'CHATARRA',
      'ALUMINIO',
      'COBRE',
    ];
    final grouped = <String, Map<String, double>>{};
    for (final row in priceRows) {
      final material = (row['material_label_snapshot'] ?? '').toString().trim();
      if (material.isEmpty) continue;
      final price = double.tryParse((row['final_price'] ?? '').toString());
      if (price == null) continue;
      final direction = (row['direction'] ?? 'purchase').toString();
      grouped.putIfAbsent(material, () => <String, double>{})[direction] =
          price;
    }

    final materialNames = grouped.keys.toList(growable: false)
      ..sort((a, b) {
        final aIndex = preferredOrder.indexOf(a.toUpperCase());
        final bIndex = preferredOrder.indexOf(b.toUpperCase());
        if (aIndex == -1 && bIndex == -1) return a.compareTo(b);
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;
        return aIndex.compareTo(bIndex);
      });

    return materialNames
        .take(6)
        .map(
          (material) => _DashboardPriceReferenceRow(
            material: material,
            purchasePrice: grouped[material]?['purchase'],
            salePrice: grouped[material]?['sale'],
          ),
        )
        .toList(growable: false);
  }

  String _toIsoDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _openCashCutDialog({
    required bool openingOnly,
    bool bypassPendingGuard = false,
  }) async {
    if (!openingOnly) {
      final granted = await _authorizeDirectionGate(
        title: 'Acceso a corte de caja',
        message:
            'Solo Dirección puede hacer el corte. Captura la contraseña de Dirección para continuar.',
      );
      if (!granted) return;
    }
    if (openingOnly && _pendingChecks.isNotEmpty && !bypassPendingGuard) {
      final continueOpening = await _openPendingChecksGuardDialog();
      if (continueOpening == true && mounted) {
        await _openCashCutDialog(openingOnly: true, bypassPendingGuard: true);
      }
      return;
    }
    if (!openingOnly) {
      await _openGuidedCashCutFlow();
      return;
    }
    if (!mounted) return;
    final base = (_todayCut ?? _MenudeoCashCutDraft.forDate(DateTime.now()))
        .copyWith(
          salesTotal: _salesToday,
          purchasesTotal: _purchasesToday,
          depositsTotal: _depositsToday,
          expensesTotal: _expensesToday,
        );
    final result = await showDialog<_MenudeoCashCutDraft>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) =>
          _DashboardCashCutDialog(initial: base, openingOnly: openingOnly),
    );
    if (result == null || !mounted) return;

    final theoreticalCash =
        result.openingCash +
        _salesToday +
        result.depositsTotal -
        _purchasesToday -
        result.expensesTotal;
    final difference = result.countedCashTotal - theoreticalCash;
    final payload = <String, dynamic>{
      'cut_date': _toIsoDate(result.date),
      'opening_cash': result.openingCash,
      'sales_total': _salesToday,
      'purchases_total': _purchasesToday,
      'deposits_total': result.depositsTotal,
      'expenses_total': result.expensesTotal,
      'theoretical_cash_total': theoreticalCash,
      'counted_cash_total': result.countedCashTotal,
      'difference_total': difference,
      'pending_checks_count': result.pendingChecksCount,
      'status': result.status,
      'notes': result.notes,
    };

    if (kMenudeoForceDemoMode) {
      setState(() {
        _todayCut = (_todayCut ?? _MenudeoCashCutDraft.forDate(result.date))
            .copyWith(
              openingCash: result.openingCash,
              salesTotal: _salesToday,
              purchasesTotal: _purchasesToday,
              depositsTotal: result.depositsTotal,
              expensesTotal: result.expensesTotal,
              countedCashTotal: result.countedCashTotal,
              pendingChecksCount: result.pendingChecksCount,
              status: result.status,
              notes: result.notes,
            );
      });
      _toastDashboard('Apertura/corte actualizado solo en demo');
      return;
    }

    try {
      await _supa.from('men_cash_cuts').upsert(payload, onConflict: 'cut_date');
      await _loadDashboardData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el corte de caja: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String> _ensureTodayCutId({
    required double openingCash,
    required double countedCashTotal,
    required String notes,
  }) async {
    if (kMenudeoForceDemoMode) return 'demo-cut';
    final today = DateTime.now();
    final todayIso = _toIsoDate(today);
    final theoreticalCash =
        openingCash +
        _salesToday +
        _depositsToday -
        _purchasesToday -
        _expensesToday;
    final difference = countedCashTotal - theoreticalCash;
    final existingRows = await _supa
        .from('men_cash_cuts')
        .select('id')
        .eq('cut_date', todayIso)
        .limit(1);
    final existing = (existingRows as List).cast<Map<String, dynamic>>();
    final payload = <String, dynamic>{
      'cut_date': todayIso,
      'opening_cash': openingCash,
      'sales_total': _salesToday,
      'purchases_total': _purchasesToday,
      'deposits_total': _depositsToday,
      'expenses_total': _expensesToday,
      'theoretical_cash_total': theoreticalCash,
      'counted_cash_total': countedCashTotal,
      'difference_total': difference,
      'notes': notes,
    };
    if (existing.isEmpty) {
      final inserted = await _supa
          .from('men_cash_cuts')
          .insert(payload)
          .select('id')
          .single();
      return (inserted['id'] ?? '').toString();
    }
    final cashCutId = (existing.first['id'] ?? '').toString();
    await _supa.from('men_cash_cuts').update(payload).eq('id', cashCutId);
    return cashCutId;
  }

  Future<void> _openGuidedCashCutFlow() async {
    final base = (_todayCut ?? _MenudeoCashCutDraft.forDate(DateTime.now()))
        .copyWith(
          salesTotal: _salesToday,
          purchasesTotal: _purchasesToday,
          depositsTotal: _depositsToday,
          expensesTotal: _expensesToday,
        );
    final capture = await showDialog<_CashCountCapture>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) => _CashCountDialog(initial: base),
    );
    if (capture == null || !mounted) return;

    try {
      final todayIso = _toIsoDate(base.date);
      final results = await Future.wait<dynamic>([
        _supa
            .from('vw_men_cash_vouchers_grid')
            .select(
              'id,folio,person_label,rubric,concepts_preview,total_amount',
            )
            .eq('voucher_date', todayIso)
            .eq('voucher_type', 'expense')
            .order('folio_sort', ascending: true)
            .order('folio', ascending: true),
        _supa
            .from('vw_men_cash_vouchers_grid')
            .select(
              'id,folio,person_label,rubric,concepts_preview,total_amount',
            )
            .eq('voucher_date', todayIso)
            .eq('voucher_type', 'deposit')
            .order('folio_sort', ascending: true)
            .order('folio', ascending: true),
        _supa
            .from('vw_men_tickets_grid')
            .select(
              'id,ticket_number,counterparty_name_snapshot,material_label_snapshot,amount_total',
            )
            .eq('ticket_date', todayIso)
            .eq('direction', 'sale')
            .order('ticket_number', ascending: true),
        _supa
            .from('vw_men_tickets_grid')
            .select(
              'id,ticket_number,counterparty_name_snapshot,material_label_snapshot,amount_total',
            )
            .eq('ticket_date', todayIso)
            .eq('direction', 'purchase')
            .order('ticket_number', ascending: true),
      ]);

      final batches = <_CashCutReviewBatch>[
        _CashCutReviewBatch(
          label: 'Gastos',
          sourceType: 'expense_voucher',
          items: (results[0] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (row) => _CashCutReviewItem(
                  sourceId: (row['id'] ?? '').toString(),
                  sourceFolio: (row['folio'] ?? '').toString(),
                  sourceType: 'expense_voucher',
                  title: (row['person_label'] ?? '').toString(),
                  subtitle: (row['rubric'] ?? '').toString(),
                  detail: (row['concepts_preview'] ?? '').toString(),
                  amount:
                      double.tryParse((row['total_amount'] ?? '').toString()) ??
                      0,
                ),
              )
              .toList(growable: false),
        ),
        _CashCutReviewBatch(
          label: 'Depósitos',
          sourceType: 'deposit_voucher',
          items: (results[1] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (row) => _CashCutReviewItem(
                  sourceId: (row['id'] ?? '').toString(),
                  sourceFolio: (row['folio'] ?? '').toString(),
                  sourceType: 'deposit_voucher',
                  title: (row['person_label'] ?? '').toString(),
                  subtitle: (row['rubric'] ?? '').toString(),
                  detail: (row['concepts_preview'] ?? '').toString(),
                  amount:
                      double.tryParse((row['total_amount'] ?? '').toString()) ??
                      0,
                ),
              )
              .toList(growable: false),
        ),
        _CashCutReviewBatch(
          label: 'Ventas',
          sourceType: 'sale_ticket',
          items: (results[2] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (row) => _CashCutReviewItem(
                  sourceId: (row['id'] ?? '').toString(),
                  sourceFolio: (row['ticket_number'] ?? '').toString(),
                  sourceType: 'sale_ticket',
                  title: (row['counterparty_name_snapshot'] ?? '').toString(),
                  subtitle: (row['material_label_snapshot'] ?? '').toString(),
                  detail: 'Ordenado por ticket',
                  amount:
                      double.tryParse((row['amount_total'] ?? '').toString()) ??
                      0,
                ),
              )
              .toList(growable: false),
        ),
        _CashCutReviewBatch(
          label: 'Compras',
          sourceType: 'purchase_ticket',
          items: (results[3] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (row) => _CashCutReviewItem(
                  sourceId: (row['id'] ?? '').toString(),
                  sourceFolio: (row['ticket_number'] ?? '').toString(),
                  sourceType: 'purchase_ticket',
                  title: (row['counterparty_name_snapshot'] ?? '').toString(),
                  subtitle: (row['material_label_snapshot'] ?? '').toString(),
                  detail: 'Ordenado por ticket',
                  amount:
                      double.tryParse((row['amount_total'] ?? '').toString()) ??
                      0,
                ),
              )
              .toList(growable: false),
        ),
      ];
      final hydratedBatches = _withCashCutMockFallback(batches, todayIso);

      if (!mounted) return;
      final review = await showDialog<_CashCutVirtualFlowResult>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.24),
        builder: (context) => _CashCutVirtualFlowDialog(
          batches: hydratedBatches,
          initialBatchIndex: 0,
          initialItemIndex: 0,
          initialDecisions: const <_CashCutCheckDecision>[],
          countedCashTotal: capture.countedCashTotal,
          openingCash: base.openingCash,
          theoreticalCash:
              base.openingCash +
              _salesToday +
              _depositsToday -
              _purchasesToday -
              _expensesToday,
        ),
      );
      if (review == null || !mounted) return;

      if (kMenudeoForceDemoMode) {
        setState(() {
          _todayCut = base.copyWith(
            countedCashTotal: capture.countedCashTotal,
            pendingChecksCount: review.pendingCount,
            status: review.pendingCount == 0 ? 'CERRADO' : 'CON_PENDIENTES',
            notes: capture.notes,
          );
          _pendingChecks = review.decisions
              .where((item) => !item.isVerified)
              .map(
                (item) => _PendingCashCheck(
                  sourceType: item.sourceType,
                  sourceFolio: item.sourceFolio,
                  reason: item.reason,
                  cutDate: base.date,
                ),
              )
              .toList(growable: false);
        });
        _toastDashboard(
          review.pendingCount == 0
              ? 'Corte completado solo en demo'
              : 'Corte demo guardado con ${review.pendingCount} pendientes',
        );
        return;
      }

      final cashCutId = await _ensureTodayCutId(
        openingCash: base.openingCash,
        countedCashTotal: capture.countedCashTotal,
        notes: capture.notes,
      );
      await _supa
          .from('men_cash_cut_checks')
          .delete()
          .eq('cash_cut_id', cashCutId);
      if (review.decisions.isNotEmpty) {
        await _supa
            .from('men_cash_cut_checks')
            .insert(
              review.decisions
                  .map(
                    (item) => <String, dynamic>{
                      'cash_cut_id': cashCutId,
                      'source_type': item.sourceType,
                      'source_id': item.sourceId,
                      'source_folio': item.sourceFolio,
                      'is_verified': item.isVerified,
                      'reason': item.reason,
                      'verified_at': item.isVerified
                          ? DateTime.now().toIso8601String()
                          : null,
                    },
                  )
                  .toList(growable: false),
            );
      }

      await _supa
          .from('men_cash_cuts')
          .update({
            'pending_checks_count': review.pendingCount,
            'status': review.pendingCount == 0 ? 'CERRADO' : 'CON_PENDIENTES',
            'closed_at': DateTime.now().toIso8601String(),
            'notes': capture.notes,
          })
          .eq('id', cashCutId);

      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review.pendingCount == 0
                ? 'Corte guardado y comprobado completo'
                : 'Corte guardado con ${review.pendingCount} pendientes',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo completar el corte guiado: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toastDashboard(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<_CashCutReviewBatch> _withCashCutMockFallback(
    List<_CashCutReviewBatch> batches,
    String todayIso,
  ) {
    final fallback = _buildCashCutMockBatches(todayIso);
    return List<_CashCutReviewBatch>.generate(batches.length, (index) {
      final current = batches[index];
      if (current.items.isNotEmpty) return current;
      return _CashCutReviewBatch(
        label: current.label,
        sourceType: current.sourceType,
        items: fallback[index].items,
      );
    }, growable: false);
  }

  List<_CashCutReviewBatch> _buildCashCutMockBatches(String todayIso) {
    Map<String, dynamic> ticketPreview({
      required String ticket,
      required String direction,
      required String counterparty,
      required String material,
      required double price,
      required double gross,
      required double tare,
      required double humidity,
      required double trash,
      required double premium,
      required double payable,
      required double amount,
      String status = 'PAGADO',
      String comment = '',
      String exitOrder = '',
    }) {
      return <String, dynamic>{
        'ticket_date': todayIso,
        'ticket_number': ticket,
        'direction': direction,
        'counterparty_name_snapshot': counterparty,
        'material_label_snapshot': material,
        'price_at_entry': price,
        'gross_weight': gross,
        'tare_weight': tare,
        'humidity_percent': humidity,
        'trash_weight': trash,
        'premium_per_kg': premium,
        'payable_weight': payable,
        'amount_total': amount,
        'status': status,
        'comment': comment,
        'exit_order_number': exitOrder,
      };
    }

    Map<String, dynamic> voucherHeader({
      required String folio,
      required String type,
      required String person,
      required String rubric,
      required double total,
      String comment = '',
    }) {
      return <String, dynamic>{
        'voucher_date': todayIso,
        'folio': folio,
        'voucher_type': type,
        'person_label': person,
        'rubric': rubric,
        'total_amount': total,
        'comment': comment,
      };
    }

    List<Map<String, dynamic>> voucherLines(List<Map<String, dynamic>> lines) =>
        lines;

    return <_CashCutReviewBatch>[
      _CashCutReviewBatch(
        label: 'Gastos',
        sourceType: 'expense_voucher',
        items: <_CashCutReviewItem>[
          _CashCutReviewItem(
            sourceId: 'demo-expense-18263',
            sourceFolio: '18263',
            sourceType: 'expense_voucher',
            title: 'JESUS RODRIGUEZ',
            subtitle: 'OPERATIVO',
            detail: 'BÁSCULA',
            amount: 150,
            previewHeader: voucherHeader(
              folio: '18263',
              type: 'expense',
              person: 'JESUS RODRIGUEZ',
              rubric: 'OPERATIVO',
              total: 150,
              comment: 'RODOLFO VERA',
            ),
            previewLines: voucherLines([
              {
                'concept': 'BÁSCULA',
                'company': 'MONROE',
                'driver': 'RODOLFO VERA',
                'amount': 150,
                'comment': '',
              },
            ]),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-expense-18276',
            sourceFolio: '18276',
            sourceType: 'expense_voucher',
            title: 'RAFAEL ABOYTES',
            subtitle: 'OPERATIVO',
            detail: 'OXÍGENO',
            amount: 2144.02,
            previewHeader: voucherHeader(
              folio: '18276',
              type: 'expense',
              person: 'RAFAEL ABOYTES',
              rubric: 'OPERATIVO',
              total: 2144.02,
              comment: 'OXÍGENO Y BOQUILLAS',
            ),
            previewLines: voucherLines([
              {
                'concept': 'OXÍGENO',
                'quantity': '2',
                'amount': 2144.02,
                'comment': 'OXÍGENO Y BOQUILLAS',
              },
            ]),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-expense-18280',
            sourceFolio: '18280',
            sourceType: 'expense_voucher',
            title: 'GABRIEL RODRIGUEZ',
            subtitle: 'OPERATIVO',
            detail: 'BÁSCULA',
            amount: 140,
            previewHeader: voucherHeader(
              folio: '18280',
              type: 'expense',
              person: 'GABRIEL RODRIGUEZ',
              rubric: 'OPERATIVO',
              total: 140,
              comment: 'MONROE',
            ),
            previewLines: voucherLines([
              {
                'concept': 'BÁSCULA',
                'company': 'MONROE',
                'driver': 'GABRIEL RODRIGUEZ',
                'amount': 140,
                'comment': '',
              },
            ]),
          ),
        ],
      ),
      _CashCutReviewBatch(
        label: 'Depósitos',
        sourceType: 'deposit_voucher',
        items: <_CashCutReviewItem>[
          _CashCutReviewItem(
            sourceId: 'demo-deposit-14350',
            sourceFolio: '14350',
            sourceType: 'deposit_voucher',
            title: 'FATIMA CORTES',
            subtitle: 'VENTA DE MATERIAL',
            detail: 'DEPÓSITO',
            amount: 14350,
            previewHeader: voucherHeader(
              folio: '14350',
              type: 'deposit',
              person: 'FATIMA CORTES',
              rubric: 'VENTA DE MATERIAL',
              total: 14350,
              comment: 'SRA REBE',
            ),
            previewLines: voucherLines([
              {'concept': 'DEPÓSITO', 'amount': 14350, 'comment': 'SRA REBE'},
            ]),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-deposit-14381',
            sourceFolio: '14381',
            sourceType: 'deposit_voucher',
            title: 'CAJA GRANDE',
            subtitle: 'REPOSICIÓN DE FONDO',
            detail: 'CAJA GRANDE',
            amount: 5000,
            previewHeader: voucherHeader(
              folio: '14381',
              type: 'deposit',
              person: 'CAJA GRANDE',
              rubric: 'REPOSICIÓN DE FONDO',
              total: 5000,
            ),
            previewLines: voucherLines([
              {'concept': 'CAJA GRANDE', 'amount': 5000, 'comment': ''},
            ]),
          ),
        ],
      ),
      _CashCutReviewBatch(
        label: 'Ventas',
        sourceType: 'sale_ticket',
        items: <_CashCutReviewItem>[
          _CashCutReviewItem(
            sourceId: 'demo-sale-56001',
            sourceFolio: '56001',
            sourceType: 'sale_ticket',
            title: 'GRUPAK',
            subtitle: 'CARTÓN AMERICANO',
            detail: 'Ordenado por ticket',
            amount: 238.5,
            previewHeader: ticketPreview(
              ticket: '56001',
              direction: 'sale',
              counterparty: 'GRUPAK',
              material: 'CARTÓN AMERICANO',
              price: 2.65,
              gross: 120,
              tare: 20,
              humidity: 0,
              trash: 10,
              premium: 0,
              payable: 90,
              amount: 238.5,
              exitOrder: 'OS-2214',
            ),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-sale-56002',
            sourceFolio: '56002',
            sourceType: 'sale_ticket',
            title: 'SAN PABLO',
            subtitle: 'PET',
            detail: 'Ordenado por ticket',
            amount: 512.4,
            previewHeader: ticketPreview(
              ticket: '56002',
              direction: 'sale',
              counterparty: 'SAN PABLO',
              material: 'PET',
              price: 6.1,
              gross: 95,
              tare: 5,
              humidity: 0,
              trash: 6,
              premium: 0,
              payable: 84,
              amount: 512.4,
              exitOrder: 'OS-2215',
            ),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-sale-56003',
            sourceFolio: '56003',
            sourceType: 'sale_ticket',
            title: 'TDF',
            subtitle: 'CHATARRA',
            detail: 'Ordenado por ticket',
            amount: 945,
            previewHeader: ticketPreview(
              ticket: '56003',
              direction: 'sale',
              counterparty: 'TDF',
              material: 'CHATARRA',
              price: 3.15,
              gross: 340,
              tare: 20,
              humidity: 0,
              trash: 20,
              premium: 0,
              payable: 300,
              amount: 945,
              exitOrder: 'OS-2216',
            ),
          ),
        ],
      ),
      _CashCutReviewBatch(
        label: 'Compras',
        sourceType: 'purchase_ticket',
        items: <_CashCutReviewItem>[
          _CashCutReviewItem(
            sourceId: 'demo-purchase-55980',
            sourceFolio: '55980',
            sourceType: 'purchase_ticket',
            title: 'MAURICIO ALCALA',
            subtitle: 'CARTÓN REVUELTO',
            detail: 'Ordenado por ticket',
            amount: 1220.4,
            previewHeader: ticketPreview(
              ticket: '55980',
              direction: 'purchase',
              counterparty: 'MAURICIO ALCALA',
              material: 'CARTÓN REVUELTO',
              price: 5.26,
              gross: 300,
              tare: 40,
              humidity: 5,
              trash: 15,
              premium: 0,
              payable: 232,
              amount: 1220.4,
            ),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-purchase-56012',
            sourceFolio: '56012',
            sourceType: 'purchase_ticket',
            title: 'AMBROCIO PEÑAFLOR',
            subtitle: 'CARTÓN AMERICANO',
            detail: 'Ordenado por ticket',
            amount: 162.54,
            previewHeader: ticketPreview(
              ticket: '56012',
              direction: 'purchase',
              counterparty: 'AMBROCIO PEÑAFLOR',
              material: 'CARTÓN AMERICANO',
              price: 1.35,
              gross: 135,
              tare: 10,
              humidity: 4,
              trash: 4,
              premium: 0.05,
              payable: 116.1,
              amount: 162.54,
            ),
          ),
          _CashCutReviewItem(
            sourceId: 'demo-purchase-56031',
            sourceFolio: '56031',
            sourceType: 'purchase_ticket',
            title: 'ANTONIO MORALES',
            subtitle: 'CARTÓN REVUELTO',
            detail: 'Ordenado por ticket',
            amount: 372.6,
            previewHeader: ticketPreview(
              ticket: '56031',
              direction: 'purchase',
              counterparty: 'ANTONIO MORALES',
              material: 'CARTÓN REVUELTO',
              price: 2.7,
              gross: 150,
              tare: 5,
              humidity: 2,
              trash: 4,
              premium: 0,
              payable: 138,
              amount: 372.6,
            ),
          ),
        ],
      ),
    ];
  }

  Future<bool?> _openPendingChecksDialog() async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) => _PendingChecksDialog(
        checks: _pendingChecks,
        allowContinueToOpening: false,
      ),
    );
  }

  Future<bool?> _openPendingChecksGuardDialog() async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) => _PendingChecksDialog(
        checks: _pendingChecks,
        allowContinueToOpening: true,
      ),
    );
  }

  Future<void> _goBack() async {
    if (!_canReturnToDirection || !mounted) return;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openOperationalDashboard() async {
    if (!_canReturnToDirection || !mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _showStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Menudeo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openPriceAdjustmentsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openTicketsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoTicketsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openSalesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoSalesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openDepositsExpensesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoDepositsExpensesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openCashCutsPage() async {
    final granted = await _authorizeDirectionGate(
      title: 'Acceso a historial de cortes',
      message:
          'Solo Dirección puede ver los cortes. Captura la contraseña de Dirección para continuar.',
    );
    if (!granted || !mounted) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoCashCutsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<bool> _authorizeDirectionGate({
    required String title,
    required String message,
  }) async {
    if (_canReturnToDirection) return true;
    final granted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) =>
          _DirectionPasswordDialog(title: title, message: message),
    );
    return granted == true;
  }

  void _handleAreaAction(String label) {
    if (label == 'Catálogo') {
      unawaited(_openCatalogPage());
      return;
    }
    if (label == 'Ajuste de precios') {
      unawaited(_openPriceAdjustmentsPage());
      return;
    }
    if (label == 'Tickets de menudeo') {
      unawaited(_openTicketsPage());
      return;
    }
    if (label == 'Ventas menudeo') {
      unawaited(_openSalesPage());
      return;
    }
    if (label == 'Depósitos y gastos') {
      unawaited(_openDepositsExpensesPage());
      return;
    }
    if (label == 'Corte de caja') {
      unawaited(_openCashCutsPage());
      return;
    }
    _showStub(label);
  }

  Future<void> _logout() async {
    final ok = await showMenudeoSessionConfirmDialog(context);
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _MenudeoBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, anim) => _MenudeoHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Menú',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => MenudeoHeaderBrand(
            contentAnim: contentAnim,
            title: 'Dashboard Menudeo',
          ),
          trailingBuilder: (_, anim) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenudeoHeaderButton(
                label: _pendingChecks.isEmpty
                    ? 'Pendientes'
                    : 'Pendientes ${_pendingChecks.length}',
                icon: _pendingChecks.isEmpty
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                onTap: _openPendingChecksDialog,
              ),
              const SizedBox(width: 10),
              _MenudeoHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              _MenudeoBody(
                loadingDashboard: _loadingDashboard,
                salesToday: _salesToday,
                purchasesToday: _purchasesToday,
                salesCount: _salesCount,
                purchasesCount: _purchasesCount,
                depositsToday: _depositsToday,
                expensesToday: _expensesToday,
                purchaseMaterialRows: _purchaseMaterialRows,
                purchaseProviderRows: _purchaseProviderRows,
                priceReferenceRows: _priceReferenceRows,
                cut: _todayCut,
                onOpenCashCuts: _openCashCutsPage,
                onOpenPurchases: _openTicketsPage,
                onOpenSales: _openSalesPage,
                onOpenDepositsExpenses: _openDepositsExpensesPage,
                onOpenCatalog: _openCatalogPage,
                onOpenOpening: () => _openCashCutDialog(openingOnly: true),
                onOpenCut: () => _openCashCutDialog(openingOnly: false),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: _MenudeoSidePanel(
                    onBack: _goBack,
                    onOpenOperationalDashboard: _openOperationalDashboard,
                    onStubTap: _handleAreaAction,
                    canReturnToDirection: _canReturnToDirection,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoBody extends StatelessWidget {
  final bool loadingDashboard;
  final double salesToday;
  final double purchasesToday;
  final int salesCount;
  final int purchasesCount;
  final double depositsToday;
  final double expensesToday;
  final List<_DashboardWeightRow> purchaseMaterialRows;
  final List<_DashboardWeightRow> purchaseProviderRows;
  final List<_DashboardPriceReferenceRow> priceReferenceRows;
  final _MenudeoCashCutDraft? cut;
  final Future<void> Function() onOpenCashCuts;
  final Future<void> Function() onOpenPurchases;
  final Future<void> Function() onOpenSales;
  final Future<void> Function() onOpenDepositsExpenses;
  final Future<void> Function() onOpenCatalog;
  final Future<void> Function() onOpenOpening;
  final Future<void> Function() onOpenCut;

  const _MenudeoBody({
    required this.loadingDashboard,
    required this.salesToday,
    required this.purchasesToday,
    required this.salesCount,
    required this.purchasesCount,
    required this.depositsToday,
    required this.expensesToday,
    required this.purchaseMaterialRows,
    required this.purchaseProviderRows,
    required this.priceReferenceRows,
    required this.cut,
    required this.onOpenCashCuts,
    required this.onOpenPurchases,
    required this.onOpenSales,
    required this.onOpenDepositsExpenses,
    required this.onOpenCatalog,
    required this.onOpenOpening,
    required this.onOpenCut,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final totalCash =
        (cut?.openingCash ?? 0) +
        salesToday +
        depositsToday -
        purchasesToday -
        expensesToday;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenudeoDashboardTopBar(
                totalCash: loadingDashboard ? 'Cargando...' : _money(totalCash),
                onOpenCashCuts: onOpenCashCuts,
                onOpenOpening: onOpenOpening,
                onOpenCut: onOpenCut,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1200
                      ? 4
                      : width >= 860
                      ? 2
                      : 1;
                  final spacing = 16.0;
                  final cardWidth =
                      (width - ((columns - 1) * spacing)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.shopping_basket_rounded,
                        title: 'Compra de hoy',
                        value: loadingDashboard
                            ? 'Cargando...'
                            : _money(purchasesToday),
                        detail: '$purchasesCount tickets pagados',
                        accent: tokens.primaryStrong,
                        onTap: onOpenPurchases,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.point_of_sale_rounded,
                        title: 'Venta de hoy',
                        value: loadingDashboard
                            ? 'Cargando...'
                            : _money(salesToday),
                        detail: '$salesCount tickets cobrados',
                        accent: tokens.accent,
                        onTap: onOpenSales,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Gastos de hoy',
                        value: loadingDashboard
                            ? 'Cargando...'
                            : _money(expensesToday),
                        detail: 'Capturados en el corte activo',
                        accent: tokens.badgeText,
                        onTap: onOpenDepositsExpenses,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.savings_rounded,
                        title: 'Depósitos de hoy',
                        value: loadingDashboard
                            ? 'Cargando...'
                            : _money(depositsToday),
                        detail: 'Capturados en el corte activo',
                        accent: const Color(0xFF5A8466),
                        onTap: onOpenDepositsExpenses,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _MenudeoInsightGrid(
                purchaseMaterialRows: purchaseMaterialRows,
                purchaseProviderRows: purchaseProviderRows,
                priceReferenceRows: priceReferenceRows,
                openingCash: cut?.openingCash ?? 0,
                countedCash: cut?.countedCashTotal ?? 0,
                pendingChecksCount: cut?.pendingChecksCount ?? 0,
                onOpenTickets: onOpenPurchases,
                onOpenCatalog: onOpenCatalog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(num value) => formatMoney(value);
}

class _MenudeoDashboardTopBar extends StatelessWidget {
  final String totalCash;
  final Future<void> Function() onOpenCashCuts;
  final Future<void> Function() onOpenOpening;
  final Future<void> Function() onOpenCut;

  const _MenudeoDashboardTopBar({
    required this.totalCash,
    required this.onOpenCashCuts,
    required this.onOpenOpening,
    required this.onOpenCut,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MenudeoHeroActionIconButton(
                tooltip: 'Apertura de caja',
                icon: Icons.lock_open_rounded,
                filled: true,
                onTap: () => unawaited(onOpenOpening()),
              ),
              _MenudeoHeroActionIconButton(
                tooltip: 'Hacer corte',
                icon: Icons.request_quote_rounded,
                onTap: () => unawaited(onOpenCut()),
              ),
              _MenudeoHeroActionIconButton(
                tooltip: 'Ver cortes',
                icon: Icons.history_rounded,
                onTap: () => unawaited(onOpenCashCuts()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: tokens.primarySoft.withValues(alpha: 0.30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primaryStrong.withValues(alpha: 0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total en caja',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    totalCash,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F262B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Apertura + venta + depósitos - compra - gastos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A6966),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenudeoHeroActionIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _MenudeoHeroActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  State<_MenudeoHeroActionIconButton> createState() =>
      _MenudeoHeroActionIconButtonState();
}

class _MenudeoHeroActionIconButtonState
    extends State<_MenudeoHeroActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final background = widget.filled
        ? tokens.primaryStrong.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.58);
    final iconColor = widget.filled ? Colors.white : tokens.primaryStrong;
    final borderColor = widget.filled
        ? tokens.primaryStrong.withValues(alpha: 0.18)
        : tokens.primaryStrong.withValues(alpha: 0.16);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.05 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translateByDouble(0, _hovered ? -2 : 0, 0, 1),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: tokens.primaryStrong.withValues(
                    alpha: _hovered ? 0.16 : 0.08,
                  ),
                  blurRadius: _hovered ? 20 : 12,
                  offset: Offset(0, _hovered ? 10 : 6),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(widget.icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenudeoMetricCard extends StatefulWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final Future<void> Function()? onTap;

  const _MenudeoMetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    this.onTap,
  });

  @override
  State<_MenudeoMetricCard> createState() => _MenudeoMetricCardState();
}

class _MenudeoMetricCardState extends State<_MenudeoMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: highlighted ? 1.008 : 1.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: enabled ? () => widget.onTap!() : null,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, highlighted ? -3.0 : 0.0, 0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: highlighted
                      ? [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.16),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : const [],
                ),
                child: ContractGlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: widget.accent),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A5552),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F262B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6A6966),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenudeoInsightGrid extends StatelessWidget {
  final List<_DashboardWeightRow> purchaseMaterialRows;
  final List<_DashboardWeightRow> purchaseProviderRows;
  final List<_DashboardPriceReferenceRow> priceReferenceRows;
  final double openingCash;
  final double countedCash;
  final int pendingChecksCount;
  final Future<void> Function() onOpenTickets;
  final Future<void> Function() onOpenCatalog;

  const _MenudeoInsightGrid({
    required this.purchaseMaterialRows,
    required this.purchaseProviderRows,
    required this.priceReferenceRows,
    required this.openingCash,
    required this.countedCash,
    required this.pendingChecksCount,
    required this.onOpenTickets,
    required this.onOpenCatalog,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MenudeoInsightCard(
                onTap: onOpenTickets,
                child: _DashboardBarBlock(
                  title: 'Materiales comprados por peso',
                  subtitle: 'Peso comprando hoy por material',
                  rows: purchaseMaterialRows,
                  accent: tokens.primaryStrong,
                  emptyLabel: 'Todavía no hay compras cargadas hoy',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MenudeoInsightCard(
                onTap: onOpenTickets,
                child: _DashboardBarBlock(
                  title: 'Proveedores por peso',
                  subtitle: 'Quién concentra más peso comprado hoy',
                  rows: purchaseProviderRows,
                  accent: tokens.accent,
                  emptyLabel: 'Todavía no hay proveedores con peso hoy',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenudeoInsightCard(
          onTap: onOpenCatalog,
          child: _DashboardPriceReferenceBlock(rows: priceReferenceRows),
        ),
      ],
    );
  }
}

class _MenudeoInsightCard extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onTap;

  const _MenudeoInsightCard({required this.child, this.onTap});

  @override
  State<_MenudeoInsightCard> createState() => _MenudeoInsightCardState();
}

class _MenudeoInsightCardState extends State<_MenudeoInsightCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.004 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: enabled ? () => widget.onTap!() : null,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, highlighted ? -3.0 : 0.0, 0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: tokens.primaryStrong.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : const [],
              ),
              child: ContractGlassCard(
                padding: const EdgeInsets.all(18),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenudeoCashCutDraft {
  final DateTime date;
  final double openingCash;
  final double depositsTotal;
  final double expensesTotal;
  final double salesTotal;
  final double purchasesTotal;
  final double countedCashTotal;
  final int pendingChecksCount;
  final String status;
  final String notes;

  const _MenudeoCashCutDraft({
    required this.date,
    required this.openingCash,
    required this.depositsTotal,
    required this.expensesTotal,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.countedCashTotal,
    required this.pendingChecksCount,
    required this.status,
    required this.notes,
  });

  factory _MenudeoCashCutDraft.forDate(DateTime date) {
    return _MenudeoCashCutDraft(
      date: DateTime(date.year, date.month, date.day),
      openingCash: 0,
      depositsTotal: 0,
      expensesTotal: 0,
      salesTotal: 0,
      purchasesTotal: 0,
      countedCashTotal: 0,
      pendingChecksCount: 0,
      status: 'ABIERTO',
      notes: '',
    );
  }

  factory _MenudeoCashCutDraft.fromMap(Map<String, dynamic> row) {
    double parseNum(dynamic value) =>
        double.tryParse((value ?? '').toString()) ?? 0;

    return _MenudeoCashCutDraft(
      date:
          DateTime.tryParse((row['cut_date'] ?? '').toString()) ??
          DateTime.now(),
      openingCash: parseNum(row['opening_cash']),
      depositsTotal: parseNum(row['deposits_total']),
      expensesTotal: parseNum(row['expenses_total']),
      salesTotal: parseNum(row['sales_total']),
      purchasesTotal: parseNum(row['purchases_total']),
      countedCashTotal: parseNum(row['counted_cash_total']),
      pendingChecksCount:
          int.tryParse((row['pending_checks_count'] ?? '').toString()) ?? 0,
      status: (row['status'] ?? 'ABIERTO').toString(),
      notes: (row['notes'] ?? '').toString(),
    );
  }

  _MenudeoCashCutDraft copyWith({
    DateTime? date,
    double? openingCash,
    double? depositsTotal,
    double? expensesTotal,
    double? salesTotal,
    double? purchasesTotal,
    double? countedCashTotal,
    int? pendingChecksCount,
    String? status,
    String? notes,
  }) {
    return _MenudeoCashCutDraft(
      date: date ?? this.date,
      openingCash: openingCash ?? this.openingCash,
      depositsTotal: depositsTotal ?? this.depositsTotal,
      expensesTotal: expensesTotal ?? this.expensesTotal,
      salesTotal: salesTotal ?? this.salesTotal,
      purchasesTotal: purchasesTotal ?? this.purchasesTotal,
      countedCashTotal: countedCashTotal ?? this.countedCashTotal,
      pendingChecksCount: pendingChecksCount ?? this.pendingChecksCount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class _DashboardCashCutDialog extends StatefulWidget {
  final _MenudeoCashCutDraft initial;
  final bool openingOnly;

  const _DashboardCashCutDialog({
    required this.initial,
    required this.openingOnly,
  });

  @override
  State<_DashboardCashCutDialog> createState() =>
      _DashboardCashCutDialogState();
}

class _DashboardCashCutDialogState extends State<_DashboardCashCutDialog> {
  late final TextEditingController _openingC;
  late final TextEditingController _depositsC;
  late final TextEditingController _expensesC;
  late final TextEditingController _countedC;
  late final TextEditingController _pendingC;
  late final TextEditingController _notesC;
  String _status = 'ABIERTO';

  @override
  void initState() {
    super.initState();
    _openingC = TextEditingController(text: _num(widget.initial.openingCash));
    _depositsC = TextEditingController(
      text: _num(widget.initial.depositsTotal),
    );
    _expensesC = TextEditingController(
      text: _num(widget.initial.expensesTotal),
    );
    _countedC = TextEditingController(
      text: _num(widget.initial.countedCashTotal),
    );
    _pendingC = TextEditingController(
      text: widget.initial.pendingChecksCount == 0
          ? ''
          : widget.initial.pendingChecksCount.toString(),
    );
    _notesC = TextEditingController(text: widget.initial.notes);
    _status = widget.initial.status;
  }

  @override
  void dispose() {
    _openingC.dispose();
    _depositsC.dispose();
    _expensesC.dispose();
    _countedC.dispose();
    _pendingC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  String _num(double value) => value == 0 ? '' : value.toStringAsFixed(2);

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: AreaThemeScope(
        tokens: tokens,
        child: Theme(
          data: _menudeoDashboardDialogTheme(Theme.of(context), tokens),
          child: ContractPopupSurface(
            constraints: const BoxConstraints(
              minWidth: 620,
              maxWidth: 860,
              maxHeight: 760,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.openingOnly
                                ? 'Apertura de caja'
                                : 'Hacer corte',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.openingOnly)
                      _DashboardCutField(
                        label: 'Monto de apertura',
                        child: TextField(
                          controller: _openingC,
                          style: _dashboardCutInputTextStyle(tokens),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: '0.00',
                            hintStyle: _dashboardCutHintTextStyle(tokens),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Apertura de caja',
                                      child: TextField(
                                        controller: _openingC,
                                        onChanged: (_) => setLocalState(() {}),
                                        style: _dashboardCutInputTextStyle(
                                          tokens,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration.collapsed(
                                          hintText: '0.00',
                                          hintStyle: _dashboardCutHintTextStyle(
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Depósitos de hoy',
                                      child: TextField(
                                        controller: _depositsC,
                                        onChanged: (_) => setLocalState(() {}),
                                        style: _dashboardCutInputTextStyle(
                                          tokens,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration.collapsed(
                                          hintText: '0.00',
                                          hintStyle: _dashboardCutHintTextStyle(
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Gastos de hoy',
                                      child: TextField(
                                        controller: _expensesC,
                                        onChanged: (_) => setLocalState(() {}),
                                        style: _dashboardCutInputTextStyle(
                                          tokens,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration.collapsed(
                                          hintText: '0.00',
                                          hintStyle: _dashboardCutHintTextStyle(
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Conteo real de caja',
                                      child: TextField(
                                        controller: _countedC,
                                        onChanged: (_) => setLocalState(() {}),
                                        style: _dashboardCutInputTextStyle(
                                          tokens,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration.collapsed(
                                          hintText: '0.00',
                                          hintStyle: _dashboardCutHintTextStyle(
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Pendientes por comprobar',
                                      child: TextField(
                                        controller: _pendingC,
                                        style: _dashboardCutInputTextStyle(
                                          tokens,
                                        ),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration.collapsed(
                                          hintText: '0',
                                          hintStyle: _dashboardCutHintTextStyle(
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DashboardCutField(
                                      label: 'Estado',
                                      child: SegmentedButton<String>(
                                        style: _dashboardCutSegmentedStyle(
                                          tokens,
                                        ),
                                        segments: const [
                                          ButtonSegment(
                                            value: 'ABIERTO',
                                            label: Text('Abierto'),
                                          ),
                                          ButtonSegment(
                                            value: 'CERRADO',
                                            label: Text('Cerrado'),
                                          ),
                                          ButtonSegment(
                                            value: 'CON_PENDIENTES',
                                            label: Text('Pendientes'),
                                          ),
                                        ],
                                        selected: <String>{_status},
                                        onSelectionChanged: (value) {
                                          setLocalState(
                                            () => _status = value.first,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DashboardCutField(
                                label: 'Observaciones',
                                child: TextField(
                                  controller: _notesC,
                                  maxLines: 3,
                                  style: _dashboardCutInputTextStyle(tokens),
                                  decoration: InputDecoration.collapsed(
                                    hintText:
                                        'Notas de corte, diferencias o pendientes',
                                    hintStyle: _dashboardCutHintTextStyle(
                                      tokens,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _dashboardCutSecondaryButtonStyle(tokens),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: _dashboardCutPrimaryButtonStyle(tokens),
                          onPressed: () {
                            Navigator.of(context).pop(
                              widget.initial.copyWith(
                                openingCash: _parse(_openingC),
                                depositsTotal: _parse(_depositsC),
                                expensesTotal: _parse(_expensesC),
                                countedCashTotal: _parse(_countedC),
                                pendingChecksCount:
                                    int.tryParse(_pendingC.text.trim()) ?? 0,
                                status: widget.openingOnly
                                    ? 'ABIERTO'
                                    : _status,
                                notes: _notesC.text.trim(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            widget.openingOnly
                                ? 'Guardar apertura'
                                : 'Guardar corte',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCutField extends StatelessWidget {
  final String label;
  final Widget child;

  const _DashboardCutField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

ThemeData _menudeoDashboardDialogTheme(
  ThemeData base,
  ContractAreaTokens tokens,
) {
  final scheme = base.colorScheme.copyWith(
    primary: tokens.primaryStrong,
    onPrimary: Colors.white,
    secondary: tokens.primaryStrong,
    onSecondary: Colors.white,
    tertiary: tokens.accent,
    surfaceTint: tokens.surfaceTint,
  );
  return base.copyWith(
    colorScheme: scheme,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.primaryStrong,
      selectionColor: tokens.primarySoft.withValues(alpha: 0.42),
      selectionHandleColor: tokens.primaryStrong,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _dashboardCutPrimaryButtonStyle(tokens),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _dashboardCutSecondaryButtonStyle(tokens),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.primaryStrong),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: _dashboardCutSegmentedStyle(tokens),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: _dashboardCutHintTextStyle(tokens),
    ),
  );
}

TextStyle _dashboardCutInputTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: tokens.primaryStrong,
);

TextStyle _dashboardCutHintTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: tokens.badgeText.withValues(alpha: 0.84),
);

ButtonStyle _dashboardCutPrimaryButtonStyle(ContractAreaTokens tokens) {
  return FilledButton.styleFrom(
    backgroundColor: tokens.primaryStrong,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _dashboardCutSecondaryButtonStyle(ContractAreaTokens tokens) {
  return OutlinedButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.55),
    side: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.9)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _dashboardCutTonalButtonStyle(ContractAreaTokens tokens) {
  return FilledButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    backgroundColor: tokens.badgeBackground.withValues(alpha: 0.88),
    disabledForegroundColor: tokens.primaryStrong.withValues(alpha: 0.42),
    disabledBackgroundColor: tokens.badgeBackground.withValues(alpha: 0.46),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _dashboardCutSegmentedStyle(ContractAreaTokens tokens) {
  return SegmentedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    foregroundColor: tokens.primaryStrong,
    selectedForegroundColor: tokens.primaryStrong,
    selectedBackgroundColor: tokens.badgeBackground.withValues(alpha: 0.92),
    backgroundColor: Colors.white.withValues(alpha: 0.72),
    side: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.42)),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
  );
}

class _PendingCashCheck {
  final String sourceType;
  final String sourceFolio;
  final String reason;
  final DateTime cutDate;

  const _PendingCashCheck({
    required this.sourceType,
    required this.sourceFolio,
    required this.reason,
    required this.cutDate,
  });

  factory _PendingCashCheck.fromMap(Map<String, dynamic> row) {
    Map<String, dynamic>? cashCut;
    final rawCashCut = row['men_cash_cuts'];
    if (rawCashCut is Map<String, dynamic>) {
      cashCut = rawCashCut;
    } else if (rawCashCut is List && rawCashCut.isNotEmpty) {
      final first = rawCashCut.first;
      if (first is Map<String, dynamic>) {
        cashCut = first;
      }
    }
    return _PendingCashCheck(
      sourceType: (row['source_type'] ?? '').toString(),
      sourceFolio: (row['source_folio'] ?? '').toString(),
      reason: (row['reason'] ?? '').toString(),
      cutDate:
          DateTime.tryParse((cashCut?['cut_date'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  String get sourceTypeLabel {
    switch (sourceType) {
      case 'expense_voucher':
        return 'Gasto';
      case 'deposit_voucher':
        return 'Depósito';
      case 'sale_ticket':
        return 'Venta';
      case 'purchase_ticket':
        return 'Compra';
      default:
        return sourceType;
    }
  }
}

class _PendingChecksDialog extends StatelessWidget {
  final List<_PendingCashCheck> checks;
  final bool allowContinueToOpening;

  const _PendingChecksDialog({
    required this.checks,
    required this.allowContinueToOpening,
  });

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: ContractPopupSurface(
          constraints: const BoxConstraints(
            minWidth: 680,
            maxWidth: 960,
            maxHeight: 760,
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pendientes por comprobar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Estos folios o tickets quedaron abiertos en cortes anteriores. Puedes revisar la lista y después continuar con la apertura si así lo decides.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: checks.isEmpty
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(
                              0xFFCC8A67,
                            ).withValues(alpha: 0.16),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 34,
                              color: Color(0xFF4D7C59),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No hay pendientes por comprobar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Caja no tiene folios heredados abiertos de cortes anteriores.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A6C63),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: checks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = checks[index];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(
                                  0xFFCC8A67,
                                ).withValues(alpha: 0.24),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFC47A18,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.notification_important_rounded,
                                    color: Color(0xFFC47A18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.sourceTypeLabel} · ${item.sourceFolio}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Pendiente desde ${_fmtDate(item.cutDate)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF7A6C63),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.reason.isEmpty
                                            ? 'Sin comentario de observación.'
                                            : item.reason,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cerrar'),
                  ),
                  if (allowContinueToOpening) ...[
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: contractPrimaryButtonStyle(context),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continuar a apertura'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionPasswordDialog extends StatefulWidget {
  final String title;
  final String message;

  const _DirectionPasswordDialog({required this.title, required this.message});

  @override
  State<_DirectionPasswordDialog> createState() =>
      _DirectionPasswordDialogState();
}

class _DirectionPasswordDialogState extends State<_DirectionPasswordDialog> {
  final TextEditingController _passwordC = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _passwordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordC.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await AuthAccess.validateDirectionPassword(_passwordC.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = 'La contraseña de Dirección no es válida.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: AreaThemeScope(
        tokens: tokens,
        child: Theme(
          data: _menudeoDashboardDialogTheme(Theme.of(context), tokens),
          child: ContractPopupSurface(
            constraints: const BoxConstraints(
              minWidth: 520,
              maxWidth: 620,
              maxHeight: 520,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: tokens.primaryStrong.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 14),
                _DashboardCutField(
                  label: 'Contraseña de Dirección',
                  child: TextField(
                    controller: _passwordC,
                    focusNode: _passwordFocus,
                    obscureText: _obscure,
                    style: _dashboardCutInputTextStyle(tokens),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: 'Capturar contraseña',
                      hintStyle: _dashboardCutHintTextStyle(tokens),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: tokens.primaryStrong.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A3C2C),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _dashboardCutSecondaryButtonStyle(tokens),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: _dashboardCutPrimaryButtonStyle(tokens),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(_submitting ? 'Validando...' : 'Autorizar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashCountCapture {
  final double countedCashTotal;
  final String notes;

  const _CashCountCapture({
    required this.countedCashTotal,
    required this.notes,
  });
}

class _CashCountDialog extends StatefulWidget {
  final _MenudeoCashCutDraft initial;

  const _CashCountDialog({required this.initial});

  @override
  State<_CashCountDialog> createState() => _CashCountDialogState();
}

class _CashCountDialogState extends State<_CashCountDialog> {
  late final TextEditingController _countedC;
  late final TextEditingController _notesC;

  @override
  void initState() {
    super.initState();
    _countedC = TextEditingController(
      text: widget.initial.countedCashTotal == 0
          ? ''
          : widget.initial.countedCashTotal.toStringAsFixed(2),
    );
    _notesC = TextEditingController(text: widget.initial.notes);
  }

  @override
  void dispose() {
    _countedC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: AreaThemeScope(
        tokens: tokens,
        child: Theme(
          data: _menudeoDashboardDialogTheme(Theme.of(context), tokens),
          child: ContractPopupSurface(
            constraints: const BoxConstraints(
              minWidth: 520,
              maxWidth: 620,
              maxHeight: 420,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Conteo real de caja',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Captura el dinero real contado en caja y luego pasamos a comprobar gastos, depósitos, ventas y compras en ese orden.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.badgeText,
                  ),
                ),
                const SizedBox(height: 14),
                _DashboardCutField(
                  label: 'Dinero real contado',
                  child: TextField(
                    controller: _countedC,
                    autofocus: true,
                    style: _dashboardCutInputTextStyle(tokens),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '0.00',
                      hintStyle: _dashboardCutHintTextStyle(tokens),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DashboardCutField(
                  label: 'Observación general',
                  child: TextField(
                    controller: _notesC,
                    maxLines: 3,
                    style: _dashboardCutInputTextStyle(tokens),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Opcional',
                      hintStyle: _dashboardCutHintTextStyle(tokens),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _dashboardCutSecondaryButtonStyle(tokens),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: _dashboardCutPrimaryButtonStyle(tokens),
                      onPressed: () {
                        Navigator.of(context).pop(
                          _CashCountCapture(
                            countedCashTotal:
                                double.tryParse(_countedC.text.trim()) ?? 0,
                            notes: _notesC.text.trim(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Empezar comprobación'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashCutReviewBatch {
  final String label;
  final String sourceType;
  final List<_CashCutReviewItem> items;

  const _CashCutReviewBatch({
    required this.label,
    required this.sourceType,
    required this.items,
  });
}

class _CashCutReviewItem {
  final String sourceId;
  final String sourceFolio;
  final String sourceType;
  final String title;
  final String subtitle;
  final String detail;
  final double amount;
  final Map<String, dynamic>? previewHeader;
  final List<Map<String, dynamic>> previewLines;

  const _CashCutReviewItem({
    required this.sourceId,
    required this.sourceFolio,
    required this.sourceType,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.amount,
    this.previewHeader,
    this.previewLines = const <Map<String, dynamic>>[],
  });
}

class _CashCutCheckDecision {
  final String sourceType;
  final String sourceId;
  final String sourceFolio;
  final bool isVerified;
  final String reason;

  const _CashCutCheckDecision({
    required this.sourceType,
    required this.sourceId,
    required this.sourceFolio,
    required this.isVerified,
    required this.reason,
  });
}

class _CashCutReviewResult {
  final List<_CashCutCheckDecision> checks;
  final String notes;

  const _CashCutReviewResult({required this.checks, required this.notes});

  int get pendingCount => checks.where((item) => !item.isVerified).length;
}

class _CashCutVirtualFlowResult {
  final List<_CashCutCheckDecision> decisions;
  final int batchIndex;
  final int itemIndex;
  final bool finished;

  const _CashCutVirtualFlowResult({
    required this.decisions,
    required this.batchIndex,
    required this.itemIndex,
    required this.finished,
  });

  int get pendingCount => decisions.where((item) => !item.isVerified).length;
}

// ignore: unused_element
class _CashCutReviewDialog extends StatefulWidget {
  final List<_CashCutReviewBatch> batches;
  final double countedCashTotal;
  final double openingCash;
  final double theoreticalCash;
  final String notes;
  final Future<_CashCutVirtualFlowResult?> Function(
    int batchIndex,
    int itemIndex,
    List<_CashCutCheckDecision> decisions,
  )
  onOpenVirtualFlow;

  const _CashCutReviewDialog({
    required this.batches,
    required this.countedCashTotal,
    required this.openingCash,
    required this.theoreticalCash,
    required this.notes,
    required this.onOpenVirtualFlow,
  });

  @override
  State<_CashCutReviewDialog> createState() => _CashCutReviewDialogState();
}

class _CashCutVirtualFlowDialog extends StatefulWidget {
  final List<_CashCutReviewBatch> batches;
  final int initialBatchIndex;
  final int initialItemIndex;
  final List<_CashCutCheckDecision> initialDecisions;
  final double countedCashTotal;
  final double openingCash;
  final double theoreticalCash;

  const _CashCutVirtualFlowDialog({
    required this.batches,
    required this.initialBatchIndex,
    required this.initialItemIndex,
    required this.initialDecisions,
    required this.countedCashTotal,
    required this.openingCash,
    required this.theoreticalCash,
  });

  @override
  State<_CashCutVirtualFlowDialog> createState() =>
      _CashCutVirtualFlowDialogState();
}

// ignore: unused_element
class _CashCutVirtualFlowDialogState extends State<_CashCutVirtualFlowDialog> {
  final SupabaseClient _supa = Supabase.instance.client;
  final FocusNode _focusNode = FocusNode();
  final Map<String, _CashCutCheckDecision> _decisions =
      <String, _CashCutCheckDecision>{};
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _ticketRow;
  Map<String, dynamic>? _voucherHeader;
  List<Map<String, dynamic>> _voucherLines = const <Map<String, dynamic>>[];
  late final List<_CashCutReviewBatch> _nonEmptyBatches;
  late int _batchIndex;
  late int _itemIndex;

  @override
  void initState() {
    super.initState();
    _nonEmptyBatches = widget.batches
        .where((batch) => batch.items.isNotEmpty)
        .toList(growable: false);
    _batchIndex = widget.initialBatchIndex.clamp(
      0,
      _nonEmptyBatches.isEmpty ? 0 : _nonEmptyBatches.length - 1,
    );
    _itemIndex = widget.initialItemIndex.clamp(
      0,
      _nonEmptyBatches.isEmpty
          ? 0
          : _nonEmptyBatches[_batchIndex].items.length - 1,
    );
    for (final decision in widget.initialDecisions) {
      _decisions[_decisionKey(
            decision.sourceType,
            decision.sourceId,
            decision.sourceFolio,
          )] =
          decision;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    unawaited(_loadCurrent());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _decisionKey(String sourceType, String sourceId, String sourceFolio) =>
      '$sourceType|$sourceId|$sourceFolio';

  _CashCutReviewBatch? get _currentBatch =>
      _nonEmptyBatches.isEmpty ? null : _nonEmptyBatches[_batchIndex];

  _CashCutReviewItem? get _currentItem {
    final batch = _currentBatch;
    if (batch == null || batch.items.isEmpty) return null;
    return batch.items[_itemIndex];
  }

  _CashCutCheckDecision? get _currentDecision {
    final batch = _currentBatch;
    final item = _currentItem;
    if (batch == null || item == null) return null;
    return _decisions[_decisionKey(
      batch.sourceType,
      item.sourceId,
      item.sourceFolio,
    )];
  }

  int get _globalItemCount =>
      _nonEmptyBatches.fold<int>(0, (sum, batch) => sum + batch.items.length);

  int get _globalItemPosition {
    var offset = 0;
    for (var i = 0; i < _batchIndex; i++) {
      offset += _nonEmptyBatches[i].items.length;
    }
    return offset + _itemIndex + 1;
  }

  Future<void> _loadCurrent() async {
    final item = _currentItem;
    if (item == null) return;
    setState(() {
      _loading = true;
      _error = '';
      _ticketRow = null;
      _voucherHeader = null;
      _voucherLines = const <Map<String, dynamic>>[];
    });
    try {
      if (item.previewHeader != null) {
        if (item.sourceType == 'expense_voucher' ||
            item.sourceType == 'deposit_voucher') {
          if (!mounted) return;
          setState(() {
            _voucherHeader = item.previewHeader;
            _voucherLines = item.previewLines;
            _loading = false;
          });
          return;
        }
        if (!mounted) return;
        setState(() {
          _ticketRow = item.previewHeader;
          _loading = false;
        });
        return;
      }
      if (item.sourceType == 'expense_voucher' ||
          item.sourceType == 'deposit_voucher') {
        final header = await _supa
            .from('vw_men_cash_vouchers_grid')
            .select(
              'id,voucher_date,folio,voucher_type,person_label,rubric,comment,total_amount',
            )
            .eq('id', item.sourceId)
            .single();
        final lines = await _supa
            .from('men_cash_voucher_lines')
            .select(
              'line_order,concept,unit,quantity,company,driver,destination,subconcept,mode,amount,comment',
            )
            .eq('voucher_id', item.sourceId)
            .order('line_order');
        if (!mounted) return;
        setState(() {
          _voucherHeader = Map<String, dynamic>.from(header);
          _voucherLines = (lines as List)
              .cast<Map<String, dynamic>>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
          _loading = false;
        });
        return;
      }

      final row = await _supa
          .from('vw_men_tickets_grid')
          .select(
            'id,ticket_date,ticket_number,counterparty_name_snapshot,material_label_snapshot,price_at_entry,gross_weight,tare_weight,humidity_percent,trash_weight,premium_per_kg,payable_weight,amount_total,status,comment,exit_order_number,direction',
          )
          .eq('id', item.sourceId)
          .single();
      if (!mounted) return;
      setState(() {
        _ticketRow = Map<String, dynamic>.from(row);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setVerified(bool verified, {String reason = ''}) async {
    final batch = _currentBatch;
    final item = _currentItem;
    if (batch == null || item == null) return;
    _decisions[_decisionKey(
      batch.sourceType,
      item.sourceId,
      item.sourceFolio,
    )] = _CashCutCheckDecision(
      sourceType: batch.sourceType,
      sourceId: item.sourceId,
      sourceFolio: item.sourceFolio,
      isVerified: verified,
      reason: reason,
    );
    if (!_moveNextInternal()) {
      if (!mounted) return;
      Navigator.of(context).pop(
        _CashCutVirtualFlowResult(
          decisions: _decisions.values.toList(growable: false),
          batchIndex: _batchIndex,
          itemIndex: _itemIndex,
          finished: true,
        ),
      );
      return;
    }
    await _loadCurrent();
  }

  Future<void> _markPending() async {
    final current = _currentDecision;
    final reason = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) =>
          _CashCutReasonDialog(initial: current?.reason ?? ''),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _setVerified(false, reason: reason.trim());
  }

  bool _moveNextInternal() {
    final batch = _currentBatch;
    if (batch == null) return false;
    if (_itemIndex < batch.items.length - 1) {
      setState(() => _itemIndex += 1);
      return true;
    }
    if (_batchIndex < _nonEmptyBatches.length - 1) {
      setState(() {
        _batchIndex += 1;
        _itemIndex = 0;
      });
      return true;
    }
    return false;
  }

  bool _movePreviousInternal() {
    if (_nonEmptyBatches.isEmpty) return false;
    if (_itemIndex > 0) {
      setState(() => _itemIndex -= 1);
      return true;
    }
    if (_batchIndex > 0) {
      setState(() {
        _batchIndex -= 1;
        _itemIndex = _nonEmptyBatches[_batchIndex].items.length - 1;
      });
      return true;
    }
    return false;
  }

  Future<void> _goPrevious() async {
    if (_movePreviousInternal()) {
      await _loadCurrent();
    }
  }

  Future<void> _goNext() async {
    if (_moveNextInternal()) {
      await _loadCurrent();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      unawaited(_goPrevious());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      unawaited(_goNext());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      unawaited(_setVerified(true));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      unawaited(_markPending());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _closeNavigator() {
    Navigator.of(context).pop(
      _CashCutVirtualFlowResult(
        decisions: _decisions.values.toList(growable: false),
        batchIndex: _batchIndex,
        itemIndex: _itemIndex,
        finished: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final currentBatch = _currentBatch;
    final currentItem = _currentItem;
    final currentDecision = _currentDecision;
    final difference = widget.countedCashTotal - widget.theoreticalCash;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(
          minWidth: 760,
          maxWidth: 980,
          maxHeight: 900,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Virtual de corte',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _closeNavigator,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (currentBatch != null && currentItem != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AlertPill(
                      title:
                          '${currentBatch.label} · ${_itemIndex + 1} de ${currentBatch.items.length}',
                      tone: const Color(0xFFB65C2A),
                    ),
                    _AlertPill(
                      title: currentItem.sourceFolio,
                      tone: const Color(0xFFC47A18),
                    ),
                    _AlertPill(
                      title: '$_globalItemPosition de $_globalItemCount',
                      tone: const Color(0xFF8C6C5A),
                    ),
                    _AlertPill(
                      title: 'Conteo ${_money(widget.countedCashTotal)}',
                      tone: const Color(0xFF8C6C5A),
                    ),
                    _AlertPill(
                      title: 'Dif. ${_money(difference)}',
                      tone: difference.abs() < 0.01
                          ? const Color(0xFF5A8466)
                          : const Color(0xFF7A3422),
                    ),
                    if (currentDecision != null)
                      _AlertPill(
                        title: currentDecision.isVerified
                            ? 'Comprobado'
                            : 'No comprobado',
                        tone: currentDecision.isVerified
                            ? const Color(0xFF5A8466)
                            : const Color(0xFF7A3422),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          'No se pudo cargar el virtual:\n$_error',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.badgeText,
                          ),
                        ),
                      )
                    : _ticketRow != null
                    ? SingleChildScrollView(
                        child: _CashCutTicketPreviewContent(row: _ticketRow!),
                      )
                    : _voucherHeader != null
                    ? SingleChildScrollView(
                        child: _CashCutVoucherPreviewContent(
                          header: _voucherHeader!,
                          lines: _voucherLines,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _goPrevious,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _markPending,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('No comprobado'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: contractPrimaryButtonStyle(context),
                      onPressed: () => _setVerified(true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Comprobado'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enter marca comprobado y avanza. Space pide comentario de no comprobación y avanza. ← y → navegan el lote sin salir del virtual.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _money(num value) => formatMoney(value);
}

class _CashCutReviewDialogState extends State<_CashCutReviewDialog> {
  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _notesC;
  late final List<_CashCutReviewBatch> _nonEmptyBatches;
  final Map<String, _CashCutCheckDecision> _decisions =
      <String, _CashCutCheckDecision>{};
  int _batchIndex = 0;
  int _itemIndex = 0;

  @override
  void initState() {
    super.initState();
    _notesC = TextEditingController(text: widget.notes);
    _nonEmptyBatches = widget.batches
        .where((batch) => batch.items.isNotEmpty)
        .toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _notesC.dispose();
    super.dispose();
  }

  String _decisionKey(String sourceType, String sourceId, String sourceFolio) =>
      '$sourceType|$sourceId|$sourceFolio';

  _CashCutReviewBatch? get _currentBatch =>
      _nonEmptyBatches.isEmpty ? null : _nonEmptyBatches[_batchIndex];

  _CashCutReviewItem? get _currentItem {
    final batch = _currentBatch;
    if (batch == null || batch.items.isEmpty) return null;
    return batch.items[_itemIndex];
  }

  _CashCutCheckDecision? get _currentDecision {
    final batch = _currentBatch;
    final item = _currentItem;
    if (batch == null || item == null) return null;
    return _decisions[_decisionKey(
      batch.sourceType,
      item.sourceId,
      item.sourceFolio,
    )];
  }

  int get _totalItems =>
      _nonEmptyBatches.fold<int>(0, (sum, batch) => sum + batch.items.length);

  int get _completedItems => _decisions.length;

  bool _moveNext() {
    final batch = _currentBatch;
    if (batch == null) return false;
    if (_itemIndex < batch.items.length - 1) {
      setState(() => _itemIndex += 1);
      return true;
    }
    if (_batchIndex < _nonEmptyBatches.length - 1) {
      setState(() {
        _batchIndex += 1;
        _itemIndex = 0;
      });
      return true;
    }
    return false;
  }

  bool _movePrevious() {
    if (_nonEmptyBatches.isEmpty) return false;
    if (_itemIndex > 0) {
      setState(() => _itemIndex -= 1);
      return true;
    }
    if (_batchIndex > 0) {
      setState(() {
        _batchIndex -= 1;
        _itemIndex = _nonEmptyBatches[_batchIndex].items.length - 1;
      });
      return true;
    }
    return false;
  }

  void _saveDecision({required bool verified, required String reason}) {
    final batch = _currentBatch;
    final item = _currentItem;
    if (batch == null || item == null) return;
    _decisions[_decisionKey(
      batch.sourceType,
      item.sourceId,
      item.sourceFolio,
    )] = _CashCutCheckDecision(
      sourceType: batch.sourceType,
      sourceId: item.sourceId,
      sourceFolio: item.sourceFolio,
      isVerified: verified,
      reason: reason,
    );
  }

  void _finish() {
    final checks = <_CashCutCheckDecision>[];
    for (final batch in _nonEmptyBatches) {
      for (final item in batch.items) {
        final decision =
            _decisions[_decisionKey(
              batch.sourceType,
              item.sourceId,
              item.sourceFolio,
            )];
        checks.add(
          decision ??
              _CashCutCheckDecision(
                sourceType: batch.sourceType,
                sourceId: item.sourceId,
                sourceFolio: item.sourceFolio,
                isVerified: false,
                reason: 'No se revisó durante el corte.',
              ),
        );
      }
    }
    Navigator.of(
      context,
    ).pop(_CashCutReviewResult(checks: checks, notes: _notesC.text.trim()));
  }

  Future<void> _markCurrentAsVerified() async {
    _saveDecision(verified: true, reason: '');
    if (!_moveNext()) {
      _finish();
    }
  }

  Future<void> _markCurrentAsPending() async {
    final current = _currentDecision;
    final reason = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) =>
          _CashCutReasonDialog(initial: current?.reason ?? ''),
    );
    if (reason == null || reason.trim().isEmpty) return;
    _saveDecision(verified: false, reason: reason.trim());
    if (!_moveNext()) {
      _finish();
    }
  }

  Future<void> _openVirtualFlow() async {
    final result = await widget.onOpenVirtualFlow(
      _batchIndex,
      _itemIndex,
      _decisions.values.toList(growable: false),
    );
    if (result == null || !mounted) return;
    setState(() {
      _decisions
        ..clear()
        ..addEntries(
          result.decisions.map(
            (item) => MapEntry(
              _decisionKey(item.sourceType, item.sourceId, item.sourceFolio),
              item,
            ),
          ),
        );
      _batchIndex = result.batchIndex.clamp(
        0,
        _nonEmptyBatches.isEmpty ? 0 : _nonEmptyBatches.length - 1,
      );
      final maxItemIndex = _nonEmptyBatches.isEmpty
          ? 0
          : _nonEmptyBatches[_batchIndex].items.length - 1;
      _itemIndex = result.itemIndex.clamp(0, maxItemIndex);
    });
    if (result.finished && mounted) {
      _finish();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _movePrevious();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveNext();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      unawaited(_markCurrentAsVerified());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      unawaited(_markCurrentAsPending());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _money(num value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final currentBatch = _currentBatch;
    final currentItem = _currentItem;
    final currentDecision = _currentDecision;
    final difference = widget.countedCashTotal - widget.theoreticalCash;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(
          minWidth: 760,
          maxWidth: 980,
          maxHeight: 860,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Corte de caja',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AlertPill(
                    title: 'Conteo real ${_money(widget.countedCashTotal)}',
                    tone: const Color(0xFFB65C2A),
                  ),
                  _AlertPill(
                    title: 'Teórico ${_money(widget.theoreticalCash)}',
                    tone: const Color(0xFFC47A18),
                  ),
                  _AlertPill(
                    title: 'Diferencia ${_money(difference)}',
                    tone: difference.abs() < 0.01
                        ? const Color(0xFF5A8466)
                        : const Color(0xFF7A3422),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_nonEmptyBatches.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No hay gastos, depósitos, ventas ni compras para comprobar hoy.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.badgeText,
                      ),
                    ),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List<Widget>.generate(_nonEmptyBatches.length, (
                    index,
                  ) {
                    final batch = _nonEmptyBatches[index];
                    final active = index == _batchIndex;
                    final completed = batch.items
                        .where(
                          (item) => _decisions.containsKey(
                            _decisionKey(
                              batch.sourceType,
                              item.sourceId,
                              item.sourceFolio,
                            ),
                          ),
                        )
                        .length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? tokens.primarySoft.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? tokens.primaryStrong.withValues(alpha: 0.42)
                              : tokens.primarySoft.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: tokens.primaryStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completed / ${batch.items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: tokens.badgeText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: tokens.primarySoft.withValues(alpha: 0.26),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: currentBatch == null || currentItem == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${currentBatch.label} · ${_itemIndex + 1} de ${currentBatch.items.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.badgeText,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: _openVirtualFlow,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          currentItem.sourceFolio,
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: tokens.primaryStrong,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: tokens
                                                .primaryStrong
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _DashboardCutField(
                                      label: currentBatch.label == 'Ventas'
                                          ? 'Cliente'
                                          : currentBatch.label == 'Compras'
                                          ? 'Proveedor'
                                          : 'Persona',
                                      child: Text(
                                        currentItem.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _DashboardCutField(
                                      label:
                                          currentBatch.label == 'Ventas' ||
                                              currentBatch.label == 'Compras'
                                          ? 'Material'
                                          : 'Rubro',
                                      child: Text(
                                        currentItem.subtitle,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (currentItem.detail.isNotEmpty)
                                      _DashboardCutField(
                                        label: 'Detalle',
                                        child: Text(
                                          currentItem.detail,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    if (currentItem.detail.isNotEmpty)
                                      const SizedBox(height: 10),
                                    _DashboardCutField(
                                      label: 'Importe',
                                      child: Text(
                                        _money(currentItem.amount),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (currentDecision != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: currentDecision.isVerified
                                              ? const Color(
                                                  0xFF5A8466,
                                                ).withValues(alpha: 0.12)
                                              : const Color(
                                                  0xFFB65C2A,
                                                ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          currentDecision.isVerified
                                              ? 'Comprobado'
                                              : 'No comprobado: ${currentDecision.reason}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: currentDecision.isVerified
                                                ? const Color(0xFF356245)
                                                : const Color(0xFF7A3422),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ContractGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Atajos',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Enter: comprobado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Space: no comprobado + comentario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '← →: mover entre folios',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ContractGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Observación general',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _notesC,
                                    maxLines: 5,
                                    decoration: const InputDecoration.collapsed(
                                      hintText: 'Opcional',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: contractSecondaryButtonStyle(
                                      context,
                                    ),
                                    onPressed: _movePrevious,
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    label: const Text('Anterior'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: contractSecondaryButtonStyle(
                                      context,
                                    ),
                                    onPressed: _moveNext,
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Siguiente'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: contractSecondaryButtonStyle(
                                      context,
                                    ),
                                    onPressed: _markCurrentAsPending,
                                    icon: const Icon(Icons.edit_note_rounded),
                                    label: const Text('No comprobado'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: contractPrimaryButtonStyle(context),
                                    onPressed: _markCurrentAsVerified,
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Comprobado'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              style: _dashboardCutTonalButtonStyle(tokens),
                              onPressed: _openVirtualFlow,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Abrir virtual'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              style: _dashboardCutTonalButtonStyle(tokens),
                              onPressed: _finish,
                              icon: const Icon(Icons.save_rounded),
                              label: Text(
                                _completedItems >= _totalItems
                                    ? 'Guardar corte'
                                    : 'Guardar como va',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Revisados $_completedItems de $_totalItems. El recorrido sigue el orden físico: gastos, depósitos, ventas y compras, todos en ascendente.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tokens.badgeText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CashCutReasonDialog extends StatefulWidget {
  final String initial;

  const _CashCutReasonDialog({required this.initial});

  @override
  State<_CashCutReasonDialog> createState() => _CashCutReasonDialogState();
}

class _CashCutReasonDialogState extends State<_CashCutReasonDialog> {
  late final TextEditingController _reasonC;

  @override
  void initState() {
    super.initState();
    _reasonC = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _reasonC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: ContractPopupSurface(
        constraints: const BoxConstraints(
          minWidth: 520,
          maxWidth: 620,
          maxHeight: 360,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Motivo de no comprobación',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonC,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Ej. Falta ticket físico, no coincide el importe, no era el precio autorizado...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: () =>
                      Navigator.of(context).pop(_reasonC.text.trim()),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar y seguir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashCutTicketPreviewContent extends StatelessWidget {
  final Map<String, dynamic> row;

  const _CashCutTicketPreviewContent({required this.row});

  String _displayDate(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    if (parsed == null) return (raw ?? '').toString();
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _money(num value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final gross = (row['gross_weight'] as num?)?.toDouble() ?? 0;
    final tare = (row['tare_weight'] as num?)?.toDouble() ?? 0;
    final humidity = (row['humidity_percent'] as num?)?.toDouble() ?? 0;
    final trash = (row['trash_weight'] as num?)?.toDouble() ?? 0;
    final premium = (row['premium_per_kg'] as num?)?.toDouble() ?? 0;
    final payable = (row['payable_weight'] as num?)?.toDouble() ?? 0;
    final amount = (row['amount_total'] as num?)?.toDouble() ?? 0;
    final price = (row['price_at_entry'] as num?)?.toDouble() ?? 0;
    final net = gross - tare;
    final isSale = (row['direction'] ?? '').toString() == 'sale';
    final exitOrder = (row['exit_order_number'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ticket virtual',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: tokens.primaryStrong,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AlertPill(
              title: 'Ticket ${(row['ticket_number'] ?? '').toString()}',
              tone: const Color(0xFFB65C2A),
            ),
            _AlertPill(
              title: _displayDate(row['ticket_date']),
              tone: const Color(0xFFC47A18),
            ),
            _AlertPill(
              title: (row['status'] ?? 'PENDIENTE').toString(),
              tone: ((row['status'] ?? '').toString() == 'PAGADO')
                  ? const Color(0xFF5A8466)
                  : const Color(0xFF7A3422),
            ),
            if (isSale && exitOrder.isNotEmpty)
              _AlertPill(
                title: 'Orden $exitOrder',
                tone: const Color(0xFF5A8466),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _DashboardCutField(
          label: isSale ? 'Cliente' : 'Proveedor',
          child: Text(
            (row['counterparty_name_snapshot'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        _DashboardCutField(
          label: 'Material',
          child: Text(
            (row['material_label_snapshot'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DashboardCutField(
                label: 'Bruto',
                child: Text(
                  '$gross',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Tara',
                child: Text(
                  '$tare',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Neto',
                child: Text(
                  '$net',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DashboardCutField(
                label: 'Humedad %',
                child: Text(
                  '$humidity',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Basura',
                child: Text(
                  '$trash',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Peso pagable',
                child: Text(
                  '$payable',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DashboardCutField(
                label: 'Precio',
                child: Text(
                  _money(price),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Sobreprecio',
                child: Text(
                  _money(premium),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Importe',
                child: Text(
                  _money(amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        if ((row['comment'] ?? '').toString().trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _DashboardCutField(
            label: 'Comentario',
            child: Text(
              (row['comment'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _CashCutVoucherPreviewContent extends StatelessWidget {
  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> lines;

  const _CashCutVoucherPreviewContent({
    required this.header,
    required this.lines,
  });

  String _displayDate(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    if (parsed == null) return (raw ?? '').toString();
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _money(num value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isDeposit = (header['voucher_type'] ?? '').toString() == 'deposit';
    final total = (header['total_amount'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Voucher virtual',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: tokens.primaryStrong,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AlertPill(
              title: 'Folio ${(header['folio'] ?? '').toString()}',
              tone: const Color(0xFFB65C2A),
            ),
            _AlertPill(
              title: _displayDate(header['voucher_date']),
              tone: const Color(0xFFC47A18),
            ),
            _AlertPill(
              title: isDeposit ? 'DEPÓSITO' : 'GASTO',
              tone: isDeposit
                  ? const Color(0xFF5A8466)
                  : const Color(0xFF7A3422),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DashboardCutField(
                label: isDeposit ? 'Recibido de' : 'Entregado a',
                child: Text(
                  (header['person_label'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardCutField(
                label: 'Rubro',
                child: Text(
                  (header['rubric'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Renglones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: tokens.primaryStrong,
          ),
        ),
        const SizedBox(height: 10),
        ...lines.map(
          (line) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tokens.primarySoft.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (line['concept'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _money(
                        (line['amount'] as num?)?.toDouble() ??
                            double.tryParse(
                              (line['amount'] ?? '').toString(),
                            ) ??
                            0,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in <(String, String)>[
                      ('Unidad', (line['unit'] ?? '').toString()),
                      ('Cantidad', (line['quantity'] ?? '').toString()),
                      ('Empresa', (line['company'] ?? '').toString()),
                      ('Chofer', (line['driver'] ?? '').toString()),
                      ('Destino', (line['destination'] ?? '').toString()),
                      ('Subconcepto', (line['subconcept'] ?? '').toString()),
                      ('Modo', (line['mode'] ?? '').toString()),
                    ])
                      if (entry.$2.trim().isNotEmpty)
                        _AlertPill(
                          title: '${entry.$1}: ${entry.$2}',
                          tone: const Color(0xFF8C6C5A),
                        ),
                  ],
                ),
                if ((line['comment'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (line['comment'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _DashboardCutField(
          label: 'Total',
          child: Text(
            _money(total),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        if ((header['comment'] ?? '').toString().trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _DashboardCutField(
            label: 'Comentario general',
            child: Text(
              (header['comment'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardWeightRow {
  final String label;
  final double weight;

  const _DashboardWeightRow({required this.label, required this.weight});
}

class _DashboardPriceReferenceRow {
  final String material;
  final double? purchasePrice;
  final double? salePrice;

  const _DashboardPriceReferenceRow({
    required this.material,
    required this.purchasePrice,
    required this.salePrice,
  });
}

class _DashboardBarBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_DashboardWeightRow> rows;
  final Color accent;
  final String emptyLabel;

  const _DashboardBarBlock({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.accent,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxWeight = rows.isEmpty
        ? 1.0
        : rows.map((row) => row.weight).reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF202629),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666461),
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A7773),
            ),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2C3133),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${row.weight.toStringAsFixed(0)} kg',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: row.weight / maxWeight,
                      minHeight: 10,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardPriceReferenceBlock extends StatelessWidget {
  final List<_DashboardPriceReferenceRow> rows;

  const _DashboardPriceReferenceBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precios Rápidos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF202629),
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const Text(
            'Todavía no hay precios activos para mostrar aquí.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A7773),
            ),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFCDAE9E).withValues(alpha: 0.40),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.material,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3133),
                        ),
                      ),
                    ),
                    Text(
                      'C ${_price(row.purchasePrice)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A3422),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'V ${_price(row.salePrice)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A6F56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _price(double? value) {
    if (value == null) return '--';
    return formatMoney(value);
  }
}

class _AlertPill extends StatelessWidget {
  final String title;
  final Color tone;

  const _AlertPill({required this.title, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _MenudeoSidePanel extends StatelessWidget {
  final Future<void> Function() onBack;
  final Future<void> Function() onOpenOperationalDashboard;
  final ValueChanged<String> onStubTap;
  final bool canReturnToDirection;

  const _MenudeoSidePanel({
    required this.onBack,
    required this.onOpenOperationalDashboard,
    required this.onStubTap,
    required this.canReturnToDirection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _MenudeoPanelItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: onBack,
                ),
                const SizedBox(height: 10),
              ],
              const _MenudeoSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x66EFD7C2),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _MenudeoPanelItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Compras',
                      subtitle: 'Tickets virtuales de compra',
                      onTapSync: () => onStubTap('Tickets de menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _MenudeoPanelItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Tickets virtuales de venta',
                      onTapSync: () => onStubTap('Ventas menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _MenudeoPanelItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Depósitos y gastos',
                      subtitle: 'Vouchers de caja y egresos',
                      onTapSync: () => onStubTap('Depósitos y gastos'),
                    ),
                    const SizedBox(height: 8),
                    _MenudeoPanelItem(
                      icon: Icons.auto_graph_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      onTapSync: () => onStubTap('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _MenudeoPanelItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Materiales, grupos y precios',
                      onTapSync: () => onStubTap('Catálogo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _MenudeoSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _MenudeoPanelItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: onBack,
                ),
                const SizedBox(height: 8),
                _MenudeoPanelItem(
                  icon: Icons.precision_manufacturing_rounded,
                  title: 'Dashboard Operación',
                  subtitle: 'Patio, inventario y servicios',
                  onTap: onOpenOperationalDashboard,
                ),
                const SizedBox(height: 8),
              ],
              _MenudeoPanelItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Menudeo',
                subtitle: 'Vista general del área',
                accented: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoSectionHeader extends StatelessWidget {
  final String label;

  const _MenudeoSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _MenudeoPanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool accented;

  const _MenudeoPanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onTapSync,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            if (onTap != null) {
              await onTap!();
            } else {
              onTapSync?.call();
            }
          },
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE5A56F), Color(0xFFCF7E59)],
                    )
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFF6E2D1), Color(0xFFE7B992)],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? const Color(0xFFF7DCC5)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB46D4F).withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFB97A5C).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: accented
                              ? Colors.white
                              : const Color(0xFF7E4632),
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accented
                                ? Colors.white.withValues(alpha: 0.92)
                                : const Color(0xFF8F5A44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8A513B),
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenudeoHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MenudeoHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_MenudeoHeaderButton> createState() => _MenudeoHeaderButtonState();
}

class _MenudeoHeaderButtonState extends State<_MenudeoHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.30 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.34 : 0.24,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.46),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.primaryStrong.withValues(
                      alpha: highlighted ? 0.10 : 0.04,
                    ),
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
}

class _MenudeoBackground extends StatelessWidget {
  const _MenudeoBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                tokens.primarySoft.withValues(alpha: 0.9),
                tokens.accent.withValues(alpha: 0.38),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -110,
          child: _blurCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                tokens.primarySoft.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        Positioned(
          right: -210,
          top: -70,
          child: _blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.accent.withValues(alpha: 0.82),
                tokens.glow.withValues(alpha: 0.44),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -250,
          child: _blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.primary.withValues(alpha: 0.32),
                tokens.primarySoft.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        Positioned(
          right: -110,
          bottom: -120,
          child: Container(
            width: 320,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(220),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.accent.withValues(alpha: 0.95),
                  tokens.primaryStrong.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient gradient) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}
