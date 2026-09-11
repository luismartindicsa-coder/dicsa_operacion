import 'package:flutter/material.dart';

import 'human_resources_theme.dart';
import 'human_resources_fiscal_payment.dart';

/// Deposit is the payment to send through the bank. Fiscal total remains
/// visible as origin; its cheque portion is included in flow delivery.
/// Fits the existing KPI row so small windows keep their working table area.
class HrFiscalPaymentCard extends StatelessWidget {
  final HrFiscalPayment payment;
  final String Function(double) formatMoney;

  const HrFiscalPaymentCard({
    super.key,
    required this.payment,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) => _HrPaymentBreakdownCard(
    cardId: 'fiscal-payment-card',
    title: 'Depósito fiscal',
    amount: payment.deposit,
    amountId: 'fiscal-deposit-total',
    details: [
      ('Total fiscal', payment.total, 'fiscal-combined-total'),
      ('Cheque', payment.cheque, 'fiscal-cheque-total'),
    ],
    formatMoney: formatMoney,
  );
}

/// Delivery total with its operational flow and fiscal cheque components.
class HrFlowPaymentCard extends StatelessWidget {
  final double deliveryAmount;
  final double chequeAmount;
  final String Function(double) formatMoney;

  const HrFlowPaymentCard({
    super.key,
    required this.deliveryAmount,
    required this.chequeAmount,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) => _HrPaymentBreakdownCard(
    cardId: 'flow-payment-card',
    title: 'Flujo a entregar',
    amount: deliveryAmount,
    amountId: 'flow-delivery-total',
    details: [
      ('Flujo', deliveryAmount - chequeAmount, 'flow-operational-total'),
      ('Cheque', chequeAmount, 'flow-cheque-total'),
    ],
    formatMoney: formatMoney,
  );
}

class _HrPaymentBreakdownCard extends StatelessWidget {
  final String cardId;
  final String title;
  final double amount;
  final String amountId;
  final List<(String, double, String)> details;
  final String Function(double) formatMoney;

  const _HrPaymentBreakdownCard({
    required this.cardId,
    required this.title,
    required this.amount,
    required this.amountId,
    required this.details,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(cardId),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: humanResourcesAreaTokens.primarySoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: humanResourcesAreaTokens.border.withValues(alpha: .45),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.15,
            color: humanResourcesAreaTokens.surfaceTint,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoney(amount),
            key: ValueKey(amountId),
            style: TextStyle(
              color: humanResourcesAreaTokens.primaryStrong,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        for (final item in details)
          Row(
            children: [
              Expanded(
                child: Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    color: humanResourcesAreaTokens.surfaceTint,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(item.$2),
                      key: ValueKey(item.$3),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: humanResourcesAreaTokens.primaryStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
