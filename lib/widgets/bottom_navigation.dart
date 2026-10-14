import 'package:flutter/material.dart';

import '../app/routes.dart';

class BottomNavigationCustom extends StatelessWidget {
  const BottomNavigationCustom({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

void navigateToMainDestination(BuildContext context, int index) {
  const routes = [
    AppRoutes.home,
    AppRoutes.busca,
    AppRoutes.favoritos,
    AppRoutes.meusServicos,
    AppRoutes.perfil,
  ];
  if (index < 0 || index >= routes.length) {
    return;
  }
  final target = routes[index];
  if (ModalRoute.of(context)?.settings.name == target) return;

  final navigator = Navigator.of(context);
  String? rootName;
  navigator.popUntil((route) {
    if (!route.isFirst) return false;
    rootName = route.settings.name;
    return true;
  });

  if (rootName == AppRoutes.home) {
    if (target != AppRoutes.home) navigator.pushNamed(target);
  } else {
    navigator.pushReplacementNamed(target);
  }
}
