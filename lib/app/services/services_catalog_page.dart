import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
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

String _commercialMaterialCodeFromName(String raw) {
  final normalized = _normalizeName(raw);
  final underscored = normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  return underscored
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _inventoryMaterialCodeFromGeneralName(String raw) {
  final normalized = _normalizeName(raw);
  switch (normalized) {
    case 'CARTON NACIONAL':
    case 'CARTON CELANESE':
    case 'GRANEL NACIONAL':
      return 'CARDBOARD_BULK_NATIONAL';
    case 'CARTON AMERICANO':
    case 'GRANEL AMERICANO':
      return 'CARDBOARD_BULK_AMERICAN';
    case 'PACA NACIONAL':
      return 'BALE_NATIONAL';
    case 'PACA AMERICANA':
      return 'BALE_AMERICAN';
    case 'PACA LIMPIA':
      return 'BALE_CLEAN';
    case 'PACA BASURA':
      return 'BALE_TRASH';
    case 'CHATARRA':
    case 'SCRAP':
      return 'SCRAP';
    case 'METAL':
      return 'METAL';
    case 'MADERA':
      return 'WOOD';
    case 'PAPEL':
      return 'PAPER';
    case 'PLASTICO':
      return 'PLASTIC';
    default:
      return _commercialMaterialCodeFromName(normalized);
  }
}

const String _kOpeningTemplateSite = 'DICSA';

const List<_OpMaterialOpt> _kOpeningTemplateMaterials = [
  _OpMaterialOpt('CARDBOARD_BULK_NATIONAL', 'Granel nacional'),
  _OpMaterialOpt('CARDBOARD_BULK_AMERICAN', 'Granel americano'),
  _OpMaterialOpt('BALE_NATIONAL', 'Paca nacional'),
  _OpMaterialOpt('BALE_AMERICAN', 'Paca americana'),
  _OpMaterialOpt('BALE_CLEAN', 'Paca limpia'),
  _OpMaterialOpt('BALE_TRASH', 'Paca basura'),
  _OpMaterialOpt('SCRAP', 'Chatarra'),
  _OpMaterialOpt('METAL', 'Metal'),
  _OpMaterialOpt('WOOD', 'Madera'),
  _OpMaterialOpt('PAPER', 'Papel'),
  _OpMaterialOpt('PLASTIC', 'Plástico'),
];

List<Map<String, dynamic>> _sortCatalogRowsByName(
  List<Map<String, dynamic>> rows, {
  String field = 'name',
}) {
  final out = List<Map<String, dynamic>>.from(rows);
  out.sort((a, b) {
    final an = _normalizeName((a[field] ?? '').toString());
    final bn = _normalizeName((b[field] ?? '').toString());
    final byName = an.compareTo(bn);
    if (byName != 0) return byName;
    final aid = (a['id'] ?? a['code'] ?? '').toString();
    final bid = (b['id'] ?? b['code'] ?? '').toString();
    return aid.compareTo(bid);
  });
  return out;
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

class _CatalogPickerOption<T> {
  final T value;
  final String label;
  const _CatalogPickerOption({required this.value, required this.label});
}

ButtonStyle _catalogPrimaryActionStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
    side: BorderSide(color: const Color(0xFF4F8E8C).withValues(alpha: 0.45)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _catalogSecondaryActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.52)),
    backgroundColor: Colors.white.withValues(alpha: 0.18),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

const Color _kCatalogTableGlassMenuBg = Color(0xE6EAF2F9);
const Color _kCatalogTableFilterAccent = Color(0xFF4F8E8C);
const Color _kCatalogTableFilterAccentSoft = Color(0xFFE2EEEC);
const Color _kCatalogTableSelectionAccent = Color(0xFF153B66);

InputDecoration _catalogContractGlassFieldDecoration({String? hintText}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: Colors.white.withValues(alpha: 0.58),
      width: 1,
    ),
  );

  return InputDecoration(
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: _kCatalogTableSelectionAccent.withValues(alpha: 0.8),
        width: 1.2,
      ),
    ),
  );
}

BoxDecoration _catalogFilterDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.62),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
  );
}

ButtonStyle _catalogFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withValues(alpha: 0.25)),
    backgroundColor: Colors.white.withValues(alpha: 0.40),
  );
}

ButtonStyle _catalogFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _kCatalogTableFilterAccent,
    foregroundColor: Colors.white,
  );
}

InputDecoration _catalogEditDialogFieldDecoration({
  String? labelText,
  String? hintText,
  bool alwaysFloatLabel = false,
}) {
  return _catalogContractGlassFieldDecoration(hintText: hintText).copyWith(
    labelText: labelText,
    floatingLabelBehavior: alwaysFloatLabel
        ? FloatingLabelBehavior.always
        : null,
  );
}

Widget _catalogGlassDialogScaffold({
  required String title,
  required Widget child,
  double maxWidth = 560,
  double? maxHeight,
}) {
  final constraints = maxHeight == null
      ? BoxConstraints(maxWidth: maxWidth)
      : BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight);
  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: constraints,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: _catalogFilterDialogDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2B2B),
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _catalogInputPanel({required Widget child}) {
  return Card(
    elevation: 0.4,
    color: const Color(0xFFE7F1F8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.40)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    ),
  );
}

Future<T?> _showCatalogSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<_CatalogPickerOption<T>> options,
  T? initialValue,
}) {
  final searchC = TextEditingController();
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      T? highlighted =
          initialValue ?? (options.isEmpty ? null : options.first.value);
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final q = _normalizeName(searchC.text);
          final visible = options
              .where((o) => q.isEmpty || _normalizeName(o.label).contains(q))
              .toList(growable: false);
          final listHeight = visible.isEmpty
              ? 120.0
              : ((visible.length * 58.0) + 8.0).clamp(120.0, 470.0).toDouble();
          highlighted = visible.any((o) => o.value == highlighted)
              ? highlighted
              : (visible.isEmpty ? null : visible.first.value);

          return _catalogGlassDialogScaffold(
            title: title,
            maxWidth: 460,
            maxHeight: 640,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                final currentIndex = visible.indexWhere(
                  (o) => o.value == highlighted,
                );
                if (key == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown && visible.isNotEmpty) {
                  final next = currentIndex < 0
                      ? 0
                      : (currentIndex + 1).clamp(0, visible.length - 1);
                  setLocalState(() => highlighted = visible[next].value);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp && visible.isNotEmpty) {
                  final next = currentIndex < 0
                      ? 0
                      : (currentIndex - 1).clamp(0, visible.length - 1);
                  setLocalState(() => highlighted = visible[next].value);
                  return KeyEventResult.handled;
                }
                if ((key == LogicalKeyboardKey.enter ||
                        key == LogicalKeyboardKey.numpadEnter ||
                        key == LogicalKeyboardKey.space) &&
                    highlighted != null) {
                  Navigator.pop(dialogContext, highlighted);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchC,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.singleLineFormatter,
                      _NameInputFormatter(),
                    ],
                    onChanged: (_) => setLocalState(() {}),
                    decoration:
                        _catalogContractGlassFieldDecoration(
                          hintText: 'Buscar',
                        ).copyWith(
                          fillColor: const Color(
                            0xFFF5FBFF,
                          ).withValues(alpha: 0.70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF2FA8FF),
                              width: 1.15,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF2FA8FF),
                              width: 1.35,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF2FA8FF),
                              width: 1.15,
                            ),
                          ),
                          hintStyle: const TextStyle(
                            color: Color(0xFF8A989E),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: listHeight,
                    child: visible.isEmpty
                        ? const Center(child: Text('Sin valores para mostrar'))
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final option = visible[i];
                              final isSelected = option.value == initialValue;
                              final isHighlighted = option.value == highlighted;
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () =>
                                    Navigator.pop(dialogContext, option.value),
                                onHover: (v) {
                                  if (v) {
                                    setLocalState(
                                      () => highlighted = option.value,
                                    );
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHighlighted
                                        ? const Color(
                                            0xFFBFD8EE,
                                          ).withValues(alpha: 0.34)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isHighlighted
                                          ? const Color(0xFF2F86FF)
                                          : Colors.transparent,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? const Color(0xFF19C37D)
                                                : const Color(0xFF1C2326),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF1D77FF),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(searchC.dispose);
}

class _CatalogPickerField<T> extends StatelessWidget {
  final FocusNode? focusNode;
  final String label;
  final String valueLabel;
  final String dialogTitle;
  final List<_CatalogPickerOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  const _CatalogPickerField({
    required this.label,
    required this.valueLabel,
    required this.dialogTitle,
    required this.options,
    required this.value,
    required this.onChanged,
    this.focusNode,
  });

  Future<void> _open(BuildContext context) async {
    final selected = await _showCatalogSearchablePickerDialog<T>(
      context,
      title: dialogTitle,
      options: options,
      initialValue: value,
    );
    if (selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: InputDecorator(
          decoration: _catalogContractGlassFieldDecoration().copyWith(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  valueLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202628),
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

enum OperationsCatalogModule { all, flotilla, empresas, materiales }

class ServicesCatalogPage extends StatefulWidget {
  final OperationsCatalogModule module;

  const ServicesCatalogPage({
    super.key,
    this.module = OperationsCatalogModule.all,
  });

  @override
  State<ServicesCatalogPage> createState() => _ServicesCatalogPageState();
}

class _ServicesCatalogPageState extends State<ServicesCatalogPage> {
  final supa = Supabase.instance.client;

  final TextEditingController _clientNameC = TextEditingController();
  final TextEditingController _materialNameC = TextEditingController();
  final TextEditingController _driverNameC = TextEditingController();
  final TextEditingController _vehicleCodeC = TextEditingController();
  final TextEditingController _commercialMaterialNameC =
      TextEditingController();
  final TextEditingController _openingTemplateSortOrderC =
      TextEditingController(text: '100');
  final FocusNode _commercialInsertNameFocus = FocusNode(
    debugLabel: 'commercial_insert_name',
  );
  final FocusNode _commercialInsertMaterialFocus = FocusNode(
    debugLabel: 'commercial_insert_material',
  );
  final FocusNode _commercialFilterMaterialFocus = FocusNode(
    debugLabel: 'commercial_filter_material',
  );
  final FocusNode _openingInsertMaterialFocus = FocusNode(
    debugLabel: 'opening_insert_material',
  );
  final FocusNode _openingInsertSortFocus = FocusNode(
    debugLabel: 'opening_insert_sort',
  );
  final FocusNode _openingInsertCommercialFocus = FocusNode(
    debugLabel: 'opening_insert_commercial',
  );

  bool _loading = true;
  bool _savingClient = false;
  bool _savingMaterial = false;
  bool _savingDriver = false;
  bool _savingVehicle = false;
  bool _savingCommercialMaterial = false;
  bool _savingOpeningTemplate = false;
  bool _changed = false;

  String? _defaultAreaId;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _commercialMaterials = [];
  List<Map<String, dynamic>> _openingTemplates = [];
  String _openingTemplateMaterial = _kOpeningTemplateMaterials.first.value;
  String? _openingTemplateCommercialCode;
  String? _commercialMaterialFilterMaterialId;
  String? _commercialMaterialDraftMaterialId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clientNameC.dispose();
    _materialNameC.dispose();
    _driverNameC.dispose();
    _vehicleCodeC.dispose();
    _commercialMaterialNameC.dispose();
    _openingTemplateSortOrderC.dispose();
    _commercialInsertNameFocus.dispose();
    _commercialInsertMaterialFocus.dispose();
    _commercialFilterMaterialFocus.dispose();
    _openingInsertMaterialFocus.dispose();
    _openingInsertSortFocus.dispose();
    _openingInsertCommercialFocus.dispose();
    super.dispose();
  }

  List<FocusNode> get _commercialInsertFocusOrder => <FocusNode>[
    _commercialInsertNameFocus,
    _commercialInsertMaterialFocus,
    _commercialFilterMaterialFocus,
  ];

  List<FocusNode> get _openingInsertFocusOrder => <FocusNode>[
    _openingInsertMaterialFocus,
    _openingInsertSortFocus,
    _openingInsertCommercialFocus,
  ];

  int _focusedIndexIn(List<FocusNode> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].hasFocus) return i;
    }
    return -1;
  }

  void _moveInsertFocus(List<FocusNode> nodes, int delta) {
    if (nodes.isEmpty) return;
    final current = _focusedIndexIn(nodes);
    final next = current < 0
        ? 0
        : (((current + delta) % nodes.length) + nodes.length) % nodes.length;
    nodes[next].requestFocus();
  }

  String _materialLabelById(String? id, {String emptyLabel = 'Seleccionar'}) {
    if (id == null || id.isEmpty) return emptyLabel;
    final match = _materials.cast<Map<String, dynamic>?>().firstWhere(
      (m) => (m?['id'] ?? '').toString() == id,
      orElse: () => null,
    );
    final label = (match?['name'] ?? '').toString();
    return label.isEmpty ? emptyLabel : label;
  }

  Future<void> _openCommercialInsertMaterialPicker() async {
    final options = _materials
        .map(
          (m) => _CatalogPickerOption<String?>(
            value: m['id']?.toString(),
            label: (m['name'] ?? '').toString(),
          ),
        )
        .toList(growable: false);
    final selected = await _showCatalogSearchablePickerDialog<String?>(
      context,
      title: 'Seleccionar',
      options: options,
      initialValue: _commercialMaterialDraftMaterialId,
    );
    if (!mounted || selected == null) return;
    setState(() => _commercialMaterialDraftMaterialId = selected);
  }

  Future<void> _openCommercialFilterMaterialPicker() async {
    final searchC = TextEditingController();
    String? draftSelected = _commercialMaterialFilterMaterialId;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final query = _normalizeName(searchC.text);
          final visibleMaterials = _materials
              .where((m) {
                final label = _normalizeName((m['name'] ?? '').toString());
                return query.isEmpty || label.contains(query);
              })
              .toList(growable: false);

          void applyAndClose() {
            Navigator.pop(dialogContext, {'selected': draftSelected});
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  applyAndClose();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _catalogFilterDialogDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filtro: MATERIAL GENERAL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2B2B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchC,
                          autofocus: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter,
                            _NameInputFormatter(),
                          ],
                          onChanged: (_) => setLocalState(() {}),
                          onSubmitted: (_) => applyAndClose(),
                          decoration: _catalogContractGlassFieldDecoration(
                            hintText: 'Buscar',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2A4B49),
                              ),
                              onPressed: () =>
                                  setLocalState(() => draftSelected = null),
                              child: const Text('Todos'),
                            ),
                            const Spacer(),
                            Text(
                              draftSelected == null
                                  ? 'Todos'
                                  : _materialLabelById(
                                      draftSelected,
                                      emptyLabel: 'Todos',
                                    ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: visibleMaterials.isEmpty
                              ? const Center(
                                  child: Text('Sin valores para mostrar'),
                                )
                              : ListView.builder(
                                  itemCount: visibleMaterials.length,
                                  itemBuilder: (_, idx) {
                                    final material = visibleMaterials[idx];
                                    final id = (material['id'] ?? '')
                                        .toString();
                                    final selected = draftSelected == id;
                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                      leading: Icon(
                                        selected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: selected
                                            ? _kCatalogTableFilterAccent
                                            : const Color(0xFF6C7E7C),
                                      ),
                                      title: Text(
                                        (material['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => setLocalState(
                                        () => draftSelected = id,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: _catalogFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _catalogFilterOutlinedButtonStyle(),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, {'clear': true}),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _catalogFilterFilledButtonStyle(),
                              onPressed: applyAndClose,
                              child: const Text('Aplicar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    searchC.dispose();
    if (!mounted || result == null) return;
    if (result['clear'] == true) {
      setState(() => _commercialMaterialFilterMaterialId = null);
      return;
    }
    final selected = result['selected']?.toString();
    setState(
      () => _commercialMaterialFilterMaterialId =
          (selected == null || selected.isEmpty) ? null : selected,
    );
  }

  Future<void> _openOpeningMaterialPicker() async {
    final options = _kOpeningTemplateMaterials
        .map(
          (m) => _CatalogPickerOption<String>(value: m.value, label: m.label),
        )
        .toList(growable: false);
    final selected = await _showCatalogSearchablePickerDialog<String>(
      context,
      title: 'Seleccionar',
      options: options,
      initialValue: _openingTemplateMaterial,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _openingTemplateMaterial = selected;
      _openingTemplateCommercialCode = null;
    });
  }

  Future<void> _openOpeningCommercialPicker() async {
    final options =
        _openingTemplateCommercialOptionsForMaterial(_openingTemplateMaterial)
            .map(
              (r) => _CatalogPickerOption<String>(
                value: (r['code'] ?? '').toString(),
                label: (r['name'] ?? '').toString(),
              ),
            )
            .toList(growable: false);
    final selected = await _showCatalogSearchablePickerDialog<String>(
      context,
      title: 'Seleccionar',
      options: options,
      initialValue: _openingTemplateCommercialCode,
    );
    if (!mounted || selected == null) return;
    setState(() => _openingTemplateCommercialCode = selected);
  }

  KeyEventResult _handleCommercialInsertKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (_commercialInsertMaterialFocus.hasFocus) {
        unawaited(_openCommercialInsertMaterialPicker());
        return KeyEventResult.handled;
      }
      if (_commercialFilterMaterialFocus.hasFocus) {
        unawaited(_openCommercialFilterMaterialPicker());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _moveInsertFocus(_commercialInsertFocusOrder, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _moveInsertFocus(_commercialInsertFocusOrder, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!_savingCommercialMaterial) unawaited(_addCommercialMaterial());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_commercialInsertNameFocus.hasFocus) {
        _commercialMaterialNameC.clear();
        setState(() {});
        return KeyEventResult.handled;
      }
      if (_commercialInsertMaterialFocus.hasFocus) {
        setState(() => _commercialMaterialDraftMaterialId = null);
        return KeyEventResult.handled;
      }
      if (_commercialFilterMaterialFocus.hasFocus) {
        setState(() => _commercialMaterialFilterMaterialId = null);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleOpeningInsertKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (_openingInsertMaterialFocus.hasFocus) {
        unawaited(_openOpeningMaterialPicker());
        return KeyEventResult.handled;
      }
      if (_openingInsertCommercialFocus.hasFocus) {
        unawaited(_openOpeningCommercialPicker());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _moveInsertFocus(_openingInsertFocusOrder, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _moveInsertFocus(_openingInsertFocusOrder, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!_savingOpeningTemplate) unawaited(_addOpeningTemplate());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_openingInsertCommercialFocus.hasFocus) {
        setState(() => _openingTemplateCommercialCode = null);
        return KeyEventResult.handled;
      }
      if (_openingInsertSortFocus.hasFocus) {
        _openingTemplateSortOrderC.clear();
        setState(() {});
        return KeyEventResult.handled;
      }
      if (_openingInsertMaterialFocus.hasFocus) {
        setState(() {
          _openingTemplateMaterial = _kOpeningTemplateMaterials.first.value;
          _openingTemplateCommercialCode = null;
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmDeleteDialog({
    required String title,
    required String message,
    String confirmLabel = 'Desactivar',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(dialogContext, false);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            Navigator.pop(dialogContext, true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirmAndDeleteMany({
    required String title,
    required List<Map<String, dynamic>> rows,
    required Future<void> Function(Map<String, dynamic> row) deleteOne,
  }) async {
    if (rows.isEmpty) return;
    final ok = await _confirmDeleteDialog(
      title: title,
      message: '¿Seguro que deseas desactivar ${rows.length} registros?',
    );
    if (!ok) return;
    for (final row in rows) {
      await deleteOne(row);
    }
  }

  Future<void> _openInactiveCatalogDialog({
    required String title,
    required String emptyText,
    required Future<List<Map<String, dynamic>>> Function() loader,
    required Future<bool> Function(Map<String, dynamic> row) onReactivate,
    String reactivateLabel = 'Reactivar',
  }) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => _InactiveCatalogDialog(
        title: title,
        emptyText: emptyText,
        loadRows: loader,
        onReactivate: onReactivate,
        reactivateLabel: reactivateLabel,
      ),
    );
    if (changed == true && mounted) {
      await _loadData();
    }
  }

  Future<List<Map<String, dynamic>>> _loadInactiveClients() async {
    final rows = await supa
        .from('sites')
        .select('id,name,type,is_active')
        .eq('type', 'cliente')
        .eq('is_active', false)
        .order('name');
    return _sortCatalogRowsByName((rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _loadInactiveMaterials() async {
    final rows = await supa
        .from('materials')
        .select('id,name,area_id,is_active')
        .eq('is_active', false)
        .order('name');
    return _sortCatalogRowsByName((rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _loadInactiveDrivers() async {
    final rows = await supa
        .from('employees')
        .select('id,full_name,is_active,is_driver')
        .eq('is_driver', true)
        .eq('is_active', false)
        .order('full_name');
    return _sortCatalogRowsByName(
      (rows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => <String, dynamic>{'id': e['id'], 'name': e['full_name']})
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadInactiveVehicles() async {
    final rows = await supa
        .from('vehicles')
        .select('id,code,serial_number,status')
        .eq('status', 'fuera_servicio')
        .order('code');
    return _sortCatalogRowsByName(
      (rows as List)
          .cast<Map<String, dynamic>>()
          .map(
            (e) => <String, dynamic>{
              'id': e['id'],
              'name': e['code'],
              'serial_number': e['serial_number'],
            },
          )
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadInactiveCommercialMaterials() async {
    final rows = await supa
        .from('commercial_material_catalog')
        .select('code,name,family,material_id')
        .eq('active', false)
        .order('name');
    return _sortCatalogRowsByName((rows as List).cast<Map<String, dynamic>>());
  }

  Future<bool> _reactivateClient(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return false;
    try {
      final updated = await supa
          .from('sites')
          .update({'is_active': true})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar empresa');
        return false;
      }
      _changed = true;
      _toast('Empresa reactivada');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar empresa: ${e.message}');
      return false;
    }
  }

  Future<bool> _reactivateMaterial(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return false;
    try {
      final updated = await supa
          .from('materials')
          .update({'is_active': true})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar material');
        return false;
      }
      _changed = true;
      _toast('Material reactivado');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar material: ${e.message}');
      return false;
    }
  }

  Future<bool> _reactivateDriver(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return false;
    try {
      final updated = await supa
          .from('employees')
          .update({'is_active': true})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar chofer');
        return false;
      }
      _changed = true;
      _toast('Chofer reactivado');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar chofer: ${e.message}');
      return false;
    }
  }

  Future<bool> _reactivateVehicle(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return false;
    try {
      final updated = await supa
          .from('vehicles')
          .update({'status': 'activo'})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar unidad');
        return false;
      }
      _changed = true;
      _toast('Unidad reactivada');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar unidad: ${e.message}');
      return false;
    }
  }

  Future<bool> _reactivateCommercialMaterial(Map<String, dynamic> row) async {
    final code = row['code']?.toString();
    if (code == null || code.isEmpty) return false;
    try {
      final updated = await supa
          .from('commercial_material_catalog')
          .update({'active': true})
          .eq('code', code)
          .select('code');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar material comercial');
        return false;
      }
      _changed = true;
      _toast('Material comercial reactivado');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar material comercial: ${e.message}');
      return false;
    }
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
            .eq('is_active', true)
            .order('name'),
        supa
            .from('materials')
            .select(
              'id,name,area_id,inventory_general_code,inventory_material_code',
            )
            .eq('is_active', true)
            .order('name'),
        supa
            .from('employees')
            .select('id,full_name')
            .eq('is_driver', true)
            .eq('is_active', true)
            .order('full_name'),
        supa
            .from('vehicles')
            .select('id,code,serial_number,status')
            .eq('status', 'activo')
            .order('code'),
        supa
            .from('commercial_material_catalog')
            .select('code,name,family,material_id,inventory_material')
            .eq('active', true)
            .order('name'),
        supa
            .from('inventory_opening_templates')
            .select(
              'id,site,material,commercial_material_code,sort_order,notes,is_active',
            )
            .eq('site', _kOpeningTemplateSite)
            .eq('is_active', true)
            .order('sort_order')
            .order('commercial_material_code'),
      ]);

      final areas = (res[0] as List).cast<Map<String, dynamic>>();
      final clients = _sortCatalogRowsByName(
        (res[1] as List).cast<Map<String, dynamic>>(),
      );
      final materials = _sortCatalogRowsByName(
        (res[2] as List).cast<Map<String, dynamic>>(),
      );
      final drivers = _sortCatalogRowsByName(
        (res[3] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (e) => <String, dynamic>{'id': e['id'], 'name': e['full_name']},
            )
            .toList(),
      );
      final vehicles = _sortCatalogRowsByName(
        (res[4] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (e) => <String, dynamic>{
                'id': e['id'],
                'name': e['code'],
                'serial_number': e['serial_number'],
              },
            )
            .toList(),
      );
      final commercialMaterials = _sortCatalogRowsByName(
        (res[5] as List).cast<Map<String, dynamic>>(),
      );
      final openingTemplates = (res[6] as List)
          .cast<Map<String, dynamic>>()
          .toList();

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
        _drivers = drivers;
        _vehicles = vehicles;
        _commercialMaterials = commercialMaterials;
        _openingTemplates = openingTemplates;
        final filterStillExists = _materials.any(
          (m) => m['id']?.toString() == _commercialMaterialFilterMaterialId,
        );
        if (!filterStillExists) {
          _commercialMaterialFilterMaterialId = null;
        }
        final draftMaterialStillExists = _materials.any(
          (m) => m['id']?.toString() == _commercialMaterialDraftMaterialId,
        );
        if (!draftMaterialStillExists) {
          _commercialMaterialDraftMaterialId = null;
        }
        final selectedStillExists = commercialMaterials.any(
          (r) => r['code']?.toString() == _openingTemplateCommercialCode,
        );
        if (!selectedStillExists) {
          _openingTemplateCommercialCode = null;
        }
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

  bool _driverExists(String normalized, {String? excludingId}) {
    for (final d in _drivers) {
      final id = d['id']?.toString();
      if (excludingId != null && id == excludingId) continue;
      if (_normalizeName((d['name'] ?? '').toString()) == normalized) {
        return true;
      }
    }
    return false;
  }

  bool _vehicleExists(String normalized, {String? excludingId}) {
    for (final v in _vehicles) {
      final id = v['id']?.toString();
      if (excludingId != null && id == excludingId) continue;
      if (_normalizeName((v['name'] ?? '').toString()) == normalized) {
        return true;
      }
    }
    return false;
  }

  bool _commercialMaterialNameExists(
    String normalized, {
    String? excludingCode,
  }) {
    for (final row in _commercialMaterials) {
      final code = row['code']?.toString();
      if (excludingCode != null && code == excludingCode) continue;
      if (_normalizeName((row['name'] ?? '').toString()) == normalized) {
        return true;
      }
    }
    return false;
  }

  bool _commercialMaterialCodeExists(String code, {String? excludingCode}) {
    for (final row in _commercialMaterials) {
      final current = row['code']?.toString();
      if (excludingCode != null && current == excludingCode) continue;
      if ((current ?? '').toUpperCase() == code.toUpperCase()) return true;
    }
    return false;
  }

  Future<void> _addClientFromValue(
    String raw, {
    bool clearInput = false,
  }) async {
    final normalized = _normalizeName(raw);
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
      if (clearInput) _clientNameC.clear();
      _changed = true;
      _toast('Empresa agregada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar empresa: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingClient = false);
    }
  }

  Future<void> _addMaterialFromValue(
    String raw, {
    bool clearInput = false,
  }) async {
    final normalized = _normalizeName(raw);
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
      final inventoryMaterialCode = _inventoryMaterialCodeFromGeneralName(
        normalized,
      );
      final payload = <String, dynamic>{
        'name': normalized,
        'inventory_material_code': inventoryMaterialCode,
      };
      if (_defaultAreaId != null) {
        payload['area_id'] = _defaultAreaId;
      }
      await supa.from('materials').insert(payload);
      if (clearInput) _materialNameC.clear();
      _changed = true;
      _toast('Material agregado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar material: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingMaterial = false);
    }
  }

  Future<void> _addDriverFromValue(
    String raw, {
    bool clearInput = false,
  }) async {
    final normalized = _normalizeName(raw);
    if (normalized.isEmpty) {
      _toast('Escribe el nombre del chofer');
      return;
    }
    if (_driverExists(normalized)) {
      _toast('El chofer ya existe');
      return;
    }

    setState(() => _savingDriver = true);
    try {
      await supa.from('employees').insert({
        'full_name': normalized,
        'is_driver': true,
        'is_active': true,
      });
      if (clearInput) _driverNameC.clear();
      _changed = true;
      _toast('Chofer agregado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar chofer: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingDriver = false);
    }
  }

  Future<void> _addVehicleFromValue(
    String raw, {
    String? serialNumber,
    bool clearInput = false,
  }) async {
    final parts = raw.split('|');
    final rawCode = parts.first;
    final inlineSerial = parts.length > 1 ? parts.sublist(1).join('|') : '';
    final normalized = _normalizeName(rawCode);
    final resolvedSerial = _normalizeName(
      (serialNumber ?? '').trim().isEmpty ? inlineSerial : (serialNumber ?? ''),
    );
    if (normalized.isEmpty) {
      _toast('Escribe el código de la unidad');
      return;
    }
    if (_vehicleExists(normalized)) {
      _toast('La unidad ya existe');
      return;
    }

    setState(() => _savingVehicle = true);
    try {
      await supa.from('vehicles').insert({
        'code': normalized,
        'serial_number': resolvedSerial.isEmpty ? null : resolvedSerial,
        'status': 'activo',
      });
      if (clearInput) _vehicleCodeC.clear();
      _changed = true;
      _toast('Unidad agregada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar unidad: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingVehicle = false);
    }
  }

  Future<void> _updateClientNameInline(
    Map<String, dynamic> row,
    String raw,
  ) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final newName = _normalizeName(raw);
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

  Future<void> _updateMaterialNameInline(
    Map<String, dynamic> row,
    String raw,
  ) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final newName = _normalizeName(raw);
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

  Future<void> _updateDriverNameInline(
    Map<String, dynamic> row,
    String raw,
  ) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final newName = _normalizeName(raw);
    if (newName.isEmpty) {
      _toast('El nombre no puede estar vacío');
      return;
    }
    if (_driverExists(newName, excludingId: id)) {
      _toast('El chofer ya existe');
      return;
    }
    try {
      await supa.from('employees').update({'full_name': newName}).eq('id', id);
      _changed = true;
      _toast('Chofer actualizado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar chofer: ${e.message}');
    }
  }

  Future<void> _updateVehicleCodeInline(
    Map<String, dynamic> row,
    String raw,
  ) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final newCode = _normalizeName(raw);
    if (newCode.isEmpty) {
      _toast('El código no puede estar vacío');
      return;
    }
    if (_vehicleExists(newCode, excludingId: id)) {
      _toast('La unidad ya existe');
      return;
    }
    try {
      await supa.from('vehicles').update({'code': newCode}).eq('id', id);
      _changed = true;
      _toast('Unidad actualizada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar unidad: ${e.message}');
    }
  }

  Future<void> _addClient() async {
    await _addClientFromValue(_clientNameC.text, clearInput: true);
  }

  Future<void> _addMaterial() async {
    await _addMaterialFromValue(_materialNameC.text, clearInput: true);
  }

  Future<void> _addDriver() async {
    await _addDriverFromValue(_driverNameC.text, clearInput: true);
  }

  Future<void> _addVehicle() async {
    await _addVehicleFromValue(_vehicleCodeC.text, clearInput: true);
  }

  Future<void> _addCommercialMaterial() async {
    final normalizedName = _normalizeName(_commercialMaterialNameC.text);
    if (normalizedName.isEmpty) {
      _toast('Escribe el nombre del material comercial');
      return;
    }
    if (_commercialMaterialNameExists(normalizedName)) {
      _toast('El material comercial ya existe');
      return;
    }
    final generatedCode = _commercialMaterialCodeFromName(normalizedName);
    if (generatedCode.isEmpty) {
      _toast('No se pudo generar código del material comercial');
      return;
    }
    if (_commercialMaterialCodeExists(generatedCode)) {
      _toast('Ya existe un código comercial igual ($generatedCode)');
      return;
    }
    final materialId = _commercialMaterialDraftMaterialId;
    if (materialId == null || materialId.isEmpty) {
      _toast('Selecciona el material general para el material comercial');
      return;
    }

    setState(() => _savingCommercialMaterial = true);
    try {
      await supa.from('commercial_material_catalog').insert({
        'code': generatedCode,
        'name': normalizedName,
        'family': 'other',
        'material_id': materialId,
        'active': true,
      });
      _commercialMaterialNameC.clear();
      _commercialMaterialFilterMaterialId ??= materialId;
      _changed = true;
      _toast('Material comercial agregado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo agregar material comercial: ${e.message}');
    } finally {
      if (mounted) setState(() => _savingCommercialMaterial = false);
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

    final ok = await _confirmDeleteDialog(
      title: 'Desactivar Empresa',
      message: '¿Seguro que deseas desactivar "$name"?',
    );
    if (!ok) return;
    await _deleteClientWithoutConfirm(row);
  }

  Future<void> _deleteClientWithoutConfirm(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final updated = await supa
          .from('sites')
          .update({'is_active': false})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast(
          'No se pudo desactivar empresa (sin permisos o registro en uso)',
        );
        return;
      }
      _changed = true;
      _toast('Empresa desactivada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo desactivar empresa: ${e.message}');
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
    final ok = await _confirmDeleteDialog(
      title: 'Desactivar Material',
      message: '¿Seguro que deseas desactivar "$name"?',
    );
    if (!ok) return;
    await _deleteMaterialWithoutConfirm(row);
  }

  Future<void> _deleteMaterialWithoutConfirm(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final updated = await supa
          .from('materials')
          .update({'is_active': false})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast(
          'No se pudo desactivar material (sin permisos o registro en uso)',
        );
        return;
      }
      _changed = true;
      _toast('Material desactivado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo desactivar material: ${e.message}');
    }
  }

  Future<void> _editDriver(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final input = TextEditingController(
      text: _normalizeName('${row['name'] ?? ''}'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Chofer'),
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
    if (result == null) return;
    final newName = result;
    if (newName.isEmpty) {
      _toast('El nombre no puede estar vacío');
      return;
    }
    if (_driverExists(newName, excludingId: id)) {
      _toast('El chofer ya existe');
      return;
    }

    try {
      await supa.from('employees').update({'full_name': newName}).eq('id', id);
      _changed = true;
      _toast('Chofer actualizado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar chofer: ${e.message}');
    }
  }

  Future<void> _deleteDriver(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final name = '${row['name'] ?? ''}';
    final ok = await _confirmDeleteDialog(
      title: 'Desactivar Chofer',
      message: '¿Seguro que deseas desactivar "$name"?',
    );
    if (!ok) return;
    await _deleteDriverWithoutConfirm(row);
  }

  Future<void> _deleteDriverWithoutConfirm(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final updated = await supa
          .from('employees')
          .update({'is_active': false})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo desactivar chofer (sin permisos o registro en uso)');
        return;
      }
      _changed = true;
      _toast('Chofer desactivado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo desactivar chofer: ${e.message}');
    }
  }

  Future<void> _editVehicle(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final codeC = TextEditingController(
      text: _normalizeName('${row['name'] ?? ''}'),
    );
    final serialC = TextEditingController(
      text: _normalizeName('${row['serial_number'] ?? ''}'),
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => _catalogGlassDialogScaffold(
        title: 'Editar Unidad',
        maxWidth: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeC,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
                _NameInputFormatter(),
              ],
              decoration: _catalogEditDialogFieldDecoration(
                labelText: 'Código',
                hintText: 'Código',
                alwaysFloatLabel: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serialC,
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
                _NameInputFormatter(),
              ],
              decoration: _catalogEditDialogFieldDecoration(
                labelText: 'Serie',
                hintText: 'Número de serie (opcional)',
                alwaysFloatLabel: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: _catalogSecondaryActionStyle(),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: _catalogPrimaryActionStyle(),
                  onPressed: () => Navigator.pop(dialogContext, {
                    'code': _normalizeName(codeC.text),
                    'serial_number': _normalizeName(serialC.text),
                  }),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final newCode = (result['code'] ?? '').trim();
    final newSerial = (result['serial_number'] ?? '').trim();
    if (newCode.isEmpty) {
      _toast('El código no puede estar vacío');
      return;
    }
    if (_vehicleExists(newCode, excludingId: id)) {
      _toast('La unidad ya existe');
      return;
    }

    try {
      await supa
          .from('vehicles')
          .update({
            'code': newCode,
            'serial_number': newSerial.isEmpty ? null : newSerial,
          })
          .eq('id', id);
      _changed = true;
      _toast('Unidad actualizada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar unidad: ${e.message}');
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final name = '${row['name'] ?? ''}';
    final ok = await _confirmDeleteDialog(
      title: 'Enviar Unidad a Fuera de Servicio',
      message: '¿Seguro que deseas enviar "$name" a fuera de servicio?',
    );
    if (!ok) return;
    await _deleteVehicleWithoutConfirm(row);
  }

  Future<void> _deleteVehicleWithoutConfirm(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final updated = await supa
          .from('vehicles')
          .update({'status': 'fuera_servicio'})
          .eq('id', id)
          .select('id');
      if (updated.isEmpty) {
        _toast(
          'No se pudo enviar unidad a fuera de servicio (sin permisos o registro en uso)',
        );
        return;
      }
      _changed = true;
      _toast('Unidad enviada a fuera de servicio');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar unidad a fuera de servicio: ${e.message}');
    }
  }

  Future<void> _editCommercialMaterial(Map<String, dynamic> row) async {
    const noMaterialValue = '__NONE__';
    final code = row['code']?.toString();
    if (code == null || code.isEmpty) return;

    final nameC = TextEditingController(
      text: _normalizeName('${row['name'] ?? ''}'),
    );
    String family = (row['family']?.toString() ?? 'other').trim();
    String? selectedMaterialId = row['material_id']?.toString();
    final materialOptions = _materials
        .map(
          (m) => _CatalogPickerOption<String>(
            value: (m['id'] ?? '').toString(),
            label: (m['name'] ?? '').toString(),
          ),
        )
        .toList(growable: false);
    const familyOptions = <_CatalogPickerOption<String>>[
      _CatalogPickerOption(value: 'cardboard', label: 'cardboard'),
      _CatalogPickerOption(value: 'scrap', label: 'scrap'),
      _CatalogPickerOption(value: 'metal', label: 'metal'),
      _CatalogPickerOption(value: 'paper', label: 'paper'),
      _CatalogPickerOption(value: 'plastic', label: 'plastic'),
      _CatalogPickerOption(value: 'wood', label: 'wood'),
      _CatalogPickerOption(value: 'service', label: 'service'),
      _CatalogPickerOption(value: 'other', label: 'other'),
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => _catalogGlassDialogScaffold(
          title: 'Editar Material Comercial',
          maxWidth: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código: $code',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A4B49),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameC,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                  _NameInputFormatter(),
                ],
                decoration: _catalogEditDialogFieldDecoration(
                  hintText: 'Nombre',
                ),
              ),
              const SizedBox(height: 10),
              _CatalogPickerField<String>(
                label: 'Familia',
                valueLabel: (family.isEmpty ? 'other' : family),
                dialogTitle: 'Seleccionar',
                value: family.isEmpty ? 'other' : family,
                options: familyOptions,
                onChanged: (v) => setLocalState(() => family = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              _CatalogPickerField<String>(
                label: 'Material general',
                valueLabel: _materialLabelById(selectedMaterialId),
                dialogTitle: 'Seleccionar',
                value: selectedMaterialId ?? noMaterialValue,
                options: [
                  const _CatalogPickerOption<String>(
                    value: noMaterialValue,
                    label: 'Seleccionar',
                  ),
                  ...materialOptions,
                ],
                onChanged: (v) => setLocalState(
                  () => selectedMaterialId = (v == null || v == noMaterialValue)
                      ? null
                      : v,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: _catalogFilterOutlinedButtonStyle(),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: _catalogFilterFilledButtonStyle(),
                    onPressed: () {
                      Navigator.pop(dialogContext, {
                        'name': _normalizeName(nameC.text),
                        'family': family,
                        'material_id': selectedMaterialId,
                      });
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    nameC.dispose();

    if (result == null) return;
    final newName = (result['name'] ?? '').toString();
    final nextMaterialId = (result['material_id'] ?? '').toString();
    if (newName.isEmpty) {
      _toast('El nombre no puede estar vacío');
      return;
    }
    if (nextMaterialId.isEmpty) {
      _toast('Selecciona material general');
      return;
    }
    if (_commercialMaterialNameExists(newName, excludingCode: code)) {
      _toast('El material comercial ya existe');
      return;
    }

    try {
      await supa
          .from('commercial_material_catalog')
          .update({
            'name': newName,
            'family': result['family'],
            'material_id': nextMaterialId,
          })
          .eq('code', code);
      _changed = true;
      _toast('Material comercial actualizado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar material comercial: ${e.message}');
    }
  }

  Future<void> _deleteCommercialMaterial(Map<String, dynamic> row) async {
    final code = row['code']?.toString();
    if (code == null || code.isEmpty) return;
    final name = '${row['name'] ?? ''}';
    final ok = await _confirmDeleteDialog(
      title: 'Desactivar Material Comercial',
      message: '¿Seguro que deseas desactivar "$name"?',
    );
    if (!ok) return;
    await _deleteCommercialMaterialWithoutConfirm(row);
  }

  Future<void> _deleteCommercialMaterialWithoutConfirm(
    Map<String, dynamic> row,
  ) async {
    final code = row['code']?.toString();
    if (code == null || code.isEmpty) return;
    try {
      final updated = await supa
          .from('commercial_material_catalog')
          .update({'active': false})
          .eq('code', code)
          .select('code');
      if ((updated as List).isEmpty) {
        _toast('No se pudo desactivar material comercial');
        return;
      }
      _changed = true;
      _toast('Material comercial desactivado');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo desactivar material comercial: ${e.message}');
    }
  }

  Future<void> _deleteClientsBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Desactivar Empresas',
      rows: rows,
      deleteOne: _deleteClientWithoutConfirm,
    );
  }

  Future<void> _deleteMaterialsBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Desactivar Materiales',
      rows: rows,
      deleteOne: _deleteMaterialWithoutConfirm,
    );
  }

  Future<void> _deleteDriversBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Desactivar Choferes',
      rows: rows,
      deleteOne: _deleteDriverWithoutConfirm,
    );
  }

  Future<void> _deleteVehiclesBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Enviar Unidades a Fuera de Servicio',
      rows: rows,
      deleteOne: _deleteVehicleWithoutConfirm,
    );
  }

  Future<void> _deleteCommercialMaterialsBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Desactivar Materiales Comerciales',
      rows: rows,
      deleteOne: _deleteCommercialMaterialWithoutConfirm,
    );
  }

  List<Map<String, dynamic>> _openingTemplateCommercialOptionsForMaterial(
    String inventoryMaterial,
  ) {
    final rows = _commercialMaterials.toList();
    rows.sort((a, b) {
      final aInv = (a['inventory_material'] ?? '').toString().trim();
      final bInv = (b['inventory_material'] ?? '').toString().trim();
      final aMatch = aInv == inventoryMaterial ? 0 : 1;
      final bMatch = bInv == inventoryMaterial ? 0 : 1;
      final byMatch = aMatch.compareTo(bMatch);
      if (byMatch != 0) return byMatch;
      final an = _normalizeName((a['name'] ?? '').toString());
      final bn = _normalizeName((b['name'] ?? '').toString());
      final byName = an.compareTo(bn);
      if (byName != 0) return byName;
      return (a['code'] ?? '').toString().compareTo(
        (b['code'] ?? '').toString(),
      );
    });
    return rows;
  }

  bool _openingTemplateExists({
    required String material,
    required String commercialCode,
    String? excludingId,
  }) {
    for (final row in _openingTemplates) {
      final id = row['id']?.toString();
      if (excludingId != null && id == excludingId) continue;
      if ((row['material'] ?? '').toString() == material &&
          (row['commercial_material_code'] ?? '').toString() ==
              commercialCode) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addOpeningTemplate() async {
    final material = _openingTemplateMaterial;
    final commercialCode = (_openingTemplateCommercialCode ?? '').trim();
    final sortOrder =
        int.tryParse(_openingTemplateSortOrderC.text.trim()) ?? 100;
    if (commercialCode.isEmpty) {
      _toast('Selecciona un material comercial');
      return;
    }
    if (_openingTemplateExists(
      material: material,
      commercialCode: commercialCode,
    )) {
      _toast('Esa relación ya existe en la plantilla');
      return;
    }
    setState(() => _savingOpeningTemplate = true);
    try {
      await supa.from('inventory_opening_templates').insert({
        'site': _kOpeningTemplateSite,
        'material': material,
        'commercial_material_code': commercialCode,
        'sort_order': sortOrder,
        'is_active': true,
      });
      _changed = true;
      _toast('Renglón de plantilla agregado');
      await _loadData();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final isDuplicate =
          msg.contains('duplicate key') || msg.contains('unique constraint');
      if (isDuplicate) {
        try {
          final updated = await supa
              .from('inventory_opening_templates')
              .update({
                'is_active': true,
                'sort_order': sortOrder,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('site', _kOpeningTemplateSite)
              .eq('material', material)
              .eq('commercial_material_code', commercialCode)
              .select('id');
          if ((updated as List).isNotEmpty) {
            _changed = true;
            _toast('Plantilla reactivada y actualizada');
            await _loadData();
          } else {
            _toast('No se pudo reactivar plantilla duplicada');
          }
        } on PostgrestException catch (e2) {
          _toast('No se pudo reactivar plantilla: ${e2.message}');
        }
      } else {
        _toast('No se pudo agregar plantilla: ${e.message}');
      }
    } finally {
      if (mounted) setState(() => _savingOpeningTemplate = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadInactiveOpeningTemplates() async {
    final rows = await supa
        .from('inventory_opening_templates')
        .select(
          'id,site,material,commercial_material_code,sort_order,is_active',
        )
        .eq('site', _kOpeningTemplateSite)
        .eq('is_active', false)
        .order('sort_order')
        .order('commercial_material_code');
    final mapped = (rows as List).cast<Map<String, dynamic>>().map((r) {
      final material = (r['material'] ?? '').toString();
      final code = (r['commercial_material_code'] ?? '').toString();
      final commercial = _commercialMaterials
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (c) => (c?['code'] ?? '').toString() == code,
            orElse: () => null,
          );
      final opLabel = _kOpeningTemplateMaterials
          .firstWhere(
            (m) => m.value == material,
            orElse: () => _OpMaterialOpt(material, material),
          )
          .label;
      return <String, dynamic>{
        ...r,
        'name':
            '${(commercial?['name'] ?? code).toString()} · $opLabel · orden ${(r['sort_order'] ?? '').toString()}',
      };
    }).toList();
    return _sortCatalogRowsByName(mapped);
  }

  Future<bool> _reactivateOpeningTemplate(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return false;
    try {
      final updated = await supa
          .from('inventory_opening_templates')
          .update({'is_active': true})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo reactivar plantilla de apertura');
        return false;
      }
      _changed = true;
      _toast('Plantilla de apertura reactivada');
      return true;
    } on PostgrestException catch (e) {
      _toast('No se pudo reactivar plantilla: ${e.message}');
      return false;
    }
  }

  Future<void> _editOpeningTemplate(Map<String, dynamic> row) async {
    const noCommercialValue = '__NONE__';
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    String material = (row['material'] ?? '').toString();
    String commercialCode = (row['commercial_material_code'] ?? '').toString();
    int sortOrder = (row['sort_order'] as num?)?.toInt() ?? 100;
    final notesC = TextEditingController(text: (row['notes'] ?? '').toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final commercialOptions =
              _openingTemplateCommercialOptionsForMaterial(material);
          if (commercialCode.isNotEmpty &&
              !commercialOptions.any(
                (r) => (r['code'] ?? '').toString() == commercialCode,
              )) {
            commercialCode = '';
          }
          return _catalogGlassDialogScaffold(
            title: 'Editar Plantilla de Apertura',
            maxWidth: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CatalogPickerField<String>(
                  label: 'Material operativo',
                  valueLabel: _kOpeningTemplateMaterials
                      .firstWhere(
                        (m) => m.value == material,
                        orElse: () => _OpMaterialOpt(material, material),
                      )
                      .label,
                  dialogTitle: 'Seleccionar',
                  value: material,
                  options: _kOpeningTemplateMaterials
                      .map(
                        (m) => _CatalogPickerOption<String>(
                          value: m.value,
                          label: m.label,
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocalState(() {
                      material = v;
                      commercialCode = '';
                    });
                  },
                ),
                const SizedBox(height: 10),
                _CatalogPickerField<String>(
                  label: 'Material comercial',
                  valueLabel: commercialCode.isEmpty
                      ? 'Seleccionar'
                      : (commercialOptions
                                    .cast<Map<String, dynamic>?>()
                                    .firstWhere(
                                      (r) =>
                                          (r?['code'] ?? '').toString() ==
                                          commercialCode,
                                      orElse: () => null,
                                    )?['name'] ??
                                'Seleccionar')
                            .toString(),
                  dialogTitle: 'Seleccionar',
                  value: commercialCode.isEmpty
                      ? noCommercialValue
                      : commercialCode,
                  options: [
                    const _CatalogPickerOption<String>(
                      value: noCommercialValue,
                      label: 'Seleccionar',
                    ),
                    ...commercialOptions.map(
                      (r) => _CatalogPickerOption<String>(
                        value: (r['code'] ?? '').toString(),
                        label: (r['name'] ?? '').toString(),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocalState(
                    () => commercialCode = (v == null || v == noCommercialValue)
                        ? ''
                        : v,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: '$sortOrder',
                  decoration: _catalogEditDialogFieldDecoration(
                    labelText: 'Orden',
                    alwaysFloatLabel: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      sortOrder = int.tryParse(v.trim()) ?? sortOrder,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesC,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _catalogEditDialogFieldDecoration(
                    labelText: 'Notas',
                    alwaysFloatLabel: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _catalogFilterOutlinedButtonStyle(),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: _catalogFilterFilledButtonStyle(),
                      onPressed: () => Navigator.pop(dialogContext, {
                        'material': material,
                        'commercial_material_code': commercialCode,
                        'sort_order': sortOrder,
                        'notes': notesC.text.trim().isEmpty
                            ? null
                            : notesC.text.trim(),
                      }),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    notesC.dispose();

    if (result == null) return;
    final nextMaterial = (result['material'] ?? '').toString();
    final nextCommercial = (result['commercial_material_code'] ?? '')
        .toString();
    final nextSort = (result['sort_order'] as int?) ?? 100;
    if (nextMaterial.isEmpty || nextCommercial.isEmpty) {
      _toast('Completa material operativo y material comercial');
      return;
    }
    if (_openingTemplateExists(
      material: nextMaterial,
      commercialCode: nextCommercial,
      excludingId: id,
    )) {
      _toast('Esa relación ya existe en la plantilla');
      return;
    }
    try {
      await supa
          .from('inventory_opening_templates')
          .update({
            'material': nextMaterial,
            'commercial_material_code': nextCommercial,
            'sort_order': nextSort,
            'notes': result['notes'],
          })
          .eq('id', id);
      _changed = true;
      _toast('Plantilla de apertura actualizada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar plantilla: ${e.message}');
    }
  }

  Future<void> _deleteOpeningTemplate(Map<String, dynamic> row) async {
    final name = (row['name'] ?? row['commercial_material_code'] ?? '')
        .toString();
    final ok = await _confirmDeleteDialog(
      title: 'Desactivar Plantilla de Apertura',
      message: '¿Seguro que deseas desactivar "$name"?',
    );
    if (!ok) return;
    await _deleteOpeningTemplateWithoutConfirm(row);
  }

  Future<void> _deleteOpeningTemplateWithoutConfirm(
    Map<String, dynamic> row,
  ) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final updated = await supa
          .from('inventory_opening_templates')
          .update({'is_active': false})
          .eq('id', id)
          .select('id');
      if ((updated as List).isEmpty) {
        _toast('No se pudo desactivar plantilla de apertura');
        return;
      }
      _changed = true;
      _toast('Plantilla de apertura desactivada');
      await _loadData();
    } on PostgrestException catch (e) {
      _toast('No se pudo desactivar plantilla: ${e.message}');
    }
  }

  Future<void> _deleteOpeningTemplatesBulk(List<Map<String, dynamic>> rows) {
    return _confirmAndDeleteMany(
      title: 'Desactivar Plantillas de Apertura',
      rows: rows,
      deleteOne: _deleteOpeningTemplateWithoutConfirm,
    );
  }

  Widget _buildOpeningTemplatesTab(InputDecoration fieldDecoration) {
    final commercialOptions = _openingTemplateCommercialOptionsForMaterial(
      _openingTemplateMaterial,
    );
    final selectedStillValid = commercialOptions.any(
      (r) => (r['code'] ?? '').toString() == _openingTemplateCommercialCode,
    );
    if (!selectedStillValid && _openingTemplateCommercialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _openingTemplateCommercialCode = null);
      });
    }

    final rows = _openingTemplates.map((r) {
      final material = (r['material'] ?? '').toString();
      final code = (r['commercial_material_code'] ?? '').toString();
      final commercial = _commercialMaterials
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (c) => (c?['code'] ?? '').toString() == code,
            orElse: () => null,
          );
      final opLabel = _kOpeningTemplateMaterials
          .firstWhere(
            (m) => m.value == material,
            orElse: () => _OpMaterialOpt(material, material),
          )
          .label;
      return {
        ...r,
        'name': (commercial?['name'] ?? code).toString(),
        '_op_label': opLabel,
      };
    }).toList();

    return _GlassCard(
      title: 'Plantilla de Apertura ($_kOpeningTemplateSite)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            canRequestFocus: false,
            onKeyEvent: _handleOpeningInsertKey,
            child: _catalogInputPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 860;
                      if (stacked) {
                        return Column(
                          children: [
                            _CatalogPickerField<String>(
                              focusNode: _openingInsertMaterialFocus,
                              label: 'Material operativo',
                              valueLabel: _kOpeningTemplateMaterials
                                  .firstWhere(
                                    (m) => m.value == _openingTemplateMaterial,
                                    orElse: () => _OpMaterialOpt(
                                      _openingTemplateMaterial,
                                      _openingTemplateMaterial,
                                    ),
                                  )
                                  .label,
                              dialogTitle: 'Seleccionar',
                              value: _openingTemplateMaterial,
                              options: _kOpeningTemplateMaterials
                                  .map(
                                    (m) => _CatalogPickerOption<String>(
                                      value: m.value,
                                      label: m.label,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _openingTemplateMaterial = v;
                                  _openingTemplateCommercialCode = null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              focusNode: _openingInsertSortFocus,
                              controller: _openingTemplateSortOrderC,
                              keyboardType: TextInputType.number,
                              decoration: fieldDecoration.copyWith(
                                labelText: 'Orden',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              onSubmitted: (_) => _addOpeningTemplate(),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _CatalogPickerField<String>(
                              focusNode: _openingInsertMaterialFocus,
                              label: 'Material operativo',
                              valueLabel: _kOpeningTemplateMaterials
                                  .firstWhere(
                                    (m) => m.value == _openingTemplateMaterial,
                                    orElse: () => _OpMaterialOpt(
                                      _openingTemplateMaterial,
                                      _openingTemplateMaterial,
                                    ),
                                  )
                                  .label,
                              dialogTitle: 'Seleccionar',
                              value: _openingTemplateMaterial,
                              options: _kOpeningTemplateMaterials
                                  .map(
                                    (m) => _CatalogPickerOption<String>(
                                      value: m.value,
                                      label: m.label,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _openingTemplateMaterial = v;
                                  _openingTemplateCommercialCode = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              focusNode: _openingInsertSortFocus,
                              controller: _openingTemplateSortOrderC,
                              keyboardType: TextInputType.number,
                              decoration: fieldDecoration.copyWith(
                                labelText: 'Orden',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              onSubmitted: (_) => _addOpeningTemplate(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _CatalogPickerField<String>(
                    focusNode: _openingInsertCommercialFocus,
                    label: 'Material comercial',
                    valueLabel: _openingTemplateCommercialCode == null
                        ? 'Seleccionar'
                        : (commercialOptions
                                      .cast<Map<String, dynamic>?>()
                                      .firstWhere(
                                        (r) =>
                                            (r?['code'] ?? '').toString() ==
                                            _openingTemplateCommercialCode,
                                        orElse: () => null,
                                      )?['name'] ??
                                  'Seleccionar')
                              .toString(),
                    dialogTitle: 'Seleccionar',
                    value: _openingTemplateCommercialCode ?? '',
                    options: commercialOptions
                        .map(
                          (r) => _CatalogPickerOption<String>(
                            value: (r['code'] ?? '').toString(),
                            label: (r['name'] ?? '').toString(),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(
                      () => _openingTemplateCommercialCode =
                          (v == null || v.isEmpty) ? null : v,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 310,
                        child: FilledButton.icon(
                          style: _catalogPrimaryActionStyle(),
                          onPressed: _savingOpeningTemplate
                              ? null
                              : _addOpeningTemplate,
                          icon: _savingOpeningTemplate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.playlist_add_check_rounded),
                          label: const Text('Agregar Material Operativo'),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: _catalogSecondaryActionStyle(),
                        onPressed: () => _openInactiveCatalogDialog(
                          title: 'Plantillas de apertura inactivas',
                          emptyText: 'Sin plantillas de apertura inactivas',
                          loader: _loadInactiveOpeningTemplates,
                          onReactivate: _reactivateOpeningTemplate,
                          reactivateLabel: 'Reactivar',
                        ),
                        icon: const Icon(Icons.history_toggle_off),
                        label: const Text('Plantillas inactivas'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _CatalogList(
              rows: rows,
              emptyText: 'Sin renglones en la plantilla de apertura',
              subtitleOf: (row) {
                final op = (row['_op_label'] ?? '').toString();
                final sort = (row['sort_order'] ?? '').toString();
                return 'Material operativo: $op · Orden: $sort';
              },
              onEdit: _editOpeningTemplate,
              onDelete: _deleteOpeningTemplate,
              onDeleteMany: _deleteOpeningTemplatesBulk,
              deleteTooltip: 'Desactivar plantilla',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogModuleCard({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required Future<void> Function() onAdd,
    required bool saving,
    required IconData addIcon,
    required String addLabel,
    required VoidCallback onOpenInactive,
    required String inactiveLabel,
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required String? Function(Map<String, dynamic>) subtitleOf,
    required Future<void> Function(Map<String, dynamic>) onEdit,
    required Future<void> Function(Map<String, dynamic>, String value)
    onInlineEdit,
    required Future<void> Function(Map<String, dynamic>) onDelete,
    required Future<void> Function(String value) onInlineInsert,
    Future<void> Function(List<Map<String, dynamic>> rows)? onDeleteMany,
    String deleteTooltip = 'Desactivar',
    required InputDecoration fieldDecoration,
    String? secondaryColumnHeader,
    String Function(Map<String, dynamic> row)? secondaryColumnValueOf,
  }) {
    return _GlassCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            style: _catalogSecondaryActionStyle(),
            onPressed: onOpenInactive,
            icon: const Icon(Icons.history_toggle_off),
            label: Text(inactiveLabel),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _CatalogContractTable(
              rows: rows,
              emptyText: emptyText,
              subtitleOf: subtitleOf,
              onEdit: onEdit,
              onInlineEdit: onInlineEdit,
              onDelete: onDelete,
              onInlineInsert: onInlineInsert,
              insertHintText: hintText,
              onDeleteMany: onDeleteMany,
              deleteTooltip: deleteTooltip,
              secondaryColumnHeader: secondaryColumnHeader,
              secondaryColumnValueOf: secondaryColumnValueOf,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTabs(InputDecoration fieldDecoration) {
    if (widget.module == OperationsCatalogModule.all) {
      return DefaultTabController(
        length: 6,
        child: _buildAllCatalogTabs(fieldDecoration),
      );
    }
    final tabs = _catalogTabSpecs(fieldDecoration);
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF0B2B2B),
              unselectedLabelColor: const Color(0xCC314747),
              indicatorColor: const Color(0xFF2A9D8F),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [for (final t in tabs) Tab(text: t.label)],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: [for (final t in tabs) t.child]),
          ),
        ],
      ),
    );
  }

  List<_CatalogTabSpec> _catalogTabSpecs(InputDecoration fieldDecoration) {
    switch (widget.module) {
      case OperationsCatalogModule.flotilla:
        return [
          _CatalogTabSpec(
            label: 'Chofer',
            child: _buildCatalogModuleCard(
              title: 'Choferes',
              controller: _driverNameC,
              hintText: 'Nombre del chofer',
              onAdd: _addDriver,
              saving: _savingDriver,
              addIcon: Icons.badge,
              addLabel: 'Agregar Chofer',
              onOpenInactive: () => _openInactiveCatalogDialog(
                title: 'Choferes inactivos',
                emptyText: 'Sin choferes inactivos',
                loader: _loadInactiveDrivers,
                onReactivate: _reactivateDriver,
              ),
              inactiveLabel: 'Ver inactivos',
              rows: _drivers,
              emptyText: 'Sin choferes',
              subtitleOf: (_) => null,
              onEdit: _editDriver,
              onInlineEdit: _updateDriverNameInline,
              onDelete: _deleteDriver,
              onInlineInsert: _addDriverFromValue,
              onDeleteMany: _deleteDriversBulk,
              fieldDecoration: fieldDecoration,
            ),
          ),
          _CatalogTabSpec(
            label: 'Unidad',
            child: _buildCatalogModuleCard(
              title: 'Unidades',
              controller: _vehicleCodeC,
              hintText: 'Código de la unidad (opcional: CODIGO | SERIE)',
              onAdd: _addVehicle,
              saving: _savingVehicle,
              addIcon: Icons.local_shipping,
              addLabel: 'Agregar Unidad',
              onOpenInactive: () => _openInactiveCatalogDialog(
                title: 'Unidades fuera de servicio',
                emptyText: 'Sin unidades fuera de servicio',
                loader: _loadInactiveVehicles,
                onReactivate: _reactivateVehicle,
              ),
              inactiveLabel: 'Fuera de servicio',
              rows: _vehicles,
              emptyText: 'Sin unidades',
              subtitleOf: (row) {
                final serial = (row['serial_number'] ?? '').toString().trim();
                return serial.isEmpty ? null : 'Serie: $serial';
              },
              onEdit: _editVehicle,
              onInlineEdit: _updateVehicleCodeInline,
              onDelete: _deleteVehicle,
              onInlineInsert: _addVehicleFromValue,
              onDeleteMany: _deleteVehiclesBulk,
              deleteTooltip: 'Enviar a fuera de servicio',
              fieldDecoration: fieldDecoration,
              secondaryColumnHeader: 'SERIE',
              secondaryColumnValueOf: (row) =>
                  (row['serial_number'] ?? '').toString(),
            ),
          ),
        ];
      case OperationsCatalogModule.empresas:
        return [
          _CatalogTabSpec(
            label: 'Empresa',
            child: _buildCatalogModuleCard(
              title: 'Empresas (CLIENTE)',
              controller: _clientNameC,
              hintText: 'Nombre de la empresa',
              onAdd: _addClient,
              saving: _savingClient,
              addIcon: Icons.add_business,
              addLabel: 'Agregar Empresa',
              onOpenInactive: () => _openInactiveCatalogDialog(
                title: 'Empresas inactivas',
                emptyText: 'Sin empresas inactivas',
                loader: _loadInactiveClients,
                onReactivate: _reactivateClient,
              ),
              inactiveLabel: 'Ver inactivas',
              rows: _clients,
              emptyText: 'Sin empresas',
              subtitleOf: (_) => null,
              onEdit: _editClient,
              onInlineEdit: _updateClientNameInline,
              onDelete: _deleteClient,
              onInlineInsert: _addClientFromValue,
              onDeleteMany: _deleteClientsBulk,
              fieldDecoration: fieldDecoration,
            ),
          ),
        ];
      case OperationsCatalogModule.materiales:
        return [
          _CatalogTabSpec(
            label: 'Material general',
            child: _buildCatalogModuleCard(
              title: 'Materiales Generales',
              controller: _materialNameC,
              hintText: 'Nombre del material general',
              onAdd: _addMaterial,
              saving: _savingMaterial,
              addIcon: Icons.playlist_add_check,
              addLabel: 'Agregar Material',
              onOpenInactive: () => _openInactiveCatalogDialog(
                title: 'Materiales inactivos',
                emptyText: 'Sin materiales inactivos',
                loader: _loadInactiveMaterials,
                onReactivate: _reactivateMaterial,
              ),
              inactiveLabel: 'Materiales inactivos',
              rows: _materials,
              emptyText: 'Sin materiales',
              subtitleOf: (row) {
                final general = row['inventory_general_code']?.toString();
                final operational = row['inventory_material_code']?.toString();
                final hasGeneral = general != null && general.isNotEmpty;
                final hasOperational =
                    operational != null && operational.isNotEmpty;
                if (!hasGeneral && !hasOperational) return null;
                if (hasGeneral && hasOperational) {
                  return 'Grupo: $general · Operativo: $operational';
                }
                if (hasGeneral) return 'Grupo inventario: $general';
                return 'Código operativo: $operational';
              },
              onEdit: _editMaterial,
              onInlineEdit: _updateMaterialNameInline,
              onDelete: _deleteMaterial,
              onInlineInsert: _addMaterialFromValue,
              onDeleteMany: _deleteMaterialsBulk,
              fieldDecoration: fieldDecoration,
            ),
          ),
          _CatalogTabSpec(
            label: 'Material comercial',
            child: _buildCommercialMaterialsTab(fieldDecoration),
          ),
          _CatalogTabSpec(
            label: 'Material operativo',
            child: _buildOpeningTemplatesTab(fieldDecoration),
          ),
        ];
      case OperationsCatalogModule.all:
        return const [];
    }
  }

  Widget _buildAllCatalogTabs(InputDecoration fieldDecoration) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
          ),
          child: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Color(0xFF0B2B2B),
            unselectedLabelColor: Color(0xCC314747),
            indicatorColor: Color(0xFF2A9D8F),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'Material general'),
              Tab(text: 'Empresas'),
              Tab(text: 'Choferes'),
              Tab(text: 'Unidades'),
              Tab(text: 'Material comercial'),
              Tab(text: 'Plantilla apertura'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            children: [
              _buildCatalogModuleCard(
                title: 'Materiales Generales',
                controller: _materialNameC,
                hintText: 'Nombre del material general',
                onAdd: _addMaterial,
                saving: _savingMaterial,
                addIcon: Icons.playlist_add_check,
                addLabel: 'Agregar Material',
                onOpenInactive: () => _openInactiveCatalogDialog(
                  title: 'Materiales inactivos',
                  emptyText: 'Sin materiales inactivos',
                  loader: _loadInactiveMaterials,
                  onReactivate: _reactivateMaterial,
                ),
                inactiveLabel: 'Materiales inactivos',
                rows: _materials,
                emptyText: 'Sin materiales',
                subtitleOf: (row) {
                  final general = row['inventory_general_code']?.toString();
                  final operational = row['inventory_material_code']
                      ?.toString();
                  final hasGeneral = general != null && general.isNotEmpty;
                  final hasOperational =
                      operational != null && operational.isNotEmpty;
                  if (!hasGeneral && !hasOperational) return null;
                  if (hasGeneral && hasOperational) {
                    return 'Grupo: $general · Operativo: $operational';
                  }
                  if (hasGeneral) return 'Grupo inventario: $general';
                  return 'Código operativo: $operational';
                },
                onEdit: _editMaterial,
                onInlineEdit: _updateMaterialNameInline,
                onDelete: _deleteMaterial,
                onInlineInsert: _addMaterialFromValue,
                onDeleteMany: _deleteMaterialsBulk,
                fieldDecoration: fieldDecoration,
              ),
              _buildCatalogModuleCard(
                title: 'Empresas (CLIENTE)',
                controller: _clientNameC,
                hintText: 'Nombre de la empresa',
                onAdd: _addClient,
                saving: _savingClient,
                addIcon: Icons.add_business,
                addLabel: 'Agregar Empresa',
                onOpenInactive: () => _openInactiveCatalogDialog(
                  title: 'Empresas inactivas',
                  emptyText: 'Sin empresas inactivas',
                  loader: _loadInactiveClients,
                  onReactivate: _reactivateClient,
                ),
                inactiveLabel: 'Ver inactivas',
                rows: _clients,
                emptyText: 'Sin empresas',
                subtitleOf: (_) => null,
                onEdit: _editClient,
                onInlineEdit: _updateClientNameInline,
                onDelete: _deleteClient,
                onInlineInsert: _addClientFromValue,
                onDeleteMany: _deleteClientsBulk,
                fieldDecoration: fieldDecoration,
              ),
              _buildCatalogModuleCard(
                title: 'Choferes',
                controller: _driverNameC,
                hintText: 'Nombre del chofer',
                onAdd: _addDriver,
                saving: _savingDriver,
                addIcon: Icons.badge,
                addLabel: 'Agregar Chofer',
                onOpenInactive: () => _openInactiveCatalogDialog(
                  title: 'Choferes inactivos',
                  emptyText: 'Sin choferes inactivos',
                  loader: _loadInactiveDrivers,
                  onReactivate: _reactivateDriver,
                ),
                inactiveLabel: 'Ver inactivos',
                rows: _drivers,
                emptyText: 'Sin choferes',
                subtitleOf: (_) => null,
                onEdit: _editDriver,
                onInlineEdit: _updateDriverNameInline,
                onDelete: _deleteDriver,
                onInlineInsert: _addDriverFromValue,
                onDeleteMany: _deleteDriversBulk,
                fieldDecoration: fieldDecoration,
              ),
              _buildCatalogModuleCard(
                title: 'Unidades',
                controller: _vehicleCodeC,
                hintText: 'Código de la unidad (opcional: CODIGO | SERIE)',
                onAdd: _addVehicle,
                saving: _savingVehicle,
                addIcon: Icons.local_shipping,
                addLabel: 'Agregar Unidad',
                onOpenInactive: () => _openInactiveCatalogDialog(
                  title: 'Unidades fuera de servicio',
                  emptyText: 'Sin unidades fuera de servicio',
                  loader: _loadInactiveVehicles,
                  onReactivate: _reactivateVehicle,
                ),
                inactiveLabel: 'Fuera de servicio',
                rows: _vehicles,
                emptyText: 'Sin unidades',
                subtitleOf: (row) {
                  final serial = (row['serial_number'] ?? '').toString().trim();
                  return serial.isEmpty ? null : 'Serie: $serial';
                },
                onEdit: _editVehicle,
                onInlineEdit: _updateVehicleCodeInline,
                onDelete: _deleteVehicle,
                onInlineInsert: _addVehicleFromValue,
                onDeleteMany: _deleteVehiclesBulk,
                deleteTooltip: 'Enviar a fuera de servicio',
                fieldDecoration: fieldDecoration,
                secondaryColumnHeader: 'SERIE',
                secondaryColumnValueOf: (row) =>
                    (row['serial_number'] ?? '').toString(),
              ),
              _buildCommercialMaterialsTab(fieldDecoration),
              _buildOpeningTemplatesTab(fieldDecoration),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommercialMaterialsTab(InputDecoration fieldDecoration) {
    const draftNone = '__NONE__';

    final filteredRows = _commercialMaterials.where((row) {
      if (_commercialMaterialFilterMaterialId == null) return true;
      return (row['material_id'] ?? '').toString() ==
          _commercialMaterialFilterMaterialId;
    }).toList();

    String? subtitleOf(Map<String, dynamic> row) {
      final materialId = row['material_id']?.toString();
      if (materialId == null || materialId.isEmpty) {
        return 'Material general: Sin asignar';
      }
      final match = _materials.cast<Map<String, dynamic>?>().firstWhere(
        (m) => (m?['id'] ?? '').toString() == materialId,
        orElse: () => null,
      );
      final generalName = (match?['name'] ?? '').toString();
      return generalName.isEmpty
          ? 'Material general: Sin asignar'
          : 'Material general: $generalName';
    }

    return _GlassCard(
      title: 'Materiales Comerciales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            canRequestFocus: false,
            onKeyEvent: _handleCommercialInsertKey,
            child: _catalogInputPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 900;
                      if (stacked) {
                        return Column(
                          children: [
                            TextField(
                              focusNode: _commercialInsertNameFocus,
                              controller: _commercialMaterialNameC,
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter,
                                _NameInputFormatter(),
                              ],
                              decoration: fieldDecoration.copyWith(
                                hintText: 'Nombre del material comercial',
                              ),
                              onSubmitted: (_) => _addCommercialMaterial(),
                            ),
                            const SizedBox(height: 10),
                            _CatalogPickerField<String>(
                              focusNode: _commercialInsertMaterialFocus,
                              label: 'Material general',
                              valueLabel: _materialLabelById(
                                _commercialMaterialDraftMaterialId,
                              ),
                              dialogTitle: 'Seleccionar',
                              value:
                                  _commercialMaterialDraftMaterialId ??
                                  draftNone,
                              options: [
                                const _CatalogPickerOption<String>(
                                  value: draftNone,
                                  label: 'Seleccionar',
                                ),
                                ..._materials.map(
                                  (m) => _CatalogPickerOption<String>(
                                    value: (m['id'] ?? '').toString(),
                                    label: (m['name'] ?? '').toString(),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _commercialMaterialDraftMaterialId =
                                    (v == null || v == draftNone) ? null : v,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: TextField(
                              focusNode: _commercialInsertNameFocus,
                              controller: _commercialMaterialNameC,
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter,
                                _NameInputFormatter(),
                              ],
                              decoration: fieldDecoration.copyWith(
                                hintText: 'Nombre del material comercial',
                              ),
                              onSubmitted: (_) => _addCommercialMaterial(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: _CatalogPickerField<String>(
                              focusNode: _commercialInsertMaterialFocus,
                              label: 'Material general',
                              valueLabel: _materialLabelById(
                                _commercialMaterialDraftMaterialId,
                              ),
                              dialogTitle: 'Seleccionar',
                              value:
                                  _commercialMaterialDraftMaterialId ??
                                  draftNone,
                              options: [
                                const _CatalogPickerOption<String>(
                                  value: draftNone,
                                  label: 'Seleccionar',
                                ),
                                ..._materials.map(
                                  (m) => _CatalogPickerOption<String>(
                                    value: (m['id'] ?? '').toString(),
                                    label: (m['name'] ?? '').toString(),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _commercialMaterialDraftMaterialId =
                                    (v == null || v == draftNone) ? null : v,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final hasMaterialFilter =
                          _commercialMaterialFilterMaterialId != null;
                      final filterSummary = hasMaterialFilter
                          ? _materialLabelById(
                              _commercialMaterialFilterMaterialId,
                              emptyLabel: 'Todos',
                            )
                          : 'Todos';
                      return Focus(
                        focusNode: _commercialFilterMaterialFocus,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _openCommercialFilterMaterialPicker,
                          child: InputDecorator(
                            decoration: _catalogContractGlassFieldDecoration()
                                .copyWith(
                                  labelText: 'Filtro: material general',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: hasMaterialFilter
                                        ? _kCatalogTableFilterAccent
                                        : _kCatalogTableFilterAccentSoft
                                              .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: hasMaterialFilter
                                          ? _kCatalogTableFilterAccent
                                                .withValues(alpha: 0.55)
                                          : const Color(
                                              0xFF0B2B2B,
                                            ).withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Icon(
                                    hasMaterialFilter
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined,
                                    size: 15,
                                    color: hasMaterialFilter
                                        ? Colors.white
                                        : const Color(0xFF2A4B49),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    filterSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF202628),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.tune_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 260,
                        child: FilledButton.icon(
                          style: _catalogPrimaryActionStyle(),
                          onPressed: _savingCommercialMaterial
                              ? null
                              : _addCommercialMaterial,
                          icon: _savingCommercialMaterial
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.playlist_add),
                          label: const Text('Agregar Material Comercial'),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: _catalogSecondaryActionStyle(),
                        onPressed: () => _openInactiveCatalogDialog(
                          title: 'Materiales comerciales inactivos',
                          emptyText: 'Sin materiales comerciales inactivos',
                          loader: _loadInactiveCommercialMaterials,
                          onReactivate: _reactivateCommercialMaterial,
                        ),
                        icon: const Icon(Icons.history_toggle_off),
                        label: const Text('Comerciales inactivos'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _CatalogList(
              rows: filteredRows,
              emptyText: 'Sin materiales comerciales',
              subtitleOf: subtitleOf,
              onEdit: _editCommercialMaterial,
              onDelete: _deleteCommercialMaterial,
              onDeleteMany: _deleteCommercialMaterialsBulk,
            ),
          ),
        ],
      ),
    );
  }

  String _catalogDialogTitle() {
    switch (widget.module) {
      case OperationsCatalogModule.flotilla:
        return 'Módulo Flotilla';
      case OperationsCatalogModule.empresas:
        return 'Módulo Empresas';
      case OperationsCatalogModule.materiales:
        return 'Módulo de Materiales';
      case OperationsCatalogModule.all:
        return 'Catálogo Global de Operaciones';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.62)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.62)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF2A9D8F).withValues(alpha: 0.88),
          width: 1.2,
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context, _changed);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360, maxHeight: 860),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
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
                                  Expanded(
                                    child: Text(
                                      _catalogDialogTitle(),
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
                                child: _buildCatalogTabs(fieldDecoration),
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
      ),
    );
  }
}

class _CatalogTabSpec {
  final String label;
  final Widget child;
  const _CatalogTabSpec({required this.label, required this.child});
}

class _CatalogContractTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final String? Function(Map<String, dynamic>) subtitleOf;
  final Future<void> Function(Map<String, dynamic> row) onEdit;
  final Future<void> Function(Map<String, dynamic> row, String value)
  onInlineEdit;
  final Future<void> Function(Map<String, dynamic> row) onDelete;
  final Future<void> Function(String value) onInlineInsert;
  final Future<void> Function(List<Map<String, dynamic>> rows)? onDeleteMany;
  final String deleteTooltip;
  final String insertHintText;
  final String? secondaryColumnHeader;
  final String Function(Map<String, dynamic> row)? secondaryColumnValueOf;

  const _CatalogContractTable({
    required this.rows,
    required this.emptyText,
    required this.subtitleOf,
    required this.onEdit,
    required this.onInlineEdit,
    required this.onDelete,
    required this.onInlineInsert,
    this.onDeleteMany,
    this.deleteTooltip = 'Desactivar',
    required this.insertHintText,
    this.secondaryColumnHeader,
    this.secondaryColumnValueOf,
  });

  @override
  State<_CatalogContractTable> createState() => _CatalogContractTableState();
}

class _CatalogContractTableState extends State<_CatalogContractTable> {
  static const double _rowExtentEstimate = 84;

  final FocusNode _focusNode = FocusNode(debugLabel: 'CatalogContractTable');
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _insertController = TextEditingController();
  final FocusNode _insertFocusNode = FocusNode(debugLabel: 'CatalogInsert');
  final TextEditingController _nameFilterC = TextEditingController();
  Set<String> _nameFilterSelectedNames = <String>{};
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};
  final Map<String, GlobalKey> _rowRenderKeys = <String, GlobalKey>{};

  int _selectedIndex = 0; // visible rows index
  int? _selectionAnchorIndex;
  final Set<String> _selectedRowIds = <String>{};
  final Set<String> _editingRowIds = <String>{};
  String? _activeEditingRowId;
  String? _hoveredRowId;
  bool _insertActive = true;
  bool _savingEdits = false;
  bool _inserting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _nameFilterC.addListener(_onFiltersChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _insertFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _CatalogContractTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validIds = widget.rows.map(_rowId).whereType<String>().toSet();
    _selectedRowIds.removeWhere((id) => !validIds.contains(id));
    _editingRowIds.removeWhere((id) => !validIds.contains(id));
    // Do not dispose row editors during widget updates; rows can still be
    // rebuilding during transition frames and Flutter may read the controller.
    // Cleanup happens on widget dispose.
    _editControllers.removeWhere((id, _) => !validIds.contains(id));
    _editFocusNodes.removeWhere((id, _) => !validIds.contains(id));
    _rowRenderKeys.removeWhere((id, _) => !validIds.contains(id));
    _nameFilterSelectedNames = _nameFilterSelectedNames
        .where(
          (name) => widget.rows.any(
            (r) => _normalizeName((r['name'] ?? '').toString()) == name,
          ),
        )
        .toSet();
    final rows = _visibleRows;
    if (rows.isEmpty) {
      _selectedIndex = 0;
      _selectionAnchorIndex = null;
      _selectedRowIds.clear();
      _editingRowIds.clear();
      _activeEditingRowId = null;
      _insertActive = true;
      return;
    }
    _selectedIndex = _selectedIndex.clamp(0, rows.length - 1);
    _selectionAnchorIndex = (_selectionAnchorIndex ?? _selectedIndex).clamp(
      0,
      rows.length - 1,
    );
    final currentId = _visibleRowIdAt(_selectedIndex);
    if (currentId != null && _selectedRowIds.isEmpty) {
      _selectedRowIds.add(currentId);
    }
    if (_activeEditingRowId != null &&
        !_editingRowIds.contains(_activeEditingRowId)) {
      _activeEditingRowId = _editingRowIds.isEmpty
          ? null
          : _editingRowIds.first;
    }
    if (_editingRowIds.isNotEmpty && _activeEditingRowId == null) {
      _activeEditingRowId = _editingRowIds.first;
    }
    if (_editingRowIds.isEmpty && !_insertActive) {
      _insertActive = rows.isEmpty;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _scrollController.dispose();
    _insertController.dispose();
    _insertFocusNode.dispose();
    _nameFilterC.dispose();
    for (final c in _editControllers.values) {
      c.dispose();
    }
    for (final n in _editFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleRows {
    final nameFilter = _normalizeName(_nameFilterC.text);
    return widget.rows
        .where((row) {
          final name = _normalizeName((row['name'] ?? '').toString());
          final okName = nameFilter.isEmpty || name.contains(nameFilter);
          final okSelection =
              _nameFilterSelectedNames.isEmpty ||
              _nameFilterSelectedNames.contains(name);
          return okName && okSelection;
        })
        .toList(growable: false);
  }

  Future<void> _openNameFilterDialog() async {
    final searchC = TextEditingController(text: _nameFilterC.text);
    final currentSelection = Set<String>.from(_nameFilterSelectedNames);
    final allNames =
        widget.rows
            .map((r) => _normalizeName((r['name'] ?? '').toString()))
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final query = _normalizeName(searchC.text);
          final visibleNames = allNames
              .where((n) => query.isEmpty || n.contains(query))
              .toList(growable: false);
          final allVisibleSelected =
              visibleNames.isNotEmpty &&
              visibleNames.every(currentSelection.contains);
          void applyAndClose() {
            Navigator.pop(dialogContext, {
              'query': searchC.text,
              'selected': currentSelection.toList(),
            });
          }

          void toggleVisibleSelection() {
            final allVisibleSelected =
                visibleNames.isNotEmpty &&
                visibleNames.every(currentSelection.contains);
            setLocalState(() {
              if (allVisibleSelected) {
                currentSelection.removeAll(visibleNames);
              } else {
                currentSelection.addAll(visibleNames);
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  applyAndClose();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _catalogFilterDialogDecoration(),
                    child: FocusScope(
                      autofocus: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtro: NOMBRE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: searchC,
                            autofocus: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.singleLineFormatter,
                              _NameInputFormatter(),
                            ],
                            onChanged: (_) => setLocalState(() {}),
                            onSubmitted: (_) => applyAndClose(),
                            decoration: _catalogContractGlassFieldDecoration(
                              hintText: 'Buscar',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2A4B49),
                                ),
                                onPressed: toggleVisibleSelection,
                                child: Text(
                                  allVisibleSelected
                                      ? 'Deseleccionar visibles'
                                      : 'Seleccionar visibles',
                                ),
                              ),
                              const Spacer(),
                              Text('${currentSelection.length} seleccionados'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: visibleNames.isEmpty
                                ? const Center(
                                    child: Text('Sin valores para mostrar'),
                                  )
                                : ListView.builder(
                                    itemCount: visibleNames.length,
                                    itemBuilder: (_, idx) {
                                      final name = visibleNames[idx];
                                      final checked = currentSelection.contains(
                                        name,
                                      );
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        title: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onChanged: (v) {
                                          setLocalState(() {
                                            if (v ?? false) {
                                              currentSelection.add(name);
                                            } else {
                                              currentSelection.remove(name);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _catalogFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _catalogFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext, {
                                  'clear': true,
                                }),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _catalogFilterFilledButtonStyle(),
                                onPressed: applyAndClose,
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    if (result['clear'] == true) {
      _nameFilterC.clear();
      setState(() => _nameFilterSelectedNames.clear());
      return;
    }
    _nameFilterC.text = (result['query'] ?? '').toString();
    final selected = (result['selected'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toSet();
    setState(() => _nameFilterSelectedNames = selected);
  }

  String? _rowId(Map<String, dynamic> row) =>
      row['id']?.toString() ?? row['code']?.toString();

  String? _visibleRowIdAt(int index) {
    final rows = _visibleRows;
    if (index < 0 || index >= rows.length) return null;
    return _rowId(rows[index]);
  }

  bool _isCtrlOrCmdPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isSelectionExtendPressed() =>
      _isCtrlOrCmdPressed() || HardwareKeyboard.instance.isShiftPressed;

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _onFiltersChanged() {
    if (!mounted) return;
    final rows = _visibleRows;
    if (rows.isEmpty) {
      _selectedIndex = 0;
      _insertActive = true;
    } else {
      _selectedIndex = _selectedIndex.clamp(0, rows.length - 1);
    }
    setState(() {});
  }

  TextEditingController _controllerForRow(Map<String, dynamic> row) {
    final id = _rowId(row)!;
    return _editControllers.putIfAbsent(
      id,
      () => TextEditingController(
        text: _normalizeName((row['name'] ?? '').toString()),
      ),
    );
  }

  FocusNode _focusNodeForRow(String id) => _editFocusNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'CatalogEdit-$id'),
  );

  GlobalKey _renderKeyForRow(String id) => _rowRenderKeys.putIfAbsent(
    id,
    () => GlobalKey(debugLabel: 'CatalogRow-$id'),
  );

  void _ensureVisible(int visibleIndex, {int? moveDelta}) {
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : moveDelta < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    final rowId = _visibleRowIdAt(visibleIndex);
    if (rowId != null) {
      final rowContext = _rowRenderKeys[rowId]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignmentPolicy: alignmentPolicy,
        );
        return;
      }
    }

    if (_scrollController.hasClients) {
      final target = (visibleIndex * _rowExtentEstimate).toDouble();
      final viewport = _scrollController.position.viewportDimension;
      final current = _scrollController.offset;
      final maxVisible = current + viewport - _rowExtentEstimate;
      if (target < current) {
        _scrollController.jumpTo(
          target.clamp(0, _scrollController.position.maxScrollExtent),
        );
      } else if (target > maxVisible) {
        _scrollController.jumpTo(
          (target - (viewport - _rowExtentEstimate)).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _visibleRowIdAt(visibleIndex);
      if (id == null) return;
      final rowContext = _rowRenderKeys[id]?.currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
    });
  }

  void _selectIndex(
    int index, {
    bool additive = false,
    bool additiveToggle = false,
    bool ensureVisible = true,
    int? ensureMoveDelta,
  }) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final clamped = index.clamp(0, rows.length - 1);
    final id = _rowId(rows[clamped]);
    if (id == null) return;
    setState(() {
      _insertActive = false;
      _selectedIndex = clamped;
      _selectionAnchorIndex ??= clamped;
      if (additive) {
        _selectedRowIds.add(id);
      } else if (additiveToggle) {
        if (_selectedRowIds.contains(id) && _selectedRowIds.length > 1) {
          _selectedRowIds.remove(id);
        } else {
          _selectedRowIds.add(id);
        }
      } else {
        _selectedRowIds
          ..clear()
          ..add(id);
      }
      _selectionAnchorIndex = clamped;
    });
    if (ensureVisible) _ensureVisible(clamped, moveDelta: ensureMoveDelta);
  }

  void _activateInsertRow() {
    setState(() {
      _insertActive = true;
      _selectedRowIds.clear();
      _selectionAnchorIndex = null;
    });
    _focusNode.requestFocus();
    _insertFocusNode.requestFocus();
  }

  void _moveSelection(int delta, {bool extend = false}) {
    final rows = _visibleRows;
    if (rows.isEmpty) {
      _activateInsertRow();
      return;
    }
    if (_insertActive && delta > 0) {
      _selectIndex(0, ensureMoveDelta: delta);
      return;
    }
    if (_insertActive && delta < 0) {
      return;
    }
    final next = (_selectedIndex + delta).clamp(0, rows.length - 1);
    if (extend) {
      final currentId = _visibleRowIdAt(_selectedIndex);
      if (currentId != null) _selectedRowIds.add(currentId);
      _selectIndex(next, additive: true, ensureMoveDelta: delta);
      return;
    }
    if (delta < 0 && _selectedIndex == 0) {
      _activateInsertRow();
      return;
    }
    _selectIndex(next, ensureMoveDelta: delta);
  }

  Future<void> _insertFromRow() async {
    if (_inserting || _savingEdits) return;
    final value = _normalizeName(_insertController.text);
    if (value.isEmpty) return;
    setState(() => _inserting = true);
    try {
      await widget.onInlineInsert(value);
      if (!mounted) return;
      _insertController.clear();
      _activateInsertRow();
    } finally {
      if (mounted) setState(() => _inserting = false);
    }
  }

  void _enterEditModeForSelection({Map<String, dynamic>? preferredRow}) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final currentRow =
        preferredRow ?? rows[_selectedIndex.clamp(0, rows.length - 1)];
    final currentId = _rowId(currentRow);
    if (currentId == null) return;

    final ids = _selectedRowIds.isEmpty
        ? <String>{currentId}
        : Set<String>.from(_selectedRowIds);
    if (preferredRow != null &&
        _isCtrlOrCmdPressed() &&
        !ids.contains(currentId)) {
      ids.add(currentId);
    } else if (preferredRow != null && !_selectedRowIds.contains(currentId)) {
      ids
        ..clear()
        ..add(currentId);
    }

    for (final row in rows.where((r) => ids.contains(_rowId(r)))) {
      final c = _controllerForRow(row);
      c.text = _normalizeName((row['name'] ?? '').toString());
    }
    setState(() {
      _insertActive = false;
      _selectedRowIds
        ..clear()
        ..addAll(ids);
      _editingRowIds
        ..clear()
        ..addAll(ids);
      _activeEditingRowId = currentId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focus = _focusNodeForRow(currentId);
      if (mounted) {
        focus.requestFocus();
        final ctl = _editControllers[currentId];
        ctl?.selection = TextSelection(
          baseOffset: 0,
          extentOffset: ctl.text.length,
        );
      }
    });
  }

  void _cancelEditing({bool keepSelection = true}) {
    if (_editingRowIds.isEmpty) return;
    for (final row in widget.rows) {
      final id = _rowId(row);
      if (id != null && _editingRowIds.contains(id)) {
        final c = _editControllers[id];
        if (c != null) c.text = _normalizeName((row['name'] ?? '').toString());
      }
    }
    setState(() {
      _editingRowIds.clear();
      _activeEditingRowId = null;
      if (!keepSelection && _selectedRowIds.isNotEmpty) {
        _selectedRowIds.clear();
      }
    });
  }

  Future<void> _saveEditingRows() async {
    if (_editingRowIds.isEmpty || _savingEdits) return;
    final rowsToSave = widget.rows
        .where((r) => _editingRowIds.contains(_rowId(r)))
        .toList(growable: false);
    if (rowsToSave.isEmpty) {
      _cancelEditing();
      return;
    }
    setState(() => _savingEdits = true);
    try {
      for (final row in rowsToSave) {
        final id = _rowId(row);
        final controller = id == null ? null : _editControllers[id];
        if (controller == null) continue;
        await widget.onInlineEdit(row, controller.text);
      }
      if (!mounted) return;
      setState(() {
        _editingRowIds.clear();
        _activeEditingRowId = null;
      });
    } finally {
      if (mounted) setState(() => _savingEdits = false);
    }
  }

  void _moveEditingFocus(int delta) {
    if (_editingRowIds.isEmpty) return;
    final rows = _visibleRows;
    final editingVisibleIndexes = <int>[
      for (var i = 0; i < rows.length; i++)
        if (_editingRowIds.contains(_rowId(rows[i]))) i,
    ];
    if (editingVisibleIndexes.isEmpty) return;
    final currentVisibleIndex = rows.indexWhere(
      (r) => _rowId(r) == _activeEditingRowId,
    );
    if (currentVisibleIndex < 0) return;
    final currentPos = editingVisibleIndexes.indexOf(currentVisibleIndex);
    if (currentPos < 0) return;
    final nextPos = (currentPos + delta).clamp(
      0,
      editingVisibleIndexes.length - 1,
    );
    final nextIndex = editingVisibleIndexes[nextPos];
    final nextId = _rowId(rows[nextIndex]);
    if (nextId == null) return;
    setState(() {
      _selectedIndex = nextIndex;
      _activeEditingRowId = nextId;
      _insertActive = false;
    });
    _ensureVisible(nextIndex, moveDelta: delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = _focusNodeForRow(nextId);
      final ctl = _editControllers[nextId];
      focus.requestFocus();
      ctl?.selection = TextSelection.collapsed(offset: ctl.text.length);
    });
  }

  Future<void> _deleteSelection() async {
    final allRows = widget.rows;
    if (allRows.isEmpty) return;
    final ids = _selectedRowIds.isEmpty
        ? <String>{
            if (_visibleRowIdAt(_selectedIndex) != null)
              _visibleRowIdAt(_selectedIndex)!,
          }
        : Set<String>.from(_selectedRowIds);
    final rows = allRows
        .where((r) => ids.contains(_rowId(r)))
        .toList(growable: false);
    if (rows.isEmpty) return;
    if (rows.length > 1 && widget.onDeleteMany != null) {
      await widget.onDeleteMany!(rows);
    } else {
      for (final row in rows) {
        await widget.onDelete(row);
      }
    }
  }

  Future<void> _showRowActionsMenu(
    int visibleIndex,
    Map<String, dynamic> row, {
    Offset? globalPosition,
  }) async {
    final rowId = _rowId(row);
    if (rowId == null) return;
    _focusNode.requestFocus();
    if (!_selectedRowIds.contains(rowId)) {
      _selectIndex(
        visibleIndex,
        ensureVisible: false,
        additiveToggle: globalPosition != null && _isCtrlOrCmdPressed(),
      );
    } else {
      setState(() {
        _selectedIndex = visibleIndex;
        _insertActive = false;
      });
    }
    final editing = _editingRowIds.contains(rowId);
    final overlay = Overlay.of(context).context.findRenderObject();
    final position = (globalPosition != null && overlay is RenderBox)
        ? RelativeRect.fromRect(
            Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(0, 0, 0, 0);
    final action = await showMenu<String>(
      context: context,
      position: position,
      color: _kCatalogTableGlassMenuBg,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
      ),
      items: [
        if (editing)
          const PopupMenuItem<String>(
            value: 'save',
            child: Text(
              'GUARDAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        else
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text(
              'EDITAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (editing)
          const PopupMenuItem<String>(
            value: 'cancel',
            child: Text(
              'CANCELAR',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            widget.deleteTooltip.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    switch (action) {
      case 'edit':
        _enterEditModeForSelection(preferredRow: row);
        break;
      case 'save':
        await _saveEditingRows();
        break;
      case 'cancel':
        _cancelEditing();
        break;
      case 'delete':
        await _deleteSelection();
        break;
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_editingRowIds.isNotEmpty) {
      if (key == LogicalKeyboardKey.escape) {
        _cancelEditing();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        unawaited(_saveEditingRows());
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveEditingFocus(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveEditingFocus(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.backspace) {
        return KeyEventResult.ignored;
      }
    }

    if (_insertActive) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveSelection(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        unawaited(_insertFromRow());
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        if (_insertController.text.isNotEmpty) {
          _insertController.clear();
        } else {
          node.unfocus();
        }
        return KeyEventResult.handled;
      }
    }

    final rows = _visibleRows;
    if (rows.isEmpty) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        unawaited(_insertFromRow());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1, extend: _isSelectionExtendPressed());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1, extend: _isSelectionExtendPressed());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _enterEditModeForSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      unawaited(_deleteSelection());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedRowIds.length > 1) {
        _selectIndex(_selectedIndex, ensureVisible: false);
      } else if (_selectedRowIds.isNotEmpty) {
        setState(() => _selectedRowIds.clear());
      } else {
        _activateInsertRow();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _actionButtonForRow(int visibleIndex, Map<String, dynamic> row) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => unawaited(_showRowActionsMenu(visibleIndex, row)),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(Icons.more_horiz),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    const editableCellMaxWidth = 440.0;
    final hasSecondaryColumn =
        widget.secondaryColumnHeader != null &&
        widget.secondaryColumnHeader!.trim().isNotEmpty &&
        widget.secondaryColumnValueOf != null;
    final hasNameFilterActive =
        _nameFilterC.text.trim().isNotEmpty ||
        _nameFilterSelectedNames.isNotEmpty;
    final canInsert =
        _normalizeName(_insertController.text).isNotEmpty &&
        !_inserting &&
        !_savingEdits;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _focusNode.requestFocus();
          _activateInsertRow();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? _kCatalogTableSelectionAccent.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.48),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Colors.white.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.table_rows_rounded,
                        size: 15,
                        color: Color(0xFF2A4B49),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${rows.length} renglones',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedRowIds.length} seleccionados',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_editingRowIds.isNotEmpty)
                        const Text(
                          'Edición inline · Enter guarda · Esc cancela',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2A4B49),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.black.withValues(alpha: 0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openNameFilterDialog,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hasNameFilterActive
                                ? _kCatalogTableFilterAccent
                                : _kCatalogTableFilterAccentSoft.withValues(
                                    alpha: 0.35,
                                  ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasNameFilterActive
                                  ? _kCatalogTableFilterAccent.withValues(
                                      alpha: 0.55,
                                    )
                                  : const Color(
                                      0xFF0B2B2B,
                                    ).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Icon(
                            hasNameFilterActive
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                            size: 15,
                            color: hasNameFilterActive
                                ? Colors.white
                                : const Color(0xFF2A4B49),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NOMBRE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasSecondaryColumn) ...[
                        const SizedBox(width: 18),
                        Text(
                          widget.secondaryColumnHeader!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (hasNameFilterActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nameFilterC.text.trim().isEmpty
                                ? '${_nameFilterSelectedNames.length} seleccionados'
                                : _nameFilterC.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF375A77),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Limpiar filtros',
                          onPressed: () {
                            _nameFilterC.clear();
                            setState(() => _nameFilterSelectedNames.clear());
                          },
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 18,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Card(
                elevation: 0.4,
                color: _insertActive
                    ? const Color(0xFFD9ECFA)
                    : const Color(0xFFE7F1F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _insertActive
                        ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
                        : Colors.transparent,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: editableCellMaxWidth,
                            ),
                            child: TextField(
                              focusNode: _insertFocusNode,
                              controller: _insertController,
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter,
                                _NameInputFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                              onTap: () {
                                _focusNode.requestFocus();
                                _activateInsertRow();
                              },
                              onSubmitted: (_) => _insertFromRow(),
                              onTapOutside: (event) {
                                if (event.kind == PointerDeviceKind.mouse &&
                                    event.buttons == kSecondaryButton) {
                                  return;
                                }
                              },
                              decoration: _catalogContractGlassFieldDecoration(
                                hintText: widget.insertHintText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'AGREGAR',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: canInsert
                              ? () => unawaited(_insertFromRow())
                              : null,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: canInsert
                                  ? const Color(
                                      0xFF19C37D,
                                    ).withValues(alpha: 0.92)
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                            child: _inserting
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.add,
                                    size: 18,
                                    color: canInsert
                                        ? Colors.white
                                        : const Color(0xFF0B2B2B),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          widget.emptyText,
                          style: const TextStyle(color: Color(0xFF345454)),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => Divider(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 6,
                          ),
                          itemBuilder: (_, i) {
                            final row = rows[i];
                            final rowId = _rowId(row);
                            final title = (row['name'] ?? '').toString();
                            final subtitle = widget.subtitleOf(row);
                            final inSelection =
                                rowId != null &&
                                _selectedRowIds.contains(rowId);
                            final primarySelected =
                                !_insertActive && i == _selectedIndex;
                            final hovered =
                                rowId != null && _hoveredRowId == rowId;
                            final editing =
                                rowId != null && _editingRowIds.contains(rowId);
                            final editController = rowId == null
                                ? null
                                : _controllerForRow(row);
                            final hasSelection = primarySelected || inSelection;
                            final hoverOnly = hovered && !hasSelection;
                            final highlighted = hasSelection || hovered;
                            final rowBg = editing
                                ? const Color(0xFFCBEFE2)
                                : hasSelection
                                ? _kCatalogTableSelectionAccent.withValues(
                                    alpha: primarySelected ? 0.16 : 0.13,
                                  )
                                : hoverOnly
                                ? const Color(0xFFE9F7EE)
                                : Colors.white;
                            return MouseRegion(
                              key: rowId == null
                                  ? null
                                  : _renderKeyForRow(rowId),
                              onEnter: (_) =>
                                  setState(() => _hoveredRowId = rowId),
                              onExit: (_) {
                                if (_hoveredRowId == rowId && mounted) {
                                  setState(() => _hoveredRowId = null);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                transform: Matrix4.translationValues(
                                  0.0,
                                  highlighted ? -2.0 : 0.0,
                                  0.0,
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onSecondaryTapDown: (details) {
                                    unawaited(
                                      _showRowActionsMenu(
                                        i,
                                        row,
                                        globalPosition: details.globalPosition,
                                      ),
                                    );
                                  },
                                  onDoubleTap: () {
                                    if (rowId != null &&
                                        _selectedRowIds.length > 1 &&
                                        !_selectedRowIds.contains(rowId)) {
                                      _selectedRowIds.add(rowId);
                                    }
                                    _selectIndex(
                                      i,
                                      ensureVisible: false,
                                      additiveToggle: _isCtrlOrCmdPressed(),
                                    );
                                    _enterEditModeForSelection(
                                      preferredRow: row,
                                    );
                                  },
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      _focusNode.requestFocus();
                                      _selectIndex(
                                        i,
                                        ensureVisible: false,
                                        additiveToggle: _isCtrlOrCmdPressed(),
                                      );
                                    },
                                    child: Card(
                                      elevation: highlighted ? 4 : 0.5,
                                      color: rowBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: primarySelected
                                              ? _kCatalogTableSelectionAccent
                                                    .withValues(alpha: 0.65)
                                              : Colors.white.withValues(
                                                  alpha: 0.0,
                                                ),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxWidth:
                                                            editableCellMaxWidth,
                                                      ),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 100,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (hovered || editing)
                                                          ? _kCatalogTableSelectionAccent
                                                                .withValues(
                                                                  alpha: editing
                                                                      ? 0.12
                                                                      : 0.06,
                                                                )
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: editing
                                                            ? _kCatalogTableSelectionAccent
                                                                  .withValues(
                                                                    alpha: 0.25,
                                                                  )
                                                            : hovered
                                                            ? _kCatalogTableSelectionAccent
                                                                  .withValues(
                                                                    alpha: 0.14,
                                                                  )
                                                            : Colors
                                                                  .transparent,
                                                      ),
                                                    ),
                                                    child:
                                                        editing &&
                                                            editController !=
                                                                null
                                                        ? TextField(
                                                            focusNode:
                                                                _focusNodeForRow(
                                                                  rowId,
                                                                ),
                                                            controller:
                                                                editController,
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter
                                                                  .singleLineFormatter,
                                                              _NameInputFormatter(),
                                                            ],
                                                            onTap: () {
                                                              _focusNode
                                                                  .requestFocus();
                                                              setState(() {
                                                                _insertActive =
                                                                    false;
                                                                _activeEditingRowId =
                                                                    rowId;
                                                                _selectedIndex =
                                                                    i;
                                                              });
                                                            },
                                                            onTapOutside: (event) {
                                                              if (event.kind ==
                                                                      PointerDeviceKind
                                                                          .mouse &&
                                                                  event.buttons ==
                                                                      kSecondaryButton) {
                                                                return;
                                                              }
                                                              _cancelEditing();
                                                            },
                                                            decoration: _catalogContractGlassFieldDecoration()
                                                                .copyWith(
                                                                  contentPadding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            7,
                                                                      ),
                                                                ),
                                                          )
                                                        : Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                title,
                                                                maxLines:
                                                                    subtitle ==
                                                                        null
                                                                    ? 2
                                                                    : 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  color: Color(
                                                                    0xFF0B2B2B,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                              if (subtitle !=
                                                                      null &&
                                                                  subtitle
                                                                      .isNotEmpty) ...[
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  subtitle,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Color(
                                                                      0xFF486563,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (hasSecondaryColumn) ...[
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                width: 170,
                                                child: Text(
                                                  widget
                                                      .secondaryColumnValueOf!(
                                                    row,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF0B2B2B),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            _actionButtonForRow(i, row),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
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
      ),
    );
  }
}

class _CatalogList extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final String? Function(Map<String, dynamic>) subtitleOf;
  final Future<void> Function(Map<String, dynamic> row) onEdit;
  final Future<void> Function(Map<String, dynamic> row) onDelete;
  final Future<void> Function(List<Map<String, dynamic>> rows)? onDeleteMany;
  final String deleteTooltip;

  const _CatalogList({
    required this.rows,
    required this.emptyText,
    required this.subtitleOf,
    required this.onEdit,
    required this.onDelete,
    this.onDeleteMany,
    this.deleteTooltip = 'Desactivar',
  });

  @override
  State<_CatalogList> createState() => _CatalogListState();
}

class _InactiveCatalogDialog extends StatefulWidget {
  final String title;
  final String emptyText;
  final String reactivateLabel;
  final Future<List<Map<String, dynamic>>> Function() loadRows;
  final Future<bool> Function(Map<String, dynamic> row) onReactivate;

  const _InactiveCatalogDialog({
    required this.title,
    required this.emptyText,
    required this.loadRows,
    required this.onReactivate,
    this.reactivateLabel = 'Reactivar',
  });

  @override
  State<_InactiveCatalogDialog> createState() => _InactiveCatalogDialogState();
}

class _OpMaterialOpt {
  final String value;
  final String label;
  const _OpMaterialOpt(this.value, this.label);
}

class _InactiveCatalogDialogState extends State<_InactiveCatalogDialog> {
  bool _loading = true;
  bool _changed = false;
  List<Map<String, dynamic>> _rows = const [];
  final Set<String> _reactivatingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.loadRows();
      if (!mounted) return;
      setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reactivate(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || _reactivatingIds.contains(id)) return;
    setState(() => _reactivatingIds.add(id));
    try {
      final ok = await widget.onReactivate(row);
      if (!mounted) return;
      if (ok) {
        _changed = true;
        setState(() {
          _rows = _rows.where((r) => r['id']?.toString() != id).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _reactivatingIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        Navigator.pop(context, _changed);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0B2B2B),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Recargar',
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.pop(context, _changed),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.52),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.70),
                              ),
                            ),
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _rows.isEmpty
                                ? Center(
                                    child: Text(
                                      widget.emptyText,
                                      style: const TextStyle(
                                        color: Color(0xFF345454),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _rows.length,
                                    separatorBuilder: (_, _) => Divider(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                    itemBuilder: (_, i) {
                                      final row = _rows[i];
                                      final id = row['id']?.toString() ?? '';
                                      final title = (row['name'] ?? '')
                                          .toString();
                                      final busy = _reactivatingIds.contains(
                                        id,
                                      );
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
                                        trailing: FilledButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _reactivate(row),
                                          icon: busy
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.replay),
                                          label: Text(widget.reactivateLabel),
                                        ),
                                      );
                                    },
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
      ),
    );
  }
}

class _CatalogListState extends State<_CatalogList> {
  static const double _rowExtentEstimate = 84;

  final FocusNode _focusNode = FocusNode(debugLabel: 'CatalogList');
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _rowRenderKeys = <String, GlobalKey>{};
  int _selectedIndex = 0;
  int? _selectionAnchorIndex;
  final Set<String> _selectedRowIds = <String>{};
  String? _hoveredRowId;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CatalogList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.isEmpty) {
      if (_selectedIndex != 0 ||
          _selectionAnchorIndex != null ||
          _selectedRowIds.isNotEmpty) {
        setState(() {
          _selectedIndex = 0;
          _selectionAnchorIndex = null;
          _selectedRowIds.clear();
        });
      }
      return;
    }
    final validIds = widget.rows
        .map((r) => _rowId(r))
        .whereType<String>()
        .toSet();
    _rowRenderKeys.removeWhere((id, _) => !validIds.contains(id));
    var changed = false;
    final selectedCountBefore = _selectedRowIds.length;
    _selectedRowIds.removeWhere((id) => !validIds.contains(id));
    if (_selectedRowIds.length != selectedCountBefore) {
      changed = true;
    }
    final nextIndex = _selectedIndex.clamp(0, widget.rows.length - 1);
    if (nextIndex != _selectedIndex) {
      _selectedIndex = nextIndex;
      changed = true;
    }
    final primaryId = _selectedRowIdAt(_selectedIndex);
    if (_selectedRowIds.isEmpty && primaryId != null) {
      _selectedRowIds.add(primaryId);
      changed = true;
    } else if (primaryId != null && !_selectedRowIds.contains(primaryId)) {
      _selectedRowIds
        ..clear()
        ..add(primaryId);
      changed = true;
    }
    if (_selectionAnchorIndex == null) {
      _selectionAnchorIndex = _selectedIndex;
      changed = true;
    } else {
      final clampedAnchor = _selectionAnchorIndex!.clamp(
        0,
        widget.rows.length - 1,
      );
      if (clampedAnchor != _selectionAnchorIndex) {
        _selectionAnchorIndex = clampedAnchor;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  String? _rowId(Map<String, dynamic> row) =>
      row['id']?.toString() ?? row['code']?.toString();

  String? _selectedRowIdAt(int index) {
    if (index < 0 || index >= widget.rows.length) return null;
    return _rowId(widget.rows[index]);
  }

  GlobalKey _renderKeyForRow(String id) => _rowRenderKeys.putIfAbsent(
    id,
    () => GlobalKey(debugLabel: 'CatalogListRow-$id'),
  );

  Widget _buildRowActionButton(
    int index,
    Map<String, dynamic> row, {
    bool compact = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => unawaited(_showRowActionsMenu(index, row)),
      child: SizedBox(
        width: compact ? 30 : 32,
        height: compact ? 30 : 32,
        child: const Icon(Icons.more_horiz, color: Color(0xFF0B2B2B)),
      ),
    );
  }

  bool _isCtrlOrCmdPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isSelectionExtendPressed() =>
      _isCtrlOrCmdPressed() || HardwareKeyboard.instance.isShiftPressed;

  void _selectIndex(
    int index, {
    bool ensureVisible = true,
    bool additive = false,
    bool additiveToggle = false,
    int? ensureMoveDelta,
  }) {
    if (widget.rows.isEmpty) return;
    final clamped = index.clamp(0, widget.rows.length - 1);
    final id = _selectedRowIdAt(clamped);
    if (id == null) return;
    setState(() {
      _selectedIndex = clamped;
      _selectionAnchorIndex ??= clamped;
      if (additive) {
        _selectedRowIds.add(id);
        _selectionAnchorIndex = clamped;
      } else if (additiveToggle) {
        if (_selectedRowIds.contains(id) && _selectedRowIds.length > 1) {
          _selectedRowIds.remove(id);
        } else {
          _selectedRowIds.add(id);
        }
        _selectionAnchorIndex = clamped;
      } else {
        _selectedRowIds
          ..clear()
          ..add(id);
        _selectionAnchorIndex = clamped;
      }
    });
    if (ensureVisible) _ensureVisible(clamped, moveDelta: ensureMoveDelta);
  }

  void _moveSelectedRow(int delta) {
    if (widget.rows.isEmpty) return;
    final nextIndex = widget.rows.isEmpty
        ? 0
        : (((_selectedIndex + delta) % widget.rows.length) +
                  widget.rows.length) %
              widget.rows.length;
    _selectIndex(nextIndex, ensureMoveDelta: delta);
  }

  void _extendSelectionWithArrow(int delta) {
    if (widget.rows.isEmpty) return;
    final currentId = _selectedRowIdAt(_selectedIndex);
    if (currentId != null) {
      _selectedRowIds.add(currentId);
    }
    final nextIndex = widget.rows.isEmpty
        ? 0
        : (((_selectedIndex + delta) % widget.rows.length) +
                  widget.rows.length) %
              widget.rows.length;
    _selectIndex(nextIndex, additive: true, ensureMoveDelta: delta);
  }

  Future<void> _deleteSelection() async {
    if (widget.rows.isEmpty) return;
    final ids = _selectedRowIds.isEmpty
        ? <String>{
            if (_selectedRowIdAt(_selectedIndex) != null)
              _selectedRowIdAt(_selectedIndex)!,
          }
        : Set<String>.from(_selectedRowIds);
    if (ids.isEmpty) return;
    final rows = widget.rows
        .where((r) => ids.contains(_rowId(r)))
        .toList(growable: false);
    if (rows.isEmpty) return;
    if (rows.length > 1 && widget.onDeleteMany != null) {
      await widget.onDeleteMany!(rows);
      return;
    }
    for (final row in rows) {
      await widget.onDelete(row);
    }
  }

  Future<void> _showRowActionsMenu(
    int index,
    Map<String, dynamic> row, {
    Offset? globalPosition,
  }) async {
    _focusNode.requestFocus();
    final rowId = _rowId(row);
    if (rowId == null) return;
    if (!_selectedRowIds.contains(rowId)) {
      _selectIndex(
        index,
        ensureVisible: false,
        additiveToggle: globalPosition == null ? false : _isCtrlOrCmdPressed(),
      );
    } else {
      setState(() => _selectedIndex = index);
    }

    final rowsToDelete =
        _selectedRowIds.length > 1 && widget.onDeleteMany != null
        ? widget.rows
              .where((r) => _selectedRowIds.contains(_rowId(r)))
              .toList(growable: false)
        : <Map<String, dynamic>>[];

    final overlay = Overlay.of(context).context.findRenderObject();
    final position = (globalPosition != null && overlay is RenderBox)
        ? RelativeRect.fromRect(
            Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(0, 0, 0, 0);

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: _kCatalogTableGlassMenuBg,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('EDITAR', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            rowsToDelete.isNotEmpty
                ? '${widget.deleteTooltip.toUpperCase()} (${rowsToDelete.length})'
                : widget.deleteTooltip.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    switch (action) {
      case 'edit':
        await widget.onEdit(row);
        break;
      case 'delete':
        if (rowsToDelete.isNotEmpty) {
          await widget.onDeleteMany!(rowsToDelete);
        } else {
          await widget.onDelete(row);
        }
        break;
    }
  }

  void _ensureVisible(int index, {int? moveDelta}) {
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : moveDelta < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;

    final rowId = _selectedRowIdAt(index);
    if (rowId != null) {
      final rowContext = _rowRenderKeys[rowId]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignmentPolicy: alignmentPolicy,
        );
        return;
      }
    }

    if (_scrollController.hasClients) {
      final target = (index * _rowExtentEstimate).toDouble();
      final viewport = _scrollController.position.viewportDimension;
      final current = _scrollController.offset;
      final minVisible = current;
      final maxVisible = current + viewport - _rowExtentEstimate;
      if (target < minVisible) {
        _scrollController.animateTo(
          target.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (target > maxVisible) {
        final nextOffset = target - (viewport - _rowExtentEstimate);
        _scrollController.animateTo(
          nextOffset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _selectedRowIdAt(index);
      if (id == null) return;
      final rowContext = _rowRenderKeys[id]?.currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (widget.rows.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_isSelectionExtendPressed()) {
        _extendSelectionWithArrow(1);
      } else {
        _moveSelectedRow(1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_isSelectionExtendPressed()) {
        _extendSelectionWithArrow(-1);
      } else {
        _moveSelectedRow(-1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      unawaited(widget.onEdit(widget.rows[_selectedIndex]));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      unawaited(_deleteSelection());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      unawaited(widget.onEdit(widget.rows[_selectedIndex]));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedRowIds.length > 1) {
        _selectIndex(_selectedIndex, ensureVisible: false);
      } else {
        node.unfocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _focusNode.requestFocus();
          _selectIndex(_selectedIndex, ensureVisible: false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? _kCatalogTableSelectionAccent.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.48),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Colors.white.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      return Row(
                        children: [
                          const Icon(
                            Icons.table_rows_rounded,
                            size: 15,
                            color: Color(0xFF2A4B49),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.rows.length} renglones',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A4B49),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedRowIds.length} seleccionados',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (!compact)
                            const Flexible(
                              child: Text(
                                'Enter editar · Delete borrar · Ctrl/Cmd + ↑↓ multiselección · Click derecho/… acciones',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A4B49),
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Enter · Delete · Ctrl/Cmd',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF486563),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Colors.black.withValues(alpha: 0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'NOMBRE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Spacer(),
                      SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: widget.rows.isEmpty
                    ? Center(
                        child: Text(
                          widget.emptyText,
                          style: const TextStyle(color: Color(0xFF345454)),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: widget.rows.length,
                          separatorBuilder: (_, _) => Divider(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 6,
                          ),
                          itemBuilder: (_, i) {
                            final row = widget.rows[i];
                            final rowId = _rowId(row);
                            final title = (row['name'] ?? '').toString();
                            final subtitle = widget.subtitleOf(row);
                            final inSelection =
                                rowId != null &&
                                _selectedRowIds.contains(rowId);
                            final hovered =
                                rowId != null && _hoveredRowId == rowId;
                            final primarySelected =
                                _focusNode.hasFocus && i == _selectedIndex;
                            final hasSelection = primarySelected || inSelection;
                            final hoverOnly = hovered && !hasSelection;
                            final highlighted = hasSelection || hovered;
                            final rowBg = hasSelection
                                ? _kCatalogTableSelectionAccent.withValues(
                                    alpha: primarySelected ? 0.16 : 0.13,
                                  )
                                : hoverOnly
                                ? const Color(0xFFE9F7EE)
                                : Colors.white;
                            return MouseRegion(
                              key: rowId == null
                                  ? null
                                  : _renderKeyForRow(rowId),
                              onEnter: (_) =>
                                  setState(() => _hoveredRowId = rowId),
                              onExit: (_) {
                                if (_hoveredRowId == rowId && mounted) {
                                  setState(() => _hoveredRowId = null);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                transform: Matrix4.translationValues(
                                  0.0,
                                  highlighted ? -2.0 : 0.0,
                                  0.0,
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onSecondaryTapDown: (details) {
                                    unawaited(
                                      _showRowActionsMenu(
                                        i,
                                        row,
                                        globalPosition: details.globalPosition,
                                      ),
                                    );
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 520;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          _focusNode.requestFocus();
                                          _selectIndex(
                                            i,
                                            ensureVisible: false,
                                            additiveToggle:
                                                _isCtrlOrCmdPressed(),
                                          );
                                        },
                                        onLongPress: () {
                                          _focusNode.requestFocus();
                                          _selectIndex(i, ensureVisible: false);
                                          unawaited(widget.onEdit(row));
                                        },
                                        child: Card(
                                          elevation: highlighted ? 4 : 0.5,
                                          color: rowBg,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: primarySelected
                                                  ? _kCatalogTableSelectionAccent
                                                        .withValues(alpha: 0.65)
                                                  : Colors.white.withValues(
                                                      alpha: 0.0,
                                                    ),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        title,
                                                        maxLines:
                                                            subtitle == null
                                                            ? 2
                                                            : 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF0B2B2B,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      if (subtitle != null &&
                                                          subtitle
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          subtitle,
                                                          maxLines: compact
                                                              ? 1
                                                              : 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF486563,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildRowActionButton(
                                                  i,
                                                  row,
                                                  compact: compact,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
      ),
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
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
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
