import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_dialog_widgets.dart';
import 'mayoreo_invoice_reconciliation.dart';
import 'mayoreo_invoice_reconciliation_store.dart';
import 'mayoreo_invoice_tickets_tab.dart';

/// Auxiliary commercial dialog: Menudeo cash-cut capture/history composition,
/// Entradas y Salidas focus/keyboard rules, Mayoreo semantic area palette.
class MayoreoInvoiceReconciliationDialog extends StatefulWidget {
  final MayoreoInvoiceRepository repository;
  const MayoreoInvoiceReconciliationDialog({
    super.key,
    required this.repository,
  });

  @override
  State<MayoreoInvoiceReconciliationDialog> createState() =>
      _MayoreoInvoiceReconciliationDialogState();
}

class _MayoreoInvoiceReconciliationDialogState
    extends State<MayoreoInvoiceReconciliationDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _amountFocus = FocusNode();
  List<MayoreoInvoiceClient> _clients = [];
  List<MayoreoInvoiceHistory> _history = [];
  final _details = <String, Future<List<MayoreoInvoiceTicket>>>{};
  MayoreoInvoiceClient? _client;
  MayoreoInvoiceMatch? _match;
  String? _requestId;
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  bool _updatingTickets = false;
  bool _uncertainSave = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _tab = 0;

  bool get _locked => _loading || _searching || _saving || _uncertainSave;
  bool get _navigationLocked =>
      _searching || _saving || _uncertainSave || _updatingTickets;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final clients = await widget.repository.loadClients();
      final history = await widget.repository.loadHistory(0);
      if (!mounted) return;
      setState(() {
        _clients = clients..sort((a, b) => a.name.compareTo(b.name));
        _history = history;
        _hasMore = history.length == 40;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudieron cargar las conciliaciones. ${_errorText(error)}';
      });
    }
  }

  String _errorText(Object error) {
    if (error is PostgrestException) {
      if (['42P01', '42883', 'PGRST202', 'PGRST205'].contains(error.code)) {
        return 'La función de conciliación todavía no está habilitada en la base de datos.';
      }
      if (error.code == 'PT409' || error.code == '22023') return error.message;
    }
    return 'Revisa la conexión e inténtalo de nuevo.';
  }

  void _invalidate() {
    _match = null;
    _requestId = null;
    _error = null;
    _notice = null;
  }

  Future<void> _search() async {
    if (_locked) return;
    final target = parseReconciliationCents(_amount.text);
    if (_client == null || target == null) {
      setState(
        () => _error = _client == null
            ? 'Selecciona un cliente de la lista.'
            : 'Escribe un importe mayor que cero, con hasta dos decimales.',
      );
      return;
    }
    setState(() {
      _invalidate();
      _searching = true;
    });
    try {
      // Read all the client's available tickets, independently of grid filters
      // and pagination. The RPC revalidates this snapshot at save time.
      final candidates = await widget.repository.loadCandidates(_client!.key);
      final match = await compute(
        findMayoreoInvoiceMatch,
        MayoreoInvoiceSearch(candidates, _client!.key, target),
      );
      if (!mounted) return;
      setState(() {
        _match = match;
        _requestId = const Uuid().v4();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final match = _match;
    if (_saving || match == null || match.tickets.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(
        requestId: _requestId!,
        clientKey: _client!.key,
        match: match,
        reference: _reference.text,
      );
      if (!mounted) return;
      setState(() {
        _history = [saved, ..._history.where((row) => row.id != saved.id)];
        _match = null;
        _requestId = null;
        _uncertainSave = false;
        _tab = 1;
        _notice = 'Conciliación guardada. Sus boletas quedaron reservadas.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final definitive =
            error is PostgrestException &&
            ['PT409', '22023', '42501', '23505'].contains(error.code);
        _uncertainSave = !definitive;
        if (definitive) _match = null;
        _error = _uncertainSave
            ? 'No se pudo confirmar el guardado. Reintenta para verificar la misma solicitud sin duplicarla.'
            : _errorText(error);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moreHistory() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final next = await widget.repository.loadHistory(_history.length);
      if (!mounted) return;
      setState(() {
        final ids = _history.map((row) => row.id).toSet();
        _history.addAll(next.where((row) => ids.add(row.id)));
        _hasMore = next.length == 40;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshClientsAfterUsageChange() async {
    setState(() {
      _invalidate();
      _details.clear();
    });
    try {
      final clients = await widget.repository.loadClients();
      if (mounted) setState(() => _clients = clients);
    } catch (_) {
      // Candidate searches always fetch current availability independently.
    }
  }

  @override
  Widget build(BuildContext context) =>
      MayoreoDialogTheme(child: Builder(builder: _buildDialog));

  Widget _buildDialog(BuildContext context) {
    return PopScope(
      canPop: !_saving && !_updatingTickets,
      child: ContractDialogShell(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 790),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MayoreoDialogHeader(
                  title: 'Conciliar boletas para factura',
                  onClose: _saving || _updatingTickets
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Nueva conciliación'),
                        icon: Icon(Icons.note_add_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Historial'),
                        icon: Icon(Icons.history_rounded),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text('Boletas'),
                        icon: Icon(Icons.receipt_long_outlined),
                      ),
                    ],
                    selected: {_tab},
                    showSelectedIcon: false,
                    onSelectionChanged: _navigationLocked
                        ? null
                        : (value) => setState(() => _tab = value.single),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_notice!),
                  ),
                const SizedBox(height: 14),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _tab == 0
                      ? _newReconciliation(context)
                      : _tab == 1
                      ? _historyView()
                      : MayoreoInvoiceTicketsTab(
                          repository: widget.repository,
                          onBusyChanged: (busy) =>
                              setState(() => _updatingTickets = busy),
                          onUsageChanged: () =>
                              unawaited(_refreshClientsAfterUsageChange()),
                        ),
                ),
                if (_tab == 0) ...[
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _locked ? null : _search,
                        icon: const Icon(Icons.manage_search),
                        label: Text(
                          _searching
                              ? 'Buscando combinación…'
                              : 'Buscar boletas',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _saving ||
                                _searching ||
                                _match == null ||
                                _match!.tickets.isEmpty
                            ? null
                            : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'Guardando…'
                              : _uncertainSave
                              ? 'Reintentar guardado'
                              : 'Guardar conciliación',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newReconciliation(BuildContext context) => ListView(
    children: [
      ContractGlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final client = Autocomplete<MayoreoInvoiceClient>(
                  initialValue: TextEditingValue(text: _client?.name ?? ''),
                  displayStringForOption: (value) => value.name,
                  optionsBuilder: (value) => _clients.where(
                    (client) => client.name.toLowerCase().contains(
                      value.text.toLowerCase(),
                    ),
                  ),
                  optionsViewBuilder: (context, onSelected, options) =>
                      MayoreoDialogOptions<MayoreoInvoiceClient>(
                        options: options,
                        label: (client) => client.name,
                        onSelected: onSelected,
                        width: constraints.maxWidth < 620
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) * 3 / 5,
                      ),
                  onSelected: (value) {
                    setState(() {
                      _client = value;
                      _invalidate();
                    });
                    _amountFocus.requestFocus();
                  },
                  fieldViewBuilder: (context, controller, focus, submit) =>
                      TextField(
                        controller: controller,
                        focusNode: focus,
                        autofocus: true,
                        enabled: !_locked,
                        decoration: mayoreoDialogFieldDecoration(
                          context,
                          label: 'Cliente',
                          hint: 'Buscar y seleccionar cliente',
                          icon: Icons.business_outlined,
                        ),
                        onChanged: (_) => setState(() {
                          _client = null;
                          _invalidate();
                        }),
                        onSubmitted: (_) => submit(),
                      ),
                );
                final amount = TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  enabled: !_locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: mayoreoDialogFieldDecoration(
                    context,
                    label: 'Importe solicitado',
                    hint: '165,643.00',
                  ).copyWith(prefixText: '\$ '),
                  onChanged: (_) => setState(_invalidate),
                  onSubmitted: (_) => _search(),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [client, const SizedBox(height: 12), amount],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: client),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: amount),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              enabled: !_locked,
              maxLength: 500,
              decoration: mayoreoDialogFieldDecoration(
                context,
                label: 'Referencia de factura (opcional)',
                icon: Icons.description_outlined,
              ).copyWith(counterText: ''),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Se usan boletas completas del cliente, sin exceder el importe solicitado. '
        'Las boletas guardadas en una conciliación dejan de estar disponibles.',
      ),
      if (_searching)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (!_searching && _match == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Selecciona el cliente, captura el importe y busca la combinación.',
          ),
        ),
      if (_match case final match?) ...[
        const SizedBox(height: 18),
        _totals(match.targetCents, match.totalCents),
        const SizedBox(height: 12),
        Text(
          match.tickets.isEmpty
              ? 'No hay boletas disponibles que quepan en el importe solicitado.'
              : match.missingCents == 0
              ? 'Coincidencia exacta · ${match.tickets.length} boletas'
              : '${match.tickets.length} boletas · Faltan ${_money(match.missingCents)} para completar la factura.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (!match.exhaustive && match.missingCents > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Combinación aproximada por el volumen de búsqueda; podría existir otra más cercana.',
            ),
          ),
        const SizedBox(height: 10),
        ...match.tickets.map(_ticketTile),
      ],
    ],
  );

  Widget _totals(int target, int total) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 780
          ? (constraints.maxWidth - 24) / 3
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          for (final item in [
            (Icons.request_quote_outlined, 'Importe solicitado', target),
            (Icons.receipt_long_outlined, 'Total de boletas', total),
            (
              Icons.pending_actions_rounded,
              'Faltante para completar',
              target - total,
            ),
          ])
            SizedBox(
              width: width,
              child: MayoreoDialogSummaryCard(
                icon: item.$1,
                title: item.$2,
                value: _money(item.$3),
              ),
            ),
        ],
      );
    },
  );

  Widget _ticketTile(MayoreoInvoiceTicket ticket) => MayoreoDialogRecordCard(
    child: ExpansionTile(
      title: Text('Boleta ${ticket.ticket} · ${_money(ticket.amountCents)}'),
      subtitle: Text(
        '${_date(ticket.saleDate)} · ${ticket.details.length} partida(s)'
        '${ticket.releasedAt == null ? '' : '\nLiberada para volver a conciliar el ${_date(ticket.releasedAt!.toLocal())}'}',
      ),
      children: ticket.details
          .map(
            (detail) => ListTile(
              dense: true,
              title: Text(
                '${detail['material']} · ${_money((detail['amount_cents'] as num).toInt())}',
              ),
              subtitle: Text(
                'Remisión: ${detail['remision']} · '
                '${formatDecimal(detail['approved_weight'] as num)} kg · '
                'Precio: ${formatMoney(detail['approved_price'] as num)}',
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _historyView() {
    if (_history.isEmpty) {
      return const Center(child: Text('Aún no hay conciliaciones guardadas.'));
    }
    return ListView.builder(
      itemCount: _history.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _history.length) {
          return TextButton(
            onPressed: _loadingMore ? null : _moreHistory,
            child: Text(_loadingMore ? 'Cargando…' : 'Ver más conciliaciones'),
          );
        }
        final row = _history[index];
        return MayoreoDialogRecordCard(
          child: ExpansionTile(
            key: ValueKey(row.id),
            title: Text('${row.clientName} · ${_money(row.targetCents)}'),
            subtitle: Text(
              '${_date(row.createdAt)} ${_time(row.createdAt)}'
              '${row.reference.isEmpty ? '' : ' · ${row.reference}'}'
              '${row.historical ? ' · Histórico' : ''}\n'
              'Boletas: ${_money(row.totalCents)} · Faltante: ${_money(row.targetCents - row.totalCents)}',
            ),
            onExpansionChanged: (expanded) {
              if (expanded && !_details.containsKey(row.id)) {
                setState(() {
                  _details[row.id] = widget.repository.loadDetails(row.id);
                });
              }
            },
            children: [
              if (_details[row.id] != null)
                FutureBuilder<List<MayoreoInvoiceTicket>>(
                  future: _details[row.id],
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'No se pudo cargar el detalle. ${_errorText(snapshot.error!)}',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: snapshot.data!.map(_ticketTile).toList(),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

String _money(int cents) => formatMoney(cents / 100);
String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
