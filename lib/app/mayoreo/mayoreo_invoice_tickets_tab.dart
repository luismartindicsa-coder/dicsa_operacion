import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_dialog_widgets.dart';
import 'mayoreo_invoice_reconciliation_store.dart';

/// Read-only operational detail with one editable field: used/not used.
/// Uses the same Mayoreo dialog/theme; availability writes are atomic RPCs.
class MayoreoInvoiceTicketsTab extends StatefulWidget {
  final MayoreoInvoiceRepository repository;
  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onUsageChanged;

  const MayoreoInvoiceTicketsTab({
    super.key,
    required this.repository,
    required this.onBusyChanged,
    required this.onUsageChanged,
  });

  @override
  State<MayoreoInvoiceTicketsTab> createState() =>
      _MayoreoInvoiceTicketsTabState();
}

class _MayoreoInvoiceTicketsTabState extends State<MayoreoInvoiceTicketsTab> {
  List<MayoreoManagedInvoiceTicket> _tickets = [];
  final _ticketSearch = TextEditingController();
  String _clientQuery = '';
  String? _clientKey;
  bool? _usedFilter;
  int _page = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  int _mutationVersion = 0;
  String? _error;
  String? _notice;
  Timer? _refreshTimer;
  ({String id, MayoreoManagedInvoiceTicket ticket, bool used})? _pending;

  bool get _locked => _saving || _pending != null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_locked && !_loading && !_refreshing) unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ticketSearch.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final version = _mutationVersion;
    try {
      final rows = await widget.repository.loadTickets();
      if (!mounted) return;
      // A background read started before an edit must not overwrite its result.
      if (!_locked && version == _mutationVersion) {
        setState(() {
          _tickets = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error =
              'No se pudieron cargar las boletas. Revisa la conexión e inténtalo de nuevo.';
        });
      }
    } finally {
      _refreshing = false;
      if (mounted && !_locked && version != _mutationVersion) {
        unawaited(_load(silent: true));
      }
    }
  }

  Future<void> _setUsed(MayoreoManagedInvoiceTicket row, bool used) async {
    if (_saving) return;
    _pending ??= (id: const Uuid().v4(), ticket: row, used: used);
    final pending = _pending!;
    _mutationVersion++;
    widget.onBusyChanged(true);
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.repository.setTicketUsed(
        requestId: pending.id,
        ticket: pending.ticket,
        used: pending.used,
      );
      if (!mounted) return;
      setState(() {
        _tickets = _tickets
            .map((item) => item.key == updated.key ? updated : item)
            .toList();
        _pending = null;
        _notice = updated.used
            ? 'Boleta ${updated.ticket.ticket} marcada como usada; queda fuera de la conciliación.'
            : updated.eligible
            ? 'Boleta ${updated.ticket.ticket} disponible para conciliar.'
            : 'Boleta ${updated.ticket.ticket} marcada sin usar. ${updated.eligibilityReason}.';
      });
      widget.onUsageChanged();
    } catch (error) {
      if (!mounted) return;
      final definitive =
          error is PostgrestException &&
          ['PT409', '22023', '42501', '23505'].contains(error.code);
      setState(() {
        if (definitive) _pending = null;
        _error = definitive
            ? error.code == 'PT409' || error.code == '22023'
                  ? error.message
                  : 'No se pudo cambiar el uso de esta boleta.'
            : 'No se pudo confirmar el cambio. Reintenta para verificar la misma solicitud.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onBusyChanged(false);
        if (_pending == null) unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final clientsByKey = <String, MayoreoInvoiceClient>{
      for (final row in _tickets)
        row.ticket.clientKey: MayoreoInvoiceClient(
          row.ticket.clientKey,
          row.ticket.clientName,
        ),
    };
    final clients = clientsByKey.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final query = _ticketSearch.text.trim().toLowerCase();
    final filtered = _tickets
        .where(
          (row) =>
              (_clientKey != null
                  ? row.ticket.clientKey == _clientKey
                  : row.ticket.clientName.toLowerCase().contains(
                      _clientQuery.toLowerCase(),
                    )) &&
              (_usedFilter == null || row.used == _usedFilter) &&
              (query.isEmpty ||
                  row.ticket.ticket.toLowerCase().contains(query)),
        )
        .toList();
    final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 40;
    final page = _page.clamp(0, lastPage);
    final visible = filtered.skip(page * 40).take(40).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 310,
                    child: LayoutBuilder(
                      builder: (context, fieldConstraints) =>
                          Autocomplete<MayoreoInvoiceClient>(
                            displayStringForOption: (client) => client.name,
                            optionsBuilder: (value) => clients.where(
                              (client) => client.name.toLowerCase().contains(
                                value.text.toLowerCase(),
                              ),
                            ),
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    MayoreoDialogOptions<MayoreoInvoiceClient>(
                                      options: options,
                                      label: (client) => client.name,
                                      onSelected: onSelected,
                                      width: fieldConstraints.maxWidth,
                                    ),
                            onSelected: (client) => setState(() {
                              _clientKey = client.key;
                              _clientQuery = client.name;
                              _page = 0;
                            }),
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focus,
                                  submit,
                                ) => TextField(
                                  controller: controller,
                                  focusNode: focus,
                                  autofocus: true,
                                  enabled: !_locked,
                                  decoration:
                                      mayoreoDialogFieldDecoration(
                                        context,
                                        label: 'Filtrar por cliente',
                                        hint: 'Todos los clientes',
                                        icon: Icons.business_outlined,
                                      ).copyWith(
                                        suffixIcon: controller.text.isEmpty
                                            ? null
                                            : IconButton(
                                                tooltip: 'Todos los clientes',
                                                onPressed: _locked
                                                    ? null
                                                    : () {
                                                        controller.clear();
                                                        setState(() {
                                                          _clientKey = null;
                                                          _clientQuery = '';
                                                          _page = 0;
                                                        });
                                                        focus.requestFocus();
                                                      },
                                                icon: const Icon(Icons.clear),
                                              ),
                                      ),
                                  onChanged: (value) => setState(() {
                                    _clientKey = null;
                                    _clientQuery = value;
                                    _page = 0;
                                  }),
                                  onSubmitted: (_) => submit(),
                                ),
                          ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: TextField(
                      controller: _ticketSearch,
                      enabled: !_locked,
                      decoration: mayoreoDialogFieldDecoration(
                        context,
                        label: 'Buscar boleta',
                        icon: Icons.search_rounded,
                      ),
                      onChanged: (_) => setState(() => _page = 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Todas')),
                    ButtonSegment(value: 1, label: Text('Usadas')),
                    ButtonSegment(value: 2, label: Text('Sin usar')),
                  ],
                  selected: {
                    _usedFilter == null
                        ? 0
                        : _usedFilter!
                        ? 1
                        : 2,
                  },
                  showSelectedIcon: false,
                  onSelectionChanged: _locked
                      ? null
                      : (value) => setState(() {
                          _usedFilter = value.single == 0
                              ? null
                              : value.single == 1;
                          _page = 0;
                        }),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Marca «Usada» para excluir una boleta. Al desmarcarla vuelve a estar disponible; '
            'su participación anterior queda en el historial.',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_pending case final pending?) {
                            unawaited(_setUsed(pending.ticket, pending.used));
                          } else {
                            setState(() => _error = null);
                            unawaited(_load());
                          }
                        },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_notice!),
          ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No hay boletas con estos filtros.'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final row = visible[index];
                    final ticket = row.ticket;
                    return MayoreoDialogRecordCard(
                      child: ExpansionTile(
                        key: ValueKey(row.key),
                        title: Text(
                          'Boleta ${ticket.ticket} · ${formatMoney(ticket.amountCents / 100)}',
                        ),
                        subtitle: Text(
                          '${ticket.clientName} · ${_date(ticket.saleDate)}\n${row.statusLabel}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Usada'),
                            const SizedBox(width: 4),
                            Semantics(
                              label:
                                  'Boleta ${ticket.ticket} de ${ticket.clientName}: usada',
                              child: Switch(
                                key: ValueKey('used-${row.key}'),
                                value: row.used,
                                onChanged: _locked
                                    ? null
                                    : (value) => _setUsed(row, value),
                              ),
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: ticket.details
                            .map(
                              (detail) => ListTile(
                                dense: true,
                                title: Text(
                                  '${detail['material'] ?? ''} · '
                                  '${formatMoney(((detail['amount_cents'] as num?) ?? 0) / 100)}',
                                ),
                                subtitle: Text(
                                  'Remisión: ${detail['remision'] ?? ''} · '
                                  'Peso: ${detail['approved_weight'] == null ? 'sin aprobar' : '${formatDecimal(detail['approved_weight'] as num)} kg'} · '
                                  'Precio: ${detail['approved_price'] == null ? 'sin aprobar' : formatMoney(detail['approved_price'] as num)}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} boletas · Página ${page + 1} de ${lastPage + 1}',
              ),
            ),
            IconButton(
              tooltip: 'Página anterior',
              onPressed: _locked || page == 0
                  ? null
                  : () => setState(() => _page = page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: _locked || page == lastPage
                  ? null
                  : () => setState(() => _page = page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
