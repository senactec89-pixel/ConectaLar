import 'package:flutter/material.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Modo demonstração. Dados fictícios.',
    child: Banner(
      message: 'DEMO',
      location: BannerLocation.topEnd,
      child: child,
    ),
  );
}
