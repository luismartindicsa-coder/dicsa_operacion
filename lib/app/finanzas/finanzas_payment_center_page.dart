import 'dart:async';
import 'package:flutter/material.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/date_picker_defaults.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_payment_center_budget_engine.dart';
import 'finanzas_payment_center_budget_loader.dart';
import 'finanzas_payment_center_budget_models.dart';
import 'finanzas_payment_center_reserves_store.dart';
import 'finanzas_payment_learning_store.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_theme.dart';

enum _PaymentCenterMode {
  presupuesto('Presupuesto'),
  pendientes('Pendientes'),
  reservas('Reservas protegidas'),
  aprendizaje('Aprendizaje');

  final String label;
  const _PaymentCenterMode(this.label);
}

ThemeData _paymentCenterContractTheme(BuildContext context) {
  final base = Theme.of(context);
  final tokens = AreaThemeScope.of(context);
  final colorScheme = base.colorScheme.copyWith(
    primary: tokens.primaryStrong,
    secondary: tokens.primary,
    surface: tokens.surfaceTint,
    onSurface: tokens.onGlass,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: tokens.border.withValues(alpha: 0.42)),
  );
  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    splashColor: tokens.primaryStrong.withValues(alpha: 0.12),
    highlightColor: tokens.primaryStrong.withValues(alpha: 0.08),
    hoverColor: tokens.primarySoft.withValues(alpha: 0.12),
    focusColor: tokens.primarySoft.withValues(alpha: 0.16),
    dividerColor: tokens.border.withValues(alpha: 0.24),
    iconTheme: IconThemeData(color: tokens.primaryStrong),
    textButtonTheme: TextButtonThemeData(
      style: _paymentCenterTextButtonStyle(context),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _paymentCenterOutlinedButtonStyle(context),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _paymentCenterFilledButtonStyle(context),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.fieldSurface,
      hintStyle: TextStyle(color: tokens.onGlass.withValues(alpha: 0.62)),
      labelStyle: TextStyle(
        color: tokens.badgeText,
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.primaryStrong, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.badgeBackground.withValues(alpha: 0.82),
      selectedColor: tokens.primaryStrong.withValues(alpha: 0.18),
      disabledColor: tokens.badgeBackground.withValues(alpha: 0.42),
      side: BorderSide(color: tokens.border.withValues(alpha: 0.38)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelStyle: TextStyle(
        color: tokens.badgeText,
        fontWeight: FontWeight.w800,
      ),
      secondaryLabelStyle: TextStyle(
        color: tokens.primaryStrong,
        fontWeight: FontWeight.w900,
      ),
      checkmarkColor: tokens.primaryStrong,
    ),
  );
}

ThemeData _paymentCenterOverlayTheme(BuildContext context) {
  final base = _paymentCenterContractTheme(context);
  final tokens = AreaThemeScope.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: tokens.primaryStrong,
      onPrimary: tokens.onGlass,
      secondary: tokens.primarySoft,
      onSecondary: tokens.onGlass,
      surface: kFinanzasDialogSurface,
      onSurface: tokens.onGlass,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: kFinanzasDialogSurface),
    textTheme: base.textTheme
        .apply(bodyColor: tokens.onGlass, displayColor: tokens.onGlass)
        .copyWith(
          bodySmall: TextStyle(
            color: kFinanzasMutedInk.withValues(alpha: 0.92),
          ),
          bodyMedium: TextStyle(color: tokens.onGlass),
          bodyLarge: TextStyle(color: tokens.onGlass),
          titleMedium: TextStyle(
            color: tokens.onGlass,
            fontWeight: FontWeight.w800,
          ),
        ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: tokens.onGlass,
      displayColor: tokens.onGlass,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.primaryStrong,
      selectionColor: tokens.primaryStrong.withValues(alpha: 0.24),
      selectionHandleColor: tokens.primaryStrong,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.primaryStrong,
      textColor: tokens.onGlass,
      tileColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.onGlass;
        }
        return kFinanzasMutedInk.withValues(alpha: 0.92);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.primaryStrong.withValues(alpha: 0.92);
        }
        return tokens.badgeBackground.withValues(alpha: 0.94);
      }),
      trackOutlineColor: WidgetStateProperty.all(
        tokens.border.withValues(alpha: 0.42),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: kFinanzasDialogSurface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Color.alphaBlend(
        tokens.primaryStrong.withValues(alpha: 0.08),
        kFinanzasDialogSurface,
      ),
      headerForegroundColor: tokens.onGlass,
      weekdayStyle: TextStyle(
        color: kFinanzasMutedInk.withValues(alpha: 0.92),
        fontWeight: FontWeight.w700,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return kFinanzasMutedInk.withValues(alpha: 0.38);
        }
        return tokens.onGlass;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.primaryStrong;
        }
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.all(tokens.primarySoft),
      cancelButtonStyle: _paymentCenterTextButtonStyle(
        context,
        tone: tokens.primarySoft,
      ),
      confirmButtonStyle: _paymentCenterTextButtonStyle(
        context,
        tone: tokens.primaryStrong,
      ),
    ),
  );
}

InputDecoration _paymentCenterOverlayFieldDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
}) {
  final tokens = AreaThemeScope.of(context);
  final decoration = contractGlassFieldDecoration(context, hintText: hintText);
  return decoration.copyWith(
    labelText: labelText,
    labelStyle: TextStyle(color: tokens.badgeText, fontWeight: FontWeight.w800),
    floatingLabelStyle: TextStyle(
      color: tokens.primaryStrong,
      fontWeight: FontWeight.w900,
    ),
  );
}

TextStyle _paymentCenterOverlayFieldTextStyle(BuildContext context) {
  final tokens = AreaThemeScope.of(context);
  return TextStyle(
    color: tokens.onGlass,
    fontSize: 14.5,
    fontWeight: FontWeight.w800,
  );
}

ButtonStyle _paymentCenterTextButtonStyle(BuildContext context, {Color? tone}) {
  final tokens = AreaThemeScope.of(context);
  final resolvedTone = tone ?? tokens.primaryStrong;
  return TextButton.styleFrom(
    foregroundColor: resolvedTone,
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    overlayColor: resolvedTone.withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

ButtonStyle _paymentCenterOutlinedButtonStyle(
  BuildContext context, {
  Color? tone,
  Color? backgroundColor,
}) {
  final tokens = AreaThemeScope.of(context);
  final resolvedTone = tone ?? tokens.primaryStrong;
  return OutlinedButton.styleFrom(
    foregroundColor: resolvedTone,
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
    side: BorderSide(color: resolvedTone.withValues(alpha: 0.44)),
    backgroundColor:
        backgroundColor ??
        Color.alphaBlend(
          resolvedTone.withValues(alpha: 0.06),
          tokens.glassSurface.withValues(alpha: 0.88),
        ),
    overlayColor: resolvedTone.withValues(alpha: 0.08),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

ButtonStyle _paymentCenterFilledButtonStyle(
  BuildContext context, {
  Color? tone,
  Color? foregroundColor,
}) {
  final tokens = AreaThemeScope.of(context);
  final resolvedTone = tone ?? tokens.primaryStrong;
  return FilledButton.styleFrom(
    foregroundColor: foregroundColor ?? tokens.onGlass,
    backgroundColor: resolvedTone,
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
    overlayColor: (foregroundColor ?? tokens.onGlass).withValues(alpha: 0.08),
    shadowColor: resolvedTone.withValues(alpha: 0.34),
    elevation: 8,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}

class FinanzasPaymentCenterPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasPaymentCenterPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasPaymentCenterPage> createState() =>
      _FinanzasPaymentCenterPageState();
}

class _FinanzasPaymentCenterPageState extends State<FinanzasPaymentCenterPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  _PaymentCenterMode _activeMode = _PaymentCenterMode.presupuesto;
  List<FinanzasPaymentCenterOperationalItem> _items =
      const <FinanzasPaymentCenterOperationalItem>[];
  List<FinanzasPaymentLearningRecord> _learningLogs =
      const <FinanzasPaymentLearningRecord>[];
  Map<String, double> _accountBalances = const <String, double>{};
  Map<String, double> _realAccountBalances = const <String, double>{};
  List<FinanzasPaymentCenterReserveRecord> _reserves =
      const <FinanzasPaymentCenterReserveRecord>[];
  FinanzasPaymentCenterReserveImpactSummary _reserveSummary =
      const FinanzasPaymentCenterReserveImpactSummary.empty();
  FinanzasPaymentCenterBudgetTodaySummary? _budgetToday;
  FinanzasPaymentCenterBudgetWeekSummary? _budgetWeek;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadPage());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
      _canAccessComprasArea = AuthAccess.canAccessComprasArea(profile);
    });
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    try {
      final sourceSnapshot = await loadFinanzasPaymentCenterSourceSnapshot();
      if (!mounted) return;
      final operationalSnapshot = buildFinanzasPaymentCenterOperationalSnapshot(
        sourceSnapshot,
      );
      setState(() {
        _realAccountBalances = operationalSnapshot.realAccountBalances;
        _accountBalances = operationalSnapshot.accountBalances;
        _items = operationalSnapshot.items;
        _learningLogs = operationalSnapshot.learningLogs;
        _reserves = operationalSnapshot.reserves;
        _reserveSummary = operationalSnapshot.reserveSummary;
        _budgetToday = operationalSnapshot.budgetToday;
        _budgetWeek = operationalSnapshot.budgetWeek;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cargar Centro de pagos con la informacion remota actual.',
          ),
        ),
      );
    }
  }

  String _learningActionLabel(FinanzasPaymentCenterExecutionDecision decision) {
    switch (decision) {
      case FinanzasPaymentCenterExecutionDecision.pagarCompleto:
        return 'PAGAR_COMPLETO';
      case FinanzasPaymentCenterExecutionDecision.abonar:
        return 'ABONAR';
      case FinanzasPaymentCenterExecutionDecision.esperar:
        return 'ESPERAR';
    }
  }

  String _learningActionDisplay(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PAGAR_COMPLETO':
        return 'Pagar completo';
      case 'ABONAR':
        return 'Abonar';
      case 'ESPERAR':
        return 'Esperar';
      default:
        return raw.trim().isEmpty ? 'Sin registrar' : raw.trim();
    }
  }

  List<FinanzasPaymentLearningRecord> _buildLearningSnapshotRecords() {
    final capturedAt = DateTime.now();
    return _items
        .map((item) {
          final millis = capturedAt.microsecondsSinceEpoch;
          return FinanzasPaymentLearningRecord(
            id: '${item.providerId}_${item.itemType}_${millis}_${item.priorityScore}',
            capturedAt: capturedAt,
            providerId: item.providerId,
            providerName: item.providerName,
            bucket: item.bucket.label.toUpperCase(),
            itemType: item.itemType,
            sourceLabel: item.sourceLabel,
            dueDate: item.dueDate,
            targetCompany: item.targetCompany,
            targetBranch: item.targetBranch,
            suggestedAction: _learningActionLabel(item.executionDecision),
            suggestedAmount: item.executionAmount > 0
                ? item.executionAmount
                : item.amountSuggested,
            recommendation: item.executionSummary.isNotEmpty
                ? item.executionSummary
                : item.recommendation,
            status: 'PENDIENTE',
            executedAction: null,
            executedAmount: null,
            notes: item.decisionReasons.join(' | '),
            createdAt: null,
            updatedAt: null,
          );
        })
        .toList(growable: false);
  }

  Future<void> _captureLearningSnapshot() async {
    if (_items.isEmpty) return;
    final logs = _buildLearningSnapshotRecords();
    await FinanzasPaymentLearningStore.saveLogs(logs);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se capturó un corte de aprendizaje con ${logs.length} pendientes.',
        ),
      ),
    );
    await _loadPage();
  }

  Future<void> _registerLearningDecision(
    FinanzasPaymentLearningRecord row,
  ) async {
    final amountC = TextEditingController(
      text:
          row.executedAmount?.toStringAsFixed(2) ??
          row.suggestedAmount.toStringAsFixed(2),
    );
    final notesC = TextEditingController(text: row.notes);
    String selectedAction = row.executedAction ?? row.suggestedAction;
    var saving = false;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              final tokens = AreaThemeScope.of(context);
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 640,
                    maxHeight: 560,
                  ),
                  child: SingleChildScrollView(
                    child: ContractGlassCard(
                      borderRadius: BorderRadius.circular(30),
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar decisión',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: tokens.primaryStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            row.providerName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kFinanzasMutedInk,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final action in const <String>[
                                'PAGAR_COMPLETO',
                                'ABONAR',
                                'ESPERAR',
                              ])
                                ChoiceChip(
                                  label: Text(_learningActionDisplay(action)),
                                  selected: selectedAction == action,
                                  onSelected: (_) => setLocalState(
                                    () => selectedAction = action,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: amountC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Monto ejecutado',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: notesC,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Notas',
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setLocalState(() => saving = true);
                                        final parsedAmount =
                                            double.tryParse(
                                              amountC.text
                                                  .replaceAll(',', '')
                                                  .trim(),
                                            ) ??
                                            0;
                                        final updated = row.copyWith(
                                          status: 'REGISTRADO',
                                          executedAction: selectedAction,
                                          executedAmount: parsedAmount,
                                          notes: notesC.text.trim(),
                                        );
                                        await FinanzasPaymentLearningStore.saveLog(
                                          updated,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop(true);
                                        }
                                      },
                                child: const Text('Guardar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      if (saved == true && mounted) {
        await _loadPage();
      }
    } finally {
      amountC.dispose();
      notesC.dispose();
    }
  }

  Future<void> _openReserveDialog({
    FinanzasPaymentCenterReserveRecord? initialRow,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentCenterReserveDialog(initialRow: initialRow),
    );
    if (saved == true && mounted) {
      await _loadPage();
    }
  }

  Future<void> _confirmDeleteReserve(
    FinanzasPaymentCenterReserveRecord row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tokens = AreaThemeScope.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ContractGlassCard(
              borderRadius: BorderRadius.circular(30),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eliminar reserva',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Se eliminará `${row.name}` de Centro de pagos. Esta acción solo afecta reservas protegidas.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kFinanzasMutedInk,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: _paymentCenterFilledButtonStyle(
                          dialogContext,
                          tone: kFinanzasCoral,
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await FinanzasPaymentCenterReservesStore.deleteReserve(row.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMissingPaymentCenterReservesFeatureError(error)
                ? kFinPaymentCenterReservesUnavailableMessage
                : 'No se pudo eliminar la reserva protegida.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reserva eliminada: ${row.name}')));
    await _loadPage();
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasCatalogPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasCompanyDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openProviderAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasProviderAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openBankAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasBankAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPayments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasFixedPaymentsPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPaymentsForRow(
    FinanzasPaymentCenterOperationalItem row,
  ) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: FinanzasFixedPaymentsPage(
          instantOpen: true,
          initialSelectedPaymentId: row.linkedFixedPaymentId,
        ),
      ),
    );
  }

  Future<void> _openBankExecutionForRow(
    FinanzasPaymentCenterOperationalItem row,
  ) async {
    if (!mounted) return;
    final preset = _buildBankLaunchPreset(row);
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: FinanzasBankAccountsPage(instantOpen: true, launchPreset: preset),
      ),
    );
  }

  FinanzasBankMovementLaunchPreset? _buildBankLaunchPreset(
    FinanzasPaymentCenterOperationalItem row,
  ) {
    if (row.itemType == 'Pago fijo' && row.linkedFixedPaymentId != null) {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'PAGO_FIJO',
        linkedFixedPaymentId: row.linkedFixedPaymentId,
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'GASTOS OPERATIVOS',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount > 0
            ? row.executionAmount
            : row.amountSuggested,
      );
    }
    if (row.itemType == 'Factura' && row.linkedInvoiceId != null) {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'COMPRA_FACTURA',
        linkedSupplierInvoiceId: row.linkedInvoiceId,
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'COMPRA DE MATERIAL',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount,
      );
    }
    if (row.itemType == 'Convenio' || row.itemType == 'Saldo general') {
      return FinanzasBankMovementLaunchPreset(
        sourceType: 'MANUAL',
        company: row.targetCompany,
        branch: row.targetBranch,
        counterpartyName: row.providerName,
        counterpartyCompanyId: row.providerId,
        category: 'COMPRA DE MATERIAL',
        reference: row.sourceLabel,
        comment: row.recommendation,
        creditAmount: 0,
        debitAmount: row.executionAmount,
      );
    }
    return null;
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Finanzas':
        unawaited(_openDashboard());
        return;
      case 'Catálogo Finanzas':
        unawaited(_openCatalog());
        return;
      case 'Directorio Empresas':
        unawaited(_openDirectory());
        return;
      case 'Cuentas por Proveedor':
        unawaited(_openProviderAccounts());
        return;
      case 'Cuentas Bancarias':
        unawaited(_openBankAccounts());
        return;
      case 'Pagos fijos':
        unawaited(_openFixedPayments());
        return;
      case 'Centro de pagos':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
    }
  }

  String _money(double value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs().toStringAsFixed(2);
    final parts = absolute.split('.');
    final integer = parts.first;
    final decimal = parts.last;
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final reversed = integer.length - i;
      buffer.write(integer[i]);
      if (reversed > 1 && reversed % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign\$$buffer.$decimal';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '—';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final protectedAccountTotal = _accountBalances.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final realTotalAvailable = _reserveSummary.realTotalBalance;
    final protectedAvailable = _reserveSummary.availableAfterBlocking;
    final displayItems = _items;
    final totalSuggested = displayItems.fold<double>(
      0,
      (sum, row) => sum + row.amountSuggested,
    );
    final visualItemsByBucket =
        <
          FinanzasPaymentCenterPriorityBucket,
          List<FinanzasPaymentCenterOperationalItem>
        >{
          for (final bucket in FinanzasPaymentCenterPriorityBucket.values)
            bucket: displayItems
                .where((row) => row.bucket == bucket)
                .toList(growable: false),
        };
    final payableNowAmount = displayItems.fold<double>(
      0,
      (sum, row) => sum + (row.executionAmount > 0 ? row.executionAmount : 0),
    );
    final criticalCount = displayItems
        .where(
          (row) =>
              row.bucket == FinanzasPaymentCenterPriorityBucket.obligatorio,
        )
        .length;
    final urgentCount = displayItems
        .where(
          (row) => row.bucket == FinanzasPaymentCenterPriorityBucket.urgente,
        )
        .length;
    final actionableCount = displayItems
        .where(
          (row) =>
              row.executionDecision !=
              FinanzasPaymentCenterExecutionDecision.esperar,
        )
        .length;
    final coverageRatio = totalSuggested <= 0.009
        ? 1.0
        : (protectedAvailable / totalSuggested).clamp(0.0, 1.0);
    final learningPending = _learningLogs
        .where((row) => row.status == 'PENDIENTE')
        .length;
    final learningRegistered = _learningLogs
        .where((row) => row.status == 'REGISTRADO')
        .length;
    final learningMatched = _learningLogs
        .where(
          (row) =>
              row.status == 'REGISTRADO' &&
              row.executedAction != null &&
              row.executedAction == row.suggestedAction,
        )
        .length;
    final learningMatchRatio = learningRegistered == 0
        ? 0.0
        : learningMatched / learningRegistered;
    final reserveActiveCount = _reserveSummary.activeCount;
    final reserveBlockingCount = _reserveSummary.blockingReserveCount;
    final reserveAccountPressureCount = _reserveSummary.accountPressureCount;
    final reserveGlobalCount = _reserveSummary.globalReserveCount;
    final budgetToday = _budgetToday;
    final budgetWeek = _budgetWeek;
    final budgetAccounts =
        budgetToday?.accounts ??
        const <FinanzasPaymentCenterBudgetAccountSummary>[];
    final budgetMovements = budgetAccounts
        .expand((account) => account.providers)
        .toList(growable: false);
    final budgetMinimumToday = budgetToday?.minimumTodayAmount ?? 0;
    final budgetRecommendedToday = budgetToday?.recommendedTodayAmount ?? 0;
    final budgetAvailableAmount = budgetToday?.availableBudgetAmount ?? 0;
    final budgetPlannedToday = budgetToday?.plannedTodayAmount ?? 0;
    final budgetFreeMarginAfterPlanned =
        budgetToday?.freeMarginAfterPlanned ?? 0;
    final budgetUncoveredMinimumToday =
        budgetToday?.uncoveredMinimumTodayAmount ?? 0;
    FinanzasPaymentCenterBudgetWeekDaySummary? budgetTomorrowSummary;
    if (budgetToday != null && budgetWeek != null) {
      final todayDate = DateUtils.dateOnly(budgetToday.today);
      for (final day in budgetWeek.days) {
        final dayDate = DateUtils.dateOnly(day.date);
        if (dayDate.isAfter(todayDate)) {
          budgetTomorrowSummary = day;
          break;
        }
      }
    }
    final budgetTodayDateLabel = _dateLabel(budgetToday?.today);
    final budgetTomorrowDateLabel = _dateLabel(budgetTomorrowSummary?.date);
    final budgetTomorrowCommittedAmount =
        budgetTomorrowSummary?.committedAmount ?? 0;
    final budgetTomorrowPressureAmount =
        budgetTomorrowSummary?.pressureAmount ?? 0;
    final budgetTomorrowRemainingAfterCommitted =
        budgetTomorrowSummary?.remainingAfterCommitted ?? 0;
    final budgetMinimumMovementCount = budgetMovements
        .where((provider) => provider.minimumTodayAmount > 0.009)
        .length;
    final budgetPlannedMovementCount = budgetMovements
        .where((provider) => provider.plannedTodayAmount > 0.009)
        .length;

    List<Widget> buildMetricCards(double cardWidth) {
      switch (_activeMode) {
        case _PaymentCenterMode.presupuesto:
          final mustPayTone = budgetMinimumToday > 0.009
              ? kFinanzasCoral
              : kFinanzasSage;
          final plannedTone = budgetPlannedToday > 0.009
              ? kFinanzasSage
              : kFinanzasAmber;
          final freeMarginTone = budgetFreeMarginAfterPlanned >= 0
              ? kFinanzasSage
              : kFinanzasCoral;
          final tomorrowTone = budgetTomorrowCommittedAmount > 0.009
              ? kFinanzasAmber
              : kFinanzasSage;
          return <Widget>[
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Presion visible hoy',
                value: _money(budgetMinimumToday),
                subtitle: budgetUncoveredMinimumToday > 0.009
                    ? '$budgetMinimumMovementCount movimientos vencidos o del dia para $budgetTodayDateLabel; no todo alcanza a salir hoy y siguen cortos ${_money(budgetUncoveredMinimumToday)}.'
                    : '$budgetMinimumMovementCount movimientos vencidos o del dia para $budgetTodayDateLabel.',
                icon: Icons.assignment_turned_in_rounded,
                tone: mustPayTone,
                progress: budgetRecommendedToday <= 0.009
                    ? 0
                    : (budgetMinimumToday / budgetRecommendedToday).clamp(
                        0.0,
                        1.0,
                      ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Que si pago hoy',
                value: _money(budgetPlannedToday),
                subtitle:
                    '$budgetPlannedMovementCount movimientos ya quedan fondeados con caja protegida al $budgetTodayDateLabel.',
                icon: Icons.priority_high_rounded,
                tone: plannedTone,
                progress: budgetAvailableAmount <= 0.009
                    ? 0
                    : (budgetPlannedToday / budgetAvailableAmount).clamp(
                        0.0,
                        1.0,
                      ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Asi cierro hoy en bancos',
                value: _money(budgetFreeMarginAfterPlanned),
                subtitle:
                    'Despues del plan de hoy y ${_money(budgetToday?.protectedReserveTotal ?? 0)} de reservas protegidas.',
                icon: Icons.account_balance_wallet_rounded,
                tone: freeMarginTone,
                progress: budgetAvailableAmount <= 0.009
                    ? 0
                    : (budgetFreeMarginAfterPlanned / budgetAvailableAmount)
                          .clamp(0.0, 1.0),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Manana ya pide',
                value: _money(budgetTomorrowCommittedAmount),
                subtitle: budgetTomorrowSummary == null
                    ? 'Todavia no hay compromisos visibles para el siguiente dia en la ventana semanal.'
                    : 'Para $budgetTomorrowDateLabel arrancas con ${_money(budgetTomorrowRemainingAfterCommitted)} libres despues de lo comprometido.',
                icon: Icons.today_rounded,
                tone: tomorrowTone,
                progress: budgetTomorrowPressureAmount <= 0.009
                    ? 0
                    : (budgetTomorrowCommittedAmount /
                              budgetTomorrowPressureAmount)
                          .clamp(0.0, 1.0),
              ),
            ),
          ];
        case _PaymentCenterMode.pendientes:
          return <Widget>[
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Saldo real',
                value: _money(realTotalAvailable),
                subtitle: 'Caja viva antes de proteger reservas',
                icon: Icons.account_balance_wallet_rounded,
                tone: finanzasAreaTokens.primaryStrong,
                progress: 0.84,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Reservas protegidas',
                value: _money(_reserveSummary.blockingReserveTotal),
                subtitle:
                    '$reserveBlockingCount bloqueantes · ${_money(_reserveSummary.globalBlockingTotal)} globales',
                icon: Icons.shield_moon_outlined,
                tone: kFinanzasCoral,
                progress: _reserveSummary.blockingReserveTotal <= 0.009
                    ? 0.12
                    : 0.82,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Disponible protegido',
                value: _money(protectedAvailable),
                subtitle:
                    '${_money(_reserveSummary.accountScopedBlockingTotal)} por cuenta · ${_money(_reserveSummary.globalBlockingTotal)} globales',
                icon: Icons.radar_rounded,
                tone: kFinanzasSage,
                progress: realTotalAvailable <= 0.009
                    ? 0
                    : (protectedAvailable / realTotalAvailable).clamp(0.0, 1.0),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Pendientes',
                value: '${displayItems.length}',
                subtitle: '$criticalCount críticos · $urgentCount urgentes',
                icon: Icons.layers_rounded,
                tone: kFinanzasAmber,
                progress: 0.58,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Cobertura inmediata',
                value: '${(coverageRatio * 100).toStringAsFixed(0)}%',
                subtitle:
                    'Pago ejecutable hoy: ${_money(payableNowAmount)} · $actionableCount movimientos',
                icon: Icons.rule_folder_outlined,
                tone: coverageRatio >= 0.85
                    ? kFinanzasSage
                    : coverageRatio >= 0.55
                    ? kFinanzasAmber
                    : kFinanzasCoral,
                progress: coverageRatio >= 0.85
                    ? 1
                    : coverageRatio >= 0.55
                    ? 0.58
                    : 0.32,
              ),
            ),
          ];
        case _PaymentCenterMode.reservas:
          return <Widget>[
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Saldo real',
                value: _money(realTotalAvailable),
                subtitle: 'Caja viva antes de proteger reservas',
                icon: Icons.account_balance_wallet_rounded,
                tone: finanzasAreaTokens.primaryStrong,
                progress: 0.84,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Reservas visibles',
                value: _money(_reserveSummary.visibleReserveTotal),
                subtitle:
                    '$reserveActiveCount activas · ${_money(_reserveSummary.provisionalVisibleTotal)} provisionales',
                icon: Icons.visibility_rounded,
                tone: kFinanzasCopper,
                progress: reserveActiveCount == 0 ? 0.18 : 0.78,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Reservas que bloquean',
                value: _money(_reserveSummary.blockingReserveTotal),
                subtitle:
                    '${_money(_reserveSummary.accountScopedBlockingTotal)} por cuenta · ${_money(_reserveSummary.globalBlockingTotal)} globales',
                icon: Icons.lock_outline_rounded,
                tone: kFinanzasCoral,
                progress: _reserveSummary.blockingReserveTotal <= 0.009
                    ? 0.12
                    : 0.88,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Disponible protegido',
                value: _money(protectedAvailable),
                subtitle: 'Saldo por cuenta: ${_money(protectedAccountTotal)}',
                icon: Icons.shield_outlined,
                tone: kFinanzasSage,
                progress: realTotalAvailable <= 0.009
                    ? 0
                    : (protectedAvailable / realTotalAvailable).clamp(0.0, 1.0),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Cuentas impactadas',
                value: '$reserveAccountPressureCount',
                subtitle:
                    '$reserveGlobalCount globales · $reserveBlockingCount bloqueantes',
                icon: Icons.account_tree_outlined,
                tone: kFinanzasAmber,
                progress: reserveAccountPressureCount == 0 ? 0.18 : 0.68,
              ),
            ),
          ];
        case _PaymentCenterMode.aprendizaje:
          return <Widget>[
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Cortes capturados',
                value: '${_learningLogs.length}',
                subtitle: 'Historial total guardado por Centro de pagos',
                icon: Icons.camera_alt_outlined,
                tone: finanzasAreaTokens.primaryStrong,
                progress: _learningLogs.isEmpty ? 0.12 : 0.86,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Pendientes por registrar',
                value: '$learningPending',
                subtitle: 'Cortes esperando decisión humana',
                icon: Icons.pending_actions_rounded,
                tone: kFinanzasOrangeElectric,
                progress: learningPending == 0 ? 0.18 : 0.58,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Decisiones registradas',
                value: '$learningRegistered',
                subtitle: 'Historial ya validado contra la operación',
                icon: Icons.fact_check_outlined,
                tone: kFinanzasOrange,
                progress: learningRegistered == 0 ? 0.12 : 0.88,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _CenterMetricCard(
                label: 'Coincidencia del motor',
                value: '${(learningMatchRatio * 100).toStringAsFixed(0)}%',
                subtitle: 'Qué tanto coincide el sistema con la decisión real',
                icon: Icons.hub_outlined,
                tone: learningMatchRatio >= 0.7
                    ? kFinanzasSage
                    : learningMatchRatio >= 0.45
                    ? kFinanzasAmber
                    : kFinanzasCoral,
                progress: learningMatchRatio.clamp(0.0, 1.0),
              ),
            ),
          ];
      }
    }

    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Builder(
        builder: (context) => Theme(
          data: _paymentCenterContractTheme(context),
          child: Material(
            color: Colors.transparent,
            child: AppShell(
              background: const _FinPaymentCenterBackground(),
              animateBody: !widget.instantOpen,
              wrapBodyInGlass: false,
              animateHeaderSlots: false,
              headerBodySpacing: 8,
              padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
              leadingBuilder: (_, _) => FinanzasPageHeaderButton(
                label: _menuOpen ? 'Cerrar panel' : 'Navegación',
                icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
                onTapSync: () => setState(() => _menuOpen = !_menuOpen),
              ),
              centerBuilder: (_, _) =>
                  const FinanzasPageHeaderBrand(title: 'Centro de pagos'),
              trailingBuilder: (_, _) => FinanzasPageHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      const spacing = 10.0;
                                      final cardWidth =
                                          ((constraints.maxWidth -
                                                      (spacing * 3)) /
                                                  4)
                                              .clamp(250.0, 380.0);
                                      final metricCards = buildMetricCards(
                                        cardWidth,
                                      );
                                      return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < metricCards.length;
                                              i++
                                            ) ...[
                                              metricCards[i],
                                              if (i != metricCards.length - 1)
                                                const SizedBox(width: spacing),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final mode
                                          in _PaymentCenterMode.values)
                                        ChoiceChip(
                                          label: Text(mode.label),
                                          selected: _activeMode == mode,
                                          onSelected: (_) => setState(
                                            () => _activeMode = mode,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Expanded(
                                    child: switch (_activeMode) {
                                      _PaymentCenterMode.presupuesto =>
                                        budgetToday == null ||
                                                _budgetWeek == null
                                            ? const _CenterEmptyPane(
                                                label:
                                                    'Sin presupuesto disponible',
                                                subtitle:
                                                    'Recarga Centro de pagos para reconstruir el corte presupuestal del día.',
                                              )
                                            : _PaymentCenterBudgetTodayView(
                                                summary: budgetToday,
                                                weekSummary: _budgetWeek!,
                                                reserveSummary: _reserveSummary,
                                                moneyFormatter: _money,
                                                dateFormatter: _dateLabel,
                                                onShowPendingMode: () =>
                                                    setState(
                                                      () => _activeMode =
                                                          _PaymentCenterMode
                                                              .pendientes,
                                                    ),
                                                onOpenProviderAccounts: () =>
                                                    _openProviderAccounts(),
                                              ),
                                      _PaymentCenterMode.pendientes =>
                                        displayItems.isEmpty
                                            ? const _CenterEmptyPane(
                                                label:
                                                    'Sin pendientes por priorizar',
                                                subtitle:
                                                    'Cuando entren compromisos, urgencias o facturas priorizadas, aparecerán aquí.',
                                              )
                                            : LayoutBuilder(
                                                builder: (context, constraints) {
                                                  const spacing = 12.0;
                                                  final columnWidth =
                                                      ((constraints.maxWidth -
                                                                  (spacing *
                                                                      3)) /
                                                              4)
                                                          .clamp(280.0, 380.0);
                                                  final totalWidth =
                                                      (columnWidth * 4) +
                                                      (spacing * 3);
                                                  return SingleChildScrollView(
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: SizedBox(
                                                        width:
                                                            totalWidth <
                                                                constraints
                                                                    .maxWidth
                                                            ? constraints
                                                                  .maxWidth
                                                            : totalWidth,
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            for (
                                                              var i = 0;
                                                              i <
                                                                  FinanzasPaymentCenterPriorityBucket
                                                                      .values
                                                                      .length;
                                                              i++
                                                            ) ...[
                                                              SizedBox(
                                                                width:
                                                                    columnWidth,
                                                                height: constraints
                                                                    .maxHeight,
                                                                child: _PaymentCenterPriorityColumn(
                                                                  bucket: FinanzasPaymentCenterPriorityBucket
                                                                      .values[i],
                                                                  rows:
                                                                      visualItemsByBucket[FinanzasPaymentCenterPriorityBucket
                                                                          .values[i]] ??
                                                                      const <
                                                                        FinanzasPaymentCenterOperationalItem
                                                                      >[],
                                                                  moneyFormatter:
                                                                      _money,
                                                                  dateFormatter:
                                                                      _dateLabel,
                                                                  onOpenProviderAccounts:
                                                                      () =>
                                                                          _openProviderAccounts(),
                                                                  onOpenBankAccounts:
                                                                      (row) =>
                                                                          _openBankExecutionForRow(
                                                                            row,
                                                                          ),
                                                                  onOpenFixedPayments:
                                                                      (row) =>
                                                                          _openFixedPaymentsForRow(
                                                                            row,
                                                                          ),
                                                                ),
                                                              ),
                                                              if (i !=
                                                                  FinanzasPaymentCenterPriorityBucket
                                                                          .values
                                                                          .length -
                                                                      1)
                                                                const SizedBox(
                                                                  width:
                                                                      spacing,
                                                                ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      _PaymentCenterMode.reservas =>
                                        _PaymentCenterReservesView(
                                          reserves: _reserves,
                                          reserveSummary: _reserveSummary,
                                          realAccountBalances:
                                              _realAccountBalances,
                                          protectedAccountBalances:
                                              _accountBalances,
                                          moneyFormatter: _money,
                                          dateFormatter: _dateLabel,
                                          onCreateReserve: () =>
                                              _openReserveDialog(),
                                          onEditReserve: (row) =>
                                              _openReserveDialog(
                                                initialRow: row,
                                              ),
                                          onDeleteReserve:
                                              _confirmDeleteReserve,
                                        ),
                                      _PaymentCenterMode.aprendizaje =>
                                        _PaymentCenterLearningView(
                                          logs: _learningLogs,
                                          pendingCount: learningPending,
                                          registeredCount: learningRegistered,
                                          matchRatio: learningMatchRatio,
                                          moneyFormatter: _money,
                                          dateFormatter: _dateLabel,
                                          onCaptureSnapshot:
                                              _captureLearningSnapshot,
                                          onRegisterDecision:
                                              _registerLearningDecision,
                                        ),
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ),
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
                            color: const Color(
                              0xFF8B4A1A,
                            ).withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 2,
                    bottom: 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      offset: _menuOpen ? Offset.zero : const Offset(-1.08, 0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: _menuOpen ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_menuOpen,
                          child: _FinPaymentCenterSidePanel(
                            canReturnToDirection: _canReturnToDirection,
                            canAccessComprasArea: _canAccessComprasArea,
                            onNavigate: _handleNavigationAction,
                          ),
                        ),
                      ),
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

class _CenterMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final double progress;

  const _CenterMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => FinanzasSummaryMetricCard(
    label: label,
    value: value,
    icon: icon,
    accent: tone,
    valueColor: tone,
    subtitle: subtitle,
    subtitleFontSize: 11.8,
    labelFontSize: 12.5,
    iconBoxSize: 48,
    iconSize: 24,
    centered: true,
    progress: progress,
    height: 170,
  );
}

class _PaymentCenterBudgetTodayView extends StatelessWidget {
  final FinanzasPaymentCenterBudgetTodaySummary summary;
  final FinanzasPaymentCenterBudgetWeekSummary weekSummary;
  final FinanzasPaymentCenterReserveImpactSummary reserveSummary;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final VoidCallback onShowPendingMode;
  final Future<void> Function() onOpenProviderAccounts;

  const _PaymentCenterBudgetTodayView({
    required this.summary,
    required this.weekSummary,
    required this.reserveSummary,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onShowPendingMode,
    required this.onOpenProviderAccounts,
  });

  String _headlineDate() {
    const weekdays = <String>[
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    final weekday = weekdays[summary.today.weekday - 1];
    return '$weekday ${dateFormatter(summary.today)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    FinanzasPaymentCenterBudgetWeekDaySummary? tomorrowSummary;
    final todayDate = DateUtils.dateOnly(summary.today);
    for (final day in weekSummary.days) {
      final dayDate = DateUtils.dateOnly(day.date);
      if (dayDate.isAfter(todayDate)) {
        tomorrowSummary = day;
        break;
      }
    }
    final plannedAccountsWithProviders =
        summary.accounts
            .map(
              (account) => _filterBudgetAccountSummaryForFocus(
                account,
                focus: _PaymentCenterBudgetSectionFocus.plannedToday,
                includeProvider: _hasPlannedMovementProvider,
              ),
            )
            .whereType<FinanzasPaymentCenterBudgetAccountSummary>()
            .toList(growable: false)
          ..sort(_compareBudgetPlannedAccountSummaries);
    final pendingAccountsWithPressure =
        summary.accounts
            .map(
              (account) => _filterBudgetAccountSummaryForFocus(
                account,
                focus: _PaymentCenterBudgetSectionFocus.pendingPressure,
                includeProvider: _hasPendingPressureProvider,
              ),
            )
            .whereType<FinanzasPaymentCenterBudgetAccountSummary>()
            .toList(growable: false)
          ..sort(_compareBudgetPendingAccountSummaries);
    final weekAccountsWithPressure = weekSummary.accounts
        .where(
          (account) =>
              account.weekPressureAmount > 0.009 ||
              account.riskReviewAmount > 0.009 ||
              account.outsideWindowAmount > 0.009,
        )
        .toList(growable: false);
    final movementCount = plannedAccountsWithProviders.fold<int>(
      0,
      (sum, account) => sum + account.providers.length,
    );
    final plannedMovementCount = movementCount;
    final uncoveredMinimumMovementCount = pendingAccountsWithPressure.fold<int>(
      0,
      (sum, account) =>
          sum +
          account.providers
              .where((provider) => provider.pendingVisibleTodayAmount > 0.009)
              .length,
    );
    final riskCount = summary.riskItems.length;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presupuesto de hoy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Corte del ${_headlineDate()}. Primero responde que si se tiene que pagar hoy, que si cabe mover hoy con caja real y con cuanto se cierra para entrar a manana.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onShowPendingMode,
                    style: _paymentCenterOutlinedButtonStyle(context),
                    icon: const Icon(Icons.view_column_rounded, size: 18),
                    label: const Text('Ver pendientes'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(onOpenProviderAccounts()),
                    style: _paymentCenterOutlinedButtonStyle(
                      context,
                      tone: kFinanzasAmber,
                    ),
                    icon: const Icon(Icons.apartment_rounded, size: 18),
                    label: const Text('Abrir CxP'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          FinanzasGlassPanel(
            borderRadius: BorderRadius.circular(26),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            fillColor: kFinanzasPanelSurfaceStrong,
            borderColor: tokens.border.withValues(alpha: 0.34),
            glowColor: kFinanzasCopper.withValues(alpha: 0.12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyChip(
                  label:
                      'Debe hoy ${moneyFormatter(summary.minimumTodayAmount)}',
                  tone: kFinanzasCoral,
                ),
                _TinyChip(
                  label:
                      'Si cabe hoy ${moneyFormatter(summary.plannedTodayAmount)}',
                  tone: kFinanzasSage,
                ),
                _TinyChip(
                  label:
                      'Cierre libre ${moneyFormatter(summary.freeMarginAfterPlanned)}',
                  tone: finanzasAreaTokens.primaryStrong,
                ),
                if (tomorrowSummary != null)
                  _TinyChip(
                    label:
                        'Manana ${dateFormatter(tomorrowSummary.date)} pide ${moneyFormatter(tomorrowSummary.committedAmount)}',
                    tone: kFinanzasAmber,
                  ),
                if (reserveSummary.globalBlockingTotal > 0.009)
                  _TinyChip(
                    label:
                        'Reserva global ${moneyFormatter(reserveSummary.globalBlockingTotal)}',
                    tone: kFinanzasCoral,
                  ),
                if (riskCount > 0)
                  _TinyChip(
                    label: '$riskCount riesgos por revisar',
                    tone: kFinanzasAmber,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _PaymentCenterTodayFocusPanel(
            summary: summary,
            tomorrowSummary: tomorrowSummary,
            plannedMovementCount: plannedMovementCount,
            uncoveredMinimumMovementCount: uncoveredMinimumMovementCount,
            riskCount: riskCount,
            moneyFormatter: moneyFormatter,
            dateFormatter: dateFormatter,
          ),
          const SizedBox(height: 18),
          if (summary.accounts.isEmpty)
            const _CenterEmptyPane(
              label: 'Sin presión presupuestal todavía',
              subtitle:
                  'Cuando entren convenios, facturas, pagos fijos o saldos abiertos, aquí aparecerá la caja disponible del día.',
            )
          else ...[
            Text(
              'Pagos a mover hoy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aqui solo vive la instruccion del dia: facturas y movimientos que si quedaron fondeados con caja real.',
              style: TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            if (plannedAccountsWithProviders.isEmpty)
              FinanzasGlassPanel(
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                fillColor: kFinanzasPanelSurfaceStrong,
                borderColor: tokens.border.withValues(alpha: 0.34),
                child: const Text(
                  'Hoy no hay movimientos fondeados. Lo pendiente queda abajo para revision o para manana, sin mezclarlo con la orden real del dia.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
                    height: 1.35,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (
                    var i = 0;
                    i < plannedAccountsWithProviders.length;
                    i++
                  ) ...[
                    _PaymentCenterBudgetAccountSection(
                      summary: plannedAccountsWithProviders[i],
                      focus: _PaymentCenterBudgetSectionFocus.plannedToday,
                      moneyFormatter: moneyFormatter,
                      dateFormatter: dateFormatter,
                    ),
                    if (i != plannedAccountsWithProviders.length - 1)
                      const SizedBox(height: 16),
                  ],
                ],
              ),
            if (pendingAccountsWithPressure.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Pendiente para manana o revision',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Esta parte no es la orden de pago de hoy. Aqui se queda lo que sigue visible, pero no alcanzo a entrar al plan o necesita revision.',
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  for (
                    var i = 0;
                    i < pendingAccountsWithPressure.length;
                    i++
                  ) ...[
                    _PaymentCenterBudgetAccountSection(
                      summary: pendingAccountsWithPressure[i],
                      focus: _PaymentCenterBudgetSectionFocus.pendingPressure,
                      moneyFormatter: moneyFormatter,
                      dateFormatter: dateFormatter,
                    ),
                    if (i != pendingAccountsWithPressure.length - 1)
                      const SizedBox(height: 16),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Caja por cuenta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Esta capa ya es de soporte: confirma que la decision del dia si cuadra contra cada cuenta.',
              style: TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final account in summary.accounts)
                  _PaymentCenterBudgetAccountCard(
                    summary: account,
                    moneyFormatter: moneyFormatter,
                  ),
              ],
            ),
            if (summary.riskItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PaymentCenterBudgetRiskPanel(
                items: summary.riskItems,
                moneyFormatter: moneyFormatter,
                dateFormatter: dateFormatter,
                onOpenProviderAccounts: onOpenProviderAccounts,
              ),
            ],
          ],
          const SizedBox(height: 18),
          _PaymentCenterBudgetWeekOverview(
            summary: weekSummary,
            accounts: weekAccountsWithPressure,
            moneyFormatter: moneyFormatter,
            dateFormatter: dateFormatter,
          ),
        ],
      ),
    );
  }
}

enum _PaymentCenterBudgetSectionFocus { plannedToday, pendingPressure }

bool _hasPlannedMovementProvider(
  FinanzasPaymentCenterBudgetProviderSummary provider,
) => provider.plannedTodayAmount > 0.009;

bool _hasPendingPressureProvider(
  FinanzasPaymentCenterBudgetProviderSummary provider,
) =>
    provider.pendingVisibleTodayAmount > 0.009 ||
    provider.riskReviewAmount > 0.009;

FinanzasPaymentCenterBudgetAccountSummary? _filterBudgetAccountSummaryForFocus(
  FinanzasPaymentCenterBudgetAccountSummary summary, {
  required _PaymentCenterBudgetSectionFocus focus,
  required bool Function(FinanzasPaymentCenterBudgetProviderSummary provider)
  includeProvider,
}) {
  final providers = summary.providers
      .where(includeProvider)
      .toList(growable: false);
  if (providers.isEmpty) return null;
  final sortedProviders =
      List<FinanzasPaymentCenterBudgetProviderSummary>.from(providers)..sort(
        focus == _PaymentCenterBudgetSectionFocus.plannedToday
            ? _compareBudgetPlannedProviderSummaries
            : _compareBudgetPendingProviderSummaries,
      );
  return FinanzasPaymentCenterBudgetAccountSummary(
    accountKey: summary.accountKey,
    targetCompany: summary.targetCompany,
    targetBranch: summary.targetBranch,
    realBalance: summary.realBalance,
    reserveAmount: summary.reserveAmount,
    availableBalance: summary.availableBalance,
    minimumTodayAmount: sortedProviders.fold<double>(
      0,
      (sum, provider) => sum + provider.minimumTodayAmount,
    ),
    recommendedAdditionalAmount: sortedProviders.fold<double>(
      0,
      (sum, provider) => sum + provider.recommendedAdditionalAmount,
    ),
    postergableAmount: sortedProviders.fold<double>(
      0,
      (sum, provider) => sum + provider.postergableAmount,
    ),
    riskReviewAmount: sortedProviders.fold<double>(
      0,
      (sum, provider) => sum + provider.riskReviewAmount,
    ),
    plannedTodayAmount: sortedProviders.fold<double>(
      0,
      (sum, provider) => sum + provider.plannedTodayAmount,
    ),
    providers: sortedProviders,
  );
}

int _compareBudgetPlannedProviderSummaries(
  FinanzasPaymentCenterBudgetProviderSummary a,
  FinanzasPaymentCenterBudgetProviderSummary b,
) {
  final plannedCompare = b.plannedTodayAmount.compareTo(a.plannedTodayAmount);
  if (plannedCompare != 0) return plannedCompare;
  final pendingCompare = b.pendingVisibleTodayAmount.compareTo(
    a.pendingVisibleTodayAmount,
  );
  if (pendingCompare != 0) return pendingCompare;
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

int _compareBudgetPendingProviderSummaries(
  FinanzasPaymentCenterBudgetProviderSummary a,
  FinanzasPaymentCenterBudgetProviderSummary b,
) {
  final pendingCompare = b.pendingVisibleTodayAmount.compareTo(
    a.pendingVisibleTodayAmount,
  );
  if (pendingCompare != 0) return pendingCompare;
  final riskCompare = b.riskReviewAmount.compareTo(a.riskReviewAmount);
  if (riskCompare != 0) return riskCompare;
  final priorityCompare = b.priorityScore.compareTo(a.priorityScore);
  if (priorityCompare != 0) return priorityCompare;
  return a.providerName.toLowerCase().compareTo(b.providerName.toLowerCase());
}

int _compareBudgetPlannedAccountSummaries(
  FinanzasPaymentCenterBudgetAccountSummary a,
  FinanzasPaymentCenterBudgetAccountSummary b,
) {
  final plannedCompare = b.plannedTodayAmount.compareTo(a.plannedTodayAmount);
  if (plannedCompare != 0) return plannedCompare;
  final pendingCompare = b.pendingVisibleTodayAmount.compareTo(
    a.pendingVisibleTodayAmount,
  );
  if (pendingCompare != 0) return pendingCompare;
  final availableCompare = b.availableBalance.compareTo(a.availableBalance);
  if (availableCompare != 0) return availableCompare;
  return a.accountKey.compareTo(b.accountKey);
}

int _compareBudgetPendingAccountSummaries(
  FinanzasPaymentCenterBudgetAccountSummary a,
  FinanzasPaymentCenterBudgetAccountSummary b,
) {
  final pendingCompare = b.pendingVisibleTodayAmount.compareTo(
    a.pendingVisibleTodayAmount,
  );
  if (pendingCompare != 0) return pendingCompare;
  final riskCompare = b.riskReviewAmount.compareTo(a.riskReviewAmount);
  if (riskCompare != 0) return riskCompare;
  final availableCompare = b.availableBalance.compareTo(a.availableBalance);
  if (availableCompare != 0) return availableCompare;
  return a.accountKey.compareTo(b.accountKey);
}

class _PaymentCenterTodayFocusPanel extends StatelessWidget {
  final FinanzasPaymentCenterBudgetTodaySummary summary;
  final FinanzasPaymentCenterBudgetWeekDaySummary? tomorrowSummary;
  final int plannedMovementCount;
  final int uncoveredMinimumMovementCount;
  final int riskCount;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterTodayFocusPanel({
    required this.summary,
    required this.tomorrowSummary,
    required this.plannedMovementCount,
    required this.uncoveredMinimumMovementCount,
    required this.riskCount,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  String _headline() {
    if (summary.plannedTodayAmount > 0.009 &&
        summary.uncoveredMinimumTodayAmount <= 0.009) {
      return 'Hoy ya queda claro que si se puede mover.';
    }
    if (summary.plannedTodayAmount > 0.009) {
      return 'Hoy ya hay un plan parcial aterrizado.';
    }
    if (summary.minimumTodayAmount > 0.009) {
      return 'Hoy hay presión visible, pero la caja no alcanza para resolverla.';
    }
    return 'Hoy no hay presión inmediata con salida sugerida.';
  }

  String _narrative() {
    final tomorrowLine = tomorrowSummary == null
        ? ''
        : ' Manana ${dateFormatter(tomorrowSummary!.date)} ya aparece comprometido ${moneyFormatter(tomorrowSummary!.committedAmount)}.';
    if (summary.plannedTodayAmount > 0.009 &&
        summary.uncoveredMinimumTodayAmount > 0.009) {
      return 'Hoy se tiene que pagar ${moneyFormatter(summary.minimumTodayAmount)} y si cabe mover ${moneyFormatter(summary.plannedTodayAmount)}. El resto minimo que no alcanzo hoy es ${moneyFormatter(summary.uncoveredMinimumTodayAmount)} y se va a manana o revision.$tomorrowLine';
    }
    if (summary.plannedTodayAmount > 0.009) {
      return 'Hoy se tiene que pagar ${moneyFormatter(summary.minimumTodayAmount)} y si cabe mover ${moneyFormatter(summary.plannedTodayAmount)}. Despues de eso quedan ${moneyFormatter(summary.freeMarginAfterPlanned)} libres.$tomorrowLine';
    }
    if (summary.minimumTodayAmount > 0.009) {
      return 'Hoy se tiene que pagar ${moneyFormatter(summary.minimumTodayAmount)}, pero con la caja protegida no alcanza para aterrizar un plan real.$tomorrowLine';
    }
    return 'Hoy no aparece una salida obligatoria inmediata. La caja queda libre para revisar manana y el resto de la semana sin perder el foco del dia.';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final planTone = summary.plannedTodayAmount > 0.009
        ? kFinanzasSage
        : kFinanzasAmber;
    final shortfallTone = summary.uncoveredMinimumTodayAmount > 0.009
        ? kFinanzasCoral
        : kFinanzasSage;
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      fillColor: kFinanzasPanelSurfaceStrong,
      borderColor: tokens.border.withValues(alpha: 0.34),
      glowColor: planTone.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TinyChip(label: 'Decision del dia', tone: planTone),
          const SizedBox(height: 10),
          Text(
            _headline(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _narrative(),
            style: const TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
              color: kFinanzasMutedInk,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniInfoPill(
                label: 'Presiona hoy',
                value: moneyFormatter(summary.minimumTodayAmount),
              ),
              _MiniInfoPill(
                label: 'Que si pago hoy',
                value: moneyFormatter(summary.plannedTodayAmount),
              ),
              _MiniInfoPill(
                label: 'Me deja libre',
                value: moneyFormatter(summary.freeMarginAfterPlanned),
              ),
              _MiniInfoPill(
                label: tomorrowSummary == null
                    ? 'Sigue pendiente'
                    : 'Manana ya pide',
                value: moneyFormatter(
                  tomorrowSummary?.committedAmount ??
                      summary.uncoveredMinimumTodayAmount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyChip(
                label: '$plannedMovementCount movimientos fondeados hoy',
                tone: planTone,
              ),
              if (uncoveredMinimumMovementCount > 0)
                _TinyChip(
                  label:
                      '$uncoveredMinimumMovementCount movimientos minimos pendientes',
                  tone: shortfallTone,
                ),
              if (riskCount > 0)
                _TinyChip(
                  label: '$riskCount riesgos antes de decidir más',
                  tone: kFinanzasAmber,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterBudgetWeekOverview extends StatelessWidget {
  final FinanzasPaymentCenterBudgetWeekSummary summary;
  final List<FinanzasPaymentCenterBudgetWeekAccountSummary> accounts;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetWeekOverview({
    required this.summary,
    required this.accounts,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  String _rangeLabel() =>
      '${dateFormatter(summary.startDate)} al ${dateFormatter(summary.endDate)}';

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final providers = accounts
        .expand((account) => account.providers)
        .toList(growable: false);
    final topProviders = providers
        .where(
          (provider) =>
              provider.weekPressureAmount > 0.009 ||
              provider.riskReviewAmount > 0.009 ||
              provider.outsideWindowAmount > 0.009,
        )
        .take(8)
        .toList(growable: false);
    final committedProviderCount = providers
        .where((provider) => provider.committedWeekAmount > 0.009)
        .length;
    final extendedProviderCount = providers
        .where((provider) => provider.weekPressureAmount > 0.009)
        .length;
    final conservativeStressCount = accounts
        .where((account) => account.marginAfterCommitted < -0.009)
        .length;
    final extendedStressCount = accounts
        .where((account) => account.marginAfterWeekPressure < -0.009)
        .length;
    final peakCommittedDay = summary.days
        .fold<FinanzasPaymentCenterBudgetWeekDaySummary?>(
          null,
          (selected, day) =>
              selected == null || day.committedAmount > selected.committedAmount
              ? day
              : selected,
        );
    final peakExtendedDay = summary.days
        .fold<FinanzasPaymentCenterBudgetWeekDaySummary?>(
          null,
          (selected, day) =>
              selected == null || day.pressureAmount > selected.pressureAmount
              ? day
              : selected,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que sigue esta semana',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tokens.primaryStrong,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Revisa esto despues de definir hoy. Ventana del ${_rangeLabel()}. Este consolidado compara compromisos contra la caja protegida del miércoles 12/08/2026 y no mete entradas futuras todavía.',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kFinanzasMutedInk,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PaymentCenterBudgetScenarioCard(
              label: 'Escenario conservador',
              title: 'Cubrir solo compromisos fechados',
              amount: summary.committedWeekAmount,
              margin: summary.freeMarginAfterCommitted,
              accountStressCount: conservativeStressCount,
              providerCount: committedProviderCount,
              peakDay: peakCommittedDay,
              note:
                  'Toma como base solo lo que vence del miércoles 12 de agosto de 2026 al martes 18 de agosto de 2026.',
              amountTone: kFinanzasCoral,
              moneyFormatter: moneyFormatter,
              dateFormatter: dateFormatter,
            ),
            _PaymentCenterBudgetScenarioCard(
              label: 'Escenario extendido',
              title: 'Sumar presión sugerida de la semana',
              amount: summary.weekPressureAmount,
              margin: summary.freeMarginAfterWeekPressure,
              accountStressCount: extendedStressCount,
              providerCount: extendedProviderCount,
              peakDay: peakExtendedDay,
              note:
                  'Además incorpora saldos abiertos y presión cercana para no gastar caja que luego hará falta.',
              amountTone: kFinanzasAmber,
              moneyFormatter: moneyFormatter,
              dateFormatter: dateFormatter,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PaymentCenterBudgetWeekStatCard(
              label: 'Caja base protegida',
              value: moneyFormatter(summary.availableBudgetAmount),
              note: 'Saldo libre hoy después de reservas.',
              tone: finanzasAreaTokens.primaryStrong,
            ),
            _PaymentCenterBudgetWeekStatCard(
              label: 'Compromisos 7 días',
              value: moneyFormatter(summary.committedWeekAmount),
              note: 'Pagos con fecha dentro de la ventana.',
              tone: kFinanzasCoral,
            ),
            _PaymentCenterBudgetWeekStatCard(
              label: 'Presión adicional',
              value: moneyFormatter(summary.suggestedAdditionalAmount),
              note: 'Sugerido sin fecha dura o presión abierta.',
              tone: kFinanzasAmber,
            ),
            _PaymentCenterBudgetWeekStatCard(
              label: 'Margen tras compromisos',
              value: moneyFormatter(summary.freeMarginAfterCommitted),
              note: 'Lo que queda si cubrimos la semana base.',
              tone: summary.freeMarginAfterCommitted >= 0
                  ? kFinanzasSage
                  : kFinanzasCoral,
            ),
            _PaymentCenterBudgetWeekStatCard(
              label: 'Margen tras presión',
              value: moneyFormatter(summary.freeMarginAfterWeekPressure),
              note: 'Escenario extendido con sugeridos.',
              tone: summary.freeMarginAfterWeekPressure >= 0
                  ? kFinanzasSage
                  : kFinanzasCoral,
            ),
            _PaymentCenterBudgetWeekStatCard(
              label: 'Riesgo y fuera de ventana',
              value: moneyFormatter(
                summary.riskReviewAmount + summary.outsideWindowAmount,
              ),
              note:
                  'Pendientes sin fecha clara o visibles después del 18/08/2026.',
              tone: kFinanzasCopper,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < summary.days.length; i++) ...[
                _PaymentCenterBudgetWeekDayCard(
                  summary: summary.days[i],
                  moneyFormatter: moneyFormatter,
                  dateFormatter: dateFormatter,
                ),
                if (i != summary.days.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Cuentas con mayor presión semanal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final account in accounts.take(4))
                _PaymentCenterBudgetWeekAccountCard(
                  summary: account,
                  moneyFormatter: moneyFormatter,
                ),
            ],
          ),
        ],
        if (topProviders.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Movimientos que cargan la semana',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 10),
          FinanzasGlassPanel(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            fillColor: kFinanzasPanelSurfaceStrong,
            borderColor: tokens.border.withValues(alpha: 0.32),
            glowColor: kFinanzasCopper.withValues(alpha: 0.10),
            child: Column(
              children: [
                for (var i = 0; i < topProviders.length; i++) ...[
                  _PaymentCenterBudgetWeekProviderRow(
                    summary: topProviders[i],
                    moneyFormatter: moneyFormatter,
                    dateFormatter: dateFormatter,
                  ),
                  if (i != topProviders.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentCenterBudgetScenarioCard extends StatelessWidget {
  final String label;
  final String title;
  final double amount;
  final double margin;
  final int accountStressCount;
  final int providerCount;
  final FinanzasPaymentCenterBudgetWeekDaySummary? peakDay;
  final String note;
  final Color amountTone;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetScenarioCard({
    required this.label,
    required this.title,
    required this.amount,
    required this.margin,
    required this.accountStressCount,
    required this.providerCount,
    required this.peakDay,
    required this.note,
    required this.amountTone,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final marginTone = margin >= 0 ? kFinanzasSage : kFinanzasCoral;
    final dayLabel = peakDay == null
        ? 'Sin pico'
        : '${dateFormatter(peakDay!.date)} · ${moneyFormatter(amountTone == kFinanzasAmber ? peakDay!.pressureAmount : peakDay!.committedAmount)}';
    return SizedBox(
      width: 360,
      child: FinanzasGlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: amountTone.withValues(alpha: 0.30),
        glowColor: amountTone.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TinyChip(label: label, tone: amountTone),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              moneyFormatter(amount),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: amountTone,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniInfoPill(
                  label: 'Margen final',
                  value: moneyFormatter(margin),
                ),
                _MiniInfoPill(
                  label: 'Cuentas tensas',
                  value: '$accountStressCount',
                ),
                _MiniInfoPill(label: 'Movimientos', value: '$providerCount'),
                _MiniInfoPill(label: 'Día pico', value: dayLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: marginTone,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterBudgetWeekStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final Color tone;

  const _PaymentCenterBudgetWeekStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 240,
      child: FinanzasGlassPanel(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: tone.withValues(alpha: 0.28),
        glowColor: tone.withValues(alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterBudgetWeekDayCard extends StatelessWidget {
  final FinanzasPaymentCenterBudgetWeekDaySummary summary;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetWeekDayCard({
    required this.summary,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  String _weekdayLabel() {
    const weekdays = <String>['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
    return weekdays[summary.date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = summary.remainingAfterSuggested >= 0
        ? kFinanzasSage
        : kFinanzasCoral;
    return SizedBox(
      width: 220,
      child: FinanzasGlassPanel(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: tokens.border.withValues(alpha: 0.34),
        glowColor: tone.withValues(alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_weekdayLabel()} ${dateFormatter(summary.date)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
                _TinyChip(
                  label: '${summary.providerCount} prov.',
                  tone: finanzasAreaTokens.primaryStrong,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MiniInfoPill(
              label: 'Compromisos',
              value: moneyFormatter(summary.committedAmount),
            ),
            const SizedBox(height: 8),
            _MiniInfoPill(
              label: 'Adicional',
              value: moneyFormatter(summary.suggestedAdditionalAmount),
            ),
            const SizedBox(height: 8),
            _MiniInfoPill(
              label: 'Margen cierre',
              value: moneyFormatter(summary.remainingAfterSuggested),
            ),
            const SizedBox(height: 10),
            Text(
              '${summary.itemCount} movimientos visibles en el día.',
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterBudgetWeekAccountCard extends StatelessWidget {
  final FinanzasPaymentCenterBudgetWeekAccountSummary summary;
  final String Function(double value) moneyFormatter;

  const _PaymentCenterBudgetWeekAccountCard({
    required this.summary,
    required this.moneyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = summary.marginAfterWeekPressure >= 0
        ? kFinanzasSage
        : kFinanzasCoral;
    return SizedBox(
      width: 280,
      child: FinanzasGlassPanel(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: tone.withValues(alpha: 0.28),
        glowColor: tone.withValues(alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.targetCompany} ${summary.targetBranch}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniInfoPill(
                  label: 'Compromisos',
                  value: moneyFormatter(summary.committedWeekAmount),
                ),
                _MiniInfoPill(
                  label: 'Presión',
                  value: moneyFormatter(summary.weekPressureAmount),
                ),
                _MiniInfoPill(
                  label: 'Margen',
                  value: moneyFormatter(summary.marginAfterWeekPressure),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fuera de ventana ${moneyFormatter(summary.outsideWindowAmount)} · riesgo ${moneyFormatter(summary.riskReviewAmount)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterBudgetWeekProviderRow extends StatelessWidget {
  final FinanzasPaymentCenterBudgetWeekProviderSummary summary;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetWeekProviderRow({
    required this.summary,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = summary.committedWeekAmount > 0.009
        ? kFinanzasCoral
        : summary.suggestedAdditionalAmount > 0.009
        ? kFinanzasAmber
        : kFinanzasCopper;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: kFinanzasPanelSurfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.providerName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.targetCompany} ${summary.targetBranch} · siguiente fecha ${dateFormatter(summary.nextDueDate)}',
                      style: const TextStyle(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                      ),
                    ),
                    if (summary.sourcePreviews.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Detalle: ${summary.sourcePreviews.join(' · ')}',
                        style: const TextStyle(
                          fontSize: 12.1,
                          fontWeight: FontWeight.w700,
                          color: kFinanzasMutedInk,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                moneyFormatter(summary.weekPressureAmount),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(
                label: 'Compromisos',
                value: moneyFormatter(summary.committedWeekAmount),
              ),
              _MiniInfoPill(
                label: 'Adicional',
                value: moneyFormatter(summary.suggestedAdditionalAmount),
              ),
              if (summary.outsideWindowAmount > 0.009)
                _MiniInfoPill(
                  label: 'Post semana',
                  value: moneyFormatter(summary.outsideWindowAmount),
                ),
              if (summary.riskReviewAmount > 0.009)
                _MiniInfoPill(
                  label: 'Riesgo',
                  value: moneyFormatter(summary.riskReviewAmount),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterBudgetAccountCard extends StatelessWidget {
  final FinanzasPaymentCenterBudgetAccountSummary summary;
  final String Function(double value) moneyFormatter;

  const _PaymentCenterBudgetAccountCard({
    required this.summary,
    required this.moneyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final marginTone = summary.marginAfterRecommended >= 0
        ? kFinanzasSage
        : kFinanzasCoral;
    return SizedBox(
      width: 290,
      child: FinanzasGlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        borderRadius: BorderRadius.circular(24),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: tokens.border.withValues(alpha: 0.36),
        glowColor: marginTone.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.targetCompany} ${summary.targetBranch}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyChip(
                  label: '${summary.providers.length} movimientos',
                  tone: finanzasAreaTokens.primaryStrong,
                ),
                if (summary.minimumTodayAmount > 0.009)
                  _TinyChip(label: 'Minimo hoy', tone: kFinanzasCoral),
                if (summary.recommendedAdditionalAmount > 0.009)
                  _TinyChip(label: 'Recomendado', tone: kFinanzasAmber),
                if (summary.riskReviewAmount > 0.009)
                  _TinyChip(label: 'Riesgo', tone: kFinanzasAmber),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniInfoPill(
                  label: 'Saldo real',
                  value: moneyFormatter(summary.realBalance),
                ),
                _MiniInfoPill(
                  label: 'Reserva',
                  value: moneyFormatter(summary.reserveAmount),
                ),
                _MiniInfoPill(
                  label: 'Libre',
                  value: moneyFormatter(summary.availableBalance),
                ),
                _MiniInfoPill(
                  label: 'Mínimo hoy',
                  value: moneyFormatter(summary.minimumTodayAmount),
                ),
                _MiniInfoPill(
                  label: 'Recomendado',
                  value: moneyFormatter(summary.recommendedTodayAmount),
                ),
                _MiniInfoPill(
                  label: 'Margen final',
                  value: moneyFormatter(summary.marginAfterRecommended),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary.providers.isEmpty
                  ? 'Sin presión registrada hoy para esta cuenta.'
                  : 'Presión planeada hoy: ${moneyFormatter(summary.plannedTodayAmount)}.',
              style: TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
                color: marginTone,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterBudgetAccountSection extends StatelessWidget {
  final FinanzasPaymentCenterBudgetAccountSummary summary;
  final _PaymentCenterBudgetSectionFocus focus;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetAccountSection({
    required this.summary,
    required this.focus,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isPlannedFocus =
        focus == _PaymentCenterBudgetSectionFocus.plannedToday;
    final headlineTone = isPlannedFocus ? kFinanzasSage : kFinanzasCopper;
    final supportLine = isPlannedFocus
        ? 'Se mueve hoy ${moneyFormatter(summary.plannedTodayAmount)} · sigue visible ${moneyFormatter(summary.pendingVisibleTodayAmount)}'
        : 'Sigue visible ${moneyFormatter(summary.pendingVisibleTodayAmount)} · libre ${moneyFormatter(summary.availableBalance)}';
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      fillColor: kFinanzasPanelSurfaceStrong,
      borderColor: tokens.border.withValues(alpha: 0.34),
      glowColor: headlineTone.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.targetCompany} ${summary.targetBranch}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      supportLine,
                      style: const TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isPlannedFocus)
                    _TinyChip(
                      label:
                          'Mover hoy ${moneyFormatter(summary.plannedTodayAmount)}',
                      tone: kFinanzasSage,
                    )
                  else ...[
                    _TinyChip(
                      label:
                          'Mínimo ${moneyFormatter(summary.minimumTodayAmount)}',
                      tone: kFinanzasCoral,
                    ),
                    _TinyChip(
                      label:
                          'Recomendado ${moneyFormatter(summary.recommendedTodayAmount)}',
                      tone: kFinanzasAmber,
                    ),
                    if (summary.postergableAmount > 0.009)
                      _TinyChip(
                        label:
                            'Postergable ${moneyFormatter(summary.postergableAmount)}',
                        tone: kFinanzasSage,
                      ),
                  ],
                  if (summary.pendingVisibleTodayAmount > 0.009)
                    _TinyChip(
                      label:
                          'Sigue pendiente ${moneyFormatter(summary.pendingVisibleTodayAmount)}',
                      tone: kFinanzasCoral,
                    ),
                  if (summary.riskReviewAmount > 0.009)
                    _TinyChip(label: 'Riesgo', tone: kFinanzasAmber),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < summary.providers.length; i++) ...[
                _PaymentCenterBudgetProviderCard(
                  summary: summary.providers[i],
                  focus: focus,
                  moneyFormatter: moneyFormatter,
                  dateFormatter: dateFormatter,
                ),
                if (i != summary.providers.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterBudgetProviderCard extends StatelessWidget {
  final FinanzasPaymentCenterBudgetProviderSummary summary;
  final _PaymentCenterBudgetSectionFocus focus;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetProviderCard({
    required this.summary,
    required this.focus,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  Color _headlineTone() {
    if (summary.minimumTodayAmount > 0.009) return kFinanzasCoral;
    if (summary.recommendedAdditionalAmount > 0.009) return kFinanzasAmber;
    if (summary.riskReviewAmount > 0.009) return kFinanzasAmber;
    return kFinanzasSage;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isPlannedFocus =
        focus == _PaymentCenterBudgetSectionFocus.plannedToday;
    final tone = isPlannedFocus ? kFinanzasSage : _headlineTone();
    final primaryItem = summary.primaryActionItem;
    final headlineAmount = isPlannedFocus
        ? summary.plannedTodayAmount
        : summary.plannedTodayAmount > 0.009
        ? summary.plannedTodayAmount
        : summary.minimumTodayAmount > 0.009
        ? summary.minimumTodayAmount
        : summary.recommendedTodayAmount;
    final headlineLabel = isPlannedFocus
        ? 'Mover hoy'
        : summary.plannedTodayAmount > 0.009
        ? 'Plan de hoy'
        : summary.minimumTodayAmount > 0.009
        ? 'Presión mínima'
        : summary.recommendedAdditionalAmount > 0.009
        ? 'Adicional sugerido'
        : 'Visible';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kFinanzasPanelSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.providerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      primaryItem != null && summary.itemCount == 1
                          ? '${primaryItem.itemType} · ${primaryItem.sourceLabel} · abierto ${moneyFormatter(summary.totalOpenAmount)}'
                          : isPlannedFocus
                          ? '${summary.itemCount} movimientos fondeados · abierto ${moneyFormatter(summary.totalOpenAmount)}'
                          : '${summary.itemCount} movimientos visibles · abierto ${moneyFormatter(summary.totalOpenAmount)}',
                      style: const TextStyle(
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    headlineLabel,
                    style: const TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w800,
                      color: kFinanzasMutedInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moneyFormatter(headlineAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: tone,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isPlannedFocus)
                _TinyChip(
                  label:
                      'Planeado ${moneyFormatter(summary.plannedTodayAmount)}',
                  tone: kFinanzasSage,
                ),
              if (!isPlannedFocus && summary.minimumTodayAmount > 0.009)
                _TinyChip(label: 'Minimo hoy', tone: kFinanzasCoral),
              if (!isPlannedFocus &&
                  summary.recommendedAdditionalAmount > 0.009)
                _TinyChip(
                  label:
                      'Extra sugerido ${moneyFormatter(summary.recommendedAdditionalAmount)}',
                  tone: kFinanzasAmber,
                ),
              if (!isPlannedFocus && summary.postergableAmount > 0.009)
                _TinyChip(label: 'Postergable', tone: kFinanzasSage),
              if (summary.pendingVisibleTodayAmount > 0.009)
                _TinyChip(
                  label:
                      'Sigue pendiente ${moneyFormatter(summary.pendingVisibleTodayAmount)}',
                  tone: kFinanzasCoral,
                ),
              if (summary.riskReviewAmount > 0.009)
                _TinyChip(label: 'Riesgo a revisar', tone: kFinanzasAmber),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(
                label: isPlannedFocus ? 'Mover hoy' : 'Mínimo hoy',
                value: moneyFormatter(
                  isPlannedFocus
                      ? summary.plannedTodayAmount
                      : summary.minimumTodayAmount,
                ),
              ),
              _MiniInfoPill(
                label: isPlannedFocus ? 'Abierto' : 'Recomendado hoy',
                value: moneyFormatter(
                  isPlannedFocus
                      ? summary.totalOpenAmount
                      : summary.recommendedTodayAmount,
                ),
              ),
              if (isPlannedFocus || summary.postergableAmount > 0.009)
                _MiniInfoPill(
                  label: isPlannedFocus ? 'Sigue pendiente' : 'Postergable',
                  value: moneyFormatter(
                    isPlannedFocus
                        ? summary.pendingVisibleTodayAmount
                        : summary.postergableAmount,
                  ),
                ),
              if (summary.riskReviewAmount > 0.009)
                _MiniInfoPill(
                  label: 'Riesgo',
                  value: moneyFormatter(summary.riskReviewAmount),
                ),
            ],
          ),
          if (summary.sourcePreviews.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Fuentes: ${summary.sourcePreviews.join(' · ')}',
              style: const TextStyle(
                fontSize: 12.3,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
          if (primaryItem != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ancla del día',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${primaryItem.itemType} · ${primaryItem.sourceLabel} · ${dateFormatter(primaryItem.dueDate)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.primaryStrong,
              ),
            ),
            if (primaryItem.recommendation.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                primaryItem.recommendation,
                style: const TextStyle(
                  fontSize: 12.3,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PaymentCenterBudgetRiskPanel extends StatelessWidget {
  final List<FinanzasPaymentCenterOperationalItem> items;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenProviderAccounts;

  const _PaymentCenterBudgetRiskPanel({
    required this.items,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenProviderAccounts,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      fillColor: kFinanzasPanelSurfaceStrong,
      borderColor: kFinanzasAmber.withValues(alpha: 0.34),
      glowColor: kFinanzasAmber.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riesgo a revisar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aquí caen los movimientos que todavía no tienen suficiente contexto para presupuestar bien, por ejemplo facturas sin fecha de vencimiento.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => unawaited(onOpenProviderAccounts()),
                style: _paymentCenterOutlinedButtonStyle(
                  context,
                  tone: kFinanzasAmber,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Revisar en CxP'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _PaymentCenterBudgetRiskRow(
                  row: items[i],
                  moneyFormatter: moneyFormatter,
                  dateFormatter: dateFormatter,
                ),
                if (i != items.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterBudgetRiskRow extends StatelessWidget {
  final FinanzasPaymentCenterOperationalItem row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;

  const _PaymentCenterBudgetRiskRow({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kFinanzasPanelSurfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kFinanzasAmber.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.providerName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.itemType} · ${row.sourceLabel}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kFinanzasMutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                moneyFormatter(row.amountSuggested),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: kFinanzasAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(
                label: 'Cuenta',
                value: '${row.targetCompany} ${row.targetBranch}',
              ),
              _MiniInfoPill(label: 'Vence', value: dateFormatter(row.dueDate)),
              _MiniInfoPill(label: 'Acuerdo', value: row.agreementLabel),
            ],
          ),
          if (row.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.recommendation,
              style: const TextStyle(
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCenterLearningView extends StatelessWidget {
  final List<FinanzasPaymentLearningRecord> logs;
  final int pendingCount;
  final int registeredCount;
  final double matchRatio;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onCaptureSnapshot;
  final Future<void> Function(FinanzasPaymentLearningRecord row)
  onRegisterDecision;

  const _PaymentCenterLearningView({
    required this.logs,
    required this.pendingCount,
    required this.registeredCount,
    required this.matchRatio,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onCaptureSnapshot,
    required this.onRegisterDecision,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Capa de aprendizaje',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onCaptureSnapshot,
              style: _paymentCenterOutlinedButtonStyle(context),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Capturar corte actual'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Aquí se registran las sugerencias del motor y la decisión humana real para entrenar mejor la lógica sin tocar el flujo operativo.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: kFinanzasMutedInk,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CenterMetricCard(
              label: 'Pendientes por registrar',
              value: '$pendingCount',
              subtitle: 'Cortes capturados pendientes de decisión humana',
              icon: Icons.pending_actions_rounded,
              tone: kFinanzasOrangeElectric,
              progress: 0.58,
            ),
            _CenterMetricCard(
              label: 'Decisiones registradas',
              value: '$registeredCount',
              subtitle: 'Historial ya validado contra la operación',
              icon: Icons.fact_check_outlined,
              tone: kFinanzasOrange,
              progress: 0.88,
            ),
            _CenterMetricCard(
              label: 'Coincidencia con sistema',
              value: '${(matchRatio * 100).toStringAsFixed(0)}%',
              subtitle: 'Qué tanto coincide el motor con la decisión real',
              icon: Icons.hub_outlined,
              tone: finanzasAreaTokens.primaryStrong,
              progress: matchRatio.clamp(0.0, 1.0),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: logs.isEmpty
              ? const _CenterEmptyPane(
                  label: 'Aún no hay cortes de aprendizaje',
                  subtitle:
                      'Captura un corte actual para empezar a guardar recomendaciones y decisiones humanas.',
                )
              : Container(
                  decoration: BoxDecoration(
                    color: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.48),
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemBuilder: (context, index) {
                      final row = logs[index];
                      return _PaymentLearningRow(
                        row: row,
                        moneyFormatter: moneyFormatter,
                        dateFormatter: dateFormatter,
                        onRegisterDecision: () => onRegisterDecision(row),
                      );
                    },
                    separatorBuilder: (_, separatorIndex) => Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.border.withValues(alpha: 0.8),
                    ),
                    itemCount: logs.length,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PaymentLearningRow extends StatelessWidget {
  final FinanzasPaymentLearningRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onRegisterDecision;

  const _PaymentLearningRow({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onRegisterDecision,
  });

  String _displayAction(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PAGAR_COMPLETO':
        return 'Pagar completo';
      case 'ABONAR':
        return 'Abonar';
      case 'ESPERAR':
        return 'Esperar';
      default:
        return raw.trim().isEmpty ? '—' : raw.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final statusTone = row.status == 'REGISTRADO'
        ? kFinanzasSage
        : kFinanzasAmber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              _TinyChip(label: row.bucket, tone: statusTone),
              const SizedBox(width: 8),
              _TinyChip(label: row.status, tone: statusTone),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: 'Tipo', value: row.itemType),
              _MiniInfoPill(label: 'Vence', value: dateFormatter(row.dueDate)),
              _MiniInfoPill(
                label: 'Sugerido',
                value:
                    '${_displayAction(row.suggestedAction)} · ${moneyFormatter(row.suggestedAmount)}',
              ),
              _MiniInfoPill(
                label: 'Objetivo',
                value: '${row.targetCompany} ${row.targetBranch}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.sourceLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
            ),
          ),
          if (row.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              row.recommendation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.executedAction == null
                      ? 'Sin decisión registrada todavía.'
                      : 'Ejecutado: ${_displayAction(row.executedAction!)}${row.executedAmount == null ? '' : ' · ${moneyFormatter(row.executedAmount!)}'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onRegisterDecision,
                style: _paymentCenterOutlinedButtonStyle(
                  context,
                  tone: kFinanzasAmber,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  row.status == 'REGISTRADO'
                      ? 'Editar decisión'
                      : 'Registrar decisión',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterReservesView extends StatelessWidget {
  final List<FinanzasPaymentCenterReserveRecord> reserves;
  final FinanzasPaymentCenterReserveImpactSummary reserveSummary;
  final Map<String, double> realAccountBalances;
  final Map<String, double> protectedAccountBalances;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onCreateReserve;
  final Future<void> Function(FinanzasPaymentCenterReserveRecord row)
  onEditReserve;
  final Future<void> Function(FinanzasPaymentCenterReserveRecord row)
  onDeleteReserve;

  const _PaymentCenterReservesView({
    required this.reserves,
    required this.reserveSummary,
    required this.realAccountBalances,
    required this.protectedAccountBalances,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onCreateReserve,
    required this.onEditReserve,
    required this.onDeleteReserve,
  });

  String _accountLabel(String accountKey) {
    final parts = accountKey.split('_');
    if (parts.length < 2) return accountKey;
    return '${parts.first} ${parts.sublist(1).join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final accountKeys = <String>{
      ...realAccountBalances.keys,
      ...protectedAccountBalances.keys,
      ...reserveSummary.accountReserveAmounts.keys,
    }.toList(growable: false)..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservas protegidas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Protege nómina, impuestos, colchones y extraordinarios sin salir de Centro de pagos.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kFinanzasMutedInk,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCreateReserve,
              style: _paymentCenterFilledButtonStyle(
                context,
                tone: kFinanzasCoral,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva reserva'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (reserves.isEmpty)
          Expanded(
            child: const _CenterEmptyPane(
              label: 'Aún no hay reservas protegidas',
              subtitle:
                  'Captura nómina, impuestos o colchones para que Centro de pagos deje de sobreestimar la caja disponible.',
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (reserveSummary.activeReserves.isEmpty)
                  FinanzasGlassPanel(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    borderRadius: BorderRadius.circular(24),
                    fillColor: kFinanzasPanelSurfaceStrong,
                    borderColor: kFinanzasAmber.withValues(alpha: 0.32),
                    glowColor: kFinanzasAmber.withValues(alpha: 0.14),
                    child: const Text(
                      'Hay reservas registradas, pero ninguna está activa hoy. El presupuesto sigue corriendo sin caja protegida efectiva para el miércoles 12 de agosto de 2026.',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (reserveSummary.activeReserves.isEmpty)
                  const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (reserveSummary.globalBlockingTotal > 0.009)
                      _PaymentCenterReserveAccountCard(
                        title: 'Reserva global',
                        realBalance: reserveSummary.realTotalBalance,
                        reserveAmount: reserveSummary.globalBlockingTotal,
                        availableBalance: reserveSummary.availableAfterBlocking,
                        moneyFormatter: moneyFormatter,
                        note:
                            'No se reparte por cuenta; se protege a nivel total.',
                      ),
                    for (final accountKey in accountKeys)
                      _PaymentCenterReserveAccountCard(
                        title: _accountLabel(accountKey),
                        realBalance: realAccountBalances[accountKey] ?? 0,
                        reserveAmount:
                            reserveSummary.accountReserveAmounts[accountKey] ??
                            0,
                        availableBalance:
                            protectedAccountBalances[accountKey] ?? 0,
                        moneyFormatter: moneyFormatter,
                        note: 'Saldo real vs saldo protegido de la cuenta.',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Reservas registradas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < reserves.length; i++) ...[
                  _PaymentCenterReserveRowCard(
                    row: reserves[i],
                    moneyFormatter: moneyFormatter,
                    dateFormatter: dateFormatter,
                    onEdit: () => onEditReserve(reserves[i]),
                    onDelete: () => onDeleteReserve(reserves[i]),
                  ),
                  if (i != reserves.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PaymentCenterReserveAccountCard extends StatelessWidget {
  final String title;
  final double realBalance;
  final double reserveAmount;
  final double availableBalance;
  final String Function(double value) moneyFormatter;
  final String note;

  const _PaymentCenterReserveAccountCard({
    required this.title,
    required this.realBalance,
    required this.reserveAmount,
    required this.availableBalance,
    required this.moneyFormatter,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 268,
      child: FinanzasGlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        borderRadius: BorderRadius.circular(24),
        fillColor: kFinanzasPanelSurfaceStrong,
        borderColor: tokens.border.withValues(alpha: 0.36),
        glowColor: kFinanzasCopper.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 10),
            _MiniInfoPill(
              label: 'Saldo real',
              value: moneyFormatter(realBalance),
            ),
            const SizedBox(height: 8),
            _MiniInfoPill(
              label: 'Reserva',
              value: moneyFormatter(reserveAmount),
            ),
            const SizedBox(height: 8),
            _MiniInfoPill(
              label: 'Disponible',
              value: moneyFormatter(availableBalance),
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCenterReserveRowCard extends StatelessWidget {
  final FinanzasPaymentCenterReserveRecord row;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _PaymentCenterReserveRowCard({
    required this.row,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onEdit,
    required this.onDelete,
  });

  Color _typeTone() {
    switch (row.reserveType) {
      case 'NOMINA':
        return kFinanzasCoral;
      case 'IMPUESTOS':
        return kFinanzasAmber;
      case 'COLCHON_CUENTA':
        return kFinanzasSage;
      default:
        return kFinanzasCopper;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final typeTone = _typeTone();
    final statusTone = row.isActive ? typeTone : kFinanzasMutedInk;
    final scopeLabel = row.isGlobal
        ? 'Global'
        : '${row.targetCompany ?? ''} ${row.targetBranch ?? ''}'.trim();
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(24),
      fillColor: kFinanzasPanelSurfaceStrong,
      borderColor: tokens.border.withValues(alpha: 0.32),
      glowColor: typeTone.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TinyChip(
                          label: finPaymentCenterReserveTypeLabel(
                            row.reserveType,
                          ),
                          tone: typeTone,
                        ),
                        _TinyChip(
                          label: finPaymentCenterReserveClassificationLabel(
                            row.classification,
                          ),
                          tone: row.classification == 'DURA'
                              ? kFinanzasCoral
                              : kFinanzasAmber,
                        ),
                        _TinyChip(
                          label: finPaymentCenterReserveScopeLabel(
                            row.scopeType,
                          ),
                          tone: kFinanzasCopper,
                        ),
                        _TinyChip(
                          label: row.blocksCash
                              ? 'Bloquea caja'
                              : 'Solo visible',
                          tone: row.blocksCash
                              ? kFinanzasCoral
                              : kFinanzasMutedInk,
                        ),
                        _TinyChip(
                          label: row.isActive ? 'Activa' : 'Inactiva',
                          tone: statusTone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                moneyFormatter(row.amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: typeTone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: 'Cuenta', value: scopeLabel),
              _MiniInfoPill(
                label: 'Efectiva',
                value: dateFormatter(row.effectiveDate),
              ),
              _MiniInfoPill(label: 'Límite', value: dateFormatter(row.endDate)),
            ],
          ),
          if (row.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              row.note,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                style: _paymentCenterOutlinedButtonStyle(
                  context,
                  tone: kFinanzasAmber,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                style: _paymentCenterOutlinedButtonStyle(
                  context,
                  tone: kFinanzasCoral,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterOverlaySection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _PaymentCenterOverlaySection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PaymentCenterReserveDialog extends StatefulWidget {
  final FinanzasPaymentCenterReserveRecord? initialRow;

  const _PaymentCenterReserveDialog({this.initialRow});

  @override
  State<_PaymentCenterReserveDialog> createState() =>
      _PaymentCenterReserveDialogState();
}

class _PaymentCenterReserveDialogState
    extends State<_PaymentCenterReserveDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _amountC;
  late final TextEditingController _noteC;
  late String _reserveType;
  late String _classification;
  late String _scopeType;
  late String _targetCompany;
  late String _targetBranch;
  late DateTime _effectiveDate;
  DateTime? _endDate;
  late bool _blocksCash;
  late bool _isActive;
  bool _saving = false;

  static const _companies = <String>['DICSA', 'VH'];
  static const _branches = <String>['CELAYA', 'MAZATLAN'];

  @override
  void initState() {
    super.initState();
    final row = widget.initialRow;
    _nameC = TextEditingController(text: row?.name ?? '');
    _amountC = TextEditingController(
      text: row == null ? '' : row.amount.toStringAsFixed(2),
    );
    _noteC = TextEditingController(text: row?.note ?? '');
    _reserveType = row?.reserveType ?? 'NOMINA';
    _classification = row?.classification ?? 'DURA';
    _scopeType = row?.scopeType ?? 'GLOBAL';
    _targetCompany = row?.targetCompany ?? 'DICSA';
    _targetBranch = row?.targetBranch ?? 'CELAYA';
    _effectiveDate = DateUtils.dateOnly(row?.effectiveDate ?? DateTime.now());
    _endDate = row?.endDate == null ? null : DateUtils.dateOnly(row!.endDate!);
    _blocksCash = row?.blocksCash ?? true;
    _isActive = row?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _amountC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  double _parseAmount() {
    final cleaned = _amountC.text
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String? get _validationMessage {
    if (_nameC.text.trim().isEmpty) return 'Captura el nombre de la reserva.';
    if (_parseAmount() <= 0) return 'Captura un monto mayor a cero.';
    if (_reserveType == 'COLCHON_CUENTA' && _scopeType != 'CUENTA') {
      return 'Colchon de cuenta debe ir ligado a una cuenta.';
    }
    if (_scopeType == 'CUENTA' &&
        (_targetCompany.trim().isEmpty || _targetBranch.trim().isEmpty)) {
      return 'Selecciona la cuenta objetivo de la reserva.';
    }
    if (_endDate != null && _endDate!.isBefore(_effectiveDate)) {
      return 'La fecha límite no puede ser anterior a la fecha efectiva.';
    }
    return null;
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      builder: _buildThemedDatePicker,
    );
    if (picked == null || !mounted) return;
    setState(() => _effectiveDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      currentDate: defaultDatePickerOpenDate(
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ),
      builder: _buildThemedDatePicker,
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = DateUtils.dateOnly(picked));
  }

  Widget _buildThemedDatePicker(BuildContext context, Widget? child) {
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Builder(
        builder: (context) => Theme(
          data: _paymentCenterOverlayTheme(context),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final validationMessage = _validationMessage;
    if (validationMessage != null) return;
    setState(() => _saving = true);
    try {
      final initial = widget.initialRow;
      final reserve =
          (initial ??
                  FinanzasPaymentCenterReserveRecord(
                    id: 'fin_reserve_${DateTime.now().microsecondsSinceEpoch}',
                    name: '',
                    reserveType: 'NOMINA',
                    classification: 'DURA',
                    scopeType: 'GLOBAL',
                    targetCompany: null,
                    targetBranch: null,
                    amount: 0,
                    effectiveDate: _effectiveDate,
                    endDate: null,
                    note: '',
                    blocksCash: true,
                    isActive: true,
                    createdAt: null,
                    updatedAt: null,
                  ))
              .copyWith(
                name: _nameC.text.trim(),
                reserveType: _reserveType,
                classification: _classification,
                scopeType: _scopeType,
                targetCompany: _scopeType == 'GLOBAL' ? null : _targetCompany,
                clearTargetCompany: _scopeType == 'GLOBAL',
                targetBranch: _scopeType == 'GLOBAL' ? null : _targetBranch,
                clearTargetBranch: _scopeType == 'GLOBAL',
                amount: _parseAmount(),
                effectiveDate: _effectiveDate,
                endDate: _endDate,
                clearEndDate: _endDate == null,
                note: _noteC.text.trim(),
                blocksCash: _blocksCash,
                isActive: _isActive,
              );
      await FinanzasPaymentCenterReservesStore.saveReserve(reserve);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMissingPaymentCenterReservesFeatureError(error)
                ? kFinPaymentCenterReservesUnavailableMessage
                : 'No se pudo guardar la reserva protegida.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isEditing = widget.initialRow != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: AreaThemeScope(
        tokens: finanzasAreaTokens,
        child: Builder(
          builder: (context) {
            return Theme(
              data: _paymentCenterOverlayTheme(context),
              child: FinanzasGlassPanel(
                borderRadius: BorderRadius.circular(34),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                fillColor: kFinanzasPanelSurface,
                borderColor: tokens.border.withValues(alpha: 0.38),
                edgeHighlightColor: kFinanzasLightGlow.withValues(alpha: 0.12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 980,
                    maxHeight: 820,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing
                                      ? 'Editar reserva protegida'
                                      : 'Nueva reserva protegida',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: kFinanzasInk,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Esta captura vive solo dentro de Centro de pagos y define dinero que no se debe comprometer sin control.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: kFinanzasMutedInk.withValues(
                                      alpha: 0.92,
                                    ),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PaymentCenterOverlaySection(
                                title: 'Datos base',
                                subtitle:
                                    'Ponle nombre, monto y contexto para que esta reserva sea entendible en el tablero.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _nameC,
                                      cursorColor: tokens.primaryStrong,
                                      style:
                                          _paymentCenterOverlayFieldTextStyle(
                                            context,
                                          ),
                                      decoration:
                                          _paymentCenterOverlayFieldDecoration(
                                            context,
                                            labelText: 'Nombre',
                                            hintText: 'Nomina jueves Celaya',
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _amountC,
                                      cursorColor: tokens.primaryStrong,
                                      style:
                                          _paymentCenterOverlayFieldTextStyle(
                                            context,
                                          ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration:
                                          _paymentCenterOverlayFieldDecoration(
                                            context,
                                            labelText: 'Monto',
                                            hintText: '121000.00',
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _noteC,
                                      cursorColor: tokens.primaryStrong,
                                      style:
                                          _paymentCenterOverlayFieldTextStyle(
                                            context,
                                          ),
                                      minLines: 2,
                                      maxLines: 4,
                                      decoration:
                                          _paymentCenterOverlayFieldDecoration(
                                            context,
                                            labelText: 'Nota',
                                            hintText:
                                                'Ejemplo: reservar base de nomina del jueves.',
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _PaymentCenterOverlaySection(
                                title: 'Tipo y alcance',
                                subtitle:
                                    'Define que clase de reserva es y si protege toda la caja o una cuenta específica.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tipo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final value
                                            in kFinPaymentCenterReserveTypes)
                                          ChoiceChip(
                                            label: Text(
                                              finPaymentCenterReserveTypeLabel(
                                                value,
                                              ),
                                            ),
                                            selected: _reserveType == value,
                                            onSelected: (_) => setState(() {
                                              _reserveType = value;
                                              if (value == 'COLCHON_CUENTA') {
                                                _scopeType = 'CUENTA';
                                              }
                                            }),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Clasificación',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final value
                                            in kFinPaymentCenterReserveClassifications)
                                          ChoiceChip(
                                            label: Text(
                                              finPaymentCenterReserveClassificationLabel(
                                                value,
                                              ),
                                            ),
                                            selected: _classification == value,
                                            onSelected: (_) => setState(
                                              () => _classification = value,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Alcance',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final value
                                            in kFinPaymentCenterReserveScopeTypes)
                                          ChoiceChip(
                                            label: Text(
                                              finPaymentCenterReserveScopeLabel(
                                                value,
                                              ),
                                            ),
                                            selected: _scopeType == value,
                                            onSelected: (_) => setState(
                                              () => _scopeType = value,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_scopeType == 'CUENTA') ...[
                                      const SizedBox(height: 18),
                                      Text(
                                        'Cuenta objetivo',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: tokens.primaryStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (final company in _companies)
                                            ChoiceChip(
                                              label: Text(company),
                                              selected:
                                                  _targetCompany == company,
                                              onSelected: (_) => setState(
                                                () => _targetCompany = company,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (final branch in _branches)
                                            ChoiceChip(
                                              label: Text(branch),
                                              selected: _targetBranch == branch,
                                              onSelected: (_) => setState(
                                                () => _targetBranch = branch,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _PaymentCenterOverlaySection(
                                title: 'Vigencia y efecto en caja',
                                subtitle:
                                    'Controla desde cuando aplica y si realmente debe apartar disponibilidad hoy.',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _pickEffectiveDate,
                                          icon: const Icon(
                                            Icons.event_available_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            'Efectiva: ${_dateLabel(_effectiveDate)}',
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _pickEndDate,
                                          icon: const Icon(
                                            Icons.event_busy_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _endDate == null
                                                ? 'Sin fecha límite'
                                                : 'Límite: ${_dateLabel(_endDate!)}',
                                          ),
                                        ),
                                        if (_endDate != null)
                                          TextButton(
                                            onPressed: () =>
                                                setState(() => _endDate = null),
                                            child: const Text('Quitar límite'),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: tokens.fieldSurface.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: tokens.border.withValues(
                                            alpha: 0.34,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          SwitchListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 2,
                                                ),
                                            title: Text(
                                              'Bloquea caja',
                                              style: TextStyle(
                                                color: tokens.onGlass,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: const Text(
                                              'Si está activa, descuenta disponibilidad real.',
                                              style: TextStyle(
                                                color: kFinanzasMutedInk,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            value: _blocksCash,
                                            onChanged: (value) => setState(
                                              () => _blocksCash = value,
                                            ),
                                          ),
                                          Divider(
                                            height: 1,
                                            color: tokens.border.withValues(
                                              alpha: 0.24,
                                            ),
                                          ),
                                          SwitchListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 2,
                                                ),
                                            title: Text(
                                              'Activa',
                                              style: TextStyle(
                                                color: tokens.onGlass,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: const Text(
                                              'Permite dejarla registrada sin afectar hoy.',
                                              style: TextStyle(
                                                color: kFinanzasMutedInk,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            value: _isActive,
                                            onChanged: (value) => setState(
                                              () => _isActive = value,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_validationMessage != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _validationMessage!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: kFinanzasCoral,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _saving || _validationMessage != null
                                ? null
                                : _save,
                            style: _paymentCenterFilledButtonStyle(
                              context,
                              tone: kFinanzasCoral,
                            ),
                            child: Text(
                              _saving
                                  ? 'Guardando...'
                                  : isEditing
                                  ? 'Guardar cambios'
                                  : 'Guardar reserva',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentCenterPriorityColumn extends StatelessWidget {
  final FinanzasPaymentCenterPriorityBucket bucket;
  final List<FinanzasPaymentCenterOperationalItem> rows;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenProviderAccounts;
  final Future<void> Function(FinanzasPaymentCenterOperationalItem row)
  onOpenBankAccounts;
  final Future<void> Function(FinanzasPaymentCenterOperationalItem row)
  onOpenFixedPayments;

  const _PaymentCenterPriorityColumn({
    required this.bucket,
    required this.rows,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenProviderAccounts,
    required this.onOpenBankAccounts,
    required this.onOpenFixedPayments,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = _paymentCenterBucketTone(bucket);
    final total = rows.fold<double>(0, (sum, row) => sum + row.amountSuggested);
    final previewCount = rows.where((row) => row.isPreviewMock).length;
    return FinanzasGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: BorderRadius.circular(30),
      fillColor: kFinanzasPanelSurfaceSoft,
      borderColor: tokens.border.withValues(alpha: 0.28),
      glowColor: tone.withValues(alpha: 0.14),
      edgeHighlightColor: tone.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.12),
                  border: Border.all(color: tone.withValues(alpha: 0.26)),
                ),
                child: Icon(
                  _paymentCenterBucketIcon(bucket),
                  color: tone,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bucket.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paymentCenterBucketSubtitle(bucket),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kFinanzasMutedInk,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        moneyFormatter(total),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: tone,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monto visible del bucket',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TinyChip(label: '${rows.length}', tone: tone),
                  if (previewCount > 0) ...[
                    const SizedBox(height: 6),
                    _PreviewLabelChip(label: '$previewCount preview'),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: rows.isEmpty
                ? const _CenterEmptyMiniColumn()
                : ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return _PaymentCenterCompactCard(
                          row: row,
                          tone: tone,
                          moneyFormatter: moneyFormatter,
                          dateFormatter: dateFormatter,
                          onOpenProviderAccounts: onOpenProviderAccounts,
                          onOpenBankAccounts: () => onOpenBankAccounts(row),
                          onOpenFixedPayments: () => onOpenFixedPayments(row),
                          featured: index == 0,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCenterCompactCard extends StatelessWidget {
  final FinanzasPaymentCenterOperationalItem row;
  final Color tone;
  final String Function(double value) moneyFormatter;
  final String Function(DateTime? value) dateFormatter;
  final Future<void> Function() onOpenProviderAccounts;
  final Future<void> Function() onOpenBankAccounts;
  final Future<void> Function() onOpenFixedPayments;
  final bool featured;

  const _PaymentCenterCompactCard({
    required this.row,
    required this.tone,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onOpenProviderAccounts,
    required this.onOpenBankAccounts,
    required this.onOpenFixedPayments,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        featured ? 16 : 14,
        featured ? 16 : 14,
        featured ? 16 : 14,
        featured ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: featured ? kFinanzasPanelSurfaceStrong : kFinanzasPanelSurface,
        borderRadius: BorderRadius.circular(featured ? 24 : 22),
        border: Border.all(
          color: row.isPreviewMock
              ? tone.withValues(alpha: 0.26)
              : tokens.border.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: featured ? 18 : 12,
            offset: const Offset(0, 8),
            color: const Color(
              0xFF060100,
            ).withValues(alpha: featured ? 0.20 : 0.12),
          ),
          BoxShadow(
            blurRadius: featured ? 22 : 14,
            offset: const Offset(0, 0),
            color: tone.withValues(alpha: featured ? 0.12 : 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: featured ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.onGlass,
                    height: 1.12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TinyChip(label: row.itemType, tone: tone),
                  if (row.isPreviewMock) ...[
                    const SizedBox(height: 6),
                    const _PreviewLabelChip(label: 'Preview'),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: 'Vence', value: dateFormatter(row.dueDate)),
              _MiniInfoPill(
                label: 'Cantidad',
                value: row.executionAmount > 0.009
                    ? moneyFormatter(row.executionAmount)
                    : moneyFormatter(row.amountSuggested),
              ),
              _MiniInfoPill(
                label: 'Cuenta',
                value: '${row.targetCompany} ${row.targetBranch}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.sourceLabel,
            maxLines: featured ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kFinanzasMutedInk,
              height: 1.3,
            ),
          ),
          if (row.recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.recommendation,
              maxLines: featured ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.badgeText,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyChip(label: row.executionDecision.label, tone: tone),
              if (row.decisionReasons.isNotEmpty)
                _TinyChip(label: row.decisionReasons.first, tone: tone),
              if (row.canPayNow)
                const _PreviewLabelChip(label: 'Caja disponible'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: row.itemType == 'Pago fijo'
                    ? onOpenFixedPayments
                    : onOpenProviderAccounts,
                style: _paymentCenterOutlinedButtonStyle(
                  context,
                  tone: kFinanzasAmber,
                ),
                icon: Icon(
                  row.itemType == 'Pago fijo'
                      ? Icons.receipt_long_outlined
                      : Icons.account_tree_outlined,
                  size: 18,
                ),
                label: Text(row.itemType == 'Pago fijo' ? 'Ver' : 'Cuenta'),
              ),
              FilledButton.icon(
                onPressed: onOpenBankAccounts,
                style: _paymentCenterFilledButtonStyle(
                  context,
                  tone: kFinanzasCoral,
                ),
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: Text(switch (row.executionDecision) {
                  FinanzasPaymentCenterExecutionDecision.pagarCompleto =>
                    'Pagar',
                  FinanzasPaymentCenterExecutionDecision.abonar => 'Abonar',
                  FinanzasPaymentCenterExecutionDecision.esperar => 'Revisar',
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tokens.primary.withValues(alpha: 0.08),
          tokens.badgeBackground.withValues(alpha: 0.86),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: tokens.onGlass,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterEmptyMiniColumn extends StatelessWidget {
  const _CenterEmptyMiniColumn();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderRadius: BorderRadius.circular(20),
      fillColor: kFinanzasPanelSurfaceLight,
      borderColor: tokens.border.withValues(alpha: 0.24),
      child: Text(
        'Sin pendientes en esta prioridad.',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: kFinanzasMutedInk,
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color tone;

  const _TinyChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: 0.14),
          tokens.badgeBackground.withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _PreviewLabelChip extends StatelessWidget {
  final String label;

  const _PreviewLabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.badgeBackground.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: tokens.badgeText,
        ),
      ),
    );
  }
}

class _CenterEmptyPane extends StatelessWidget {
  final String label;
  final String subtitle;

  const _CenterEmptyPane({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: FinanzasGlassPanel(
        width: 460,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        borderRadius: BorderRadius.circular(24),
        fillColor: kFinanzasPanelSurfaceSoft,
        borderColor: tokens.border.withValues(alpha: 0.28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance_outlined, size: 34, color: tokens.primaryStrong),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kFinanzasMutedInk,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinPaymentCenterBackground extends StatelessWidget {
  const _FinPaymentCenterBackground();

  @override
  Widget build(BuildContext context) => const FinanzasAreaBackground();
}

class _FinPaymentCenterSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final void Function(String label) onNavigate;

  const _FinPaymentCenterSidePanel({
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) => FinanzasAreaSidePanel(
    currentLabel: 'Centro de pagos',
    canReturnToDirection: canReturnToDirection,
    canAccessComprasArea: canAccessComprasArea,
    onNavigate: onNavigate,
  );
}

Color _paymentCenterBucketTone(FinanzasPaymentCenterPriorityBucket bucket) {
  switch (bucket) {
    case FinanzasPaymentCenterPriorityBucket.obligatorio:
      return kFinanzasOrangeIntense;
    case FinanzasPaymentCenterPriorityBucket.urgente:
      return kFinanzasOrange;
    case FinanzasPaymentCenterPriorityBucket.recomendado:
      return kFinanzasOrangeElectric;
    case FinanzasPaymentCenterPriorityBucket.postergable:
      return kFinanzasBronze;
  }
}

IconData _paymentCenterBucketIcon(FinanzasPaymentCenterPriorityBucket bucket) {
  switch (bucket) {
    case FinanzasPaymentCenterPriorityBucket.obligatorio:
      return Icons.warning_amber_rounded;
    case FinanzasPaymentCenterPriorityBucket.urgente:
      return Icons.flash_on_rounded;
    case FinanzasPaymentCenterPriorityBucket.recomendado:
      return Icons.check_circle_outline_rounded;
    case FinanzasPaymentCenterPriorityBucket.postergable:
      return Icons.schedule_rounded;
  }
}

String _paymentCenterBucketSubtitle(
  FinanzasPaymentCenterPriorityBucket bucket,
) {
  switch (bucket) {
    case FinanzasPaymentCenterPriorityBucket.obligatorio:
      return 'Compromisos que ya no deberían esperar.';
    case FinanzasPaymentCenterPriorityBucket.urgente:
      return 'Salidas sensibles para esta ventana de caja.';
    case FinanzasPaymentCenterPriorityBucket.recomendado:
      return 'Pagos programables con buena lectura operativa.';
    case FinanzasPaymentCenterPriorityBucket.postergable:
      return 'Elementos visibles sin presión inmediata.';
  }
}
