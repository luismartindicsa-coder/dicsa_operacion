import 'package:flutter/material.dart';

import '../../../ui_contract_core/dialogs/contract_menu_surface.dart';
import '../../../ui_contract_core/theme/area_theme_scope.dart';
import '../../../ui_contract_core/theme/contract_tokens.dart';
import '../../auxiliary_surfaces/auxiliary_surfaces.dart';
import '../grid_editable.dart';

class GridEditableDemoPage extends StatefulWidget {
  const GridEditableDemoPage({super.key});

  @override
  State<GridEditableDemoPage> createState() => _GridEditableDemoPageState();
}

class _GridEditableDemoPageState extends State<GridEditableDemoPage> {
  static const _rowIds = ['row-0', 'row-1', 'row-2', 'row-3'];
  final TextEditingController _kgController = TextEditingController(text: '0');
  final FocusNode _kgFocusNode = FocusNode();
  final FocusNode _dateFocusNode = FocusNode();
  final FocusNode _materialFocusNode = FocusNode();
  final GridNavigationController _navigationController =
      GridNavigationController();
  final GridSelectionController _selectionController =
      GridSelectionController();
  final DragSelectionController _dragSelectionController =
      DragSelectionController();
  final ScrollController _listScrollController = ScrollController();
  final GridScrollVisibilityCoordinator _scrollVisibilityCoordinator =
      GridScrollVisibilityCoordinator();
  final GlobalKey _overlayKey = GlobalKey();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  DateTime? _draftDate = DateTime.now();
  String? _draftMaterial;
  DateTimeRange? _range;

  @override
  void dispose() {
    _kgController.dispose();
    _kgFocusNode.dispose();
    _dateFocusNode.dispose();
    _materialFocusNode.dispose();
    _navigationController.dispose();
    _selectionController.dispose();
    _dragSelectionController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  List<MarqueeRowHit> _resolveMarqueeRows() {
    final overlayContext = _overlayKey.currentContext;
    final overlayBox = overlayContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return const [];

    return [
      for (var index = 0; index < _rowIds.length; index++)
        if (_rowKeys[_rowIds[index]]?.currentContext case final context?)
          (() {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.attached) return null;
            final origin = overlayBox.globalToLocal(
              box.localToGlobal(Offset.zero),
            );
            return MarqueeRowHit(
              id: _rowIds[index],
              rowIndex: index,
              rect: origin & box.size,
            );
          })(),
    ].whereType<MarqueeRowHit>().toList();
  }

  @override
  Widget build(BuildContext context) {
    _navigationController.configure(
      insertColumnCount: 3,
      gridColumnCount: 3,
      rowCount: 4,
    );

    return AreaThemeScope(
      tokens: ContractAreaTokens.fallback(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridKeyboardShell(
              navigationController: _navigationController,
              onNavigated: (position) {
                _scrollVisibilityCoordinator.ensureVisible(position);
              },
              onOpenActiveCell: () {
                if (_navigationController.active.zone !=
                    GridNavigationZone.insertRow) {
                  return;
                }
                switch (_navigationController.active.columnIndex) {
                  case 0:
                    _dateFocusNode.requestFocus();
                    break;
                  case 1:
                    _materialFocusNode.requestFocus();
                    break;
                  case 2:
                    _kgFocusNode.requestFocus();
                    break;
                }
              },
              child: GridEditableShell(
                topBar: DateRangeFilterBar(
                  value: _range,
                  onPickRange: (context) => showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                    initialDateRange: _range,
                  ),
                  onChanged: (value) => setState(() => _range = value),
                ),
                insertRow: Row(
                  children: [
                    Expanded(
                      child: InsertRowDateField(
                        value: _draftDate,
                        focusNode: _dateFocusNode,
                        onOpenPicker: (context) =>
                            showContractDatePickerSurface(
                              context,
                              initialDate: _draftDate ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            ),
                        onChanged: (value) =>
                            setState(() => _draftDate = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InsertRowPickerCell<String>(
                        label: _draftMaterial,
                        focusNode: _materialFocusNode,
                        onOpenPicker: (context) => showSearchablePickerDialog(
                          context,
                          title: 'Material',
                          options: const [
                            SearchablePickerOption(
                              value: 'Paca nacional',
                              label: 'Paca nacional',
                            ),
                            SearchablePickerOption(
                              value: 'Granel nacional',
                              label: 'Granel nacional',
                            ),
                          ],
                        ),
                        onChanged: (value) =>
                            setState(() => _draftMaterial = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InsertRowNumberField(
                        controller: _kgController,
                        focusNode: _kgFocusNode,
                        hintText: 'Kg',
                      ),
                    ),
                  ],
                ),
                body: MarqueeSelectionOverlay(
                  key: _overlayKey,
                  controller: _dragSelectionController,
                  scrollController: _listScrollController,
                  resolveRows: _resolveMarqueeRows,
                  onSelectionChanged: (hits) {
                    if (hits.isEmpty) return;
                    _selectionController.selectRange(
                      hits.map((hit) => hit.id),
                      anchorRowIndex: hits.first.rowIndex,
                    );
                    _scrollVisibilityCoordinator.ensureGridRowVisible(
                      hits.last.rowIndex,
                    );
                  },
                  child: ListView.separated(
                    controller: _listScrollController,
                    itemCount: _rowIds.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rowId = _rowIds[index];
                      final scrollKey = _scrollVisibilityCoordinator.keyForCell(
                        zone: GridNavigationZone.grid,
                        rowIndex: index,
                        columnIndex: 0,
                      );
                      final rowKey = _rowKeys.putIfAbsent(rowId, GlobalKey.new);
                      return KeyedSubtree(
                        key: rowKey,
                        child: EditableGridRowShell(
                          key: scrollKey,
                          selected: _selectionController.isSelected(rowId),
                          hovering: index == 2,
                          active:
                              _navigationController.active.zone ==
                                  GridNavigationZone.grid &&
                              _navigationController.active.rowIndex == index,
                          onTap: () {
                            _selectionController.handlePointerSelection(
                              id: rowId,
                              rowIndex: index,
                              resolveRangeIds: (start, end) =>
                                  _rowIds.getRange(start, end + 1),
                              visibilityCoordinator:
                                  _scrollVisibilityCoordinator,
                            );
                            _navigationController.focusGridCell(
                              rowIndex: index,
                              columnIndex: 0,
                            );
                          },
                          child: ListTile(
                            title: Text('Fila demo ${index + 1}'),
                            subtitle: const Text('Base reusable Grid Editable'),
                            trailing: EditableRowActionsButton<String>(
                              entries: const [
                                ContractMenuEntry(
                                  value: 'edit',
                                  label: 'Editar',
                                  icon: Icons.edit_rounded,
                                ),
                                ContractMenuEntry(
                                  value: 'delete',
                                  label: 'Eliminar',
                                  icon: Icons.delete_outline_rounded,
                                ),
                              ],
                              onSelected: (_) {},
                            ),
                          ),
                        ),
                      );
                    },
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
