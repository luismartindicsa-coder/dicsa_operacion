import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_delete_confirm_dialog.dart';
import 'menudeo_demo_mode.dart';
import 'menudeo_filter_widgets.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_metric_card.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_tickets_page.dart';
import 'menudeo_theme.dart';

class MenudeoDepositsExpensesPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoDepositsExpensesPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoDepositsExpensesPage> createState() =>
      _MenudeoDepositsExpensesPageState();
}

enum _VoucherType { deposit, expense }

enum _VoucherGridMenuAction { open, deleteSelection }

class _VoucherDialogResult {
  final _VoucherRecord? record;
  final int navigateDelta;

  const _VoucherDialogResult.save(this.record) : navigateDelta = 0;
  const _VoucherDialogResult.navigate(this.navigateDelta) : record = null;
}

final Object _kVoucherSelectionTapRegionGroup = Object();

const TextStyle _kVoucherMenuTextStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: Color(0xFF2D2A28),
  letterSpacing: 0.2,
);

Widget _voucherPopupMenuItemChild({
  required IconData icon,
  required String label,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF8E3F2A)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: _kVoucherMenuTextStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

List<PopupMenuEntry<_VoucherGridMenuAction>> _buildVoucherMenuItems({
  required int selectedCount,
}) {
  return <PopupMenuEntry<_VoucherGridMenuAction>>[
    PopupMenuItem<_VoucherGridMenuAction>(
      value: _VoucherGridMenuAction.open,
      child: _voucherPopupMenuItemChild(
        icon: Icons.open_in_new_rounded,
        label: 'Abrir voucher',
      ),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<_VoucherGridMenuAction>(
      value: _VoucherGridMenuAction.deleteSelection,
      child: _voucherPopupMenuItemChild(
        icon: Icons.delete_outline_rounded,
        label: selectedCount > 1 ? 'Eliminar selección' : 'Eliminar voucher',
      ),
    ),
  ];
}

class _ConceptConfig {
  final String label;
  final bool requiresUnit;
  final bool requiresQuantity;
  final bool requiresCompany;
  final bool requiresDriver;
  final bool requiresDestination;
  final bool requiresSubconcept;
  final bool requiresMode;
  final List<String> subconcepts;
  final List<String> modes;

  const _ConceptConfig({
    required this.label,
    this.requiresUnit = false,
    this.requiresQuantity = false,
    this.requiresCompany = false,
    this.requiresDriver = false,
    this.requiresDestination = false,
    this.requiresSubconcept = false,
    this.requiresMode = false,
    this.subconcepts = const <String>[],
    this.modes = const <String>[],
  });
}

class _LineItemRecord {
  final String concept;
  final String unit;
  final String quantity;
  final String company;
  final String driver;
  final String destination;
  final String subconcept;
  final String mode;
  final String amount;
  final String comment;

  const _LineItemRecord({
    required this.concept,
    required this.unit,
    required this.quantity,
    required this.company,
    required this.driver,
    required this.destination,
    required this.subconcept,
    required this.mode,
    required this.amount,
    required this.comment,
  });
}

class _VoucherRecord {
  final String? id;
  final String folio;
  final String date;
  final _VoucherType type;
  final String person;
  final String rubric;
  final String comment;
  final List<_LineItemRecord> lines;

  const _VoucherRecord({
    this.id,
    required this.folio,
    required this.date,
    required this.type,
    required this.person,
    required this.rubric,
    required this.comment,
    required this.lines,
  });

  double get total => lines.fold<double>(
    0,
    (sum, line) => sum + (double.tryParse(line.amount) ?? 0),
  );

  String get conceptsPreview {
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first.concept;
    return '${lines.first.concept} +${lines.length - 1}';
  }

  String get selectionKey => id ?? '$folio|$date|${type.name}';
}

class _LineItemDraft {
  String concept = '';
  String unit = '';
  String quantity = '';
  String company = '';
  String driver = '';
  String destination = '';
  String subconcept = '';
  String mode = '';
  final TextEditingController amountC = TextEditingController();
  final TextEditingController commentC = TextEditingController();

  void dispose() {
    amountC.dispose();
    commentC.dispose();
  }

  _LineItemRecord toRecord() {
    return _LineItemRecord(
      concept: concept,
      unit: unit,
      quantity: quantity,
      company: company,
      driver: driver,
      destination: destination,
      subconcept: subconcept,
      mode: mode,
      amount: amountC.text.trim(),
      comment: commentC.text.trim(),
    );
  }

  static _LineItemDraft fromRecord(_LineItemRecord record) {
    final draft = _LineItemDraft();
    draft.concept = record.concept;
    draft.unit = record.unit;
    draft.quantity = record.quantity;
    draft.company = record.company;
    draft.driver = record.driver;
    draft.destination = record.destination;
    draft.subconcept = record.subconcept;
    draft.mode = record.mode;
    draft.amountC.text = record.amount;
    draft.commentC.text = record.comment;
    return draft;
  }
}

const Map<_VoucherType, Map<String, List<_ConceptConfig>>> _voucherConfig =
    <_VoucherType, Map<String, List<_ConceptConfig>>>{
      _VoucherType.deposit: <String, List<_ConceptConfig>>{
        'Venta de material': <_ConceptConfig>[_ConceptConfig(label: 'Ingreso')],
        'Reposición de fondo': <_ConceptConfig>[
          _ConceptConfig(label: 'Bóveda'),
          _ConceptConfig(label: 'Caja grande'),
        ],
        'Servicio de transporte': <_ConceptConfig>[
          _ConceptConfig(label: 'Compra de material'),
          _ConceptConfig(label: 'Venta de material'),
        ],
      },
      _VoucherType.expense: <String, List<_ConceptConfig>>{
        'Operativo': <_ConceptConfig>[
          _ConceptConfig(
            label: 'Combustible',
            requiresUnit: true,
            requiresQuantity: true,
          ),
          _ConceptConfig(
            label: 'Mantenimiento',
            requiresUnit: true,
            requiresSubconcept: true,
            subconcepts: <String>[
              'Talacha',
              'Luz',
              'Espejos',
              'Llantas',
              'Mangueras',
              'Electricidad',
              'Mecánica',
            ],
          ),
          _ConceptConfig(label: 'Comisiones'),
          _ConceptConfig(
            label: 'Báscula',
            requiresCompany: true,
            requiresDriver: true,
          ),
          _ConceptConfig(
            label: 'Gratificación',
            requiresDriver: true,
            requiresDestination: true,
          ),
          _ConceptConfig(
            label: 'Cena',
            requiresDriver: true,
            requiresDestination: true,
          ),
          _ConceptConfig(
            label: 'Equipo',
            requiresSubconcept: true,
            requiresQuantity: true,
            subconcepts: <String>[
              'Guantes',
              'Lentes',
              'Chalecos',
              'Tapones',
              'Uniformes',
              'Zapatos',
              'Extintores',
              'Cables',
              'Almacén',
              'Tanques',
              'Agujas',
            ],
          ),
          _ConceptConfig(
            label: 'Flete',
            requiresDestination: true,
            requiresMode: true,
            modes: <String>['Full', 'Sencillo'],
          ),
          _ConceptConfig(
            label: 'Viajes',
            requiresSubconcept: true,
            subconcepts: <String>[
              'Comida',
              'Caseta',
              'Combustible',
              'Estacionamiento',
              'Tránsito',
            ],
          ),
          _ConceptConfig(label: 'Oxígeno', requiresQuantity: true),
        ],
        'Administrativo': <_ConceptConfig>[
          _ConceptConfig(
            label: 'Papelería',
            requiresSubconcept: true,
            requiresQuantity: true,
            subconcepts: <String>[
              'Plumas',
              'Lápices',
              'Plumones',
              'Borradores',
              'Post-its',
              'Hojas',
              'Pegamento',
              'Tijeras',
              'Calculadora',
              'USB',
              'Engrapadora',
              'Grapas',
              'Sobres',
            ],
          ),
          _ConceptConfig(
            label: 'Mantenimiento',
            requiresSubconcept: true,
            subconcepts: <String>[
              'Impresoras',
              'Computadoras',
              'Teléfonos',
              'Oficina',
            ],
          ),
          _ConceptConfig(label: 'Remodelación'),
        ],
        'Nómina': <_ConceptConfig>[
          _ConceptConfig(
            label: 'Empresa',
            requiresSubconcept: true,
            subconcepts: <String>['Whirlpool', 'KS', 'Monroe'],
          ),
          _ConceptConfig(label: 'Préstamo'),
        ],
        'Personales': <_ConceptConfig>[
          _ConceptConfig(label: 'Comida'),
          _ConceptConfig(label: 'Gasolina'),
          _ConceptConfig(label: 'Casetas'),
        ],
      },
    };

const List<String> _voucherDestinations = <String>[
  'De Acero',
  'Grupak',
  'San Pablo',
  'San Luis',
  'Jaime Velázquez',
  'TDF',
  'Morelia',
  'Querétaro',
  'Queretania',
];

class _MenudeoDepositsExpensesPageState
    extends State<MenudeoDepositsExpensesPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final ScrollController _voucherRowsScrollC = ScrollController();
  final GlobalKey _voucherRowsViewportKey = GlobalKey();
  DateTimeRange? _voucherDateFilter;
  Set<String> _voucherFolioFilter = <String>{};
  Set<String> _voucherTypeFilter = <String>{};
  Set<String> _voucherPersonFilter = <String>{};
  Set<String> _voucherRubricFilter = <String>{};
  Set<String> _voucherConceptFilter = <String>{};
  final Set<String> _selectedVoucherKeys = <String>{};
  String? _activeVoucherKey;
  String? _voucherSelectionAnchorKey;
  bool _dragSelectingRows = false;
  Offset? _dragPointerLocal;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;
  bool _pointerDownAdditiveSelection = false;
  bool _suppressNextRowTap = false;
  bool _menuOpen = false;
  bool _loadingRows = true;
  bool _exportingCsv = false;
  int _currentPage = 0;
  int _pageSize = 40;
  int _folioSequence = 18420;
  List<String> _unitOptions = <String>[];
  List<String> _companyOptions = <String>[];
  List<String> _driverOptions = <String>[];
  final List<_VoucherRecord> _rows = <_VoucherRecord>[];

  @override
  void initState() {
    super.initState();
    unawaited(HardwareKeyboard.instance.syncKeyboardState());
    unawaited(_loadVouchers());
    unawaited(_loadCatalogOptions());
  }

  @override
  void dispose() {
    _dragAutoScrollTimer?.cancel();
    _voucherRowsScrollC.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        _supa
            .from('sites')
            .select('id,name,type')
            .eq('type', 'cliente')
            .eq('is_active', true)
            .order('name'),
        _supa
            .from('employees')
            .select('id,full_name')
            .eq('is_driver', true)
            .eq('is_active', true)
            .order('full_name'),
        _supa
            .from('vehicles')
            .select('id,code,status')
            .eq('status', 'activo')
            .order('code'),
      ]);

      if (!mounted) return;
      setState(() {
        _companyOptions =
            ((results[0] as List).cast<Map<String, dynamic>>())
                .map((row) => (row['name'] ?? '').toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        _driverOptions =
            ((results[1] as List).cast<Map<String, dynamic>>())
                .map((row) => (row['full_name'] ?? '').toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        _unitOptions =
            ((results[2] as List).cast<Map<String, dynamic>>())
                .map((row) => (row['code'] ?? '').toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar unidades, choferes y empresas desde Operación: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadVouchers() async {
    if (mounted) setState(() => _loadingRows = true);
    if (kMenudeoForceDemoMode) {
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(_buildMockVoucherRows());
        _loadingRows = false;
      });
      return;
    }
    try {
      final voucherRows = await _supa
          .from('vw_men_cash_vouchers_grid')
          .select('*')
          .order('voucher_date', ascending: false)
          .order('folio_sort', ascending: false)
          .order('folio', ascending: false);

      final vouchers = (voucherRows as List).cast<Map<String, dynamic>>();
      final ids = vouchers
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      Map<String, List<_LineItemRecord>> linesByVoucher =
          <String, List<_LineItemRecord>>{};
      if (ids.isNotEmpty) {
        final lineRows = await _supa
            .from('men_cash_voucher_lines')
            .select(
              'voucher_id,line_order,concept,unit,quantity,company,driver,destination,subconcept,mode,amount,comment',
            )
            .inFilter('voucher_id', ids)
            .order('line_order');
        for (final raw in (lineRows as List).cast<Map<String, dynamic>>()) {
          final voucherId = (raw['voucher_id'] ?? '').toString();
          if (voucherId.isEmpty) continue;
          linesByVoucher
              .putIfAbsent(voucherId, () => <_LineItemRecord>[])
              .add(
                _LineItemRecord(
                  concept: (raw['concept'] ?? '').toString(),
                  unit: (raw['unit'] ?? '').toString(),
                  quantity: (raw['quantity'] ?? '').toString(),
                  company: (raw['company'] ?? '').toString(),
                  driver: (raw['driver'] ?? '').toString(),
                  destination: (raw['destination'] ?? '').toString(),
                  subconcept: (raw['subconcept'] ?? '').toString(),
                  mode: (raw['mode'] ?? '').toString(),
                  amount: (raw['amount'] ?? '0').toString(),
                  comment: (raw['comment'] ?? '').toString(),
                ),
              );
        }
      }

      int nextSequence = _folioSequence;
      final mappedRows = vouchers
          .map((row) {
            final folio = (row['folio'] ?? '').toString();
            final numericFolio = int.tryParse(
              folio.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            if (numericFolio != null && numericFolio > nextSequence) {
              nextSequence = numericFolio;
            }
            final rawDate = DateTime.tryParse(
              (row['voucher_date'] ?? '').toString(),
            );
            final date = rawDate == null
                ? (row['voucher_date'] ?? '').toString()
                : '${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year}';
            final type = ((row['voucher_type'] ?? '').toString() == 'deposit')
                ? _VoucherType.deposit
                : _VoucherType.expense;
            final id = (row['id'] ?? '').toString();
            return _VoucherRecord(
              id: id.isEmpty ? null : id,
              folio: folio,
              date: date,
              type: type,
              person: (row['person_label'] ?? '').toString(),
              rubric: (row['rubric'] ?? '').toString(),
              comment: (row['comment'] ?? '').toString(),
              lines: linesByVoucher[id] ?? const <_LineItemRecord>[],
            );
          })
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(mappedRows.isEmpty ? _buildMockVoucherRows() : mappedRows);
        _folioSequence = nextSequence;
        _loadingRows = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(_buildMockVoucherRows());
        _loadingRows = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar depósitos y gastos reales. Se muestran vouchers demo para probar el flujo: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<_VoucherRecord> _buildMockVoucherRows() {
    _LineItemRecord line({
      required String concept,
      String unit = '',
      String quantity = '',
      String company = '',
      String driver = '',
      String destination = '',
      String subconcept = '',
      String mode = '',
      required String amount,
      String comment = '',
    }) {
      return _LineItemRecord(
        concept: concept,
        unit: unit,
        quantity: quantity,
        company: company,
        driver: driver,
        destination: destination,
        subconcept: subconcept,
        mode: mode,
        amount: amount,
        comment: comment,
      );
    }

    final rows = <_VoucherRecord>[
      _VoucherRecord(
        folio: '18263',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'JESUS RODRIGUEZ',
        rubric: 'OPERATIVO',
        comment: 'RODOLFO VERA',
        lines: [
          line(
            concept: 'BÁSCULA',
            company: 'MONROE',
            driver: 'RODOLFO VERA',
            amount: '150',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18264',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'GIL GUIA',
        rubric: 'OPERATIVO',
        comment: 'REPARACIÓN DE FUGA DE AGUA PRIV.29',
        lines: [
          line(
            concept: 'MANTENIMIENTO',
            unit: 'U-17',
            subconcept: 'MANGUERAS',
            amount: '300',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18265',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'DON VICTOR',
        rubric: 'OPERATIVO',
        comment: 'COMISIONES',
        lines: [line(concept: 'COMISIONES', amount: '5000')],
      ),
      _VoucherRecord(
        folio: '18266',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'GAS',
        rubric: 'OPERATIVO',
        comment: '109 LTS',
        lines: [
          line(
            concept: 'COMBUSTIBLE',
            unit: 'U-21',
            quantity: '109',
            amount: '1179.38',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18267',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'RIGOBERTO GONZALEZ',
        rubric: 'OPERATIVO',
        comment: 'DE BANDAS',
        lines: [
          line(
            concept: 'MANTENIMIENTO',
            unit: 'U-09',
            subconcept: 'MECÁNICA',
            amount: '755.42',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18268',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'OSCAR LARA',
        rubric: 'OPERATIVO',
        comment: '100.4 KILOS DE TRAPO',
        lines: [
          line(
            concept: 'EQUIPO',
            quantity: '100.4',
            subconcept: 'ALMACÉN',
            amount: '3012',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18269',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'MANUEL PAVANA',
        rubric: 'OPERATIVO',
        comment: 'COMPLEMENTARIO DE VIAJES SAN PABLO',
        lines: [
          line(
            concept: 'VIAJES',
            subconcept: 'COMIDA',
            amount: '157.24',
            destination: 'SAN PABLO',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18270',
        date: '14/04/2026',
        type: _VoucherType.expense,
        person: 'RENE JIMENEZ',
        rubric: 'OPERATIVO',
        comment: 'GKN',
        lines: [line(concept: 'BÁSCULA', company: 'GKN', amount: '100')],
      ),
      _VoucherRecord(
        folio: '18271',
        date: '13/04/2026',
        type: _VoucherType.expense,
        person: 'ANGEL LOPEZ',
        rubric: 'OPERATIVO',
        comment: 'DECASA-MONROE',
        lines: [line(concept: 'BÁSCULA', company: 'MONROE', amount: '350')],
      ),
      _VoucherRecord(
        folio: '18272',
        date: '13/04/2026',
        type: _VoucherType.expense,
        person: 'RAFAEL ABOYTES',
        rubric: 'OPERATIVO',
        comment: 'OXÍGENO Y BOQUILLAS',
        lines: [line(concept: 'OXÍGENO', quantity: '2', amount: '2144.02')],
      ),
      _VoucherRecord(
        folio: '18273',
        date: '13/04/2026',
        type: _VoucherType.expense,
        person: 'JESUS RDZ',
        rubric: 'OPERATIVO',
        comment: 'DEACERO',
        lines: [
          line(
            concept: 'CENA',
            driver: 'JESUS RDZ',
            destination: 'DE ACERO',
            amount: '150',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '18274',
        date: '13/04/2026',
        type: _VoucherType.expense,
        person: 'JESUS RODRIGUEZ',
        rubric: 'OPERATIVO',
        comment: 'GRUPACK-REGRESO EL DINERO',
        lines: [
          line(
            concept: 'VIAJES',
            subconcept: 'CASETA',
            amount: '0',
            destination: 'GRUPAK',
          ),
        ],
      ),
      _VoucherRecord(
        folio: '14350',
        date: '14/04/2026',
        type: _VoucherType.deposit,
        person: 'FATIMA CORTES',
        rubric: 'VENTA DE MATERIAL',
        comment: 'SRA REBE',
        lines: [line(concept: 'DEPÓSITO', amount: '14350')],
      ),
      _VoucherRecord(
        folio: '14381',
        date: '14/04/2026',
        type: _VoucherType.deposit,
        person: 'CAJA GRANDE',
        rubric: 'REPOSICIÓN DE FONDO',
        comment: '',
        lines: [line(concept: 'CAJA GRANDE', amount: '5000')],
      ),
      _VoucherRecord(
        folio: '14382',
        date: '13/04/2026',
        type: _VoucherType.deposit,
        person: 'BÓVEDA',
        rubric: 'REPOSICIÓN DE FONDO',
        comment: '',
        lines: [line(concept: 'BÓVEDA', amount: '7200')],
      ),
    ];
    final maxFolio = rows
        .map(
          (row) =>
              int.tryParse(row.folio.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .fold<int>(0, (max, value) => value > max ? value : max);
    if (maxFolio > _folioSequence) {
      _folioSequence = maxFolio;
    }
    return rows;
  }

  Future<void> _goBack() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openPriceAdjustmentsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openTicketsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoTicketsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openSalesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoSalesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Menudeo':
        unawaited(_goBack());
        return;
      case 'Catálogo':
        unawaited(_openCatalogPage());
        return;
      case 'Ajuste de precios':
        unawaited(_openPriceAdjustmentsPage());
        return;
      case 'Tickets de menudeo':
        unawaited(_openTicketsPage());
        return;
      case 'Ventas menudeo':
        unawaited(_openSalesPage());
        return;
      case 'Depósitos y gastos':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  DateTime? _tryParseVoucherDate(String raw) {
    final value = raw.trim();
    final parts = value.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(value);
  }

  List<_VoucherRecord> get _filteredVoucherRows {
    return _rows
        .where((row) {
          if (_voucherFolioFilter.isNotEmpty &&
              !_voucherFolioFilter.contains(row.folio)) {
            return false;
          }
          final typeLabel = row.type == _VoucherType.deposit
              ? 'DEPÓSITO'
              : 'GASTO';
          if (_voucherTypeFilter.isNotEmpty &&
              !_voucherTypeFilter.contains(typeLabel)) {
            return false;
          }
          if (_voucherPersonFilter.isNotEmpty &&
              !_voucherPersonFilter.contains(row.person)) {
            return false;
          }
          if (_voucherRubricFilter.isNotEmpty &&
              !_voucherRubricFilter.contains(row.rubric)) {
            return false;
          }
          if (_voucherConceptFilter.isNotEmpty &&
              !_voucherConceptFilter.contains(row.conceptsPreview)) {
            return false;
          }
          if (_voucherDateFilter != null) {
            final rowDate = _tryParseVoucherDate(row.date);
            if (rowDate == null) return false;
            final onlyDate = DateTime(rowDate.year, rowDate.month, rowDate.day);
            final start = DateTime(
              _voucherDateFilter!.start.year,
              _voucherDateFilter!.start.month,
              _voucherDateFilter!.start.day,
            );
            final end = DateTime(
              _voucherDateFilter!.end.year,
              _voucherDateFilter!.end.month,
              _voucherDateFilter!.end.day,
            );
            if (onlyDate.isBefore(start) || onlyDate.isAfter(end)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  int _effectiveCurrentPageFor(int totalRows) {
    if (totalRows <= 0) return 0;
    final maxPage = (totalRows - 1) ~/ _pageSize;
    return _currentPage.clamp(0, maxPage);
  }

  int _totalPagesFor(int totalRows) {
    if (totalRows <= 0) return 1;
    return ((totalRows - 1) ~/ _pageSize) + 1;
  }

  List<_VoucherRecord> _pageRows(List<_VoucherRecord> rows) {
    if (rows.isEmpty) return const <_VoucherRecord>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = math.min(start + _pageSize, rows.length);
    return rows.sublist(start, end);
  }

  bool _isShortcutModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  int _visiblePositionForKey(String? rowKey, List<_VoucherRecord> rows) {
    if (rowKey == null) return -1;
    return rows.indexWhere((row) => row.selectionKey == rowKey);
  }

  void _selectVisibleVoucherRange(
    List<_VoucherRecord> rows,
    int startVisible,
    int endVisible,
  ) {
    final from = startVisible < endVisible ? startVisible : endVisible;
    final to = startVisible < endVisible ? endVisible : startVisible;
    _selectedVoucherKeys
      ..clear()
      ..addAll(rows.sublist(from, to + 1).map((row) => row.selectionKey));
  }

  void _selectSingleVoucher(String rowKey) {
    _activeVoucherKey = rowKey;
    _voucherSelectionAnchorKey = rowKey;
    _selectedVoucherKeys
      ..clear()
      ..add(rowKey);
    _dragSelectingRows = false;
    _dragPointerLocal = null;
    _dragPointerGlobal = null;
  }

  void _toggleVoucherSelection(String rowKey) {
    _activeVoucherKey = rowKey;
    _voucherSelectionAnchorKey = rowKey;
    if (_selectedVoucherKeys.contains(rowKey)) {
      _selectedVoucherKeys.remove(rowKey);
      if (_selectedVoucherKeys.isEmpty) {
        _selectedVoucherKeys.add(rowKey);
      }
    } else {
      _selectedVoucherKeys.add(rowKey);
    }
    _dragSelectingRows = false;
  }

  void _extendVoucherSelectionTo(String rowKey, List<_VoucherRecord> rows) {
    final anchor = _voucherSelectionAnchorKey ?? _activeVoucherKey;
    final anchorVisible = _visiblePositionForKey(anchor, rows);
    final targetVisible = _visiblePositionForKey(rowKey, rows);
    if (anchorVisible < 0 || targetVisible < 0) {
      _selectSingleVoucher(rowKey);
      return;
    }
    _activeVoucherKey = rowKey;
    _selectVisibleVoucherRange(rows, anchorVisible, targetVisible);
    _dragSelectingRows = true;
  }

  void _clearVoucherSelection() {
    _selectedVoucherKeys.clear();
    _activeVoucherKey = null;
    _voucherSelectionAnchorKey = null;
    _dragSelectingRows = false;
    _dragPointerLocal = null;
    _dragPointerGlobal = null;
    _dragAutoScrollVelocity = 0;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
    _pointerDownAdditiveSelection = false;
    _suppressNextRowTap = false;
  }

  void _selectAllVisibleVouchers(List<_VoucherRecord> rows) {
    if (rows.isEmpty) return;
    _selectedVoucherKeys
      ..clear()
      ..addAll(rows.map((row) => row.selectionKey));
    _activeVoucherKey = rows.first.selectionKey;
    _voucherSelectionAnchorKey = rows.first.selectionKey;
  }

  void _ensureVoucherVisible(String rowKey) {
    final key = _rowKeys[rowKey];
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Offset? _globalToRowsLocal(Offset globalPosition) {
    final box =
        _voucherRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(globalPosition);
  }

  int? _visibleVoucherPositionAtGlobalPosition(
    Offset globalPosition,
    List<_VoucherRecord> rows,
  ) {
    for (var index = 0; index < rows.length; index++) {
      final box =
          _rowKeys[rows[index].selectionKey]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      if (globalPosition.dx >= topLeft.dx &&
          globalPosition.dx <= bottomRight.dx &&
          globalPosition.dy >= topLeft.dy &&
          globalPosition.dy <= bottomRight.dy) {
        return index;
      }
    }
    return null;
  }

  void _handleVoucherPrimaryPointerDown(
    String rowKey,
    List<_VoucherRecord> rows,
  ) {
    setState(() {
      _pointerDownAdditiveSelection =
          _isShortcutModifierPressed() || _isShiftPressed();
      if (_isShiftPressed()) {
        _extendVoucherSelectionTo(rowKey, rows);
        _suppressNextRowTap = true;
      } else if (_isShortcutModifierPressed()) {
        _toggleVoucherSelection(rowKey);
        _suppressNextRowTap = true;
      } else {
        _selectSingleVoucher(rowKey);
        _dragSelectingRows = true;
        _suppressNextRowTap = false;
      }
    });
  }

  void _handleVoucherRowsPointerDown(
    PointerDownEvent event,
    List<_VoucherRecord> rows,
  ) {
    _pointerDownAdditiveSelection =
        _isShortcutModifierPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final visibleIndex = _visibleVoucherPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _dragPointerGlobal = event.position;
    _handleVoucherPrimaryPointerDown(rows[visibleIndex].selectionKey, rows);
    _updateVoucherDragAutoScroll(rows);
  }

  void _handleVoucherTap(String rowKey) {
    if (_suppressNextRowTap || _pointerDownAdditiveSelection) {
      setState(() {
        _suppressNextRowTap = false;
        _pointerDownAdditiveSelection = false;
      });
      return;
    }
    setState(() => _selectSingleVoucher(rowKey));
  }

  void _handleVoucherRowDragEnter(String rowKey, List<_VoucherRecord> rows) {
    if (!_dragSelectingRows) return;
    setState(() => _extendVoucherSelectionTo(rowKey, rows));
  }

  void _handleVoucherRowsPointerMove(
    PointerMoveEvent event,
    List<_VoucherRecord> rows,
  ) {
    if (!_dragSelectingRows) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _dragPointerGlobal = event.position;
    _updateVoucherDragAutoScroll(rows);
    final visibleIndex = _visibleVoucherPositionAtGlobalPosition(
      event.position,
      rows,
    );
    if (visibleIndex == null) return;
    setState(
      () => _extendVoucherSelectionTo(rows[visibleIndex].selectionKey, rows),
    );
  }

  void _handleVoucherPointerEnd() {
    if (!_dragSelectingRows &&
        !_pointerDownAdditiveSelection &&
        !_suppressNextRowTap) {
      _dragPointerLocal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    setState(() {
      _dragSelectingRows = false;
      _dragPointerLocal = null;
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      _pointerDownAdditiveSelection = false;
      _suppressNextRowTap = false;
    });
  }

  void _updateVoucherDragAutoScroll(List<_VoucherRecord> rows) {
    if (!_dragSelectingRows || _dragPointerLocal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _voucherRowsViewportKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final y = _dragPointerLocal!.dy;
    if (y < edge) {
      _dragAutoScrollVelocity = -((edge - y) / edge).clamp(0.0, 1.0) * maxStep;
    } else if (y > box.size.height - edge) {
      _dragAutoScrollVelocity =
          ((y - (box.size.height - edge)) / edge).clamp(0.0, 1.0) * maxStep;
    } else {
      _dragAutoScrollVelocity = 0;
    }
    if (_dragAutoScrollVelocity == 0) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    _dragAutoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performVoucherDragAutoScroll(rows),
    );
  }

  void _performVoucherDragAutoScroll(List<_VoucherRecord> rows) {
    if (!_dragSelectingRows ||
        _dragAutoScrollVelocity == 0 ||
        !_voucherRowsScrollC.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _voucherRowsScrollC.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _voucherRowsScrollC.jumpTo(next);
    final pointerGlobal = _dragPointerGlobal;
    if (pointerGlobal == null) return;
    final visibleIndex = _visibleVoucherPositionAtGlobalPosition(
      pointerGlobal,
      rows,
    );
    if (visibleIndex == null) return;
    if (!mounted) return;
    setState(
      () => _extendVoucherSelectionTo(rows[visibleIndex].selectionKey, rows),
    );
  }

  Future<void> _openSelectedVoucher(List<_VoucherRecord> rows) async {
    if (rows.isEmpty) return;
    final key = _activeVoucherKey ?? rows.first.selectionKey;
    final row = rows.firstWhere(
      (item) => item.selectionKey == key,
      orElse: () => rows.first,
    );
    await _openVoucherDialog(initial: row, index: _rows.indexOf(row));
  }

  Future<void> _deleteSelectedVouchers(List<_VoucherRecord> rows) async {
    if (_selectedVoucherKeys.isEmpty || rows.isEmpty) return;
    final selectedRows = rows
        .where((row) => _selectedVoucherKeys.contains(row.selectionKey))
        .toList(growable: false);
    if (selectedRows.isEmpty) return;
    final confirmed = await showMenudeoDeleteConfirmDialog(
      context,
      title: selectedRows.length == 1
          ? 'Eliminar voucher'
          : 'Eliminar selección',
      message: selectedRows.length == 1
          ? '¿Seguro que deseas eliminar el voucher ${selectedRows.first.folio}?'
          : '¿Seguro que deseas eliminar ${selectedRows.length} vouchers?',
      impactLabel: selectedRows.length == 1
          ? 'El voucher saldrá del grid y del corte actual.'
          : '${selectedRows.length} vouchers saldrán del grid actual.',
      subtitle: selectedRows.length == 1
          ? 'Confirma la baja del voucher visible.'
          : 'Confirma la baja de la selección activa.',
    );
    if (confirmed != true || !mounted) return;
    final ids = selectedRows
        .map((row) => row.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    try {
      if (ids.isNotEmpty) {
        await _supa.from('men_cash_vouchers').delete().inFilter('id', ids);
      }
      await _loadVouchers();
      if (!mounted) return;
      setState(_clearVoucherSelection);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron eliminar los vouchers: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVoucherContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required _VoucherRecord row,
    required List<_VoucherRecord> visibleRows,
  }) async {
    if (!_selectedVoucherKeys.contains(row.selectionKey)) {
      setState(() => _selectSingleVoucher(row.selectionKey));
    }
    final selectedCount = visibleRows
        .where((item) => _selectedVoucherKeys.contains(item.selectionKey))
        .length;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<_VoucherGridMenuAction>(
      context: context,
      color: const Color(0xFFF3E4D9).withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: _buildVoucherMenuItems(selectedCount: selectedCount),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case _VoucherGridMenuAction.open:
        await _openSelectedVoucher(visibleRows);
      case _VoucherGridMenuAction.deleteSelection:
        await _deleteSelectedVouchers(visibleRows);
    }
  }

  bool _hasVoucherFilters() {
    return _voucherDateFilter != null ||
        _voucherFolioFilter.isNotEmpty ||
        _voucherTypeFilter.isNotEmpty ||
        _voucherPersonFilter.isNotEmpty ||
        _voucherRubricFilter.isNotEmpty ||
        _voucherConceptFilter.isNotEmpty;
  }

  void _clearVoucherFilters() {
    setState(() {
      _voucherDateFilter = null;
      _voucherFolioFilter.clear();
      _voucherTypeFilter.clear();
      _voucherPersonFilter.clear();
      _voucherRubricFilter.clear();
      _voucherConceptFilter.clear();
    });
  }

  Future<void> _openVoucherDateFilter() async {
    final bounds = _rows
        .map((row) => _tryParseVoucherDate(row.date))
        .whereType<DateTime>()
        .toList(growable: false);
    if (bounds.isEmpty) return;
    final sorted = [...bounds]..sort();
    final result = await showMenudeoDateRangeFilterDialog(
      context,
      label: 'FECHA',
      bounds: DateTimeRange(start: sorted.first, end: sorted.last),
      initialRange: _voucherDateFilter,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.clear) {
        _voucherDateFilter = null;
      } else {
        _voucherDateFilter = result.range;
      }
    });
  }

  Future<void> _openVoucherValueFilter({
    required String title,
    required Set<String> current,
    required List<String> options,
    required ValueChanged<Set<String>> onApply,
  }) async {
    final selected = await showMenudeoValueFilterDialog(
      context,
      title: title,
      options: options,
      initialValues: current,
    );
    if (selected == null || !mounted) return;
    setState(() => onApply(selected));
  }

  Future<void> _logout() async {
    final ok = await showMenudeoSessionConfirmDialog(context);
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  String _uiDateToIso(String raw) {
    final parsed = _tryParseVoucherDate(raw);
    if (parsed == null) {
      final now = DateTime.now();
      return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persistVoucher(_VoucherRecord record) async {
    if (kMenudeoForceDemoMode) return;
    final payload = <String, dynamic>{
      'voucher_date': _uiDateToIso(record.date),
      'folio': record.folio,
      'voucher_type': record.type == _VoucherType.deposit
          ? 'deposit'
          : 'expense',
      'person_label': record.person,
      'rubric': record.rubric,
      'comment': record.comment,
      'total_amount': record.total,
    };

    String voucherId = record.id ?? '';
    if (voucherId.isEmpty) {
      final inserted = await _supa
          .from('men_cash_vouchers')
          .insert(payload)
          .select('id')
          .single();
      voucherId = (inserted['id'] ?? '').toString();
    } else {
      await _supa.from('men_cash_vouchers').update(payload).eq('id', voucherId);
      await _supa
          .from('men_cash_voucher_lines')
          .delete()
          .eq('voucher_id', voucherId);
    }

    if (record.lines.isNotEmpty) {
      final linesPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < record.lines.length; i++) {
        final line = record.lines[i];
        linesPayload.add(<String, dynamic>{
          'voucher_id': voucherId,
          'line_order': i + 1,
          'concept': line.concept,
          'unit': line.unit,
          'quantity': line.quantity,
          'company': line.company,
          'driver': line.driver,
          'destination': line.destination,
          'subconcept': line.subconcept,
          'mode': line.mode,
          'amount': double.tryParse(line.amount) ?? 0,
          'comment': line.comment,
        });
      }
      await _supa.from('men_cash_voucher_lines').insert(linesPayload);
    }
  }

  Future<void> _openVoucherDialog({_VoucherRecord? initial, int? index}) async {
    final pageContext = context;
    final messenger = ScaffoldMessenger.of(pageContext);
    final editableEntries = <({int index, _VoucherRecord row})>[
      if (initial != null && index != null)
        ...((_selectedVoucherKeys.length > 1 &&
                    _selectedVoucherKeys.contains(initial.selectionKey))
                ? _rows.asMap().entries.where(
                    (entry) =>
                        _selectedVoucherKeys.contains(entry.value.selectionKey),
                  )
                : _rows.asMap().entries)
            .map((entry) => (index: entry.key, row: entry.value)),
    ];
    var currentPosition = 0;
    if (initial != null && index != null) {
      final located = editableEntries.indexWhere(
        (entry) => entry.row.selectionKey == initial.selectionKey,
      );
      if (located >= 0) currentPosition = located;
    }

    while (mounted) {
      final currentInitial = index == null
          ? initial
          : editableEntries[currentPosition].row;
      if (!pageContext.mounted) return;
      final result = await showDialog<_VoucherDialogResult>(
        context: pageContext,
        barrierColor: Colors.black.withValues(alpha: 0.24),
        builder: (dialogContext) {
          return _VoucherEditorDialog(
            initial: currentInitial,
            suggestedFolio:
                currentInitial?.folio ?? (_folioSequence + 1).toString(),
            unitOptions: _unitOptions,
            companyOptions: _companyOptions,
            driverOptions: _driverOptions,
            canGoPrevious: index != null && currentPosition > 0,
            canGoNext:
                index != null && currentPosition < editableEntries.length - 1,
            positionLabel: index != null
                ? '${currentPosition + 1} de ${editableEntries.length}'
                : null,
          );
        },
      );
      if (result == null || !mounted) return;
      if (result.navigateDelta != 0 && index != null) {
        currentPosition = (currentPosition + result.navigateDelta).clamp(
          0,
          editableEntries.length - 1,
        );
        continue;
      }
      final saved = result.record;
      if (saved == null) return;
      try {
        await _persistVoucher(saved);
        await _loadVouchers();
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el voucher: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
  }

  String _money(num value) => formatMoney(value);
  String _voucherTypeLabel(_VoucherType type) =>
      type == _VoucherType.deposit ? 'DEPÓSITO' : 'GASTO';

  Future<void> _exportFilteredVouchersCsv(List<_VoucherRecord> rows) async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'fecha,folio,tipo,persona,rubro,conceptos,total,comentario',
      );
      String escape(String value) =>
          '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      for (final row in rows) {
        buffer.writeln(
          [
            escape(row.date),
            escape(row.folio),
            escape(_voucherTypeLabel(row.type)),
            escape(row.person),
            escape(row.rubric),
            escape(row.conceptsPreview),
            row.total.toStringAsFixed(2),
            escape(row.comment),
          ].join(','),
        );
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await saveCsvFile(
        fileName: 'menudeo_vouchers_$stamp.csv',
        dialogTitle: 'Guardar CSV de vouchers',
        content: buffer.toString(),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _filteredVoucherRows;
    final visibleRows = _pageRows(filteredRows);
    final totalPages = _totalPagesFor(filteredRows.length);
    final currentPage = _effectiveCurrentPageFor(filteredRows.length);
    final activeVisibleIndex = visibleRows.indexWhere(
      (row) => row.selectionKey == _activeVoucherKey,
    );
    final visibleTotal = filteredRows.fold<double>(
      0,
      (sum, row) => sum + row.total,
    );
    final visibleDepositTotal = filteredRows
        .where((row) => row.type == _VoucherType.deposit)
        .fold<double>(0, (sum, row) => sum + row.total);
    final visibleExpenseTotal = filteredRows
        .where((row) => row.type == _VoucherType.expense)
        .fold<double>(0, (sum, row) => sum + row.total);
    final depositCount = filteredRows
        .where((row) => row.type == _VoucherType.deposit)
        .length;
    final expenseCount = filteredRows.length - depositCount;
    final selectedRows = filteredRows
        .where((row) => _selectedVoucherKeys.contains(row.selectionKey))
        .toList(growable: false);
    final selectedTotal = selectedRows.fold<double>(
      0,
      (sum, row) => sum + row.total,
    );
    final activeFilterCount =
        (_voucherDateFilter != null ? 1 : 0) +
        (_voucherFolioFilter.isNotEmpty ? 1 : 0) +
        (_voucherTypeFilter.isNotEmpty ? 1 : 0) +
        (_voucherPersonFilter.isNotEmpty ? 1 : 0) +
        (_voucherRubricFilter.isNotEmpty ? 1 : 0) +
        (_voucherConceptFilter.isNotEmpty ? 1 : 0);
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape &&
              _selectedVoucherKeys.isNotEmpty) {
            setState(_clearVoucherSelection);
            return KeyEventResult.handled;
          }
          if (_isShortcutModifierPressed() &&
              event.logicalKey == LogicalKeyboardKey.keyA &&
              visibleRows.isNotEmpty) {
            setState(() => _selectAllVisibleVouchers(visibleRows));
            return KeyEventResult.handled;
          }
          if (visibleRows.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            final next = (current + 1).clamp(0, visibleRows.length - 1);
            final nextKey = visibleRows[next].selectionKey;
            setState(() {
              if (_isShiftPressed()) {
                _extendVoucherSelectionTo(nextKey, visibleRows);
              } else {
                _selectSingleVoucher(nextKey);
              }
            });
            _ensureVoucherVisible(nextKey);
            return KeyEventResult.handled;
          }
          if (visibleRows.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            final next = (current - 1).clamp(0, visibleRows.length - 1);
            final nextKey = visibleRows[next].selectionKey;
            setState(() {
              if (_isShiftPressed()) {
                _extendVoucherSelectionTo(nextKey, visibleRows);
              } else {
                _selectSingleVoucher(nextKey);
              }
            });
            _ensureVoucherVisible(nextKey);
            return KeyEventResult.handled;
          }
          if (visibleRows.isNotEmpty &&
              event.logicalKey == LogicalKeyboardKey.space) {
            final current = activeVisibleIndex < 0 ? 0 : activeVisibleIndex;
            setState(
              () => _toggleVoucherSelection(visibleRows[current].selectionKey),
            );
            return KeyEventResult.handled;
          }
          if (filteredRows.isNotEmpty &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            unawaited(_openSelectedVoucher(filteredRows));
            return KeyEventResult.handled;
          }
          if (filteredRows.isNotEmpty &&
              (event.logicalKey == LogicalKeyboardKey.delete ||
                  event.logicalKey == LogicalKeyboardKey.backspace)) {
            unawaited(_deleteSelectedVouchers(filteredRows));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _DepositsExpensesBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, anim) => _DepositsHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => MenudeoHeaderBrand(
            contentAnim: contentAnim,
            title: 'Depósitos y Gastos',
          ),
          trailingBuilder: (_, anim) => _DepositsHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 56,
                      right: 2,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VouchersModuleTopBar(
                          visibleCount: visibleRows.length,
                          filteredCount: filteredRows.length,
                          selectedCount: selectedRows.length,
                          activeFilterCount: activeFilterCount,
                          visibleTotal: visibleTotal,
                          visibleDepositTotal: visibleDepositTotal,
                          visibleExpenseTotal: visibleExpenseTotal,
                          depositCount: depositCount,
                          expenseCount: expenseCount,
                          selectedTotal: selectedTotal,
                          selectedAverage: selectedRows.isEmpty
                              ? 0
                              : selectedTotal / selectedRows.length,
                          exportingCsv: _exportingCsv,
                          onExportCsv: () =>
                              _exportFilteredVouchersCsv(filteredRows),
                          onShowNewVoucher: () => _openVoucherDialog(),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TapRegion(
                            groupId: _kVoucherSelectionTapRegionGroup,
                            onTapOutside: (_) {
                              if (_selectedVoucherKeys.isNotEmpty) {
                                setState(_clearVoucherSelection);
                              }
                            },
                            child: ContractGlassCard(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                14,
                              ),
                              child: _loadingRows
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _VoucherGrid(
                                      rows: visibleRows,
                                      money: _money,
                                      selectedRowKeys: _selectedVoucherKeys,
                                      activeRowKey: _activeVoucherKey,
                                      rowKeys: _rowKeys,
                                      hasDateFilter: _voucherDateFilter != null,
                                      hasFolioFilter:
                                          _voucherFolioFilter.isNotEmpty,
                                      hasTypeFilter:
                                          _voucherTypeFilter.isNotEmpty,
                                      hasPersonFilter:
                                          _voucherPersonFilter.isNotEmpty,
                                      hasRubricFilter:
                                          _voucherRubricFilter.isNotEmpty,
                                      hasConceptFilter:
                                          _voucherConceptFilter.isNotEmpty,
                                      onOpenDateFilter: _openVoucherDateFilter,
                                      onOpenFolioFilter: () =>
                                          _openVoucherValueFilter(
                                            title: 'Filtrar folio',
                                            current: _voucherFolioFilter,
                                            options: _rows
                                                .map((row) => row.folio)
                                                .toList(),
                                            onApply: (next) =>
                                                _voucherFolioFilter = next,
                                          ),
                                      onOpenTypeFilter: () =>
                                          _openVoucherValueFilter(
                                            title: 'Filtrar tipo',
                                            current: _voucherTypeFilter,
                                            options: _rows
                                                .map(
                                                  (row) => _voucherTypeLabel(
                                                    row.type,
                                                  ),
                                                )
                                                .toList(),
                                            onApply: (next) =>
                                                _voucherTypeFilter = next,
                                          ),
                                      onOpenPersonFilter: () =>
                                          _openVoucherValueFilter(
                                            title: 'Filtrar persona',
                                            current: _voucherPersonFilter,
                                            options: _rows
                                                .map((row) => row.person)
                                                .toList(),
                                            onApply: (next) =>
                                                _voucherPersonFilter = next,
                                          ),
                                      onOpenRubricFilter: () =>
                                          _openVoucherValueFilter(
                                            title: 'Filtrar rubro',
                                            current: _voucherRubricFilter,
                                            options: _rows
                                                .map((row) => row.rubric)
                                                .toList(),
                                            onApply: (next) =>
                                                _voucherRubricFilter = next,
                                          ),
                                      onOpenConceptFilter: () =>
                                          _openVoucherValueFilter(
                                            title: 'Filtrar conceptos',
                                            current: _voucherConceptFilter,
                                            options: _rows
                                                .map(
                                                  (row) => row.conceptsPreview,
                                                )
                                                .toList(),
                                            onApply: (next) =>
                                                _voucherConceptFilter = next,
                                          ),
                                      onClearFilters: _hasVoucherFilters()
                                          ? _clearVoucherFilters
                                          : null,
                                      onRowPrimaryPointerDown: (rowKey) =>
                                          _handleVoucherPrimaryPointerDown(
                                            rowKey,
                                            visibleRows,
                                          ),
                                      onRowTap: _handleVoucherTap,
                                      onRowDragEnter: (rowKey) =>
                                          _handleVoucherRowDragEnter(
                                            rowKey,
                                            visibleRows,
                                          ),
                                      onRowPointerEnd: _handleVoucherPointerEnd,
                                      onOpenContextMenu:
                                          (context, offset, row) =>
                                              _openVoucherContextMenu(
                                                context: context,
                                                globalPosition: offset,
                                                row: row,
                                                visibleRows: visibleRows,
                                              ),
                                      onDeleteRow: (row) async {
                                        if (!_selectedVoucherKeys.contains(
                                          row.selectionKey,
                                        )) {
                                          setState(
                                            () => _selectSingleVoucher(
                                              row.selectionKey,
                                            ),
                                          );
                                        }
                                        await _deleteSelectedVouchers(
                                          filteredRows,
                                        );
                                      },
                                      onDeleteSelection:
                                          _selectedVoucherKeys.isNotEmpty
                                          ? () => _deleteSelectedVouchers(
                                              filteredRows,
                                            )
                                          : null,
                                      rowsScrollController: _voucherRowsScrollC,
                                      viewportKey: _voucherRowsViewportKey,
                                      onRowsPointerDown: (event) =>
                                          _handleVoucherRowsPointerDown(
                                            event,
                                            visibleRows,
                                          ),
                                      onRowsPointerMove: (event) =>
                                          _handleVoucherRowsPointerMove(
                                            event,
                                            visibleRows,
                                          ),
                                      onOpen: (row) => _openVoucherDialog(
                                        initial: row,
                                        index: _rows.indexOf(row),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: MenudeoGridPager(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            pageSize: _pageSize,
                            totalRows: filteredRows.length,
                            onPrevious: currentPage > 0
                                ? () => setState(
                                    () => _currentPage = currentPage - 1,
                                  )
                                : null,
                            onNext: currentPage < totalPages - 1
                                ? () => setState(
                                    () => _currentPage = currentPage + 1,
                                  )
                                : null,
                            onPageSizeChanged: (value) {
                              setState(() {
                                _pageSize = value;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: _DepositsSidePanel(
                    onBack: _goBack,
                    onNavigate: _handleNavigationAction,
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

class _DepositsHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _DepositsHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_DepositsHeaderButton> createState() => _DepositsHeaderButtonState();
}

class _DepositsHeaderButtonState extends State<_DepositsHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.30 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.34 : 0.24,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.46),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepositsSidePanel extends StatelessWidget {
  final Future<void> Function() onBack;
  final ValueChanged<String> onNavigate;

  const _DepositsSidePanel({required this.onBack, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menudeo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 16),
            const _DepositsSectionHeader(label: 'MENU'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x66EFD7C2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: tokens.primaryStrong.withValues(alpha: 0.14),
                ),
              ),
              child: Column(
                children: [
                  _DepositsSidePanelItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Compras',
                    subtitle: 'Tickets virtuales de compra',
                    onTapSync: () => onNavigate('Tickets de menudeo'),
                  ),
                  const SizedBox(height: 8),
                  _DepositsSidePanelItem(
                    icon: Icons.point_of_sale_rounded,
                    title: 'Ventas',
                    subtitle: 'Tickets virtuales de venta',
                    onTapSync: () => onNavigate('Ventas menudeo'),
                  ),
                  const SizedBox(height: 8),
                  _DepositsSidePanelItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Depósitos y gastos',
                    subtitle: 'Vouchers de caja y egresos',
                    highlighted: true,
                  ),
                  const SizedBox(height: 8),
                  _DepositsSidePanelItem(
                    icon: Icons.auto_graph_rounded,
                    title: 'Ajuste de precios',
                    subtitle: 'Cambios e historial',
                    onTapSync: () => onNavigate('Ajuste de precios'),
                  ),
                  const SizedBox(height: 8),
                  _DepositsSidePanelItem(
                    icon: Icons.price_check_rounded,
                    title: 'Catálogo',
                    subtitle: 'Materiales, grupos y precios',
                    onTapSync: () => onNavigate('Catálogo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _DepositsSectionHeader(label: 'ACCESOS'),
            const SizedBox(height: 8),
            _DepositsSidePanelItem(
              icon: Icons.space_dashboard_rounded,
              title: 'Dashboard Menudeo',
              subtitle: 'Vista general del área',
              accented: true,
              onTap: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositsSectionHeader extends StatelessWidget {
  final String label;

  const _DepositsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _DepositsSidePanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool highlighted;
  final bool accented;

  const _DepositsSidePanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onTapSync,
    this.highlighted = false,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = onTap != null || onTapSync != null;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: !enabled
              ? null
              : () async {
                  if (onTap != null) {
                    await onTap!();
                  } else {
                    onTapSync?.call();
                  }
                },
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: accented
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE5A56F), Color(0xFFCF7E59)],
                    )
                  : highlighted
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFEFC186), Color(0xFFDFA06F)],
                    )
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFF6E2D1), Color(0xFFE7B992)],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? const Color(0xFFF7DCC5)
                    : highlighted
                    ? tokens.primaryStrong.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB46D4F).withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : highlighted
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB97A5C).withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFB97A5C).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.badgeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (highlighted && !accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.primarySoft,
                    size: 22,
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DepositsExpensesBackground extends StatelessWidget {
  const _DepositsExpensesBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7EDE6), Color(0xFFD8C1B0), Color(0xFFA88973)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 340,
              height: 340,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD89A5C),
              ),
            ),
          ),
          Positioned(
            left: -120,
            bottom: -160,
            child: Container(
              width: 460,
              height: 460,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE4BCA7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherGrid extends StatelessWidget {
  final List<_VoucherRecord> rows;
  final String Function(num value) money;
  final ValueChanged<_VoucherRecord> onOpen;
  final Set<String> selectedRowKeys;
  final String? activeRowKey;
  final Map<String, GlobalKey> rowKeys;
  final bool hasDateFilter;
  final bool hasFolioFilter;
  final bool hasTypeFilter;
  final bool hasPersonFilter;
  final bool hasRubricFilter;
  final bool hasConceptFilter;
  final Future<void> Function() onOpenDateFilter;
  final Future<void> Function() onOpenFolioFilter;
  final Future<void> Function() onOpenTypeFilter;
  final Future<void> Function() onOpenPersonFilter;
  final Future<void> Function() onOpenRubricFilter;
  final Future<void> Function() onOpenConceptFilter;
  final VoidCallback? onClearFilters;
  final ValueChanged<String> onRowPrimaryPointerDown;
  final ValueChanged<String> onRowTap;
  final ValueChanged<String> onRowDragEnter;
  final VoidCallback onRowPointerEnd;
  final Future<void> Function(BuildContext, Offset, _VoucherRecord)
  onOpenContextMenu;
  final Future<void> Function(_VoucherRecord row) onDeleteRow;
  final Future<void> Function()? onDeleteSelection;
  final ScrollController rowsScrollController;
  final Key viewportKey;
  final ValueChanged<PointerDownEvent> onRowsPointerDown;
  final ValueChanged<PointerMoveEvent> onRowsPointerMove;

  const _VoucherGrid({
    required this.rows,
    required this.money,
    required this.onOpen,
    required this.selectedRowKeys,
    required this.activeRowKey,
    required this.rowKeys,
    required this.hasDateFilter,
    required this.hasFolioFilter,
    required this.hasTypeFilter,
    required this.hasPersonFilter,
    required this.hasRubricFilter,
    required this.hasConceptFilter,
    required this.onOpenDateFilter,
    required this.onOpenFolioFilter,
    required this.onOpenTypeFilter,
    required this.onOpenPersonFilter,
    required this.onOpenRubricFilter,
    required this.onOpenConceptFilter,
    required this.onRowPrimaryPointerDown,
    required this.onRowTap,
    required this.onRowDragEnter,
    required this.onRowPointerEnd,
    required this.onOpenContextMenu,
    required this.onDeleteRow,
    required this.rowsScrollController,
    required this.viewportKey,
    required this.onRowsPointerDown,
    required this.onRowsPointerMove,
    this.onDeleteSelection,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    const totalWidth = 110 + 110 + 110 + 250 + 180 + 180 + 196;
    final selectedRows = rows
        .where((row) => selectedRowKeys.contains(row.selectionKey))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onClearFilters != null) ...[
          Row(
            children: [
              if (selectedRows.isNotEmpty)
                FilledButton.icon(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: onDeleteSelection,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text('Eliminar (${selectedRowKeys.length})'),
                ),
              if (selectedRows.isNotEmpty) const SizedBox(width: 8),
              const Spacer(),
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: onClearFilters,
                child: const Text('Limpiar filtros'),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Card(
          elevation: 0,
          color: Colors.black.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: ContractGridScaledRow(
                    child: SizedBox(
                      width: totalWidth.toDouble(),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Fecha',
                              style: headerStyle,
                              active: hasDateFilter,
                              onTap: onOpenDateFilter,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Folio',
                              style: headerStyle,
                              active: hasFolioFilter,
                              onTap: onOpenFolioFilter,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Tipo',
                              style: headerStyle,
                              active: hasTypeFilter,
                              onTap: onOpenTypeFilter,
                            ),
                          ),
                          SizedBox(
                            width: 250,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Persona',
                              style: headerStyle,
                              active: hasPersonFilter,
                              onTap: onOpenPersonFilter,
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Rubro',
                              style: headerStyle,
                              active: hasRubricFilter,
                              onTap: onOpenRubricFilter,
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Conceptos',
                              style: headerStyle,
                              active: hasConceptFilter,
                              onTap: onOpenConceptFilter,
                            ),
                          ),
                          const SizedBox(
                            width: 196,
                            child: Text('Total', style: headerStyle),
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
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'Sin vouchers con los filtros actuales.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Listener(
              onPointerDown: onRowsPointerDown,
              onPointerMove: onRowsPointerMove,
              onPointerUp: (_) => onRowPointerEnd(),
              onPointerCancel: (_) => onRowPointerEnd(),
              child: ListView.separated(
                key: viewportKey,
                controller: rowsScrollController,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final rowKey = row.selectionKey;
                  rowKeys.putIfAbsent(rowKey, () => GlobalKey());
                  return _VoucherGridRow(
                    key: rowKeys[rowKey],
                    row: row,
                    selected: selectedRowKeys.contains(rowKey),
                    highlighted: activeRowKey == rowKey,
                    money: money,
                    onPrimaryPointerDown: () => onRowPrimaryPointerDown(rowKey),
                    onTap: () => onRowTap(rowKey),
                    onOpen: () => onOpen(row),
                    onDragEnter: () => onRowDragEnter(rowKey),
                    onPointerEnd: onRowPointerEnd,
                    onSecondaryTapDown: (context, offset) =>
                        onOpenContextMenu(context, offset, row),
                    onDelete: () => onDeleteRow(row),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _VoucherGridRow extends StatefulWidget {
  final _VoucherRecord row;
  final bool selected;
  final bool highlighted;
  final String Function(num value) money;
  final VoidCallback onPrimaryPointerDown;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onDragEnter;
  final VoidCallback onPointerEnd;
  final Future<void> Function(BuildContext context, Offset offset)
  onSecondaryTapDown;

  const _VoucherGridRow({
    super.key,
    required this.row,
    required this.selected,
    required this.highlighted,
    required this.money,
    required this.onPrimaryPointerDown,
    required this.onTap,
    required this.onOpen,
    required this.onDelete,
    required this.onDragEnter,
    required this.onPointerEnd,
    required this.onSecondaryTapDown,
  });

  @override
  State<_VoucherGridRow> createState() => _VoucherGridRowState();
}

class _VoucherGridRowState extends State<_VoucherGridRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selectedContext = widget.selected || widget.highlighted;
    const rowContentWidth = 110 + 110 + 110 + 250 + 180 + 180 + 196;

    Widget divider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: tokens.border.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    Widget cell({
      required double width,
      required Widget child,
      bool includeDivider = true,
    }) {
      return SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: child),
            if (includeDivider) divider(),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        widget.onDragEnter();
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              (event.buttons & kPrimaryMouseButton) != 0) {
            widget.onPrimaryPointerDown();
          }
        },
        onPointerUp: (_) => widget.onPointerEnd(),
        onPointerCancel: (_) => widget.onPointerEnd(),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hovering ? 1.003 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selectedContext
                    ? [
                        tokens.badgeBackground.withValues(alpha: 0.96),
                        const Color(0xFFF1D7C7).withValues(alpha: 0.90),
                      ]
                    : _hovering
                    ? [
                        Colors.white.withValues(alpha: 0.90),
                        const Color(0xFFF4E6DD).withValues(alpha: 0.82),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.74),
                        const Color(0xFFF7ECE5).withValues(alpha: 0.68),
                      ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selectedContext
                    ? tokens.primaryStrong.withValues(alpha: 0.48)
                    : _hovering
                    ? tokens.primarySoft.withValues(alpha: 0.30)
                    : tokens.border.withValues(alpha: 0.64),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(-2, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: selectedContext
                        ? 0.12
                        : _hovering
                        ? 0.10
                        : 0.06,
                  ),
                  blurRadius: _hovering ? 20 : 14,
                  offset: Offset(0, _hovering ? 12 : 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: ContractGridScaledRow(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onSecondaryTapDown: (details) => unawaited(
                        widget.onSecondaryTapDown(
                          context,
                          details.globalPosition,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onTap,
                          onDoubleTap: widget.onOpen,
                          child: SizedBox(
                            width: rowContentWidth.toDouble(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                cell(width: 110, child: Text(widget.row.date)),
                                cell(
                                  width: 110,
                                  child: TextButton(
                                    onPressed: widget.onOpen,
                                    style: TextButton.styleFrom(
                                      foregroundColor: tokens.primaryStrong,
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                      minimumSize: Size.zero,
                                    ),
                                    child: Text(
                                      widget.row.folio,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                ),
                                cell(
                                  width: 110,
                                  child: Text(
                                    widget.row.type == _VoucherType.deposit
                                        ? 'DEPÓSITO'
                                        : 'GASTO',
                                  ),
                                ),
                                cell(
                                  width: 250,
                                  child: Text(widget.row.person),
                                ),
                                cell(
                                  width: 180,
                                  child: Text(widget.row.rubric),
                                ),
                                cell(
                                  width: 180,
                                  child: Text(widget.row.conceptsPreview),
                                ),
                                AnchoredActionSlot(
                                  width: 196,
                                  trailingWidth: 36,
                                  gap: 8,
                                  leading: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      widget.money(widget.row.total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                  trailing:
                                      PopupMenuButton<_VoucherGridMenuAction>(
                                        tooltip: 'Acciones',
                                        padding: EdgeInsets.zero,
                                        color: const Color(
                                          0xFFF3E4D9,
                                        ).withValues(alpha: 0.96),
                                        elevation: 8,
                                        shadowColor: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        onSelected: (action) {
                                          switch (action) {
                                            case _VoucherGridMenuAction.open:
                                              widget.onOpen();
                                            case _VoucherGridMenuAction
                                                .deleteSelection:
                                              widget.onDelete();
                                          }
                                        },
                                        itemBuilder: (_) =>
                                            _buildVoucherMenuItems(
                                              selectedCount: 1,
                                            ),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: tokens.primarySoft
                                                  .withValues(alpha: 0.24),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            color: tokens.primaryStrong,
                                            size: 18,
                                          ),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VouchersModuleTopBar extends StatelessWidget {
  final int visibleCount;
  final int filteredCount;
  final int selectedCount;
  final int activeFilterCount;
  final double visibleTotal;
  final double visibleDepositTotal;
  final double visibleExpenseTotal;
  final int depositCount;
  final int expenseCount;
  final double selectedTotal;
  final double selectedAverage;
  final bool exportingCsv;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onShowNewVoucher;

  const _VouchersModuleTopBar({
    required this.visibleCount,
    required this.filteredCount,
    required this.selectedCount,
    required this.activeFilterCount,
    required this.visibleTotal,
    required this.visibleDepositTotal,
    required this.visibleExpenseTotal,
    required this.depositCount,
    required this.expenseCount,
    required this.selectedTotal,
    required this.selectedAverage,
    required this.exportingCsv,
    required this.onExportCsv,
    required this.onShowNewVoucher,
  });

  String _money(num value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Depósitos / Gastos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        AppGlassToolbarPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = _VouchersSelectionInfo(
                selectedCount: selectedCount,
                activeFilterCount: activeFilterCount,
                selectedTotalLabel: selectedCount > 0
                    ? _money(selectedTotal)
                    : null,
                selectedAverageLabel: selectedCount > 0
                    ? _money(selectedAverage)
                    : null,
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: _vouchersGlassToolbarActionStyle(),
                    onPressed: exportingCsv
                        ? null
                        : () => unawaited(onExportCsv()),
                    icon: exportingCsv
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      exportingCsv ? 'Exportando...' : 'Descargar CSV',
                    ),
                  ),
                  FilledButton.icon(
                    style: contractPrimaryButtonStyle(context),
                    onPressed: () => unawaited(onShowNewVoucher()),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Nuevo voucher'),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actions,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: info),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions),
                  const SizedBox(width: 10),
                  info,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              MenudeoMetricCard(
                icon: Icons.receipt_long_rounded,
                title: 'VOUCHERS',
                value: '$filteredCount',
                detail: '$depositCount depósitos · $expenseCount gastos',
                accent: menudeoAreaTokens.primaryStrong,
              ),
              MenudeoMetricCard(
                icon: Icons.arrow_downward_rounded,
                title: 'TOTAL DEPÓSITOS',
                value: _money(visibleDepositTotal),
                detail: '$depositCount visibles',
                accent: const Color(0xFFB27253),
              ),
              MenudeoMetricCard(
                icon: Icons.arrow_upward_rounded,
                title: 'TOTAL GASTOS',
                value: _money(visibleExpenseTotal),
                detail: activeFilterCount > 0
                    ? '$expenseCount visibles · $activeFilterCount filtros'
                    : '$expenseCount visibles',
                accent: menudeoAreaTokens.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VouchersSelectionInfo extends StatelessWidget {
  final int selectedCount;
  final int activeFilterCount;
  final String? selectedTotalLabel;
  final String? selectedAverageLabel;

  const _VouchersSelectionInfo({
    required this.selectedCount,
    required this.activeFilterCount,
    required this.selectedTotalLabel,
    required this.selectedAverageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (selectedTotalLabel != null) 'Total: $selectedTotalLabel',
      if (selectedAverageLabel != null) 'Promedio: $selectedAverageLabel',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          selectedCount == 1
              ? '1 seleccionado'
              : '$selectedCount seleccionados',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8F5E4A),
          ),
          textAlign: TextAlign.right,
        ),
        if (summary.isNotEmpty)
          Text(
            summary.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F5E4A),
            ),
            textAlign: TextAlign.right,
          ),
        if (activeFilterCount > 0)
          Text(
            '$activeFilterCount filtros activos',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F5E4A),
            ),
            textAlign: TextAlign.right,
          ),
      ],
    );
  }
}

ButtonStyle _vouchersGlassToolbarActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2D2A28),
    backgroundColor: Colors.white.withValues(alpha: 0.22),
    disabledForegroundColor: const Color(0xFF2D2A28).withValues(alpha: 0.42),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.58)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

class _VoucherEditorDialog extends StatefulWidget {
  final _VoucherRecord? initial;
  final String suggestedFolio;
  final List<String> unitOptions;
  final List<String> companyOptions;
  final List<String> driverOptions;
  final bool canGoPrevious;
  final bool canGoNext;
  final String? positionLabel;

  const _VoucherEditorDialog({
    required this.initial,
    required this.suggestedFolio,
    required this.unitOptions,
    required this.companyOptions,
    required this.driverOptions,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.positionLabel,
  });

  @override
  State<_VoucherEditorDialog> createState() => _VoucherEditorDialogState();
}

class _VoucherEditorDialogState extends State<_VoucherEditorDialog> {
  late _VoucherType _type;
  late final TextEditingController _folioC;
  late final TextEditingController _dateC;
  late final TextEditingController _personC;
  late final TextEditingController _generalCommentC;
  String _rubric = '';
  final List<_LineItemDraft> _lines = <_LineItemDraft>[];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? _VoucherType.expense;
    _folioC = TextEditingController(
      text: initial?.folio ?? widget.suggestedFolio,
    );
    _dateC = TextEditingController(
      text: initial?.date ?? _formatDate(DateTime.now()),
    );
    _personC = TextEditingController(text: initial?.person ?? '');
    _generalCommentC = TextEditingController(text: initial?.comment ?? '');
    _rubric = initial?.rubric ?? _rubricOptionsForType(_type).first;
    if (initial != null) {
      for (final line in initial.lines) {
        _lines.add(_LineItemDraft.fromRecord(line));
      }
    }
    if (_lines.isEmpty) {
      _lines.add(_LineItemDraft());
    }
  }

  @override
  void dispose() {
    _folioC.dispose();
    _dateC.dispose();
    _personC.dispose();
    _generalCommentC.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  DateTime _parseDateOrNow(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.now();
  }

  Future<void> _pickVoucherDate() async {
    final picked = await showContractDatePickerSurface(
      context,
      initialDate: _parseDateOrNow(_dateC.text),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      title: 'Selecciona fecha del voucher',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateC.text = _formatDate(picked);
    });
  }

  List<String> _rubricOptionsForType(_VoucherType type) {
    return _voucherConfig[type]!.keys.toList(growable: false);
  }

  List<_ConceptConfig> _conceptOptionsForRubric() {
    return _voucherConfig[_type]![_rubric] ?? const <_ConceptConfig>[];
  }

  _ConceptConfig? _findConcept(String value) {
    for (final concept in _conceptOptionsForRubric()) {
      if (concept.label == value) return concept;
    }
    return null;
  }

  double get _total => _lines.fold<double>(
    0,
    (sum, line) => sum + (double.tryParse(line.amountC.text.trim()) ?? 0),
  );

  void _syncLineWithRubric(_LineItemDraft line) {
    final concepts = _conceptOptionsForRubric().map((e) => e.label).toSet();
    if (!concepts.contains(line.concept)) {
      line.concept = '';
      line.unit = '';
      line.quantity = '';
      line.company = '';
      line.driver = '';
      line.destination = '';
      line.subconcept = '';
      line.mode = '';
    }
  }

  void _save() {
    final cleanLines = _lines
        .where((line) {
          return line.concept.trim().isNotEmpty &&
              line.amountC.text.trim().isNotEmpty;
        })
        .toList(growable: false);
    if (_folioC.text.trim().isEmpty ||
        _personC.text.trim().isEmpty ||
        _rubric.trim().isEmpty ||
        cleanLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa folio, persona y al menos un renglón válido.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _VoucherDialogResult.save(
        _VoucherRecord(
          id: widget.initial?.id,
          folio: _folioC.text.trim(),
          date: _dateC.text.trim(),
          type: _type,
          person: _personC.text.trim().toUpperCase(),
          rubric: _rubric,
          comment: _generalCommentC.text.trim(),
          lines: cleanLines
              .map((line) => line.toRecord())
              .toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    final totalLabel = formatMoney(_total);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.canGoPrevious) {
            Navigator.of(context).pop(const _VoucherDialogResult.navigate(-1));
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              widget.canGoNext) {
            Navigator.of(context).pop(const _VoucherDialogResult.navigate(1));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AreaThemeScope(
          tokens: menudeoAreaTokens,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: menudeoAreaTokens.primaryStrong,
                secondary: menudeoAreaTokens.primaryStrong,
                surface: const Color(0xFFFFFAF6),
                onSurface: const Color(0xFF2D2A28),
              ),
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: menudeoAreaTokens.primaryStrong,
                selectionColor: menudeoAreaTokens.primarySoft.withValues(
                  alpha: 0.48,
                ),
                selectionHandleColor: menudeoAreaTokens.primaryStrong,
              ),
              splashColor: menudeoAreaTokens.primarySoft.withValues(
                alpha: 0.16,
              ),
              highlightColor: menudeoAreaTokens.primarySoft.withValues(
                alpha: 0.10,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: _voucherPrimaryButtonStyle(menudeoAreaTokens),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: _voucherSecondaryButtonStyle(menudeoAreaTokens),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: menudeoAreaTokens.primaryStrong,
                ),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  foregroundColor: menudeoAreaTokens.primaryStrong,
                  selectedForegroundColor: menudeoAreaTokens.primaryStrong,
                  selectedBackgroundColor: menudeoAreaTokens.badgeBackground
                      .withValues(alpha: 0.92),
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  side: BorderSide(
                    color: menudeoAreaTokens.primarySoft.withValues(
                      alpha: 0.42,
                    ),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              popupMenuTheme: PopupMenuThemeData(
                color: const Color(0xFFF3E4D9).withValues(alpha: 0.96),
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ),
            child: ContractPopupSurface(
              constraints: const BoxConstraints(
                minWidth: 760,
                maxWidth: 1080,
                maxHeight: 860,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VoucherDialogHeader(
                    canGoPrevious: widget.canGoPrevious,
                    canGoNext: widget.canGoNext,
                    positionLabel: widget.positionLabel,
                    onPrevious: widget.canGoPrevious
                        ? () => Navigator.of(
                            context,
                          ).pop(const _VoucherDialogResult.navigate(-1))
                        : null,
                    onNext: widget.canGoNext
                        ? () => Navigator.of(
                            context,
                          ).pop(const _VoucherDialogResult.navigate(1))
                        : null,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.center,
                    child: _VoucherTopChip(
                      label: 'Total',
                      value: totalLabel,
                      emphasized: true,
                      centered: true,
                      minWidth: 340,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ContractGlassCard(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _VoucherField(
                                        label: 'Fecha',
                                        compact: true,
                                        child: InkWell(
                                          onTap: _pickVoucherDate,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _dateC.text,
                                                  style: _voucherInputTextStyle(
                                                    tokens,
                                                  ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_month_rounded,
                                                size: 18,
                                                color: tokens.primaryStrong,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _VoucherField(
                                        label: 'Folio',
                                        compact: true,
                                        child: TextField(
                                          controller: _folioC,
                                          style: _voucherInputTextStyle(tokens),
                                          decoration: InputDecoration.collapsed(
                                            hintText: 'Folio',
                                            hintStyle: _voucherHintTextStyle(
                                              tokens,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _VoucherField(
                                        label: 'Tipo',
                                        compact: true,
                                        child: SegmentedButton<_VoucherType>(
                                          style: SegmentedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            foregroundColor:
                                                tokens.primaryStrong,
                                            selectedForegroundColor:
                                                tokens.primaryStrong,
                                            selectedBackgroundColor: tokens
                                                .badgeBackground
                                                .withValues(alpha: 0.92),
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.72),
                                            side: BorderSide(
                                              color: tokens.primarySoft
                                                  .withValues(alpha: 0.42),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          segments: const [
                                            ButtonSegment(
                                              value: _VoucherType.deposit,
                                              label: Text('Depósito'),
                                            ),
                                            ButtonSegment(
                                              value: _VoucherType.expense,
                                              label: Text('Gasto'),
                                            ),
                                          ],
                                          selected: <_VoucherType>{_type},
                                          onSelectionChanged: (value) {
                                            setState(() {
                                              _type = value.first;
                                              _rubric = _rubricOptionsForType(
                                                _type,
                                              ).first;
                                              for (final line in _lines) {
                                                _syncLineWithRubric(line);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _VoucherField(
                                        label: _type == _VoucherType.deposit
                                            ? 'Recibido de'
                                            : 'Entregado a',
                                        compact: true,
                                        child: TextField(
                                          controller: _personC,
                                          style: _voucherInputTextStyle(tokens),
                                          decoration: InputDecoration.collapsed(
                                            hintText: 'Persona / cuenta',
                                            hintStyle: _voucherHintTextStyle(
                                              tokens,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _VoucherField(
                                        label: 'Rubro',
                                        compact: true,
                                        child: _InlineDropdown(
                                          value: _rubric,
                                          items: _rubricOptionsForType(_type),
                                          hint: 'Rubro',
                                          onChanged: (value) {
                                            setState(() {
                                              _rubric = value;
                                              for (final line in _lines) {
                                                _syncLineWithRubric(line);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _VoucherField(
                                  label: 'Comentario general',
                                  compact: true,
                                  child: TextField(
                                    controller: _generalCommentC,
                                    maxLines: 1,
                                    style: _voucherInputTextStyle(tokens),
                                    decoration: InputDecoration.collapsed(
                                      hintText:
                                          'Observación general del voucher',
                                      hintStyle: _voucherHintTextStyle(tokens),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ContractGlassCard(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...List<Widget>.generate(_lines.length, (
                                  index,
                                ) {
                                  final line = _lines[index];
                                  final concept = _findConcept(line.concept);
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == _lines.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _VoucherLineCard(
                                      index: index,
                                      line: line,
                                      concepts: _conceptOptionsForRubric(),
                                      concept: concept,
                                      unitOptions: widget.unitOptions,
                                      companyOptions: widget.companyOptions,
                                      driverOptions: widget.driverOptions,
                                      onChanged: () => setState(() {}),
                                      onRemove: _lines.length == 1
                                          ? null
                                          : () {
                                              setState(() {
                                                _lines
                                                    .removeAt(index)
                                                    .dispose();
                                              });
                                            },
                                    ),
                                  );
                                }),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton(
                                    style: _voucherSecondaryButtonStyle(tokens),
                                    onPressed: () {
                                      setState(
                                        () => _lines.add(_LineItemDraft()),
                                      );
                                    },
                                    child: const Text('+'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: _voucherSecondaryButtonStyle(tokens),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: _voucherPrimaryButtonStyle(tokens),
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar voucher'),
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
  }
}

TextStyle _voucherInputTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: tokens.primaryStrong,
);

TextStyle _voucherHintTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: tokens.badgeText.withValues(alpha: 0.84),
);

ButtonStyle _voucherPrimaryButtonStyle(ContractAreaTokens tokens) {
  return FilledButton.styleFrom(
    backgroundColor: tokens.primaryStrong,
    foregroundColor: Colors.white,
    disabledBackgroundColor: tokens.primarySoft,
    disabledForegroundColor: tokens.badgeText.withValues(alpha: 0.5),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _voucherSecondaryButtonStyle(ContractAreaTokens tokens) {
  return OutlinedButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.55),
    side: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.9)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

class _VoucherField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool compact;

  const _VoucherField({
    required this.label,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            const Color(0xFFF5ECE6).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.primarySoft.withValues(alpha: compact ? 0.34 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          child,
        ],
      ),
    );
  }
}

class _VoucherDialogHeader extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final String? positionLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  const _VoucherDialogHeader({
    required this.onClose,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.positionLabel,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.54),
            const Color(0xFFF4E8E0).withValues(alpha: 0.30),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DicsaLogoD(size: 32),
              const SizedBox(width: 10),
              Text(
                'DICSA',
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canGoPrevious || canGoNext) ...[
                  _VoucherDialogActionButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: canGoPrevious ? onPrevious : null,
                  ),
                  const SizedBox(width: 8),
                  if (positionLabel != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        positionLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText,
                        ),
                      ),
                    ),
                  if (positionLabel != null) const SizedBox(width: 8),
                  _VoucherDialogActionButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: canGoNext ? onNext : null,
                  ),
                  const SizedBox(width: 8),
                ],
                _VoucherDialogActionButton(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherDialogActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _VoucherDialogActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFFF2E4DB).withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: tokens.primarySoft.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.46),
                blurRadius: 10,
                offset: const Offset(-2, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: onTap == null
                ? tokens.badgeText.withValues(alpha: 0.42)
                : tokens.primaryStrong,
          ),
        ),
      ),
    );
  }
}

class _VoucherTopChip extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool centered;
  final double minWidth;

  const _VoucherTopChip({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.centered = false,
    this.minWidth = 148,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            emphasized
                ? const Color(0xFFF5D4C2).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.92),
            emphasized
                ? const Color(0xFFE8B89B).withValues(alpha: 0.90)
                : const Color(0xFFF2E4DB).withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasized
              ? tokens.primaryStrong.withValues(alpha: 0.22)
              : tokens.primarySoft.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.46),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: emphasized ? tokens.primaryStrong : tokens.badgeText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? 'Pendiente' : value,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: emphasized ? 18.5 : 15,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherLineCard extends StatelessWidget {
  final int index;
  final _LineItemDraft line;
  final List<_ConceptConfig> concepts;
  final _ConceptConfig? concept;
  final List<String> unitOptions;
  final List<String> companyOptions;
  final List<String> driverOptions;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _VoucherLineCard({
    required this.index,
    required this.line,
    required this.concepts,
    required this.concept,
    required this.unitOptions,
    required this.companyOptions,
    required this.driverOptions,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Renglón ${index + 1}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: tokens.badgeText,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _VoucherField(
                  label: 'Concepto',
                  compact: true,
                  child: _InlineDropdown(
                    value: line.concept,
                    items: concepts.map((item) => item.label).toList(),
                    hint: 'Seleccionar concepto',
                    onChanged: (value) {
                      line.concept = value;
                      line.unit = '';
                      line.quantity = '';
                      line.company = '';
                      line.driver = '';
                      line.destination = '';
                      line.subconcept = '';
                      line.mode = '';
                      onChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoucherField(
                  label: 'Importe',
                  compact: true,
                  child: TextField(
                    controller: line.amountC,
                    onChanged: (_) => onChanged(),
                    style: _voucherInputTextStyle(tokens),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '0.00',
                      hintStyle: _voucherHintTextStyle(tokens),
                    ),
                  ),
                ),
              ),
              if (concept?.requiresQuantity ?? false) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _VoucherField(
                    label: 'Cantidad',
                    compact: true,
                    child: TextField(
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: line.quantity,
                          selection: TextSelection.collapsed(
                            offset: line.quantity.length,
                          ),
                        ),
                      ),
                      onChanged: (value) => line.quantity = value,
                      style: _voucherInputTextStyle(tokens),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Cantidad',
                        hintStyle: _voucherHintTextStyle(tokens),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _VoucherField(
                  label: 'Comentario corto',
                  compact: true,
                  child: TextField(
                    controller: line.commentC,
                    onChanged: (_) => onChanged(),
                    style: _voucherInputTextStyle(tokens),
                    maxLines: 1,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Detalle',
                      hintStyle: _voucherHintTextStyle(tokens),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (concept != null &&
              (concept!.requiresUnit ||
                  concept!.requiresCompany ||
                  concept!.requiresDriver ||
                  concept!.requiresDestination ||
                  concept!.requiresSubconcept ||
                  concept!.requiresMode)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (concept!.requiresUnit)
                  SizedBox(
                    width: 170,
                    child: _VoucherField(
                      label: 'Unidad',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.unit,
                        items: unitOptions,
                        hint: 'Unidad',
                        onChanged: (value) {
                          line.unit = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                if (concept!.requiresCompany)
                  SizedBox(
                    width: 170,
                    child: _VoucherField(
                      label: 'Empresa',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.company,
                        items: companyOptions,
                        hint: 'Empresa',
                        onChanged: (value) {
                          line.company = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                if (concept!.requiresDriver)
                  SizedBox(
                    width: 170,
                    child: _VoucherField(
                      label: 'Chofer',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.driver,
                        items: driverOptions,
                        hint: 'Chofer',
                        onChanged: (value) {
                          line.driver = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                if (concept!.requiresDestination)
                  SizedBox(
                    width: 170,
                    child: _VoucherField(
                      label: 'Destino',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.destination,
                        items: _voucherDestinations,
                        hint: 'Destino',
                        onChanged: (value) {
                          line.destination = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                if (concept!.requiresSubconcept)
                  SizedBox(
                    width: 180,
                    child: _VoucherField(
                      label: 'Subconcepto',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.subconcept,
                        items: concept!.subconcepts,
                        hint: 'Subconcepto',
                        onChanged: (value) {
                          line.subconcept = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
                if (concept!.requiresMode)
                  SizedBox(
                    width: 160,
                    child: _VoucherField(
                      label: 'Modalidad',
                      compact: true,
                      child: _InlineDropdown(
                        value: line.mode,
                        items: concept!.modes,
                        hint: 'Modalidad',
                        onChanged: (value) {
                          line.mode = value;
                          onChanged();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final ValueChanged<String> onChanged;

  const _InlineDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedItems = <String>[
      if (value.trim().isNotEmpty && !items.contains(value)) value,
      ...items,
    ];
    final tokens = AreaThemeScope.of(context);
    return DropdownButtonHideUnderline(
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: tokens.primarySoft.withValues(alpha: 0.14),
          highlightColor: tokens.primarySoft.withValues(alpha: 0.08),
          hoverColor: tokens.primarySoft.withValues(alpha: 0.10),
          focusColor: Colors.transparent,
        ),
        child: DropdownButton<String>(
          isExpanded: true,
          value: resolvedItems.contains(value) ? value : null,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: const Color(0xFFFFFAF6),
          focusColor: Colors.transparent,
          menuMaxHeight: 320,
          hint: Text(
            hint,
            style: TextStyle(color: tokens.badgeText.withValues(alpha: 0.92)),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: tokens.primaryStrong,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.primaryStrong,
          ),
          items: resolvedItems
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
