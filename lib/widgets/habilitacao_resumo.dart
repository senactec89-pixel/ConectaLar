import 'package:flutter/material.dart';

class HabilitacaoResumo extends StatelessWidget {
  const HabilitacaoResumo({required this.dados, super.key});
  final Map<String, dynamic> dados;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Habilitação para atendimento',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        dados['estado'] == 'suspenso'
            ? 'Habilitação suspensa'
            : 'Habilitação pendente',
      ),
      const SizedBox(height: 8),
      const Text(
        'Novos atendimentos bloqueados. A aprovação de documentos não substitui as verificações de segurança.',
      ),
      const SizedBox(height: 12),
      for (final etapa
          in (dados['etapas'] as List? ?? const []).whereType<Map>())
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                etapa['status'] == 'confirmado' ||
                        etapa['status'] == 'cadastrado'
                    ? Icons.check_circle_outline
                    : Icons.pending_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_etapa(etapa['codigo'])}: ${_status(etapa['status'])}',
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'Identidade e telefone aguardam integração. Antecedentes aguardam definição da política de análise. Não envie selfies, CPF ou certidões para essas etapas por enquanto.',
      ),
      if (dados['revisaoSolicitadaEm'] != null) ...[
        const SizedBox(height: 8),
        const Text('Solicitação de revisão registrada.'),
      ],
    ],
  );
}

String _etapa(Object? value) => switch (value) {
  'perfil' => 'Perfil',
  'email' => 'E-mail',
  'telefone' => 'Telefone',
  'identidade' => 'Identidade e prova de vida',
  'antecedentes' => 'Antecedentes',
  'aprovacao' => 'Análise administrativa',
  _ => 'Verificação',
};
String _status(Object? value) => switch (value) {
  'confirmado' => 'Confirmado',
  'cadastrado' => 'Cadastrado',
  'aguardando_integracao' => 'Ainda indisponível',
  'revisao_necessaria' => 'Precisa de revisão manual',
  'aguardando_politica' => 'Aguardando política de análise',
  'em_analise' => 'Em análise',
  'suspenso' => 'Suspensa',
  _ => 'Pendente',
};
