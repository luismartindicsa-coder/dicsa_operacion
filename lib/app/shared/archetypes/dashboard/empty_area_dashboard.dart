import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/auth_access.dart';
import '../../../auth/auth_navigation.dart';
import '../../../dashboard/general_dashboard_page.dart';
import '../../app_shell.dart';
import '../../dicsa_logo_mark.dart';
import '../../page_routes.dart';
import '../../ui_contract_core/theme/area_theme_scope.dart';
import '../../ui_contract_core/theme/contract_tokens.dart';
import '../../ui_contract_core/theme/glass_styles.dart';

class EmptyAreaDashboardPage extends StatefulWidget {
  final bool instantOpen;
  final EmptyAreaDashboardConfig config;

  const EmptyAreaDashboardPage({
    super.key,
    this.instantOpen = false,
    required this.config,
  });

  @override
  State<EmptyAreaDashboardPage> createState() => _EmptyAreaDashboardPageState();
}

typedef EmptyAreaDashboardSidePanelBuilder =
    Widget Function(
      BuildContext context,
      EmptyAreaDashboardConfig config,
      bool canReturnToDirection,
      List<DashboardNavAction> accessItems,
      List<DashboardNavAction> areaItems,
    );

typedef EmptyAreaDashboardWorkspaceBuilder =
    Widget Function(
      BuildContext context,
      EmptyAreaDashboardConfig config,
      double width,
    );

class _EmptyAreaDashboardPageState extends State<EmptyAreaDashboardPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  AuthResolvedProfile? _profile;

  EmptyAreaDashboardConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _resolveNavigationAccess();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_menuOpen && mounted) {
      setState(() => _menuOpen = false);
    }
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final headerActions = <DashboardHeaderAction>[
      ..._config.headerActions.where(
        (action) => action.isVisible?.call(_profile) ?? true,
      ),
      DashboardHeaderAction(
        label: 'Cerrar sesión',
        icon: Icons.logout_rounded,
        onTap: _logout,
      ),
    ];

    final accessItems = <DashboardNavAction>[
      if (_canReturnToDirection)
        DashboardNavAction(
          title: 'Dashboard Dirección',
          subtitle: 'Vista ejecutiva multiarea',
          icon: Icons.assessment_outlined,
          onTap: _openDirectionDashboard,
        ),
      ..._config.accessItems.where(
        (action) => action.isVisible?.call(_profile) ?? true,
      ),
    ];

    final areaItems = _config.areaItems.where(
      (action) => action.isVisible?.call(_profile) ?? true,
    );

    return AreaThemeScope(
      tokens: _config.tokens,
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
          background: _AreaDashboardBackground(config: _config),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _AreaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => _AreaHeaderBrand(config: _config),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < headerActions.length; index++) ...[
                _AreaHeaderButton(
                  label: headerActions[index].label,
                  icon: headerActions[index].icon,
                  compact: headerActions[index].compact,
                  onTap: () => _runAction(headerActions[index].onTap),
                ),
                if (index != headerActions.length - 1)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          child: Stack(
            children: [
              _AreaDashboardBody(config: _config),
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
                  child:
                      _config.sidePanelBuilder?.call(
                        context,
                        _config,
                        _canReturnToDirection,
                        accessItems,
                        areaItems.toList(growable: false),
                      ) ??
                      _AreaSidePanel(
                        config: _config.copyWith(
                          areaItems: areaItems.toList(growable: false),
                        ),
                        canReturnToDirection: _canReturnToDirection,
                        accessItems: accessItems,
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

class EmptyAreaDashboardConfig {
  final String dashboardLabel;
  final String sidePanelLabel;
  final Color? headerTitleColor;
  final String heroEyebrow;
  final String heroTitle;
  final String heroSubtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final String contractTitle;
  final String contractSubtitle;
  final String contractFootnote;
  final Color? heroCardBorderColor;
  final Gradient? heroCardGradient;
  final Color? heroEyebrowColor;
  final Color? heroTitleColor;
  final Color? heroSubtitleColor;
  final Color? workspaceBodyColor;
  final Color? emptyStateSurfaceColor;
  final Color? emptyStateBorderColor;
  final Color? emptyStateIconColor;
  final Color? emptyStateBodyColor;
  final Color? contractPanelColor;
  final Color? contractActionColor;
  final Color? contractActionHoverColor;
  final Color? contractActionIconColor;
  final Color? contractFootnoteColor;
  final Color? placeholderCardColor;
  final Color? placeholderCardIconColor;
  final Color? placeholderCardDescriptionColor;
  final Color? placeholderCardArrowColor;
  final ContractAreaTokens tokens;
  final Color ink;
  final Color mutedInk;
  final Gradient heroGradient;
  final Gradient panelGradient;
  final Gradient accentGradient;
  final List<Color> backgroundGradientColors;
  final List<Color> topLeftBlobColors;
  final List<Color> topRightBlobColors;
  final List<Color> bottomLeftBlobColors;
  final List<Color> pillarGradientColors;
  final List<DashboardNavAction> areaItems;
  final List<DashboardNavAction> accessItems;
  final List<DashboardHeaderAction> headerActions;
  final List<DashboardPlaceholderCard> placeholderCards;
  final EmptyAreaDashboardSidePanelBuilder? sidePanelBuilder;
  final EmptyAreaDashboardWorkspaceBuilder? workspaceBuilder;
  final bool showContractPanel;
  final bool showPlaceholderCards;

  const EmptyAreaDashboardConfig({
    required this.dashboardLabel,
    required this.sidePanelLabel,
    this.headerTitleColor,
    required this.heroEyebrow,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.contractTitle,
    required this.contractSubtitle,
    required this.contractFootnote,
    this.heroCardBorderColor,
    this.heroCardGradient,
    this.heroEyebrowColor,
    this.heroTitleColor,
    this.heroSubtitleColor,
    this.workspaceBodyColor,
    this.emptyStateSurfaceColor,
    this.emptyStateBorderColor,
    this.emptyStateIconColor,
    this.emptyStateBodyColor,
    this.contractPanelColor,
    this.contractActionColor,
    this.contractActionHoverColor,
    this.contractActionIconColor,
    this.contractFootnoteColor,
    this.placeholderCardColor,
    this.placeholderCardIconColor,
    this.placeholderCardDescriptionColor,
    this.placeholderCardArrowColor,
    required this.tokens,
    required this.ink,
    required this.mutedInk,
    required this.heroGradient,
    required this.panelGradient,
    required this.accentGradient,
    required this.backgroundGradientColors,
    required this.topLeftBlobColors,
    required this.topRightBlobColors,
    required this.bottomLeftBlobColors,
    required this.pillarGradientColors,
    required this.areaItems,
    this.accessItems = const <DashboardNavAction>[],
    this.headerActions = const <DashboardHeaderAction>[],
    this.placeholderCards = const <DashboardPlaceholderCard>[
      DashboardPlaceholderCard(
        icon: Icons.dashboard_customize_rounded,
        title: 'Widget reservado',
        description:
            'Contenedor listo para funcionalidad real, sin métricas inventadas.',
      ),
      DashboardPlaceholderCard(
        icon: Icons.timeline_rounded,
        title: 'Superficie futura',
        description:
            'Contenedor listo para funcionalidad real, sin métricas inventadas.',
      ),
      DashboardPlaceholderCard(
        icon: Icons.widgets_outlined,
        title: 'Espacio homologado',
        description:
            'Contenedor listo para funcionalidad real, sin métricas inventadas.',
      ),
    ],
    this.sidePanelBuilder,
    this.workspaceBuilder,
    this.showContractPanel = true,
    this.showPlaceholderCards = true,
  });

  EmptyAreaDashboardConfig copyWith({
    List<DashboardNavAction>? areaItems,
    List<DashboardNavAction>? accessItems,
    List<DashboardHeaderAction>? headerActions,
    List<DashboardPlaceholderCard>? placeholderCards,
    EmptyAreaDashboardWorkspaceBuilder? workspaceBuilder,
    bool? showContractPanel,
    bool? showPlaceholderCards,
  }) {
    return EmptyAreaDashboardConfig(
      dashboardLabel: dashboardLabel,
      sidePanelLabel: sidePanelLabel,
      headerTitleColor: headerTitleColor,
      heroEyebrow: heroEyebrow,
      heroTitle: heroTitle,
      heroSubtitle: heroSubtitle,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      contractTitle: contractTitle,
      contractSubtitle: contractSubtitle,
      contractFootnote: contractFootnote,
      heroCardBorderColor: heroCardBorderColor,
      heroCardGradient: heroCardGradient,
      heroEyebrowColor: heroEyebrowColor,
      heroTitleColor: heroTitleColor,
      heroSubtitleColor: heroSubtitleColor,
      workspaceBodyColor: workspaceBodyColor,
      emptyStateSurfaceColor: emptyStateSurfaceColor,
      emptyStateBorderColor: emptyStateBorderColor,
      emptyStateIconColor: emptyStateIconColor,
      emptyStateBodyColor: emptyStateBodyColor,
      contractPanelColor: contractPanelColor,
      contractActionColor: contractActionColor,
      contractActionHoverColor: contractActionHoverColor,
      contractActionIconColor: contractActionIconColor,
      contractFootnoteColor: contractFootnoteColor,
      placeholderCardColor: placeholderCardColor,
      placeholderCardIconColor: placeholderCardIconColor,
      placeholderCardDescriptionColor: placeholderCardDescriptionColor,
      placeholderCardArrowColor: placeholderCardArrowColor,
      tokens: tokens,
      ink: ink,
      mutedInk: mutedInk,
      heroGradient: heroGradient,
      panelGradient: panelGradient,
      accentGradient: accentGradient,
      backgroundGradientColors: backgroundGradientColors,
      topLeftBlobColors: topLeftBlobColors,
      topRightBlobColors: topRightBlobColors,
      bottomLeftBlobColors: bottomLeftBlobColors,
      pillarGradientColors: pillarGradientColors,
      areaItems: areaItems ?? this.areaItems,
      accessItems: accessItems ?? this.accessItems,
      headerActions: headerActions ?? this.headerActions,
      placeholderCards: placeholderCards ?? this.placeholderCards,
      sidePanelBuilder: sidePanelBuilder,
      workspaceBuilder: workspaceBuilder ?? this.workspaceBuilder,
      showContractPanel: showContractPanel ?? this.showContractPanel,
      showPlaceholderCards: showPlaceholderCards ?? this.showPlaceholderCards,
    );
  }
}

class DashboardPlaceholderCard {
  final IconData icon;
  final String title;
  final String description;

  const DashboardPlaceholderCard({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class DashboardNavAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;
  final bool current;
  final bool Function(AuthResolvedProfile? profile)? isVisible;

  const DashboardNavAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.current = false,
    this.isVisible,
  });
}

class DashboardHeaderAction {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;
  final bool compact;
  final bool Function(AuthResolvedProfile? profile)? isVisible;

  const DashboardHeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.isVisible,
  });
}

class _AreaDashboardBackground extends StatelessWidget {
  final EmptyAreaDashboardConfig config;

  const _AreaDashboardBackground({required this.config});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: config.backgroundGradientColors,
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(760, config.topLeftBlobColors),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(580, config.topRightBlobColors),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(640, config.bottomLeftBlobColors),
        ),
        Positioned(
          right: -105,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: config.pillarGradientColors,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, List<Color> colors) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _AreaHeaderBrand extends StatelessWidget {
  final EmptyAreaDashboardConfig config;

  const _AreaHeaderBrand({required this.config});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: config.tokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        Text(
          config.dashboardLabel,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: config.headerTitleColor ?? config.ink,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _AreaDashboardBody extends StatelessWidget {
  final EmptyAreaDashboardConfig config;

  const _AreaDashboardBody({required this.config});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AreaHero(config: config),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  if (!config.showContractPanel) {
                    return _WorkspaceCard(
                      width: availableWidth,
                      config: config,
                    );
                  }
                  final isWide = availableWidth >= 1180;
                  final rightWidth = isWide ? 360.0 : availableWidth;
                  final leftWidth = isWide
                      ? availableWidth - rightWidth - 16
                      : availableWidth;
                  if (!isWide) {
                    return Column(
                      children: [
                        _WorkspaceCard(width: leftWidth, config: config),
                        const SizedBox(height: 16),
                        _ContractCard(width: rightWidth, config: config),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkspaceCard(width: leftWidth, config: config),
                      const SizedBox(width: 16),
                      _ContractCard(width: rightWidth, config: config),
                    ],
                  );
                },
              ),
              if (config.showPlaceholderCards &&
                  config.placeholderCards.isNotEmpty) ...[
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final wide = availableWidth >= 1240;
                    final medium = availableWidth >= 860;
                    final spacing = 16.0;
                    final columns = wide
                        ? 3
                        : medium
                        ? 2
                        : 1;
                    final width =
                        (availableWidth - spacing * (columns - 1)) / columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final card in config.placeholderCards)
                          _PlaceholderWidgetCard(
                            width: width,
                            config: config,
                            icon: card.icon,
                            title: card.title,
                            description: card.description,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaHero extends StatelessWidget {
  final EmptyAreaDashboardConfig config;

  const _AreaHero({required this.config});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: config.heroCardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                config.heroCardBorderColor ??
                Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: config.heroGradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.space_dashboard_rounded,
                  size: 30,
                  color:
                      config.emptyStateIconColor ?? config.tokens.primaryStrong,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.heroEyebrow,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: config.heroEyebrowColor ?? config.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.heroTitle,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: config.heroTitleColor ?? config.ink,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.heroSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: config.heroSubtitleColor ?? config.mutedInk,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final double width;
  final EmptyAreaDashboardConfig config;

  const _WorkspaceCard({required this.width, required this.config});

  @override
  Widget build(BuildContext context) {
    if (config.workspaceBuilder != null) {
      return SizedBox(
        width: width,
        child: config.workspaceBuilder!(context, config, width),
      );
    }
    return SizedBox(
      width: width,
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              config.emptyTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: config.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.emptySubtitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: config.workspaceBodyColor ?? config.mutedInk,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            CustomPaint(
              painter: _DashedRoundedRectPainter(
                color:
                    config.emptyStateBorderColor ??
                    config.tokens.border.withValues(alpha: 0.30),
                radius: 28,
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 280),
                decoration: BoxDecoration(
                  color: config.emptyStateSurfaceColor,
                  gradient: config.emptyStateSurfaceColor == null
                      ? config.panelGradient
                      : null,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            gradient: config.contractActionColor == null
                                ? config.accentGradient
                                : null,
                            color: config.contractActionColor,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: config.tokens.glow.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.widgets_outlined,
                            size: 34,
                            color:
                                config.emptyStateIconColor ??
                                config.tokens.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Sin datos simulados',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: config.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Text(
                            'Esta superficie quedó preparada para conectar métricas, alertas y widgets reales cuando la funcionalidad exista.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color:
                                  config.emptyStateBodyColor ??
                                  config.workspaceBodyColor ??
                                  config.mutedInk,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
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
}

class _ContractCard extends StatelessWidget {
  final double width;
  final EmptyAreaDashboardConfig config;

  const _ContractCard({required this.width, required this.config});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ContractGlassCard(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: config.contractPanelColor,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.contractTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: config.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                config.contractSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: config.workspaceBodyColor ?? config.mutedInk,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _ContractBadge(
                config: config,
                icon: Icons.grid_view_rounded,
                title: 'Shell y navegación',
              ),
              const SizedBox(height: 10),
              _ContractBadge(
                config: config,
                icon: Icons.ads_click_rounded,
                title: 'Hover, lift y sombras',
              ),
              const SizedBox(height: 10),
              _ContractBadge(
                config: config,
                icon: Icons.view_quilt_outlined,
                title: 'Cards y widgets base',
              ),
              const SizedBox(height: 14),
              Text(
                config.contractFootnote,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color:
                      config.contractFootnoteColor ??
                      config.workspaceBodyColor ??
                      config.mutedInk,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractBadge extends StatefulWidget {
  final EmptyAreaDashboardConfig config;
  final IconData icon;
  final String title;

  const _ContractBadge({
    required this.config,
    required this.icon,
    required this.title,
  });

  @override
  State<_ContractBadge> createState() => _ContractBadgeState();
}

class _ContractBadgeState extends State<_ContractBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered
              ? (config.contractActionHoverColor ??
                    config.tokens.badgeBackground.withValues(alpha: 0.82))
              : (config.contractActionColor ??
                    config.tokens.badgeBackground.withValues(alpha: 0.72)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: config.tokens.border.withValues(
              alpha: _hovered ? 0.22 : 0.12,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.22 : 0.12),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 18,
              color:
                  config.contractActionIconColor ?? config.tokens.primaryStrong,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: config.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color:
                  config.contractActionIconColor ??
                  config.tokens.primaryStrong.withValues(alpha: 0.92),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderWidgetCard extends StatefulWidget {
  final double width;
  final EmptyAreaDashboardConfig config;
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderWidgetCard({
    required this.width,
    required this.config,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  State<_PlaceholderWidgetCard> createState() => _PlaceholderWidgetCardState();
}

class _PlaceholderWidgetCardState extends State<_PlaceholderWidgetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.012 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          width: widget.width,
          child: ContractGlassCard(
            padding: EdgeInsets.zero,
            elevation: _hovered ? 22 : 16,
            child: Container(
              decoration: BoxDecoration(
                color: config.placeholderCardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: config.contractActionColor == null
                          ? config.accentGradient
                          : null,
                      color: config.contractActionColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color:
                          config.placeholderCardIconColor ??
                          config.tokens.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: config.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          config.placeholderCardDescriptionColor ??
                          config.workspaceBodyColor ??
                          config.mutedInk,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: config.contractActionColor == null
                              ? config.accentGradient
                              : null,
                          color: config.contractActionColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 22,
                          color:
                              config.placeholderCardArrowColor ??
                              config.placeholderCardIconColor ??
                              config.tokens.primary,
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
    );
  }
}

class _AreaHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const _AreaHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  State<_AreaHeaderButton> createState() => _AreaHeaderButtonState();
}

class _AreaHeaderButtonState extends State<_AreaHeaderButton> {
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
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
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
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              width: widget.compact ? 56 : 176,
              height: 56,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 0 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.18 : 0.12),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.20 : 0.12,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.22 : 0.12,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.12 : 0.05,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: widget.compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: tokens.darkGlass
                        ? tokens.onGlass
                        : tokens.primaryStrong,
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: tokens.darkGlass
                                ? tokens.onGlass
                                : tokens.primaryStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaSidePanel extends StatelessWidget {
  final EmptyAreaDashboardConfig config;
  final bool canReturnToDirection;
  final List<DashboardNavAction> accessItems;

  const _AreaSidePanel({
    required this.config,
    required this.canReturnToDirection,
    required this.accessItems,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                config.sidePanelLabel,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.darkGlass
                      ? tokens.onGlass
                      : tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _AreaNavItem(
                  config: config,
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  subtitle: 'Regresar a la vista ejecutiva',
                  onTap: accessItems.first.onTap,
                ),
                const SizedBox(height: 10),
              ],
              const _AreaSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.darkGlass
                      ? config.contractActionColor
                      : tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.darkGlass
                        ? Colors.white.withValues(alpha: 0.08)
                        : tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < config.areaItems.length;
                      index++
                    ) ...[
                      _AreaNavItem(
                        config: config,
                        icon: config.areaItems[index].icon,
                        title: config.areaItems[index].title,
                        subtitle: config.areaItems[index].subtitle,
                        accented: config.areaItems[index].current,
                        onTap: config.areaItems[index].onTap,
                      ),
                      if (index != config.areaItems.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _AreaSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              for (var index = 0; index < accessItems.length; index++) ...[
                _AreaNavItem(
                  config: config,
                  icon: accessItems[index].icon,
                  title: accessItems[index].title,
                  subtitle: accessItems[index].subtitle,
                  onTap: accessItems[index].onTap,
                ),
                if (index != accessItems.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaSectionHeader extends StatelessWidget {
  final String label;

  const _AreaSectionHeader({required this.label});

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
            color: tokens.darkGlass ? tokens.primary : tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.darkGlass
                ? Colors.white.withValues(alpha: 0.10)
                : tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _AreaNavItem extends StatelessWidget {
  final EmptyAreaDashboardConfig config;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const _AreaNavItem({
    required this.config,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented ? config.heroGradient : config.panelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.white.withValues(
                        alpha: tokens.darkGlass ? 0.08 : 0.58,
                      ),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: tokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented
                      ? Colors.white
                      : (tokens.darkGlass
                            ? tokens.primary
                            : tokens.primaryStrong),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: accented
                              ? Colors.white
                              : (tokens.darkGlass
                                    ? tokens.onGlass
                                    : tokens.primaryStrong),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accented
                              ? Colors.white.withValues(alpha: 0.92)
                              : (tokens.darkGlass
                                    ? tokens.onGlass.withValues(alpha: 0.58)
                                    : tokens.badgeText),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.darkGlass ? tokens.primary : tokens.badgeText,
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

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRoundedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashWidth = 8.0;
    const dashGap = 7.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
