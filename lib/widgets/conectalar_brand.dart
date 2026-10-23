import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Símbolo decorativo acompanhado pelo nome legível da marca nas telas.
class ConectaLarSymbol extends StatelessWidget {
  const ConectaLarSymbol({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/conectalar_symbol.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.high,
  );
}

/// Texto nativo para preservar leitura assistiva e ampliação da fonte.
class ConectaLarWordmark extends StatelessWidget {
  const ConectaLarWordmark({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Text.rich(
    const TextSpan(
      children: [
        TextSpan(text: 'Conecta'),
        TextSpan(
          text: 'Lar',
          style: TextStyle(color: AppColors.verde),
        ),
      ],
    ),
    semanticsLabel: 'ConectaLar',
    style: TextStyle(
      color: AppColors.verdeEscuro,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.1,
    ),
  );
}
