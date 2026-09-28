part of 'profitability_view.dart';

/// Hybrid tabs: same Almacén navigation as the existing executive workspace.
/// Dashboard cards and read-only master/detail reuse Dirección's current UI.
/// Scenario forms reuse the shared picker, Enter/Esc and refresh guard.
extension _ProfitConsolidatedView on _ProfitabilityViewState {
  void _selectDecision(String key) {
    _redraw(() {
      _consolidatedSelected = key;
      _decisionPlan = ProfitDecisionPlan();
    });
    if (_consolidatedScroll.hasClients) _consolidatedScroll.jumpTo(0);
  }

  Widget _consolidatedView() {
    // Search only filters the company tab. A decision always includes all DICSA.
    final total = ProfitConsolidated(_analysis!.reportCompanies);
    final priorities = total.priorities;
    final selected =
        total.companies
            .where((c) => c.entity.key == _consolidatedSelected)
            .firstOrNull ??
        priorities.firstOrNull?.company;
    final actionable = priorities.where((p) => p.priority == 1).length;
    final supported = priorities.where((p) => p.priority == 2).length;
    return ListView(
      key: const ValueKey('profit-consolidated'),
      controller: _consolidatedScroll,
      children: [
        _heading('Consolidado Compras Mayoreo'),
        _text(
          '${total.companies.length} empresas · ${_period.label} · Empresas del catálogo, sin el filtro de búsqueda.',
        ),
        const SizedBox(height: 10),
        _statementCards(total.generated, total.costs, total.result),
        _historicalReserveNote(total.companies),
        _scopeReconciliation(),
        if (total.overhead > 0)
          _text(
            'Incluye ${_mxn(total.overhead)} de estructura adicional, además del aporte operativo de las empresas.',
          ),
        _text(
          'Valor recuperable estimado + ingresos por servicios. Comparación para un periodo de ${_period.days} días con la actividad seleccionada; no es flujo de efectivo ni pronóstico de demanda.',
        ),
        const SizedBox(height: 12),
        _card([
          _heading('Dónde conviene actuar'),
          _text(
            '$actionable cuentas generan menos que los costos que se supone dejarían de consumirse: revisar precios, rutas y una posible salida.',
          ),
          const SizedBox(height: 6),
          _text(
            '$supported cuentas están en pérdida después del reparto, pero cubren los costos que se supone ahorraríamos al salir. Dejarlas puede empeorar el total.',
          ),
          if (priorities.any((p) => p.priority == 0)) ...[
            const SizedBox(height: 6),
            _text(
              '${priorities.where((p) => p.priority == 0).length} cuentas sin ingreso atribuido: validar sus bases antes de decidir.',
              warning: true,
            ),
          ],
        ]),
        if (selected != null) _decisionSimulator(total, selected),
        _card([
          _heading('Prioridades por empresa'),
          _text(
            'Ordenadas por ingreso sin atribuir, posible mejora al salir y déficit. La columna de salida usa los supuestos iniciales; abre una empresa para ajustarlos.',
          ),
          const SizedBox(height: 8),
          if (priorities.isEmpty)
            _text('No hay cuentas operativas en este periodo.'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 24,
              horizontalMargin: 4,
              headingTextStyle: const TextStyle(
                color: kDirectionMutedText,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(color: kDirectionSurfaceText),
              columns: const [
                DataColumn(label: Text('Empresa')),
                DataColumn(label: Text('Aporte actual'), numeric: true),
                DataColumn(
                  label: Text('Cubre costos que quedan'),
                  numeric: true,
                ),
                DataColumn(label: Text('Cambio al salir'), numeric: true),
                DataColumn(label: Text('Qué revisar')),
              ],
              rows: [
                for (final p
                    in _decisionShowAll ? priorities : priorities.take(8))
                  DataRow(
                    selected: p.company.entity.key == selected?.entity.key,
                    onSelectChanged: _busy
                        ? null
                        : (_) => _selectDecision(p.company.entity.key),
                    cells: [
                      DataCell(
                        Text(
                          p.company.displayName,
                          key: ValueKey('decision:${p.company.entity.key}'),
                        ),
                      ),
                      DataCell(Text(_mxn(p.account.afterOverhead))),
                      DataCell(Text(_mxn(p.contributionToRetainedCosts))),
                      DataCell(
                        Text(
                          _mxn(p.exit.change),
                          style: TextStyle(color: _sign(p.exit.change)),
                        ),
                      ),
                      DataCell(Text(p.action)),
                    ],
                  ),
              ],
            ),
          ),
          if (priorities.length > 8)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    _redraw(() => _decisionShowAll = !_decisionShowAll),
                child: Text(
                  _decisionShowAll
                      ? 'Ver primeras 8'
                      : 'Ver todas las empresas',
                ),
              ),
            ),
          _text(
            '“Cubre costos que quedan” = genera menos el ahorro supuesto al salir. Positivo indica que esa cuenta ayuda a sostener nómina, equipo y otros costos que permanecen.',
          ),
        ]),
      ],
    );
  }

  Widget _decisionSimulator(
    ProfitConsolidated total,
    ProfitCompanyResult company,
  ) {
    final impact = total.simulate(company.entity.key, _decisionPlan);
    final a = company.account!;
    final exit = _decisionPlan.mode == ProfitPlanMode.exit;
    final deficit = math.max(0.0, -a.afterOverhead);
    return _card([
      _heading('Simular · ${company.displayName}'),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _action(
            'Cambiar empresa',
            () => _pickDecisionCompany(total, company),
            icon: Icons.search,
          ),
          _action(
            'Ver análisis de la empresa',
            () => _redraw(() {
              _search.clear();
              _simpleSelected = company.entity.key;
              _simpleTab = 0;
            }),
            icon: Icons.open_in_new,
          ),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<ProfitPlanMode>(
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
              value: ProfitPlanMode.adjust,
              label: Text('Ajustar operación'),
            ),
            ButtonSegment(
              value: ProfitPlanMode.exit,
              label: Text('Salir de la empresa'),
            ),
          ],
          selected: {_decisionPlan.mode},
          onSelectionChanged: _enabled
              ? (v) => _redraw(
                  () => _decisionPlan = ProfitDecisionPlan(mode: v.single),
                )
              : null,
        ),
      ),
      const SizedBox(height: 12),
      _decisionResultCards(impact),
      const SizedBox(height: 12),
      _text(
        exit
            ? 'Salida completa al inicio de un periodo equivalente. Se pierde el material y el ingreso de esta cuenta. Los costos que no se ahorren permanecen en DICSA.'
            : 'Se conserva el volumen de material. Menos viajes supone consolidar cargas o recibir entregas directas; consumo y km bajan en la misma proporción. Hay que validar capacidad y frecuencia. No se supone un ahorro de nómina ni equipo.',
      ),
      const SizedBox(height: 8),
      _text(
        exit
            ? 'Supuesto inicial: se evitan compras, combustible, recolección/transporte, disposición y báscula. Nómina, equipo, mantenimiento, proceso y soporte permanecen. Revisa los porcentajes según contratos y operación.'
            : 'Compra ${_percent(_decisionPlan.purchaseChange)}, valor recuperable ${_percent(_decisionPlan.valueChange)}, tarifa de servicios ${_percent(_decisionPlan.serviceChange)}, viajes −${_percent(_decisionPlan.fewerTrips)}. ${_decisionPlan.preserveServiceIncome ? 'Se mantiene el ingreso de servicios pese a reducir viajes.' : 'El ingreso de servicios baja proporcionalmente a los viajes.'}',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _action(
            exit ? 'Ajustar ahorros y salida' : 'Cambiar precios y viajes',
            () => _editDecision(company),
            icon: Icons.tune,
          ),
          TextButton(
            onPressed: _enabled
                ? () => _redraw(
                    () => _decisionPlan = ProfitDecisionPlan(
                      mode: _decisionPlan.mode,
                    ),
                  )
                : null,
            child: const Text('Restablecer simulación'),
          ),
        ],
      ),
      const Divider(),
      _statementRow(
        'Resultado actual de las empresas seleccionadas',
        impact.before,
      ),
      _statementRow(
        exit ? 'Valor e ingresos que se pierden' : 'Cambio en valor e ingresos',
        impact.generationChange,
      ),
      _statementRow(
        'Ahorro de costos supuesto (− = mayor gasto)',
        impact.costSaving,
      ),
      _statementRow(
        'Costo de implementar el cambio',
        -_decisionPlan.transitionCost,
      ),
      _statementRow(
        'Aporte neto adicional por capacidad reutilizada',
        _decisionPlan.replacementContribution,
      ),
      _statementRow(
        'RESULTADO SIMULADO DEL ALCANCE',
        impact.after,
        emphasized: true,
      ),
      _statementRow(
        'Toda la operación modelada con este cambio',
        _analysis!.modeledResult + impact.change,
      ),
      _text(
        exit
            ? '${_mxn(impact.retainedCost)} de los costos atribuidos a esta cuenta seguirían en DICSA. Redistribuirlos entre otras empresas no los elimina.'
            : '${_mxn(impact.retainedCost)} sería el costo de la cuenta antes del costo de implementar el cambio.',
      ),
      const SizedBox(height: 8),
      _text(
        exit
            ? 'Actividad liberada: ${_kg(impact.releasedTrips)} viajes y ${_kg(impact.releasedKm)} km. Se dejan de recibir ${_kg(impact.lostKg / 1000)} t. No equivale a vehículos o plazas que puedan eliminarse.'
            : 'Reducción simulada: ${_kg(impact.releasedTrips)} viajes y ${_kg(impact.releasedKm)} km, conservando ${_kg(a.kg / 1000)} t.',
      ),
      if (impact.replacementToKeepResult > 0)
        _text(
          'Para conservar el resultado actual haría falta ${_mxn(impact.replacementToKeepResult)} de aporte neto total por reemplazo en estos ${_period.days} días; ya supusiste ${_mxn(_decisionPlan.replacementContribution)}.',
        ),
      if (deficit > .005) ...[
        const SizedBox(height: 12),
        _heading('Alternativas para cubrir el déficit de esta cuenta'),
        _text(
          'Brecha actual: ${_mxn(deficit)}. Las siguientes opciones son alternativas completas, no ahorros que deban sumarse.',
        ),
        if (a.kg > 0)
          _text(
            'Mejorar el margen de material ${_mxn(deficit / a.kg)}/kg físico, manteniendo volumen y costos.',
          ),
        if (a.block('purchase') > 0)
          _text(
            'Bajar el gasto de compra ${_percent(deficit / a.block('purchase'))}${deficit > a.block('purchase') ? ': ni eliminar toda la compra cubriría por sí solo la brecha.' : ', con el mismo volumen.'}',
          ),
        if (a.serviceCount > 0)
          _text(
            'Recuperar ${_mxn(deficit / a.serviceCount)} adicionales por servicio, si es comercialmente viable.',
          ),
      ],
      ExpansionTile(
        title: const Text(
          'Costos que se ahorran y costos que permanecen',
          style: TextStyle(color: kDirectionSurfaceText),
        ),
        children: [
          for (final block in profitAccountBlocks.entries.where(
            (e) => !['value', 'income'].contains(e.key) && a.block(e.key) > 0,
          ))
            ListTile(
              title: Text(
                block.value,
                style: const TextStyle(color: kDirectionSurfaceText),
              ),
              subtitle: Text(
                'Base ${_mxn(a.block(block.key))} · ahorro ${_mxn(impact.savings[block.key])} · permanece ${_mxn(a.block(block.key) - impact.savings[block.key]!)}',
                style: const TextStyle(color: kDirectionMutedText),
              ),
            ),
        ],
      ),
      _text(
        'Simulación temporal; usa la última lectura del periodo y no modifica precios, contratos ni operaciones. La capacidad reutilizada es aporte neto después de sus costos incrementales; empieza en cero. Cancelaciones, penalizaciones y otros costos de transición deben incluirse en el supuesto.',
      ),
    ]);
  }

  Widget _decisionResultCards(ProfitDecisionImpact impact) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth >= 850 ? 3 : 1;
      final width = (constraints.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: _kpi(
              'Alcance actual',
              _mxn(impact.before),
              'Misma lectura y periodo',
              sign: impact.before,
            ),
          ),
          SizedBox(
            width: width,
            child: _kpi(
              'Alcance con este cambio',
              _mxn(impact.after),
              'Con los supuestos de la simulación',
              sign: impact.after,
            ),
          ),
          SizedBox(
            width: width,
            child: _kpi(
              'CAMBIO EN EL RESULTADO',
              _mxn(impact.change),
              impact.change.abs() < .005
                  ? 'Sin cambio bajo estos supuestos'
                  : impact.change > 0
                  ? 'Mejora estimada para DICSA'
                  : 'Empeora el resultado de DICSA',
              sign: impact.change,
            ),
          ),
        ],
      );
    },
  );

  Future<void> _pickDecisionCompany(
    ProfitConsolidated total,
    ProfitCompanyResult current,
  ) => _guard(() async {
    final rows = [...total.companies]
      ..sort((a, b) => a.entity.name.compareTo(b.entity.name));
    await showIncomeForm(
      context,
      title: 'Empresa para simular',
      description:
          'El resultado consolidado siempre considera a todas las empresas del periodo.',
      fields: [
        IncomeFormField(
          'company',
          'Empresa',
          current.entity.key,
          options: {for (final c in rows) c.entity.key: c.displayName},
        ),
      ],
      onSave: (v) async => _selectDecision(profitText(v['company'])),
    );
  });

  Future<void> _editDecision(ProfitCompanyResult company) => _guard(() async {
    final plan = _decisionPlan;
    final exit = plan.mode == ProfitPlanMode.exit;
    final blocks = profitAccountBlocks.entries
        .where(
          (e) =>
              !['value', 'income'].contains(e.key) &&
              company.account!.block(e.key) > 0,
        )
        .toList();
    await showIncomeForm(
      context,
      title: exit
          ? 'Supuestos de salida · ${company.displayName}'
          : 'Cambios operativos · ${company.displayName}',
      description: exit
          ? 'Porcentaje del costo que efectivamente dejaría de pagarse o consumirse durante ${_period.days} días. Reasignar personal no elimina su sueldo. Guardar aplica solo a esta simulación.'
          : 'Cambios porcentuales frente al corte actual. Negativo baja el precio; positivo lo sube. Menos viajes conserva material con cargas mayores. Guardar aplica solo a esta simulación.',
      fields: [
        if (exit)
          for (final block in blocks)
            IncomeFormField(
              'share:${block.key}',
              '${block.value} · ahorro (%)',
              (plan.exitShares[block.key] ?? 0) * 100,
              numeric: true,
              max: 100,
            ),
        if (!exit) ...[
          IncomeFormField(
            'purchase',
            'Cambio precio de compra (%)',
            plan.purchaseChange * 100,
            numeric: true,
            min: -100,
            max: 100,
          ),
          IncomeFormField(
            'value',
            'Cambio valor recuperable del material (%)',
            plan.valueChange * 100,
            numeric: true,
            min: -100,
            max: 100,
          ),
          IncomeFormField(
            'income',
            'Cambio tarifa de servicios (%)',
            plan.serviceChange * 100,
            numeric: true,
            min: -100,
            max: 100,
          ),
          IncomeFormField(
            'trips',
            'Reducir viajes y km (%)',
            plan.fewerTrips * 100,
            numeric: true,
            max: 100,
          ),
          IncomeFormField(
            'preserve',
            'Conservar ingreso de servicios al reducir viajes',
            plan.preserveServiceIncome,
          ),
        ],
        IncomeFormField(
          'transition',
          'Costo de implementar el cambio en el periodo',
          plan.transitionCost,
          numeric: true,
        ),
        IncomeFormField(
          'replacement',
          'Aporte NETO adicional por capacidad reutilizada',
          plan.replacementContribution,
          numeric: true,
        ),
      ],
      onSave: (v) async {
        double n(String key) => profitNumber(v[key]) ?? 0;
        _redraw(
          () => _decisionPlan = ProfitDecisionPlan(
            mode: plan.mode,
            exitShares: exit
                ? {
                    for (final block in blocks)
                      block.key: n('share:${block.key}') / 100,
                  }
                : plan.exitShares,
            purchaseChange: n('purchase') / 100,
            valueChange: n('value') / 100,
            serviceChange: n('income') / 100,
            fewerTrips: n('trips') / 100,
            preserveServiceIncome: v['preserve'] == true,
            transitionCost: n('transition'),
            replacementContribution: n('replacement'),
          ),
        );
      },
    );
  });
}
