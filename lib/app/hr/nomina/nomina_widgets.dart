part of '../human_resources_nomina_page.dart';

// Presentation grouping only: the existing total already includes deductions
// and payment outside. No second deduction or alternative payroll calculation.
double _nominaFlow(_HrNominaSummaryRow row) =>
    row.totalAmount - row.fiscalAmount;
String _nominaDate(DateTime? date) => date == null
    ? '—'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _nominaChannel(String value) => switch (value) {
  'Efectivo' => 'Flujo',
  'Fiscal en efectivo' => 'Fiscal sin depósito',
  _ => value,
};

// Visual reference: Prenómina. This scope only changes presentation.
class _NominaTheme extends StatelessWidget {
  final Widget child;
  final bool dark;
  const _NominaTheme({required this.child, this.dark = false});
  @override
  Widget build(BuildContext context) {
    const t = humanResourcesAreaTokens;
    final foreground = dark ? t.onGlass : t.primaryStrong;
    final muted = dark ? t.badgeText : t.surfaceTint;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        brightness: dark ? Brightness.dark : Brightness.light,
        colorScheme: dark
            ? ColorScheme.dark(
                primary: t.accent,
                surface: t.glassSurface,
                onSurface: t.onGlass,
                onPrimary: t.primaryStrong,
              )
            : ColorScheme.light(
                primary: t.surfaceTint,
                surface: t.primarySoft,
                onSurface: t.primaryStrong,
                onPrimary: t.onGlass,
              ),
        textTheme: theme.textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
        iconTheme: IconThemeData(color: muted),
        dividerTheme: DividerThemeData(color: t.border.withValues(alpha: .25)),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _nominaOutlinedStyle(context, dark: dark),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _nominaFilledStyle(context),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: muted,
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: t.primarySoft.withValues(alpha: .6),
          hintStyle: TextStyle(color: muted, fontSize: 12),
          prefixIconColor: muted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.border.withValues(alpha: .45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: t.border, width: 1.5),
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: child,
      ),
    );
  }
}

ButtonStyle _nominaOutlinedStyle(BuildContext context, {bool dark = false}) =>
    OutlinedButton.styleFrom(
      foregroundColor: dark
          ? humanResourcesAreaTokens.onGlass
          : humanResourcesAreaTokens.primaryStrong,
      side: BorderSide(
        color: humanResourcesAreaTokens.border.withValues(alpha: .65),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    );
ButtonStyle _nominaFilledStyle(BuildContext context) => FilledButton.styleFrom(
  backgroundColor: humanResourcesAreaTokens.accent,
  foregroundColor: humanResourcesAreaTokens.primaryStrong,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  textStyle: Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
);

class _NominaSurface extends StatelessWidget {
  final Widget child;
  const _NominaSurface({required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: humanResourcesAreaTokens.primarySoft,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: humanResourcesAreaTokens.border.withValues(alpha: .3),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: _NominaTheme(child: child),
    ),
  );
}

class _NominaCards extends StatelessWidget {
  final List<(String, String, String)> items;
  final HrFiscalPayment? fiscalPayment;
  const _NominaCards({required this.items, this.fiscalPayment});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 850
          ? (items.length > 4 ? 3 : 2)
          : items.length;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              height: 110,
              child: item.$1 == 'Fiscal' && fiscalPayment != null
                  ? HrFiscalPaymentCard(
                      payment: fiscalPayment!,
                      formatMoney: _fmtHrNominaMoney,
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.$1.startsWith('Total')
                            ? humanResourcesAreaTokens.accent
                            : humanResourcesAreaTokens.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: humanResourcesAreaTokens.border.withValues(
                            alpha: .45,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                switch (item.$1) {
                                  'Colaboradores' => Icons.people_outline,
                                  'Listos' => Icons.task_alt,
                                  'Pendientes' =>
                                    Icons.pending_actions_outlined,
                                  'Fiscal' => Icons.account_balance_outlined,
                                  'Flujo' => Icons.payments_outlined,
                                  _ => Icons.account_balance_wallet_outlined,
                                },
                                size: 20,
                                color: humanResourcesAreaTokens.surfaceTint,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: humanResourcesAreaTokens.surfaceTint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.$2,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: humanResourcesAreaTokens.primaryStrong,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: humanResourcesAreaTokens.surfaceTint,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      );
    },
  );
}

class _NominaDetailTotals extends StatelessWidget {
  final _HrNominaSummaryRow row;
  const _NominaDetailTotals({required this.row});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in [
        ('Fiscal', row.fiscalAmount),
        ('Flujo', _nominaFlow(row)),
        ('Total', row.totalAmount),
      ])
        Expanded(
          child: Container(
            margin: EdgeInsets.only(right: item.$1 == 'Total' ? 0 : 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.$1 == 'Total'
                  ? humanResourcesAreaTokens.primaryStrong
                  : humanResourcesAreaTokens.primarySoft.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: humanResourcesAreaTokens.border.withValues(
                  alpha: item.$1 == 'Total' ? .8 : .25,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: TextStyle(
                    color: humanResourcesAreaTokens.badgeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fmtHrNominaMoney(item.$2),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
