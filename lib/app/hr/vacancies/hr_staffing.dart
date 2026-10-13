import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../personnel/hr_companies.dart';
import '../personnel/hr_job_positions.dart';

/// Local saves invalidate counts immediately; other devices are checked on
/// resume, on opening alerts, and periodically by the mounted surfaces.
class HrStaffingChangeSignal extends ChangeNotifier {
  void changed() => notifyListeners();
}

final hrStaffingChanges = HrStaffingChangeSignal();

class HrStaffingTarget {
  final Map<String, dynamic> row;
  HrStaffingTarget(Map<String, dynamic> row) : row = Map.unmodifiable(row);
  String get id => row['id'] as String;
  String get company => row['company'] as String;
  String get position => row['position'] as String;
  int get requiredCount => (row['required_count'] as num).toInt();
  int get filled => (row['filled_count'] as num? ?? 0).toInt();
  int get vacant => (requiredCount - filled).clamp(0, requiredCount);
  int get revision => (row['revision'] as num? ?? 0).toInt();
  String get status => requiredCount == 0
      ? 'Sin requerimiento'
      : vacant > 0
      ? 'Por cubrir'
      : 'Completa';
}

class HrStaffingSnapshot {
  final List<HrStaffingTarget> targets;
  final List<String> companies;
  final int unassignedCount;
  HrStaffingSnapshot({
    required this.targets,
    required this.companies,
    this.unassignedCount = 0,
  });
  factory HrStaffingSnapshot.fromJson(Map<String, dynamic> data) =>
      HrStaffingSnapshot(
        targets: [
          for (final row in data['targets'] as List)
            HrStaffingTarget(Map<String, dynamic>.from(row as Map)),
        ],
        companies: hrJobPositionOptions([
          ...hrCompanyOptions,
          ...(data['companies'] as List).cast<String>(),
        ]),
        unassignedCount: (data['unassigned_count'] as num? ?? 0).toInt(),
      );
  List<HrStaffingTarget> get pending =>
      targets.where((t) => t.vacant > 0).toList();
  int get vacancyCount => targets.fold(0, (sum, t) => sum + t.vacant);
}

class HrStaffingSave {
  final String id, requestId, company, position;
  final int revision, requiredCount;
  bool confirmationPending = false;
  HrStaffingSave({
    String? id,
    String? requestId,
    required this.company,
    required this.position,
    required this.requiredCount,
    this.revision = 0,
  }) : id = id ?? const Uuid().v4(),
       requestId = requestId ?? const Uuid().v4();
  Map<String, dynamic> get params => {
    'p_id': id,
    'p_request_id': requestId,
    'p_expected_revision': revision,
    'p_company': company,
    'p_position': position,
    'p_required_count': requiredCount,
  };
}

class HrStaffingRepository {
  final SupabaseClient client;
  HrStaffingRepository(this.client);
  Future<HrStaffingSnapshot> load() async => HrStaffingSnapshot.fromJson(
    Map<String, dynamic>.from(
      await client
              .rpc('hr_staffing_snapshot')
              .timeout(const Duration(seconds: 30))
          as Map,
    ),
  );
  Future<void> save(List<HrStaffingSave> operations) async {
    for (final op in operations) {
      op.confirmationPending = true;
    }
    try {
      await client
          .rpc(
            'hr_staffing_save_batch',
            params: {
              'p_operations': operations.map((op) => op.params).toList(),
            },
          )
          .timeout(const Duration(seconds: 30));
      for (final op in operations) {
        op.confirmationPending = false;
      }
      hrStaffingChanges.changed();
    } on PostgrestException catch (e) {
      // SQL rejections are definitive. A transport failure may follow a commit;
      // keep the same request frozen for a safe retry in that case.
      if (['22023', '23505', '40001', '42501'].contains(e.code)) {
        for (final op in operations) {
          op.confirmationPending = false;
        }
      }
      rethrow;
    }
  }
}

String hrStaffingError(Object e) => e is PostgrestException
    ? e.message
    : 'No se pudo confirmar la operación. Revisa la conexión y vuelve a intentar.';
