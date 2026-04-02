import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/inventory_page.dart';
import '../services/services_page.dart';
import '../services/services_shell.dart';
import '../services/warehouse_page.dart';
import '../services/weighings_page.dart';
import '../shared/app_error_reporter.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/page_routes.dart';

const List<String> _kStatusFlow = [
  'aviso_falla',
  'revision_area',
  'reporte_mantenimiento',
  'cotizacion',
  'autorizacion_finanzas',
  'material_recolectado',
  'programado',
  'mantenimiento_realizado',
  'supervision',
  'cerrado',
];

const Map<String, String> _kStatusLabel = {
  'aviso_falla': 'Aviso falla',
  'revision_area': 'Revision area',
  'reporte_mantenimiento': 'Reporte mantenimiento',
  'cotizacion': 'Cotizacion',
  'autorizacion_finanzas': 'Autorizacion finanzas',
  'material_recolectado': 'Material recolectado',
  'programado': 'Programado',
  'mantenimiento_realizado': 'Mantenimiento realizado',
  'supervision': 'Supervision',
  'cerrado': 'Cerrado',
  'rechazado': 'Rechazado',
};

const Map<String, String> _kPriorityLabel = {
  'alta': 'Alta',
  'media': 'Media',
  'baja': 'Baja',
};

const Map<String, String> _kTypeLabel = {
  'preventivo': 'Preventivo',
  'correctivo': 'Correctivo',
  'mejora': 'Mejora',
};

const Map<String, String> _kCategoryLabel = {
  'mecanica': 'Mecanica',
  'electrica': 'Electrica',
  'hidraulica': 'Hidraulica',
  'neumatica': 'Neumatica',
  'electronica': 'Electronica',
  'otros': 'Otros',
};

const Map<String, String> _kImpactLabel = {
  'paro_total': 'Paro total',
  'paro_parcial': 'Paro parcial',
  'sin_impacto': 'Sin impacto',
};

const Map<String, String> _kEvidenceCategoryLabel = {
  'antes': 'Antes',
  'durante': 'Durante',
  'despues': 'Despues',
  'facturas': 'Facturas',
  'otros': 'Otros',
};

const Map<String, String> _kApprovalStepLabel = {
  'operador': 'Operador',
  'jefe_area': 'Jefe de area',
  'interviniente': 'Interviniente',
  'direccion': 'Direccion',
  'jefe_operativo': 'Jefe operativo',
  'finanzas': 'Finanzas',
  'area': 'Area',
  'mantenimiento': 'Mantenimiento',
  'verificacion': 'Verificacion',
};

const Map<String, String> _kMaterialSourceLabel = {
  'almacen': 'Almacen',
  'compra': 'Compra',
  'proveedor': 'Proveedor',
  'mano_obra': 'Mano de obra',
  'servicio_tecnico': 'Servicio tecnico',
};

const Map<String, List<String>> _kNextStatuses = {
  'aviso_falla': ['revision_area', 'rechazado'],
  'revision_area': ['reporte_mantenimiento', 'rechazado'],
  'reporte_mantenimiento': ['cotizacion', 'rechazado'],
  'cotizacion': ['autorizacion_finanzas', 'rechazado'],
  'autorizacion_finanzas': ['material_recolectado', 'rechazado'],
  'material_recolectado': ['programado', 'rechazado'],
  'programado': ['mantenimiento_realizado', 'rechazado'],
  'mantenimiento_realizado': ['supervision', 'rechazado'],
  'supervision': ['cerrado', 'rechazado'],
  'rechazado': ['revision_area', 'reporte_mantenimiento', 'cotizacion'],
};

class _MaintenanceFilterDialogResult {
  final Set<String> selectedValues;
  const _MaintenanceFilterDialogResult({required this.selectedValues});
}

const Map<String, List<String>> _kTransitionRoles = {
  'aviso_falla->revision_area': [
    'jefe_area',
    'control_transporte',
    'encargado_fabricas',
    'ops_manager',
  ],
  'revision_area->reporte_mantenimiento': ['jefe_operativo', 'ops_manager'],
  'reporte_mantenimiento->cotizacion': ['auxiliar_direccion'],
  'cotizacion->autorizacion_finanzas': ['finanzas'],
  'autorizacion_finanzas->material_recolectado': ['mensajeria'],
  'material_recolectado->programado': ['auxiliar_direccion'],
  'programado->mantenimiento_realizado': ['tecnico', 'mecanico', 'services'],
  'mantenimiento_realizado->supervision': ['jefe_area', 'control_transporte'],
  'supervision->cerrado': ['jefe_operativo', 'ops_manager'],
};

const List<String> _kFixedAreas = [
  'CARTON',
  'CHATARRA',
  'FABRICAS',
  'FLOTILLA',
];

String _normEnum(dynamic value) =>
    (value ?? '').toString().toLowerCase().trim();

class _MaintenanceDateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;
  const _MaintenanceDateFilterDialogResult({this.range, this.clear = false});
}

enum _MaintenanceWorkspace { orders, reports }

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;
  Timer? _autoRefreshTimer;
  Timer? _deferredAutoRefreshTimer;
  RealtimeChannel? _maintenanceRealtimeChannel;
  final FocusNode _ordersListFocusNode = FocusNode(
    debugLabel: 'maintenance-orders-list',
  );

  bool _loading = true;
  bool _saving = false;
  bool _creating = false;
  bool _exportingPdf = false;
  bool _exportingReportPdf = false;
  bool _exportingReportCsv = false;
  bool _autoReloading = false;
  bool _pendingAutoReload = false;
  bool _suspendAutosave = false;
  bool _autosavePending = false;
  DateTime? _lastBackgroundRefreshAt;
  Timer? _autosaveTimer;
  String? _lastSavedFingerprint;
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 12);
  static const Duration _backgroundRefreshRetryDelay = Duration(seconds: 8);
  static const Duration _autosaveDelay = Duration(seconds: 2);

  List<Map<String, dynamic>> _orders = const [];
  final Map<String, int> _evidenceCountByOt = <String, int>{};
  final Map<String, int> _pendingApprovalsByOt = <String, int>{};

  String _search = '';
  String? _statusFilter;
  String _profileRole = 'viewer';
  String _profileName = '';
  String? _hoveredOrderId;
  _MaintenanceWorkspace _workspace = _MaintenanceWorkspace.orders;

  String? _selectedOrderId;
  Map<String, dynamic>? _selectedOrder;
  List<Map<String, dynamic>> _vehicleCatalog = const [];
  String? _selectedVehicleId;

  final TextEditingController _areaC = TextEditingController();
  final TextEditingController _equipmentC = TextEditingController();
  final TextEditingController _serialC = TextEditingController();
  final TextEditingController _requesterC = TextEditingController();
  final TextEditingController _mechanicNameC = TextEditingController();
  final TextEditingController _mechanicContactC = TextEditingController();
  final TextEditingController _descriptionC = TextEditingController();
  final TextEditingController _diagnosisC = TextEditingController();
  final TextEditingController _summaryC = TextEditingController();
  final TextEditingController _assignedToC = TextEditingController();
  final ScrollController _detailScrollController = ScrollController();
  final ScrollController _reportsScrollController = ScrollController();

  String _priority = 'media';
  String _type = 'correctivo';
  String _category = 'otros';
  String _impact = 'sin_impacto';

  List<Map<String, dynamic>> _tasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _materials = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _timeLogs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _evidences = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _approvals = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _reportTimeLogs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _reportTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _reportMaterials = <Map<String, dynamic>>[];

  Set<String> _reportMechanicFilters = <String>{};
  Set<String> _reportEquipmentFilters = <String>{};
  Set<String> _reportAreaFilters = <String>{};
  Set<String> _reportStatusFilters = <String>{};
  Set<String> _reportTypeFilters = <String>{};
  DateTimeRange? _reportDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachAutosaveListeners();
    unawaited(_bootstrap());
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _deferredAutoRefreshTimer?.cancel();
    _autosaveTimer?.cancel();
    _maintenanceRealtimeChannel?.unsubscribe();
    _ordersListFocusNode.dispose();
    _detailScrollController.dispose();
    _reportsScrollController.dispose();
    _detachAutosaveListeners();
    _areaC.dispose();
    _equipmentC.dispose();
    _serialC.dispose();
    _requesterC.dispose();
    _mechanicNameC.dispose();
    _mechanicContactC.dispose();
    _descriptionC.dispose();
    _diagnosisC.dispose();
    _summaryC.dispose();
    _assignedToC.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestAutoReload(force: true);
    }
  }

  Future<void> _bootstrap() async {
    await _loadProfile();
    await _loadVehicleCatalog();
    await _loadOrders();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _requestAutoReload(),
    );

    _maintenanceRealtimeChannel?.unsubscribe();
    _maintenanceRealtimeChannel = _supa
        .channel('maintenance-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_orders',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_tasks',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_materials',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_time_logs',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_evidence',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_approvals',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_status_log',
          callback: (_) => _requestAutoReload(),
        )
        .subscribe();
  }

  bool get _shouldDeferBackgroundRefresh =>
      _loading || _saving || _creating || _exportingPdf || _isEditableFocused();

  void _queueDeferredAutoReload([Duration? delay]) {
    if (!mounted) return;
    _pendingAutoReload = true;
    _deferredAutoRefreshTimer?.cancel();
    _deferredAutoRefreshTimer = Timer(
      delay ?? _backgroundRefreshRetryDelay,
      () {
        _deferredAutoRefreshTimer = null;
        _requestAutoReload();
      },
    );
  }

  void _requestAutoReload({bool force = false}) {
    if (!mounted) return;
    if (!force && (_autoReloading || _shouldDeferBackgroundRefresh)) {
      _queueDeferredAutoReload();
      return;
    }
    if (!force && _lastBackgroundRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundRefreshAt!);
      if (elapsed < _backgroundRefreshMinGap) {
        _queueDeferredAutoReload(_backgroundRefreshMinGap - elapsed);
        return;
      }
    }
    if (_autoReloading) {
      _queueDeferredAutoReload();
      return;
    }
    unawaited(_refreshSilentlyIfIdle(force: force));
  }

  Future<void> _refreshSilentlyIfIdle({bool force = false}) async {
    if (!mounted || _autoReloading) return;
    _autoReloading = true;
    try {
      await _loadOrders(refreshSelectedDetails: _selectedOrderId != null);
      _lastBackgroundRefreshAt = DateTime.now();
    } finally {
      _autoReloading = false;
      if (_pendingAutoReload && mounted) {
        if (force || !_shouldDeferBackgroundRefresh) {
          _pendingAutoReload = false;
          _requestAutoReload();
        } else {
          _queueDeferredAutoReload();
        }
      }
    }
  }

  Future<void> _loadVehicleCatalog() async {
    try {
      final rows = await _supa
          .from('vehicles')
          .select('id,code,serial_number,status')
          .eq('status', 'activo')
          .order('code');
      _vehicleCatalog = (rows as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar el catalogo de vehiculos.',
      );
      _vehicleCatalog = const [];
    }
  }

  Future<void> _loadProfile() async {
    final user = _supa.auth.currentUser;
    if (user == null) return;
    _profileName = (user.email ?? '').trim();

    try {
      final row = await _supa
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      _profileRole = ((row?['role'] as String?) ?? 'viewer')
          .toLowerCase()
          .trim();
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar el perfil de mantenimiento.',
      );
      _profileRole = 'viewer';
    }
  }

  Future<void> _loadOrders({bool refreshSelectedDetails = true}) async {
    try {
      final rows = await _supa
          .from('maintenance_orders')
          .select(
            'id,ot_folio,status,priority,type,category,impact,requested_at,area_label,equipment_label,assigned_to_name,updated_at,mechanic_name,mechanic_contact,requester_name,cost_estimated_total,cost_actual_total',
          )
          .order('requested_at', ascending: false)
          .limit(400);

      final list = (rows as List).cast<Map<String, dynamic>>().map((row) {
        final mapped = Map<String, dynamic>.from(row);
        mapped['status'] = _normEnum(mapped['status']);
        mapped['priority'] = _normEnum(mapped['priority']);
        mapped['type'] = _normEnum(mapped['type']);
        return mapped;
      }).toList();
      _orders = list;

      final ids = _orders
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      _evidenceCountByOt.clear();
      _pendingApprovalsByOt.clear();

      if (ids.isNotEmpty) {
        final evidenceRows = await _supa
            .from('maintenance_evidence')
            .select('ot_id')
            .inFilter('ot_id', ids);
        for (final row in (evidenceRows as List).cast<Map<String, dynamic>>()) {
          final otId = (row['ot_id'] ?? '').toString();
          if (otId.isEmpty) continue;
          _evidenceCountByOt[otId] = (_evidenceCountByOt[otId] ?? 0) + 1;
        }

        final approvalRows = await _supa
            .from('maintenance_approvals')
            .select('ot_id,status')
            .inFilter('ot_id', ids)
            .eq('status', 'pendiente');
        for (final row in (approvalRows as List).cast<Map<String, dynamic>>()) {
          final otId = (row['ot_id'] ?? '').toString();
          if (otId.isEmpty) continue;
          _pendingApprovalsByOt[otId] = (_pendingApprovalsByOt[otId] ?? 0) + 1;
        }

        final timeLogRows = await _supa
            .from('maintenance_time_logs')
            .select('ot_id,start_at,end_at,minutes,tech_name')
            .inFilter('ot_id', ids);
        _reportTimeLogs = (timeLogRows as List)
            .cast<Map<String, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

        final taskRows = await _supa
            .from('maintenance_tasks')
            .select('ot_id,is_done')
            .inFilter('ot_id', ids);
        _reportTasks = (taskRows as List)
            .cast<Map<String, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

        final materialRows = await _supa
            .from('maintenance_materials')
            .select('ot_id')
            .inFilter('ot_id', ids);
        _reportMaterials = (materialRows as List)
            .cast<Map<String, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      } else {
        _reportTimeLogs = <Map<String, dynamic>>[];
        _reportTasks = <Map<String, dynamic>>[];
        _reportMaterials = <Map<String, dynamic>>[];
      }

      if (_selectedOrderId != null) {
        final stillExists = _orders.any((e) => e['id'] == _selectedOrderId);
        if (!stillExists) {
          _selectedOrderId = null;
          _selectedOrder = null;
          _clearEditors();
        }
      }

      if (_selectedOrderId == null && _orders.isNotEmpty) {
        _selectedOrderId = _orders.first['id']?.toString();
      }

      _sanitizeReportFilters();

      if (refreshSelectedDetails && _selectedOrderId != null) {
        await _loadOrderDetails(_selectedOrderId!);
      }

      if (mounted) setState(() {});
    } catch (e) {
      _toast('No se pudieron cargar OT: $e');
    }
  }

  Future<void> _loadOrderDetails(String orderId) async {
    final row = await _supa
        .from('maintenance_orders')
        .select('*')
        .eq('id', orderId)
        .single();

    final tasks = await _supa
        .from('maintenance_tasks')
        .select('*')
        .eq('ot_id', orderId)
        .order('line_no');
    final materials = await _supa
        .from('maintenance_materials')
        .select('*')
        .eq('ot_id', orderId)
        .order('line_no');
    final timeLogs = await _supa
        .from('maintenance_time_logs')
        .select('*')
        .eq('ot_id', orderId)
        .order('start_at');
    final evidences = await _supa
        .from('maintenance_evidence')
        .select('*')
        .eq('ot_id', orderId)
        .order('uploaded_at', ascending: false);
    final approvals = await _supa
        .from('maintenance_approvals')
        .select('*')
        .eq('ot_id', orderId)
        .order('created_at');

    _selectedOrder = Map<String, dynamic>.from(row)
      ..['status'] = _normEnum(row['status'])
      ..['priority'] = _normEnum(row['priority'])
      ..['type'] = _normEnum(row['type'])
      ..['category'] = _normEnum(row['category'])
      ..['impact'] = _normEnum(row['impact'])
      ..['provider_type'] = _normEnum(row['provider_type']);
    _tasks = (tasks as List).map((e) => Map<String, dynamic>.from(e)).toList();
    _materials = (materials as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _timeLogs = (timeLogs as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _evidences = (evidences as List)
        .map(
          (e) => Map<String, dynamic>.from(e)
            ..['category'] = _normEnum((e as Map<String, dynamic>)['category']),
        )
        .toList();
    _approvals = (approvals as List)
        .map(
          (e) => Map<String, dynamic>.from(e)
            ..['status'] = _normEnum((e as Map<String, dynamic>)['status'])
            ..['step'] = _normEnum((e)['step']),
        )
        .toList();

    _syncEditorsFromOrder();
    _lastSavedFingerprint = _buildAutosaveFingerprint();
    _autosavePending = false;
    if (mounted) setState(() {});
  }

  void _syncEditorsFromOrder() {
    final order = _selectedOrder;
    if (order == null) {
      _clearEditors();
      return;
    }
    _runWithAutosaveSuspended(() {
      _areaC.text = (order['area_label'] ?? '').toString();
      _equipmentC.text = (order['equipment_label'] ?? '').toString();
      _serialC.text = (order['equipment_serial'] ?? '').toString();
      _requesterC.text = (order['requester_name'] ?? '').toString();
      _mechanicNameC.text = (order['mechanic_name'] ?? '').toString();
      _mechanicContactC.text = (order['mechanic_contact'] ?? '').toString();
      _descriptionC.text = (order['problem_description'] ?? '').toString();
      _diagnosisC.text = (order['diagnosis'] ?? '').toString();
      _summaryC.text = (order['work_summary'] ?? '').toString();
      _assignedToC.text = (order['assigned_to_name'] ?? '').toString();

      _priority = (order['priority'] ?? 'media').toString();
      _type = (order['type'] ?? 'correctivo').toString();
      _category = (order['category'] ?? 'otros').toString();
      _impact = (order['impact'] ?? 'sin_impacto').toString();

      _selectedVehicleId = (order['equipment_id'] ?? '').toString().trim();
      if (_selectedVehicleId!.isEmpty) {
        final equipment = _equipmentC.text.trim().toUpperCase();
        final match = _vehicleCatalog.cast<Map<String, dynamic>?>().firstWhere(
          (v) =>
              ((v?['code'] ?? '').toString().trim().toUpperCase()) == equipment,
          orElse: () => null,
        );
        _selectedVehicleId = match?['id']?.toString();
        if (_serialC.text.trim().isEmpty &&
            (match?['serial_number'] ?? '').toString().trim().isNotEmpty) {
          _serialC.text = (match?['serial_number'] ?? '').toString();
        }
      }
      if (!_kFixedAreas.contains(_areaC.text.trim().toUpperCase())) {
        _areaC.text = _kFixedAreas.first;
      }
    });
  }

  void _clearEditors() {
    _runWithAutosaveSuspended(() {
      _areaC.text = _kFixedAreas.first;
      _equipmentC.clear();
      _serialC.clear();
      _requesterC.clear();
      _mechanicNameC.clear();
      _mechanicContactC.clear();
      _descriptionC.clear();
      _diagnosisC.clear();
      _summaryC.clear();
      _assignedToC.clear();
      _priority = 'media';
      _type = 'correctivo';
      _category = 'otros';
      _impact = 'sin_impacto';
      _selectedVehicleId = null;
      _tasks = <Map<String, dynamic>>[];
      _materials = <Map<String, dynamic>>[];
      _timeLogs = <Map<String, dynamic>>[];
      _evidences = <Map<String, dynamic>>[];
      _approvals = <Map<String, dynamic>>[];
      _lastSavedFingerprint = null;
      _autosavePending = false;
    });
  }

  void _attachAutosaveListeners() {
    for (final controller in [
      _areaC,
      _equipmentC,
      _serialC,
      _requesterC,
      _mechanicNameC,
      _mechanicContactC,
      _descriptionC,
      _diagnosisC,
      _summaryC,
      _assignedToC,
    ]) {
      controller.addListener(_handleAutosaveEditorChanged);
    }
  }

  void _detachAutosaveListeners() {
    for (final controller in [
      _areaC,
      _equipmentC,
      _serialC,
      _requesterC,
      _mechanicNameC,
      _mechanicContactC,
      _descriptionC,
      _diagnosisC,
      _summaryC,
      _assignedToC,
    ]) {
      controller.removeListener(_handleAutosaveEditorChanged);
    }
  }

  void _handleAutosaveEditorChanged() {
    _scheduleAutosave();
  }

  void _runWithAutosaveSuspended(VoidCallback action) {
    final previous = _suspendAutosave;
    _suspendAutosave = true;
    try {
      action();
    } finally {
      _suspendAutosave = previous;
    }
  }

  String? _buildAutosaveFingerprint() {
    final orderId = _selectedOrder?['id']?.toString();
    if (orderId == null || orderId.isEmpty) return null;
    return jsonEncode({
      'order_id': orderId,
      'area_label': _areaC.text.trim(),
      'equipment_id': _selectedVehicleId,
      'equipment_label': _equipmentC.text.trim(),
      'equipment_serial': _serialC.text.trim(),
      'requester_name': _requesterC.text.trim(),
      'mechanic_name': _mechanicNameC.text.trim(),
      'mechanic_contact': _mechanicContactC.text.trim(),
      'priority': _priority,
      'type': _type,
      'category': _category,
      'impact': _impact,
      'problem_description': _descriptionC.text.trim(),
      'diagnosis': _diagnosisC.text.trim(),
      'work_summary': _summaryC.text.trim(),
      'assigned_to_name': _assignedToC.text.trim(),
      'tasks': _tasks,
      'materials': _materials,
      'time_logs': _timeLogs,
    });
  }

  void _scheduleAutosave({bool immediate = false}) {
    if (_suspendAutosave || !mounted) return;
    final fingerprint = _buildAutosaveFingerprint();
    if (fingerprint == null) return;
    if (!immediate && fingerprint == _lastSavedFingerprint) {
      _autosavePending = false;
      return;
    }
    _autosavePending = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      immediate ? Duration.zero : _autosaveDelay,
      () => unawaited(_flushAutosave()),
    );
  }

  Future<void> _flushAutosave() async {
    if (!mounted || _suspendAutosave || !_autosavePending) return;
    if (_saving || _loading || _creating) {
      _scheduleAutosave();
      return;
    }
    final fingerprint = _buildAutosaveFingerprint();
    if (fingerprint == null) {
      _autosavePending = false;
      return;
    }
    if (fingerprint == _lastSavedFingerprint) {
      _autosavePending = false;
      return;
    }
    await _saveCurrentOrder(showToast: false, refreshAfterSave: false);
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((order) {
      if (_statusFilter != null && _statusFilter != 'all') {
        if ((order['status'] ?? '').toString() != _statusFilter) return false;
      }

      final query = _search.trim().toLowerCase();
      if (query.isEmpty) return true;

      final haystack = [
        (order['ot_folio'] ?? '').toString(),
        (order['equipment_label'] ?? '').toString(),
        (order['area_label'] ?? '').toString(),
        (order['assigned_to_name'] ?? '').toString(),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  bool _isEditableFocused() {
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _selectOrderByIndex(List<Map<String, dynamic>> rows, int index) {
    if (rows.isEmpty || index < 0 || index >= rows.length) return;
    final id = (rows[index]['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (_selectedOrderId != id) {
      setState(() => _selectedOrderId = id);
    }
    _ordersListFocusNode.requestFocus();
    unawaited(_loadOrderDetails(id));
  }

  void _moveOrderSelection(int delta) {
    final rows = _filteredOrders;
    if (rows.isEmpty) return;
    var currentIndex = rows.indexWhere(
      (row) => (row['id'] ?? '').toString() == (_selectedOrderId ?? ''),
    );
    if (currentIndex < 0) currentIndex = 0;
    final next = (currentIndex + delta).clamp(0, rows.length - 1);
    _selectOrderByIndex(rows, next);
  }

  Future<void> _openOrderContextMenu(
    int rowIndex,
    TapDownDetails details,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    _selectOrderByIndex(rows, rowIndex);
    _ordersListFocusNode.requestFocus();

    final orderId = (rows[rowIndex]['id'] ?? '').toString();
    if (orderId.isEmpty) return;

    final action = await _showOrderContextMenu(details.globalPosition);
    if (action == null) return;
    await _runOrderAction(orderId, action);
  }

  Future<void> _openOrderActionsFromButton(
    String orderId,
    BuildContext buttonContext,
  ) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = Offset(
      topLeft.dx + box.size.width * 0.60,
      topLeft.dy + box.size.height,
    );
    final action = await _showOrderContextMenu(position);
    if (action == null) return;
    await _runOrderAction(orderId, action);
  }

  List<MapEntry<String, String>> _orderContextActions() {
    return const <MapEntry<String, String>>[
      MapEntry('save', 'GUARDAR'),
      MapEntry('status', 'EDITAR ESTADO'),
      MapEntry('pdf', 'DESCARGAR PDF'),
      MapEntry('evidence', 'EVIDENCIAS'),
      MapEntry('delete', 'ELIMINAR'),
    ];
  }

  Future<String?> _showOrderContextMenu(Offset globalPosition) {
    final actions = _orderContextActions();
    const menuTextStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF1C3E5D),
    );
    final mediaSize = MediaQuery.of(context).size;
    return showMenu<String>(
      context: context,
      color: const Color(0xE6EAF2F9),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        mediaSize.width - globalPosition.dx,
        mediaSize.height - globalPosition.dy,
      ),
      items: [
        for (var i = 0; i < actions.length; i++) ...[
          PopupMenuItem<String>(
            value: actions[i].key,
            child: Text(
              actions[i].value,
              style: actions[i].key == 'delete'
                  ? menuTextStyle.copyWith(color: const Color(0xFF8A1F1F))
                  : menuTextStyle,
            ),
          ),
          if (i != actions.length - 1) const PopupMenuDivider(height: 1),
        ],
      ],
    );
  }

  int _countStatus(String status) {
    return _orders
        .where((e) => (e['status'] ?? '').toString() == status)
        .length;
  }

  Future<void> _createOrder() async {
    if (_creating) return;
    final user = _supa.auth.currentUser;
    if (user == null) return;

    setState(() => _creating = true);
    try {
      final now = DateTime.now();
      final inserted = await _insertNewOrderWithConsecutiveFolio(user.id, now);

      final id = inserted['id']?.toString();
      await _loadOrders();
      if (id != null) {
        _selectedOrderId = id;
        await _loadOrderDetails(id);
      }
      _toast('OT creada');
    } catch (e) {
      _toast('No se pudo crear OT: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<Map<String, dynamic>> _insertNewOrderWithConsecutiveFolio(
    String userId,
    DateTime now,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final folio = await _nextConsecutiveOtFolio(now.year);
      try {
        final inserted = await _supa
            .from('maintenance_orders')
            .insert({
              'ot_folio': folio,
              'status': 'aviso_falla',
              'priority': 'media',
              'type': 'correctivo',
              'category': 'otros',
              'impact': 'sin_impacto',
              'requester_name': null,
              'requester_user_id': userId,
              'created_by': userId,
              'requested_at': now.toIso8601String(),
            })
            .select('id')
            .single();
        return Map<String, dynamic>.from(inserted);
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
    }
    throw Exception('No se pudo generar folio consecutivo, intenta de nuevo.');
  }

  Future<String> _nextConsecutiveOtFolio(int year) async {
    final rows = await _supa
        .from('maintenance_orders')
        .select('ot_folio')
        .order('created_at', ascending: false)
        .limit(600);
    final re = RegExp(r'^OT-(\d{4})-(\d+)$');
    var maxSeq = 0;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final folio = (row['ot_folio'] ?? '').toString().trim();
      final m = re.firstMatch(folio);
      if (m == null) continue;
      final folioYear = int.tryParse(m.group(1) ?? '');
      final seq = int.tryParse(m.group(2) ?? '');
      if (folioYear != year || seq == null) continue;
      if (seq > maxSeq) maxSeq = seq;
    }
    final next = (maxSeq + 1).toString().padLeft(6, '0');
    return 'OT-$year-$next';
  }

  Future<void> _saveCurrentOrder({
    bool showToast = true,
    bool refreshAfterSave = true,
  }) async {
    final order = _selectedOrder;
    if (order == null || _saving) return;
    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    final fingerprintBeforeSave = _buildAutosaveFingerprint();

    setState(() => _saving = true);
    try {
      final estTotal = _materials.fold<double>(
        0,
        (sum, row) => sum + (_toDouble(row['cost_estimated']) ?? 0),
      );
      final realTotal = _materials.fold<double>(
        0,
        (sum, row) => sum + (_toDouble(row['cost_actual']) ?? 0),
      );

      await _supa
          .from('maintenance_orders')
          .update({
            'area_label': _areaC.text.trim(),
            'equipment_id': _selectedVehicleId,
            'equipment_label': _equipmentC.text.trim(),
            'equipment_serial': _serialC.text.trim(),
            'requester_name': _requesterC.text.trim(),
            'mechanic_name': _mechanicNameC.text.trim().isEmpty
                ? null
                : _mechanicNameC.text.trim(),
            'mechanic_contact': _mechanicContactC.text.trim().isEmpty
                ? null
                : _mechanicContactC.text.trim(),
            'priority': _priority,
            'type': _type,
            'category': _category,
            'impact': _impact,
            'problem_description': _descriptionC.text.trim(),
            'diagnosis': _diagnosisC.text.trim().isEmpty
                ? null
                : _diagnosisC.text.trim(),
            'work_summary': _summaryC.text.trim().isEmpty
                ? null
                : _summaryC.text.trim(),
            'assigned_to_name': _assignedToC.text.trim().isEmpty
                ? null
                : _assignedToC.text.trim(),
            'assigned_at': _assignedToC.text.trim().isEmpty
                ? null
                : DateTime.now().toIso8601String(),
            'cost_estimated_total': estTotal,
            'cost_actual_total': realTotal,
          })
          .eq('id', orderId);

      await _replaceChildRows(orderId);
      _lastSavedFingerprint = fingerprintBeforeSave;
      _autosavePending = false;
      if (refreshAfterSave) {
        await _loadOrders();
        await _loadOrderDetails(orderId);
      } else if (mounted) {
        setState(() {
          _selectedOrder = {
            ...?_selectedOrder,
            'area_label': _areaC.text.trim(),
            'equipment_id': _selectedVehicleId,
            'equipment_label': _equipmentC.text.trim(),
            'equipment_serial': _serialC.text.trim(),
            'requester_name': _requesterC.text.trim(),
            'mechanic_name': _mechanicNameC.text.trim().isEmpty
                ? null
                : _mechanicNameC.text.trim(),
            'mechanic_contact': _mechanicContactC.text.trim().isEmpty
                ? null
                : _mechanicContactC.text.trim(),
            'priority': _priority,
            'type': _type,
            'category': _category,
            'impact': _impact,
            'problem_description': _descriptionC.text.trim(),
            'diagnosis': _diagnosisC.text.trim().isEmpty
                ? null
                : _diagnosisC.text.trim(),
            'work_summary': _summaryC.text.trim().isEmpty
                ? null
                : _summaryC.text.trim(),
            'assigned_to_name': _assignedToC.text.trim().isEmpty
                ? null
                : _assignedToC.text.trim(),
            'cost_estimated_total': estTotal,
            'cost_actual_total': realTotal,
          };
        });
      }
      if (showToast) _toast('OT guardada');
    } catch (e) {
      _toast('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
      final currentFingerprint = _buildAutosaveFingerprint();
      if (currentFingerprint != null &&
          currentFingerprint != _lastSavedFingerprint) {
        _scheduleAutosave();
      }
    }
  }

  Future<void> _replaceChildRows(String orderId) async {
    await _supa.from('maintenance_tasks').delete().eq('ot_id', orderId);
    await _supa.from('maintenance_materials').delete().eq('ot_id', orderId);
    await _supa.from('maintenance_time_logs').delete().eq('ot_id', orderId);

    final tasks = <Map<String, dynamic>>[];
    for (var i = 0; i < _tasks.length; i++) {
      final row = _tasks[i];
      final desc = (row['description'] ?? '').toString().trim();
      if (desc.isEmpty) continue;
      tasks.add({
        'ot_id': orderId,
        'line_no': i + 1,
        'description': desc,
        'unit': _emptyAsNull(row['unit']),
        'qty': _toDouble(row['qty']),
        'is_done': row['is_done'] == true,
        'notes': _emptyAsNull(row['notes']),
        'done_at': row['is_done'] == true
            ? DateTime.now().toIso8601String()
            : null,
      });
    }

    final materials = <Map<String, dynamic>>[];
    for (var i = 0; i < _materials.length; i++) {
      final row = _materials[i];
      final name = (row['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      materials.add({
        'ot_id': orderId,
        'line_no': i + 1,
        'name': name,
        'qty': _toDouble(row['qty']),
        'source': (row['source'] ?? 'almacen').toString(),
        'cost_estimated': _toDouble(row['cost_estimated']),
        'cost_actual': _toDouble(row['cost_actual']),
        'notes': _emptyAsNull(row['notes']),
      });
    }

    final timeLogs = <Map<String, dynamic>>[];
    for (final row in _timeLogs) {
      final startAt = row['start_at']?.toString();
      if (startAt == null || startAt.isEmpty) continue;
      final endAt = row['end_at']?.toString();
      final start = DateTime.tryParse(startAt);
      final end = endAt == null ? null : DateTime.tryParse(endAt);
      final minutes = (start != null && end != null)
          ? end.difference(start).inMinutes.clamp(0, 100000)
          : null;

      timeLogs.add({
        'ot_id': orderId,
        'tech_name': _emptyAsNull(row['tech_name']),
        'start_at': startAt,
        'end_at': endAt,
        'minutes': minutes,
        'note': _emptyAsNull(row['note']),
      });
    }

    if (tasks.isNotEmpty) {
      await _supa.from('maintenance_tasks').insert(tasks);
    }
    if (materials.isNotEmpty) {
      await _supa.from('maintenance_materials').insert(materials);
    }
    if (timeLogs.isNotEmpty) {
      await _supa.from('maintenance_time_logs').insert(timeLogs);
    }
  }

  Future<void> _changeStatus() async {
    final order = _selectedOrder;
    final orderId = order?['id']?.toString();
    final current = order?['status']?.toString() ?? '';
    if (orderId == null || current.isEmpty) return;

    final allNext = _kNextStatuses[current] ?? const [];
    final allowed = allNext
        .where((next) => _canTransition(current, next))
        .toList(growable: false);
    if (allowed.isEmpty) {
      _toast('Tu rol no puede mover este estado');
      return;
    }

    String next = allowed.first;
    final commentC = TextEditingController();

    final ok = await _showMaintenanceDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Cambiar estado'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: next,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: const Color(0xFFF4FAF8),
                      items: allowed
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(_kStatusLabel[e] ?? e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => next = v);
                      },
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Nuevo estado',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: next == 'rechazado'
                            ? 'Comentario (obligatorio)'
                            : 'Comentario',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final comment = commentC.text.trim();
    if (next == 'rechazado' && comment.isEmpty) {
      _toast('El rechazo requiere comentario');
      return;
    }

    final validationError = _validateStatusChange(current, next);
    if (validationError != null) {
      _toast(validationError);
      return;
    }

    final user = _supa.auth.currentUser;
    await _supa
        .from('maintenance_orders')
        .update({'status': next})
        .eq('id', orderId);

    await _supa.from('maintenance_status_log').insert({
      'ot_id': orderId,
      'from_status': current,
      'to_status': next,
      'changed_by': user?.id,
      'changed_by_name': _profileName,
      'comment': comment.isEmpty ? null : comment,
    });

    await _loadOrders();
    await _loadOrderDetails(orderId);
    _toast('Estado actualizado');
  }

  Future<void> _deleteSelectedOrder() async {
    final order = _selectedOrder;
    final orderId = order?['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    final ok = await _showMaintenanceDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar OT'),
          content: Text(
            'Se eliminará ${order?['ot_folio'] ?? 'esta OT'} y su historial. Esta acción no se puede deshacer.',
          ),
          actions: [
            OutlinedButton(
              style: _maintenanceDialogOutlinedButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    try {
      await _supa.from('maintenance_tasks').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_materials').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_time_logs').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_evidence').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_approvals').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_status_log').delete().eq('ot_id', orderId);
      await _supa.from('maintenance_orders').delete().eq('id', orderId);
      _selectedOrderId = null;
      _selectedOrder = null;
      _clearEditors();
      await _loadOrders();
      _toast('OT eliminada');
    } catch (e) {
      _toast('No se pudo eliminar OT: $e');
    }
  }

  Future<void> _runOrderAction(String orderId, String action) async {
    if (_selectedOrderId != orderId) {
      _selectedOrderId = orderId;
      await _loadOrderDetails(orderId);
    }
    switch (action) {
      case 'save':
        await _saveCurrentOrder();
        break;
      case 'status':
        await _changeStatus();
        break;
      case 'delete':
        await _deleteSelectedOrder();
        break;
      case 'evidence':
        await _openEvidenceModal(orderId);
        break;
      case 'pdf':
        await _downloadOrderPdf(orderId);
        break;
    }
  }

  Future<void> _downloadOrderPdf(String orderId) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      if (_selectedOrderId != orderId) {
        _selectedOrderId = orderId;
        await _loadOrderDetails(orderId);
      }
      final order = _selectedOrder;
      if (order == null) {
        _toast('No se pudo cargar la OT para PDF');
        return;
      }

      final doc = pw.Document();
      final folio = (order['ot_folio'] ?? 'OT').toString();
      final estTotal = _materials.fold<double>(
        0,
        (sum, e) => sum + (_toDouble(e['cost_estimated']) ?? 0),
      );
      final realTotal = _materials.fold<double>(
        0,
        (sum, e) => sum + (_toDouble(e['cost_actual']) ?? 0),
      );
      final requestedAt = DateTime.tryParse(
        (order['requested_at'] ?? '').toString(),
      );
      final requestedDate = requestedAt == null
          ? '-'
          : '${requestedAt.year.toString().padLeft(4, '0')}-${requestedAt.month.toString().padLeft(2, '0')}-${requestedAt.day.toString().padLeft(2, '0')}';
      final requestedTime = requestedAt == null
          ? '-'
          : '${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}';
      final statusLabel =
          _kStatusLabel[(order['status'] ?? '').toString()] ??
          (order['status'] ?? '-').toString();
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e, st) {
        AppErrorReporter.report(
          e,
          st,
          fallbackMessage: 'No se pudo cargar el logo para el PDF.',
        );
        logoImage = null;
      }
      final evidencesByCategory = <String, List<String>>{
        for (final key in _kEvidenceCategoryLabel.keys) key: <String>[],
      };
      for (final ev in _evidences) {
        final key = (ev['category'] ?? 'otros').toString();
        final note = (ev['comment'] ?? '').toString().trim();
        final path = (ev['storage_path'] ?? '').toString().trim();
        final url = (ev['file_url'] ?? '').toString().trim();
        final name = path.isNotEmpty
            ? path.split('/').last
            : (url.isNotEmpty ? url.split('/').last : 'archivo');
        final line = note.isEmpty ? name : '$name - $note';
        (evidencesByCategory[key] ?? evidencesByCategory['otros']!).add(line);
      }

      doc.addPage(
        pw.MultiPage(
          pageTheme: _reportPdfPageTheme(),
          build: (context) => [
            _pdfHeaderCard(
              folio: folio,
              site: 'Celaya',
              date: requestedDate,
              time: requestedTime,
              status: statusLabel.toUpperCase(),
              logoImage: logoImage,
            ),
            _pdfSection('DATOS GENERALES', [
              'Area: ${(order['area_label'] ?? '-').toString()}',
              'Equipo: ${(order['equipment_label'] ?? '-').toString()}',
              'Serie: ${(order['equipment_serial'] ?? '-').toString()}',
              'Solicitante: ${(order['requester_name'] ?? '-').toString()}',
              'Mecanico: ${(order['mechanic_name'] ?? '-').toString()}',
              'Contacto mecanico: ${(order['mechanic_contact'] ?? '-').toString()}',
              'Responsable: ${(order['assigned_to_name'] ?? '-').toString()}',
              'Fecha solicitud: ${_fmtDateTimeNullable(order['requested_at'])}',
            ]),
            _pdfSection('CLASIFICACION', [
              'Tipo: ${_kTypeLabel[(order['type'] ?? '').toString()] ?? order['type']}',
              'Prioridad: ${_kPriorityLabel[(order['priority'] ?? '').toString()] ?? order['priority']}',
              'Categoria: ${_kCategoryLabel[(order['category'] ?? '').toString()] ?? order['category']}',
              'Impacto: ${_kImpactLabel[(order['impact'] ?? '').toString()] ?? order['impact']}',
            ]),
            _pdfSection('DESCRIPCION DEL PROBLEMA', [
              (order['problem_description'] ?? '').toString().trim().isEmpty
                  ? '-'
                  : (order['problem_description'] ?? '').toString(),
            ]),
            _pdfSection('DIAGNOSTICO', [
              (order['diagnosis'] ?? '').toString().trim().isEmpty
                  ? '-'
                  : (order['diagnosis'] ?? '').toString(),
            ]),
            _pdfTable(
              title: 'ACTIVIDADES A REALIZAR',
              headers: const [
                'Actividad/Item',
                'Unidad',
                'Cantidad',
                'Hecho',
                'Notas',
              ],
              rows: _tasks
                  .map(
                    (e) => [
                      (e['description'] ?? '').toString(),
                      (e['unit'] ?? '').toString(),
                      (e['qty'] ?? '').toString(),
                      e['is_done'] == true ? 'Sí' : 'No',
                      (e['notes'] ?? '').toString(),
                    ],
                  )
                  .toList(),
            ),
            _pdfTable(
              title: 'MATERIALES / REFACCIONES',
              headers: const [
                'Material',
                'Cantidad',
                'Fuente',
                r'$ Est.',
                r'$ Real',
                'Nota/Archivo',
              ],
              rows: _materials
                  .map(
                    (e) => [
                      (e['name'] ?? '').toString(),
                      (e['qty'] ?? '').toString(),
                      _materialSourceLabel((e['source'] ?? '').toString()),
                      _fmtMoney(_toDouble(e['cost_estimated']) ?? 0),
                      _fmtMoney(_toDouble(e['cost_actual']) ?? 0),
                      (e['notes'] ?? '').toString(),
                    ],
                  )
                  .toList(),
            ),
            _pdfSection('TOTALES', [
              'Estimado: ${_fmtMoney(estTotal)}',
              'Real: ${_fmtMoney(realTotal)}',
            ]),
            _pdfTable(
              title: 'TIEMPOS',
              headers: const ['Inicio', 'Fin', 'Horas', 'Tecnico', 'Nota'],
              rows: _timeLogs.map((e) {
                final start = DateTime.tryParse(
                  (e['start_at'] ?? '').toString(),
                );
                final end = DateTime.tryParse((e['end_at'] ?? '').toString());
                final mins = start != null && end != null
                    ? end.difference(start).inMinutes.clamp(0, 100000)
                    : 0;
                final hours = (mins / 60).toStringAsFixed(2);
                return [
                  start == null ? '-' : _fmtDateTime(start),
                  end == null ? '-' : _fmtDateTime(end),
                  hours,
                  (e['tech_name'] ?? '').toString(),
                  (e['note'] ?? '').toString(),
                ];
              }).toList(),
            ),
            _pdfSection('EVIDENCIAS', [
              'Antes: ${(evidencesByCategory['antes'] ?? const []).join(', ').trim().isEmpty ? 'Sin evidencias' : (evidencesByCategory['antes'] ?? const []).join(', ')}',
              'Durante: ${(evidencesByCategory['durante'] ?? const []).join(', ').trim().isEmpty ? 'Sin evidencias' : (evidencesByCategory['durante'] ?? const []).join(', ')}',
              'Despues: ${(evidencesByCategory['despues'] ?? const []).join(', ').trim().isEmpty ? 'Sin evidencias' : (evidencesByCategory['despues'] ?? const []).join(', ')}',
              'Facturas: ${(evidencesByCategory['facturas'] ?? const []).join(', ').trim().isEmpty ? 'Sin evidencias' : (evidencesByCategory['facturas'] ?? const []).join(', ')}',
              'Otros: ${(evidencesByCategory['otros'] ?? const []).join(', ').trim().isEmpty ? 'Sin evidencias' : (evidencesByCategory['otros'] ?? const []).join(', ')}',
            ]),
            _pdfTable(
              title: 'APROBACIONES',
              headers: const [
                'Paso',
                'Estado',
                'Usuario',
                'Fecha',
                'Comentario',
              ],
              rows: _approvals
                  .map(
                    (e) => [
                      _kApprovalStepLabel[(e['step'] ?? '').toString()] ??
                          (e['step'] ?? '').toString(),
                      (e['status'] ?? '').toString(),
                      (e['by_user_name'] ?? '-').toString(),
                      _fmtDateTimeNullable(e['at']),
                      (e['comment'] ?? '').toString(),
                    ],
                  )
                  .toList(),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final suggestedName = '$folio.pdf';
      String? outputPath;
      if (!kIsWeb) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar OT como PDF',
          fileName: suggestedName,
          allowedExtensions: const ['pdf'],
          type: FileType.custom,
          lockParentWindow: true,
        );
      }

      if (outputPath == null || outputPath.trim().isEmpty) {
        _toast('Guardado cancelado');
        return;
      }

      final normalized = outputPath.toLowerCase().endsWith('.pdf')
          ? outputPath
          : '$outputPath.pdf';
      await File(normalized).writeAsBytes(bytes, flush: true);
      _toast('PDF guardado: $normalized');
    } catch (e) {
      _toast('No se pudo generar PDF: $e');
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  pw.Widget _pdfHeaderCard({
    required String folio,
    required String site,
    required String date,
    required String time,
    required String status,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF1C3E5D),
          width: 1,
        ),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 114,
                height: 40,
                alignment: pw.Alignment.centerLeft,
                child: logoImage == null
                    ? pw.Text(
                        'DICSA',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 15,
                          color: const PdfColor.fromInt(0xFF1C3E5D),
                        ),
                      )
                    : pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.Text(
                'ORDEN DE TRABAJO: $folio',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: const PdfColor.fromInt(0xFF1C3E5D),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sitio: $site',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF1C3E5D),
                ),
              ),
              pw.Text(
                'Fecha: $date',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF1C3E5D),
                ),
              ),
              pw.Text(
                'Hora: $time',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF1C3E5D),
                ),
              ),
              pw.Text(
                'Estado: $status',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF1C3E5D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSection(String title, List<String> lines) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFD8E8EB),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: const PdfColor.fromInt(0xFFF3FAF8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: const PdfColor.fromInt(0xFF123B44),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: lines
                  .map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFD8E8EB),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: const PdfColor.fromInt(0xFFF3FAF8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: const PdfColor.fromInt(0xFF123B44),
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows.isEmpty ? [List.filled(headers.length, '-')] : rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9.5,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: const PdfColor.fromInt(0xFFD8E8EB),
                  width: 0.8,
                ),
                verticalInside: pw.BorderSide(
                  color: const PdfColor.fromInt(0xFFE2EEF0),
                  width: 0.6,
                ),
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1F5B66),
              ),
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _reportPdfHeroCard({
    required DateTime generatedAt,
    required int rowsCount,
    required double totalReal,
    required String dateFilterLabel,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF123B44),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte OT',
                      style: pw.TextStyle(
                        color: const PdfColor.fromInt(0xFF123B44),
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Resumen analitico de mantenimiento con enfoque en costos, carga operativa y seguimiento por unidad.',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFF4F6C71),
                        fontSize: 9.2,
                        lineSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                width: 96,
                height: 38,
                alignment: pw.Alignment.centerRight,
                child: logoImage == null
                    ? pw.Text(
                        'DICSA',
                        style: pw.TextStyle(
                          color: const PdfColor.fromInt(0xFF123B44),
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _reportPdfInfoBadge('Generado', _fmtDateTime(generatedAt)),
              _reportPdfInfoBadge('OT en vista', '$rowsCount'),
              _reportPdfInfoBadge('Costo real', _fmtMoney(totalReal)),
              _reportPdfInfoBadge('Rango', dateFilterLabel),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _reportPdfInfoBadge(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF245A64),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF245A64),
          width: 0.8,
        ),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              color: const PdfColor.fromInt(0xFFB6DDE0),
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _reportPdfMetricGrid(List<MapEntry<String, String>> metrics) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: metrics.map(_reportPdfMetricCard).toList(),
      ),
    );
  }

  pw.Widget _reportPdfMetricCard(MapEntry<String, String> metric) {
    return pw.Container(
      width: 104,
      padding: const pw.EdgeInsets.fromLTRB(9, 9, 9, 9),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF3FAF8),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFD3E8E5),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            metric.key,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xFF5C7C81),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            metric.value,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF123B44),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _reportPdfSection({
    required String title,
    required pw.Widget child,
    double bottomMargin = 12,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: bottomMargin),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFD8E8EB),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF123B44),
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  pw.Widget _reportPdfTwoColumnSection({
    required String leftTitle,
    required pw.Widget leftChild,
    required String rightTitle,
    required pw.Widget rightChild,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _reportPdfSection(title: leftTitle, child: leftChild),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _reportPdfSection(title: rightTitle, child: rightChild),
          ),
        ],
      ),
    );
  }

  pw.Widget _reportPdfRankList(List<MapEntry<String, String>> items) {
    if (items.isEmpty) {
      return pw.Text(
        'Sin datos para mostrar',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xFF6E8A8F),
        ),
      );
    }
    return pw.Column(
      children: items
          .map(
            (entry) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF7FBFC),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFDDEBED),
                  width: 1,
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      entry.key,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF123B44),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    entry.value,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF55757B),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _reportPdfBarChart(
    List<MapEntry<String, double>> items, {
    required PdfColor barColor,
    bool compact = false,
  }) {
    if (items.isEmpty) {
      return pw.Text(
        'Sin datos para mostrar',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xFF6E8A8F),
        ),
      );
    }
    final maxValue = items.fold<double>(
      1,
      (max, entry) => entry.value > max ? entry.value : max,
    );
    final maxBarWidth = compact ? 165.0 : 130.0;
    final labelWidth = compact ? 68.0 : 62.0;
    return pw.Column(
      children: items
          .map(
            (entry) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: compact ? 6 : 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(
                    width: labelWidth,
                    child: pw.Text(
                      entry.key,
                      style: pw.TextStyle(
                        fontSize: compact ? 8.2 : 8.6,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF123B44),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    width: maxBarWidth,
                    height: compact ? 11 : 12,
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE5EFF1),
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFD4E6E9),
                        width: 0.8,
                      ),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        width: maxValue == 0
                            ? 0
                            : maxBarWidth * (entry.value / maxValue),
                        decoration: pw.BoxDecoration(
                          color: barColor,
                          border: pw.Border.all(color: barColor, width: 0.8),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: compact ? 22 : 28,
                    child: pw.Text(
                      entry.value.toStringAsFixed(0),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: compact ? 8.1 : 8.4,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF55757B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _reportPdfPieChart(List<MapEntry<String, double>> items) {
    if (items.isEmpty) {
      return pw.Text(
        'Sin datos para mostrar',
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xFF6E8A8F),
        ),
      );
    }
    const palette = <String>[
      '#1F5B66',
      '#4F8E8C',
      '#7AAFB5',
      '#B7D5D8',
      '#D7E7E8',
    ];
    final total = items.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total <= 0) {
      return pw.Text('Sin datos para mostrar');
    }

    final svg = _buildReportPieChartSvg(
      items,
      palette: palette,
      size: 120,
      radius: 52,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 124, height: 124, child: pw.SvgImage(svg: svg)),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: items.asMap().entries.map((entry) {
              final color = palette[entry.key % palette.length];
              final pct = ((entry.value.value / total) * 100).round();
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF7FBFC),
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFDDEBED),
                    width: 0.8,
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      color: PdfColor.fromHex(color),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        entry.value.key,
                        style: pw.TextStyle(
                          fontSize: 8.8,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF123B44),
                        ),
                      ),
                    ),
                    pw.Text(
                      '${entry.value.value.toStringAsFixed(0)} · $pct%',
                      style: const pw.TextStyle(
                        fontSize: 8.4,
                        color: PdfColor.fromInt(0xFF55757B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _buildReportPieChartSvg(
    List<MapEntry<String, double>> items, {
    required List<String> palette,
    required double size,
    required double radius,
  }) {
    final total = items.fold<double>(0, (sum, entry) => sum + entry.value);
    final center = size / 2;
    var startAngle = -math.pi / 2;
    final buffer = StringBuffer()
      ..write(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size">',
      )
      ..write(
        '<circle cx="$center" cy="$center" r="$radius" fill="#EEF5F6" />',
      );

    for (var i = 0; i < items.length; i++) {
      final value = items[i].value;
      if (value <= 0) continue;
      final sweep = (value / total) * math.pi * 2;
      final endAngle = startAngle + sweep;
      final x1 = center + radius * math.cos(startAngle);
      final y1 = center + radius * math.sin(startAngle);
      final x2 = center + radius * math.cos(endAngle);
      final y2 = center + radius * math.sin(endAngle);
      final largeArc = sweep > math.pi ? 1 : 0;
      buffer.write(
        '<path d="M $center $center L ${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} '
        'A $radius $radius 0 $largeArc 1 ${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} Z" '
        'fill="${palette[i % palette.length]}" stroke="#FFFFFF" stroke-width="1"/>',
      );
      startAngle = endAngle;
    }

    buffer
      ..write(
        '<circle cx="$center" cy="$center" r="18" fill="#FFFFFF" stroke="#DDEBED" stroke-width="1"/>',
      )
      ..write('</svg>');
    return buffer.toString();
  }

  pw.Widget _reportPdfModernTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFD8E8EB),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF123B44),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows.isEmpty ? [List.filled(headers.length, '-')] : rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 8.8,
              color: PdfColor.fromInt(0xFF233E45),
            ),
            headerDecoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF1F5B66),
            ),
            rowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FBFB),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEFF6F7),
            ),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: const PdfColor.fromInt(0xFFD8E8EB),
                width: 0.8,
              ),
              verticalInside: pw.BorderSide(
                color: const PdfColor.fromInt(0xFFE2EEF0),
                width: 0.6,
              ),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
          ),
        ],
      ),
    );
  }

  pw.PageTheme _reportPdfPageTheme() {
    return pw.PageTheme(
      margin: const pw.EdgeInsets.all(24),
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(color: PdfColors.white),
      ),
    );
  }

  String? _validateStatusChange(String current, String next) {
    if (next == 'mantenimiento_realizado') {
      if (_diagnosisC.text.trim().isEmpty) {
        return 'No se puede completar sin diagnostico';
      }
      final validTasks = _tasks
          .where((e) => (e['description'] ?? '').toString().trim().isNotEmpty)
          .toList();
      if (validTasks.isEmpty) {
        return 'Agrega al menos una actividad antes de completar';
      }
    }

    if (next == 'cerrado') {
      if (!_isOpsManagerRole(_profileRole) && _profileRole != 'admin') {
        return 'Solo Jefe Operativo o Admin puede cerrar';
      }
      if (_diagnosisC.text.trim().isEmpty) {
        return 'No se puede cerrar sin diagnostico';
      }
      final validTasks = _tasks
          .where((e) => (e['description'] ?? '').toString().trim().isNotEmpty)
          .toList();
      if (validTasks.isEmpty) {
        return 'No se puede cerrar sin actividades';
      }
      final hasAfterEvidence = _evidences.any(
        (e) => (e['category'] ?? '').toString() == 'despues',
      );
      if (!hasAfterEvidence) {
        return 'No se puede cerrar sin evidencia "despues"';
      }
    }

    if (current == 'programado' && next == 'mantenimiento_realizado') {
      final hasFinance = _orders.any(
        (e) =>
            (e['id'] ?? '').toString() == _selectedOrderId &&
            (_selectedOrder?['status'] ?? '').toString() == 'programado',
      );
      if (!hasFinance) {
        return 'No se puede ejecutar sin autorizacion de finanzas';
      }
    }

    return null;
  }

  bool _canTransition(String from, String to) {
    if (_profileRole == 'admin') return true;
    if (_isOpsManagerRole(_profileRole)) return true;
    if (to == 'rechazado') {
      return _profileRole != 'viewer';
    }

    final key = '$from->$to';
    final allowed = _kTransitionRoles[key] ?? const [];
    final role = _normalizeRole(_profileRole);
    return allowed.contains(role) || allowed.contains(_profileRole);
  }

  String _normalizeRole(String role) {
    switch (role) {
      case 'ops_manager':
        return 'jefe_operativo';
      case 'services':
        return 'tecnico';
      default:
        return role;
    }
  }

  bool _isOpsManagerRole(String role) {
    final normalized = _normalizeRole(role);
    return normalized == 'jefe_operativo' || role == 'ops_manager';
  }

  Future<void> _openEvidenceModal(String orderId) async {
    await _loadOrderDetails(orderId);
    if (!mounted) return;

    await _showMaintenanceDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Evidencias'),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _addEvidence(orderId);
                    },
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Agregar evidencia'),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _evidences.isEmpty
                      ? const Center(child: Text('Sin evidencias'))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _evidences.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _evidences[index];
                            final url = (row['file_url'] ?? '').toString();
                            final isImage = _looksLikeImageUrl(url);
                            return ListTile(
                              dense: true,
                              leading: isImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _showImagePreview(url),
                                        child: Image.network(
                                          url,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                width: 52,
                                                height: 52,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.55),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blueGrey
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.broken_image_rounded,
                                                  size: 20,
                                                ),
                                              ),
                                        ),
                                      ),
                                    )
                                  : null,
                              title: Text(
                                _kEvidenceCategoryLabel[(row['category'] ?? '')
                                        .toString()] ??
                                    (row['category'] ?? '').toString(),
                              ),
                              subtitle: Text(
                                (row['comment'] ?? '').toString().trim().isEmpty
                                    ? 'Sin comentario'
                                    : (row['comment'] ?? '').toString(),
                              ),
                              trailing: IconButton(
                                tooltip: isImage ? 'Vista previa' : 'Abrir',
                                onPressed: url.isEmpty
                                    ? null
                                    : () => isImage
                                          ? _showImagePreview(url)
                                          : _showUrlDialog(url),
                                icon: Icon(
                                  isImage
                                      ? Icons.visibility_rounded
                                      : Icons.open_in_new_rounded,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: _maintenanceDialogOutlinedButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addEvidence(String orderId) async {
    String category = 'durante';
    final commentC = TextEditingController();
    final urlC = TextEditingController();
    PlatformFile? picked;

    final save = await _showMaintenanceDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nueva evidencia'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: const Color(0xFFF4FAF8),
                      items: _kEvidenceCategoryLabel.keys
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(_kEvidenceCategoryLabel[e] ?? e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => category = v);
                      },
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Categoria',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            lockParentWindow: true,
                            type: FileType.image,
                          );
                          if (result == null || result.files.isEmpty) {
                            _toast('No se seleccionó archivo');
                            return;
                          }
                          setLocal(() => picked = result.files.first);
                        } catch (e) {
                          _toast('No se pudo abrir selector de archivos: $e');
                        }
                      },
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(
                        picked == null
                            ? 'Seleccionar foto'
                            : 'Archivo: ${picked!.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: Text('o URL manual')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlC,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'URL (opcional si subes archivo)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Comentario',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) return;

    String url = urlC.text.trim();
    String? storagePath;

    if (picked != null) {
      final uploaded = await _uploadEvidenceFile(orderId, category, picked!);
      if (uploaded == null) return;
      url = uploaded.$1;
      storagePath = uploaded.$2;
    }

    if (url.isEmpty) {
      _toast('Debes seleccionar archivo o capturar URL');
      return;
    }

    final user = _supa.auth.currentUser;
    await _supa.from('maintenance_evidence').insert({
      'ot_id': orderId,
      'category': category,
      'file_url': url,
      'storage_path': storagePath,
      'uploaded_by': user?.id,
      'uploaded_by_name': _profileName,
      'comment': commentC.text.trim().isEmpty ? null : commentC.text.trim(),
    });

    await _loadOrders();
    await _loadOrderDetails(orderId);
    _toast('Evidencia agregada');
  }

  Future<(String, String)?> _uploadEvidenceFile(
    String orderId,
    String category,
    PlatformFile file,
  ) async {
    final sanitized = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'ot/$orderId/$category/${DateTime.now().millisecondsSinceEpoch}_$sanitized';

    try {
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          _toast('No se pudo leer el archivo seleccionado (bytes vacíos)');
          return null;
        }
        await _supa.storage
            .from('maintenance_evidence')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          await _supa.storage
              .from('maintenance_evidence')
              .upload(
                storagePath,
                File(path),
                fileOptions: const FileOptions(upsert: true),
              );
        } else if (file.bytes != null) {
          await _supa.storage
              .from('maintenance_evidence')
              .uploadBinary(
                storagePath,
                file.bytes!,
                fileOptions: const FileOptions(upsert: true),
              );
        } else {
          _toast('No se pudo leer el archivo (sin ruta ni bytes)');
          return null;
        }
      }

      final url = _supa.storage
          .from('maintenance_evidence')
          .getPublicUrl(storagePath);
      return (url, storagePath);
    } catch (e) {
      _toast('No se pudo subir evidencia: $e');
      return null;
    }
  }

  Future<void> _showUrlDialog(String url) async {
    await _showMaintenanceDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('URL de evidencia'),
          content: SelectableText(url),
          actions: [
            OutlinedButton(
              style: _maintenanceDialogOutlinedButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImagePreview(String url) async {
    await _showMaintenanceDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Evidencia'),
          content: SizedBox(
            width: 860,
            height: 520,
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      'No se pudo cargar la imagen.\n$error',
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: _maintenanceDialogOutlinedButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addTask() async {
    final row = await _showTaskDialog();
    if (row == null) return;
    setState(() => _tasks.add(row));
    _scheduleAutosave(immediate: true);
  }

  Future<void> _editTask(int index) async {
    final row = await _showTaskDialog(initial: _tasks[index]);
    if (row == null) return;
    setState(() => _tasks[index] = row);
    _scheduleAutosave(immediate: true);
  }

  Future<Map<String, dynamic>?> _showTaskDialog({
    Map<String, dynamic>? initial,
  }) {
    final descC = TextEditingController(
      text: (initial?['description'] ?? '').toString(),
    );
    final unitC = TextEditingController(
      text: (initial?['unit'] ?? '').toString(),
    );
    final qtyC = TextEditingController(
      text: (initial?['qty'] ?? '').toString(),
    );
    final notesC = TextEditingController(
      text: (initial?['notes'] ?? '').toString(),
    );
    bool isDone = initial?['is_done'] == true;

    return _showMaintenanceDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                initial == null ? 'Nueva actividad' : 'Editar actividad',
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descC,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Actividad',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: unitC,
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Unidad',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: qtyC,
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Cantidad',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Notas',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isDone,
                      onChanged: (v) => setLocal(() => isDone = v == true),
                      title: const Text('Actividad completada'),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () {
                    final desc = descC.text.trim();
                    if (desc.isEmpty) return;
                    Navigator.pop(dialogContext, {
                      'description': desc,
                      'unit': unitC.text.trim(),
                      'qty': _toDouble(qtyC.text),
                      'notes': notesC.text.trim(),
                      'is_done': isDone,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addMaterial() async {
    final row = await _showMaterialDialog();
    if (row == null) return;
    setState(() => _materials.add(row));
    _scheduleAutosave(immediate: true);
  }

  Future<void> _editMaterial(int index) async {
    final row = await _showMaterialDialog(initial: _materials[index]);
    if (row == null) return;
    setState(() => _materials[index] = row);
    _scheduleAutosave(immediate: true);
  }

  Future<Map<String, dynamic>?> _showMaterialDialog({
    Map<String, dynamic>? initial,
  }) {
    final nameC = TextEditingController(
      text: (initial?['name'] ?? '').toString(),
    );
    final qtyC = TextEditingController(
      text: (initial?['qty'] ?? '').toString(),
    );
    final estC = TextEditingController(
      text: (initial?['cost_estimated'] ?? '').toString(),
    );
    final realC = TextEditingController(
      text: (initial?['cost_actual'] ?? '').toString(),
    );
    final notesC = TextEditingController(
      text: (initial?['notes'] ?? '').toString(),
    );
    String source = (initial?['source'] ?? 'almacen').toString();

    return _showMaintenanceDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                initial == null
                    ? 'Nuevo costo (material/mano de obra)'
                    : 'Editar costo (material/mano de obra)',
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Concepto',
                        hintText:
                            'Ej. Manguera, Tornillo, Mano de obra electricista',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Cantidad',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: source,
                            isExpanded: true,
                            menuMaxHeight: 320,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: const Color(0xFFF4FAF8),
                            items: const [
                              DropdownMenuItem(
                                value: 'almacen',
                                child: Text('Almacen'),
                              ),
                              DropdownMenuItem(
                                value: 'compra',
                                child: Text('Compra'),
                              ),
                              DropdownMenuItem(
                                value: 'proveedor',
                                child: Text('Proveedor'),
                              ),
                              DropdownMenuItem(
                                value: 'mano_obra',
                                child: Text('Mano de obra'),
                              ),
                              DropdownMenuItem(
                                value: 'servicio_tecnico',
                                child: Text('Servicio tecnico'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setLocal(() => source = v);
                            },
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Fuente',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: estC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Costo estimado',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: realC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _maintenanceInputDecoration(
                              labelText: 'Costo real',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Notas',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () {
                    final name = nameC.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(dialogContext, {
                      'name': name,
                      'qty': _toDouble(qtyC.text),
                      'source': source,
                      'cost_estimated': _toDouble(estC.text),
                      'cost_actual': _toDouble(realC.text),
                      'notes': notesC.text.trim(),
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addTimeLog() async {
    final row = await _showTimeDialog();
    if (row == null) return;
    setState(() => _timeLogs.add(row));
    _scheduleAutosave(immediate: true);
  }

  Future<void> _editTimeLog(int index) async {
    final row = await _showTimeDialog(initial: _timeLogs[index]);
    if (row == null) return;
    setState(() => _timeLogs[index] = row);
    _scheduleAutosave(immediate: true);
  }

  Future<Map<String, dynamic>?> _showTimeDialog({
    Map<String, dynamic>? initial,
  }) {
    final techC = TextEditingController(
      text: (initial?['tech_name'] ?? '').toString(),
    );
    final noteC = TextEditingController(
      text: (initial?['note'] ?? '').toString(),
    );

    DateTime start =
        DateTime.tryParse((initial?['start_at'] ?? '').toString()) ??
        DateTime.now();
    DateTime end =
        DateTime.tryParse((initial?['end_at'] ?? '').toString()) ??
        start.add(const Duration(hours: 1));

    return _showMaintenanceDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(initial == null ? 'Nuevo tiempo' : 'Editar tiempo'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: techC,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Tecnico',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Inicio: ${_fmtDateTime(start)}'),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: _maintenanceDialogOutlinedButtonStyle(),
                      onPressed: () async {
                        final date = await _showMaintenanceDatePicker(
                          dialogContext,
                          initialDate: start,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        if (!dialogContext.mounted) return;
                        final time = await _showMaintenanceTimePicker(
                          dialogContext,
                          initialTime: TimeOfDay.fromDateTime(start),
                        );
                        if (time == null) return;
                        setLocal(() {
                          start = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          if (end.isBefore(start)) {
                            end = start.add(const Duration(hours: 1));
                          }
                        });
                      },
                      child: const Text('Editar inicio'),
                    ),
                    const SizedBox(height: 8),
                    Text('Fin: ${_fmtDateTime(end)}'),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: _maintenanceDialogOutlinedButtonStyle(),
                      onPressed: () async {
                        final date = await _showMaintenanceDatePicker(
                          dialogContext,
                          initialDate: end,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        if (!dialogContext.mounted) return;
                        final time = await _showMaintenanceTimePicker(
                          dialogContext,
                          initialTime: TimeOfDay.fromDateTime(end),
                        );
                        if (time == null) return;
                        setLocal(() {
                          end = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: const Text('Editar fin'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Nota',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'tech_name': techC.text.trim(),
                      'start_at': start.toIso8601String(),
                      'end_at': end.toIso8601String(),
                      'note': noteC.text.trim(),
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addApproval() async {
    final orderId = _selectedOrderId;
    if (orderId == null) return;

    String step = 'operador';
    String status = 'pendiente';
    final commentC = TextEditingController();

    final ok = await _showMaintenanceDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nueva aprobacion'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: step,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: const Color(0xFFF4FAF8),
                      items: const [
                        DropdownMenuItem(
                          value: 'operador',
                          child: Text('Operador'),
                        ),
                        DropdownMenuItem(
                          value: 'jefe_area',
                          child: Text('Jefe de area'),
                        ),
                        DropdownMenuItem(
                          value: 'interviniente',
                          child: Text('Interviniente'),
                        ),
                        DropdownMenuItem(
                          value: 'direccion',
                          child: Text('Direccion'),
                        ),
                        DropdownMenuItem(
                          value: 'jefe_operativo',
                          child: Text('Jefe operativo'),
                        ),
                        DropdownMenuItem(
                          value: 'finanzas',
                          child: Text('Finanzas'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => step = v);
                      },
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Paso',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: const Color(0xFFF4FAF8),
                      items: const [
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                        DropdownMenuItem(
                          value: 'aprobada',
                          child: Text('Aprobada'),
                        ),
                        DropdownMenuItem(
                          value: 'rechazada',
                          child: Text('Rechazada'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => status = v);
                      },
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Estado',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentC,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _maintenanceInputDecoration(
                        labelText: 'Comentario',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: _maintenanceDialogOutlinedButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: _maintenanceDialogFilledButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    if (status == 'rechazada' && commentC.text.trim().isEmpty) {
      _toast('Comentario obligatorio para rechazo');
      return;
    }

    final user = _supa.auth.currentUser;
    await _supa.from('maintenance_approvals').insert({
      'ot_id': orderId,
      'step': step,
      'status': status,
      'by_user_id': user?.id,
      'by_user_name': _profileName,
      'at': DateTime.now().toIso8601String(),
      'comment': commentC.text.trim().isEmpty ? null : commentC.text.trim(),
    });

    await _loadOrders();
    await _loadOrderDetails(orderId);
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _goToDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(page: const DashboardPage(instantOpen: true)),
    );
  }

  Future<void> _goToGeneralDashboard() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!AuthAccess.canAccessGeneralDashboard(profile)) return;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryPage()));
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryProductionPage()));
  }

  Future<void> _goToInventory() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const InventoryStockPage()));
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const ServicesPage()));
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const WeighingsPage()));
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const WarehousePage()));
  }

  @override
  Widget build(BuildContext context) {
    return ServicesShell(
      headerTitle: 'Mantenimiento',
      activeOverlayModule: ServicesOverlayNavModule.mantenimiento,
      onHeaderGuide: _showOtFlowGuide,
      headerGuideLabel: 'Flujo OT',
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: () async {},
      onGoToWarehouse: _goToWarehouse,
      topContent: _buildTopActions(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildWorkspaceSwitcher(),
                const SizedBox(height: 10),
                Expanded(
                  child: _workspace == _MaintenanceWorkspace.orders
                      ? _buildOrdersWorkspace()
                      : _buildReportsWorkspace(),
                ),
              ],
            ),
    );
  }

  Widget _buildTopActions() {
    return OperationalGlassToolbarPanel(
      child: _workspace == _MaintenanceWorkspace.orders
          ? _buildOrdersTopActionsBar()
          : _buildReportsTopActionsBar(),
    );
  }

  Widget _buildOrdersTopActionsBar() {
    final openStates = _orders.where((e) {
      final st = (e['status'] ?? '').toString();
      return st != 'cerrado' && st != 'rechazado';
    }).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Card(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  style: _maintenanceActionFilledButtonStyle(),
                  onPressed: _creating ? null : _createOrder,
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text('Nueva OT'),
                ),
              );

              final info = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_orders.length} OT totales',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$openStates abiertas · ${_countStatus('cerrado')} cerradas',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A4B49),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: actions),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: actions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  info,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTopActionsBar() {
    final rows = _filteredReportOrders;
    final filtersCount = _reportActiveFiltersCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Card(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: _maintenanceActionOutlinedButtonStyle(),
                      onPressed: _exportingReportPdf
                          ? null
                          : _exportCurrentReportPdf,
                      icon: Icon(
                        _exportingReportPdf
                            ? Icons.hourglass_top_rounded
                            : Icons.picture_as_pdf_outlined,
                      ),
                      label: Text(
                        _exportingReportPdf
                            ? 'Generando PDF...'
                            : 'Descargar PDF',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: _maintenanceActionOutlinedButtonStyle(),
                      onPressed: _exportingReportCsv
                          ? null
                          : _exportCurrentReportCsv,
                      icon: Icon(
                        _exportingReportCsv
                            ? Icons.hourglass_top_rounded
                            : Icons.download_rounded,
                      ),
                      label: Text(
                        _exportingReportCsv ? 'Exportando...' : 'Descargar CSV',
                      ),
                    ),
                    if (_hasActiveReportFilters) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: _maintenanceActionFilledButtonStyle(),
                        onPressed: () {
                          setState(() {
                            _reportMechanicFilters.clear();
                            _reportEquipmentFilters.clear();
                            _reportAreaFilters.clear();
                            _reportStatusFilters.clear();
                            _reportTypeFilters.clear();
                            _reportDateRange = null;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpiar filtros'),
                      ),
                    ],
                  ],
                ),
              );

              final info = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rows.length} OT visibles',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$filtersCount filtros activos · ${_fmtReportDateRangeLabel(compact: true)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A4B49),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: actions),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: actions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  info,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceSwitcher() {
    final isOrders = _workspace == _MaintenanceWorkspace.orders;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDBF0E8), Color(0xFFD8E8F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E3A47).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _workspaceSwitchChip(
              title: 'Operacion OT',
              subtitle: 'Captura y seguimiento',
              icon: Icons.fact_check_outlined,
              selected: isOrders,
              onTap: () =>
                  setState(() => _workspace = _MaintenanceWorkspace.orders),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _workspaceSwitchChip(
              title: 'Reportes OT',
              subtitle: 'Resumenes y analitica',
              icon: Icons.insights_rounded,
              selected: !isOrders,
              onTap: () =>
                  setState(() => _workspace = _MaintenanceWorkspace.reports),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceSwitchChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF103A42), Color(0xFF256A7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.42)
                : const Color(0xFF6AA3B3).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE8F5F4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF1F5B66),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: selected ? Colors.white : const Color(0xFF103A42),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.82)
                          : const Color(0xFF43656C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersWorkspace() {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1180) {
          return Column(
            children: [
              _buildDashboardCards(),
              const SizedBox(height: 10),
              SizedBox(height: 300, child: _buildOrdersTable()),
              const SizedBox(height: 10),
              Expanded(child: _buildOrderSheet()),
            ],
          );
        }

        return Column(
          children: [
            _buildDashboardCards(),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 470, child: _buildOrdersTable()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildOrderSheet()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredReportOrders {
    return _orders.where((order) {
      final mechanic = (order['mechanic_name'] ?? '').toString().trim();
      final equipment = (order['equipment_label'] ?? '').toString().trim();
      final area = (order['area_label'] ?? '').toString().trim();
      final status = (order['status'] ?? '').toString().trim();
      final type = (order['type'] ?? '').toString().trim();
      final requestedAt = DateTime.tryParse(
        (order['requested_at'] ?? '').toString(),
      );

      if (_reportMechanicFilters.isNotEmpty &&
          !_reportMechanicFilters.contains(mechanic)) {
        return false;
      }
      if (_reportEquipmentFilters.isNotEmpty &&
          !_reportEquipmentFilters.contains(equipment)) {
        return false;
      }
      if (_reportAreaFilters.isNotEmpty && !_reportAreaFilters.contains(area)) {
        return false;
      }
      if (_reportStatusFilters.isNotEmpty &&
          !_reportStatusFilters.contains(status)) {
        return false;
      }
      if (_reportTypeFilters.isNotEmpty && !_reportTypeFilters.contains(type)) {
        return false;
      }
      if (_reportDateRange != null && requestedAt != null) {
        final start = DateTime(
          _reportDateRange!.start.year,
          _reportDateRange!.start.month,
          _reportDateRange!.start.day,
        );
        final end = DateTime(
          _reportDateRange!.end.year,
          _reportDateRange!.end.month,
          _reportDateRange!.end.day,
          23,
          59,
          59,
        );
        if (requestedAt.isBefore(start) || requestedAt.isAfter(end)) {
          return false;
        }
      } else if (_reportDateRange != null && requestedAt == null) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _distinctReportValues(String key) {
    final byNormalized = <String, String>{};
    for (final row in _orders) {
      final value = (row[key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      byNormalized.putIfAbsent(value.toLowerCase(), () => value);
    }
    final values = byNormalized.values.toList()..sort();
    return values;
  }

  void _sanitizeReportFilters() {
    final mechanicOptions = _distinctReportValues('mechanic_name');
    final equipmentOptions = _distinctReportValues('equipment_label');
    final areaOptions = _distinctReportValues('area_label');
    _reportMechanicFilters = _reportMechanicFilters
        .where(mechanicOptions.contains)
        .toSet();
    _reportEquipmentFilters = _reportEquipmentFilters
        .where(equipmentOptions.contains)
        .toSet();
    _reportAreaFilters = _reportAreaFilters.where(areaOptions.contains).toSet();
    _reportStatusFilters = _reportStatusFilters
        .where(_kStatusLabel.keys.contains)
        .toSet();
    _reportTypeFilters = _reportTypeFilters
        .where(_kTypeLabel.keys.contains)
        .toSet();
  }

  Map<String, int> _groupCount(
    Iterable<Map<String, dynamic>> rows,
    String key,
  ) {
    final map = <String, int>{};
    for (final row in rows) {
      final value = (row[key] ?? '').toString().trim();
      final label = value.isEmpty ? 'Sin dato' : value;
      map[label] = (map[label] ?? 0) + 1;
    }
    return map;
  }

  double _sumOrderCost(Iterable<Map<String, dynamic>> rows, String field) {
    return rows.fold<double>(
      0,
      (sum, row) => sum + (_toDouble(row[field]) ?? 0),
    );
  }

  int _totalMinutesForOrders(Iterable<Map<String, dynamic>> rows) {
    final ids = rows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _reportTimeLogs.fold<int>(0, (sum, log) {
      final otId = (log['ot_id'] ?? '').toString();
      if (!ids.contains(otId)) return sum;
      final explicitMinutes = log['minutes'];
      if (explicitMinutes is num) return sum + explicitMinutes.toInt();
      final start = DateTime.tryParse((log['start_at'] ?? '').toString());
      final end = DateTime.tryParse((log['end_at'] ?? '').toString());
      if (start == null || end == null) return sum;
      return sum + end.difference(start).inMinutes.clamp(0, 100000);
    });
  }

  int _countTasksForOrders(
    Iterable<Map<String, dynamic>> rows, {
    bool onlyDone = false,
  }) {
    final ids = rows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _reportTasks.where((task) {
      final otId = (task['ot_id'] ?? '').toString();
      if (!ids.contains(otId)) return false;
      if (!onlyDone) return true;
      return task['is_done'] == true;
    }).length;
  }

  int _countMaterialsForOrders(Iterable<Map<String, dynamic>> rows) {
    final ids = rows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _reportMaterials.where((row) {
      final otId = (row['ot_id'] ?? '').toString();
      return ids.contains(otId);
    }).length;
  }

  Widget _buildReportsWorkspace() {
    final rows = _filteredReportOrders;
    final totalReal = _sumOrderCost(rows, 'cost_actual_total');
    final totalEstimated = _sumOrderCost(rows, 'cost_estimated_total');
    final totalMinutes = _totalMinutesForOrders(rows);
    final totalTasks = _countTasksForOrders(rows);
    final totalDoneTasks = _countTasksForOrders(rows, onlyDone: true);
    final totalMaterials = _countMaterialsForOrders(rows);
    final closedCount = rows
        .where((row) => (row['status'] ?? '').toString() == 'cerrado')
        .length;
    final averageCost = rows.isEmpty ? 0.0 : totalReal / rows.length;
    final uniqueUnits = rows
        .map((row) => (row['equipment_label'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6FBFA), Color(0xFFEAF4F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Scrollbar(
        controller: _reportsScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _reportsScrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReportsHero(rows),
              const SizedBox(height: 12),
              _buildReportFilters(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final kpiWidth = _adaptiveTileWidth(
                    constraints.maxWidth,
                    largeColumns: 4,
                    mediumColumns: 3,
                    smallColumns: 2,
                    minWidth: 178,
                  );
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _reportKpiCard(
                        'OTs encontradas',
                        '${rows.length}',
                        'Unidades: $uniqueUnits',
                        Icons.inventory_2_outlined,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Costo real',
                        _fmtMoney(totalReal),
                        'Estimado: ${_fmtMoney(totalEstimated)}',
                        Icons.payments_outlined,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Horas registradas',
                        (totalMinutes / 60).toStringAsFixed(1),
                        '$totalMinutes min acumulados',
                        Icons.schedule_rounded,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Actividades',
                        '$totalTasks',
                        '$totalDoneTasks realizadas',
                        Icons.checklist_rounded,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Materiales',
                        '$totalMaterials',
                        'Renglones requeridos',
                        Icons.handyman_outlined,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Cierre',
                        rows.isEmpty
                            ? '0%'
                            : '${((closedCount / rows.length) * 100).round()}%',
                        '$closedCount cerradas',
                        Icons.check_circle_outline_rounded,
                        width: kpiWidth,
                      ),
                      _reportKpiCard(
                        'Ticket promedio',
                        _fmtMoney(averageCost),
                        'Por OT filtrada',
                        Icons.bar_chart_rounded,
                        width: kpiWidth,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final panelWidth = _adaptiveTileWidth(
                    constraints.maxWidth,
                    largeColumns: 3,
                    mediumColumns: 2,
                    smallColumns: 1,
                    minWidth: 300,
                  );
                  return Wrap(
                    spacing: 10,
                    runSpacing: 0,
                    children: [
                      SizedBox(
                        width: panelWidth,
                        child: _buildMechanicSpotlight(rows),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildUnitSpotlight(rows),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildImpactBreakdown(rows),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildStatusBreakdown(rows),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildMechanicCostBreakdown(rows),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildTopUnitsBreakdown(rows),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _buildMonthlyTrend(rows),
                      ),
                    ],
                  );
                },
              ),
              _buildDetailedReportTable(rows),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsHero(List<Map<String, dynamic>> rows) {
    final mechanicLabel = _reportFilterSummaryLabel(
      _reportMechanicFilters,
      emptyLabel: 'Todos los mecanicos',
      pluralLabel: 'mecanicos',
    );
    final equipmentLabel = _reportFilterSummaryLabel(
      _reportEquipmentFilters,
      emptyLabel: 'Todas las unidades',
      pluralLabel: 'unidades',
    );
    final dateLabel = _reportDateRange == null
        ? 'Historico completo'
        : '${_reportDateRange!.start.day.toString().padLeft(2, '0')}/${_reportDateRange!.start.month.toString().padLeft(2, '0')}/${_reportDateRange!.start.year} - ${_reportDateRange!.end.day.toString().padLeft(2, '0')}/${_reportDateRange!.end.month.toString().padLeft(2, '0')}/${_reportDateRange!.end.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123B44), Color(0xFF2F6F7D), Color(0xFF7DB7BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reportes OT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vista analitica para revisar trabajos por mecanico, unidad, costo, fechas y etapa operativa.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill(Icons.person_outline_rounded, mechanicLabel),
              _heroPill(Icons.local_shipping_outlined, equipmentLabel),
              _heroPill(Icons.calendar_month_outlined, dateLabel),
              _heroPill(Icons.summarize_outlined, '${rows.length} OT en vista'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportFilters() {
    final mechanicOptions = _distinctReportValues('mechanic_name');
    final equipmentOptions = _distinctReportValues('equipment_label');
    final areaOptions = _distinctReportValues('area_label');
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Card(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF1B5560)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filtros de resumen',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_hasActiveReportFilters)
                    OutlinedButton.icon(
                      style: _maintenanceFilterOutlinedButtonStyle(),
                      onPressed: () {
                        setState(() {
                          _reportMechanicFilters.clear();
                          _reportEquipmentFilters.clear();
                          _reportAreaFilters.clear();
                          _reportStatusFilters.clear();
                          _reportTypeFilters.clear();
                          _reportDateRange = null;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpiar'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 250,
                    child: _reportMultiSelectFilterButton(
                      label: 'Mecanico',
                      values: _reportMechanicFilters,
                      options: mechanicOptions,
                      pluralLabel: 'mecanicos',
                      onPressed: () => _openReportMultiSelectFilter(
                        label: 'Mecanico',
                        options: mechanicOptions,
                        initialSelected: _reportMechanicFilters,
                        onApplied: (values) =>
                            setState(() => _reportMechanicFilters = values),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _reportMultiSelectFilterButton(
                      label: 'Unidad',
                      values: _reportEquipmentFilters,
                      options: equipmentOptions,
                      pluralLabel: 'unidades',
                      onPressed: () => _openReportMultiSelectFilter(
                        label: 'Unidad',
                        options: equipmentOptions,
                        initialSelected: _reportEquipmentFilters,
                        onApplied: (values) =>
                            setState(() => _reportEquipmentFilters = values),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _reportMultiSelectFilterButton(
                      label: 'Area',
                      values: _reportAreaFilters,
                      options: areaOptions,
                      pluralLabel: 'areas',
                      onPressed: () => _openReportMultiSelectFilter(
                        label: 'Area',
                        options: areaOptions,
                        initialSelected: _reportAreaFilters,
                        onApplied: (values) =>
                            setState(() => _reportAreaFilters = values),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _reportMultiSelectFilterButton(
                      label: 'Estatus',
                      values: _reportStatusFilters,
                      options: _kStatusLabel.keys.toList(),
                      pluralLabel: 'estatus',
                      labelBuilder: (v) => _kStatusLabel[v] ?? v,
                      onPressed: () => _openReportMultiSelectFilter(
                        label: 'Estatus',
                        options: _kStatusLabel.keys.toList(),
                        initialSelected: _reportStatusFilters,
                        labelBuilder: (v) => _kStatusLabel[v] ?? v,
                        onApplied: (values) =>
                            setState(() => _reportStatusFilters = values),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: _reportMultiSelectFilterButton(
                      label: 'Tipo',
                      values: _reportTypeFilters,
                      options: _kTypeLabel.keys.toList(),
                      pluralLabel: 'tipos',
                      labelBuilder: (v) => _kTypeLabel[v] ?? v,
                      onPressed: () => _openReportMultiSelectFilter(
                        label: 'Tipo',
                        options: _kTypeLabel.keys.toList(),
                        initialSelected: _reportTypeFilters,
                        labelBuilder: (v) => _kTypeLabel[v] ?? v,
                        onApplied: (values) =>
                            setState(() => _reportTypeFilters = values),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 290,
                    child: OutlinedButton.icon(
                      style: _maintenanceFilterOutlinedButtonStyle(),
                      onPressed: _pickReportDateRange,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(_fmtReportDateRangeLabel()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActiveReportFilters =>
      _reportMechanicFilters.isNotEmpty ||
      _reportEquipmentFilters.isNotEmpty ||
      _reportAreaFilters.isNotEmpty ||
      _reportStatusFilters.isNotEmpty ||
      _reportTypeFilters.isNotEmpty ||
      _reportDateRange != null;

  int get _reportActiveFiltersCount {
    var count = 0;
    if (_reportMechanicFilters.isNotEmpty) count++;
    if (_reportEquipmentFilters.isNotEmpty) count++;
    if (_reportAreaFilters.isNotEmpty) count++;
    if (_reportStatusFilters.isNotEmpty) count++;
    if (_reportTypeFilters.isNotEmpty) count++;
    if (_reportDateRange != null) count++;
    return count;
  }

  String _fmtReportDateRangeLabel({bool compact = false}) {
    if (_reportDateRange == null) {
      return compact ? 'Sin rango' : 'Rango de fechas';
    }
    final start = _reportDateRange!.start;
    final end = _reportDateRange!.end;
    final startLabel =
        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
    final endLabel =
        '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
    return compact ? '$startLabel - $endLabel' : '$startLabel - $endLabel';
  }

  String _reportFilterSummaryLabel(
    Set<String> values, {
    required String emptyLabel,
    required String pluralLabel,
    String Function(String value)? labelBuilder,
  }) {
    if (values.isEmpty) return emptyLabel;
    if (values.length == 1) {
      final only = values.first;
      return labelBuilder == null ? only : labelBuilder(only);
    }
    return '${values.length} $pluralLabel';
  }

  Widget _reportMultiSelectFilterButton({
    required String label,
    required Set<String> values,
    required List<String> options,
    required VoidCallback onPressed,
    required String pluralLabel,
    String Function(String value)? labelBuilder,
  }) {
    final dedupedOptions = <String>{
      for (final option in options)
        if (option.trim().isNotEmpty) option.trim(),
    }.toList()..sort();
    final effectiveValues = values.where(dedupedOptions.contains).toSet();
    final summary = _reportFilterSummaryLabel(
      effectiveValues,
      emptyLabel: 'Todos',
      pluralLabel: pluralLabel,
      labelBuilder: labelBuilder,
    );
    return OutlinedButton.icon(
      style: _maintenanceFilterOutlinedButtonStyle().copyWith(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.filter_list_rounded),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF42666C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2B2B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReportMultiSelectFilter({
    required String label,
    required List<String> options,
    required Set<String> initialSelected,
    required ValueChanged<Set<String>> onApplied,
    String Function(String value)? labelBuilder,
  }) async {
    final dedupedOptions = <String>{
      for (final option in options)
        if (option.trim().isNotEmpty) option.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final result = await showDialog<_MaintenanceFilterDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        final localSelected = <String>{
          ...initialSelected.where(dedupedOptions.contains),
        };
        String localSearch = '';

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final visibleOptions = dedupedOptions.where((option) {
              final candidate = labelBuilder == null
                  ? option
                  : labelBuilder(option);
              return localSearch.trim().isEmpty ||
                  candidate.toLowerCase().contains(
                    localSearch.trim().toLowerCase(),
                  );
            }).toList();
            final allVisibleSelected =
                visibleOptions.isNotEmpty &&
                visibleOptions.every(localSelected.contains);

            void applyAndClose() {
              Navigator.pop(
                dialogContext,
                _MaintenanceFilterDialogResult(
                  selectedValues: {...localSelected},
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _maintenanceFilterDialogDecoration(),
                    child: FocusScope(
                      autofocus: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtro: $label',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (value) =>
                                setLocalState(() => localSearch = value),
                            onSubmitted: (_) => applyAndClose(),
                            decoration: _maintenanceInputDecoration(
                              hintText: 'Buscar',
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2A4B49),
                                ),
                                onPressed: () {
                                  setLocalState(() {
                                    if (allVisibleSelected) {
                                      localSelected.removeAll(visibleOptions);
                                    } else {
                                      localSelected.addAll(visibleOptions);
                                    }
                                  });
                                },
                                child: Text(
                                  allVisibleSelected
                                      ? 'Deseleccionar visibles'
                                      : 'Seleccionar visibles',
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${localSelected.length} seleccionados',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: visibleOptions.isEmpty
                                ? const Center(
                                    child: Text('Sin valores para mostrar'),
                                  )
                                : ListView.builder(
                                    itemCount: visibleOptions.length,
                                    itemBuilder: (_, index) {
                                      final value = visibleOptions[index];
                                      final checked = localSelected.contains(
                                        value,
                                      );
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        title: Text(
                                          labelBuilder == null
                                              ? value
                                              : labelBuilder(value),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onChanged: (selected) {
                                          setLocalState(() {
                                            if (selected ?? false) {
                                              localSelected.add(value);
                                            } else {
                                              localSelected.remove(value);
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
                                style: _maintenanceFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _maintenanceFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _MaintenanceFilterDialogResult(
                                    selectedValues: <String>{},
                                  ),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _maintenanceFilterFilledButtonStyle(),
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
        );
      },
    );

    if (!mounted || result == null) return;
    onApplied(result.selectedValues);
  }

  Future<void> _pickReportDateRange() async {
    final now = DateTime.now();
    final picked = await _showMaintenanceReportDateRangeDialog(
      context,
      label: 'Rango de fechas',
      bounds: DateTimeRange(
        start: DateTime(now.year - 3, 1, 1),
        end: DateTime(now.year + 1, 12, 31),
      ),
      initialRange: _reportDateRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.clear) {
        _reportDateRange = null;
      } else {
        _reportDateRange = picked.range;
      }
    });
  }

  Widget _reportKpiCard(
    String title,
    String value,
    String caption,
    IconData icon, {
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E4E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1B6671)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B6970),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5F7D83)),
          ),
        ],
      ),
    );
  }

  double _adaptiveTileWidth(
    double availableWidth, {
    required int largeColumns,
    required int mediumColumns,
    required int smallColumns,
    required double minWidth,
    double spacing = 10,
  }) {
    final columns = availableWidth >= 1380
        ? largeColumns
        : availableWidth >= 900
        ? mediumColumns
        : smallColumns;
    final width = (availableWidth - (spacing * (columns - 1))) / columns;
    if (width >= minWidth || columns == 1) return width;
    final fallbackColumns = columns > 2 ? 2 : 1;
    return (availableWidth - (spacing * (fallbackColumns - 1))) /
        fallbackColumns;
  }

  Widget _buildMechanicSpotlight(List<Map<String, dynamic>> rows) {
    final effectiveMechanic =
        (_reportMechanicFilters.length == 1
            ? _reportMechanicFilters.first
            : null) ??
        (() {
          final grouped = _groupCount(rows, 'mechanic_name').entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return grouped.isEmpty ? null : grouped.first.key;
        })();
    final mechanicRows = effectiveMechanic == null
        ? <Map<String, dynamic>>[]
        : rows
              .where(
                (row) =>
                    (row['mechanic_name'] ?? '').toString().trim() ==
                    effectiveMechanic,
              )
              .toList();
    final units = mechanicRows
        .map((row) => (row['equipment_label'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    final totalReal = _sumOrderCost(mechanicRows, 'cost_actual_total');
    final totalTasks = _countTasksForOrders(mechanicRows);
    final doneTasks = _countTasksForOrders(mechanicRows, onlyDone: true);
    final totalMaterials = _countMaterialsForOrders(mechanicRows);
    final statuses = _groupCount(mechanicRows, 'status').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final impacts = _groupCount(mechanicRows, 'impact').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final latestDate = mechanicRows
        .map((row) => DateTime.tryParse((row['updated_at'] ?? '').toString()))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });

    return _reportPanel(
      title: 'Resumen por mecanico',
      icon: Icons.person_search_rounded,
      child: mechanicRows.isEmpty
          ? const Text(
              'Selecciona un mecanico o ajusta filtros para ver resumen.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effectiveMechanic ?? 'Sin mecanico',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryTag('OTs', '${mechanicRows.length}'),
                    _summaryTag('Unidades', '${units.length}'),
                    _summaryTag('Costo real', _fmtMoney(totalReal)),
                    _summaryTag('Impacto dominante', _labelForImpact(impacts)),
                    _summaryTag(
                      'Actividades',
                      '$totalTasks / $doneTasks hechas',
                    ),
                    _summaryTag('Materiales', '$totalMaterials'),
                    _summaryTag(
                      'Ultimo movimiento',
                      latestDate == null ? '-' : _fmtDateTime(latestDate),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (statuses.isNotEmpty) ...[
                  const Text(
                    'Etapas actuales',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  ...statuses
                      .take(4)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 170,
                                child: Text(
                                  _kStatusLabel[entry.key] ?? entry.key,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 10,
                                    value: mechanicRows.isEmpty
                                        ? 0
                                        : entry.value / mechanicRows.length,
                                    backgroundColor: const Color(0xFFDDEDF0),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2E7B86),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusBreakdown(List<Map<String, dynamic>> rows) {
    final grouped = _groupCount(rows, 'status').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _reportPanel(
      title: 'Distribucion por etapa',
      icon: Icons.account_tree_outlined,
      child: grouped.isEmpty
          ? const Text('Sin datos para este filtro.')
          : Column(
              children: grouped
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 170,
                            child: Text(
                              _kStatusLabel[entry.key] ?? entry.key,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 12,
                                value: rows.isEmpty
                                    ? 0
                                    : entry.value / rows.length,
                                backgroundColor: const Color(0xFFE3EEF1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF377D8A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildImpactBreakdown(List<Map<String, dynamic>> rows) {
    final grouped = _groupCount(rows, 'impact').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const palette = <Color>[
      Color(0xFF1F6F78),
      Color(0xFF3D8D99),
      Color(0xFF78B7BD),
      Color(0xFFA9D2D6),
    ];
    final total = grouped.fold<int>(0, (sum, entry) => sum + entry.value);
    return _reportPanel(
      title: 'Distribucion por impacto',
      icon: Icons.donut_large_rounded,
      child: grouped.isEmpty
          ? const Text('Sin datos de impacto para este filtro.')
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            segments: grouped
                                .asMap()
                                .entries
                                .map(
                                  (entry) => _DonutSegment(
                                    value: entry.value.value.toDouble(),
                                    color: palette[entry.key % palette.length],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'OT',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5C7C81),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: grouped.asMap().entries.map((entry) {
                      final color = palette[entry.key % palette.length];
                      final label =
                          _kImpactLabel[entry.value.key] ?? entry.value.key;
                      final pct = total == 0
                          ? 0
                          : ((entry.value.value / total) * 100).round();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5FBFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD5E6E9)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label)),
                            Text(
                              '${entry.value.value} · $pct%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMechanicCostBreakdown(List<Map<String, dynamic>> rows) {
    final grouped = <String, double>{};
    for (final row in rows) {
      final key = (row['mechanic_name'] ?? '').toString().trim();
      final label = key.isEmpty ? 'Sin mecanico' : key;
      grouped[label] =
          (grouped[label] ?? 0) + (_toDouble(row['cost_actual_total']) ?? 0);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isEmpty
        ? 1.0
        : entries.fold<double>(
            0,
            (max, entry) => entry.value > max ? entry.value : max,
          );
    return _reportPanel(
      title: 'Costo real por mecanico',
      icon: Icons.bar_chart_rounded,
      child: entries.isEmpty
          ? const Text('Sin costos para este filtro.')
          : Column(
              children: entries.take(6).map((entry) {
                final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 14,
                            value: ratio,
                            backgroundColor: const Color(0xFFE4EEF0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2E7B86),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 92,
                        child: Text(
                          _fmtMoney(entry.value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTopUnitsBreakdown(List<Map<String, dynamic>> rows) {
    final grouped = _groupCount(rows, 'equipment_label').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _reportPanel(
      title: 'Unidades con mas intervencion',
      icon: Icons.local_shipping_outlined,
      child: grouped.isEmpty
          ? const Text('Sin unidades para mostrar.')
          : Column(
              children: grouped.take(6).map((entry) {
                final unitRows = rows
                    .where(
                      (row) =>
                          (row['equipment_label'] ?? '').toString().trim() ==
                          entry.key,
                    )
                    .toList();
                final cost = _sumOrderCost(unitRows, 'cost_actual_total');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FBFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4E7EA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.value} OT · ${_fmtMoney(cost)}',
                              style: const TextStyle(
                                color: Color(0xFF55757B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF76949A),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildUnitSpotlight(List<Map<String, dynamic>> rows) {
    final effectiveUnit =
        (_reportEquipmentFilters.length == 1
            ? _reportEquipmentFilters.first
            : null) ??
        (() {
          final grouped = _groupCount(rows, 'equipment_label').entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return grouped.isEmpty ? null : grouped.first.key;
        })();
    final unitRows = effectiveUnit == null
        ? <Map<String, dynamic>>[]
        : rows
              .where(
                (row) =>
                    (row['equipment_label'] ?? '').toString().trim() ==
                    effectiveUnit,
              )
              .toList();
    final mechanics = unitRows
        .map((row) => (row['mechanic_name'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    final totalReal = _sumOrderCost(unitRows, 'cost_actual_total');
    final totalEstimated = _sumOrderCost(unitRows, 'cost_estimated_total');
    final totalTasks = _countTasksForOrders(unitRows);
    final doneTasks = _countTasksForOrders(unitRows, onlyDone: true);
    final totalMaterials = _countMaterialsForOrders(unitRows);
    final impacts = _groupCount(unitRows, 'impact').entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final latestStatus = unitRows.isEmpty
        ? '-'
        : (_kStatusLabel[(unitRows.first['status'] ?? '').toString()] ??
              (unitRows.first['status'] ?? '-').toString());
    final latestDate = unitRows
        .map((row) => DateTime.tryParse((row['updated_at'] ?? '').toString()))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });

    return _reportPanel(
      title: 'Resumen por unidad',
      icon: Icons.precision_manufacturing_outlined,
      child: unitRows.isEmpty
          ? const Text(
              'Selecciona una unidad o ajusta filtros para ver su resumen.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effectiveUnit ?? 'Sin unidad',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryTag('OTs', '${unitRows.length}'),
                    _summaryTag('Mecanicos', '${mechanics.length}'),
                    _summaryTag('Costo real', _fmtMoney(totalReal)),
                    _summaryTag('Costo estimado', _fmtMoney(totalEstimated)),
                    _summaryTag('Impacto dominante', _labelForImpact(impacts)),
                    _summaryTag(
                      'Actividades',
                      '$totalTasks / $doneTasks hechas',
                    ),
                    _summaryTag('Materiales', '$totalMaterials'),
                    _summaryTag('Etapa actual', latestStatus),
                    _summaryTag(
                      'Ultimo movimiento',
                      latestDate == null ? '-' : _fmtDateTime(latestDate),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildMonthlyTrend(List<Map<String, dynamic>> rows) {
    final monthly = <String, int>{};
    for (final row in rows) {
      final dt = DateTime.tryParse((row['requested_at'] ?? '').toString());
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + 1;
    }
    final series = monthly.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _reportPanel(
      title: 'Tendencia por mes',
      icon: Icons.show_chart_rounded,
      child: series.isEmpty
          ? const Text('Sin historial suficiente.')
          : Column(
              children: series.take(8).map((entry) {
                final maxValue = series.fold<int>(
                  1,
                  (max, item) => item.value > max ? item.value : max,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3EEF1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: entry.value / maxValue,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF205C67),
                                    Color(0xFF83BEC3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDetailedReportTable(List<Map<String, dynamic>> rows) {
    final sortedRows = [...rows]
      ..sort((a, b) {
        final ad = DateTime.tryParse((a['requested_at'] ?? '').toString());
        final bd = DateTime.tryParse((b['requested_at'] ?? '').toString());
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    return _reportPanel(
      title: 'Detalle de trabajos',
      icon: Icons.table_rows_outlined,
      child: sortedRows.isEmpty
          ? const Text('No hay OTs con el filtro actual.')
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('OT / Unidad')),
                      Expanded(flex: 2, child: Text('Mecanico')),
                      Expanded(child: Text('Fecha')),
                      Expanded(child: Text('Responsable')),
                      Expanded(child: Text('Costo')),
                      Expanded(child: Text('Etapa')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...sortedRows.take(24).map((row) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.blueGrey.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (row['ot_folio'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${row['equipment_label'] ?? 'Sin unidad'} · ${row['area_label'] ?? 'Sin area'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5F7A80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((row['mechanic_name'] ?? '-').toString()),
                              const SizedBox(height: 2),
                              Text(
                                (row['mechanic_contact'] ?? '-').toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF67848A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _fmtDateTimeNullable(row['requested_at']),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            (row['assigned_to_name'] ?? '-').toString(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _fmtMoney(_toDouble(row['cost_actual_total']) ?? 0),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _kStatusLabel[(row['status'] ?? '').toString()] ??
                                (row['status'] ?? '').toString(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _exportCurrentReportCsv() async {
    if (_exportingReportCsv) return;
    final rows = _filteredReportOrders;
    if (rows.isEmpty) {
      _toast('No hay datos para exportar con el filtro actual');
      return;
    }

    setState(() => _exportingReportCsv = true);
    try {
      final totalMinutes = _totalMinutesForOrders(rows);
      final csvRows = <List<String>>[
        [
          'folio_ot',
          'mecanico',
          'contacto_mecanico',
          'unidad',
          'area',
          'tipo',
          'prioridad',
          'estatus',
          'fecha_solicitud',
          'responsable',
          'solicitante',
          'costo_estimado_total',
          'costo_real_total',
        ],
        ...rows.map(
          (row) => [
            (row['ot_folio'] ?? '').toString(),
            (row['mechanic_name'] ?? '').toString(),
            (row['mechanic_contact'] ?? '').toString(),
            (row['equipment_label'] ?? '').toString(),
            (row['area_label'] ?? '').toString(),
            _kTypeLabel[(row['type'] ?? '').toString()] ??
                (row['type'] ?? '').toString(),
            _kPriorityLabel[(row['priority'] ?? '').toString()] ??
                (row['priority'] ?? '').toString(),
            _kStatusLabel[(row['status'] ?? '').toString()] ??
                (row['status'] ?? '').toString(),
            _fmtDateTimeNullable(row['requested_at']),
            (row['assigned_to_name'] ?? '').toString(),
            (row['requester_name'] ?? '').toString(),
            (_toDouble(row['cost_estimated_total']) ?? 0).toStringAsFixed(2),
            (_toDouble(row['cost_actual_total']) ?? 0).toStringAsFixed(2),
          ],
        ),
        [
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'RESUMEN',
          '',
          '',
          '',
          _sumOrderCost(rows, 'cost_estimated_total').toStringAsFixed(2),
          _sumOrderCost(rows, 'cost_actual_total').toStringAsFixed(2),
        ],
        [
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'MINUTOS',
          '$totalMinutes',
          '',
          '',
          '',
          '',
        ],
      ];
      final csv = csvRows.map(_csvLine).join('\n');
      final suggestedName =
          'reporte_ot_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.csv';
      String? outputPath;
      if (!kIsWeb) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar reporte OT en CSV',
          fileName: suggestedName,
          allowedExtensions: const ['csv'],
          type: FileType.custom,
          lockParentWindow: true,
        );
      }
      if (outputPath == null || outputPath.trim().isEmpty) {
        _toast('Exportacion cancelada');
        return;
      }
      final normalized = outputPath.toLowerCase().endsWith('.csv')
          ? outputPath
          : '$outputPath.csv';
      await File(normalized).writeAsString(csv, flush: true);
      _toast('CSV guardado: $normalized');
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingReportCsv = false);
    }
  }

  Future<void> _exportCurrentReportPdf() async {
    if (_exportingReportPdf) return;
    final rows = _filteredReportOrders;
    if (rows.isEmpty) {
      _toast('No hay datos para exportar con el filtro actual');
      return;
    }

    setState(() => _exportingReportPdf = true);
    try {
      final doc = pw.Document();
      final now = DateTime.now();
      final totalReal = _sumOrderCost(rows, 'cost_actual_total');
      final totalEstimated = _sumOrderCost(rows, 'cost_estimated_total');
      final totalMinutes = _totalMinutesForOrders(rows);
      final totalTasks = _countTasksForOrders(rows);
      final totalDoneTasks = _countTasksForOrders(rows, onlyDone: true);
      final totalMaterials = _countMaterialsForOrders(rows);
      final closedCount = rows
          .where((row) => (row['status'] ?? '').toString() == 'cerrado')
          .length;
      final uniqueUnits = rows
          .map((row) => (row['equipment_label'] ?? '').toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .length;
      final averageCost = rows.isEmpty ? 0.0 : totalReal / rows.length;
      final mechanicBreakdown = _groupCount(
        rows,
        'mechanic_name',
      ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final statusBreakdown = _groupCount(rows, 'status').entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final impactBreakdown = _groupCount(rows, 'impact').entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final unitBreakdown = _groupCount(
        rows,
        'equipment_label',
      ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final monthlyMap = <String, int>{};
      for (final row in rows) {
        final dt = DateTime.tryParse((row['requested_at'] ?? '').toString());
        if (dt == null) continue;
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlyMap[key] = (monthlyMap[key] ?? 0) + 1;
      }
      final monthlyBreakdown = monthlyMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final detailRows = [...rows]
        ..sort((a, b) {
          final ad = DateTime.tryParse((a['requested_at'] ?? '').toString());
          final bd = DateTime.tryParse((b['requested_at'] ?? '').toString());
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
      final mechanicFilterLabel = _reportFilterSummaryLabel(
        _reportMechanicFilters,
        emptyLabel: 'Todos los mecanicos',
        pluralLabel: 'mecanicos',
      );
      final unitFilterLabel = _reportFilterSummaryLabel(
        _reportEquipmentFilters,
        emptyLabel: 'Todas las unidades',
        pluralLabel: 'unidades',
      );
      final areaFilterLabel = _reportFilterSummaryLabel(
        _reportAreaFilters,
        emptyLabel: 'Todas las areas',
        pluralLabel: 'areas',
      );
      final statusFilterLabel = _reportFilterSummaryLabel(
        _reportStatusFilters,
        emptyLabel: 'Todos los estatus',
        pluralLabel: 'estatus',
        labelBuilder: (value) => _kStatusLabel[value] ?? value,
      );
      final typeFilterLabel = _reportFilterSummaryLabel(
        _reportTypeFilters,
        emptyLabel: 'Todos los tipos',
        pluralLabel: 'tipos',
        labelBuilder: (value) => _kTypeLabel[value] ?? value,
      );
      final dateFilterLabel = _reportDateRange == null
          ? 'Historico completo'
          : _fmtReportDateRangeLabel();

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e, st) {
        AppErrorReporter.report(
          e,
          st,
          fallbackMessage: 'No se pudo cargar el logo para el PDF del reporte.',
        );
      }

      final filters = <MapEntry<String, String>>[
        MapEntry('Mecanico', mechanicFilterLabel),
        MapEntry('Unidad', unitFilterLabel),
        MapEntry('Area', areaFilterLabel),
        MapEntry('Estatus', statusFilterLabel),
        MapEntry('Tipo', typeFilterLabel),
        MapEntry('Rango', dateFilterLabel),
      ];

      final metrics = <MapEntry<String, String>>[
        MapEntry('OTs encontradas', '${rows.length}'),
        MapEntry('Unidades', '$uniqueUnits'),
        MapEntry('Costo estimado', _fmtMoney(totalEstimated)),
        MapEntry('Costo real', _fmtMoney(totalReal)),
        MapEntry('Ticket prom.', _fmtMoney(averageCost)),
        MapEntry('Horas', (totalMinutes / 60).toStringAsFixed(1)),
        MapEntry('Actividades', '$totalTasks/$totalDoneTasks'),
        MapEntry('Materiales', '$totalMaterials'),
        MapEntry('Cerradas', '$closedCount'),
      ];

      doc.addPage(
        pw.MultiPage(
          pageTheme: _reportPdfPageTheme(),
          build: (context) => [
            _reportPdfHeroCard(
              logoImage: logoImage,
              generatedAt: now,
              rowsCount: rows.length,
              totalReal: totalReal,
              dateFilterLabel: dateFilterLabel,
            ),
            _reportPdfMetricGrid(metrics),
            _reportPdfSection(
              title: 'Grafica por etapa',
              child: _reportPdfBarChart(
                statusBreakdown
                    .take(6)
                    .map(
                      (entry) => MapEntry(
                        _kStatusLabel[entry.key] ?? entry.key,
                        entry.value.toDouble(),
                      ),
                    )
                    .toList(),
                barColor: const PdfColor.fromInt(0xFF1F5B66),
                compact: true,
              ),
            ),
            _reportPdfSection(
              title: 'Distribucion por impacto',
              child: _reportPdfPieChart(
                impactBreakdown
                    .take(4)
                    .map(
                      (entry) => MapEntry(
                        _kImpactLabel[entry.key] ?? entry.key,
                        entry.value.toDouble(),
                      ),
                    )
                    .toList(),
              ),
            ),
            _reportPdfSection(
              title: 'Tendencia mensual',
              child: _reportPdfBarChart(
                monthlyBreakdown
                    .take(5)
                    .map((entry) => MapEntry(entry.key, entry.value.toDouble()))
                    .toList(),
                barColor: const PdfColor.fromInt(0xFF7AAFB5),
                compact: true,
              ),
            ),
            pw.NewPage(),
            _reportPdfSection(
              title: 'Filtros aplicados',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: filters
                    .map(
                      (entry) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '${entry.key}: ${entry.value}',
                          style: const pw.TextStyle(
                            fontSize: 9.2,
                            color: PdfColor.fromInt(0xFF284A51),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            _reportPdfTwoColumnSection(
              leftTitle: 'OTs por mecanico',
              leftChild: _reportPdfRankList(
                mechanicBreakdown
                    .take(8)
                    .map((entry) => MapEntry(entry.key, '${entry.value} OT'))
                    .toList(),
              ),
              rightTitle: 'Unidades con mas intervencion',
              rightChild: _reportPdfRankList(
                unitBreakdown
                    .take(6)
                    .map((entry) => MapEntry(entry.key, '${entry.value} OT'))
                    .toList(),
              ),
            ),
            _reportPdfModernTable(
              title: 'Detalle de trabajos (primeras 12 OT)',
              headers: const [
                'OT',
                'Unidad',
                'Mecanico',
                'Fecha',
                'Responsable',
                'Costo real',
                'Etapa',
              ],
              rows: detailRows
                  .take(12)
                  .map(
                    (row) => [
                      (row['ot_folio'] ?? '').toString(),
                      (row['equipment_label'] ?? 'Sin unidad').toString(),
                      (row['mechanic_name'] ?? '-').toString(),
                      _fmtDateTimeNullable(row['requested_at']),
                      (row['assigned_to_name'] ?? '-').toString(),
                      _fmtMoney(_toDouble(row['cost_actual_total']) ?? 0),
                      _kStatusLabel[(row['status'] ?? '').toString()] ??
                          (row['status'] ?? '').toString(),
                    ],
                  )
                  .toList(),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final suggestedName =
          'reporte_ot_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
      String? outputPath;
      if (!kIsWeb) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar reporte OT como PDF',
          fileName: suggestedName,
          allowedExtensions: const ['pdf'],
          type: FileType.custom,
          lockParentWindow: true,
        );
      }

      if (outputPath == null || outputPath.trim().isEmpty) {
        _toast('Exportacion cancelada');
        return;
      }

      final normalized = outputPath.toLowerCase().endsWith('.pdf')
          ? outputPath
          : '$outputPath.pdf';
      await File(normalized).writeAsBytes(bytes, flush: true);
      _toast('PDF guardado: $normalized');
    } catch (e) {
      _toast('No se pudo exportar PDF: $e');
    } finally {
      if (mounted) setState(() => _exportingReportPdf = false);
    }
  }

  Widget _reportPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5E6E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF205C67)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1E5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5E7E83),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Future<void> _showOtFlowGuide() async {
    const flow = <String>[
      'AVISO_FALLA',
      'REVISION_AREA',
      'REPORTE_MANTENIMIENTO',
      'COTIZACION',
      'AUTORIZACION_FINANZAS',
      'MATERIAL_RECOLECTADO',
      'PROGRAMADO',
      'MANTENIMIENTO_REALIZADO',
      'SUPERVISION',
      'CERRADO',
    ];

    await _showMaintenanceDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Flujo OT y proceso de llenado'),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Este modulo administra la OT completa: aviso, diagnostico, ejecucion, evidencia, aprobaciones y cierre. No es solo una lista de tickets.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Secuencia de estados',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: flow.asMap().entries.map((entry) {
                      return _flowStepChip(
                        number: entry.key + 1,
                        label: entry.value,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _guideBlock(
                    icon: Icons.post_add_rounded,
                    title: '1) Crear OT',
                    body:
                        'Crea la orden cuando existe una falla, solicitud o trabajo programado que debe quedar trazado. Aqui se captura el equipo, area, clasificacion y descripcion del problema.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.fact_check_rounded,
                    title: '2) Diagnosticar y documentar',
                    body:
                        'Antes de cerrar, la OT debe tener diagnostico claro, actividades realizadas, materiales usados y tiempos registrados. Eso convierte la OT en evidencia operativa, no solo administrativa.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.photo_library_rounded,
                    title: '3) Evidencias',
                    body:
                        'Sube fotos Antes, Durante y Despues cuando aplique. Las evidencias respaldan el trabajo realizado y ayudan a supervision o autorizacion.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.timeline_rounded,
                    title: '4) Cuando mover el estado',
                    body:
                        'El estado debe cambiar conforme avanza el trabajo real: aviso, revision, reporte, cotizacion, autorizacion, recoleccion de material, programacion, ejecucion, supervision y cierre. No se usa como semaforo decorativo.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.more_horiz_rounded,
                    title: '5) Acciones por OT',
                    body:
                        'Click derecho o boton ...: Guardar hoja, Editar estado, Descargar PDF, Evidencias o Eliminar. Guardar hoja persiste cambios del detalle; editar estado solo mueve la OT en el flujo.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.rule_rounded,
                    title: '6) Reglas de cierre',
                    body:
                        'No cierres una OT sin diagnostico, actividades capturadas y evidencia final cuando el trabajo lo requiera. Si faltan materiales o aprobaciones, la OT debe quedarse en el estado operativo correspondiente.',
                  ),
                  const SizedBox(height: 10),
                  _guideBlock(
                    icon: Icons.checklist_rounded,
                    title: '7) Secuencia recomendada',
                    body:
                        '1. Crear OT. 2. Seleccionar equipo y describir falla. 3. Diagnosticar. 4. Capturar actividades, materiales y tiempos. 5. Subir evidencias. 6. Mover estado segun avance real. 7. Cerrar solo cuando el trabajo este concluido y documentado.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: _maintenanceDialogOutlinedButtonStyle(),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _flowStepChip({required int number, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6BA8FF).withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0B72FF).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _guideBlock({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6BA8FF).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1C3E5D)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C3E5D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    final openStates = _orders.where((e) {
      final st = (e['status'] ?? '').toString();
      return st != 'cerrado' && st != 'rechazado';
    }).length;

    return Row(
      children: [
        _metricCard('Abiertas', '$openStates', Icons.inventory_2_rounded),
        const SizedBox(width: 8),
        _metricCard(
          'En proceso',
          '${_countStatus('programado') + _countStatus('mantenimiento_realizado')}',
          Icons.build_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Pend. aprobacion',
          '${_orders.where((o) => _pendingApprovalsByOt[(o['id'] ?? '').toString()] != null && (_pendingApprovalsByOt[(o['id'] ?? '').toString()] ?? 0) > 0).length}',
          Icons.approval_rounded,
        ),
        const SizedBox(width: 8),
        _metricCard(
          'Cerradas',
          '${_countStatus('cerrado')}',
          Icons.check_circle_rounded,
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Expanded(
      child: OperationalMetricCard(
        icon: icon,
        label: title,
        value: value,
        width: double.infinity,
        margin: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildOrdersTable() {
    final rows = _filteredOrders;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordenes de trabajo (${rows.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        onKeyEvent: (_, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            _moveOrderSelection(1);
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _moveOrderSelection(-1);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: _maintenanceInputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: 'Buscar OT/equipo/area/responsable',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter ?? 'all',
                        isExpanded: true,
                        isDense: true,
                        menuMaxHeight: 360,
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: const Color(0xFFF4FAF8),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Todos los estados'),
                          ),
                          ..._kStatusLabel.entries.map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _statusFilter = v == 'all' ? null : v,
                        ),
                        decoration: _maintenanceInputDecoration(isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Sin ordenes'))
                : Focus(
                    autofocus: true,
                    focusNode: _ordersListFocusNode,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (_isEditableFocused()) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        _moveOrderSelection(1);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        _moveOrderSelection(-1);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final id = (row['id'] ?? '').toString();
                        final selected = id == _selectedOrderId;
                        final hovering = id == _hoveredOrderId;
                        final highlighted = selected || hovering;
                        final evidenceCount = _evidenceCountByOt[id] ?? 0;
                        final pendingApprovals = _pendingApprovalsByOt[id] ?? 0;

                        final rowBg = selected
                            ? const Color(0xFF00A3FF).withValues(alpha: 0.15)
                            : hovering
                            ? const Color(0xFFE9F7EE)
                            : Colors.white;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: MouseRegion(
                            onEnter: (_) =>
                                setState(() => _hoveredOrderId = id),
                            onExit: (_) {
                              if (_hoveredOrderId == id) {
                                setState(() => _hoveredOrderId = null);
                              }
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _selectOrderByIndex(rows, index),
                              onSecondaryTapDown: (details) =>
                                  _openOrderContextMenu(index, details, rows),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                transform: Matrix4.translationValues(
                                  0,
                                  highlighted ? -1.2 : 0,
                                  0,
                                ),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  elevation: highlighted ? 3 : 0.4,
                                  color: rowBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(
                                              0xFF00A3FF,
                                            ).withValues(alpha: 0.58)
                                          : Colors.white.withValues(alpha: 0),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      10,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (row['ot_folio'] ?? '')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${row['equipment_label'] ?? 'Sin equipo'} · ${row['area_label'] ?? 'Sin area'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      Colors.blueGrey.shade800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_kStatusLabel[(row['status'] ?? '').toString()] ?? row['status']} · ${_kPriorityLabel[(row['priority'] ?? '').toString()] ?? ''}',
                                                style: TextStyle(
                                                  color:
                                                      Colors.blueGrey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Column(
                                          children: [
                                            IconButton(
                                              tooltip: 'Evidencias',
                                              onPressed: () =>
                                                  _openEvidenceModal(id),
                                              icon: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.photo_camera_outlined,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '$evidenceCount',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Builder(
                                              builder: (btnContext) {
                                                return Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.40,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.58,
                                                          ),
                                                    ),
                                                  ),
                                                  child: IconButton(
                                                    tooltip: 'Acciones OT',
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        _openOrderActionsFromButton(
                                                          id,
                                                          btnContext,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.more_horiz_rounded,
                                                      size: 18,
                                                      color: Color(0xFF0B2B2B),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (pendingApprovals > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFF3E0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFFB74D,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Aprob: $pendingApprovals',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
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
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSheet() {
    final order = _selectedOrder;
    if (order == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        alignment: Alignment.center,
        child: const Text('Selecciona una OT o crea una nueva'),
      );
    }

    final status = (order['status'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
      ),
      child: Scrollbar(
        controller: _detailScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _detailScrollController,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1150;
              final medium = constraints.maxWidth >= 860;
              const topHeight = 242.0;
              const middleHeight = 250.0;
              const costsHeight = 102.0;
              const approvalsHeight = 150.0;
              const evidenceHeight = 128.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Orden ${order['ot_folio'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStepper(status),
                  const SizedBox(height: 12),
                  if (wide) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _sectionWithIcon(
                            'Datos generales',
                            Icons.badge_outlined,
                            _buildGeneralSection(),
                            height: topHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Clasificacion',
                            Icons.rule_rounded,
                            _buildClassificationSection(),
                            height: topHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Descripcion / Diagnostico',
                            Icons.description_outlined,
                            _buildTextSections(),
                            height: topHeight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _sectionWithIcon(
                            'Actividades',
                            Icons.checklist_rounded,
                            _buildTasksSection(),
                            height: middleHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Materiales / Refacciones / Mano de obra',
                            Icons.handyman_rounded,
                            _buildMaterialsSection(),
                            height: middleHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Registro de tiempo',
                            Icons.av_timer_rounded,
                            _buildTimeSection(),
                            height: middleHeight,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _sectionWithIcon(
                            'Costos totales',
                            Icons.payments_outlined,
                            _buildCostsSection(),
                            height: costsHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            children: [
                              _sectionWithIcon(
                                'Aprobaciones',
                                Icons.fact_check_outlined,
                                _buildApprovalsSection(),
                                height: approvalsHeight,
                              ),
                              _sectionWithIcon(
                                'Evidencias',
                                Icons.photo_camera_outlined,
                                _buildEvidenceSection(),
                                height: evidenceHeight,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (medium) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _sectionWithIcon(
                            'Datos generales',
                            Icons.badge_outlined,
                            _buildGeneralSection(),
                            height: topHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Clasificacion',
                            Icons.rule_rounded,
                            _buildClassificationSection(),
                            height: topHeight,
                          ),
                        ),
                      ],
                    ),
                    _sectionWithIcon(
                      'Descripcion / Diagnostico',
                      Icons.description_outlined,
                      _buildTextSections(),
                      height: topHeight,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _sectionWithIcon(
                            'Actividades',
                            Icons.checklist_rounded,
                            _buildTasksSection(),
                            height: middleHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Materiales / Refacciones / Mano de obra',
                            Icons.handyman_rounded,
                            _buildMaterialsSection(),
                            height: middleHeight,
                          ),
                        ),
                      ],
                    ),
                    _sectionWithIcon(
                      'Registro de tiempo',
                      Icons.av_timer_rounded,
                      _buildTimeSection(),
                      height: middleHeight,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _sectionWithIcon(
                            'Costos totales',
                            Icons.payments_outlined,
                            _buildCostsSection(),
                            height: costsHeight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _sectionWithIcon(
                            'Aprobaciones',
                            Icons.fact_check_outlined,
                            _buildApprovalsSection(),
                            height: approvalsHeight,
                          ),
                        ),
                      ],
                    ),
                    _sectionWithIcon(
                      'Evidencias',
                      Icons.photo_camera_outlined,
                      _buildEvidenceSection(),
                      height: evidenceHeight,
                    ),
                  ] else ...[
                    _sectionWithIcon(
                      'Datos generales',
                      Icons.badge_outlined,
                      _buildGeneralSection(),
                    ),
                    _sectionWithIcon(
                      'Clasificacion',
                      Icons.rule_rounded,
                      _buildClassificationSection(),
                    ),
                    _sectionWithIcon(
                      'Descripcion / Diagnostico',
                      Icons.description_outlined,
                      _buildTextSections(),
                    ),
                    _sectionWithIcon(
                      'Actividades',
                      Icons.checklist_rounded,
                      _buildTasksSection(),
                    ),
                    _sectionWithIcon(
                      'Materiales / Refacciones / Mano de obra',
                      Icons.handyman_rounded,
                      _buildMaterialsSection(),
                    ),
                    _sectionWithIcon(
                      'Registro de tiempo',
                      Icons.av_timer_rounded,
                      _buildTimeSection(),
                    ),
                    _sectionWithIcon(
                      'Costos totales',
                      Icons.payments_outlined,
                      _buildCostsSection(),
                    ),
                    _sectionWithIcon(
                      'Aprobaciones',
                      Icons.fact_check_outlined,
                      _buildApprovalsSection(),
                    ),
                    _sectionWithIcon(
                      'Evidencias',
                      Icons.photo_camera_outlined,
                      _buildEvidenceSection(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(String status) {
    final activeIndex = _kStatusFlow.indexOf(status);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kStatusFlow.asMap().entries.map((entry) {
        final idx = entry.key;
        final key = entry.value;
        final done = activeIndex >= 0 && idx <= activeIndex;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: done ? const Color(0xFF1E4F80) : Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _kStatusLabel[key] ?? key,
            style: TextStyle(
              fontSize: 11,
              color: done ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String status) {
    final closed = status == 'cerrado';
    final rejected = status == 'rechazado';
    final color = rejected
        ? const Color(0xFFC62828)
        : closed
        ? const Color(0xFF2E7D32)
        : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _kStatusLabel[status] ?? status,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _sectionWithIcon(
    String title,
    IconData icon,
    Widget child, {
    double? height,
  }) {
    final content = height == null
        ? child
        : SizedBox(
            height: height,
            child: SingleChildScrollView(primary: false, child: child),
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0F4B8F)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildCostsSection() {
    final estTotal = _materials.fold<double>(
      0,
      (sum, e) => sum + (_toDouble(e['cost_estimated']) ?? 0),
    );
    final realTotal = _materials.fold<double>(
      0,
      (sum, e) => sum + (_toDouble(e['cost_actual']) ?? 0),
    );
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6BA8FF).withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Estimado: ${_fmtMoney(estTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6BA8FF).withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Real: ${_fmtMoney(realTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSection() {
    final requestedAt = _fmtDateTimeNullable(_selectedOrder?['requested_at']);
    final selectedArea = _kFixedAreas.contains(_areaC.text.trim().toUpperCase())
        ? _areaC.text.trim().toUpperCase()
        : _kFixedAreas.first;
    if (_areaC.text != selectedArea) {
      _areaC.text = selectedArea;
    }

    final vehicleOptions = _vehicleCatalog
        .map(
          (v) => DropdownMenuItem<String>(
            value: (v['id'] ?? '').toString(),
            child: Text((v['code'] ?? '').toString()),
          ),
        )
        .toList();

    if (_selectedVehicleId != null &&
        _selectedVehicleId!.isNotEmpty &&
        !_vehicleCatalog.any(
          (v) => (v['id'] ?? '').toString() == _selectedVehicleId,
        )) {
      _selectedVehicleId = null;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedArea,
                isExpanded: true,
                menuMaxHeight: 360,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: const Color(0xFFF4FAF8),
                items: _kFixedAreas
                    .map(
                      (a) => DropdownMenuItem<String>(value: a, child: Text(a)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _areaC.text = v);
                  _scheduleAutosave();
                },
                decoration: _maintenanceInputDecoration(labelText: 'Area'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedVehicleId,
                isExpanded: true,
                menuMaxHeight: 360,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: const Color(0xFFF4FAF8),
                items: vehicleOptions,
                onChanged: (v) {
                  setState(() {
                    _selectedVehicleId = v;
                    final match = _vehicleCatalog
                        .cast<Map<String, dynamic>?>()
                        .firstWhere(
                          (e) => (e?['id'] ?? '').toString() == v,
                          orElse: () => null,
                        );
                    _equipmentC.text = (match?['code'] ?? '').toString();
                    _serialC.text = (match?['serial_number'] ?? '').toString();
                  });
                  _scheduleAutosave();
                },
                decoration: _maintenanceInputDecoration(
                  labelText: 'Equipo (unidades)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _serialC,
                decoration: _maintenanceInputDecoration(labelText: 'Serie'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _requesterC,
                decoration: _maintenanceInputDecoration(
                  labelText: 'Solicitante',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _assignedToC,
                decoration: _maintenanceInputDecoration(
                  labelText: 'Responsable',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _readOnlyInfoField(
                label: 'Fecha solicitud',
                value: requestedAt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mechanicNameC,
                decoration: _maintenanceInputDecoration(labelText: 'Mecanico'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mechanicContactC,
                keyboardType: TextInputType.phone,
                decoration: _maintenanceInputDecoration(
                  labelText: 'Contacto mecanico',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassificationSection() {
    return Column(
      children: [
        _classificationRow(
          'Tipo',
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            menuMaxHeight: 360,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: const Color(0xFFF4FAF8),
            items: _kTypeLabel.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _type = v);
              _scheduleAutosave();
            },
            decoration: _maintenanceInputDecoration(),
          ),
        ),
        const SizedBox(height: 6),
        _classificationRow(
          'Prioridad',
          DropdownButtonFormField<String>(
            initialValue: _priority,
            isExpanded: true,
            menuMaxHeight: 360,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: const Color(0xFFF4FAF8),
            items: _kPriorityLabel.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _priority = v);
              _scheduleAutosave();
            },
            decoration: _maintenanceInputDecoration(),
          ),
        ),
        const SizedBox(height: 6),
        _classificationRow(
          'Categoria',
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            menuMaxHeight: 360,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: const Color(0xFFF4FAF8),
            items: _kCategoryLabel.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _category = v);
              _scheduleAutosave();
            },
            decoration: _maintenanceInputDecoration(),
          ),
        ),
        const SizedBox(height: 6),
        _classificationRow(
          'Impacto',
          DropdownButtonFormField<String>(
            initialValue: _impact,
            isExpanded: true,
            menuMaxHeight: 360,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: const Color(0xFFF4FAF8),
            items: _kImpactLabel.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _impact = v);
              _scheduleAutosave();
            },
            decoration: _maintenanceInputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _classificationRow(String label, Widget field) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: field),
      ],
    );
  }

  Widget _readOnlyInfoField({required String label, required String value}) {
    return InputDecorator(
      decoration: _maintenanceInputDecoration(labelText: label),
      child: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextSections() {
    return Column(
      children: [
        TextField(
          controller: _descriptionC,
          minLines: 3,
          maxLines: 5,
          decoration: _maintenanceInputDecoration(
            labelText: 'Descripcion del problema',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _diagnosisC,
          minLines: 3,
          maxLines: 5,
          decoration: _maintenanceInputDecoration(labelText: 'Diagnostico'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _summaryC,
          minLines: 2,
          maxLines: 4,
          decoration: _maintenanceInputDecoration(
            labelText: 'Resumen de trabajo',
          ),
        ),
      ],
    );
  }

  Widget _buildTasksSection() {
    return Column(
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _addTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar actividad'),
            ),
            const SizedBox(width: 8),
            Text('Total: ${_tasks.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (_tasks.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sin actividades'),
          ),
        ..._tasks.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text((row['description'] ?? '').toString()),
              subtitle: Text(
                'Cant: ${(row['qty'] ?? '').toString()} · Unidad: ${(row['unit'] ?? '').toString()} · ${row['is_done'] == true ? 'Hecho' : 'Pendiente'}',
              ),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: () => _editTask(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _tasks.removeAt(i));
                      _scheduleAutosave(immediate: true);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMaterialsSection() {
    final estTotal = _materials.fold<double>(
      0,
      (sum, e) => sum + (_toDouble(e['cost_estimated']) ?? 0),
    );
    final realTotal = _materials.fold<double>(
      0,
      (sum, e) => sum + (_toDouble(e['cost_actual']) ?? 0),
    );

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _addMaterial,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar material'),
            ),
            Text(
              'Estimado: ${_fmtMoney(estTotal)} · Real: ${_fmtMoney(realTotal)}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_materials.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sin materiales'),
          ),
        ..._materials.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text((row['name'] ?? '').toString()),
              subtitle: Text(
                'Cant: ${(row['qty'] ?? '').toString()} · Fuente: ${_materialSourceLabel((row['source'] ?? '').toString())} · Est: ${_fmtMoney(_toDouble(row['cost_estimated']) ?? 0)} · Real: ${_fmtMoney(_toDouble(row['cost_actual']) ?? 0)}',
              ),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: () => _editMaterial(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _materials.removeAt(i));
                      _scheduleAutosave(immediate: true);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _addTimeLog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar tiempo'),
            ),
            const SizedBox(width: 8),
            Text('Registros: ${_timeLogs.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (_timeLogs.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sin tiempos'),
          ),
        ..._timeLogs.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final start = DateTime.tryParse((row['start_at'] ?? '').toString());
          final end = DateTime.tryParse((row['end_at'] ?? '').toString());
          final mins = (start != null && end != null)
              ? end.difference(start).inMinutes.clamp(0, 100000)
              : 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(
                (row['tech_name'] ?? '').toString().isEmpty
                    ? 'Sin tecnico'
                    : (row['tech_name'] ?? '').toString(),
              ),
              subtitle: Text(
                '${start == null ? '-' : _fmtDateTime(start)} -> ${end == null ? '-' : _fmtDateTime(end)} · $mins min',
              ),
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    onPressed: () => _editTimeLog(i),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _timeLogs.removeAt(i));
                      _scheduleAutosave(immediate: true);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    final orderId =
        _selectedOrderId ?? (_selectedOrder?['id'] ?? '').toString();
    final grouped = <String, int>{};
    for (final row in _evidences) {
      final key = (row['category'] ?? 'otros').toString();
      grouped[key] = (grouped[key] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kEvidenceCategoryLabel.entries
              .map(
                (e) => Chip(label: Text('${e.value}: ${grouped[e.key] ?? 0}')),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: orderId.isEmpty ? null : () => _addEvidence(orderId),
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Agregar evidencia'),
        ),
      ],
    );
  }

  Widget _buildApprovalsSection() {
    return Column(
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _addApproval,
              icon: const Icon(Icons.approval_rounded),
              label: const Text('Registrar aprobacion'),
            ),
            const SizedBox(width: 8),
            Text('Registros: ${_approvals.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (_approvals.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sin aprobaciones'),
          ),
        ..._approvals.map((row) {
          final st = (row['status'] ?? '').toString();
          final color = st == 'aprobada'
              ? Colors.green
              : st == 'rechazada'
              ? Colors.red
              : Colors.orange;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(
                '${_kApprovalStepLabel[(row['step'] ?? '').toString()] ?? (row['step'] ?? '').toString()} · $st',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color.shade700,
                ),
              ),
              subtitle: Text(
                '${row['by_user_name'] ?? 'N/A'} · ${_fmtDateTimeNullable(row['at'])}\n${row['comment'] ?? ''}',
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _DonutSegment {
  const _DonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.segments});

  final List<_DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.value,
    );
    if (total <= 0) return;

    final strokeWidth = size.width * 0.18;
    final rect = Offset.zero & size;
    var startAngle = -90 * (3.1415926535897932 / 180.0);

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 3.1415926535897932 * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i].value != segments[i].value ||
          oldDelegate.segments[i].color != segments[i].color) {
        return true;
      }
    }
    return false;
  }
}

String _fmtDateTime(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$mi';
}

String _fmtDateTimeNullable(dynamic raw) {
  final dt = DateTime.tryParse((raw ?? '').toString());
  if (dt == null) return '-';
  return _fmtDateTime(dt);
}

String _labelForImpact(List<MapEntry<String, int>> impacts) {
  if (impacts.isEmpty) return '-';
  final key = impacts.first.key;
  return _kImpactLabel[key] ?? key;
}

String _csvLine(List<String> values) {
  return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
}

Future<T?> _showMaintenanceDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return Theme(
        data: Theme.of(dialogContext).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF4FAF8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.92),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF6BA8FF).withValues(alpha: 0.34),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF6BA8FF).withValues(alpha: 0.34),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF0B72FF).withValues(alpha: 0.84),
                width: 1.2,
              ),
            ),
          ),
        ),
        child: builder(dialogContext),
      );
    },
  );
}

Future<DateTime?> _showMaintenanceDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  DateTime selected = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  return _showMaintenanceDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Seleccionar fecha'),
        content: SizedBox(
          width: 360,
          child: CalendarDatePicker(
            initialDate: selected,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: (v) => selected = v,
          ),
        ),
        actions: [
          OutlinedButton(
            style: _maintenanceDialogOutlinedButtonStyle(),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: _maintenanceDialogFilledButtonStyle(),
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: const Text('Aceptar'),
          ),
        ],
      );
    },
  );
}

Future<TimeOfDay?> _showMaintenanceTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: kOperationalMetricAccent,
            onPrimary: Colors.white,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF4FAF8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

Future<_MaintenanceDateFilterDialogResult?>
_showMaintenanceReportDateRangeDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_MaintenanceDateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? DateTime.now()).year,
        (initialRange?.start ?? DateTime.now()).month,
      );
      DateTime? start = initialRange?.start;
      DateTime? end = initialRange?.end;
      DateTime? hover;

      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
      bool withinBounds(DateTime day) {
        final d = dateOnly(day);
        return !d.isBefore(dateOnly(bounds.start)) &&
            !d.isAfter(dateOnly(bounds.end));
      }

      String monthNameEs(int month) {
        const months = <String>[
          'enero',
          'febrero',
          'marzo',
          'abril',
          'mayo',
          'junio',
          'julio',
          'agosto',
          'septiembre',
          'octubre',
          'noviembre',
          'diciembre',
        ];
        return months[(month - 1).clamp(0, 11)];
      }

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final rangePreviewEnd = end ?? hover;

          _MaintenanceDateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _MaintenanceDateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: _maintenanceFilterDialogDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtro: $label',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2B2B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setLocalState(() {
                                  displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month - 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '${monthNameEs(monthFirst.month)[0].toUpperCase()}${monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setLocalState(() {
                                  displayMonth = DateTime(
                                    displayMonth.year,
                                    displayMonth.month + 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Expanded(child: Center(child: Text('L'))),
                            Expanded(child: Center(child: Text('M'))),
                            Expanded(child: Center(child: Text('M'))),
                            Expanded(child: Center(child: Text('J'))),
                            Expanded(child: Center(child: Text('V'))),
                            Expanded(child: Center(child: Text('S'))),
                            Expanded(child: Center(child: Text('D'))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 250,
                          child: Column(
                            children: List.generate(6, (row) {
                              return Expanded(
                                child: Row(
                                  children: List.generate(7, (col) {
                                    final day = gridStart.add(
                                      Duration(days: row * 7 + col),
                                    );
                                    final inMonth =
                                        day.month == displayMonth.month;
                                    final allowed = withinBounds(day);
                                    final selectedStart =
                                        start != null && isSameDay(day, start!);
                                    final selectedEnd =
                                        end != null && isSameDay(day, end!);
                                    final inRange = inPreviewRange(day);
                                    final active = selectedStart || selectedEnd;
                                    final bgColor = active
                                        ? const Color(0xFF4F8E8C)
                                        : inRange
                                        ? const Color(0xFFE2EEEC)
                                        : Colors.transparent;
                                    final txtColor = active
                                        ? Colors.white
                                        : !allowed
                                        ? Colors.black38
                                        : inMonth
                                        ? const Color(0xFF0B2B2B)
                                        : Colors.black54;

                                    return Expanded(
                                      child: MouseRegion(
                                        onEnter: (_) {
                                          if (start != null &&
                                              end == null &&
                                              allowed) {
                                            setLocalState(() => hover = day);
                                          }
                                        },
                                        onExit: (_) {
                                          if (hover != null) {
                                            setLocalState(() => hover = null);
                                          }
                                        },
                                        child: GestureDetector(
                                          onTap: !allowed
                                              ? null
                                              : () {
                                                  setLocalState(() {
                                                    final picked = dateOnly(
                                                      day,
                                                    );
                                                    if (start == null ||
                                                        (start != null &&
                                                            end != null)) {
                                                      start = picked;
                                                      end = null;
                                                    } else {
                                                      end = picked;
                                                    }
                                                  });
                                                },
                                          child: Container(
                                            margin: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: active
                                                    ? const Color(0xFF4F8E8C)
                                                    : inRange
                                                    ? const Color(0xFFB6D9D5)
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${day.day}',
                                              style: TextStyle(
                                                fontWeight: active
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: txtColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: _maintenanceFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: _maintenanceFilterOutlinedButtonStyle(),
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                const _MaintenanceDateFilterDialogResult(
                                  clear: true,
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: _maintenanceFilterFilledButtonStyle(),
                              onPressed: () {
                                final result = buildApplyResult();
                                if (result != null) {
                                  Navigator.pop(dialogContext, result);
                                }
                              },
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
      );
    },
  );
}

InputDecoration _maintenanceInputDecoration({
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  bool isDense = false,
}) {
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    isDense: isDense,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.34),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: const Color(0xFF6BA8FF).withValues(alpha: 0.45),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: const Color(0xFF6BA8FF).withValues(alpha: 0.45),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: const Color(0xFF0B72FF).withValues(alpha: 0.84),
        width: 1.2,
      ),
    ),
  );
}

ButtonStyle _maintenanceDialogFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
  );
}

ButtonStyle _maintenanceDialogOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withValues(alpha: 0.25)),
    backgroundColor: Colors.white.withValues(alpha: 0.40),
  );
}

BoxDecoration _maintenanceFilterDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.62),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
  );
}

ButtonStyle _maintenanceFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withValues(alpha: 0.25)),
    backgroundColor: Colors.white.withValues(alpha: 0.40),
  );
}

ButtonStyle _maintenanceFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
  );
}

ButtonStyle _maintenanceActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withValues(alpha: 0.34),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.28),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 1.5;
      if (states.contains(WidgetState.hovered)) return 6;
      return 0;
    }),
  );
}

ButtonStyle _maintenanceActionFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.30),
  ).copyWith(
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return 0;
      if (states.contains(WidgetState.pressed)) return 1.5;
      if (states.contains(WidgetState.hovered)) return 6;
      return 0;
    }),
  );
}

String _fmtMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  return '\$$fixed';
}

String _materialSourceLabel(String key) {
  final normalized = key.trim().toLowerCase();
  return _kMaterialSourceLabel[normalized] ?? key;
}

double? _toDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final txt = raw.toString().trim().replaceAll(',', '');
  if (txt.isEmpty) return null;
  return double.tryParse(txt);
}

String? _emptyAsNull(dynamic value) {
  if (value == null) return null;
  final txt = value.toString().trim();
  return txt.isEmpty ? null : txt;
}

bool _looksLikeImageUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('.png') ||
      u.contains('.jpg') ||
      u.contains('.jpeg') ||
      u.contains('.webp') ||
      u.contains('.gif') ||
      u.contains('/storage/v1/object/public/');
}
