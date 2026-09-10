part of '../human_resources_loans_page.dart';

class HrLoansWorkspace extends StatefulWidget {
  final HrLoanFundState fund;
  final Future<void> Function()? onCreate;
  final Future<void> Function(HrLoan)? onCashPayment;
  final Future<void> Function(HrLoan)? onChangeChannel;
  const HrLoansWorkspace({
    super.key,
    required this.fund,
    this.onCreate,
    this.onCashPayment,
    this.onChangeChannel,
  });
  @override
  State<HrLoansWorkspace> createState() => _HrLoansWorkspaceState();
}

class _HrLoansWorkspaceState extends State<HrLoansWorkspace> {
  final _search = TextEditingController();
  final _listFocus = FocusNode(debugLabel: 'Lista de préstamos');
  final _loanKeys = <String, GlobalKey>{};
  String? _selected;
  String _filter = 'Activos';
  @override
  void dispose() {
    _search.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  void _selectLoan(HrLoan loan, {bool backwards = false}) {
    setState(() => _selected = loan.id);
    _listFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _loanKeys[loan.id]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: backwards
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fund = widget.fund;
    final query = _search.text.trim().toUpperCase();
    final loans =
        fund.loans.where((l) {
          final active = fund.balanceCents(l) > 0;
          return (_filter == 'Todos' ||
                  (_filter == 'Activos' ? active : !active)) &&
              '${l.employeeName} ${l.employeeId} ${l.folio} ${l.company}'
                  .toUpperCase()
                  .contains(query);
        }).toList()..sort((a, b) {
          final byDate = b.displayDate.compareTo(a.displayDate);
          return byDate == 0 ? a.folio.compareTo(b.folio) : byDate;
        });
    final chosen = loans.where((l) => l.id == _selected).firstOrNull;
    return WorkflowMasterDetailShell(
      masterFlex: 2,
      detailFlex: 3,
      topBar: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Préstamos a colaboradores',
                  style: _loanText(26, strong: true),
                ),
                Text(
                  'Entregas, plazos y recuperación del fondo',
                  style: _loanText(13, muted: true),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: contractPrimaryButtonStyle(context),
            onPressed: widget.onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo préstamo'),
          ),
        ],
      ),
      summary: _HrLoanFundCard(fund: fund),
      master: ContractGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              style: _loanText(14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar colaborador o folio',
                hintStyle: _loanText(13, muted: true),
                prefixIcon: Icon(
                  Icons.search,
                  color: humanResourcesAreaTokens.accent,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final filter in ['Activos', 'Liquidados', 'Todos'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    selectedColor: humanResourcesAreaTokens.accent,
                    backgroundColor: humanResourcesAreaTokens.fieldSurface,
                    side: BorderSide(
                      color: humanResourcesAreaTokens.border.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: _filter == filter
                          ? humanResourcesAreaTokens.primaryStrong
                          : humanResourcesAreaTokens.onGlass,
                    ),
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${loans.length} préstamo(s)',
              style: _loanText(12, muted: true),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loans.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'No hay préstamos en este estado.'
                            : 'No hay coincidencias.',
                        style: _loanText(14, muted: true),
                      ),
                    )
                  : Focus(
                      focusNode: _listFocus,
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent &&
                            event is! KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        if (key != LogicalKeyboardKey.arrowDown &&
                            key != LogicalKeyboardKey.arrowUp) {
                          return KeyEventResult.ignored;
                        }
                        final current = loans.indexWhere(
                          (loan) => loan.id == _selected,
                        );
                        final index = current < 0
                            ? 0
                            : (current +
                                      (key == LogicalKeyboardKey.arrowDown
                                          ? 1
                                          : -1))
                                  .clamp(0, loans.length - 1);
                        _selectLoan(
                          loans[index],
                          backwards: key == LogicalKeyboardKey.arrowUp,
                        );
                        return KeyEventResult.handled;
                      },
                      child: ListView.separated(
                        itemCount: loans.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final loan = loans[index];
                          return Material(
                            key: _loanKeys.putIfAbsent(loan.id, GlobalKey.new),
                            color: chosen?.id == loan.id
                                ? humanResourcesAreaTokens.primary.withValues(
                                    alpha: 0.3,
                                  )
                                : humanResourcesAreaTokens.fieldSurface,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              selected: chosen?.id == loan.id,
                              onTap: () => _selectLoan(loan),
                              title: Text(
                                loan.employeeName,
                                style: _loanText(13, strong: true),
                              ),
                              subtitle: Text(
                                'PR-${loan.folio} · ${hrLoanDate(loan.displayDate)}\n${loan.methodLabel}',
                                style: _loanText(11, muted: true),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _loanMoney(fund.balanceCents(loan)),
                                    style: _loanText(15, strong: true),
                                  ),
                                  Text(
                                    fund.balanceCents(loan) == 0
                                        ? 'Liquidado'
                                        : 'Pendiente',
                                    style: _loanText(10, muted: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      detail: ContractGlassCard(
        child: chosen == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 44,
                      color: humanResourcesAreaTokens.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Selecciona un préstamo',
                      style: _loanText(20, strong: true),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Consulta su saldo, calendario y abonos.',
                      style: _loanText(13, muted: true),
                    ),
                  ],
                ),
              )
            : _HrLoanDetail(
                key: ValueKey(chosen.id),
                fund: fund,
                loan: chosen,
                onChangeChannel:
                    widget.onChangeChannel == null ||
                        fund.balanceCents(chosen) == 0
                    ? null
                    : () => widget.onChangeChannel!(chosen),
                onCashPayment:
                    widget.onCashPayment == null ||
                        fund.balanceCents(chosen) == 0
                    ? null
                    : () => widget.onCashPayment!(chosen),
              ),
      ),
    );
  }
}

class _HrLoanFundCard extends StatelessWidget {
  final HrLoanFundState fund;
  const _HrLoanFundCard({required this.fund});
  @override
  Widget build(BuildContext context) => ContractGlassCard(
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: humanResourcesAreaTokens.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DISPONIBLE EN EL FONDO',
                    style: _loanText(13, muted: true),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _loanMoney(fund.availableCents),
                style: _loanText(40, strong: true),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: fund.capitalCents == 0
                    ? 0
                    : (fund.availableCents / fund.capitalCents).clamp(0, 1),
                color: humanResourcesAreaTokens.accent,
                backgroundColor: humanResourcesAreaTokens.primaryStrong,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 7),
              Text(
                'Se recupera con abonos confirmados.',
                style: _loanText(12, muted: true),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 3,
          child: Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _loanMetric('Fondo inicial', _loanMoney(fund.capitalCents)),
              _loanMetric('Por recuperar', _loanMoney(fund.outstandingCents)),
              _loanMetric('Abonos acumulados', _loanMoney(fund.recoveredCents)),
              _loanMetric(
                'Préstamos activos',
                '${fund.loans.where((l) => fund.balanceCents(l) > 0).length}',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _loanMetric(String label, String value) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: _loanText(12, muted: true)),
    const SizedBox(height: 4),
    Text(value, style: _loanText(20, strong: true)),
  ],
);

class _HrLoanDetail extends StatelessWidget {
  final HrLoanFundState fund;
  final HrLoan loan;
  final Future<void> Function()? onCashPayment;
  final Future<void> Function()? onChangeChannel;
  const _HrLoanDetail({
    super.key,
    required this.fund,
    required this.loan,
    this.onCashPayment,
    this.onChangeChannel,
  });
  @override
  Widget build(BuildContext context) {
    final paid = fund.paidCents(loan);
    final payments = fund.payments.where((p) => p.loanId == loan.id).toList()
      ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loan.employeeName,
                  style: _loanText(19, strong: true),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onCashPayment,
                style: contractPrimaryButtonStyle(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Abono en efectivo'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'PR-${loan.folio} · ID #${loan.employeeId} · ${loan.company}',
            style: _loanText(12, muted: true),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _loanMetric('Entregado', _loanMoney(loan.principalCents)),
              _loanMetric('Abonado', _loanMoney(paid)),
              _loanMetric(
                'Saldo pendiente',
                _loanMoney(fund.balanceCents(loan)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loan.method == 'nomina')
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: onChangeChannel,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(
                  'Cobro: ${loan.payrollChannel == 'fiscal' ? 'Fiscal · CONTPAQ' : 'Flujo'}',
                ),
              ),
            ),
          TabBar(
            labelColor: humanResourcesAreaTokens.onGlass,
            unselectedLabelColor: humanResourcesAreaTokens.badgeText,
            indicatorColor: humanResourcesAreaTokens.accent,
            tabs: const [
              Tab(text: 'Plazos'),
              Tab(text: 'Historial de abonos'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  children: [
                    Text(
                      '${loan.installments} cuotas · ${loan.frequencyLabel} · ${loan.methodLabel}',
                      style: _loanText(14, strong: true),
                    ),
                    if (loan.isHistorical)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Solicitud: ${hrLoanDate(loan.displayDate)} · Saldo inicial al ${hrLoanDate(loan.issuedOn)}\n${loan.openingSnapshot['first_pending_period'] ?? ''}',
                          style: _loanText(12, muted: true),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      loan.method == 'nomina'
                          ? _loanChannelExplanation(loan.payrollChannel)
                          : 'Registra los abonos cuando el colaborador entregue el efectivo.',
                      style: _loanText(12, muted: true),
                    ),
                    if (loan.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(loan.notes, style: _loanText(13)),
                      ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < loan.installments; i++)
                      Builder(
                        builder: (_) {
                          final amount = loan.installmentCents(i);
                          final paidBefore = loan.paidBeforeInstallment(i);
                          final settled = math.min(
                            math.max(0, paid - paidBefore),
                            amount,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                    '${i + 1}',
                                    style: _loanText(12, muted: true),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    loan.dueOn(i) == null
                                        ? 'Abono anterior · sin fecha'
                                        : hrLoanDate(loan.dueOn(i)!),
                                    style: _loanText(13),
                                  ),
                                ),
                                Text(
                                  _loanMoney(amount),
                                  style: _loanText(13, strong: true),
                                ),
                                const SizedBox(width: 18),
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    settled == amount
                                        ? 'Cubierta'
                                        : settled > 0
                                        ? 'Pendiente ${_loanMoney(amount - settled)}'
                                        : 'Pendiente',
                                    textAlign: TextAlign.end,
                                    style: _loanText(11, muted: true),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                ListView(
                  children: [
                    if (loan.isHistorical)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Abonos anteriores: ${_loanMoney(loan.openingPaidCents)}',
                              style: _loanText(14, strong: true),
                            ),
                            Text(
                              '${loan.openingPaidInstallments}/${loan.installments} pagos al migrar · ${hrLoanDate(loan.issuedOn)}',
                              style: _loanText(12, muted: true),
                            ),
                            Text(
                              'Resumen de RH. No se documentaron las fechas ni el medio de los abonos anteriores.',
                              style: _loanText(12, muted: true),
                            ),
                          ],
                        ),
                      ),
                    if (payments.isEmpty)
                      Text(
                        'Aún no hay abonos nuevos registrados en la app.',
                        style: _loanText(14, muted: true),
                      ),
                    for (final payment in payments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          payment.method == 'nomina'
                              ? Icons.receipt_long_outlined
                              : Icons.payments_outlined,
                          color: humanResourcesAreaTokens.accent,
                        ),
                        title: Text(
                          '${_loanMoney(payment.cents)} · ${payment.methodLabel}',
                          style: _loanText(14, strong: true),
                        ),
                        subtitle: Text(
                          '${hrLoanDate(payment.paidOn)}${payment.periodLabel.isEmpty ? '' : '\n${payment.periodLabel}'}${payment.notes.isEmpty ? '' : '\n${payment.notes}'}',
                          style: _loanText(12, muted: true),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
