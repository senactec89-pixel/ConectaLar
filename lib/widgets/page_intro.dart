import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Título e apoio das áreas principais, abaixo da barra de navegação.
class PageIntro extends StatelessWidget {
  const PageIntro({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(height: AppSpace.xs),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textoSuave),
      ),
    ],
  );
}
