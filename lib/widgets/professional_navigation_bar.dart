import 'package:flutter/material.dart';

import '../app/routes.dart';
import 'adaptive_navigation_bar.dart';

/// Destinos principais da conta profissional, inclusive durante a edição.
class ProfessionalNavigationBar extends StatelessWidget {
  const ProfessionalNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static void openDestination(BuildContext context, int index) {
    final route = switch (index) {
      3 => AppRoutes.servicosProfissional,
      4 => AppRoutes.perfilProfissionalPrivado,
      _ => AppRoutes.areaProfissional,
    };
    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: index < 3 ? index : null,
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveNavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) {
      if (index != selectedIndex) onDestinationSelected(index);
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
      NavigationDestination(
        icon: Icon(Icons.inbox_outlined),
        label: 'Pedidos',
        tooltip: 'Solicitações recebidas',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Agenda',
      ),
      NavigationDestination(
        icon: Icon(Icons.home_repair_service_outlined),
        label: 'Serviços',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
    ],
  );
}
