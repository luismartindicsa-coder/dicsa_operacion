import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'commercial_area_chrome.dart';
import 'commercial_dashboard_page.dart';
import 'commercial_store.dart';
import 'commercial_theme.dart';

class CommercialDirectoryPage extends StatefulWidget {
  final bool instantOpen;

  const CommercialDirectoryPage({super.key, this.instantOpen = false});

  @override
  State<CommercialDirectoryPage> createState() =>
      _CommercialDirectoryPageState();
}

class _CommercialDirectoryPageState extends State<CommercialDirectoryPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _saving = false;
  bool _canReturnToDirection = false;
  bool _onlyAlerts = false;
  String _query = '';
  CommercialDirectoryBundle? _bundle;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDirectory());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
    });
  }

  Future<void> _loadDirectory() async {
    setState(() => _loading = true);
    final bundle = await CommercialStore.loadDirectory();
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _selectedId = bundle.accounts.isEmpty
          ? null
          : (_selectedId ?? bundle.accounts.first.id);
      _loading = false;
    });
  }

  Future<void> _createManualAccount() async {
    final draft = await showDialog<_CommercialAccountDraft>(
      context: context,
      builder: (_) => const _CommercialAccountDialog(),
    );
    if (draft == null) return;
    await _runSave(
      successMessage: 'Cuenta comercial creada.',
      action: () => CommercialStore.saveManualAccount(
        displayName: draft.displayName,
        kind: draft.kind,
        primaryChannel: draft.primaryChannel,
        businessType: draft.businessType,
        businessGroup: draft.businessGroup,
        status: draft.status,
        priority: draft.priority,
        notes: draft.notes,
      ),
    );
  }

  Future<void> _editAccountOverlay(CommercialDirectoryAccountRecord row) async {
    final draft = await showDialog<_CommercialAccountOverlayDraft>(
      context: context,
      builder: (_) => _CommercialAccountOverlayDialog(row: row),
    );
    if (draft == null) return;
    await _runSave(
      successMessage: 'Ficha comercial actualizada.',
      action: () => CommercialStore.saveAccountOverlay(
        row: row,
        status: draft.status,
        priority: draft.priority,
        notes: draft.notes,
      ),
    );
  }

  Future<void> _createContact(CommercialDirectoryAccountRecord row) async {
    final draft = await showDialog<_CommercialContactDraft>(
      context: context,
      builder: (_) => _CommercialContactDialog(accountName: row.displayName),
    );
    if (draft == null) return;
    await _runSave(
      successMessage: 'Contacto comercial guardado.',
      action: () async {
        final accountId = await CommercialStore.saveAccountOverlay(
          row: row,
          status: row.status,
          priority: row.priority,
          notes: row.notes,
        );
        await CommercialStore.saveContact(
          accountId: accountId,
          name: draft.name,
          role: draft.role,
          phone: draft.phone,
          email: draft.email,
          preferredChannel: draft.preferredChannel,
          notes: draft.notes,
          isPrimary: draft.isPrimary,
        );
      },
    );
  }

  Future<void> _createFollowUp(CommercialDirectoryAccountRecord row) async {
    final draft = await showDialog<_CommercialFollowUpDraft>(
      context: context,
      builder: (_) => _CommercialFollowUpDialog(accountName: row.displayName),
    );
    if (draft == null) return;
    await _runSave(
      successMessage: 'Seguimiento comercial registrado.',
      action: () async {
        final accountId = await CommercialStore.saveAccountOverlay(
          row: row,
          status: row.status,
          priority: row.priority,
          notes: row.notes,
        );
        await CommercialStore.saveFollowUp(
          accountId: accountId,
          interactionAt: draft.interactionAt,
          interactionType: draft.interactionType,
          summary: draft.summary,
          nextAction: draft.nextAction,
          nextFollowUpAt: draft.nextFollowUpAt,
          status: draft.status,
        );
      },
    );
  }

  Future<void> _runSave({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
      await _loadDirectory();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el cambio comercial. El origen operativo sigue intacto.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const CommercialDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final allRows =
        bundle?.accounts ?? const <CommercialDirectoryAccountRecord>[];
    final rows = allRows
        .where((row) {
          final q = _query.trim().toUpperCase();
          if (_onlyAlerts && row.activeAlertCount <= 0) return false;
          if (q.isEmpty) return true;
          return row.displayName.toUpperCase().contains(q) ||
              row.businessGroup.toUpperCase().contains(q) ||
              row.businessType.toUpperCase().contains(q);
        })
        .toList(growable: false);
    CommercialDirectoryAccountRecord? selected;
    for (final row in rows) {
      if (row.id == _selectedId) {
        selected = row;
        break;
      }
    }
    selected ??= rows.isNotEmpty ? rows.first : null;
    final contacts = selected == null
        ? const <CommercialContactRecord>[]
        : (bundle?.contactsByAccountId[selected.id] ?? const []);
    final followUps = selected == null
        ? const <CommercialFollowUpRecord>[]
        : (bundle?.followUpsByAccountId[selected.id] ?? const []);
    final alerts = selected == null
        ? const <CommercialAlertRecord>[]
        : (bundle?.alertsByAccountId[selected.id] ?? const []);

    return AreaThemeScope(
      tokens: commercialAreaTokens,
      child: Theme(
        data: buildCommercialAreaTheme(Theme.of(context)),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
              setState(() => _menuOpen = false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AppShell(
            background: const CommercialAreaBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => CommercialAreaHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _CommercialDirectoryHeaderBrand(
              title: 'Directorio Comercial',
              subtitle: 'Gestión de cuentas, segmentos y contexto comercial',
            ),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommercialAreaHeaderButton(
                  label: 'Recargar',
                  icon: Icons.refresh_rounded,
                  compact: true,
                  onTap: _loadDirectory,
                ),
                const SizedBox(width: 10),
                CommercialAreaHeaderButton(
                  label: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                  onTap: _logout,
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                      child: Column(
                        children: [
                          _DirectoryTopBar(
                            visibleCount: rows.length,
                            alertCount: allRows
                                .where((row) => row.activeAlertCount > 0)
                                .length,
                            onlyAlerts: _onlyAlerts,
                            onToggleAlerts: () =>
                                setState(() => _onlyAlerts = !_onlyAlerts),
                            onCreateAccount: _saving
                                ? null
                                : _createManualAccount,
                            onQueryChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 32,
                                  child: _DirectoryGlassPanel(
                                    child: _loading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : rows.isEmpty
                                        ? const _DirectoryEmptyList()
                                        : ListView.separated(
                                            itemCount: rows.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, index) {
                                              final row = rows[index];
                                              final selectedRow =
                                                  row.id == selected?.id;
                                              return _AccountTile(
                                                row: row,
                                                selected: selectedRow,
                                                onTap: () => setState(
                                                  () => _selectedId = row.id,
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 68,
                                  child: _DirectoryGlassPanel(
                                    child: selected == null
                                        ? const _EmptyDetail()
                                        : _DirectoryDetail(
                                            row: selected,
                                            contacts: contacts,
                                            followUps: followUps,
                                            alerts: alerts,
                                            saving: _saving,
                                            onEditOverlay: () =>
                                                _editAccountOverlay(selected!),
                                            onAddContact: () =>
                                                _createContact(selected!),
                                            onAddFollowUp: () =>
                                                _createFollowUp(selected!),
                                          ),
                                  ),
                                ),
                              ],
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
                    child: CommercialAreaSidePanel(
                      label: 'Desarrollo Comercial',
                      canReturnToDirection: _canReturnToDirection,
                      areaItems: [
                        CommercialAreaNavEntry(
                          icon: Icons.radar_rounded,
                          title: 'Radar Comercial',
                          subtitle: 'Alertas, materiales y contexto',
                          onTap: _openDashboard,
                        ),
                        const CommercialAreaNavEntry(
                          icon: Icons.badge_outlined,
                          title: 'Directorio Comercial',
                          subtitle: 'Cuentas, contactos y seguimiento',
                          accented: true,
                        ),
                      ],
                      accessItems: [
                        if (_canReturnToDirection)
                          CommercialAreaNavEntry(
                            icon: Icons.assessment_outlined,
                            title: 'Dashboard Dirección',
                            subtitle: 'Vista ejecutiva multiarea',
                            onTap: _openDirectionDashboard,
                          ),
                      ],
                    ),
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tone.withValues(alpha: 0.26)),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: tokens.onGlass,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: tokens.badgeText, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _CommercialDirectoryHeaderBrand extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CommercialDirectoryHeaderBrand({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 14),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.25,
                height: 1.0,
                color: Color(0xFFF0E9D1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: tokens.badgeText.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DirectoryTopBar extends StatelessWidget {
  final int visibleCount;
  final int alertCount;
  final bool onlyAlerts;
  final VoidCallback onToggleAlerts;
  final Future<void> Function()? onCreateAccount;
  final ValueChanged<String> onQueryChanged;

  const _DirectoryTopBar({
    required this.visibleCount,
    required this.alertCount,
    required this.onlyAlerts,
    required this.onToggleAlerts,
    required this.onCreateAccount,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5A000000),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1180;
              final searchField = TextField(
                onChanged: onQueryChanged,
                style: const TextStyle(color: Color(0xFFF3F1E8)),
                decoration: InputDecoration(
                  hintText: 'Buscar cuenta, segmento o tipo comercial',
                  hintStyle: const TextStyle(color: Color(0xADF3F1E8)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xADF3F1E8),
                  ),
                  filled: true,
                  fillColor: const Color(0x4D101713),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                ),
              );
              final metrics = [
                _MiniMetric(
                  label: 'Cuentas visibles',
                  value: '$visibleCount',
                  icon: Icons.business_center_outlined,
                  tone: const Color(0xFF56CCF2),
                ),
                _MiniMetric(
                  label: 'Con alertas',
                  value: '$alertCount',
                  icon: Icons.warning_amber_rounded,
                  tone: const Color(0xFFFF5B4D),
                ),
                const _MiniMetric(
                  label: 'Solo lectura origen',
                  value: 'SI',
                  icon: Icons.lock_outline_rounded,
                  tone: Color(0xFFF2C94C),
                ),
              ];
              final cta = _DirectoryPrimaryButton(
                label: 'Nueva cuenta',
                icon: Icons.add_rounded,
                onTap: onCreateAccount == null
                    ? null
                    : () => unawaited(onCreateAccount!()),
              );
              if (stacked) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final metric in metrics)
                          SizedBox(width: 160, child: metric),
                        cta,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 50, child: searchField),
                  const SizedBox(width: 16),
                  ...[
                    for (final metric in metrics) ...[
                      SizedBox(width: 150, child: metric),
                      const SizedBox(width: 12),
                    ],
                  ],
                  cta,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Solo con alertas',
                style: TextStyle(
                  color: tokens.onGlass,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: onlyAlerts,
                activeThumbColor: const Color(0xFF41D978),
                activeTrackColor: const Color(0x6641D978),
                onChanged: (_) => onToggleAlerts(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectoryPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _DirectoryPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF183826),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2D6E49)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF41D978), size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF3F1E8),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryGlassPanel extends StatelessWidget {
  final Widget child;

  const _DirectoryGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5A000000),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DirectoryEmptyList extends StatelessWidget {
  const _DirectoryEmptyList();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: Text(
        'No hay cuentas visibles con este filtro.',
        style: TextStyle(color: tokens.badgeText, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final CommercialDirectoryAccountRecord row;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0x99202F27) : const Color(0x7A1B2520),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF41D978)
                : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccountAvatar(label: row.displayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.displayName,
                    style: TextStyle(
                      color: tokens.onGlass,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    commercialKindLabel(row.kind),
                    style: TextStyle(
                      color: tokens.onGlass.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.kind == 'supplier' ? 'Proveedor' : 'Cuenta'} · ${row.businessGroup}',
                    style: TextStyle(
                      color: tokens.badgeText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(row.channel),
                      _pill(commercialFlowLabel(row.flow)),
                      _pill(commercialPriorityLabel(row.priority)),
                      _pill(row.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${row.contactCount} contactos · ${row.followUpCount} seguimientos',
                    style: TextStyle(color: tokens.badgeText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (row.activeAlertCount > 0)
                  _alertPill(
                    '${row.activeAlertCount} alertas',
                    row.highestAlertSeverity,
                  ),
                const SizedBox(height: 28),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.badgeText,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Builder(
      builder: (context) {
        final tokens = AreaThemeScope.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.badgeBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: tokens.badgeText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }

  Widget _alertPill(String label, String severity) {
    return Builder(
      builder: (context) {
        final tone = switch (severity) {
          'critica' => const Color(0xFFCC4B37),
          'atencion' => const Color(0xFFF0B33F),
          _ => const Color(0xFF70D68B),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone.withValues(alpha: 0.34)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final String label;

  const _AccountAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final letter = label.trim().isEmpty ? 'C' : label.trim()[0].toUpperCase();
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF5845B8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Color(0xFFF3F1E8),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _DirectoryDetail extends StatelessWidget {
  final CommercialDirectoryAccountRecord row;
  final List<CommercialContactRecord> contacts;
  final List<CommercialFollowUpRecord> followUps;
  final List<CommercialAlertRecord> alerts;
  final bool saving;
  final Future<void> Function() onEditOverlay;
  final Future<void> Function() onAddContact;
  final Future<void> Function() onAddFollowUp;

  const _DirectoryDetail({
    required this.row,
    required this.contacts,
    required this.followUps,
    required this.alerts,
    required this.saving,
    required this.onEditOverlay,
    required this.onAddContact,
    required this.onAddFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1180;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountAvatar(label: row.displayName),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.displayName,
                            style: TextStyle(
                              color: tokens.onGlass,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${commercialKindLabel(row.kind)} · ${row.businessType} · ${row.businessGroup}',
                            style: TextStyle(
                              color: tokens.badgeText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          CommercialAreaHeaderButton(
                            label: 'Editar ficha',
                            icon: Icons.edit_note_rounded,
                            onTap: saving ? null : onEditOverlay,
                          ),
                          CommercialAreaHeaderButton(
                            label: 'Agregar contacto',
                            icon: Icons.person_add_alt_1_rounded,
                            onTap: saving ? null : onAddContact,
                          ),
                          CommercialAreaHeaderButton(
                            label: 'Nuevo seguimiento',
                            icon: Icons.add_task_rounded,
                            onTap: saving ? null : onAddFollowUp,
                          ),
                        ],
                      ),
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      CommercialAreaHeaderButton(
                        label: 'Editar ficha',
                        icon: Icons.edit_note_rounded,
                        onTap: saving ? null : onEditOverlay,
                      ),
                      CommercialAreaHeaderButton(
                        label: 'Agregar contacto',
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: saving ? null : onAddContact,
                      ),
                      CommercialAreaHeaderButton(
                        label: 'Nuevo seguimiento',
                        icon: Icons.add_task_rounded,
                        onTap: saving ? null : onAddFollowUp,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, metricConstraints) {
                    final width = metricConstraints.maxWidth;
                    final metricWidth = compact
                        ? (width - 20) / 2
                        : (width - 50) / 6;
                    final metrics = [
                      _OperationalMetricCard(
                        label: 'Canal',
                        value: row.channel,
                        icon: Icons.layers_outlined,
                        tone: const Color(0xFF56CCF2),
                      ),
                      _OperationalMetricCard(
                        label: 'Flujo',
                        value: commercialFlowLabel(row.flow),
                        icon: Icons.swap_horiz_rounded,
                        tone: const Color(0xFF5AD1E6),
                      ),
                      _OperationalMetricCard(
                        label: 'Prioridad',
                        value: commercialPriorityLabel(row.priority),
                        icon: Icons.flag_outlined,
                        tone: const Color(0xFFF2C94C),
                      ),
                      _OperationalMetricCard(
                        label: 'Estado',
                        value: row.status,
                        icon: Icons.check_circle_outline_rounded,
                        tone: const Color(0xFF41D978),
                      ),
                      _OperationalMetricCard(
                        label: 'Origen',
                        value: row.sourceArea,
                        icon: Icons.source_outlined,
                        tone: const Color(0xFF7AB6FF),
                      ),
                      _OperationalMetricCard(
                        label: 'Alertas activas',
                        value: '${row.activeAlertCount} activas',
                        icon: Icons.warning_amber_rounded,
                        tone: const Color(0xFFFF5B4D),
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final metric in metrics)
                          SizedBox(width: metricWidth, child: metric),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, infoConstraints) {
                    final width = infoConstraints.maxWidth;
                    final infoWidth = compact ? width : (width - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: infoWidth,
                          child: _InfoSectionCard(
                            title: 'Nota comercial',
                            icon: Icons.description_outlined,
                            child: row.notes.trim().isEmpty
                                ? _EmptySectionAction(
                                    message:
                                        'Sin nota comercial capturada todavía.',
                                    buttonLabel: 'Agregar nota',
                                    onTap: saving ? null : onEditOverlay,
                                  )
                                : Text(
                                    row.notes,
                                    style: TextStyle(
                                      color: tokens.badgeText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: infoWidth,
                          child: _InfoSectionCard(
                            title: 'Contactos',
                            icon: Icons.groups_outlined,
                            child: contacts.isEmpty
                                ? _EmptySectionAction(
                                    message:
                                        'Todavía no hay contactos comerciales registrados para esta cuenta.',
                                    buttonLabel: 'Agregar contacto',
                                    onTap: saving ? null : onAddContact,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final contact in contacts.take(
                                        3,
                                      )) ...[
                                        Text(
                                          contact.name,
                                          style: TextStyle(
                                            color: tokens.onGlass,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${contact.role.isEmpty ? 'Sin rol' : contact.role} · ${contact.phone.isEmpty ? 'Sin teléfono' : contact.phone}',
                                          style: TextStyle(
                                            color: tokens.badgeText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (contact.email.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              contact.email,
                                              style: TextStyle(
                                                color: tokens.badgeText,
                                              ),
                                            ),
                                          ),
                                        if (contact != contacts.take(3).last)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: infoWidth,
                          child: _InfoSectionCard(
                            title: 'Seguimiento',
                            icon: Icons.trending_up_rounded,
                            child: followUps.isEmpty
                                ? _EmptySectionAction(
                                    message:
                                        'Todavía no hay seguimientos registrados. El origen sigue siendo solo lectura.',
                                    buttonLabel: 'Nuevo seguimiento',
                                    onTap: saving ? null : onAddFollowUp,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final item in followUps.take(3)) ...[
                                        Text(
                                          '${_formatDate(item.interactionAt)} · ${item.interactionType}',
                                          style: TextStyle(
                                            color: tokens.onGlass,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.summary,
                                          style: TextStyle(
                                            color: tokens.badgeText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (item != followUps.take(3).last)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _InfoSectionCard(
                  title: 'Alertas activas',
                  icon: Icons.warning_amber_rounded,
                  trailing: TextButton(
                    onPressed: () {},
                    child: const Text('Ver todas las alertas →'),
                  ),
                  child: alerts.isEmpty
                      ? Text(
                          'Esta cuenta no tiene alertas activas en este momento.',
                          style: TextStyle(color: tokens.badgeText),
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < alerts.length;
                              index++
                            ) ...[
                              _DirectoryAlertTile(alert: alerts[index]),
                              if (index < alerts.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _OperationalMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  const _OperationalMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tone.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: tone, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: tokens.badgeText, fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _InfoSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: tokens.badgeText, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptySectionAction extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final Future<void> Function()? onTap;

  const _EmptySectionAction({
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: tokens.badgeText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _DirectoryPrimaryButton(
          label: buttonLabel,
          icon: Icons.add_rounded,
          onTap: onTap == null ? null : () => unawaited(onTap!()),
        ),
      ],
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: Text(
        'Selecciona una cuenta para ver su contexto comercial.',
        style: TextStyle(
          color: tokens.badgeText,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _DirectoryAlertTile extends StatelessWidget {
  final CommercialAlertRecord alert;

  const _DirectoryAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = switch (alert.severity) {
      'critica' => const Color(0xFFCC4B37),
      'atencion' => const Color(0xFFF0B33F),
      _ => const Color(0xFF70D68B),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x99202F27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${alert.channel} · ${alert.materialLabel}',
                        style: TextStyle(
                          color: tokens.onGlass,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alert.message,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acción sugerida: ${alert.suggestedAction}',
                  style: TextStyle(color: tokens.badgeText, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (alert.deltaPercent != null)
                Text(
                  '${alert.deltaPercent!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                height: 40,
                child: CustomPaint(
                  painter: _DirectoryAlertSparklinePainter(color: tone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectoryAlertSparklinePainter extends CustomPainter {
  final Color color;

  const _DirectoryAlertSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.18),
      Offset(size.width * 0.14, size.height * 0.24),
      Offset(size.width * 0.28, size.height * 0.22),
      Offset(size.width * 0.42, size.height * 0.38),
      Offset(size.width * 0.56, size.height * 0.76),
      Offset(size.width * 0.7, size.height * 0.68),
      Offset(size.width * 0.84, size.height * 0.72),
      Offset(size.width, size.height * 0.64),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DirectoryAlertSparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CommercialAccountDraft {
  final String displayName;
  final String kind;
  final String primaryChannel;
  final String businessType;
  final String businessGroup;
  final String status;
  final String priority;
  final String notes;

  const _CommercialAccountDraft({
    required this.displayName,
    required this.kind,
    required this.primaryChannel,
    required this.businessType,
    required this.businessGroup,
    required this.status,
    required this.priority,
    required this.notes,
  });
}

class _CommercialAccountOverlayDraft {
  final String status;
  final String priority;
  final String notes;

  const _CommercialAccountOverlayDraft({
    required this.status,
    required this.priority,
    required this.notes,
  });
}

class _CommercialContactDraft {
  final String name;
  final String role;
  final String phone;
  final String email;
  final String preferredChannel;
  final String notes;
  final bool isPrimary;

  const _CommercialContactDraft({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.preferredChannel,
    required this.notes,
    required this.isPrimary,
  });
}

class _CommercialFollowUpDraft {
  final DateTime interactionAt;
  final String interactionType;
  final String summary;
  final String nextAction;
  final DateTime? nextFollowUpAt;
  final String status;

  const _CommercialFollowUpDraft({
    required this.interactionAt,
    required this.interactionType,
    required this.summary,
    required this.nextAction,
    required this.nextFollowUpAt,
    required this.status,
  });
}

class _CommercialAccountDialog extends StatefulWidget {
  const _CommercialAccountDialog();

  @override
  State<_CommercialAccountDialog> createState() =>
      _CommercialAccountDialogState();
}

class _CommercialAccountDialogState extends State<_CommercialAccountDialog> {
  late final TextEditingController _displayNameC;
  late final TextEditingController _notesC;
  String _kind = 'prospect';
  String _channel = 'menudeo';
  String _businessType = 'prospect';
  String _businessGroup = 'manual_prospect';
  String _status = 'prospecto';
  String _priority = 'media';

  @override
  void initState() {
    super.initState();
    _displayNameC = TextEditingController();
    _notesC = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _save() {
    final name = _displayNameC.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _CommercialAccountDraft(
        displayName: name,
        kind: _kind,
        primaryChannel: _channel,
        businessType: _businessType,
        businessGroup: _businessGroup,
        status: _status,
        priority: _priority,
        notes: _notesC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CommercialDialogShell(
      title: 'Nueva cuenta comercial',
      subtitle:
          'Crea una ficha propia de Desarrollo Comercial sin tocar el origen operativo.',
      onSave: _save,
      child: Column(
        children: [
          _dialogTextField(
            controller: _displayNameC,
            label: 'Nombre visible',
            hintText: 'Ej. Papelera del Norte',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogDropdown(
                  label: 'Tipo de cuenta',
                  value: _kind,
                  items: kCommercialKindOptions,
                  labelBuilder: commercialKindLabel,
                  onChanged: (value) => setState(() => _kind = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Canal principal',
                  value: _channel,
                  items: kCommercialChannelOptions,
                  onChanged: (value) => setState(() => _channel = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogDropdown(
                  label: 'Tipo comercial',
                  value: _businessType,
                  items: kCommercialBusinessTypeOptions,
                  onChanged: (value) => setState(() => _businessType = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Grupo comparable',
                  value: _businessGroup,
                  items: kCommercialBusinessGroupOptions,
                  onChanged: (value) => setState(() => _businessGroup = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogDropdown(
                  label: 'Estado',
                  value: _status,
                  items: kCommercialAccountStatusOptions,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Prioridad',
                  value: _priority,
                  items: kCommercialPriorityOptions,
                  labelBuilder: commercialPriorityLabel,
                  onChanged: (value) => setState(() => _priority = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dialogTextField(
            controller: _notesC,
            label: 'Nota comercial',
            hintText:
                'Contexto, oportunidad, perfil de negociación, siguiente ángulo.',
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}

class _CommercialAccountOverlayDialog extends StatefulWidget {
  final CommercialDirectoryAccountRecord row;

  const _CommercialAccountOverlayDialog({required this.row});

  @override
  State<_CommercialAccountOverlayDialog> createState() =>
      _CommercialAccountOverlayDialogState();
}

class _CommercialAccountOverlayDialogState
    extends State<_CommercialAccountOverlayDialog> {
  late final TextEditingController _notesC;
  late String _status;
  late String _priority;

  @override
  void initState() {
    super.initState();
    _notesC = TextEditingController(text: widget.row.notes);
    _status = widget.row.status;
    _priority = widget.row.priority;
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _CommercialAccountOverlayDraft(
        status: _status,
        priority: _priority,
        notes: _notesC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return _CommercialDialogShell(
      title: 'Ficha comercial',
      subtitle:
          'Ajusta seguimiento propio sin alterar Menudeo, Mayoreo o Compras.',
      onSave: _save,
      child: Column(
        children: [
          _dialogReadOnlyField(label: 'Cuenta', value: row.displayName),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogReadOnlyField(
                  label: 'Origen',
                  value: row.sourceArea,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogReadOnlyField(
                  label: 'Grupo comparable',
                  value: row.businessGroup,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogDropdown(
                  label: 'Estado comercial',
                  value: _status,
                  items: kCommercialAccountStatusOptions,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Prioridad',
                  value: _priority,
                  items: kCommercialPriorityOptions,
                  labelBuilder: commercialPriorityLabel,
                  onChanged: (value) => setState(() => _priority = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dialogTextField(
            controller: _notesC,
            label: 'Nota comercial',
            hintText:
                'Aprendizajes, sensibilidad de precio, relación, riesgo, oportunidad.',
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}

class _CommercialContactDialog extends StatefulWidget {
  final String accountName;

  const _CommercialContactDialog({required this.accountName});

  @override
  State<_CommercialContactDialog> createState() =>
      _CommercialContactDialogState();
}

class _CommercialContactDialogState extends State<_CommercialContactDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _roleC;
  late final TextEditingController _phoneC;
  late final TextEditingController _emailC;
  late final TextEditingController _notesC;
  String _preferredChannel = 'whatsapp';
  bool _isPrimary = true;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController();
    _roleC = TextEditingController();
    _phoneC = TextEditingController();
    _emailC = TextEditingController();
    _notesC = TextEditingController();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _roleC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameC.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _CommercialContactDraft(
        name: name,
        role: _roleC.text.trim(),
        phone: _phoneC.text.trim(),
        email: _emailC.text.trim(),
        preferredChannel: _preferredChannel,
        notes: _notesC.text.trim(),
        isPrimary: _isPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CommercialDialogShell(
      title: 'Nuevo contacto',
      subtitle:
          'Contacto comercial propio para seguimiento de ${widget.accountName}.',
      onSave: _save,
      child: Column(
        children: [
          _dialogTextField(
            controller: _nameC,
            label: 'Nombre',
            hintText: 'Ej. José Luis',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogTextField(
                  controller: _roleC,
                  label: 'Rol',
                  hintText: 'Compras, logística, dueño, recepción',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Canal preferido',
                  value: _preferredChannel,
                  items: kCommercialInteractionTypeOptions,
                  onChanged: (value) =>
                      setState(() => _preferredChannel = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogTextField(
                  controller: _phoneC,
                  label: 'Teléfono',
                  hintText: 'Ej. 81 0000 0000',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogTextField(
                  controller: _emailC,
                  label: 'Correo',
                  hintText: 'Ej. contacto@empresa.com',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isPrimary,
            onChanged: (value) => setState(() => _isPrimary = value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: const Color(0xFF41D978),
            activeTrackColor: const Color(0x6641D978),
            title: Text(
              'Marcar como contacto principal',
              style: TextStyle(
                color: AreaThemeScope.of(context).onGlass,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _dialogTextField(
            controller: _notesC,
            label: 'Notas',
            hintText: 'Horario, tono, restricciones, forma de entrada.',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _CommercialFollowUpDialog extends StatefulWidget {
  final String accountName;

  const _CommercialFollowUpDialog({required this.accountName});

  @override
  State<_CommercialFollowUpDialog> createState() =>
      _CommercialFollowUpDialogState();
}

class _CommercialFollowUpDialogState extends State<_CommercialFollowUpDialog> {
  late final TextEditingController _summaryC;
  late final TextEditingController _nextActionC;
  DateTime _interactionAt = DateTime.now();
  DateTime? _nextFollowUpAt = DateTime.now().add(const Duration(days: 3));
  String _interactionType = 'llamada';
  String _status = 'abierto';

  @override
  void initState() {
    super.initState();
    _summaryC = TextEditingController();
    _nextActionC = TextEditingController();
  }

  @override
  void dispose() {
    _summaryC.dispose();
    _nextActionC.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  void _save() {
    final summary = _summaryC.text.trim();
    if (summary.isEmpty) return;
    Navigator.of(context).pop(
      _CommercialFollowUpDraft(
        interactionAt: _interactionAt,
        interactionType: _interactionType,
        summary: summary,
        nextAction: _nextActionC.text.trim(),
        nextFollowUpAt: _nextFollowUpAt,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CommercialDialogShell(
      title: 'Nuevo seguimiento',
      subtitle: 'Registra el contacto comercial con ${widget.accountName}.',
      onSave: _save,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dialogDropdown(
                  label: 'Tipo de interacción',
                  value: _interactionType,
                  items: kCommercialInteractionTypeOptions,
                  onChanged: (value) =>
                      setState(() => _interactionType = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDropdown(
                  label: 'Estado',
                  value: _status,
                  items: kCommercialFollowUpStatusOptions,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dialogDateField(
                  label: 'Fecha de interacción',
                  value: _interactionAt,
                  onTap: () => _pickDate(
                    initialDate: _interactionAt,
                    onPicked: (value) {
                      if (value == null) return;
                      setState(() => _interactionAt = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dialogDateField(
                  label: 'Próximo seguimiento',
                  value: _nextFollowUpAt,
                  emptyLabel: 'Sin fecha',
                  onTap: () => _pickDate(
                    initialDate: _nextFollowUpAt ?? DateTime.now(),
                    onPicked: (value) =>
                        setState(() => _nextFollowUpAt = value),
                  ),
                  onClear: _nextFollowUpAt == null
                      ? null
                      : () => setState(() => _nextFollowUpAt = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dialogTextField(
            controller: _summaryC,
            label: 'Resumen',
            hintText: 'Qué se habló, sensibilidad de precio, volumen, interés.',
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _dialogTextField(
            controller: _nextActionC,
            label: 'Siguiente acción',
            hintText: 'Llamar, cotizar, visitar, validar proveedor alterno.',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _CommercialDialogShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onSave;

  const _CommercialDialogShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildCommercialAreaTheme(Theme.of(context)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: kCommercialInk),
        child: IconTheme(
          data: const IconThemeData(color: kCommercialInk),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                decoration: BoxDecoration(
                  color: const Color(0xF018211D),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5A000000),
                      blurRadius: 54,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: kCommercialInk,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Color(0xD9F3F1E8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: kCommercialInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      child,
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Color(0xD9F3F1E8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF183826),
                              foregroundColor: const Color(0xFFF3F1E8),
                              side: const BorderSide(color: Color(0xFF2D6E49)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: onSave,
                            icon: const Icon(
                              Icons.save_rounded,
                              color: Color(0xFF41D978),
                            ),
                            label: const Text('Guardar'),
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
      ),
    );
  }
}

Widget _dialogTextField({
  required TextEditingController controller,
  required String label,
  String? hintText,
  int maxLines = 1,
}) {
  return Builder(
    builder: (context) {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: kCommercialInk,
        style: const TextStyle(
          color: kCommercialInk,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(color: Color(0xD9F3F1E8)),
          floatingLabelStyle: const TextStyle(color: Color(0xFFF3F1E8)),
          hintStyle: const TextStyle(color: Color(0x99F3F1E8)),
          filled: true,
          fillColor: const Color(0x66101713),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF7C8F82)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF7C8F82)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2D6E49)),
          ),
        ),
      );
    },
  );
}

Widget _dialogReadOnlyField({required String label, required String value}) {
  return Builder(
    builder: (context) {
      final tokens = AreaThemeScope.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x66101713),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xD9F3F1E8), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? 'Sin dato' : value,
              style: const TextStyle(
                color: kCommercialInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _dialogDropdown({
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
  String Function(String value)? labelBuilder,
}) {
  return Builder(
    builder: (context) {
      final tokens = AreaThemeScope.of(context);
      return DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF1B221F),
        iconEnabledColor: kCommercialInk,
        style: const TextStyle(
          color: kCommercialInk,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xD9F3F1E8)),
          floatingLabelStyle: const TextStyle(color: Color(0xFFF3F1E8)),
          filled: true,
          fillColor: const Color(0x66101713),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: tokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: tokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2D6E49)),
          ),
        ),
        selectedItemBuilder: (context) => [
          for (final item in items)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                labelBuilder?.call(item) ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kCommercialInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
        items: [
          for (final item in items)
            DropdownMenuItem<String>(
              value: item,
              child: Text(
                labelBuilder?.call(item) ?? item,
                style: const TextStyle(
                  color: kCommercialInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
        onChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      );
    },
  );
}

Widget _dialogDateField({
  required String label,
  required DateTime? value,
  required VoidCallback onTap,
  VoidCallback? onClear,
  String emptyLabel = 'Seleccionar fecha',
}) {
  return Builder(
    builder: (context) {
      final tokens = AreaThemeScope.of(context);
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x66101713),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xD9F3F1E8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value == null ? emptyLabel : _formatDialogDate(value),
                      style: const TextStyle(
                        color: kCommercialInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded, color: kCommercialInk),
                ),
              const Icon(Icons.calendar_month_rounded, color: kCommercialInk),
            ],
          ),
        ),
      );
    },
  );
}

String _formatDialogDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
