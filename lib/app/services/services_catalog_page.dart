import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _stripAccents(String input) {
  const map = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'Ã': 'A',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'ç': 'c',
    'Ç': 'C',
  };

  final sb = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

String _normalizeName(String raw) {
  final noAccents = _stripAccents(raw).toUpperCase();
  return noAccents.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = _stripAccents(newValue.text).toUpperCase();
    text = text.replaceAll(RegExp(r'^\s+'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    final safeOffset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: safeOffset),
    );
  }
}

ButtonStyle _catalogPrimaryActionStyle() {
  return FilledButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withOpacity(0.34),
    side: BorderSide(color: Colors.white.withOpacity(0.72)),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withOpacity(0.30),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 2;
      if (states.contains(WidgetState.hovered)) return 7;
      return 0;
    }),
  );
}

class ServicesCatalogPage extends StatefulWidget {
  const ServicesCatalogPage({super.key});

  @override
  State<ServicesCatalogPage> createState() => _ServicesCatalogPageState();
}

class _ServicesCatalogPageState extends State<ServicesCatalogPage> {
  final supa = Supabase.instance.client;

  final TextEditingController _clientNameC = TextEditingController();
  final TextEditingController _materialNameC = TextEditingController();

  bool _loading = true;
  bool _savingClient = false;
  bool _savingMaterial = false;
  bool _changed = false;

  String? _defaultAreaId;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clientNameC.dispose();
    _materialNameC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        supa.from('areas').select('id,name').order('name'),
        supa
            .from('sites')
            .select('id,name,type')
            .eq('type', 'cliente')
            .order('name'),
        supa.from('materials').select('id,name,area_id').order('name'),
      ]);

      final areas = (res[0] as List).cast<Map<String, dynamic>>();
      final clients = (res[1] as List).cast<Map<String, dynamic>>();
      final materials = (res[2] as List).cast<Map<String, dynamic>>();

      String? defaultAreaId;
      if (areas.isNotEmpty) {
        final logistica = areas.firstWhere(
          (r) => (r['name']?.toString().toUpperCase() ?? '') == 'LOGISTICA',
          orElse: () => areas.first,
        );
        defaultAreaId = logistica['id']?.toString();
      }

      if (!mounted) return;
      setState(() {
        _defaultAreaId = defaultAreaId;
        _clients = clients;
        _materials = materials;
      });
    } catch (e) {
      _toast('No se pudo cargar catálogos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _clientExists(String normalized, {String? excludingId}) {
    for (final c in _clients) {
      final id = c['id']?.toString();
      if (excludingId != null && id == excludingId) continue;
      if (_normalizeName((c['name'] ?? '').toString()) == normalized) {
        return true;
      }
    }
    return false;
  }

  bool _materialExists(String normalized, {String? excludingId}) {
    for (final m in _materials) {
      final id = m['id']?.toString();
      if (excludingId != null && id == excludingId) continue;
      if (_normalizeName((m['name'] ?? '').toString()) == normalized) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addClient() async {
    final normalized = _normalizeName(_clientNameC.text);
    if (normalized.isEmpty) {
      _toast('Escribe el nombre de la empresa');
      return;
    }
    if (_clientExists(normalized)) {
      _toast('La empresa ya existe');
      return;
    }
    setState(() => _savingClient = true);
    try {
      await supa.from('sites').insert({'name': normalized, 'type': 'cliente'});
      _clientNameC.clear();
      _changed = true;
      _toast('Empresa agregada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar empresa: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingClient = false);
    }
  }

  Future<void> _addMaterial() async {
    final normalized = _normalizeName(_materialNameC.text);
    if (normalized.isEmpty) {
      _toast('Escribe el nombre del material');
      return;
    }
    if (_materialExists(normalized)) {
      _toast('El material ya existe');
      return;
    }

    setState(() => _savingMaterial = true);
    try {
      final payload = <String, dynamic>{'name': normalized};
      if (_defaultAreaId != null) {
        payload['area_id'] = _defaultAreaId;
      }
      await supa.from('materials').insert(payload);
      _materialNameC.clear();
      _changed = true;
      _toast('Material agregado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar material: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingMaterial = false);
    }
  }

  Future<void> _editClient(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final input = TextEditingController(
      text: _normalizeName('${row['name'] ?? ''}'),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Empresa'),
        content: TextField(
          controller: input,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.singleLineFormatter,
            _NameInputFormatter(),
          ],
          decoration: const InputDecoration(hintText: 'Nombre'),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, _normalizeName(input.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _normalizeName(input.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    input.dispose();

    if (newName == null) return;
    if (newName.isEmpty) {
      _toast('El nombre no puede estar vacío');
      return;
    }
    if (_clientExists(newName, excludingId: id)) {
      _toast('La empresa ya existe');
      return;
    }

    try {
      await supa.from('sites').update({'name': newName}).eq('id', id);
      _changed = true;
      _toast('Empresa actualizada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar empresa: ${e.message}');
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final name = '${row['name'] ?? ''}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Empresa'),
        content: Text('¿Seguro que deseas eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await supa.from('sites').delete().eq('id', id);
      _changed = true;
      _toast('Empresa eliminada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo eliminar empresa: ${e.message}');
    }
  }

  Future<void> _editMaterial(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final input = TextEditingController(
      text: _normalizeName('${row['name'] ?? ''}'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Material'),
        content: TextField(
          controller: input,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.singleLineFormatter,
            _NameInputFormatter(),
          ],
          decoration: const InputDecoration(hintText: 'Nombre'),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, _normalizeName(input.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _normalizeName(input.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    input.dispose();

    if (result == null) return;
    final newName = result;
    if (newName.isEmpty) {
      _toast('El nombre no puede estar vacío');
      return;
    }
    if (_materialExists(newName, excludingId: id)) {
      _toast('El material ya existe');
      return;
    }

    try {
      await supa.from('materials').update({'name': newName}).eq('id', id);
      _changed = true;
      _toast('Material actualizado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar material: ${e.message}');
    }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final name = '${row['name'] ?? ''}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Material'),
        content: Text('¿Seguro que deseas eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await supa.from('materials').delete().eq('id', id);
      _changed = true;
      _toast('Material eliminado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo eliminar material: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withOpacity(0.42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.62)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.62)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF2A9D8F).withOpacity(0.88),
          width: 1.2,
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.42)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Catálogo Global de Operaciones',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E2B2B),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Cerrar',
                                  onPressed: () =>
                                      Navigator.pop(context, _changed),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _GlassCard(
                                      title: 'Empresas (CLIENTE)',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller: _clientNameC,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .singleLineFormatter,
                                              _NameInputFormatter(),
                                            ],
                                            decoration: fieldDecoration
                                                .copyWith(
                                                  hintText:
                                                      'Nombre de la empresa',
                                                ),
                                            onSubmitted: (_) => _addClient(),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: 190,
                                            child: FilledButton.icon(
                                              style:
                                                  _catalogPrimaryActionStyle(),
                                              onPressed: _savingClient
                                                  ? null
                                                  : _addClient,
                                              icon: _savingClient
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.add_business,
                                                    ),
                                              label: const Text(
                                                'Agregar Empresa',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Expanded(
                                            child: _CatalogList(
                                              rows: _clients,
                                              emptyText: 'Sin empresas',
                                              subtitleOf: (_) => null,
                                              onEdit: _editClient,
                                              onDelete: _deleteClient,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _GlassCard(
                                      title: 'Materiales',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller: _materialNameC,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .singleLineFormatter,
                                              _NameInputFormatter(),
                                            ],
                                            decoration: fieldDecoration
                                                .copyWith(
                                                  hintText:
                                                      'Nombre del material',
                                                ),
                                            onSubmitted: (_) => _addMaterial(),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: 190,
                                            child: FilledButton.icon(
                                              style:
                                                  _catalogPrimaryActionStyle(),
                                              onPressed: _savingMaterial
                                                  ? null
                                                  : _addMaterial,
                                              icon: _savingMaterial
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.playlist_add_check,
                                                    ),
                                              label: const Text(
                                                'Agregar Material',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Expanded(
                                            child: _CatalogList(
                                              rows: _materials,
                                              emptyText: 'Sin materiales',
                                              subtitleOf: (_) => null,
                                              onEdit: _editMaterial,
                                              onDelete: _deleteMaterial,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F6F8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD1D9DE),
                                ),
                              ),
                              child: const Text(
                                'Formato de captura: MAYÚSCULAS, sin acentos y sin espacios al inicio o al final.',
                                style: TextStyle(
                                  color: Color(0xFF314747),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final String? Function(Map<String, dynamic>) subtitleOf;
  final Future<void> Function(Map<String, dynamic> row) onEdit;
  final Future<void> Function(Map<String, dynamic> row) onDelete;

  const _CatalogList({
    required this.rows,
    required this.emptyText,
    required this.subtitleOf,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: Color(0xFF345454)));
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) =>
          Divider(color: Colors.white.withOpacity(0.55)),
      itemBuilder: (_, i) {
        final row = rows[i];
        final title = (row['name'] ?? '').toString();
        final subtitle = subtitleOf(row);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0B2B2B),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF325454),
                    fontWeight: FontWeight.w600,
                  ),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar',
                onPressed: () => onEdit(row),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => onDelete(row),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _GlassCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2B2B),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
