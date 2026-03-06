import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ServicesOverlayNavModule {
  entradasSalidas,
  produccion,
  inventario,
  servicios,
  pesadas,
  mantenimiento,
}

class ServicesShell extends StatefulWidget {
  final Widget child;
  final String? headerTitle;
  final Widget? topContent;
  final ServicesOverlayNavModule? activeOverlayModule;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onGoToOperacion;
  final Future<void> Function()? onGoToEntriesAndOutputs;
  final Future<void> Function()? onGoToProduction;
  final Future<void> Function()? onGoToServices;
  final Future<void> Function()? onGoToWeighings;
  final Future<void> Function()? onGoToMaintenance;
  final Future<void> Function()? onGoToCatalogs;
  final Future<void> Function()? onHeaderGuide;
  final String? headerGuideLabel;

  const ServicesShell({
    super.key,
    required this.child,
    this.headerTitle,
    this.topContent,
    this.activeOverlayModule,
    this.onRefresh,
    this.onLogout,
    this.onGoToOperacion,
    this.onGoToEntriesAndOutputs,
    this.onGoToProduction,
    this.onGoToServices,
    this.onGoToWeighings,
    this.onGoToMaintenance,
    this.onGoToCatalogs,
    this.onHeaderGuide,
    this.headerGuideLabel,
  });

  @override
  State<ServicesShell> createState() => _ServicesShellState();
}

class _ServicesShellState extends State<ServicesShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _content;
  bool _menuOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _content = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 1.00, curve: Curves.easeOut),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = widget.headerTitle ?? 'Viajes y Servicios';
    const overlayWidth = 300.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape &&
              _menuOverlayOpen) {
            setState(() => _menuOverlayOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            const _DicsaBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _content,
                          builder: (_, __) => Opacity(
                            opacity: _content.value,
                            child: _HeaderActionButton(
                              label: _menuOverlayOpen
                                  ? 'Cerrar navegación'
                                  : 'Navegación',
                              icon: _menuOverlayOpen
                                  ? Icons.close_rounded
                                  : Icons.menu_rounded,
                              onTap: () async {
                                if (!mounted) return;
                                setState(
                                  () => _menuOverlayOpen = !_menuOverlayOpen,
                                );
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                        _HeaderBrand(
                          contentAnim: _content,
                          title: resolvedTitle,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onRefresh != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AnimatedBuilder(
                                  animation: _content,
                                  builder: (_, __) => Opacity(
                                    opacity: _content.value,
                                    child: _HeaderActionButton(
                                      label: 'Recargar',
                                      icon: Icons.refresh_rounded,
                                      onTap: () async => widget.onRefresh!(),
                                    ),
                                  ),
                                ),
                              ),
                            AnimatedBuilder(
                              animation: _content,
                              builder: (_, __) => Opacity(
                                opacity: _content.value,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _HeaderHelpButton(
                                    onTap: () => _showUsageHelp(resolvedTitle),
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onHeaderGuide != null)
                              AnimatedBuilder(
                                animation: _content,
                                builder: (_, __) => Opacity(
                                  opacity: _content.value,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _HeaderActionButton(
                                      label: widget.headerGuideLabel ?? 'Flujo',
                                      icon: Icons.account_tree_rounded,
                                      onTap: () async =>
                                          widget.onHeaderGuide!(),
                                    ),
                                  ),
                                ),
                              ),
                            AnimatedBuilder(
                              animation: _content,
                              builder: (_, __) => Opacity(
                                opacity: _content.value,
                                child: _HeaderActionButton(
                                  label: 'Cerrar sesión',
                                  icon: Icons.logout_rounded,
                                  onTap: widget.onLogout == null
                                      ? null
                                      : () async => widget.onLogout!(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.topContent != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: widget.topContent!,
                        ),
                      ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _content,
                        builder: (_, __) => Opacity(
                          opacity: _content.value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - _content.value) * 14),
                            child: _GlassCard(child: widget.child),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _menuOverlayOpen ? 18 : -(overlayWidth + 12),
              top: 84,
              width: overlayWidth,
              child: SafeArea(
                child: IgnorePointer(
                  ignoring: !_menuOverlayOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    opacity: _menuOverlayOpen ? 1 : 0,
                    child: _ServicesSideMenu(
                      activeModule: widget.activeOverlayModule,
                      onGoToOperacion: widget.onGoToOperacion,
                      onGoToEntriesAndOutputs: widget.onGoToEntriesAndOutputs,
                      onGoToProduction: widget.onGoToProduction,
                      onGoToServices: widget.onGoToServices,
                      onGoToWeighings: widget.onGoToWeighings,
                      onGoToMaintenance: widget.onGoToMaintenance,
                      onNavigate: () {
                        if (!mounted) return;
                        setState(() => _menuOverlayOpen = false);
                      },
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

  Future<void> _showUsageHelp(String pageTitle) async {
    final entriesAndOutputs = pageTitle.toLowerCase().contains(
      'entradas y salidas',
    );
    final sections = entriesAndOutputs
        ? const <
            ({
              IconData icon,
              String title,
              List<({IconData icon, String text})> points,
            })
          >[
            (
              icon: Icons.navigation_rounded,
              title: 'Navega y selecciona',
              points: [
                (
                  icon: Icons.mouse_rounded,
                  text: 'Un clic selecciona la fila.',
                ),
                (
                  icon: Icons.keyboard_arrow_up_rounded,
                  text: 'Usa las flechas para subir o bajar por la lista.',
                ),
                (
                  icon: Icons.keyboard_command_key_rounded,
                  text:
                      'Control (Ctrl) o Comando (Cmd) + clic para seleccionar varias filas.',
                ),
                (
                  icon: Icons.open_with_rounded,
                  text:
                      'También puedes arrastrar para seleccionar varias filas.',
                ),
              ],
            ),
            (
              icon: Icons.edit_rounded,
              title: 'Edita y guarda',
              points: [
                (
                  icon: Icons.ads_click_rounded,
                  text: 'Doble clic para editar una celda.',
                ),
                (
                  icon: Icons.keyboard_return_rounded,
                  text: 'Enter guarda los cambios.',
                ),
                (icon: Icons.keyboard_hide_rounded, text: 'Esc cancela.'),
                (
                  icon: Icons.table_rows_rounded,
                  text:
                      'Si editas varias filas, Enter y Esc aplican al conjunto completo.',
                ),
                (
                  icon: Icons.touch_app_rounded,
                  text: 'Clic fuera de la celda sale de edición sin guardar.',
                ),
              ],
            ),
            (
              icon: Icons.bolt_rounded,
              title: 'Acciones útiles',
              points: [
                (
                  icon: Icons.mouse_outlined,
                  text: 'Clic derecho o botón ... abre acciones.',
                ),
                (
                  icon: Icons.groups_rounded,
                  text:
                      'Con varias filas seleccionadas, las acciones se aplican a todas.',
                ),
                (
                  icon: Icons.backspace_rounded,
                  text:
                      'Suprimir o retroceso elimina filas solo cuando estás en selección.',
                ),
                (
                  icon: Icons.text_fields_rounded,
                  text:
                      'Si estás escribiendo, suprimir o retroceso borra texto, no la fila.',
                ),
                (
                  icon: Icons.space_bar_rounded,
                  text:
                      'Barra espaciadora abre listas o fecha en la celda activa.',
                ),
                (
                  icon: Icons.add_circle_outline_rounded,
                  text:
                      'En la fila de captura: EXTRAS define calidad y origen, y + agrega.',
                ),
              ],
            ),
          ]
        : const <
            ({
              IconData icon,
              String title,
              List<({IconData icon, String text})> points,
            })
          >[
            (
              icon: Icons.navigation_rounded,
              title: 'Navega y selecciona',
              points: [
                (
                  icon: Icons.mouse_rounded,
                  text: 'Un clic selecciona la fila.',
                ),
                (
                  icon: Icons.keyboard_arrow_up_rounded,
                  text: 'Usa las flechas para subir o bajar por la lista.',
                ),
                (
                  icon: Icons.keyboard_command_key_rounded,
                  text:
                      'Control (Ctrl) o Comando (Cmd) + clic para seleccionar varias filas.',
                ),
                (
                  icon: Icons.open_with_rounded,
                  text:
                      'También puedes arrastrar para seleccionar varias filas.',
                ),
              ],
            ),
            (
              icon: Icons.edit_rounded,
              title: 'Edita y guarda',
              points: [
                (
                  icon: Icons.ads_click_rounded,
                  text: 'Doble clic para editar una celda.',
                ),
                (
                  icon: Icons.keyboard_return_rounded,
                  text: 'Enter guarda los cambios.',
                ),
                (icon: Icons.keyboard_hide_rounded, text: 'Esc cancela.'),
                (
                  icon: Icons.table_rows_rounded,
                  text:
                      'Si editas varias filas, Enter y Esc aplican al conjunto completo.',
                ),
                (
                  icon: Icons.touch_app_rounded,
                  text: 'Clic fuera de la celda sale de edición sin guardar.',
                ),
              ],
            ),
            (
              icon: Icons.bolt_rounded,
              title: 'Acciones útiles',
              points: [
                (
                  icon: Icons.mouse_outlined,
                  text: 'Clic derecho o botón ... abre acciones.',
                ),
                (
                  icon: Icons.groups_rounded,
                  text:
                      'Con varias filas seleccionadas, las acciones se aplican a todas.',
                ),
                (
                  icon: Icons.backspace_rounded,
                  text:
                      'Suprimir o retroceso elimina filas solo cuando estás en selección.',
                ),
                (
                  icon: Icons.text_fields_rounded,
                  text:
                      'Si estás escribiendo, suprimir o retroceso borra texto, no la fila.',
                ),
                (
                  icon: Icons.space_bar_rounded,
                  text:
                      'Barra espaciadora abre listas o fecha en la celda activa.',
                ),
                (
                  icon: Icons.add_circle_outline_rounded,
                  text: 'En la fila de captura, + agrega el registro.',
                ),
              ],
            ),
          ];

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.26),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xE6EAF2F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF90AFC8).withOpacity(0.58),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E87A9).withOpacity(0.26),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    Navigator.of(dialogContext).pop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ayuda rápida de uso',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF173248),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entriesAndOutputs
                          ? 'Consejos para capturar entradas y salidas'
                          : pageTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF285071),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final section in sections) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.24),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.42),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(
                                              0xFF52CFA6,
                                            ).withOpacity(0.92),
                                            const Color(
                                              0xFF6CB7E2,
                                            ).withOpacity(0.86),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF5FAEC5,
                                            ).withOpacity(0.32),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        section.icon,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            section.title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1C3E5D),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          for (final point in section.points)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 3,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 1,
                                                        ),
                                                    child: Icon(
                                                      point.icon,
                                                      size: 15,
                                                      color: const Color(
                                                        0xFF2D5675,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      point.text,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        height: 1.25,
                                                        color: Color(
                                                          0xFF223A4D,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6A99C7),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Entendido'),
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
  }
}

class _HeaderBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const _HeaderBrand({required this.contentAnim, required this.title});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: contentAnim,
      builder: (_, __) => Opacity(
        opacity: contentAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - contentAnim.value) * 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.44)),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          spreadRadius: 1,
                          color: const Color(0xFF0E86FF).withOpacity(0.20),
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo_dicsa.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.25,
                          height: 1.0,
                          color: Color(0xFF0B2B2B),
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
    );
  }
}

class _HeaderActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderHelpButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HeaderHelpButton({required this.onTap});

  @override
  State<_HeaderHelpButton> createState() => _HeaderHelpButtonState();
}

class _HeaderHelpButtonState extends State<_HeaderHelpButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.04 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF9AC5E3).withOpacity(_hovered ? 0.24 : 0.16),
                  Colors.white.withOpacity(_hovered ? 0.22 : 0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.66)),
              boxShadow: [
                BoxShadow(
                  blurRadius: _hovered ? 28 : 16,
                  color: Colors.black.withOpacity(_hovered ? 0.22 : 0.10),
                  offset: Offset(0, _hovered ? 14 : 9),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0B2B2B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final labelLower = widget.label.toLowerCase();
    final isLogout = labelLower.contains('cerrar sesión');
    final isNavigation = labelLower.contains('navegación');
    final isRefresh = labelLower.contains('recargar');
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    final tint = isLogout
        ? const Color(0xFF8DB5D9)
        : isNavigation
        ? const Color(0xFF87C0E2)
        : isRefresh
        ? const Color(0xFF8FCDBD)
        : const Color(0xFF98BCD9);

    return Tooltip(
      message: widget.label,
      child: MouseRegion(
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
                    ? Colors.white.withOpacity(0.22)
                    : Colors.white.withOpacity(0.14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withOpacity(highlighted ? 0.22 : 0.14),
                    Colors.white.withOpacity(highlighted ? 0.20 : 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enabled
                      ? Colors.white.withOpacity(highlighted ? 0.74 : 0.60)
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
                  if (enabled)
                    BoxShadow(
                      blurRadius: highlighted ? 22 : 12,
                      color: tint.withOpacity(highlighted ? 0.30 : 0.16),
                      offset: Offset(0, highlighted ? 9 : 4),
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
      ),
    );
  }
}

class _ServicesSideMenu extends StatelessWidget {
  final ServicesOverlayNavModule? activeModule;
  final Future<void> Function()? onGoToOperacion;
  final Future<void> Function()? onGoToEntriesAndOutputs;
  final Future<void> Function()? onGoToProduction;
  final Future<void> Function()? onGoToServices;
  final Future<void> Function()? onGoToWeighings;
  final Future<void> Function()? onGoToMaintenance;
  final VoidCallback onNavigate;

  const _ServicesSideMenu({
    required this.activeModule,
    required this.onGoToOperacion,
    required this.onGoToEntriesAndOutputs,
    required this.onGoToProduction,
    required this.onGoToServices,
    required this.onGoToWeighings,
    required this.onGoToMaintenance,
    required this.onNavigate,
  });

  Future<void> _handleTap(Future<void> Function()? onTap) async {
    if (onTap == null) return;
    onNavigate();
    await onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE40B2B2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black.withOpacity(0.20),
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _SideMenuTile(
            icon: Icons.compare_arrows_rounded,
            title: 'Entradas y salidas',
            active: activeModule == ServicesOverlayNavModule.entradasSalidas,
            onTap: () => _handleTap(onGoToEntriesAndOutputs),
          ),
          const SizedBox(height: 8),
          _SideMenuTile(
            icon: Icons.local_shipping_outlined,
            title: 'Servicios',
            active: activeModule == ServicesOverlayNavModule.servicios,
            onTap: () => _handleTap(onGoToServices),
          ),
          const SizedBox(height: 8),
          _SideMenuTile(
            icon: Icons.scale_rounded,
            title: 'Pesadas',
            active: activeModule == ServicesOverlayNavModule.pesadas,
            onTap: () => _handleTap(onGoToWeighings),
          ),
          const SizedBox(height: 8),
          _SideMenuTile(
            icon: Icons.factory_outlined,
            title: 'Producción',
            active: activeModule == ServicesOverlayNavModule.produccion,
            onTap: () => _handleTap(onGoToProduction),
          ),
          const SizedBox(height: 12),
          _SideMenuTile(
            icon: Icons.dashboard_customize_rounded,
            title: 'Dashboard',
            onTap: () => _handleTap(onGoToOperacion),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _SideMenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final Future<void> Function()? onTap;
  final bool active;
  final bool emphasize;

  const _SideMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
    this.emphasize = false,
  });

  @override
  State<_SideMenuTile> createState() => _SideMenuTileState();
}

class _SideMenuTileState extends State<_SideMenuTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted =
        enabled && (_hovered || widget.active || widget.emphasize);
    final gradient = widget.emphasize
        ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF2196F3), Color(0xFF1DE9B6)],
          )
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => widget.onTap!() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: highlighted ? gradient : null,
            color: highlighted
                ? (gradient == null ? Colors.white.withOpacity(0.14) : null)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? Colors.white.withOpacity(0.28)
                  : Colors.white.withOpacity(0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: enabled ? Colors.white : const Color(0xCCFFFFFF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: enabled ? Colors.white : const Color(0xCCFFFFFF),
                  ),
                ),
              ),
              if (widget.active)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF68F8C6),
                ),
              if (!widget.active)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.78),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DicsaBackground extends StatelessWidget {
  const _DicsaBackground();

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
