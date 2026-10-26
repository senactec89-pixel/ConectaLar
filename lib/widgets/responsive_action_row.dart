import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Mantém duas ações alinhadas e as empilha quando a largura é insuficiente.
class ResponsiveActionRow extends StatelessWidget {
  const ResponsiveActionRow({
    required this.secondary,
    required this.primary,
    required this.stacked,
    this.spacing = AppSpace.sm,
    super.key,
  });

  final Widget secondary;
  final Widget primary;
  final bool stacked;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          secondary,
          SizedBox(height: spacing),
          primary,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: secondary),
        SizedBox(width: spacing),
        Expanded(child: primary),
      ],
    );
  }
}
