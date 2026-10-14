import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_widgets.dart';

/// Global title search uses the same record detail and area permissions as the
/// category workspaces. Its state never replaces the dashboard or its metrics.
class DocumentalDashboardSearch extends StatefulWidget {
  final Future<void> Function(DocumentalRecord) onOpen;
  const DocumentalDashboardSearch({super.key, required this.onOpen});

  @override
  State<DocumentalDashboardSearch> createState() =>
      _DocumentalDashboardSearchState();
}

class _DocumentalDashboardSearchState extends State<DocumentalDashboardSearch> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  DocumentalRepository? _repository;
  StreamSubscription<void>? _subscription;
  Timer? _debounce;
  DocumentalResultPage? _result;
  String? _error, _openingId;
  bool _loading = false;
  int _generation = 0, _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = DocumentalRepositoryScope.of(context);
    if (identical(repository, _repository)) return;
    _subscription?.cancel();
    _repository = repository;
    _subscription = repository.changes.listen((_) => _refresh());
    if (_text.text.trim().isNotEmpty) _changed();
  }

  void _changed() {
    _debounce?.cancel();
    _generation++; // Invalidate previous responses immediately, before debounce.
    setState(() {
      _result = null;
      _error = null;
      _page = 0;
      _loading = _text.text.trim().isNotEmpty;
    });
    if (_loading) {
      _debounce = Timer(const Duration(milliseconds: 250), () => _search());
    }
  }

  Future<void> _refresh() async {
    if (_openingId != null || _debounce?.isActive == true) return;
    await _search(page: _page);
  }

  Future<void> _search({int page = 0}) async {
    final query = _text.text.trim();
    if (query.isEmpty || !mounted || _openingId != null) return;
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository!
          .searchByTitle(query, page: page)
          .timeout(const Duration(seconds: 30));
      if (!mounted || generation != _generation) return;
      if (page > 0 && result.records.isEmpty) {
        await _search();
        return;
      }
      setState(() {
        _result = result;
        _page = page;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = null;
        _error = documentalErrorMessage(error);
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(DocumentalRecord record) async {
    if (_openingId != null || _loading) return;
    _generation++;
    setState(() {
      _openingId = record.id;
      _loading = false;
    });
    try {
      await widget.onOpen(record);
    } finally {
      if (mounted) {
        setState(() => _openingId = null);
        await _refresh();
      }
    }
  }

  void _clear() {
    _text.clear();
    _changed();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _subscription?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final result = _result;
    return LifecycleRefreshScope(
      onResume: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  _text.text.isNotEmpty) {
                _clear();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              key: const ValueKey('documental-dashboard-search'),
              controller: _text,
              focusNode: _focus,
              readOnly: _openingId != null,
              onChanged: (_) => _changed(),
              onSubmitted: (_) {
                if (!_loading && result?.records.length == 1) {
                  _open(result!.records.single);
                } else {
                  _search();
                }
              },
              decoration: InputDecoration(
                labelText: 'Buscar documento por nombre',
                hintText: 'Escribe el nombre del documento…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: _openingId == null ? _clear : null,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (result != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                result.total == 0
                    ? 'No se encontraron documentos con ese nombre.'
                    : '${result.total} ${result.total == 1 ? 'documento encontrado' : 'documentos encontrados'}',
                style: TextStyle(color: t.onGlass, fontWeight: FontWeight.w700),
              ),
            ),
            if (result.records.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: result.total > documentalSearchPageSize ? 360 : 0,
                  maxHeight: 360,
                ),
                child: ListView.separated(
                  primary: false,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(4),
                  itemCount: result.records.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = result.records[index];
                    final category = documentalCategories.firstWhere(
                      (category) => category.key == record.kind.key,
                    );
                    return DocumentalActionCard(
                      key: ValueKey('documental-search-result-${record.id}'),
                      label: 'Abrir ${record.title} · ${category.title}',
                      padding: const EdgeInsets.all(12),
                      onTap: () => _open(record),
                      child: Row(
                        children: [
                          Icon(category.icon, color: t.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.title,
                                  style: TextStyle(
                                    color: t.onGlass,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    category.title,
                                    if (record.reference.isNotEmpty)
                                      record.reference,
                                    record.status,
                                  ].join(' · '),
                                  style: TextStyle(
                                    color: t.primarySoft,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _openingId == record.id
                                ? Icons.hourglass_top_rounded
                                : Icons.open_in_new_rounded,
                            color: t.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (result.total > documentalSearchPageSize)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _page > 0 && !_loading && _openingId == null
                          ? () => _search(page: _page - 1)
                          : null,
                      child: const Text('Anterior'),
                    ),
                    Text(
                      'Página ${_page + 1} de ${(result.total / documentalSearchPageSize).ceil()}',
                      style: TextStyle(color: t.onGlass),
                    ),
                    TextButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed:
                          (_page + 1) * documentalSearchPageSize <
                                  result.total &&
                              !_loading &&
                              _openingId == null
                          ? () => _search(page: _page + 1)
                          : null,
                      child: const Text('Siguiente'),
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
