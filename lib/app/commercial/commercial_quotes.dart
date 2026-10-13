import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/utils/fetch_all_supabase_rows.dart';
import '../shared/utils/number_formatters.dart';
import 'commercial_store.dart';
import 'commercial_theme.dart';

const commercialQuoteStatuses = <String, String>{
  'borrador': 'Borrador',
  'enviada': 'Enviada',
  'aceptada': 'Aceptada',
  'rechazada': 'Rechazada',
  'cancelada': 'Cancelada',
};
const commercialQuoteUnits = ['KG', 'PZA', 'TON'];
String commercialDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class CommercialQuoteLine {
  final String material, unit;
  final double quantity, price;
  const CommercialQuoteLine({
    required this.material,
    required this.unit,
    required this.quantity,
    required this.price,
  });
  double get amount => quantity * price;
  Map<String, dynamic> toJson() => {
    'material': material.trim(),
    'unit': unit,
    'quantity': quantity,
    'price': price,
  };
  factory CommercialQuoteLine.fromRow(Map<String, dynamic> row) =>
      CommercialQuoteLine(
        material: row['material'].toString(),
        unit: row['unit'].toString(),
        quantity: (row['quantity'] as num).toDouble(),
        price: (row['price'] as num).toDouble(),
      );
}

class CommercialQuote {
  final String? id;
  final String accountId, status, notes;
  final DateTime date, validUntil;
  final List<CommercialQuoteLine> lines;
  const CommercialQuote({
    this.id,
    required this.accountId,
    required this.status,
    required this.notes,
    required this.date,
    required this.validUntil,
    required this.lines,
  });
  double get total => lines.fold<double>(0, (sum, line) => sum + line.amount);
  bool expired(DateTime now) =>
      !['aceptada', 'rechazada', 'cancelada'].contains(status) &&
      validUntil.isBefore(DateTime(now.year, now.month, now.day));
  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'status': status,
    'notes': notes.trim(),
    'quotation_date': date.toIso8601String().substring(0, 10),
    'valid_until': validUntil.toIso8601String().substring(0, 10),
    'items': lines.map((row) => row.toJson()).toList(),
  };
  factory CommercialQuote.fromRow(Map<String, dynamic> row) => CommercialQuote(
    id: row['id'].toString(),
    accountId: row['account_id'].toString(),
    status: row['status'].toString(),
    notes: (row['notes'] ?? '').toString(),
    date: DateTime.parse(row['quotation_date'].toString()),
    validUntil: DateTime.parse(row['valid_until'].toString()),
    lines: (row['items'] as List)
        .map(
          (line) => CommercialQuoteLine.fromRow(
            Map<String, dynamic>.from(line as Map),
          ),
        )
        .toList(),
  );
}

class CommercialQuotesStore {
  static Future<List<CommercialQuote>> load(String accountId) async {
    if (accountId.contains('|')) return [];
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from('commercial_quotes')
          .select()
          .eq('account_id', accountId)
          .order('quotation_date', ascending: false)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return rows.map(CommercialQuote.fromRow).toList();
  }

  static Future<void> save(CommercialQuote quote) async {
    if (!commercialQuoteStatuses.containsKey(quote.status) ||
        quote.lines.isEmpty ||
        !quote.total.isFinite ||
        quote.validUntil.isBefore(DateUtils.dateOnly(quote.date)) ||
        quote.lines.any(
          (line) =>
              line.material.trim().isEmpty ||
              !commercialQuoteUnits.contains(line.unit) ||
              !line.quantity.isFinite ||
              line.quantity <= 0 ||
              !line.price.isFinite ||
              line.price < 0,
        )) {
      throw ArgumentError(
        'Revisa los materiales, cantidades, precios y vigencia de la cotización.',
      );
    }
    final table = Supabase.instance.client.from('commercial_quotes');
    if (quote.id == null) {
      await table.insert(quote.toJson());
    } else {
      final saved = await table
          .update(quote.toJson())
          .eq('id', quote.id!)
          .eq('account_id', quote.accountId)
          .select('id');
      if (saved.isEmpty) {
        throw StateError('La cotización ya no está disponible.');
      }
    }
  }

  static Future<List<String>> materials(String channel) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => Supabase.instance.client
          .from(
            channel == 'menudeo'
                ? 'material_commercial_catalog_v2'
                : 'mayoreo_material_catalog',
          )
          .select()
          .order('name')
          .order('id')
          .range(from, to),
    );
    return rows
        .map((row) => (row['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

class CommercialAccountQuotes extends StatefulWidget {
  final CommercialDirectoryAccountRecord account;
  final Future<void> Function(String accountId) onAccountResolved;
  const CommercialAccountQuotes({
    super.key,
    required this.account,
    required this.onAccountResolved,
  });
  @override
  State<CommercialAccountQuotes> createState() =>
      _CommercialAccountQuotesState();
}

class _CommercialAccountQuotesState extends State<CommercialAccountQuotes> {
  late Future<List<CommercialQuote>> _future;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _future = CommercialQuotesStore.load(widget.account.id);
  }

  Future<void> edit([CommercialQuote? quote]) async {
    if (_saving) return;
    final draft = await showDialog<CommercialQuote>(
      context: context,
      builder: (_) =>
          CommercialQuoteDialog(account: widget.account, initial: quote),
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      // Create only the commercial overlay; operational catalog entries are read-only.
      final account = widget.account;
      final accountId = account.id.contains('|')
          ? await CommercialStore.saveAccountOverlay(
              row: account,
              status: account.status,
              priority: account.priority,
              notes: account.notes,
            )
          : account.id;
      await CommercialQuotesStore.save(
        CommercialQuote(
          id: draft.id,
          accountId: accountId,
          status: draft.status,
          notes: draft.notes,
          date: draft.date,
          validUntil: draft.validUntil,
          lines: draft.lines,
        ),
      );
      if (!mounted) return;
      setState(() {
        _future = CommercialQuotesStore.load(accountId);
      });
      await widget.onAccountResolved(accountId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cotización guardada.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la cotización. Revisa la conexión e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Cotizaciones · ${widget.account.displayName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva cotización'),
          ),
        ],
      ),
      if (_saving) const LinearProgressIndicator(),
      const SizedBox(height: 12),
      Expanded(
        child: FutureBuilder<List<CommercialQuote>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudieron cargar las cotizaciones.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _future = CommercialQuotesStore.load(widget.account.id);
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                child: Text('Esta cuenta todavía no tiene cotizaciones.'),
              );
            }
            return ListView.separated(
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quote = snapshot.data![index];
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      '${commercialDate(quote.date)} · ${quote.lines.first.material}${quote.lines.length > 1 ? ' +${quote.lines.length - 1}' : ''}',
                    ),
                    subtitle: Text(
                      '${commercialQuoteStatuses[quote.status]}${quote.expired(DateTime.now()) ? ' · Vigencia vencida' : ''} · ${formatMoney(quote.total)}\nVigente hasta ${commercialDate(quote.validUntil)}',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      for (final line in quote.lines)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(line.material),
                          subtitle: Text(
                            '${line.quantity} ${line.unit} × ${formatMoney(line.price)}',
                          ),
                          trailing: Text(formatMoney(line.amount)),
                        ),
                      if (quote.notes.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(quote.notes),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _saving ? null : () => edit(quote),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar cotización'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _QuoteLineDraft {
  final TextEditingController material, quantity, price;
  String unit;
  _QuoteLineDraft([CommercialQuoteLine? line])
    : material = TextEditingController(text: line?.material ?? ''),
      quantity = TextEditingController(text: line?.quantity.toString() ?? ''),
      price = TextEditingController(text: line?.price.toString() ?? ''),
      unit = line?.unit ?? 'KG';
  CommercialQuoteLine get value => CommercialQuoteLine(
    material: material.text.trim(),
    unit: unit,
    quantity: double.tryParse(quantity.text.replaceAll(',', '')) ?? 0,
    price: double.tryParse(price.text.replaceAll(',', '')) ?? -1,
  );
  void dispose() {
    material.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class CommercialQuoteDialog extends StatefulWidget {
  final CommercialDirectoryAccountRecord account;
  final CommercialQuote? initial;
  const CommercialQuoteDialog({super.key, required this.account, this.initial});
  @override
  State<CommercialQuoteDialog> createState() => _CommercialQuoteDialogState();
}

class _CommercialQuoteDialogState extends State<CommercialQuoteDialog> {
  final _form = GlobalKey<FormState>();
  late List<_QuoteLineDraft> _lines;
  late TextEditingController _notes;
  late DateTime _date, _until;
  late String _status;
  List<String> _materials = [];
  bool _showValidation = false;
  @override
  void initState() {
    super.initState();
    final quote = widget.initial;
    _lines = quote == null
        ? [_QuoteLineDraft()]
        : quote.lines.map(_QuoteLineDraft.new).toList();
    _notes = TextEditingController(text: quote?.notes ?? '');
    _date = quote?.date ?? DateUtils.dateOnly(DateTime.now());
    _until = quote?.validUntil ?? _date.add(const Duration(days: 15));
    _status = quote?.status ?? 'borrador';
    CommercialQuotesStore.materials(widget.account.channel)
        .then((rows) {
          if (mounted) setState(() => _materials = rows);
        })
        .catchError((_) {
          /* Existing snapshots can still be edited when suggestions are unavailable. */
        });
  }

  @override
  void dispose() {
    for (final row in _lines) {
      row.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  void save() {
    if (!_form.currentState!.validate()) {
      setState(() => _showValidation = true);
      return;
    }
    Navigator.pop(
      context,
      CommercialQuote(
        id: widget.initial?.id,
        accountId: widget.account.id,
        status: _status,
        notes: _notes.text,
        date: _date,
        validUntil: _until,
        lines: _lines.map((row) => row.value).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: buildCommercialAreaTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AlertDialog(
        title: Text(
          widget.initial == null ? 'Nueva cotización' : 'Editar cotización',
        ),
        content: SizedBox(
          width: 780,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              autovalidateMode: _showValidation
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.account.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _date = picked;
                              if (_until.isBefore(_date)) _until = _date;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Fecha: ${commercialDate(_date)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _until,
                            firstDate: _date,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && mounted) {
                            setState(() => _until = picked);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text('Vigencia: ${commercialDate(_until)}'),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Estatus',
                          ),
                          items: commercialQuoteStatuses.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _status = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final line in _lines)
                    Padding(
                      key: ObjectKey(line),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: line.material,
                            autofocus: line == _lines.first,
                            decoration: InputDecoration(
                              labelText: 'Material',
                              suffixIcon: IconButton(
                                tooltip: 'Elegir material del catálogo',
                                onPressed: _materials.isEmpty
                                    ? null
                                    : () async {
                                        final picked = await showSearch<String>(
                                          context: context,
                                          delegate: _MaterialSearch(_materials),
                                        );
                                        if (picked != null &&
                                            picked.isNotEmpty &&
                                            mounted) {
                                          setState(
                                            () => line.material.text = picked,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.search),
                              ),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Captura el material'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: line.quantity,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Cantidad',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (_) =>
                                      !line.value.quantity.isFinite ||
                                          line.value.quantity <= 0
                                      ? 'Cantidad mayor a cero'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                // Reserve room for the label, field padding and arrow.
                                width:
                                    72 +
                                    MediaQuery.textScalerOf(context).scale(48),
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: line.unit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unidad',
                                  ),
                                  items: commercialQuoteUnits
                                      .map(
                                        (unit) => DropdownMenuItem(
                                          value: unit,
                                          child: Text(unit),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => line.unit = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: line.price,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Precio unitario',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (_) =>
                                      !line.value.price.isFinite ||
                                          line.value.price < 0 ||
                                          !line.value.amount.isFinite
                                      ? 'Precio válido requerido'
                                      : null,
                                ),
                              ),
                              if (_lines.length > 1)
                                IconButton(
                                  tooltip: 'Quitar material',
                                  onPressed: () {
                                    setState(() => _lines.remove(line));
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          line.dispose();
                                        });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _lines.add(_QuoteLineDraft())),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar material'),
                    ),
                  ),
                  Text(
                    'Total: ${formatMoney(_lines.fold<double>(0, (sum, row) => sum + (row.value.price >= 0 && row.value.quantity > 0 && row.value.amount.isFinite ? row.value.amount : 0)))}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: commercialAreaTokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Comentarios'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: save,
            child: const Text('Guardar cotización'),
          ),
        ],
      ),
    ),
  );
}

class _MaterialSearch extends SearchDelegate<String> {
  final List<String> materials;
  _MaterialSearch(this.materials) : super(searchFieldLabel: 'Buscar material');
  @override
  ThemeData appBarTheme(BuildContext context) =>
      buildCommercialAreaTheme(Theme.of(context));
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) {
    final rows = materials
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(rows[index]),
        onTap: () => close(context, rows[index]),
      ),
    );
  }
}
