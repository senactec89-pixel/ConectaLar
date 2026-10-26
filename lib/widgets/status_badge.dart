import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/solicitacao.dart';

/// Apresentação compacta de uma situação, sem definir regras de transição.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    this.backgroundColor,
    this.maxWidth = 200,
    super.key,
  });

  factory StatusBadge.solicitacao(
    StatusSolicitacao status, {
    String? label,
    double maxWidth = 200,
  }) {
    final color = switch (status) {
      StatusSolicitacao.aguardandoResposta ||
      StatusSolicitacao.conclusaoPendente => const Color(0xFF9A6415),
      StatusSolicitacao.aceitaAgendada => AppColors.verde,
      StatusSolicitacao.recusada ||
      StatusSolicitacao.conclusaoContestada ||
      StatusSolicitacao.naoComparecimentoInformado => AppColors.erro,
      StatusSolicitacao.cancelada => AppColors.textoSuave,
      StatusSolicitacao.conclusaoConfirmada => AppColors.verdeEscuro,
    };
    return StatusBadge(
      label: label ?? status.rotulo,
      color: color,
      maxWidth: maxWidth,
    );
  }

  factory StatusBadge.solicitacaoValor(
    Object? value, {
    String? label,
    double maxWidth = 200,
  }) {
    for (final status in StatusSolicitacao.values) {
      if (status.valorBanco == value) {
        return StatusBadge.solicitacao(
          status,
          label: label,
          maxWidth: maxWidth,
        );
      }
    }
    return StatusBadge(
      label: label ?? 'Status desconhecido',
      color: AppColors.textoSuave,
      maxWidth: maxWidth,
    );
  }

  final String label;
  final Color color;
  final Color? backgroundColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
