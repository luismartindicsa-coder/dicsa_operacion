import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/page_routes.dart';
import 'menudeo_cash_cuts_page.dart';
import 'menudeo_cash_taxonomy_page.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_navigation_panel.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_tickets_page.dart';

export 'menudeo_navigation_panel.dart';

/// Se aplica tanto al menú visible como al despacho de sus destinos.
bool canNavigateMenudeo(
  MenudeoDestination destination,
  AuthResolvedProfile? profile,
) => switch (destination) {
  MenudeoDestination.cashTaxonomy => AuthAccess.hasMenudeoAccess(profile),
  MenudeoDestination.direction ||
  MenudeoDestination.operation ||
  MenudeoDestination.cashCuts => AuthAccess.isDirectionRole(profile),
  _ => true,
};

class MenudeoNavigationOverlay extends StatefulWidget {
  final bool isOpen;
  final MenudeoDestination currentDestination;
  final VoidCallback onClose;

  const MenudeoNavigationOverlay({
    super.key,
    required this.isOpen,
    required this.currentDestination,
    required this.onClose,
  });

  @override
  State<MenudeoNavigationOverlay> createState() =>
      _MenudeoNavigationOverlayState();
}

class _MenudeoNavigationOverlayState extends State<MenudeoNavigationOverlay> {
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  FocusNode? _previousFocus;
  bool _canReturnToDirection = false;
  bool _canOpenCashTaxonomy = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveAccess());
  }

  Future<void> _resolveAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = canNavigateMenudeo(
        MenudeoDestination.direction,
        profile,
      );
      _canOpenCashTaxonomy = canNavigateMenudeo(
        MenudeoDestination.cashTaxonomy,
        profile,
      );
    });
  }

  @override
  void didUpdateWidget(MenudeoNavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _previousFocus = FocusManager.instance.primaryFocus;
      _focusNode.requestFocus();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else if (!widget.isOpen && oldWidget.isOpen) {
      if (_previousFocus?.context != null) _previousFocus!.requestFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _navigate(MenudeoDestination destination) async {
    if (_navigating) return;
    widget.onClose();
    if (destination == widget.currentDestination) return;
    _navigating = true;
    try {
      final profile = await AuthAccess.resolveCurrentProfile();
      if (!mounted || !canNavigateMenudeo(destination, profile)) return;
      final page = switch (destination) {
        MenudeoDestination.purchases => const MenudeoTicketsPage(
          instantOpen: true,
        ),
        MenudeoDestination.sales => const MenudeoSalesPage(instantOpen: true),
        MenudeoDestination.depositsExpenses =>
          const MenudeoDepositsExpensesPage(instantOpen: true),
        MenudeoDestination.priceAdjustments =>
          const MenudeoPriceAdjustmentsPage(instantOpen: true),
        MenudeoDestination.catalog => const MenudeoCatalogPage(
          instantOpen: true,
        ),
        MenudeoDestination.cashCuts => const MenudeoCashCutsPage(
          instantOpen: true,
        ),
        MenudeoDestination.cashTaxonomy => const MenudeoCashTaxonomyPage(
          instantOpen: true,
        ),
        MenudeoDestination.dashboard => const MenudeoDashboardPage(
          instantOpen: true,
        ),
        MenudeoDestination.direction => const GeneralDashboardPage(
          instantOpen: true,
        ),
        MenudeoDestination.operation => const DashboardPage(instantOpen: true),
      };
      final route = appPageRoute(
        page: page,
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      );
      final switchingTicketFlow =
          (widget.currentDestination == MenudeoDestination.purchases &&
              destination == MenudeoDestination.sales) ||
          (widget.currentDestination == MenudeoDestination.sales &&
              destination == MenudeoDestination.purchases);
      if (destination == MenudeoDestination.dashboard ||
          destination == MenudeoDestination.direction ||
          switchingTicketFlow) {
        await Navigator.of(context).pushReplacement(route);
      } else {
        await Navigator.of(context).push(route);
      }
    } finally {
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.isOpen,
    child: ExcludeFocus(
      excluding: !widget.isOpen,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (_, event) {
          if (widget.isOpen &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: widget.isOpen ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(color: Colors.black.withValues(alpha: 0.12)),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: widget.isOpen ? 0 : -332,
              top: 0,
              bottom: 0,
              width: 320,
              child: MenudeoNavigationPanel(
                currentDestination: widget.currentDestination,
                canReturnToDirection: _canReturnToDirection,
                canOpenCashTaxonomy: _canOpenCashTaxonomy,
                onNavigate: (destination) => unawaited(_navigate(destination)),
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
