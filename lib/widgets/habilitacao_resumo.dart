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
      Text(_tituloEstado(dados)),
      const SizedBox(height: 8),
      Text(_mensagemEstado(dados)),
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
                      'nao_exigido_no_piloto',
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
        'O telefone cadastrado serve para contato e não exige código nesta fase. A habilitação não significa checagem de antecedentes, prova de vida ou garantia de qualidade do serviço.',
      ),
      if (dados['revisaoSolicitadaEm'] != null) ...[
        const SizedBox(height: 8),
        const Text('Solicitação de revisão registrada.'),
      ],
    ],
  );
}

String _tituloEstado(Map<String, dynamic> dados) {
  if (dados['estado'] == 'suspenso') return 'Habilitação suspensa';
  if (dados['estado'] == 'aprovado' && dados['podeAtender'] == true) {
    return 'Habilitado para receber solicitações';
  }
  if (dados['estado'] == 'aprovado') return 'Aprovação manual registrada';
  if (dados['estado'] == 'em_analise' &&
      dados['aguardandoSegundoRevisor'] == true) {
    return 'Aguardando segundo administrador';
  }
  if (dados['estado'] == 'teste_local_aprovado' &&
      dados['podeAtender'] == true) {
    return 'Habilitação de teste local';
  }
  return 'Habilitação pendente';
}

String _mensagemEstado(Map<String, dynamic> dados) {
  if (dados['estado'] == 'aprovado' && dados['podeAtender'] == true) {
    return 'Dois administradores concluíram a revisão manual do documento e das ofertas do piloto.';
  }
  if (dados['estado'] == 'aprovado') {
    return 'A aprovação está registrada, mas o perfil ou a conta está inativo e não pode receber solicitações.';
  }
  if (dados['estado'] == 'em_analise' &&
      dados['aguardandoSegundoRevisor'] == true) {
    return 'A primeira decisão foi registrada. Outro administrador deve revisar o dossiê e registrar uma decisão independente.';
  }
  if (dados['estado'] == 'teste_local_aprovado' &&
      dados['podeAtender'] == true) {
    return 'Este perfil está liberado somente para testes locais; não recebe solicitações reais.';
  }
  if (dados['estado'] == 'suspenso') {
    return 'O perfil não pode receber solicitações enquanto a habilitação estiver suspensa.';
  }
  return 'Atendimentos ficam bloqueados até que dois administradores revisem o documento e as ofertas do piloto.';
}

String _etapa(Object? value) => switch (value) {
  'perfil' => 'Perfil',
  'email' => 'E-mail',
  'documentos' => 'Documento de identificação',
  'telefone' => 'Telefone para contato',
  'identidade' => 'Verificação automatizada de identidade',
  'antecedentes' => 'Antecedentes',
  'aprovacao' => 'Habilitação final',
  _ => 'Verificação',
};

String _status(Object? value) => switch (value) {
  'confirmado' => 'Confirmado',
  'cadastrado' => 'Cadastrado',
  'analisado' => 'Documento analisado',
  'nao_exigido_no_piloto' => 'Não exigido nesta fase',
  'nao_verificados_no_piloto' => 'Não verificados nesta fase',
  'nao_verificada_no_piloto' => 'Não utilizada nesta fase',
  'aprovado' => 'Habilitado',
  'teste_local_aprovado' => 'Somente teste local',
  'aguardando_integracao' => 'Ainda não disponível',
  'revisao_necessaria' => 'Precisa de revisão',
  'em_analise' => 'Em análise',
  'suspenso' => 'Suspensa',
  _ => 'Pendente',
};
