import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/services_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/dicsa_logo_mark.dart';

const double _kDashboardTitleMinWidth = 430;

class DashboardPage extends StatefulWidget {
  final bool instantOpen;
  const DashboardPage({super.key, this.instantOpen = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.auth.signOut();
    // AuthGate te regresa a Login
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      background: const _DashboardBackground(),
      wrapBodyInGlass: false,
      animateHeaderSlots: false,
      animateBody: !widget.instantOpen,
      padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
      leadingBuilder: (_, __) => Row(
        children: [
          _HeaderIconButton(
            label: 'Viajes y Servicios',
            icon: Icons.local_shipping_outlined,
            onTap: () async {
              Navigator.of(
                context,
              ).push(appPageRoute(page: const ServicesPage()));
            },
          ),
        ],
      ),
      centerBuilder: (_, contentAnim) =>
          _DashboardBrand(contentAnim: contentAnim),
      trailingBuilder: (_, __) => _HeaderIconButton(
        label: 'Cerrar sesión',
        icon: Icons.logout,
        onTap: () => _logout(context),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(74, 8, 8, 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: const _ServicesSummaryPanel(),
        ),
      ),
    );
  }
}

class _DashboardBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  const _DashboardBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= _kDashboardTitleMinWidth;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.44)),
                  ),
                  child: const Center(
                    child: Hero(
                      tag: 'dicsa_d',
                      child: DicsaLogoD(size: 52, progress: 1.0),
                    ),
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B2B).withOpacity(0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Resumen Operativo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                        height: 1.0,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HeaderIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.03 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          onTap: enabled ? () => widget.onTap!() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 158,
            height: 48,
            transform: Matrix4.translationValues(0, highlighted ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withOpacity(0.24)
                  : Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? Colors.white.withOpacity(0.64)
                    : Colors.white.withOpacity(0.32),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: highlighted ? 30 : 18,
                  color: Colors.black.withOpacity(
                    enabled ? (highlighted ? 0.24 : 0.11) : 0.05,
                  ),
                  offset: Offset(0, highlighted ? 16 : 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(widget.icon, size: 18, color: const Color(0xFF0B2B2B)),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B72FF), Color(0xFF21C9A6), Color(0xFF52F59A)],
            ),
          ),
        ),
        Positioned(
          left: -250,
          top: -120,
          child: _blurCircle(
            700,
            const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF7ED0FF)],
            ),
          ),
        ),
        Positioned(
          right: -200,
          top: -80,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF4CFFB2), Color(0xFF00A3FF)],
            ),
          ),
        ),
        Positioned(
          left: -150,
          bottom: -250,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF0A84FF), Color(0xFF65FFE3)],
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -120,
          child: Container(
            width: 300,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(200),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00E0B0), Color(0xFF0080FF)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient g) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
    );
  }
}

class _ServicesSummaryPanel extends StatefulWidget {
  const _ServicesSummaryPanel();

  @override
  State<_ServicesSummaryPanel> createState() => _ServicesSummaryPanelState();
}

class _ServicesSummaryPanelState extends State<_ServicesSummaryPanel>
    with WidgetsBindingObserver {
  final _supa = Supabase.instance.client;
  bool _loadingDates = true;
  bool _loadingRows = true;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<DateTime> _datesWithServices = [];
  List<_ServiceSummaryItem> _items = [];
  Timer? _autoRefreshTimer;
  RealtimeChannel? _servicesRealtimeChannel;
  bool _refreshing = false;
  bool _pendingReload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload(showLoader: true);
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _servicesRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _requestReload();
    });

    _servicesRealtimeChannel?.unsubscribe();
    _servicesRealtimeChannel = _supa
        .channel('dashboard-services-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) {
            _requestReload();
          },
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(reload());
  }

  Future<void> reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      await _loadDates(showLoader: showLoader);
      if (_datesWithServices.isNotEmpty &&
          !_datesWithServices.contains(_selectedDate)) {
        final today = DateUtils.dateOnly(DateTime.now());
        _selectedDate = _datesWithServices.contains(today)
            ? today
            : _datesWithServices.last;
      }
      await _loadRowsForSelectedDate(showLoader: showLoader);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtStatus(String statusRaw) {
    return statusRaw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _fmtDateEs(DateTime d) {
    const weekdays = <String>[
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
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

    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd ${d.day} de $m de ${d.year}';
  }

  Future<void> _loadDates({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loadingDates = true);
    }
    final data = await _supa
        .from('services')
        .select('due_date')
        .not('due_date', 'is', null)
        .order('due_date');

    final set = <DateTime>{};
    for (final row in (data as List)) {
      final value = (row as Map<String, dynamic>)['due_date'];
      if (value == null) continue;
      set.add(DateUtils.dateOnly(_parseDate(value)));
    }

    final sorted = set.toList()..sort();
    setState(() {
      _datesWithServices = sorted;
      if (showLoader) _loadingDates = false;
    });
  }

  Future<void> _loadRowsForSelectedDate({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loadingRows = true);
    }
    final data = await _supa
        .from('v_services_grid')
        .select('*')
        .eq('due_date', _fmtDbDate(_selectedDate))
        .order('created_at');

    final rows = (data as List).cast<Map<String, dynamic>>();
    final mapped = rows.map((row) {
      final company =
          ((row['client_name'] ?? row['client_label'] ?? 'SIN EMPRESA')
                  as String)
              .trim();
      final operator =
          ((row['driver_name'] ??
                      row['driver_full_name'] ??
                      row['driver_employee_name'] ??
                      'SIN OPERADOR')
                  as String)
              .trim();
      final status = _fmtStatus(((row['status'] ?? '') as String).trim());
      return _ServiceSummaryItem(
        company: company.isEmpty ? 'SIN EMPRESA' : company,
        operator: operator.isEmpty ? 'SIN OPERADOR' : operator,
        status: status.isEmpty ? 'Sin estado' : status,
      );
    }).toList();

    setState(() {
      _items = mapped;
      if (showLoader) _loadingRows = false;
    });
  }

  DateTime? get _prevDate {
    final prev =
        _datesWithServices.where((d) => d.isBefore(_selectedDate)).toList()
          ..sort();
    return prev.isEmpty ? null : prev.last;
  }

  DateTime? get _nextDate {
    final next =
        _datesWithServices.where((d) => d.isAfter(_selectedDate)).toList()
          ..sort();
    return next.isEmpty ? null : next.first;
  }

  Future<void> _goToDate(DateTime date) async {
    setState(() => _selectedDate = DateUtils.dateOnly(date));
    await _loadRowsForSelectedDate(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final loading = (_loadingDates || _loadingRows) && _items.isEmpty;
    return Container(
      width: 620,
      height: 540,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.56),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.60)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NavGlassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                enabled: _prevDate != null,
                onTap: _prevDate == null ? null : () => _goToDate(_prevDate!),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Resumen de Viajes y Servicios',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtDateEs(_selectedDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_items.length} servicio${_items.length == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B6A68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _NavGlassButton(
                icon: Icons.arrow_forward_ios_rounded,
                enabled: _nextDate != null,
                onTap: _nextDate == null ? null : () => _goToDate(_nextDate!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.42),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'EMPRESA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'OPERADOR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'No hay servicios para esta fecha.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A4B49),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.company,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.operator,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _StateChip(text: item.status),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: Colors.white.withOpacity(0.36),
              disabledForegroundColor: const Color(
                0xFF2A4B49,
              ).withOpacity(0.72),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.send_outlined),
            label: const Text(
              'Enviar (Próximamente)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGlassButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavGlassButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.74)
              : Colors.white.withOpacity(0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.72)),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? const Color(0xFF0B2B2B) : const Color(0xFF779392),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String text;

  const _StateChip({required this.text});

  Color _bgFor(String v) {
    final key = v.toLowerCase().replaceAll(' ', '_');
    if (key.contains('cancelado')) return const Color(0xFFFFD8D8);
    if (key.contains('completado')) return const Color(0xFFD9E8FF);
    if (key.contains('en_ruta')) return const Color(0xFFD8FBF3);
    if (key.contains('confirmado')) return const Color(0xFFE1F9E9);
    return const Color(0xFFEAF1F1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _bgFor(text),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B2B2B),
        ),
      ),
    );
  }
}

class _ServiceSummaryItem {
  final String company;
  final String operator;
  final String status;

  const _ServiceSummaryItem({
    required this.company,
    required this.operator,
    required this.status,
  });
}
