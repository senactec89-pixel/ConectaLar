import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Cabeçalho da conta, compartilhado pelos perfis privados.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    required this.avatar,
    required this.name,
    required this.subtitle,
    super.key,
  });

  final Widget avatar;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(20) > 30;
    final identificacao = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Flex(
          direction: textoAmpliado ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            if (textoAmpliado)
              const SizedBox(height: AppSpace.lg)
            else
              const SizedBox(width: AppSpace.lg),
            if (textoAmpliado)
              identificacao
            else
              Expanded(child: identificacao),
          ],
        ),
      ),
    );
  }
}
