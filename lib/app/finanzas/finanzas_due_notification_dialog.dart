import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/utils/number_formatters.dart';
import 'finanzas_due_alerts_store.dart';
import 'finanzas_theme.dart';

/// Auxiliary surface shared by Finanzas and Dirección; the shell uses host tokens.
class FinanzasDueNotificationDialog extends StatefulWidget {
  final FinanzasDueAlertsSummary summary;
  final ContractAreaTokens tokens;
  final String actionLabel;
  final Future<void> Function() onOpenPayments;

  const FinanzasDueNotificationDialog({
    super.key,
    required this.summary,
    required this.tokens,
    required this.actionLabel,
    required this.onOpenPayments,
  });

  @override
  State<FinanzasDueNotificationDialog> createState() =>
      _FinanzasDueNotificationDialogState();
}

class _FinanzasDueNotificationDialogState
    extends State<FinanzasDueNotificationDialog> {
  bool _showPastDue = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final items = _showPastDue ? summary.pastDueItems : summary.weekItems;
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    final tokens = widget.tokens;
    final weekLastDay = DateTime(
      summary.weekEnd.year,
      summary.weekEnd.month,
      summary.weekEnd.day - 1,
    );
    return Dialog(
      backgroundColor: tokens.surfaceTint.withValues(alpha: 0.98),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: tokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: tokens.primaryStrong,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Finanzas requiere atención',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final pastDue in [false, true])
                    ChoiceChip(
                      label: Text(
                        pastDue
                            ? 'Deuda anterior (${summary.pastDueItems.length})'
                            : 'Esta semana (${summary.weekItems.length})',
                      ),
                      selected: _showPastDue == pastDue,
                      color: WidgetStateProperty.resolveWith(
                        (states) => Color.alphaBlend(
                          states.contains(WidgetState.selected)
                              ? tokens.primaryStrong.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.06),
                          tokens.surfaceTint,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      checkmarkColor: tokens.primaryStrong,
                      side: BorderSide(color: tokens.border),
                      onSelected: (_) {
                        setState(() => _showPastDue = pastDue);
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(0);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _showPastDue
                    ? 'Pendientes anteriores al ${_date(summary.weekStart)}'
                    : 'Por pagar del ${_date(summary.weekStart)} al ${_date(weekLastDay)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${items.length} compromisos · ${formatMoney(total)}',
                key: const ValueKey('due-notification-total'),
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.48,
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                _showPastDue
                                    ? 'No hay deuda pendiente de semanas anteriores.'
                                    : 'No hay facturas ni pagos pendientes para esta semana.',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          for (final source in [
                            'FACTURA',
                            'PAGO_FIJO',
                            'CONVENIO',
                          ])
                            if (items.any(
                              (item) => item.sourceType == source,
                            )) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  switch (source) {
                                    'PAGO_FIJO' => 'Pagos fijos',
                                    'CONVENIO' => 'Convenios',
                                    _ => 'Facturas generales',
                                  },
                                  style: TextStyle(
                                    color: finanzasPaymentSourceTone(source),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              for (final item in items.where(
                                (item) => item.sourceType == source,
                              ))
                                _DueItemCard(
                                  item: item,
                                  dateLabel: _date(item.dueDate),
                                ),
                              const SizedBox(height: 6),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: tokens.border),
                      ),
                      child: const Text('Después'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onOpenPayments,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.primaryStrong,
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(widget.actionLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueItemCard extends StatelessWidget {
  final FinanzasDueAlertItem item;
  final String dateLabel;

  const _DueItemCard({required this.item, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final tone = finanzasPaymentSourceTone(item.sourceType);
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '$dateLabel · ${formatMoney(item.amount)}',
            style: TextStyle(color: tone, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
