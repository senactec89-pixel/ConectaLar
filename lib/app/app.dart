import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';
import '../services/service_registry.dart';

class ConectaLarApp extends StatelessWidget {
  const ConectaLarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConectaLar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: switch (AppServices.instance.auth.usuarioAtual?['tipo']) {
        'profissional' || 'empresa' => AppRoutes.areaProfissional,
        'administrador' => AppRoutes.admin,
        _ => AppRoutes.home,
      },
      routes: AppRoutes.routes,
      builder: (context, child) => AppServices.instance.modoDemo
          ? Banner(
              message: 'DEMONSTRAÇÃO',
              location: BannerLocation.topEnd,
              child: child!,
            )
          : child!,
    );
  }
}
