import 'package:flutter/material.dart';

import 'menudeo_tickets_page.dart';

class MenudeoSalesPage extends StatelessWidget {
  final bool instantOpen;

  const MenudeoSalesPage({super.key, this.instantOpen = false});

  @override
  Widget build(BuildContext context) {
    return MenudeoTicketsPage(
      instantOpen: instantOpen,
      flow: MenudeoTicketFlow.sale,
    );
  }
}
