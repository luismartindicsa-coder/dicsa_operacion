import 'package:flutter/material.dart';

import 'human_resources_theme.dart';
import 'human_resources_fiscal_payment.dart';

/// Fiscal remains a dominant total; deposit and cheque explain its delivery.
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
  Widget build(BuildContext context) => Container(
    key: const ValueKey('fiscal-payment-card'),
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
          'Total fiscal',
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
            formatMoney(payment.total),
            key: const ValueKey('fiscal-combined-total'),
            style: TextStyle(
              color: humanResourcesAreaTokens.primaryStrong,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        for (final item in [
          ('Depósito', payment.deposit, 'fiscal-deposit-total'),
          ('Cheque', payment.cheque, 'fiscal-cheque-total'),
        ])
          Row(
            children: [
              Text(
                item.$1,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  color: humanResourcesAreaTokens.surfaceTint,
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
