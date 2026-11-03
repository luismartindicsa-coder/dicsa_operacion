import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../../shared/utils/number_formatters.dart';
import '../contabilidad_theme.dart';
import 'statement_models.dart';
import 'statement_repository.dart';
import 'statement_review_topics.dart';
import 'statement_review_queue.dart';

/// Hybrid tabs / existing Accounting glass shell. Auxiliary editors inherit the
/// accounting palette. Parent defers realtime refresh while an editor is open.
class StatementReviewPanel extends StatefulWidget {
  final StatementAnalysis analysis;
  final bool onlyPending;
  final Future<void> Function() onSaved;
  final ValueChanged<bool> onEditing;
  final StatementRepository repository;
  const StatementReviewPanel({
    super.key,
    required this.analysis,
    required this.onlyPending,
    required this.onSaved,
    required this.onEditing,
    this.repository = const StatementRepository(),
  });
  @override
  State<StatementReviewPanel> createState() => _StatementReviewPanelState();
}

class _StatementReviewPanelState extends State<StatementReviewPanel> {
  String _search = '', _source = '';
  String _reviewMode = 'clarify';
  StatementReviewTopic? _topic;
  int _page = 0;
  static const _size = 40;
  StatementRepository get _repository => widget.repository;
  Future<void> _open(Widget child) async {
    widget.onEditing(true);
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AreaThemeScope(
          tokens: contabilidadAreaTokens,
          child: Theme(data: contabilidadFormTheme(context), child: child),
        ),
      );
      if (saved == true) await widget.onSaved();
    } finally {
      widget.onEditing(false);
    }
  }

  Widget _entryTile(StatementAnalysis a, StatementEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        title: Text(
          e.fact.label,
          style: const TextStyle(
            color: kContabilidadInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${e.fact.date == null ? 'Sin fecha' : stDay(e.decision?.economicDate ?? e.fact.date!)} · ${e.fact.source}\n${e.includedPending
              ? 'Incluido provisional · pendiente de revisión · ${e.account.label}'
              : e.pending
              ? 'Pendiente · sin incluir'
              : e.account.label}${e.automatic ? ' · automático' : ''}${e.estimated && e.account.affectsResult ? ' · estimado' : ''}${e.issue == null ? '' : '\n${e.issue}'}${e.pending && e.issue == null ? '\n${e.fact.detail}' : ''}',
          style: const TextStyle(color: kContabilidadMutedInk),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatMoney(e.amount),
              style: const TextStyle(
                color: kContabilidadInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: 'Revisar operación',
              onPressed: a.bundle.canManage
                  ? () => _open(
                      _DecisionEditor(a: a, entry: e, repository: _repository),
                    )
                  : null,
              icon: const Icon(Icons.edit_note, color: kContabilidadGlow),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final topics = statementReviewTopics(a);
    if (!topics.containsKey(_topic)) _topic = null;
    final topicIds = _topic == null
        ? null
        : topics[_topic]!.map((e) => e.fact.id).toSet();
    final sources = a.entries.map((e) => e.fact.source).toSet().toList()
      ..sort();
    if (!sources.contains(_source)) _source = '';
    final queue = statementReviewQueue(a);
    final mode = widget.onlyPending ? _reviewMode : 'all';
    final cases = mode == 'all' || mode == 'estimates'
        ? [
            for (final e in a.entries.where(
              (e) => mode == 'all' || (e.estimated && e.account.affectsResult),
            ))
              StatementReviewCase(
                e.fact.id,
                [e],
                StatementReviewLane.included,
                '',
              ),
          ]
        : queue.where((c) => c.lane.name == mode).toList();
    final rows = cases
        .where(
          (c) =>
              (topicIds == null ||
                  mode == 'all' ||
                  mode == 'estimates' ||
                  c.entries.any((e) => topicIds.contains(e.fact.id))) &&
              (_source.isEmpty ||
                  c.entries.any((e) => e.fact.source == _source)) &&
              c.entries.any(
                (e) => stKey(
                  '${e.fact.label} ${e.fact.detail}',
                ).contains(stKey(_search)),
              ),
        )
        .toList();
    final pages = ((rows.length + _size - 1) ~/ _size).clamp(1, 1000000);
    final page = _page.clamp(0, pages - 1);
    return Theme(
      data: contabilidadFormTheme(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContractGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.status,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kContabilidadInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Las categorías capturadas siguen en el resultado base. Aquí se revisan documentos y ajustes del cierre contable.',
                  style: TextStyle(color: kContabilidadMutedInk),
                ),
                const SizedBox(height: 8),
                Text(
                  '${queue.where((c) => c.lane == StatementReviewLane.clarify).length} asuntos con datos por completar · '
                  '${queue.where((c) => c.lane == StatementReviewLane.closing).length} revisiones de cierre · '
                  '${queue.where((c) => c.lane == StatementReviewLane.included).length} ya incluidos en el contable',
                  style: const TextStyle(color: kContabilidadGlow),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: a.bundle.canManage
                          ? () => _open(
                              _ConversionEditor(a: a, repository: _repository),
                            )
                          : null,
                      icon: const Icon(Icons.link),
                      label: const Text('Vincular efectivo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: a.bundle.canManage
                          ? () => _open(
                              _AdjustmentEditor(a: a, repository: _repository),
                            )
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajuste de cierre'),
                    ),
                    if (a.bundle
                        .rows('accounting_cash_conversions')
                        .any((r) => r['active'] != false))
                      OutlinedButton.icon(
                        onPressed: a.bundle.canManage
                            ? () => _open(
                                _UnlinkEditor(a: a, repository: _repository),
                              )
                            : null,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Corregir vínculo de efectivo'),
                      ),
                    FilledButton.icon(
                      onPressed: a.bundle.canManage
                          ? () => _open(
                              _ClosingEditor(a: a, repository: _repository),
                            )
                          : null,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Revisar cierre'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ContractGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.onlyPending)
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _reviewMode,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Mostrar',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'clarify',
                              child: Text('Datos por completar'),
                            ),
                            DropdownMenuItem(
                              value: 'closing',
                              child: Text('Revisiones de cierre'),
                            ),
                            DropdownMenuItem(
                              value: 'included',
                              child: Text('Ya incluidos en el contable'),
                            ),
                            DropdownMenuItem(
                              value: 'estimates',
                              child: Text('Todas las estimaciones'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Todas las operaciones'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _reviewMode = v ?? 'clarify';
                            _topic = null;
                            _page = 0;
                          }),
                        ),
                      ),
                    SizedBox(
                      width: 340,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar operación',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() {
                          _search = v;
                          _page = 0;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _source,
                        decoration: const InputDecoration(labelText: 'Fuente'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todas las fuentes'),
                          ),
                          for (final s in sources)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(() {
                          _source = v ?? '';
                          _page = 0;
                        }),
                      ),
                    ),
                  ],
                ),
                if (widget.onlyPending &&
                    mode != 'all' &&
                    mode != 'estimates' &&
                    topics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StatementReviewTopic?>(
                    key: ValueKey(_topic),
                    initialValue: _topic,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tema de revisión',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos los temas'),
                      ),
                      for (final group in topics.entries)
                        DropdownMenuItem(
                          value: group.key,
                          child: Text(
                            '${group.key.label} · ${group.value.length} documentos',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _topic = v;
                      _page = 0;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _topic?.guidance ??
                        'Filtra por tema. Cada documento conserva su clasificación y su revisión.',
                    style: const TextStyle(color: kContabilidadMutedInk),
                  ),
                ],
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay operaciones en este filtro.'),
                  ),
                for (final c in rows.skip(page * _size).take(_size))
                  if (c.grouped)
                    ExpansionTile(
                      key: PageStorageKey('review-case-${c.id}'),
                      title: Text(
                        '${c.entries.first.fact.label} · ${c.entries.length} documentos',
                      ),
                      subtitle: Text(c.relation),
                      children: [for (final e in c.entries) _entryTile(a, e)],
                    )
                  else
                    _entryTile(a, c.entries.single),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${rows.length} asuntos · ${page + 1}/$pages'),
                    IconButton(
                      tooltip: 'Anterior',
                      onPressed: page > 0
                          ? () => setState(() => _page = page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: page + 1 < pages
                          ? () => setState(() => _page = page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (mode == 'all') ...[
            const SizedBox(height: 14),
            ContractGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Base física · Entradas y Salidas',
                    style: TextStyle(
                      color: kContabilidadInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Solo movimientos externos. La separación de chatarra y la transformación no son compras nuevas. Los costos de referencia requieren apertura y rendimiento revisados.',
                    style: TextStyle(color: kContabilidadMutedInk),
                  ),
                  const SizedBox(height: 10),
                  for (final m in a.materials)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        '${m.label}: entradas ${m.receivedKg.toStringAsFixed(2)} kg · salidas ${m.dispatchedKg.toStringAsFixed(2)} kg · promedio ${m.average == null ? 'sin costo' : formatMoney(m.average!)} / kg · ${m.recoveries} recuperaciones internas',
                        style: const TextStyle(color: kContabilidadInk),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  const _EditorFrame({
    required this.title,
    required this.children,
    required this.saving,
    required this.error,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (!saving) Navigator.pop(context, false);
      },
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (!saving) onSave();
      },
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
        if (!saving) onSave();
      },
    },
    child: AlertDialog(
      backgroundColor: kContabilidadBgTeal,
      title: Text(title),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: kContabilidadGlow),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: Text(saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}

mixin _Saving<T extends StatefulWidget> on State<T> {
  bool saving = false;
  String? error;
  Future<void> persist(Future<void> Function() action) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }
}

class _DecisionEditor extends StatefulWidget {
  final StatementAnalysis a;
  final StatementEntry entry;
  final StatementRepository repository;
  const _DecisionEditor({
    required this.a,
    required this.entry,
    required this.repository,
  });
  @override
  State<_DecisionEditor> createState() => _DecisionEditorState();
}

class _DecisionEditorState extends State<_DecisionEditor> with _Saving {
  late final TextEditingController amount, note, date;
  late StatementAccount account;
  late bool estimated;
  String duplicate = '';
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    amount = TextEditingController(text: e.amount.toStringAsFixed(2));
    note = TextEditingController(text: e.decision?.note ?? '');
    date = TextEditingController(
      text: stDay(
        e.decision?.economicDate ?? e.fact.date ?? widget.a.bundle.period.end,
      ),
    );
    account = e.account;
    estimated = e.estimated;
    duplicate = e.decision?.duplicateOf ?? '';
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return _EditorFrame(
      title: 'Revisar operación',
      saving: saving,
      error: error,
      onSave: () => persist(() async {
        final value = double.tryParse(amount.text.replaceAll(',', '')),
            day = stDate(date.text);
        if (value == null || day == null) {
          throw StateError('Captura importe y fecha válidos.');
        }
        final d = StatementDecision(
          id: e.fact.id,
          signature: e.fact.signature,
          note: note.text.trim(),
          account: account,
          amount: value,
          revision: widget.a.bundle.decisions[e.fact.id]?.revision ?? 0,
          estimated: estimated,
          economicDate: day,
          duplicateOf: duplicate,
        );
        await widget.repository.saveDecision(d);
      }),
      children: [
        Text(e.fact.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(e.fact.detail),
        if (e.fact.references.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${e.fact.references.length} documentos relacionados'),
            children: [
              for (final id in e.fact.references)
                Builder(
                  builder: (context) {
                    final linked = widget.a.entries
                        .where((x) => x.fact.id == id)
                        .firstOrNull;
                    return ListTile(
                      dense: true,
                      title: Text(linked?.fact.label ?? id),
                      subtitle: Text(
                        linked == null
                            ? 'Documento fuera del periodo o sin registro visible en este resultado.'
                            : '${linked.fact.source} · ${linked.fact.date == null ? 'Sin fecha' : stDay(linked.fact.date!)} · ${linked.account.label}\n${linked.fact.detail}',
                      ),
                      trailing: linked == null
                          ? null
                          : Text(formatMoney(linked.amount)),
                    );
                  },
                ),
            ],
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<StatementAccount>(
          initialValue: account,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tratamiento contable'),
          items: [
            for (final a in StatementAccount.values)
              DropdownMenuItem(value: a, child: Text(a.label)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => account = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Importe reconocido (base sin impuestos recuperables)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: date,
          decoration: const InputDecoration(
            labelText: 'Fecha económica · AAAA-MM-DD',
          ),
        ),
        if (account == StatementAccount.duplicate) ...[
          const SizedBox(height: 12),
          Autocomplete<StatementEntry>(
            initialValue: TextEditingValue(
              text:
                  widget.a.entries
                      .where((v) => v.fact.id == duplicate)
                      .firstOrNull
                      ?.fact
                      .label ??
                  '',
            ),
            displayStringForOption: (v) => '${v.fact.label} · ${v.fact.source}',
            optionsBuilder: (v) => widget.a.entries
                .where(
                  (x) =>
                      x.fact.id != e.fact.id &&
                      !x.pending &&
                      stKey(
                        '${x.fact.label} ${x.fact.source}',
                      ).contains(stKey(v.text)),
                )
                .take(30),
            onSelected: (v) => duplicate = v.fact.id,
            fieldViewBuilder: (context, controller, focus, submit) => TextField(
              controller: controller,
              focusNode: focus,
              onChanged: (_) => duplicate = '',
              decoration: const InputDecoration(
                labelText: 'Operación ya reconocida · buscar y seleccionar',
              ),
            ),
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('El importe todavía es una estimación'),
          value: estimated,
          onChanged: (v) => setState(() => estimated = v ?? false),
        ),
        TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Fundamento y comprobantes de la clasificación',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Los originales se conservan. Si cambian sus datos, esta clasificación deberá revisarse nuevamente.',
        ),
      ],
    );
  }
}

class _ClosingEditor extends StatefulWidget {
  final StatementAnalysis a;
  final StatementRepository repository;
  const _ClosingEditor({required this.a, required this.repository});
  @override
  State<_ClosingEditor> createState() => _ClosingEditorState();
}

class _ClosingEditorState extends State<_ClosingEditor> with _Saving {
  late final TextEditingController note;
  late final Set<String> checks;
  @override
  void initState() {
    super.initState();
    note = TextEditingController(text: widget.a.bundle.closing.note);
    checks = {...widget.a.bundle.closing.checks};
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return _EditorFrame(
      title: 'Revisión del cierre',
      saving: saving,
      error: error,
      onSave: () => persist(() async {
        if (note.text.trim().isEmpty) {
          throw StateError('Documenta la revisión del cierre.');
        }
        final ready =
            a.pending.isEmpty &&
            !a.estimated &&
            a.warnings.isEmpty &&
            statementClosingChecks.keys.every(checks.contains);
        await widget.repository.saveClosing(
          a.bundle.period,
          StatementClosing(
            revision: a.bundle.closing.revision,
            signature: ready ? a.signature : '',
            note: note.text.trim(),
            checks: checks,
            adjustments: a.bundle.closing.adjustments,
            snapshot: ready ? a.toSnapshot() : const {},
          ),
        );
      }),
      children: [
        Text(
          '${stDay(a.bundle.period.start)} al ${stDay(a.bundle.period.end)} · ${a.status}',
        ),
        const SizedBox(height: 8),
        const Text(
          'Puedes guardar avances. Solo se presenta utilidad neta revisada cuando no hay partidas pendientes ni costos estimados y se completan estos controles.',
        ),
        for (final item in statementClosingChecks.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.value),
            value: checks.contains(item.key),
            onChanged: (v) => setState(() {
              v == true ? checks.add(item.key) : checks.remove(item.key);
            }),
          ),
        TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Responsable, alcance y evidencia del cierre',
          ),
        ),
      ],
    );
  }
}

class _AdjustmentEditor extends StatefulWidget {
  final StatementAnalysis a;
  final StatementRepository repository;
  const _AdjustmentEditor({required this.a, required this.repository});
  @override
  State<_AdjustmentEditor> createState() => _AdjustmentEditorState();
}

class _AdjustmentEditorState extends State<_AdjustmentEditor> with _Saving {
  final amount = TextEditingController(), note = TextEditingController();
  late final TextEditingController date;
  StatementAccount? account;
  @override
  void initState() {
    super.initState();
    date = TextEditingController(text: stDay(widget.a.bundle.period.end));
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
    title: 'Ajuste documentado del periodo',
    saving: saving,
    error: error,
    onSave: () => persist(() async {
      final a = widget.a,
          value = double.tryParse(amount.text.replaceAll(',', '')),
          day = stDate(date.text);
      if (account == null ||
          value == null ||
          !value.isFinite ||
          !a.bundle.period.contains(day) ||
          note.text.trim().isEmpty) {
        throw StateError(
          'Completa concepto, importe, fecha del periodo y fundamento.',
        );
      }
      final adjustment = <String, dynamic>{
        'id': 'adj-${DateTime.now().microsecondsSinceEpoch}',
        'date': stDay(day!),
        'account': account!.name,
        'amount': value,
        'note': note.text.trim(),
      };
      await widget.repository.saveClosing(
        a.bundle.period,
        StatementClosing(
          revision: a.bundle.closing.revision,
          note: a.bundle.closing.note.isEmpty
              ? 'Ajustes en preparación'
              : a.bundle.closing.note,
          checks: a.bundle.closing.checks,
          adjustments: [...a.bundle.closing.adjustments, adjustment],
        ),
      );
    }),
    children: [
      const Text(
        'Registra devengaciones, impuestos, depreciación, provisiones o correcciones sustentadas. Un importe negativo revierte el concepto. No dupliques operaciones ya reconocidas.',
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<StatementAccount>(
        initialValue: account,
        decoration: const InputDecoration(labelText: 'Concepto'),
        items: [
          for (final a in StatementAccount.values.where((v) => v.affectsResult))
            DropdownMenuItem(value: a, child: Text(a.label)),
        ],
        onChanged: (v) => setState(() => account = v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: amount,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Importe firmado · MXN'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: date,
        decoration: const InputDecoration(
          labelText: 'Fecha económica · AAAA-MM-DD',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: note,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Fundamento y soporte'),
      ),
    ],
  );
}

class _ConversionEditor extends StatefulWidget {
  final StatementAnalysis a;
  final StatementRepository repository;
  const _ConversionEditor({required this.a, required this.repository});
  @override
  State<_ConversionEditor> createState() => _ConversionEditorState();
}

class _ConversionEditorState extends State<_ConversionEditor> with _Saving {
  StatementRow? bank, cash;
  final note = TextEditingController();
  bool confirmed = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Widget picker(
    String label,
    List<StatementRow> rows,
    bool isBank,
  ) => Autocomplete<StatementRow>(
    displayStringForOption: (r) => isBank
        ? '${stText(r['movement_date']).split('T').first} · ${r['counterparty_name_snapshot']} · ${formatMoney(stNumber(r['debit_amount']))}'
        : '${r['voucher_date']} · ${r['folio']} · ${r['person_label']} · ${formatMoney(stNumber(r['total_amount']))}',
    optionsBuilder: (v) =>
        rows.where((r) => stKey(r.toString()).contains(stKey(v.text))).take(30),
    onSelected: (r) => setState(() {
      if (isBank) {
        bank = r;
      } else {
        cash = r;
      }
    }),
    fieldViewBuilder: (context, controller, focus, submit) => TextField(
      controller: controller,
      focusNode: focus,
      autofocus: isBank,
      onChanged: (_) => setState(() {
        if (isBank) {
          bank = null;
        } else {
          cash = null;
        }
      }),
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final links = a.bundle
        .rows('accounting_cash_conversions')
        .where((r) => r['active'] != false)
        .toList();
    final banks =
        a.bundle
            .rows('finanzas_bank_movements')
            .where(
              (r) =>
                  stNumber(r['debit_amount']) > 0 &&
                  !links.any((l) => l['bank_id'] == r['id']),
            )
            .toList()
          ..sort(
            (a, b) => stText(
              b['movement_date'],
            ).compareTo(stText(a['movement_date'])),
          );
    final vault =
        a.bundle
            .rows('direction_vault_vouchers')
            .where(
              (r) =>
                  r['voucher_type'] == 'deposit' &&
                  !links.any((l) => l['vault_id'] == r['id']),
            )
            .toList()
          ..sort(
            (a, b) =>
                stText(b['voucher_date']).compareTo(stText(a['voucher_date'])),
          );
    return _EditorFrame(
      title: 'Vincular conversión a efectivo',
      saving: saving,
      error: error,
      onSave: () => persist(() async {
        if (bank == null ||
            cash == null ||
            !confirmed ||
            note.text.trim().isEmpty) {
          throw StateError(
            'Selecciona ambos movimientos y documenta la operación real.',
          );
        }
        await widget.repository.saveConversion(
          bankId: stText(bank!['id']),
          vaultId: stText(cash!['id']),
          bankAmount: stNumber(bank!['debit_amount']),
          cashAmount: stNumber(cash!['total_amount']),
          note: note.text.trim(),
        );
      }),
      children: [
        const Text(
          'Vincula el pago y el efectivo recibido. La diferencia será el costo de la operación; la factura ligada y sus tickets no alimentarán compras físicas. No se modifica el comprobante fiscal.',
        ),
        const SizedBox(height: 16),
        picker(
          'Pago bancario · buscar fecha, contraparte o importe',
          banks,
          true,
        ),
        const SizedBox(height: 16),
        picker(
          'Entrada a Bóveda · buscar folio, persona o importe',
          vault,
          false,
        ),
        if (bank != null && cash != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Costo: ${formatMoney(stNumber(bank!['debit_amount']) - stNumber(cash!['total_amount']))}',
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Confirmo recepción de efectivo, sin entrega física de material para esta operación',
          ),
          value: confirmed,
          onChanged: (v) => setState(() => confirmed = v ?? false),
        ),
        TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText:
                'Fundamento, base del costo y soporte de la conciliación',
          ),
        ),
      ],
    );
  }
}

class _UnlinkEditor extends StatefulWidget {
  final StatementAnalysis a;
  final StatementRepository repository;
  const _UnlinkEditor({required this.a, required this.repository});
  @override
  State<_UnlinkEditor> createState() => _UnlinkEditorState();
}

class _UnlinkEditorState extends State<_UnlinkEditor> with _Saving {
  final note = TextEditingController();
  String? selected;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final links =
        widget.a.bundle
            .rows('accounting_cash_conversions')
            .where((r) => r['active'] != false)
            .toList()
          ..sort(
            (a, b) => stText(
              b['effective_date'],
            ).compareTo(stText(a['effective_date'])),
          );
    return _EditorFrame(
      title: 'Corregir vínculo de efectivo',
      saving: saving,
      error: error,
      onSave: () => persist(() async {
        if (selected == null || note.text.trim().isEmpty) {
          throw StateError('Selecciona el vínculo y documenta la corrección.');
        }
        await widget.repository.unlinkConversion(selected!, note.text.trim());
      }),
      children: [
        const Text(
          'Desvincular devuelve los documentos a conciliación y retira el costo automático. Se conserva el historial. Después puedes vincular los movimientos correctos.',
        ),
        const SizedBox(height: 12),
        Autocomplete<StatementRow>(
          displayStringForOption: (r) =>
              '${r['effective_date']} · banco ${formatMoney(stNumber(r['bank_amount']))} · efectivo ${formatMoney(stNumber(r['cash_amount']))}',
          optionsBuilder: (v) => links
              .where((r) => stKey(r.toString()).contains(stKey(v.text)))
              .take(30),
          onSelected: (r) => selected = stText(r['id']),
          fieldViewBuilder: (context, controller, focus, submit) => TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            onChanged: (_) => selected = null,
            decoration: const InputDecoration(
              labelText: 'Buscar vínculo por fecha, importe o fundamento',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Motivo de la corrección',
          ),
        ),
      ],
    );
  }
}
