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
        'Novos atendimentos continuam bloqueados. Uma etapa confirmada não substitui as demais verificações nem libera o perfil.',
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
                const {
                      'confirmado',
                      'cadastrado',
                      'analisado',
                    }.contains(etapa['status'])
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
        'Telefone confirmado significa acesso ao WhatsApp naquele momento, não identidade ou prova de vida. Antecedentes aguardam uma política aprovada; não envie certidões ou dados biométricos por enquanto.',
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
  'documentos' => 'Documento de identidade',
  'telefone' => 'Telefone',
  'identidade' => 'Identidade e prova de vida',
  'antecedentes' => 'Antecedentes',
  'aprovacao' => 'Habilitação final',
  _ => 'Verificação',
};

String _status(Object? value) => switch (value) {
  'confirmado' => 'Acesso ao canal confirmado',
  'cadastrado' => 'Cadastrado',
  'analisado' => 'Documento analisado',
  'aguardando_integracao' => 'Ainda não disponível',
  'revisao_necessaria' => 'Precisa de revisão',
  'aguardando_politica' => 'Aguardando definição da política',
  'em_analise' => 'Em análise',
  'suspenso' => 'Suspensa',
  _ => 'Pendente',
};
