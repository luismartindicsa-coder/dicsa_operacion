import 'dart:ui';

import 'package:flutter/material.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import 'human_resources_theme.dart';

class HumanResourcesMockPage extends StatefulWidget {
  const HumanResourcesMockPage({super.key});

  @override
  State<HumanResourcesMockPage> createState() => _HumanResourcesMockPageState();
}

class _HumanResourcesMockPageState extends State<HumanResourcesMockPage> {
  Future<void> _logout() async {
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
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      background: const _HrMockBackground(),
      wrapBodyInGlass: false,
      animateHeaderSlots: false,
      headerBodySpacing: 8,
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 20),
      leadingBuilder: (_, _) => _HrHeaderButton(
        label: 'Volver',
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      centerBuilder: (_, _) => const _HrBrand(),
      trailingBuilder: (_, _) => _HrHeaderButton(
        label: 'Cerrar sesión',
        icon: Icons.logout_rounded,
        onTap: _logout,
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: _HrMockBody(),
      ),
    );
  }
}

class _HrBrand extends StatelessWidget {
  const _HrBrand();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              DicsaLogoD(size: 34, progress: 1),
              SizedBox(width: 12),
              Text(
                'Recursos Humanos',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HrHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HrHeaderButton> createState() => _HrHeaderButtonState();
}

class _HrHeaderButtonState extends State<_HrHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hovered ? 1.02 : 1,
        child: TextButton.icon(
          onPressed: widget.onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: _hovered ? 0.22 : 0.16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
            ),
            shadowColor: Colors.black.withValues(alpha: 0.18),
            elevation: _hovered ? 8 : 2,
          ),
          icon: Icon(widget.icon, size: 18),
          label: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _HrMockBody extends StatelessWidget {
  const _HrMockBody();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HrHero(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1180;
                  final medium = constraints.maxWidth >= 860;
                  final cardWidth = wide
                      ? (constraints.maxWidth - 32) / 3
                      : (medium ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: const [
                      _HrMetricCard(
                        width: 0,
                        icon: Icons.badge_rounded,
                        title: 'Headcount activo',
                        value: '148',
                        detail: '136 operativos · 12 administrativos',
                      ),
                      _HrMetricCard(
                        width: 0,
                        icon: Icons.event_available_rounded,
                        title: 'Asistencia del día',
                        value: '94.6%',
                        detail: '140 presentes · 8 incidencias',
                      ),
                      _HrMetricCard(
                        width: 0,
                        icon: Icons.payments_rounded,
                        title: 'Nómina estimada',
                        value: '\$428,560',
                        detail: 'Periodo semanal en preparación',
                      ),
                    ],
                  )._withSizedMetricWidths(cardWidth);
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1120;
                  if (stacked) {
                    return const Column(
                      children: [
                        _HrWorkspaceCard(
                          title: 'Seguimiento del Día',
                          child: _HrTimeline(),
                        ),
                        SizedBox(height: 16),
                        _HrWorkspaceCard(
                          title: 'Incidencias Abiertas',
                          child: _HrIncidents(),
                        ),
                        SizedBox(height: 16),
                        _HrWorkspaceCard(
                          title: 'Próximos Procesos',
                          child: _HrNextProcesses(),
                        ),
                      ],
                    );
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
                        child: _HrWorkspaceCard(
                          title: 'Seguimiento del Día',
                          child: _HrTimeline(),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _HrWorkspaceCard(
                              title: 'Incidencias Abiertas',
                              child: _HrIncidents(),
                            ),
                            SizedBox(height: 16),
                            _HrWorkspaceCard(
                              title: 'Próximos Procesos',
                              child: _HrNextProcesses(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Wrap {
  Widget _withSizedMetricWidths(double width) {
    final wrappedChildren = children
        .map(
          (child) => child is _HrMetricCard
              ? SizedBox(width: width, child: child.copyWithWidth(width))
              : SizedBox(width: width, child: child),
        )
        .toList(growable: false);
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      children: wrappedChildren,
    );
  }
}

class _HrHero extends StatelessWidget {
  const _HrHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.86),
            humanResourcesAreaTokens.primarySoft.withValues(alpha: 0.94),
            const Color(0xFFE4D6FF).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            offset: const Offset(0, 18),
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final buttonWidth = stacked ? constraints.maxWidth : 168.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 18,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: kHumanResourcesPanelAccentGradient,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.groups_2_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mock visual de Recursos Humanos',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: kHumanResourcesSurfaceText,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Esta vista nos sirve para comprobar que RH puede vivir en una familia morada propia, claramente distinta a Menudeo y a Operación, pero sin romper el contrato glass de DICSA.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kHumanResourcesMutedText,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HrActionTile(
                    width: buttonWidth,
                    icon: Icons.schedule_rounded,
                    label: 'Asistencia',
                  ),
                  _HrActionTile(
                    width: buttonWidth,
                    icon: Icons.payments_rounded,
                    label: 'Nómina',
                  ),
                  _HrActionTile(
                    width: buttonWidth,
                    icon: Icons.warning_amber_rounded,
                    label: 'Incidencias',
                  ),
                  _HrActionTile(
                    width: buttonWidth,
                    icon: Icons.badge_rounded,
                    label: 'Plantilla',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HrActionTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;

  const _HrActionTile({
    required this.width,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: kHumanResourcesPanelGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
      ),
      child: Row(
        children: [
          Icon(icon, color: humanResourcesAreaTokens.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kHumanResourcesSurfaceText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrMetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _HrMetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  _HrMetricCard copyWithWidth(double width) {
    return _HrMetricCard(
      width: width,
      icon: icon,
      title: title,
      value: value,
      detail: detail,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == 0 ? null : width,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.82),
            humanResourcesAreaTokens.primarySoft.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: humanResourcesAreaTokens.primary, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: kHumanResourcesMutedText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: kHumanResourcesSurfaceText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kHumanResourcesMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrWorkspaceCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _HrWorkspaceCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kHumanResourcesSurfaceText,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _HrTimeline extends StatelessWidget {
  const _HrTimeline();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('08:00', 'Entrada general validada', '143 registros sincronizados'),
      ('10:15', 'Incidencia abierta', 'Falta justificante de 2 operadores'),
      ('12:30', 'Corte de asistencia', 'Se envió resumen a supervisión'),
      ('15:45', 'Pre-nómina calculada', '7 incidencias impactan el periodo'),
    ];
    return Column(
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: humanResourcesAreaTokens.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: humanResourcesAreaTokens.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: humanResourcesAreaTokens.primarySoft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: kHumanResourcesSurfaceText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kHumanResourcesMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (item != items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HrIncidents extends StatelessWidget {
  const _HrIncidents();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Retardo recurrente', '3 personas · Patio norte'),
      ('Permiso pendiente', '2 solicitudes por aprobar'),
      ('Falta sin justificar', '1 caso crítico del turno B'),
    ];
    return Column(
      children: [
        for (final item in items) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.84),
                  humanResourcesAreaTokens.primarySoft.withValues(alpha: 0.92),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kHumanResourcesSurfaceText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kHumanResourcesMutedText,
                  ),
                ),
              ],
            ),
          ),
          if (item != items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HrNextProcesses extends StatelessWidget {
  const _HrNextProcesses();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Prenómina semanal', 'Jueves · 18:00'),
      ('Exportación IMSS', 'Viernes · 09:30'),
      ('Cierre de incidencias', 'Viernes · 14:00'),
    ];
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: humanResourcesAreaTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kHumanResourcesSurfaceText,
                  ),
                ),
              ),
              Text(
                row.$2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kHumanResourcesMutedText,
                ),
              ),
            ],
          ),
          if (row != rows.last) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _HrMockBackground extends StatelessWidget {
  const _HrMockBackground();

  @override
  Widget build(BuildContext context) {
    Widget blurCircle(double size, Gradient gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: size * 0.12,
              spreadRadius: size * 0.02,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: SizedBox(width: size, height: size),
      );
    }

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A0F2F),
                const Color(0xFF2B114F).withValues(alpha: 0.96),
                const Color(0xFF4B1E7C).withValues(alpha: 0.92),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -220,
          top: -120,
          child: blurCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.18),
                const Color(0xFF7D5BC9).withValues(alpha: 0.20),
              ],
            ),
          ),
        ),
        Positioned(
          right: -140,
          top: -80,
          child: blurCircle(
            560,
            LinearGradient(
              colors: [
                const Color(0xFF9365F0).withValues(alpha: 0.72),
                const Color(0xFF4B1E7C).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 80,
          bottom: -260,
          child: blurCircle(
            700,
            LinearGradient(
              colors: [
                const Color(0xFF5B31A6).withValues(alpha: 0.48),
                const Color(0xFFE5D9FF).withValues(alpha: 0.24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
