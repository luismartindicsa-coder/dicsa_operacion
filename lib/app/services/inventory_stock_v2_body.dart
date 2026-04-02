import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'inventory_movements_grid.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';

class InventoryStockV2Body extends StatefulWidget {
  final TabController controller;
  final void Function(int tabIndex, InventoryGridTopBarData data)?
  onTopBarChanged;

  const InventoryStockV2Body({
    super.key,
    required this.controller,
    this.onTopBarChanged,
  });

  @override
  State<InventoryStockV2Body> createState() => _InventoryStockV2BodyState();
}

class _InventoryStockV2BodyState extends State<InventoryStockV2Body> {
  final SupabaseClient supa = Supabase.instance.client;
  final TextEditingController _generalFilterC = TextEditingController();
  final TextEditingController _commercialFilterC = TextEditingController();
  final TextEditingController _openingsFilterC = TextEditingController();
  RealtimeChannel? _realtime;

  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  bool _exporting = false;
  bool _generalOnlyPositive = false;
  bool _commercialOnlyPositive = false;
  bool _openingsOnlyGeneral = false;
  DateTime _selectedPeriodMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  final String _selectedSite = 'DICSA_CELAYA';

  List<_StockBalanceRow> _generalRows = <_StockBalanceRow>[];
  List<_StockBalanceRow> _commercialRows = <_StockBalanceRow>[];
  List<_OpeningBalanceV2Row> _openingRows = <_OpeningBalanceV2Row>[];
  List<_MaterialOptionV2> _generalOptions = <_MaterialOptionV2>[];
  List<_MaterialOptionV2> _commercialOptions = <_MaterialOptionV2>[];

  List<_StockBalanceRow> get _filteredGeneralRows {
    final query = _generalFilterC.text.trim().toLowerCase();
    return _generalRows.where((row) {
      if (_generalOnlyPositive && row.onHandKg <= 0) return false;
      if (query.isEmpty) return true;
      return row.code.toLowerCase().contains(query) ||
          row.name.toLowerCase().contains(query);
    }).toList();
  }

  List<_StockBalanceRow> get _filteredCommercialRows {
    final query = _commercialFilterC.text.trim().toLowerCase();
    return _commercialRows.where((row) {
      if (_commercialOnlyPositive && row.onHandKg <= 0) return false;
      if (query.isEmpty) return true;
      return row.code.toLowerCase().contains(query) ||
          row.name.toLowerCase().contains(query) ||
          row.family.toLowerCase().contains(query);
    }).toList();
  }

  List<_OpeningBalanceV2Row> get _filteredOpeningRows {
    final query = _openingsFilterC.text.trim().toLowerCase();
    return _openingRows.where((row) {
      if (_openingsOnlyGeneral && row.inventoryLevel != 'GENERAL') return false;
      if (query.isEmpty) return true;
      return row.materialCode.toLowerCase().contains(query) ||
          row.materialName.toLowerCase().contains(query) ||
          row.notes.toLowerCase().contains(query) ||
          row.inventoryLevel.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTabChanged);
    _generalFilterC.addListener(_handleFilterChanged);
    _commercialFilterC.addListener(_handleFilterChanged);
    _openingsFilterC.addListener(_handleFilterChanged);
    unawaited(_loadAll());
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant InventoryStockV2Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleTabChanged);
    widget.controller.addListener(_handleTabChanged);
    _publishTopBarData();
  }

  void _handleTabChanged() {
    if (!mounted || widget.controller.indexIsChanging) return;
    _publishTopBarData();
  }

  void _handleFilterChanged() {
    if (!mounted) return;
    setState(() {});
    _publishTopBarData();
  }

  void _setupRealtime() {
    _realtime?.unsubscribe();
    _realtime = supa
        .channel('inventory-stock-v2-body')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_opening_balances_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_general_catalog_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_commercial_catalog_v2',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        supa
            .from('v_inventory_general_balance_v2')
            .select(
              'id,code,name,opening_kg,movement_kg,on_hand_kg,opening_units,movement_units,on_hand_units',
            )
            .order('name'),
        supa
            .from('v_inventory_commercial_balance_v2')
            .select(
              'id,code,name,family,general_code,opening_kg,movement_kg,on_hand_kg,opening_units,movement_units,on_hand_units',
            )
            .order('family')
            .order('name'),
        supa
            .from('inventory_opening_balances_v2')
            .select(
              'id,period_month,as_of_date,inventory_level,weight_kg,unit_count,site,notes,'
              'general_material:general_material_id(id,code,name),'
              'commercial_material:commercial_material_id(id,code,name,family)',
            )
            .eq('period_month', _fmtDbDate(_selectedPeriodMonth))
            .eq('site', _selectedSite)
            .order('inventory_level')
            .order('created_at'),
        supa
            .from('material_general_catalog_v2')
            .select('id,code,name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
        supa
            .from('material_commercial_catalog_v2')
            .select('id,code,name,family')
            .eq('is_active', true)
            .eq('tracks_patio_stock', true)
            .order('family')
            .order('sort_order')
            .order('name'),
      ]);

      final generalRows = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => _StockBalanceRow(
              code: (row['code'] ?? '').toString(),
              name: (row['name'] ?? '').toString(),
              family: 'GENERAL',
              openingKg: _toDouble(row['opening_kg']) ?? 0,
              movementKg: _toDouble(row['movement_kg']) ?? 0,
              onHandKg: _toDouble(row['on_hand_kg']) ?? 0,
              openingUnits: _toInt(row['opening_units']) ?? 0,
              movementUnits: _toInt(row['movement_units']) ?? 0,
              onHandUnits: _toInt(row['on_hand_units']) ?? 0,
            ),
          )
          .toList();
      final commercialRows = (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => _StockBalanceRow(
              code: (row['code'] ?? '').toString(),
              name: (row['name'] ?? '').toString(),
              family: (row['family'] ?? '').toString(),
              openingKg: _toDouble(row['opening_kg']) ?? 0,
              movementKg: _toDouble(row['movement_kg']) ?? 0,
              onHandKg: _toDouble(row['on_hand_kg']) ?? 0,
              openingUnits: _toInt(row['opening_units']) ?? 0,
              movementUnits: _toInt(row['movement_units']) ?? 0,
              onHandUnits: _toInt(row['on_hand_units']) ?? 0,
            ),
          )
          .toList();
      final openingRows = (results[2] as List)
          .cast<Map<String, dynamic>>()
          .map(_mapOpeningRow)
          .toList();
      final generalOptions = (results[3] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => _MaterialOptionV2(
              id: (row['id'] ?? '').toString(),
              code: (row['code'] ?? '').toString(),
              name: (row['name'] ?? '').toString(),
            ),
          )
          .toList();
      final commercialOptions = (results[4] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => _MaterialOptionV2(
              id: (row['id'] ?? '').toString(),
              code: (row['code'] ?? '').toString(),
              name: (row['name'] ?? '').toString(),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _generalRows = generalRows;
        _commercialRows = commercialRows;
        _openingRows = openingRows;
        _generalOptions = generalOptions;
        _commercialOptions = commercialOptions;
      });
      _publishTopBarData();
    } catch (e) {
      _toast('No se pudo cargar inventario v2: $e');
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _realtime?.unsubscribe();
    widget.controller.removeListener(_handleTabChanged);
    _generalFilterC.dispose();
    _commercialFilterC.dispose();
    _openingsFilterC.dispose();
    super.dispose();
  }

  void _publishTopBarData() {
    if (widget.onTopBarChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var index = 0; index < 3; index++) {
        widget.onTopBarChanged!(index, _buildTopBarData(index));
      }
    });
  }

  InventoryGridTopBarData _buildTopBarData(int tabIndex) {
    switch (tabIndex) {
      case 0:
        final rows = _filteredGeneralRows;
        final totalKg = rows.fold<double>(0, (sum, row) => sum + row.onHandKg);
        return InventoryGridTopBarData(
          metricIcon: Icons.inventory_2_outlined,
          metricLabel: 'NETO INVENTARIO GENERAL',
          metricValue: '${totalKg.toStringAsFixed(2)} kg',
          metricSubtitle: 'Filtrado (${rows.length} registros)',
          exportingCsv: _exporting,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: false,
          deletingSelection: false,
          selectedCount: 0,
          onExportCsv: _exportGeneralCsv,
        );
      case 1:
        final rows = _filteredCommercialRows;
        final totalKg = rows.fold<double>(0, (sum, row) => sum + row.onHandKg);
        final totalUnits = rows.fold<int>(
          0,
          (sum, row) => sum + row.onHandUnits,
        );
        return InventoryGridTopBarData(
          metricIcon: Icons.warehouse_outlined,
          metricLabel: 'NETO INVENTARIO PATIO',
          metricValue: totalUnits > 0
              ? '${totalKg.toStringAsFixed(2)} kg · $totalUnits pacas'
              : '${totalKg.toStringAsFixed(2)} kg',
          metricSubtitle: 'Filtrado (${rows.length} registros)',
          exportingCsv: _exporting,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: false,
          deletingSelection: false,
          selectedCount: 0,
          onExportCsv: _exportCommercialCsv,
        );
      default:
        final rows = _filteredOpeningRows;
        final totalKg = rows.fold<double>(0, (sum, row) => sum + row.weightKg);
        final totalUnits = rows.fold<int>(
          0,
          (sum, row) => sum + (row.unitCount ?? 0),
        );
        return InventoryGridTopBarData(
          metricIcon: Icons.event_note_rounded,
          metricLabel: 'APERTURAS DEL MES',
          metricValue: totalUnits > 0
              ? '${totalKg.toStringAsFixed(2)} kg · $totalUnits pacas'
              : '${totalKg.toStringAsFixed(2)} kg',
          metricSubtitle: 'Filtrado (${rows.length} registros)',
          exportingCsv: _exporting,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: false,
          deletingSelection: false,
          selectedCount: 0,
          onExportCsv: _exportOpeningsCsv,
        );
    }
  }

  _OpeningBalanceV2Row _mapOpeningRow(Map<String, dynamic> row) {
    final level = (row['inventory_level'] ?? '').toString();
    final general = (row['general_material'] as Map?)?.cast<String, dynamic>();
    final commercial = (row['commercial_material'] as Map?)
        ?.cast<String, dynamic>();
    return _OpeningBalanceV2Row(
      id: (row['id'] ?? '').toString(),
      inventoryLevel: level,
      materialId: level == 'GENERAL'
          ? (general?['id'] ?? '').toString()
          : (commercial?['id'] ?? '').toString(),
      materialCode: level == 'GENERAL'
          ? (general?['code'] ?? '').toString()
          : (commercial?['code'] ?? '').toString(),
      materialName: level == 'GENERAL'
          ? (general?['name'] ?? '').toString()
          : (commercial?['name'] ?? '').toString(),
      weightKg: _toDouble(row['weight_kg']) ?? 0,
      unitCount: _toInt(row['unit_count']),
      notes: (row['notes'] ?? '').toString(),
      asOfDate: _parseDate(row['as_of_date']),
    );
  }

  Future<void> _pickPeriodMonth() async {
    final picked = await _showInventoryLikeDatePickerDialog(
      context: context,
      initialDate: _selectedPeriodMonth,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null) return;
    setState(
      () => _selectedPeriodMonth = DateTime(picked.year, picked.month, 1),
    );
    await _loadAll();
  }

  Future<void> _createOpening() async {
    final result = await _showOpeningDialog();
    if (result == null) return;
    try {
      await supa.from('inventory_opening_balances_v2').insert({
        'period_month': _fmtDbDate(_selectedPeriodMonth),
        'as_of_date': _fmtDbDate(result.asOfDate),
        'inventory_level': result.inventoryLevel,
        'general_material_id': result.inventoryLevel == 'GENERAL'
            ? result.materialId
            : null,
        'commercial_material_id': result.inventoryLevel == 'COMMERCIAL'
            ? result.materialId
            : null,
        'weight_kg': result.weightKg,
        'unit_count': result.unitCount,
        'site': _selectedSite,
        'notes': result.notes.isEmpty ? null : result.notes,
      });
      await _loadAll();
      _toast('Apertura agregada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo agregar la apertura.',
        ),
      );
    } catch (e) {
      _toast('No se pudo agregar apertura: $e');
    }
  }

  Future<void> _editOpening(_OpeningBalanceV2Row row) async {
    final result = await _showOpeningDialog(existing: row);
    if (result == null) return;
    try {
      await supa
          .from('inventory_opening_balances_v2')
          .update({
            'as_of_date': _fmtDbDate(result.asOfDate),
            'inventory_level': result.inventoryLevel,
            'general_material_id': result.inventoryLevel == 'GENERAL'
                ? result.materialId
                : null,
            'commercial_material_id': result.inventoryLevel == 'COMMERCIAL'
                ? result.materialId
                : null,
            'weight_kg': result.weightKg,
            'unit_count': result.unitCount,
            'notes': result.notes.isEmpty ? null : result.notes,
          })
          .eq('id', row.id);
      await _loadAll();
      _toast('Apertura actualizada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo actualizar la apertura.',
        ),
      );
    } catch (e) {
      _toast('No se pudo actualizar apertura: $e');
    }
  }

  Future<void> _deleteOpening(_OpeningBalanceV2Row row) async {
    final ok = await showContractConfirmationDialog(
      context,
      title: 'Eliminar apertura',
      content: '¿Eliminar apertura de ${row.materialName}?',
      confirmText: 'Eliminar',
    );
    if (ok != true) return;
    try {
      await supa
          .from('inventory_opening_balances_v2')
          .delete()
          .eq('id', row.id);
      await _loadAll();
      _toast('Apertura eliminada');
    } on PostgrestException catch (e) {
      _toast(
        _friendlyPostgrestMessage(
          e,
          fallbackAction: 'No se pudo eliminar la apertura.',
        ),
      );
    } catch (e) {
      _toast('No se pudo eliminar apertura: $e');
    }
  }

  Future<_OpeningDialogResult?> _showOpeningDialog({
    _OpeningBalanceV2Row? existing,
  }) async {
    var level = existing?.inventoryLevel ?? 'GENERAL';
    var materialId = existing?.materialId;
    var asOfDate = existing?.asOfDate ?? _selectedPeriodMonth;
    final kgC = TextEditingController(
      text: existing == null ? '' : existing.weightKg.toStringAsFixed(2),
    );
    final unitCountC = TextEditingController(
      text: existing?.unitCount?.toString() ?? '',
    );
    final notesC = TextEditingController(text: existing?.notes ?? '');

    final result = await showDialog<_OpeningDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final options = level == 'GENERAL'
                ? _generalOptions
                : _commercialOptions;
            materialId = options.any((opt) => opt.id == materialId)
                ? materialId
                : (options.isEmpty ? null : options.first.id);
            _MaterialOptionV2? selectedOption;
            for (final option in options) {
              if (option.id == materialId) {
                selectedOption = option;
                break;
              }
            }
            final selectedMaterialLabel = options
                .where((opt) => opt.id == materialId)
                .map((opt) => opt.name)
                .fold<String?>(null, (_, name) => name);
            final requiresUnitCount =
                level == 'COMMERCIAL' &&
                isCountedBaleCommercialCode(selectedOption?.code);
            return ContractDialogShell(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: SizedBox(
                  width: 560,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'Nueva apertura' : 'Editar apertura',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14373B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nivel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _OpeningDialogPickerField(
                        label: level == 'GENERAL'
                            ? 'General'
                            : 'Patio clasificado',
                        hintText: 'Selecciona nivel',
                        icon: Icons.layers_outlined,
                        onOpen: () async {
                          final selected =
                              await showSearchablePickerDialog<String>(
                                context,
                                title: 'Nivel',
                                initialValue: level,
                                options: const [
                                  SearchablePickerOption(
                                    value: 'GENERAL',
                                    label: 'General',
                                  ),
                                  SearchablePickerOption(
                                    value: 'COMMERCIAL',
                                    label: 'Patio clasificado',
                                  ),
                                ],
                              );
                          if (selected == null) return;
                          setLocal(() {
                            level = selected;
                            materialId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Material',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _OpeningDialogPickerField(
                        label: selectedMaterialLabel,
                        hintText: 'Selecciona material',
                        icon: Icons.inventory_2_outlined,
                        onOpen: () async {
                          final selected =
                              await showSearchablePickerDialog<String>(
                                context,
                                title: 'Material',
                                initialValue: materialId,
                                options: options
                                    .map(
                                      (opt) => SearchablePickerOption<String>(
                                        value: opt.id,
                                        label: opt.name,
                                      ),
                                    )
                                    .toList(),
                              );
                          if (selected == null) return;
                          setLocal(() => materialId = selected);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fecha de apertura',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _OpeningDialogPickerField(
                        label: _fmtUiDate(asOfDate),
                        hintText: 'Fecha',
                        icon: Icons.calendar_month_rounded,
                        onOpen: () async {
                          final picked =
                              await _showInventoryLikeDatePickerDialog(
                                context: context,
                                initialDate: asOfDate,
                                firstDate: DateTime(2024, 1, 1),
                                lastDate: DateTime(2035, 12, 31),
                              );
                          if (picked == null) return;
                          setLocal(() => asOfDate = DateUtils.dateOnly(picked));
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Kg apertura',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: kgC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Kg apertura',
                        ),
                      ),
                      if (requiresUnitCount) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Pacas contadas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A4B49),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: unitCountC,
                          keyboardType: TextInputType.number,
                          decoration: contractGlassFieldDecoration(
                            context,
                            hintText: 'Numero de pacas',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Notas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesC,
                        minLines: 2,
                        maxLines: 3,
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Notas',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(context),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: () {
                              final kg = _toDouble(kgC.text);
                              final unitCount = _toInt(unitCountC.text);
                              if (materialId == null || kg == null || kg < 0) {
                                _toast('Completa material y kg válidos.');
                                return;
                              }
                              if (requiresUnitCount &&
                                  (unitCount == null || unitCount <= 0)) {
                                _toast('Captura las pacas contadas.');
                                return;
                              }
                              Navigator.of(context).pop(
                                _OpeningDialogResult(
                                  inventoryLevel: level,
                                  materialId: materialId!,
                                  weightKg: kg,
                                  unitCount: requiresUnitCount
                                      ? unitCount
                                      : null,
                                  notes: notesC.text.trim(),
                                  asOfDate: asOfDate,
                                ),
                              );
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
          },
        );
      },
    );

    kgC.dispose();
    unitCountC.dispose();
    notesC.dispose();
    return result;
  }

  Future<void> _exportCsv(List<List<Object?>> rows, String fileName) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    _publishTopBarData();
    try {
      final sb = StringBuffer()..write('\uFEFF');
      for (final row in rows) {
        sb.writeln(row.map(_csvEscape).join(','));
      }
      final path = await _saveFile(fileName, sb.toString());
      _toast(
        path == null ? 'No se pudo exportar CSV' : 'CSV exportado en: $path',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
      _publishTopBarData();
    }
  }

  Future<void> _exportGeneralCsv() => _exportCsv(<List<Object?>>[
    <Object?>[
      'codigo',
      'material',
      'opening_kg',
      'movement_kg',
      'on_hand_kg',
      'opening_units',
      'movement_units',
      'on_hand_units',
    ],
    ..._filteredGeneralRows.map(
      (row) => <Object?>[
        row.code,
        row.name,
        row.openingKg,
        row.movementKg,
        row.onHandKg,
        row.openingUnits,
        row.movementUnits,
        row.onHandUnits,
      ],
    ),
  ], 'inventario_general_v2_${_fmtDbDate(DateTime.now())}.csv');

  Future<void> _exportCommercialCsv() => _exportCsv(<List<Object?>>[
    <Object?>[
      'codigo',
      'material',
      'familia',
      'opening_kg',
      'movement_kg',
      'on_hand_kg',
      'opening_units',
      'movement_units',
      'on_hand_units',
    ],
    ..._filteredCommercialRows.map(
      (row) => <Object?>[
        row.code,
        row.name,
        row.family,
        row.openingKg,
        row.movementKg,
        row.onHandKg,
        row.openingUnits,
        row.movementUnits,
        row.onHandUnits,
      ],
    ),
  ], 'inventario_patio_v2_${_fmtDbDate(DateTime.now())}.csv');

  Future<void> _exportOpeningsCsv() => _exportCsv(<List<Object?>>[
    <Object?>['nivel', 'codigo', 'material', 'fecha', 'kg', 'pacas', 'notas'],
    ..._filteredOpeningRows.map(
      (row) => <Object?>[
        row.inventoryLevel,
        row.materialCode,
        row.materialName,
        _fmtDbDate(row.asOfDate),
        row.weightKg,
        row.unitCount,
        row.notes,
      ],
    ),
  ], 'aperturas_v2_${_fmtDbDate(_selectedPeriodMonth)}.csv');

  String _csvEscape(Object? value) {
    if (value == null) return '';
    final text = value.toString().replaceAll('"', '""');
    if (text.contains(',') || text.contains('\n') || text.contains('"')) {
      return '"$text"';
    }
    return text;
  }

  Future<String?> _saveFile(String fileName, String content) => saveCsvFile(
    fileName: fileName,
    content: content,
    dialogTitle: 'Guardar CSV de inventario',
  );

  double? _toDouble(dynamic value) {
    final raw = value?.toString().trim().replaceAll(',', '') ?? '';
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int? _toInt(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  DateTime _parseDate(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.length >= 10) {
      final year = int.tryParse(raw.substring(0, 4));
      final month = int.tryParse(raw.substring(5, 7));
      final day = int.tryParse(raw.substring(8, 10));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _fmtDbDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _fmtUiDate(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyPostgrestMessage(
    PostgrestException error, {
    required String fallbackAction,
  }) {
    final message = error.message.trim();
    final details = (error.details ?? '').toString().trim();
    final hint = (error.hint ?? '').toString().trim();
    if (error.code == 'P0001' && message.isNotEmpty) {
      return message;
    }
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'Ya existe una apertura para ese material en el periodo seleccionado.';
    }
    if (message.contains('foreign key') ||
        message.contains('violates foreign key')) {
      return 'El material seleccionado ya no es válido en el catálogo.';
    }
    final raw = <String>[
      message,
      details,
      hint,
    ].where((part) => part.isNotEmpty).join(' ');
    return raw.isEmpty ? fallbackAction : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeTab = widget.controller.index;
    final filteredGeneralRows = _filteredGeneralRows;
    final filteredCommercialRows = _filteredCommercialRows;
    final filteredOpeningRows = _filteredOpeningRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: _pickPeriodMonth,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      'Mes: ${_selectedPeriodMonth.month}/${_selectedPeriodMonth.year}',
                    ),
                  ),
                  if (activeTab == 2)
                    FilledButton.icon(
                      style: contractPrimaryButtonStyle(context),
                      onPressed: _createOpening,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva apertura'),
                    ),
                ],
              );
              final info = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exporting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_exporting) const SizedBox(width: 8),
                  Text(
                    activeTab == 0
                        ? '${filteredGeneralRows.length} materiales generales'
                        : activeTab == 1
                        ? '${filteredCommercialRows.length} materiales en patio'
                        : '${filteredOpeningRows.length} aperturas del mes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A4B49),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 12),
                  info,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _InventoryTableFilterBar(
          controller: activeTab == 0
              ? _generalFilterC
              : activeTab == 1
              ? _commercialFilterC
              : _openingsFilterC,
          hintText: activeTab == 0
              ? 'Filtrar materia prima por codigo o material'
              : activeTab == 1
              ? 'Filtrar patio por codigo, material o familia'
              : 'Filtrar aperturas por codigo, material o notas',
          toggleLabel: activeTab == 0
              ? 'Solo con stock'
              : activeTab == 1
              ? 'Solo con stock'
              : 'Solo general',
          toggleValue: activeTab == 0
              ? _generalOnlyPositive
              : activeTab == 1
              ? _commercialOnlyPositive
              : _openingsOnlyGeneral,
          onToggleChanged: (value) {
            setState(() {
              if (activeTab == 0) {
                _generalOnlyPositive = value;
              } else if (activeTab == 1) {
                _commercialOnlyPositive = value;
              } else {
                _openingsOnlyGeneral = value;
              }
            });
            _publishTopBarData();
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: widget.controller,
            children: [
              _StockTableCard(
                title: 'Inventario general',
                rows: filteredGeneralRows,
              ),
              _StockTableCard(
                title: 'Inventario clasificado en patio',
                rows: filteredCommercialRows,
                showFamily: true,
              ),
              _OpeningsTableCard(
                rows: filteredOpeningRows,
                onEdit: _editOpening,
                onDelete: _deleteOpening,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockTableCard extends StatelessWidget {
  final String title;
  final List<_StockBalanceRow> rows;
  final bool showFamily;

  const _StockTableCard({
    required this.title,
    required this.rows,
    this.showFamily = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < (showFamily ? 1120 : 960);
        return ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rows.length} registros',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!compact) ...[
                _StockTableHeader(showFamily: showFamily),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Sin datos'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return compact
                              ? _CompactStockRow(
                                  row: row,
                                  showFamily: showFamily,
                                )
                              : _WideStockRow(row: row, showFamily: showFamily);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpeningsTableCard extends StatelessWidget {
  final List<_OpeningBalanceV2Row> rows;
  final Future<void> Function(_OpeningBalanceV2Row row) onEdit;
  final Future<void> Function(_OpeningBalanceV2Row row) onDelete;

  const _OpeningsTableCard({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1160;
        return ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APERTURAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  '${rows.length} registros',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B2B2B),
                  ),
                ),
              ),
              if (!compact) ...[
                const _OpeningsTableHeader(),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('Sin aperturas para este mes'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return compact
                              ? _CompactOpeningRow(
                                  row: row,
                                  onEdit: onEdit,
                                  onDelete: onDelete,
                                )
                              : _WideOpeningRow(
                                  row: row,
                                  onEdit: onEdit,
                                  onDelete: onDelete,
                                );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryTableFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String toggleLabel;
  final bool toggleValue;
  final ValueChanged<bool> onToggleChanged;

  const _InventoryTableFilterBar({
    required this.controller,
    required this.hintText,
    required this.toggleLabel,
    required this.toggleValue,
    required this.onToggleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final field = SizedBox(
            width: constraints.maxWidth < 760 ? double.infinity : 360,
            child: TextField(
              controller: controller,
              decoration: contractGlassFieldDecoration(
                context,
                hintText: hintText,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          );
          final toggle = FilterChip(
            selected: toggleValue,
            onSelected: onToggleChanged,
            label: Text(toggleLabel),
            avatar: Icon(
              Icons.filter_alt_rounded,
              size: 16,
              color: toggleValue
                  ? const Color(0xFF0B2B2B)
                  : const Color(0xFF486461),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.54),
            selectedColor: const Color(0xFFD8EFE8),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.68)),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [toggle]),
              ],
            );
          }

          return Row(children: [field, const SizedBox(width: 12), toggle]);
        },
      ),
    );
  }
}

class _OpeningDialogPickerField extends StatelessWidget {
  final String? label;
  final String hintText;
  final IconData icon;
  final Future<void> Function() onOpen;

  const _OpeningDialogPickerField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.arrowDown) {
          onOpen();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onOpen()),
        child: InputDecorator(
          decoration: contractGlassFieldDecoration(
            context,
            hintText: hintText,
            prefixIcon: Icon(icon),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  (label ?? '').trim().isEmpty ? hintText : label!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: (label ?? '').trim().isEmpty
                        ? const Color(0xFF6B7F83)
                        : const Color(0xFF14373B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF486461),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockTableHeader extends StatelessWidget {
  final bool showFamily;

  const _StockTableHeader({required this.showFamily});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 110, child: _HeaderText('CODIGO')),
          const SizedBox(width: 12),
          const Expanded(flex: 3, child: _HeaderText('MATERIAL')),
          if (showFamily) ...[
            const SizedBox(width: 12),
            const SizedBox(width: 110, child: _HeaderText('FAMILIA')),
          ],
          const SizedBox(width: 12),
          const SizedBox(width: 120, child: _HeaderText('APERTURA')),
          const SizedBox(width: 12),
          const SizedBox(width: 120, child: _HeaderText('MOVIMIENTO')),
          const SizedBox(width: 12),
          const SizedBox(width: 122, child: _HeaderText('EXISTENCIA')),
        ],
      ),
    );
  }
}

class _OpeningsTableHeader extends StatelessWidget {
  const _OpeningsTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          SizedBox(width: 88, child: _HeaderText('NIVEL')),
          SizedBox(width: 12),
          SizedBox(width: 110, child: _HeaderText('CODIGO')),
          SizedBox(width: 12),
          Expanded(flex: 3, child: _HeaderText('MATERIAL')),
          SizedBox(width: 12),
          SizedBox(width: 84, child: _HeaderText('FECHA')),
          SizedBox(width: 12),
          SizedBox(width: 110, child: _HeaderText('KG')),
          SizedBox(width: 12),
          Expanded(flex: 2, child: _HeaderText('NOTAS')),
          SizedBox(width: 8),
          SizedBox(width: 96, child: _HeaderText('ACCIONES')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Color(0xFF2A4B49),
      ),
    );
  }
}

enum _OpeningMenuAction { edit, delete }

Future<_OpeningMenuAction?> _showOpeningContextMenu(
  BuildContext context,
  Offset globalPosition,
) async {
  const menuTextStyle = TextStyle(
    fontWeight: FontWeight.w800,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
    color: Color(0xFF223D5A),
  );
  final media = MediaQuery.of(context).size;
  return showMenu<_OpeningMenuAction>(
    context: context,
    color: const Color(0xFFF3F8FD),
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      media.width - globalPosition.dx,
      media.height - globalPosition.dy,
    ),
    items: const [
      PopupMenuItem<_OpeningMenuAction>(
        value: _OpeningMenuAction.edit,
        child: Text('EDITAR', style: menuTextStyle),
      ),
      PopupMenuDivider(),
      PopupMenuItem<_OpeningMenuAction>(
        value: _OpeningMenuAction.delete,
        child: Text('ELIMINAR', style: menuTextStyle),
      ),
    ],
  );
}

class _OpeningActionsButton extends StatefulWidget {
  final ValueChanged<Offset> onOpen;

  const _OpeningActionsButton({required this.onOpen});

  @override
  State<_OpeningActionsButton> createState() => _OpeningActionsButtonState();
}

class _OpeningActionsButtonState extends State<_OpeningActionsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Acciones',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => widget.onOpen(details.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.62)
                  : Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.15 : 0.08),
                  blurRadius: _hovered ? 14 : 8,
                  offset: Offset(0, _hovered ? 7 : 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.more_horiz,
              size: 20,
              color: Color(0xFF223D5A),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideStockRow extends StatelessWidget {
  final _StockBalanceRow row;
  final bool showFamily;

  const _WideStockRow({required this.row, required this.showFamily});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.code,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17324A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              row.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B2B2B),
              ),
            ),
          ),
          if (showFamily) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                row.family,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF486461),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              row.openingUnits > 0
                  ? '${row.openingKg.toStringAsFixed(2)} kg · ${row.openingUnits}'
                  : '${row.openingKg.toStringAsFixed(2)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF486461),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              row.movementUnits != 0
                  ? '${row.movementKg.toStringAsFixed(2)} kg · ${row.movementUnits}'
                  : '${row.movementKg.toStringAsFixed(2)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF486461),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 122,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8F2).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.onHandUnits > 0
                      ? '${row.onHandKg.toStringAsFixed(2)} kg · ${row.onHandUnits} pzas'
                      : '${row.onHandKg.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17324A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStockRow extends StatelessWidget {
  final _StockBalanceRow row;
  final bool showFamily;

  const _CompactStockRow({required this.row, required this.showFamily});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2B2B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8F2).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${row.onHandKg.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17324A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${row.code}${showFamily ? ' · ${row.family}' : ''}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17324A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _CompactMetricPill(
                label: 'Apertura',
                value: row.openingUnits > 0
                    ? '${row.openingKg.toStringAsFixed(2)} kg · ${row.openingUnits} pzas'
                    : '${row.openingKg.toStringAsFixed(2)} kg',
              ),
              _CompactMetricPill(
                label: 'Movimiento',
                value: row.movementUnits != 0
                    ? '${row.movementKg.toStringAsFixed(2)} kg · ${row.movementUnits} pzas'
                    : '${row.movementKg.toStringAsFixed(2)} kg',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WideOpeningRow extends StatelessWidget {
  final _OpeningBalanceV2Row row;
  final Future<void> Function(_OpeningBalanceV2Row row) onEdit;
  final Future<void> Function(_OpeningBalanceV2Row row) onDelete;

  const _WideOpeningRow({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _handleMenuAction(_OpeningMenuAction action) async {
    switch (action) {
      case _OpeningMenuAction.edit:
        await onEdit(row);
        return;
      case _OpeningMenuAction.delete:
        await onDelete(row);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        unawaited(
          _showOpeningContextMenu(context, details.globalPosition).then((
            selected,
          ) {
            if (selected != null) {
              unawaited(_handleMenuAction(selected));
            }
          }),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                row.inventoryLevel == 'GENERAL' ? 'General' : 'Patio',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF486461),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                row.materialCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17324A),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                row.materialName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B2B2B),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              child: Text(
                _fmtCompactUiDate(row.asOfDate),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF486461),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                row.unitCount != null && row.unitCount! > 0
                    ? '${row.weightKg.toStringAsFixed(2)} kg · ${row.unitCount} pzas'
                    : '${row.weightKg.toStringAsFixed(2)} kg',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF486461),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                row.notes.isEmpty ? 'Sin notas' : row.notes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF486461),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: Align(
                alignment: Alignment.centerRight,
                child: _OpeningActionsButton(
                  onOpen: (position) {
                    unawaited(
                      _showOpeningContextMenu(context, position).then((
                        selected,
                      ) {
                        if (selected != null) {
                          unawaited(_handleMenuAction(selected));
                        }
                      }),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOpeningRow extends StatelessWidget {
  final _OpeningBalanceV2Row row;
  final Future<void> Function(_OpeningBalanceV2Row row) onEdit;
  final Future<void> Function(_OpeningBalanceV2Row row) onDelete;

  const _CompactOpeningRow({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _handleMenuAction(_OpeningMenuAction action) async {
    switch (action) {
      case _OpeningMenuAction.edit:
        await onEdit(row);
        return;
      case _OpeningMenuAction.delete:
        await onDelete(row);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        unawaited(
          _showOpeningContextMenu(context, details.globalPosition).then((
            selected,
          ) {
            if (selected != null) {
              unawaited(_handleMenuAction(selected));
            }
          }),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.materialName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2B2B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: _OpeningActionsButton(
                    onOpen: (position) {
                      unawaited(
                        _showOpeningContextMenu(context, position).then((
                          selected,
                        ) {
                          if (selected != null) {
                            unawaited(_handleMenuAction(selected));
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${row.inventoryLevel == 'GENERAL' ? 'General' : 'Patio'} · ${row.materialCode} · ${_fmtCompactUiDate(row.asOfDate)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17324A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _CompactMetricPill(
                  label: 'Kg',
                  value: row.unitCount != null && row.unitCount! > 0
                      ? '${row.weightKg.toStringAsFixed(2)} kg · ${row.unitCount} pzas'
                      : '${row.weightKg.toStringAsFixed(2)} kg',
                ),
                _CompactMetricPill(
                  label: 'Notas',
                  value: row.notes.isEmpty ? 'Sin notas' : row.notes,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF486461),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B2B2B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtCompactUiDate(DateTime date) {
  final yy = (date.year % 100).toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$dd/$mm/$yy';
}

Future<DateTime?> _showInventoryLikeDatePickerDialog({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  DateTime tempDate = DateUtils.dateOnly(initialDate);

  DateTime clampDate(DateTime value) {
    if (value.isBefore(firstDate)) return firstDate;
    if (value.isAfter(lastDate)) return lastDate;
    return value;
  }

  void moveDateByDays(void Function(void Function()) setInnerState, int days) {
    setInnerState(() {
      tempDate = DateUtils.dateOnly(
        clampDate(tempDate.add(Duration(days: days))),
      );
    });
  }

  void deferredPop(BuildContext ctx, [DateTime? value]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(value);
    });
  }

  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setInnerState) {
          return FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowLeft) {
                  moveDateByDays(setInnerState, -1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowRight) {
                  moveDateByDays(setInnerState, 1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  moveDateByDays(setInnerState, -7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  moveDateByDays(setInnerState, 7);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  deferredPop(dialogContext, DateUtils.dateOnly(tempDate));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Theme(
                data: Theme.of(innerContext).copyWith(
                  colorScheme: Theme.of(innerContext).colorScheme.copyWith(
                    primary: const Color(0xFF6A99C7),
                    onPrimary: Colors.white,
                    surface: const Color(0xFFEAF2F9),
                  ),
                ),
                child: AlertDialog(
                  backgroundColor: const Color(
                    0xFFEAF2F9,
                  ).withValues(alpha: 0.98),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFF8AA9C2).withValues(alpha: 0.42),
                    ),
                  ),
                  title: const Text('Selecciona fecha'),
                  content: SizedBox(
                    width: 320,
                    child: CalendarDatePicker(
                      key: ValueKey<DateTime>(tempDate),
                      initialDate: tempDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (d) {
                        setInnerState(() {
                          tempDate = DateUtils.dateOnly(d);
                        });
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2D5478),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6A99C7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(DateUtils.dateOnly(tempDate)),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _StockBalanceRow {
  final String code;
  final String name;
  final String family;
  final double openingKg;
  final double movementKg;
  final double onHandKg;
  final int openingUnits;
  final int movementUnits;
  final int onHandUnits;

  const _StockBalanceRow({
    required this.code,
    required this.name,
    required this.family,
    required this.openingKg,
    required this.movementKg,
    required this.onHandKg,
    required this.openingUnits,
    required this.movementUnits,
    required this.onHandUnits,
  });
}

class _OpeningBalanceV2Row {
  final String id;
  final String inventoryLevel;
  final String materialId;
  final String materialCode;
  final String materialName;
  final double weightKg;
  final int? unitCount;
  final String notes;
  final DateTime asOfDate;

  const _OpeningBalanceV2Row({
    required this.id,
    required this.inventoryLevel,
    required this.materialId,
    required this.materialCode,
    required this.materialName,
    required this.weightKg,
    required this.unitCount,
    required this.notes,
    required this.asOfDate,
  });
}

class _MaterialOptionV2 {
  final String id;
  final String code;
  final String name;

  const _MaterialOptionV2({
    required this.id,
    required this.code,
    required this.name,
  });
}

class _OpeningDialogResult {
  final String inventoryLevel;
  final String materialId;
  final double weightKg;
  final int? unitCount;
  final String notes;
  final DateTime asOfDate;

  const _OpeningDialogResult({
    required this.inventoryLevel,
    required this.materialId,
    required this.weightKg,
    required this.unitCount,
    required this.notes,
    required this.asOfDate,
  });
}
