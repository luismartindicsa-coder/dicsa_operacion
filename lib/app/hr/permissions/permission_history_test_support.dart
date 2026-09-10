part of '../human_resources_permissions_page.dart';

@visibleForTesting
Map<String, dynamic> hrPermissionHistoryForTesting(Map<String, dynamic> row) {
  final record = _HrPermissionEventRecord.fromRow(row);
  final draft = record.toDraft();
  _normalizePermissionEventDraft(draft);
  return {
    ...record.toRow(),
    'quantity_hours': draft.quantityHours,
    'quantity_days': draft.quantityDays,
  };
}

@visibleForTesting
Widget hrPermissionHistoryCardForTesting({
  required Map<String, dynamic> row,
  required ValueChanged<double> onChanged,
}) {
  final draft = _HrPermissionEventRecord.fromRow(row).toDraft();
  return StatefulBuilder(
    builder: (context, setState) => SingleChildScrollView(
      child: _HrPermissionEventCard(
        draft: draft,
        onRemove: () {},
        onChanged: () {
          _normalizePermissionEventDraft(draft);
          onChanged(draft.quantityHours);
          setState(() {});
        },
      ),
    ),
  );
}
