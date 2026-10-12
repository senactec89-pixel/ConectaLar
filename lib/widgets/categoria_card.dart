import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../utils/categoria_icons.dart';

class CategoriaCard extends StatelessWidget {
  const CategoriaCard({
    required this.categoria,
    this.icon,
    this.onTap,
    super.key,
  });

  final Categoria categoria;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: categoria.nome,
      child: SizedBox(
        width: 88,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      icon ?? categoriaIconData(categoria.icone),
                      semanticLabel: categoria.nome,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categoria.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
