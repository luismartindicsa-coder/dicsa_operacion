part of 'profitability_view.dart';

/// Primary screen: one operational statement per account. The previous
/// configuration/audit workspace is an auxiliary surface, not the entry flow.
extension _ProfitSimple on _ProfitabilityViewState {
  List<ProfitCompanyResult> get _accounts =>
      (_analysis?.reportCompanies ?? [])
          .where(
            (c) =>
                c.account != null &&
                profitKey(
                  '${c.displayName} ${c.operating?.group ?? ''}',
                ).contains(profitKey(_search.text)),
          )
          .toList()
        ..sort(
          (a, b) => b.account!.contribution.compareTo(a.account!.contribution),
        );
  Future<void> _month(int offset) async {
    final date = DateTime(_period.start.year, _period.start.month + offset);
    final last = DateTime(date.year, date.month + 1, 0), now = DateTime.now();
    if (date.isAfter(now)) return;
    _simpleSelected = null;
    await _change(ProfitPeriod(date, last.isAfter(now) ? now : last));
  }

  Widget _simpleView() {
    final rows = _accounts;
    final selected = rows
        .where((c) => c.entity.key == _simpleSelected)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: _busy ? null : () => _month(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickPeriod,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_period.label),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed:
                  _busy ||
                      DateTime(
                        _period.start.year,
                        _period.start.month + 1,
                      ).isAfter(DateTime.now())
                  ? null
                  : () => _month(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: _busy ? null : () => _change(_presetPeriod(2)),
              child: const Text('Este mes'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _change(_presetPeriod(1)),
              child: const Text('Esta semana'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _change(_presetPeriod(0)),
              child: const Text('Hoy'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones del análisis',
              enabled: _enabled,
              onSelected: (value) {
                switch (value) {
                  case 'rules':
                    _redraw(() {
                      _advanced = true;
                      _executiveTab = 3;
                    });
                  case 'audit':
                    _redraw(() {
                      _advanced = true;
                      _executiveTab = 4;
                    });
                  case 'csv':
                    unawaited(_export(false));
                  case 'json':
                    unawaited(_export(true));
                  case 'save':
                    unawaited(_snapshot());
                  case 'history':
                    unawaited(_history());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rules',
                  child: Text('Ajustar supuestos y conceptos'),
                ),
                PopupMenuItem(value: 'csv', child: Text('Exportar tabla')),
                PopupMenuItem(value: 'save', child: Text('Guardar análisis')),
                PopupMenuItem(
                  value: 'history',
                  child: Text('Análisis guardados'),
                ),
                PopupMenuItem(
                  value: 'audit',
                  child: Text('Revisar fuentes y conciliación'),
                ),
                PopupMenuItem(
                  value: 'json',
                  child: Text('Exportar bases del cálculo'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz, color: kDirectionSurfaceText),
                    SizedBox(width: 6),
                    Text(
                      'Opciones',
                      style: TextStyle(color: kDirectionSurfaceText),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _text(
          'Empresas de Compras Mayoreo · Datos de Compras, Ventas, RH, Logística y Finanzas · Todos los centros incluidos',
        ),
        if ((_analysis?.unclassifiedCosts ?? 0) > 0)
          _text(
            'Resultado provisional: ${_mxn(_analysis!.unclassifiedCosts)} pendientes de clasificar. Se conservan en el resultado global, sin repartir entre empresas. Ver alcance y conciliación.',
            warning: true,
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _text(
              '$_error\n${_analysis == null ? 'Reintentando la consulta.' : 'Se muestra la última lectura; guardar y exportar están suspendidos.'}',
              warning: true,
            ),
          ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? directionAreaTokens.primary.withValues(alpha: .18)
                    : directionAreaTokens.glassSurface,
              ),
              foregroundColor: WidgetStatePropertyAll(
                directionAreaTokens.onGlass,
              ),
            ),
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Empresas'),
                icon: Icon(Icons.business_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Consolidado'),
                icon: Icon(Icons.insights_outlined),
              ),
            ],
            selected: {_simpleTab},
            onSelectionChanged: _busy
                ? null
                : (v) => _redraw(() => _simpleTab = v.single),
          ),
        ),
        const SizedBox(height: 12),
        if (_simpleTab == 0)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar empresa',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _redraw(() => _simpleSelected = null),
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton.icon(
                    key: const ValueKey('profit-company-pdf'),
                    onPressed: _enabled
                        ? () async => _exportCompanyPdf(selected.entity.key)
                        : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(_busy ? 'Generando…' : 'Generar PDF'),
                  ),
                ),
              if (selected != null)
                TextButton.icon(
                  onPressed: () => _redraw(() => _simpleSelected = null),
                  icon: const Icon(Icons.view_list_outlined),
                  label: const Text('Todas las empresas'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _analysis == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : _text('Esperando los datos de operación.'),
                )
              : _simpleTab == 1
              ? _consolidatedView()
              : selected == null
              ? _simpleOverview(rows)
              : _simpleAccount(selected, rows),
        ),
      ],
    );
  }

  Widget _statementCards(double generated, double cost, double result) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 850 ? 3 : 1,
              width = (constraints.maxWidth - (count - 1) * 12) / count;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: _kpi(
                  'Lo que genera',
                  _mxn(generated),
                  'Material recuperable + servicios',
                ),
              ),
              SizedBox(
                width: width,
                child: _kpi(
                  'Lo que cuesta atender',
                  _mxn(cost),
                  'Compra + operación + soporte asignado',
                ),
              ),
              SizedBox(
                width: width,
                child: _kpi(
                  'APORTE OPERATIVO',
                  _mxn(result),
                  generated > 0
                      ? 'Margen ${_percent(result / generated)}'
                      : 'Sin ingreso atribuido en este periodo',
                  sign: result,
                ),
              ),
            ],
          );
        },
      );
  Widget _simpleOverview(List<ProfitCompanyResult> rows) {
    final generated = rows.fold<double>(0, (v, c) => v + c.account!.generated),
        cost = rows.fold<double>(0, (v, c) => v + c.account!.costs);
    return ListView(
      children: [
        _heading('¿Cuánto nos deja atender a cada empresa?'),
        _statementCards(generated, cost, generated - cost),
        _historicalReserveNote(rows),
        _text(
          'Estimación operativa: el valor del material usa ventas comparables; el aporte incluye el reparto de soporte compartido.',
        ),
        _scopeReconciliation(),
        if (_analysis!.nonOperatingFlows.isNotEmpty)
          _card([
            ExpansionTile(
              title: Text(
                'Flujos fuera del aporte operativo · ${_mxn(_analysis!.nonOperatingFlows.fold<double>(0, (v, r) => v + (profitNumber(r['amount']) ?? 0)))}',
                style: const TextStyle(color: kDirectionSurfaceText),
              ),
              subtitle: const Text(
                'Financiamiento, tesorería y gastos personales',
                style: TextStyle(color: kDirectionMutedText),
              ),
              children: [
                for (final r in _analysis!.nonOperatingFlows)
                  ListTile(
                    title: Text(
                      '${r['date']} · ${_mxn(profitNumber(r['amount']))} · ${r['label']}',
                      style: const TextStyle(color: kDirectionSurfaceText),
                    ),
                    subtitle: SelectableText(
                      '${r['reason']} · ${r['id']}',
                      style: const TextStyle(color: kDirectionMutedText),
                    ),
                  ),
              ],
            ),
          ]),
        const SizedBox(height: 16),
        _card([
          _heading('Empresas · ${rows.length} cuentas'),
          _text(
            'Ordenadas por aporte. Abre una cuenta para ver qué materiales dejan dinero y qué costos absorbe.',
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _text('No hay actividad de empresas para este periodo.'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 26,
              horizontalMargin: 4,
              headingTextStyle: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(color: kDirectionSurfaceText),
              columns: const [
                DataColumn(label: Text('Empresa / planta')),
                DataColumn(label: Text('Volumen (t)'), numeric: true),
                DataColumn(label: Text('Servicios'), numeric: true),
                DataColumn(label: Text('Genera'), numeric: true),
                DataColumn(label: Text('Cuesta'), numeric: true),
                DataColumn(label: Text('Aporte'), numeric: true),
                DataColumn(label: Text('Lectura')),
              ],
              rows: [
                for (final c in rows)
                  DataRow(
                    onSelectChanged: (_) =>
                        _redraw(() => _simpleSelected = c.entity.key),
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text(
                            c.displayName,
                            key: ValueKey('account:${c.entity.key}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_kg(c.account!.kg / 1000))),
                      DataCell(Text(_kg(c.account!.serviceCount))),
                      DataCell(Text(_mxn(c.account!.generated))),
                      DataCell(Text(_mxn(c.account!.costs))),
                      DataCell(
                        Text(
                          _mxn(c.account!.contribution),
                          style: TextStyle(
                            color: _sign(c.account!.contribution),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          c.account!.decision,
                          style: TextStyle(
                            color: _sign(c.account!.contribution),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ]),
        _text(
          'Los importes calculados con tarifas, promedios o repartos son estimaciones de operación. Sus bases se pueden ver y ajustar dentro de cada cuenta.',
        ),
      ],
    );
  }

  Widget _scopeReconciliation() {
    final analysis = _analysis!;
    final outside = analysis.companies
        .where(
          (c) =>
              c.account != null &&
              !(analysis.reportKeys?.contains(c.entity.key) ?? true),
        )
        .toList();
    final retained = analysis.unassignedCosts
        .where((r) => r['block'] != 'inventory')
        .fold<double>(0, (t, r) => t + (profitNumber(r['amount']) ?? 0));
    final inventory = analysis.unassignedCosts
        .where((r) => r['block'] == 'inventory')
        .fold<double>(0, (t, r) => t + (profitNumber(r['amount']) ?? 0));
    final allResult = analysis.companies.fold<double>(
      0,
      (t, c) => t + (c.account?.afterOverhead ?? 0),
    );
    return _card([
      ExpansionTile(
        title: const Text(
          'Alcance y conciliación del reparto',
          style: TextStyle(color: kDirectionSurfaceText),
        ),
        subtitle: Text(
          '${outside.length} actividades fuera del catálogo conservan sus costos',
          style: const TextStyle(color: kDirectionMutedText),
        ),
        children: [
          _text(
            'Compras Mayoreo define las empresas visibles. Se conservan todos los centros de gasto, incluidos VH y Mazatlán. Los costos de otras actividades no se trasladan a estas empresas.',
          ),
          _statementRow(
            'Aporte de otras actividades',
            outside.fold<double>(0, (t, c) => t + c.account!.afterOverhead),
          ),
          _statementRow(
            'Costos sin actividad atribuible',
            retained - analysis.unclassifiedCosts,
          ),
          if (analysis.unclassifiedCosts > 0)
            _statementRow(
              'Importes por conciliar, sin repartir',
              analysis.unclassifiedCosts,
            ),
          _statementRow(
            analysis.unclassifiedCosts > 0
                ? 'Resultado global provisional'
                : 'Resultado de toda la operación modelada',
            allResult - retained,
            emphasized: true,
          ),
          if (inventory > 0)
            _statementRow(
              'Compras de almacén pendientes de consumo',
              inventory,
            ),
          if (analysis.coveredMaterialPurchases.isNotEmpty) ...[
            _statementRow(
              'Facturas de material ya cubiertas por tickets',
              analysis.coveredMaterialPurchases.fold<double>(
                0,
                (t, r) => t + (profitNumber(r['amount']) ?? 0),
              ),
            ),
            for (final row in analysis.coveredMaterialPurchases)
              _text(
                '${_mxn(profitNumber(row['amount']))} · ${row['label']} · ${row['reason']}',
              ),
          ],
          if (analysis.payrollWithholdingSettlements.isNotEmpty) ...[
            _statementRow(
              'Enteros de retenciones: sin costo adicional',
              analysis.payrollWithholdingSettlements.fold<double>(
                0,
                (t, r) => t + (profitNumber(r['amount']) ?? 0),
              ),
            ),
            for (final row in analysis.payrollWithholdingSettlements)
              _text(
                '${_mxn(profitNumber(row['amount']))} · ${row['label']} · ${row['reason']}',
              ),
          ],
          for (final row in analysis.unassignedCosts)
            _text(
              '${_mxn(profitNumber(row['amount']))} · ${row['reason']} · ${row['id']}',
            ),
          if (outside.isNotEmpty)
            _text(
              'Fuera del catálogo: ${outside.map((c) => c.displayName).join(', ')}.',
            ),
        ],
      ),
    ]);
  }

  Widget _historicalReserveNote(Iterable<ProfitCompanyResult> rows) {
    final historical = rows.fold<double>(
      0,
      (t, c) => t + (c.account?.historicalCostEstimate ?? 0),
    );
    if (historical <= 0) return const SizedBox.shrink();
    final contribution = rows.fold<double>(
      0,
      (t, c) => t + (c.account?.contribution ?? 0),
    );
    return _text(
      'El costo ya incluye ${_mxn(historical)} de complemento histórico, descontando el gasto actual comparable. '
      'El aporte antes de esas reservas es ${_mxn(contribution + historical)}. '
      'No son cargos nuevos comprobados en este periodo.',
    );
  }

  Widget _simpleAccount(
    ProfitCompanyResult company,
    List<ProfitCompanyResult> rows,
  ) {
    final a = company.account!;
    final materialLines = a.lines
        .where((l) => l.kg > 0 || l.services > 0 || l.generated > 0)
        .toList();
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            FocusManager.instance.primaryFocus?.context?.widget
                is EditableText) {
          return KeyEventResult.ignored;
        }
        final offset = event.logicalKey == LogicalKeyboardKey.arrowDown
            ? 1
            : event.logicalKey == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
        if (offset == 0) return KeyEventResult.ignored;
        final index = rows.indexOf(company);
        _redraw(
          () => _simpleSelected =
              rows[(index + offset).clamp(0, rows.length - 1)].entity.key,
        );
        return KeyEventResult.handled;
      },
      child: ListView(
        key: ValueKey('account-detail:${company.entity.key}'),
        children: [
          _heading(company.displayName),
          _statementCards(a.generated, a.costs, a.contribution),
          _historicalReserveNote([company]),
          if (a.sharedSupport > 0)
            _card([
              _statementRow(
                'Aporte antes de soporte compartido',
                a.beforeSharedSupport,
              ),
              _statementRow('Soporte compartido asignado', -a.sharedSupport),
              _statementRow(
                'Aporte después del reparto',
                a.contribution,
                emphasized: true,
              ),
              _text(
                'El soporte se reparte entre cuentas atendidas. Un resultado negativo después del reparto no implica que ese costo desaparezca al dejar una empresa.',
              ),
            ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _text('${_kg(a.kg / 1000)} t atendidas'),
              _text('${_kg(a.serviceCount)} servicios'),
              _text('${_kg(a.kilometers)} km atribuidos'),
              _text('Aporte / t: ${_mxn(a.perKg * 1000)}'),
              if (a.serviceCount > 0)
                _text('Costo total / servicio: ${_mxn(a.costPerService)}'),
            ],
          ),
          const SizedBox(height: 16),
          _card([
            _heading('¿Dónde ganamos y dónde perdemos?'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 4,
                columnSpacing: 22,
                headingTextStyle: const TextStyle(
                  color: kDirectionMutedText,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: const TextStyle(color: kDirectionSurfaceText),
                columns: const [
                  DataColumn(label: Text('Material / servicio')),
                  DataColumn(label: Text('Kg'), numeric: true),
                  DataColumn(label: Text('Genera'), numeric: true),
                  DataColumn(label: Text('Costos atribuidos'), numeric: true),
                  DataColumn(label: Text('Aporte'), numeric: true),
                ],
                rows: [
                  for (final l in materialLines)
                    DataRow(
                      cells: [
                        DataCell(Text(l.label)),
                        DataCell(Text(_kg(l.kg))),
                        DataCell(Text(_mxn(l.generated))),
                        DataCell(Text(_mxn(l.costs))),
                        DataCell(
                          Text(
                            _mxn(l.contribution),
                            style: TextStyle(
                              color: _sign(l.contribution),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(),
            for (final l in a.lines.where(
              (l) => !materialLines.contains(l) && l.costs > 0,
            ))
              _statementRow(l.label, -l.costs),
            _statementRow(
              'APORTE DE LA CUENTA',
              a.contribution,
              emphasized: true,
            ),
            if (a.block('overhead') > 0)
              _statementRow('Después de estructura adicional', a.afterOverhead),
          ]),
          _card([
            _heading('Costos de atender esta cuenta'),
            for (final block in profitAccountBlocks.entries.where(
              (e) => !['value', 'income', 'overhead'].contains(e.key),
            ))
              _statementRow(block.value, a.block(block.key)),
            const Divider(),
            _statementRow('TOTAL', a.costs, emphasized: true),
          ]),
          if (materialLines.any((l) => l.contribution < 0))
            _card([
              _heading('Qué habría que recuperar'),
              for (final l in materialLines.where((l) => l.contribution < 0))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _text(
                    '${l.label}: compensación adicional de ${_mxn(-l.contribution)} en el periodo${l.kg > 0 ? ' · ${_mxn(l.additionalPerKg)}/kg' : ''}${l.services > 0 ? ' · o ${_mxn(l.additionalPerService)}/servicio' : ''}.',
                    warning: true,
                  ),
                ),
              _text(
                'Equilibrio de los costos atribuidos a cada línea. El personal y equipo que permanecen como costos de la cuenta se muestran por separado.',
              ),
            ]),
          _card([
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _redraw(() => _showBasis = !_showBasis),
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_showBasis ? 'Ocultar bases' : 'Cómo se calculó'),
                ),
                _action(
                  'Ajustar concepto de esta cuenta',
                  () => _editAccountConcept(company),
                  icon: Icons.tune,
                ),
              ],
            ),
            if (_showBasis) ...[
              const SizedBox(height: 12),
              _text(
                '${_percent(a.inferredShare)} del importe del modelo usa estimaciones. Cada fila distingue registros, repartos y referencias.',
              ),
              ...a.assumptions.map((v) => _text(v)),
              for (final block in profitAccountBlocks.entries)
                ExpansionTile(
                  title: Text(
                    '${block.value} · ${_mxn(a.block(block.key))}',
                    style: const TextStyle(color: kDirectionSurfaceText),
                  ),
                  children: [
                    for (final v
                        in (a.components
                            .where((v) => v.block == block.key)
                            .toList()
                          ..sort((x, y) => y.date.compareTo(x.date))))
                      ListTile(
                        dense: true,
                        title: Text(
                          '${profitDateText(v.date)} · ${v.line} · ${_mxn(v.amount)} · ${_profitTypeLabels[v.sourceType]}',
                          style: const TextStyle(color: kDirectionSurfaceText),
                        ),
                        subtitle: SelectableText(
                          '${v.rule}\n${v.reference}',
                          style: const TextStyle(color: kDirectionMutedText),
                        ),
                      ),
                  ],
                ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _statementRow(
    String label,
    double amount, {
    bool emphasized = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          _mxn(amount),
          style: TextStyle(
            color: emphasized ? _sign(amount) : kDirectionSurfaceText,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  Future<void> _editAccountConcept(
    ProfitCompanyResult company,
  ) => _guard(() async {
    await showIncomeForm(
      context,
      title: 'Concepto · ${company.displayName}',
      description:
          'Ajusta una tarifa o un costo de la cuenta. Se prorratea por calendario y sustituye la inferencia de ese concepto dentro de su vigencia.',
      fields: [
        IncomeFormField(
          'line',
          'Línea / concepto',
          'Toda la cuenta',
          options: {
            'Toda la cuenta': 'Toda la cuenta',
            for (final l in company.account!.lines) l.key: l.label,
          },
        ),
        IncomeFormField(
          'block',
          'Concepto',
          'containers',
          options: {
            for (final e in profitAccountBlocks.entries)
              if (e.key != 'purchase') e.key: e.value,
          },
        ),
        const IncomeFormField(
          'basis',
          'Base',
          'monthly',
          options: {
            'monthly': 'Mensual',
            'annual': 'Anual',
            'service': 'Por servicio',
            'tonne': 'Por tonelada',
            'kg': 'Por kg',
            'once': 'Una vez',
          },
        ),
        const IncomeFormField('rate', 'Importe unitario', null, numeric: true),
        const IncomeFormField(
          'quantity',
          'Cantidad o proporción',
          1,
          numeric: true,
        ),
        IncomeFormField(
          'from',
          'Vigente desde (AAAA-MM-DD)',
          profitDateText(_period.start),
        ),
        const IncomeFormField(
          'to',
          'Hasta (vacío = sin fin)',
          '',
          optional: true,
        ),
        const IncomeFormField('note', 'Base del ajuste', ''),
      ],
      onSave: (v) async {
        final rule = ProfitParameter(
          id: 'account-${DateTime.now().microsecondsSinceEpoch}',
          kind: ProfitParameterKind.account,
          from: _parameterDate(v['from']),
          to: profitText(v['to']).isEmpty ? null : _parameterDate(v['to']),
          note: profitText(v['note']),
          data: {
            'company': company.entity.key,
            'line': v['line'],
            'block': v['block'],
            'basis': v['basis'],
            'rate': v['rate'],
            'quantity': v['quantity'],
          },
        );
        await _saveMasterRules(
          replaceProfitAccountConcept(_analysis!.master, rule),
        );
      },
    );
  });
}
