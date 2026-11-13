import 'package:flutter/material.dart';

/// Detalhes informados pelo profissional; opcionais não são contratados automaticamente.
class EscopoServicoView extends StatelessWidget {
  const EscopoServicoView({
    super.key,
    this.inclui = const [],
    this.naoInclui = const [],
    this.opcionais = const [],
    this.titulo,
  });

  final List<String> inclui;
  final List<String> naoInclui;
  final List<String> opcionais;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    if (inclui.isEmpty && naoInclui.isEmpty && opcionais.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titulo != null) ...[
          const SizedBox(height: 12),
          Text(titulo!, style: Theme.of(context).textTheme.titleSmall),
        ],
        for (final grupo in [
          ('Inclui', inclui),
          ('Não inclui', naoInclui),
          ('Opcionais a combinar', opcionais),
        ])
          if (grupo.$2.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(grupo.$1, style: Theme.of(context).textTheme.labelLarge),
            for (final item in grupo.$2) Text('• $item'),
          ],
        if (opcionais.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Opcionais devem ser combinados com o profissional.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
