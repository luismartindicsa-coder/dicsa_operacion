part of '../human_resources_dashboard_page.dart';

const _hrBirthdayCakeAsset = 'assets/images/hr_birthday_cake.png';

class _HrDashboardBirthdayCard extends StatelessWidget {
  final HrBirthdayMonth? data;
  final bool loading;

  const _HrDashboardBirthdayCard({required this.data, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final month = data;
    final tokens = humanResourcesAreaTokens;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
      button: month != null,
      label: 'Ver cumpleaños del mes',
      child: _HrDashboardPanel(
        accent: tokens.accent,
        onTap: month == null ? null : () => _showHrBirthdays(context, month),
        child: SizedBox(
          height: 204 * math.max(1.0, textScale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tokens.primary, tokens.accent],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cake_outlined,
                      color: tokens.onGlass,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cumpleaños del mes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.onGlass,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          month?.monthLabel ??
                              (loading
                                  ? 'Cargando cumpleaños…'
                                  : 'Sin datos disponibles'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.onGlass.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cakeWidth = constraints.maxWidth < 300 ? 78.0 : 100.0;
                    return Row(
                      children: [
                        SizedBox(
                          width: cakeWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Image.asset(
                                  _hrBirthdayCakeAsset,
                                  width: cakeWidth,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                month == null
                                    ? '—'
                                    : '${month.employees.length}',
                                style: TextStyle(
                                  color: tokens.onGlass,
                                  fontSize: 23,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'cumpleaños',
                                maxLines: 1,
                                style: TextStyle(
                                  color: tokens.badgeText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: month == null || month.employees.isEmpty
                              ? Text(
                                  month == null
                                      ? (loading
                                            ? 'Consultando Personal…'
                                            : 'No se pudieron consultar los cumpleaños.')
                                      : 'Sin cumpleaños registrados en ${month.monthName.toLowerCase()}.',
                                  style: TextStyle(
                                    color: tokens.onGlass.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final employee in month.employees.take(
                                      3,
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: _HrBirthdayEmployeeTile(
                                          employee: employee,
                                          month: month,
                                          compact: true,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver todos',
                    style: TextStyle(
                      color: tokens.badgeText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: tokens.badgeText,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showHrBirthdays(BuildContext context, HrBirthdayMonth month) =>
    showDialog<void>(
      context: context,
      builder: (context) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HrBirthdaysDialog(month: month),
      ),
    );

class _HrBirthdaysDialog extends StatelessWidget {
  final HrBirthdayMonth month;

  const _HrBirthdaysDialog({required this.month});

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    final size = MediaQuery.sizeOf(context);
    return ContractDialogShell(
      child: Container(
        width: 640,
        constraints: BoxConstraints(maxHeight: math.max(0, size.height - 48)),
        decoration: BoxDecoration(
          gradient: kHumanResourcesPanelGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.border.withValues(alpha: 0.65)),
        ),
        padding: EdgeInsets.all(size.width < 480 ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HumanResourcesCompactDialogHeader(
              title: 'Cumpleaños del mes',
              contextLabel: month.monthLabel,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.border.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    _hrBirthdayCakeAsset,
                    width: 72,
                    height: 72,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${month.employees.length} ${month.employees.length == 1 ? 'colaborador' : 'colaboradores'}',
                          style: TextStyle(
                            color: tokens.primaryStrong,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Cumplen años en ${month.monthName.toLowerCase()}',
                          style: const TextStyle(
                            color: kHumanResourcesMutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: month.employees.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No hay cumpleaños registrados este mes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kHumanResourcesMutedText),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: month.employees.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _HrBirthdayEmployeeTile(
                        employee: month.employees[index],
                        month: month,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              'Fechas tomadas del CURP de Personal.',
              style: const TextStyle(
                color: kHumanResourcesMutedText,
                fontSize: 12,
              ),
            ),
            if (month.missingBirthDateCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${month.missingBirthDateCount} ${month.missingBirthDateCount == 1 ? 'expediente sin fecha válida' : 'expedientes sin fecha válida'} en el CURP. Se pueden completar en Personal.',
                style: TextStyle(color: tokens.surfaceTint, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HrBirthdayEmployeeTile extends StatelessWidget {
  final HrEmployeeBirthday employee;
  final HrBirthdayMonth month;
  final bool compact;

  const _HrBirthdayEmployeeTile({
    required this.employee,
    required this.month,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = humanResourcesAreaTokens;
    final isToday = employee.day == month.today.day;
    final foreground = compact ? tokens.onGlass : tokens.primaryStrong;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 12,
        vertical: compact ? 4 : 12,
      ),
      decoration: BoxDecoration(
        color: compact
            ? tokens.primary.withValues(alpha: 0.1)
            : tokens.onGlass.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: compact
            ? null
            : Border.all(
                color: tokens.border.withValues(alpha: isToday ? 0.8 : 0.2),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 28 : 40,
            height: compact ? 28 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [tokens.accent, tokens.primary]),
            ),
            child: Text(
              employee.initials,
              style: TextStyle(
                color: tokens.onGlass,
                fontSize: compact ? 10 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: compact ? 7 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 11 : 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  compact
                      ? employee.company
                      : 'ID #${employee.employeeId} · ${employee.company}',
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    color: compact
                        ? tokens.onGlass.withValues(alpha: 0.65)
                        : kHumanResourcesMutedText,
                    fontSize: compact ? 9 : 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: compact ? 28 : 42,
            child: Column(
              children: [
                Text(
                  '${employee.day}',
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 16 : 23,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  isToday ? 'HOY' : month.monthAbbreviation,
                  style: TextStyle(
                    color: compact ? tokens.badgeText : tokens.surfaceTint,
                    fontSize: compact ? 8 : 10,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
