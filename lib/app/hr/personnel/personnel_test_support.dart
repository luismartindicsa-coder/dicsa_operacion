part of '../human_resources_personnel_page.dart';

@visibleForTesting
Future<void> hrEmploymentStatusForTesting({required bool terminated}) async {
  final row = (await _HrPersonnelStore.loadEmployees()).single;
  if (terminated) {
    await _HrPersonnelStore.terminateEmployee(row);
  } else {
    await _HrPersonnelStore.reactivateEmployee(row);
  }
}

/// Opens the real expediente dialog and returns the same payroll payload that
/// its repository persists. No Supabase calls or file uploads are performed.
@visibleForTesting
Future<Map<String, dynamic>?> hrPersonnelCompensationEditorForTesting(
  BuildContext context, {
  required Map<String, dynamic> employee,
  Future<bool> Function(Map<String, dynamic>)? persist,
}) async {
  final pay = HrEmployeeCompensation.fromRow(employee);
  final row = await showDialog<_HumanResourcesEmployeeRow>(
    context: context,
    builder: (_) => _HumanResourcesEmployeeDialog.edit(
      employee: _HumanResourcesEmployeeRow(
        id: 'test',
        nombre: 'COLABORADOR DE PRUEBA',
        empresa: 'DICSA CELAYA',
        horario: '08:00 - 18:00',
        diasLabora: const ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'],
        nss: '',
        rfc: '',
        curp: '',
        fechaIngreso: '2020-01-01',
        telefono: '',
        numeroCuenta: '',
        calzado: '',
        salario: pay.base.toStringAsFixed(2),
        salarioFlujo: pay.flow.toStringAsFixed(2),
        fiscalPaymentMode: pay.fiscalByCheck ? 'cheque' : 'deposito',
        overtimeHourlyRate: pay.overtimeHourlyRate,
      ),
      reservedIds: const {},
      onSave: persist == null
          ? null
          : (row) async => await persist(row.compensation.toRow()) ? row : null,
    ),
  );
  return row?.compensation.toRow();
}

/// Exercises the production repository using the test's injected Supabase client.
@visibleForTesting
Future<void> hrPreservingSaveForTesting({
  Future<void> Function()? afterLoad,
  bool removeDocuments = false,
  String? puesto,
}) async {
  final original = (await _HrPersonnelStore.loadEmployees()).single;
  await afterLoad?.call();
  final edited = original.copyWith(
    nombre: 'PERSONA DE PRUEBA EDITADA',
    puesto: puesto,
    requiredAttachments: removeDocuments ? [] : null,
    additionalAttachments: removeDocuments ? [] : null,
  );
  await _HrPersonnelStore.upsertEmployee(edited, original: original);
}

@visibleForTesting
Future<Map<String, dynamic>?> hrPersonnelPositionEditorForTesting(
  BuildContext context, {
  String puesto = '',
  bool create = false,
  required Future<List<String>> Function() loadPositions,
  required Future<String> Function(String) createPosition,
  Future<bool> Function(Map<String, dynamic>)? persist,
}) async {
  Future<_HumanResourcesEmployeeRow?> save(
    _HumanResourcesEmployeeRow row,
  ) async =>
      persist == null || await persist(_hrProfilePayload(row)) ? row : null;
  final row = await showDialog<_HumanResourcesEmployeeRow>(
    context: context,
    builder: (_) => AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: create
          ? _HumanResourcesEmployeeDialog.create(
              nextId: 'test-new',
              reservedIds: const {},
              onSave: save,
              loadJobPositions: loadPositions,
              createJobPosition: createPosition,
            )
          : _HumanResourcesEmployeeDialog.edit(
              employee: _HumanResourcesEmployeeRow.seed.first.copyWith(
                nombre: 'COLABORADOR DE PRUEBA',
                puesto: puesto,
                salario: '2000',
                salarioFlujo: '0',
              ),
              reservedIds: const {},
              onSave: save,
              loadJobPositions: loadPositions,
              createJobPosition: createPosition,
            ),
    ),
  );
  return row == null ? null : _hrProfilePayload(row);
}

@visibleForTesting
Widget hrPersonnelPositionGridForTesting({
  required double width,
  String puesto = 'OPERADOR DE UNIDAD',
}) {
  final row = _HumanResourcesEmployeeRow.seed.first.copyWith(puesto: puesto);
  return AreaThemeScope(
    tokens: humanResourcesAreaTokens,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HumanResourcesGridHeaderRow(
            hasActiveFilter: (_) => false,
            onOpenFilter: (_, _) async {},
          ),
          _HumanResourcesGridDataRow(
            row: row,
            rowIndex: 0,
            hovered: false,
            selected: false,
            activePosition: const GridCellPosition(
              zone: GridNavigationZone.grid,
              rowIndex: 0,
              columnIndex: 0,
            ),
            visibilityCoordinator: GridScrollVisibilityCoordinator(),
            onHoverChanged: (_) {},
            onTap: () {},
            onDoubleTap: () {},
            onSecondaryTapDown: (_) {},
            onPrepareActionsMenu: () {},
            onActionSelected: (_) {},
          ),
        ],
      ),
    ),
  );
}
