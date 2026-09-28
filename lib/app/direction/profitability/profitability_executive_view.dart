part of 'profitability_view.dart';

const _profitBlockLabels = {
  'containers': 'Contenedores',
  'administration': 'Nómina y soporte compartidos',
  'training': 'Capacitaciones',
  'disposal': 'Relleno sanitario',
  'scale': 'Báscula externa',
  'value': 'Material recuperable',
  'income': 'Ingresos por servicios',
  'purchase': 'Compra de material',
  'fuel': 'Combustible',
  'transport': 'Transporte',
  'payroll': 'Personal',
  'process': 'Proceso',
  'maintenance': 'Mantenimiento',
  'other': 'Otros directos',
  'overhead': 'Estructura',
};
const _profitTypeLabels = {
  ProfitSourceType.actual: 'Real',
  ProfitSourceType.allocated: 'Asignado',
  ProfitSourceType.estimated: 'Estimado',
  ProfitSourceType.missing: 'Faltante',
};
ProfitPeriod _presetPeriod(int index) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ProfitPeriod(switch (index) {
    0 => today,
    1 => today.subtract(Duration(days: today.weekday - 1)),
    _ => DateTime(today.year, today.month),
  }, today);
}

DateTime _parameterDate(Object? value) {
  final text = profitText(value), day = profitDate(value);
  if (day == null || profitDateText(day) != text) {
    throw StateError('Usa una fecha válida AAAA-MM-DD.');
  }
  return day;
}

/// Dashboard: GeneralDashboard cards and semantic Dirección tokens.
/// Tabs: Almacén. Company drill-down: navigable Mantenimiento master/detail.
/// All five tabs share the original repository, refresh guard and analysis.
extension _ProfitExecutive on _ProfitabilityViewState {
  String _groupNumber(double v, int digits) {
    final parts = v.abs().toStringAsFixed(digits).split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '${v < 0 ? '-' : ''}$integer${digits == 0 ? '' : '.${parts.last}'}';
  }

  String _mxn(double? v) =>
      v == null ? 'Sin cuantificar' : '\$${_groupNumber(v, 2)}';
  String _percent(double? v) =>
      v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
  String _kg(double v) => _groupNumber(v, 1);
  Color _sign(double? v) => v == null
      ? kDirectionMutedText
      : v < 0
      ? kDirectionDanger
      : kDirectionSuccess;
  ProfitOperatingResult get _totalOperating => ProfitOperatingResult([
    for (final c in _analysis!.reportCompanies) ...?c.operating?.components,
  ]);
  Widget _executiveNavigation() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<int>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? directionAreaTokens.primary.withValues(alpha: .18)
              : directionAreaTokens.glassSurface,
        ),
        foregroundColor: WidgetStatePropertyAll(directionAreaTokens.onGlass),
      ),
      segments: const [
        ButtonSegment(value: 0, label: Text('Resumen')),
        ButtonSegment(value: 1, label: Text('Empresas')),
        ButtonSegment(value: 2, label: Text('Tendencias')),
        ButtonSegment(value: 3, label: Text('Parámetros')),
        ButtonSegment(value: 4, label: Text('Auditoría y conciliación')),
      ],
      selected: {_executiveTab},
      onSelectionChanged: _busy
          ? null
          : (v) => _redraw(() => _executiveTab = v.single),
    ),
  );
  List<Widget> _periodPresets() => [
    for (final entry in [(0, 'Hoy'), (1, 'Esta semana'), (2, 'Este mes')])
      ChoiceChip(
        label: Text(entry.$2),
        backgroundColor: directionAreaTokens.glassSurface,
        selectedColor: directionAreaTokens.primary.withValues(alpha: .18),
        labelStyle: TextStyle(color: directionAreaTokens.onGlass),
        selected:
            _preset == entry.$1 && _period.key == _presetPeriod(entry.$1).key,
        onSelected: _busy
            ? null
            : (_) {
                _preset = entry.$1;
                unawaited(_change(_presetPeriod(entry.$1)));
              },
      ),
    OutlinedButton(
      onPressed: _busy ? null : _pickPeriod,
      child: const Text('Personalizado'),
    ),
  ];
  Widget _executiveContent() => switch (_executiveTab) {
    0 => _executiveSummary(),
    1 => _executiveCompanies(),
    2 => _executiveTrends(),
    _ => _parameters(),
  };
  Widget _kpi(String label, String value, String detail, {double? sign}) =>
      ContractGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: kDirectionMutedText, fontSize: 13),
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: TextStyle(
                color: sign == null ? kDirectionSurfaceText : _sign(sign),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _text(detail),
          ],
        ),
      );
  Widget _executiveSummary() {
    final total = _totalOperating;
    final rows = _rankedCompanies;
    final valued = rows.where((c) => c.operating?.contribution != null).length;
    final costs = total.costs;
    final sourceWarning = _analysis!.issues
        .where((v) => !v.startsWith('Nómina cerrada cubre'))
        .toList();
    return ListView(
      children: [
        _heading('¿Cuánto aporta cada empresa?'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _kpi(
                    'Aporte operativo',
                    _mxn(total.contribution),
                    total.partial
                        ? 'Parcial · $valued de ${rows.length} plantas con valor cuantificado'
                        : 'Estimación del periodo',
                    sign: total.contribution,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _kpi(
                    'Valor recuperable + ingresos',
                    total.hasValue ? _mxn(total.value) : 'Sin cuantificar',
                    'Material estimado + servicios registrados',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _kpi(
                    'Costos operativos',
                    _mxn(costs),
                    total.partial
                        ? 'Importe conocido · hay costos sin cuantificar'
                        : 'Compra + atención directa',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _kpi(
                    'Margen operativo',
                    _percent(total.margin),
                    total.partial
                        ? 'Sobre el valor conocido · parcial'
                        : 'Aporte / valor generado',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _text(
          'Después de estructura: ${_mxn(total.afterOverhead)}${total.partial ? ' · parcial' : ''}',
        ),
        const SizedBox(height: 16),
        _card([
          _heading('Aporte operativo por empresa'),
          _text(
            'De mayor a menor. Los resultados parciales requieren leer los faltantes antes de decidir.',
          ),
          const SizedBox(height: 12),
          if (rows.every((c) => c.operating?.contribution == null))
            _text(
              'Todavía falta configurar rendimientos comparables para valorar el material. Las compras y costos conocidos ya están disponibles en Empresas.',
              warning: true,
            ),
          ..._companyBars(
            rows.where((c) => c.operating?.contribution != null).toList(),
          ),
        ]),
        if (sourceWarning.isNotEmpty)
          _card([
            _heading('Observaciones de fuentes'),
            ...sourceWarning.take(3).map((v) => _text(v, warning: true)),
            TextButton(
              onPressed: () => _redraw(() {
                _executiveTab = 4;
                _tab = 3;
              }),
              child: const Text('Ver evidencia y cobertura'),
            ),
          ]),
        _materialAlerts(),
        _executiveTable(rows),
      ],
    );
  }

  List<ProfitCompanyResult> get _rankedCompanies {
    final rows = _analysis!.reportCompanies
        .where(
          (c) => profitKey(
            '${c.displayName} ${c.operating?.group ?? ''}',
          ).contains(profitKey(_search.text)),
        )
        .toList();
    double? value(ProfitCompanyResult c) => switch (_sort) {
      1 =>
        c.kg > 0 && c.operating?.contribution != null
            ? c.operating!.contribution! / c.kg
            : null,
      2 => c.operating?.margin,
      3 => c.kg,
      4 => c.operating?.confidence,
      _ => c.operating?.contribution,
    };
    rows.sort((x, y) {
      final a = value(x), b = value(y);
      if (a == null && b != null) return 1;
      if (b == null && a != null) return -1;
      final cmp = a == null
          ? 0
          : (_ascending ? a.compareTo(b!) : b!.compareTo(a));
      return cmp != 0 ? cmp : x.entity.name.compareTo(y.entity.name);
    });
    return rows;
  }

  List<Widget> _companyBars(List<ProfitCompanyResult> source) {
    final rows = [...source]
      ..sort(
        (x, y) =>
            y.operating!.contribution!.compareTo(x.operating!.contribution!),
      );
    final maxValue = rows.fold<double>(
      1,
      (v, c) => math.max(v, c.operating!.contribution!.abs()),
    );
    return [
      for (final c in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => _redraw(() {
              _executiveTab = 1;
              _executiveSelected = c.entity.key;
            }),
            child: LayoutBuilder(
              builder: (context, limits) {
                final value = c.operating!.contribution!,
                    half = math.max(
                      16.0,
                      (limits.maxWidth - (limits.maxWidth < 600 ? 240 : 370)) /
                          2,
                    );
                final barWidth = math.max(2.0, half * value.abs() / maxValue);
                return Row(
                  children: [
                    SizedBox(
                      width: limits.maxWidth < 600 ? 120 : 220,
                      child: Text(
                        c.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kDirectionSurfaceText),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 16,
                          width: value < 0 ? barWidth : 0,
                          color: kDirectionDanger,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: directionAreaTokens.border,
                    ),
                    SizedBox(
                      width: half,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 16,
                          width: value >= 0 ? barWidth : 0,
                          color: kDirectionSuccess,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_mxn(value)}${c.operating!.partial ? ' *' : ''}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _sign(value),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
    ];
  }

  Widget _materialAlerts() {
    final candidates =
        _analysis!.costFacts
            .where((c) => _analysis!.pendingCosts.containsKey(c.key))
            .toList()
          ..sort((x, y) => y.amount.compareTo(x.amount));
    final threshold = math.max(1000.0, _totalOperating.costs * .02);
    final material = candidates
        .where((c) => c.amount >= threshold)
        .take(5)
        .toList();
    return _card([
      _heading('Prioridades de revisión'),
      _text(
        'Primero los documentos de mayor importe (≥ 2% de costos conocidos, mínimo \$1,000). Son evidencia potencialmente superpuesta, no gastos adicionales.',
      ),
      if (material.isEmpty) _text('No hay candidatos que superen este umbral.'),
      for (final c in material)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            c.label,
            style: const TextStyle(color: kDirectionSurfaceText),
          ),
          subtitle: Text(
            c.source,
            style: const TextStyle(color: kDirectionMutedText),
          ),
          trailing: Text(
            _mxn(c.amount),
            style: const TextStyle(color: kDirectionWarning),
          ),
          onTap: _enabled ? () => _cost(c) : null,
        ),
      TextButton(
        onPressed: () => _redraw(() {
          _executiveTab = 4;
          _tab = 1;
        }),
        child: const Text('Abrir conciliación completa'),
      ),
    ]);
  }

  Widget _executiveTable(List<ProfitCompanyResult> rows) => _card([
    _heading('Empresas / plantas'),
    _text(
      '* Resultado parcial. Confianza combina procedencia del importe conocido y cobertura de bloques.',
    ),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        horizontalMargin: 4,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 60,
        headingTextStyle: const TextStyle(
          color: kDirectionMutedText,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: const TextStyle(
          color: kDirectionSurfaceText,
          fontSize: 13,
        ),
        columns: [
          const DataColumn(label: Text('Empresa / planta')),
          const DataColumn(label: Text('Material principal')),
          DataColumn(
            label: const Text('Kg'),
            numeric: true,
            onSort: (_, asc) => _redraw(() {
              _sort = 3;
              _ascending = asc;
            }),
          ),
          const DataColumn(label: Text('Compra'), numeric: true),
          const DataColumn(label: Text('Valor'), numeric: true),
          const DataColumn(label: Text('Operación'), numeric: true),
          DataColumn(
            label: const Text('Aporte operativo'),
            numeric: true,
            onSort: (_, asc) => _redraw(() {
              _sort = 0;
              _ascending = asc;
            }),
          ),
          DataColumn(
            label: const Text('\$/kg'),
            numeric: true,
            onSort: (_, asc) => _redraw(() {
              _sort = 1;
              _ascending = asc;
            }),
          ),
          DataColumn(
            label: const Text('Margen'),
            numeric: true,
            onSort: (_, asc) => _redraw(() {
              _sort = 2;
              _ascending = asc;
            }),
          ),
          DataColumn(
            label: const Text('Confianza'),
            numeric: true,
            onSort: (_, asc) => _redraw(() {
              _sort = 4;
              _ascending = asc;
            }),
          ),
        ],
        sortColumnIndex: const {0: 6, 1: 7, 2: 8, 3: 2, 4: 9}[_sort],
        sortAscending: _ascending,
        rows: [
          for (final c in rows)
            DataRow(
              key: ValueKey('executive-row:${c.entity.key}'),
              onSelectChanged: (_) => _redraw(() {
                _executiveTab = 1;
                _executiveSelected = c.entity.key;
              }),
              cells: [
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      c.displayName,
                      key: ValueKey('executive:${c.entity.key}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Text(
                      (([...c.materials]..sort(
                                (x, y) => y.physicalKg.compareTo(x.physicalKg),
                              ))
                              .firstOrNull
                              ?.material) ??
                          'Servicios',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(_kg(c.kg))),
                DataCell(Text(_mxn(c.operating?.total('purchase')))),
                DataCell(Text(_mxn(c.operating?.total('value')))),
                DataCell(Text(_mxn(c.operating?.operations))),
                DataCell(
                  Text(
                    '${_mxn(c.operating?.contribution)}${c.operating?.partial == true ? ' *' : ''}',
                    style: TextStyle(
                      color: _sign(c.operating?.contribution),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _mxn(
                      c.kg > 0 && c.operating?.contribution != null
                          ? c.operating!.contribution! / c.kg
                          : null,
                    ),
                  ),
                ),
                DataCell(Text(_percent(c.operating?.margin))),
                DataCell(Text(_percent(c.operating?.confidence))),
              ],
            ),
        ],
        showCheckboxColumn: false,
      ),
    ),
  ]);
  Widget _executiveCompanies() {
    final selected = _analysis!.reportCompanies
        .where((c) => c.entity.key == _executiveSelected)
        .firstOrNull;
    final rows = _rankedCompanies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Buscar empresa o grupo',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => _redraw(() {}),
              ),
            ),
            if (selected != null)
              TextButton.icon(
                onPressed: () => _redraw(() => _executiveSelected = null),
                icon: const Icon(Icons.table_rows_outlined),
                label: const Text('Todas las empresas'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: selected == null
              ? ListView(children: [_executiveTable(rows)])
              : Focus(
                  autofocus: true,
                  onKeyEvent: (_, e) {
                    if (e is! KeyDownEvent ||
                        FocusManager.instance.primaryFocus?.context?.widget
                            is EditableText) {
                      return KeyEventResult.ignored;
                    }
                    final delta = e.logicalKey == LogicalKeyboardKey.arrowDown
                        ? 1
                        : e.logicalKey == LogicalKeyboardKey.arrowUp
                        ? -1
                        : 0;
                    if (delta == 0 || rows.isEmpty) {
                      return KeyEventResult.ignored;
                    }
                    final index = rows.indexWhere(
                      (c) => c.entity.key == selected.entity.key,
                    );
                    _redraw(
                      () => _executiveSelected =
                          rows[(index + delta).clamp(0, rows.length - 1)]
                              .entity
                              .key,
                    );
                    return KeyEventResult.handled;
                  },
                  child: ListView(
                    key: ValueKey('detail:${selected.entity.key}'),
                    children: _executiveDetail(selected),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _executiveDetail(ProfitCompanyResult c) {
    final o = c.operating!;
    Widget line(
      String label,
      double? amount, {
      bool pending = false,
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
            '${_mxn(amount)}${pending && amount != null ? ' + faltantes' : ''}',
            style: TextStyle(
              color: emphasized ? _sign(amount) : kDirectionSurfaceText,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
    return [
      _card([
        _heading('${c.displayName}${o.group.isEmpty ? '' : ' · ${o.group}'}'),
        _text(
          '${_kg(c.kg)} kg físicos · ${c.services} servicios · ${o.partial ? 'Cálculo parcial' : 'Cálculo con cobertura'}',
        ),
        const SizedBox(height: 16),
        _heading('Valor generado'),
        line(
          'Material recuperable',
          o.total('value'),
          pending: o.missing('value'),
        ),
        line(
          'Ingresos por servicios',
          o.total('income'),
          pending: o.missing('income'),
        ),
        line('Total conocido', o.hasValue ? o.value : null),
        const Divider(),
        _heading('Costos'),
        for (final block in ProfitOperatingResult.costBlocks)
          line(
            _profitBlockLabels[block]!,
            o.total(block),
            pending: o.missing(block),
          ),
        line('Total costos conocidos', o.costs),
        const Divider(),
        line(
          'APORTE OPERATIVO${o.partial ? ' · PARCIAL' : ''}',
          o.contribution,
          emphasized: true,
        ),
        line(
          'Aporte por kg',
          c.kg > 0 && o.contribution != null ? o.contribution! / c.kg : null,
        ),
        _text('Margen: ${_percent(o.margin)}'),
        const Divider(),
        line(
          'Estructura asignada',
          o.total('overhead'),
          pending: o.missing('overhead'),
        ),
        line('Resultado después de estructura', o.afterOverhead),
        if (o.partial)
          _text(
            'Los faltantes no son cero. El aporte mostrado solo resta costos cuantificados; puede cambiar al completar la información.',
            warning: true,
          ),
      ]),
      _card([
        _heading('Calidad y cobertura'),
        _text(
          'Índice de confianza: ${_percent(o.confidence)} · Cobertura por bloques: ${_percent(o.blockCoverage)}',
        ),
        _text(
          'Del importe conocido, ${_percent(o.verifiedShare)} proviene de datos reales o repartidos. Los importes desconocidos no entran en este denominador.',
        ),
        for (final type in ProfitSourceType.values.where(
          (v) => v != ProfitSourceType.missing,
        ))
          line(_profitTypeLabels[type]!, o.amountOf(type)),
        _text(
          'Faltante: ${o.components.where((v) => v.amount == null).map((v) => _profitBlockLabels[v.block] ?? v.block).toSet().join(', ')}${o.partial ? ' · importe no cuantificable' : 'ninguno'}',
          warning: o.partial,
        ),
        _text(
          'Índice = promedio por importe (real 100%, asignado 85%, estimado 60%) × cobertura de bloques. Es una regla de calidad, no una probabilidad estadística.',
        ),
        ...o.alerts.map((v) => _text(v, warning: true)),
      ]),
      _card([
        _heading('Origen de cada importe'),
        for (final block in o.blocks)
          ExpansionTile(
            title: Text(
              _profitBlockLabels[block] ?? block,
              style: const TextStyle(color: kDirectionSurfaceText),
            ),
            subtitle: Text(
              '${_mxn(o.total(block))}${o.missing(block) ? ' · incompleto' : ''}',
              style: const TextStyle(color: kDirectionMutedText),
            ),
            children: [
              for (final v in o.inBlock(block))
                ListTile(
                  dense: true,
                  title: Text(
                    '${profitDateText(v.date)} · ${_mxn(v.amount)} · ${_profitTypeLabels[v.sourceType]}',
                    style: const TextStyle(color: kDirectionSurfaceText),
                  ),
                  subtitle: SelectableText(
                    '${v.rule}\n${v.reference}',
                    style: const TextStyle(color: kDirectionMutedText),
                  ),
                ),
            ],
          ),
        TextButton(
          onPressed: () => _redraw(() {
            _selected = c.entity.key;
            _executiveTab = 4;
            _tab = 0;
          }),
          child: const Text('Abrir rendimientos, comprobantes y evidencia'),
        ),
      ]),
    ];
  }

  Widget _executiveTrends() {
    final groups = <String, List<ProfitComponent>>{};
    for (final v in _totalOperating.components) {
      final day = _period.days <= 45
          ? v.date
          : v.date.subtract(Duration(days: v.date.weekday - 1));
      (groups[profitDateText(day)] ??= []).add(v);
    }
    final keys = groups.keys.toList()..sort();
    return ListView(
      children: [
        _card([
          _heading('Tendencia del aporte operativo'),
          _text(
            '${_period.days <= 45 ? 'Por día' : 'Por semana (lunes)'} dentro del corte. Usa las mismas compras, costos, vigencias y referencias de venta del resumen; no recalcula precios diferentes por punto.',
          ),
          if (keys.isEmpty) _text('Sin actividad en el periodo.'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Valor conocido'), numeric: true),
                DataColumn(label: Text('Costos conocidos'), numeric: true),
                DataColumn(label: Text('Aporte'), numeric: true),
                DataColumn(label: Text('Cobertura'), numeric: true),
              ],
              rows: [
                for (final key in keys)
                  _trendRow(key, ProfitOperatingResult(groups[key]!)),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  DataRow _trendRow(String date, ProfitOperatingResult o) => DataRow(
    cells: [
      DataCell(Text(date)),
      DataCell(Text(_mxn(o.hasValue ? o.value : null))),
      DataCell(Text(_mxn(o.costs))),
      DataCell(
        Text(
          '${_mxn(o.contribution)}${o.partial ? ' *' : ''}',
          style: TextStyle(color: _sign(o.contribution)),
        ),
      ),
      DataCell(Text(_percent(o.blockCoverage))),
    ],
  );

  Widget _parameters() {
    final master = _analysis!.master;
    final rules = [...master.rules]
      ..sort((x, y) {
        final date = y.from.compareTo(x.from);
        return date == 0 ? x.scope.compareTo(y.scope) : date;
      });
    return ListView(
      children: [
        _card([
          _heading('Parámetros de rentabilidad · revisión ${master.revision}'),
          _text(
            'Vigencias compartidas entre periodos. No hay tarifas de ejemplo precargadas. Una celda vacía conserva el costo como desconocido; cero requiere una base explícita.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ProfitParameterKind.values)
                _action(
                  'Agregar ${kind.label.toLowerCase()}',
                  () => _editParameter(kind),
                  icon: Icons.add,
                ),
            ],
          ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _text(
                'Empieza por las empresas / plantas y los rendimientos de sus materiales; después configura los costos estándar.',
              ),
            ),
          for (final r in rules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${r.kind.label} · ${_parameterLabel(r)}',
                style: const TextStyle(color: kDirectionSurfaceText),
              ),
              subtitle: Text(
                '${profitDateText(r.from)} → ${r.to == null ? 'sin fin' : profitDateText(r.to!)} · ${r.note}',
                style: const TextStyle(color: kDirectionMutedText),
              ),
              trailing: IconButton(
                tooltip: 'Editar parámetro y vigencia',
                onPressed: _enabled
                    ? () => _editParameter(r.kind, old: r)
                    : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
        ]),
      ],
    );
  }

  String _parameterLabel(ProfitParameter r) {
    String entity(String key) =>
        _analysis!.entities.where((e) => e.key == key).firstOrNull?.name ?? key;
    return switch (r.kind) {
      ProfitParameterKind.identity =>
        '${entity(r.text('site'))} / ${r.text('company_group')}',
      ProfitParameterKind.vehicle => r.text('unit'),
      _ =>
        '${entity(r.company)} · ${r.text('role')}${r.text('material')}${r.text('process')}${r.text('subject')}${_profitBlockLabels[r.text('block')] ?? ''}',
    };
  }

  Future<void> _saveMasterRules(List<ProfitParameter> rules) async {
    final a = _analysis!;
    final next = ProfitMaster(revision: a.master.revision, rules: rules);
    next.validate();
    analyzeProfitability(
      a.sources,
      a.review,
      master: next,
      inferOperations: true,
    );
    final saved = await _repo.saveMaster(next);
    if (mounted) {
      _redraw(
        () => _analysis = analyzeProfitability(
          a.sources,
          a.review,
          master: saved,
        ),
      );
    }
  }

  Future<void> _editParameter(
    ProfitParameterKind kind, {
    ProfitParameter? old,
  }) => _guard(() async {
    final a = _analysis!;
    final data = old?.data ?? <String, dynamic>{};
    final companyOptions = _entityOptions;
    final materials = <String, String>{
      for (final c in a.reportCompanies)
        for (final m in c.materials)
          for (final p in m.purchases)
            p.materialKey: '${m.material} · ${p.source}',
      for (final r in a.sources.rows('compras_material_catalog'))
        'compras:${r['id']}': '${r['name']} · Compras',
    };
    Map<String, String> catalog(String name, String prefix) => {
      '': 'Sin vínculo',
      for (final r in a.sources.rows(name))
        profitText(r['id']): '${r['name']} · $prefix',
    };
    IncomeFormField field(
      String key,
      String label, {
      bool number = false,
      bool optional = false,
      Map<String, String>? options,
      Object? initial,
    }) => IncomeFormField(
      key,
      label,
      data[key] ?? initial,
      numeric: number,
      optional: optional,
      options: options,
    );
    final fields = <IncomeFormField>[
      IncomeFormField(
        'valid_from',
        'Vigente desde (AAAA-MM-DD)',
        old == null ? profitDateText(_period.start) : profitDateText(old.from),
      ),
      IncomeFormField(
        'valid_to',
        kind == ProfitParameterKind.activity
            ? 'Mismo día (AAAA-MM-DD)'
            : 'Vigente hasta (vacío = sin fin)',
        old?.to == null
            ? (kind == ProfitParameterKind.activity
                  ? profitDateText(_period.start)
                  : '')
            : profitDateText(old!.to!),
        optional: kind != ProfitParameterKind.activity,
      ),
    ];
    if (kind != ProfitParameterKind.identity &&
        kind != ProfitParameterKind.vehicle) {
      fields.add(
        field(
          'company',
          'Empresa / planta',
          options: companyOptions,
          initial: '',
        ),
      );
    }
    switch (kind) {
      case ProfitParameterKind.identity:
        fields.addAll([
          field('company_group', 'Grupo comercial'),
          field(
            'site',
            'Planta (se conserva separada del grupo)',
            options: {
              for (final e in a.entities.where(
                (e) => e.key.startsWith('site:'),
              ))
                e.key: e.name,
            },
            initial: '',
          ),
          field(
            'compras_supplier_id',
            'Proveedor Compras',
            options: catalog('compras_counterparties', 'Compras'),
            initial: '',
          ),
          field(
            'mayoreo_customer_id',
            'Cliente Mayoreo',
            options: catalog('mayoreo_counterparties', 'Mayoreo'),
            initial: '',
          ),
          field(
            'menudeo_counterparty_id',
            'Contraparte Menudeo',
            options: catalog('men_counterparties', 'Menudeo'),
            initial: '',
          ),
          field(
            'hr_company_identifier',
            'Empresa histórica de RH',
            options: {
              '': 'Sin vínculo',
              for (final e in a.entities.where(
                (e) => e.key.startsWith('payroll:'),
              ))
                e.key.substring(8): e.name,
            },
            initial: '',
          ),
          field(
            'aliases',
            'Alias aprobados en gastos / pesadas (separados por ;)',
            optional: true,
            initial: '',
          ),
        ]);
      case ProfitParameterKind.vehicle:
        fields.add(
          field(
            'unit',
            'Unidad o tipo',
            options: {
              for (final r in a.sources.rows('logistics_vehicle_profiles'))
                'vehicle:${r['vehicle_id']}': '${r['vehicle_code']} · Unidad',
              for (final type in [
                'CAMIONETA',
                'CAMION',
                'PICK_UP',
                'GRUA',
                'TRAILER',
              ])
                'type:$type': '$type · Tipo',
            },
            initial: '',
          ),
        );
        for (final entry in [
          ('fuel_cost_per_km', 'Combustible / km'),
          ('maintenance_cost_per_km', 'Mantenimiento / km'),
          (
            'fixed_cost_per_service',
            'Fijo de transporte / servicio (sin combustible ni mantenimiento)',
          ),
          ('optional_cost_per_hour', 'Transporte / hora (opcional)'),
          ('hours_per_service', 'Horas estándar / servicio (opcional)'),
        ]) {
          fields.add(field(entry.$1, entry.$2, number: true, optional: true));
        }
      case ProfitParameterKind.labor:
        fields.addAll([
          field(
            'role',
            'Puesto',
            options: {
              for (final v in [
                'CHOFER',
                'OPERADOR',
                'AYUDANTE',
                'MONTACARGUISTA',
                'CLASIFICADOR',
              ])
                v: v,
            },
            initial: '',
          ),
          field(
            'basis',
            'Base',
            options: {
              'hour': 'Horas atribuibles',
              'day': 'Personal dedicado por día',
              'dedicated': 'Costo laboral del periodo / días laborables',
            },
            initial: 'hour',
          ),
          field(
            'labor_cost_per_hour',
            'Costo laboral / hora',
            number: true,
            optional: true,
          ),
          field(
            'labor_cost_per_day',
            'Costo laboral / día',
            number: true,
            optional: true,
          ),
          field(
            'period_labor_cost',
            'Costo laboral por persona del periodo de referencia',
            number: true,
            optional: true,
          ),
          field(
            'working_days',
            'Días laborables del periodo de referencia',
            number: true,
            optional: true,
          ),
          field('workers', 'Personas dedicadas', number: true, optional: true),
          field(
            'week_days',
            'Calendario dedicado',
            options: {
              '5': 'Lunes a viernes',
              '6': 'Lunes a sábado',
              '7': 'Todos los días',
            },
            initial: '5',
          ),
          field(
            'hours_per_service',
            'Horas estándar por servicio (si no hay actividad atribuida)',
            number: true,
            optional: true,
          ),
        ]);
      case ProfitParameterKind.process:
        fields.addAll([
          field(
            'material',
            'Material de entrada',
            options: materials,
            initial: '',
          ),
          field(
            'process',
            'Proceso',
            options: {
              for (final v in [
                'RECEPCION',
                'CLASIFICACION',
                'COMPACTADO',
                'MANIOBRA',
                'TRANSFORMACION',
                'CARGA',
              ])
                v: v,
            },
            initial: '',
          ),
          field('cost_per_kg', 'Costo estándar / kg', number: true),
          field(
            'kg_basis',
            'Base física',
            options: {
              'activity': 'Kg procesados registrados en actividad',
              'received': 'Kg recibidos como aproximación aprobada',
            },
            initial: 'activity',
          ),
        ]);
      case ProfitParameterKind.recovery:
        fields.add(
          field(
            'material',
            'Material de entrada',
            options: materials,
            initial: '',
          ),
        );
      case ProfitParameterKind.activity:
        fields.addAll([
          field(
            'measure',
            'Medida',
            options: {'hours': 'Horas de personal', 'kg': 'Kg procesados'},
            initial: 'hours',
          ),
          field(
            'subject',
            'Puesto o material',
            options: {
              ...materials,
              for (final v in [
                'CHOFER',
                'OPERADOR',
                'AYUDANTE',
                'MONTACARGUISTA',
                'CLASIFICADOR',
              ])
                v: v,
            },
            initial: '',
          ),
          field('quantity', 'Cantidad atribuible al día', number: true),
        ]);
      case ProfitParameterKind.account:
        fields.addAll([
          field('line', 'Línea o concepto', initial: 'Toda la cuenta'),
          field(
            'block',
            'Rubro',
            options: profitAccountBlocks,
            initial: 'other',
          ),
          field(
            'basis',
            'Periodicidad / base',
            options: {
              'monthly': 'Mensual',
              'annual': 'Anual',
              'service': 'Por servicio',
              'tonne': 'Por tonelada',
              'kg': 'Por kg',
              'once': 'Una vez',
            },
            initial: 'monthly',
          ),
          field('rate', 'Importe unitario', number: true),
          field(
            'quantity',
            'Cantidad / participación',
            number: true,
            initial: 1,
          ),
        ]);
      case ProfitParameterKind.coverage:
        fields.add(
          field(
            'block',
            'Bloque declarado sin importe aplicable',
            options: {
              for (final e in _profitBlockLabels.entries.where(
                (e) => !['value', 'purchase'].contains(e.key),
              ))
                e.key: e.value,
            },
            initial: '',
          ),
        );
    }
    fields.add(
      IncomeFormField(
        'note',
        'Fundamento / referencia (obligatorio)',
        old?.note ?? '',
      ),
    );
    Map<String, dynamic>? draft;
    Future<void> save(
      Map<String, dynamic> values, {
      Map<String, double>? outputs,
      String? note,
    }) async {
      final start = _parameterDate(values['valid_from']);
      final end = profitText(values['valid_to']).isEmpty
          ? null
          : _parameterDate(values['valid_to']);
      final payload = <String, dynamic>{
        for (final e in values.entries.where(
          (e) => !['valid_from', 'valid_to', 'note'].contains(e.key),
        ))
          e.key: e.value,
      };
      if (outputs != null) {
        payload['outputs'] = [
          for (final e in outputs.entries)
            ProfitOutputRule(e.key, e.value).toJson(),
        ];
        payload['note'] = note;
      }
      final rule = ProfitParameter(
        id: old?.id ?? 'rule-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        from: start,
        to: end,
        note: note ?? profitText(values['note']),
        data: payload,
      );
      await _saveMasterRules([
        for (final r in a.master.rules)
          if (r.id != old?.id) r,
        rule,
      ]);
    }

    final accepted = await showIncomeForm(
      context,
      title: kind.label,
      description: kind == ProfitParameterKind.identity
          ? 'Aprueba solo equivalencias de la misma planta. MONROE y MONROE SUR conservan sitios distintos aunque compartan grupo.'
          : 'Los costos estándar son estimaciones con vigencia; un costo conciliado los sustituye en las fechas y conceptos cubiertos.',
      fields: fields,
      onSave: (v) async {
        _parameterDate(v['valid_from']);
        if (profitText(v['valid_to']).isNotEmpty) _parameterDate(v['valid_to']);
        if (kind == ProfitParameterKind.recovery) {
          draft = Map.of(v);
        } else {
          await save(v);
        }
      },
    );
    if (accepted == true && draft != null && mounted) {
      await showProfitDistribution(
        context,
        title: 'Rendimiento recuperable',
        description:
            'Define salidas comparables. Se usa venta ponderada del corte, o hasta 90 días previos si no hay ventas en el corte.',
        options: {
          for (final b in a.benchmarks.values)
            b.key:
                '${b.material} · ${b.source} · ${_mxn(b.price)}/kg · ${_kg(b.kg)} kg',
        },
        values: {
          for (final o
              in old == null
                  ? <ProfitOutputRule>[]
                  : ProfitRecipe.fromJson(old.data).outputs)
            o.benchmark: o.yieldFraction,
        },
        note: profitText(draft!['note']),
        complete: false,
        onSave: (values, note) => save(draft!, outputs: values, note: note),
      );
    }
  });
}
