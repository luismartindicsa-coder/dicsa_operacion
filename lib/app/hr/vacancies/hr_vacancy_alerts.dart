import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../../shared/ui_contract_core/theme/contract_buttons.dart';
import '../../shared/ui_contract_core/theme/glass_styles.dart';
import '../human_resources_area_chrome.dart';
import '../human_resources_theme.dart';
import '../personnel/hr_job_positions.dart';
import 'hr_staffing.dart';

class HrVacancyPendingButton extends StatefulWidget {
  final Future<HrStaffingSnapshot> Function()? load;
  const HrVacancyPendingButton({super.key, this.load});
  @override
  State<HrVacancyPendingButton> createState() => _HrVacancyPendingButtonState();
}

class _HrVacancyPendingButtonState extends State<HrVacancyPendingButton> {
  Timer? _timer;
  int? _count;
  bool _loading = false, _open = false, _failed = false, _reloadPending = false;
  Future<HrStaffingSnapshot> _fetch() =>
      widget.load?.call() ??
      HrStaffingRepository(Supabase.instance.client).load();
  @override
  void initState() {
    super.initState();
    hrStaffingChanges.addListener(_changed);
    _changed();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _changed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    hrStaffingChanges.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    _reloadPending = false;
    try {
      final s = await _fetch();
      if (mounted) {
        setState(() {
          _count = s.vacancyCount;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
      if (_reloadPending && mounted) unawaited(_refresh());
    }
  }

  Future<void> _show() async {
    if (_open) return;
    _open = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AreaThemeScope(
          tokens: humanResourcesAreaTokens,
          child: HrVacancyAlertsDialog(load: _fetch),
        ),
      );
    } finally {
      _open = false;
    }
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => LifecycleRefreshScope(
    onResume: _refresh,
    child: Tooltip(
      message: _failed
          ? 'No se pudieron actualizar las vacantes. Abre para consultar de nuevo.'
          : '${_count ?? '…'} vacantes por cubrir',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HumanResourcesAreaHeaderButton(
            label: 'Pendientes',
            icon: Icons.notifications_none_rounded,
            onTap: _show,
          ),
          Positioned(
            top: -3,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: humanResourcesAreaTokens.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _failed ? '!' : _count?.toString() ?? '…',
                  key: const ValueKey('vacancyBadge'),
                  style: TextStyle(
                    color: humanResourcesAreaTokens.primaryStrong,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HrVacancyAlertsDialog extends StatefulWidget {
  final Future<HrStaffingSnapshot> Function() load;
  const HrVacancyAlertsDialog({super.key, required this.load});
  @override
  State<HrVacancyAlertsDialog> createState() => _HrVacancyAlertsDialogState();
}

class _HrVacancyAlertsDialogState extends State<HrVacancyAlertsDialog> {
  HrStaffingSnapshot? _snapshot;
  String? _error;
  bool _loading = false, _reloadPending = false;
  final _search = TextEditingController();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    hrStaffingChanges.addListener(_changed);
    _changed();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _changed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    hrStaffingChanges.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    _reloadPending = false;
    try {
      final snapshot = await widget.load();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudieron actualizar las vacantes. Los datos anteriores pueden haber cambiado.',
        );
      }
    } finally {
      _loading = false;
      if (_reloadPending && mounted) unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final rows =
        _snapshot?.pending
            .where(
              (row) => hrJobPositionKey(
                '${row.company} ${row.position}',
              ).contains(hrJobPositionKey(_search.text)),
            )
            .toList() ??
        [];
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContractDialogShell(
        child: SizedBox(
          width: 680,
          height: 600,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Vacantes por cubrir',
                        style: TextStyle(
                          color: t.onGlass,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                      icon: Icon(Icons.close, color: t.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_snapshot != null)
                  Text(
                    '${_snapshot!.vacancyCount} ${_snapshot!.vacancyCount == 1 ? 'vacante' : 'vacantes'} · ${_snapshot!.pending.length} ${_snapshot!.pending.length == 1 ? 'puesto' : 'puestos'} por empresa',
                    style: TextStyle(color: t.badgeText),
                  ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('vacancyAlertSearch'),
                  controller: _search,
                  autofocus: true,
                  style: TextStyle(color: t.onGlass),
                  onChanged: (_) => setState(() {}),
                  decoration: contractGlassFieldDecoration(
                    context,
                    hintText: 'Buscar empresa o puesto',
                    prefixIcon: Icon(Icons.search, color: t.accent),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!, style: TextStyle(color: t.onGlass)),
                  ),
                Expanded(
                  child: _snapshot == null && _error == null
                      ? Center(
                          child: CircularProgressIndicator(color: t.accent),
                        )
                      : rows.isEmpty
                      ? Center(
                          child: Text(
                            _error != null
                                ? 'No hay información disponible.'
                                : _snapshot!.targets.isEmpty
                                ? 'Configura la plantilla en Vacantes para comenzar.'
                                : _snapshot!.pending.isEmpty
                                ? 'La plantilla está cubierta.'
                                : 'No hay coincidencias.',
                            style: TextStyle(color: t.onGlass),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return ContractGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: t.accent,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.company,
                                          style: TextStyle(
                                            color: t.badgeText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          row.position,
                                          style: TextStyle(
                                            color: t.onGlass,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${row.filled} activos de ${row.requiredCount} requeridos',
                                          style: TextStyle(color: t.badgeText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Faltan ${row.vacant}',
                                    style: TextStyle(
                                      color: t.onGlass,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: contractSecondaryButtonStyle(context),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
