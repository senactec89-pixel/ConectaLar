import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';

class DetalhesServicoPage extends StatelessWidget {
  const DetalhesServicoPage({super.key});

  int? _solicitacaoId(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is int) return arguments;
    if (arguments is Solicitacao) return arguments.id;
    return null;
  }

  Future<AtendimentoResumo?> _carregarAtendimento(int? solicitacaoId) async {
    if (solicitacaoId == null) return null;

    final services = AppServices.instance;
    if (!services.auth.autenticado) {
      return ConectaLarMockStore.instance.atendimentoPorId(solicitacaoId);
    }

    final response = await services.servicos.obter(solicitacaoId);
    final solicitacao = response['solicitacao'];
    return solicitacao is Map<String, dynamic>
        ? atendimentoResumoFromApi(solicitacao)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    final solicitacaoId = _solicitacaoId(context);
    if (!AppServices.instance.auth.autenticado) {
      return Scaffold(
        appBar: const AppBarCustom(title: 'Detalhes do serviço'),
        backgroundColor: AppColors.fundo,
        body: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              final atualizado = solicitacaoId == null
                  ? null
                  : store.atendimentoPorId(solicitacaoId);
              return atualizado == null
                  ? const _DetalhesVazio()
                  : _DetalhesSolicitacao(atendimento: atualizado, store: store);
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const AppBarCustom(title: 'Detalhes do serviço'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => FutureBuilder<AtendimentoResumo?>(
            future: _carregarAtendimento(solicitacaoId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return const _DetalhesErro();
              final atendimento = snapshot.data;
              return atendimento == null
                  ? const _DetalhesVazio()
                  : _DetalhesSolicitacao(
                      atendimento: atendimento,
                      store: store,
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _DetalhesSolicitacao extends StatefulWidget {
  const _DetalhesSolicitacao({required this.atendimento, required this.store});

  final AtendimentoResumo atendimento;
  final ConectaLarMockStore store;

  @override
  State<_DetalhesSolicitacao> createState() => _DetalhesSolicitacaoState();
}

class _DetalhesSolicitacaoState extends State<_DetalhesSolicitacao> {
  final _comentarioController = TextEditingController();
  int _nota = 5;
  late AtendimentoResumo _atendimento;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _atendimento = widget.atendimento;
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  void _notificar(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _executarTransicao(
    Future<Map<String, dynamic>> Function(int id) request,
    bool Function(int id) fallback,
    String sucesso,
    String falha,
  ) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        final response = await request(_atendimento.solicitacao.id);
        final solicitacao = response['solicitacao'];
        if (solicitacao is Map<String, dynamic>) {
          setState(() => _atendimento = atendimentoResumoFromApi(solicitacao));
        }
        _notificar(sucesso);
      } else {
        final ok = fallback(_atendimento.solicitacao.id);
        final atualizado = widget.store.atendimentoPorId(
          _atendimento.solicitacao.id,
        );
        if (atualizado != null) setState(() => _atendimento = atualizado);
        _notificar(ok ? sucesso : falha);
      }
    } catch (_) {
      _notificar(falha);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar() {
    return _executarTransicao(
      AppServices.instance.servicos.cancelar,
      widget.store.cancelarSolicitacao,
      'Solicitação cancelada.',
      'Cancelamento não permitido para este status.',
    );
  }

  Future<void> _aceitar() {
    return _executarTransicao(
      AppServices.instance.servicos.aceitar,
      widget.store.aceitarSolicitacaoComoProfissional,
      'Solicitação aceita e registrada como aceita_agendada.',
      'Aceite não permitido para este status.',
    );
  }

  Future<void> _recusar() {
    return _executarTransicao(
      AppServices.instance.servicos.recusar,
      widget.store.recusarSolicitacaoComoProfissional,
      'Solicitação recusada.',
      'Recusa não permitida para este status.',
    );
  }

  Future<void> _concluir() {
    return _executarTransicao(
      AppServices.instance.servicos.concluir,
      widget.store.confirmarConclusao,
      'Conclusão confirmada pelo cliente.',
      'Conclusão só é permitida para aceita_agendada.',
    );
  }

  Future<void> _avaliar() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        await AppServices.instance.avaliacoes.avaliarProfissional(
          solicitacaoId: _atendimento.solicitacao.id,
          nota: _nota,
          comentario: _comentarioController.text,
        );
        setState(() => _atendimento = _atendimento.copyWith(avaliado: true));
        _notificar('Avaliação registrada.');
      } else {
        final ok = widget.store.avaliarAtendimento(
          solicitacaoId: _atendimento.solicitacao.id,
          nota: _nota,
          comentario: _comentarioController.text,
        );
        final atualizado = widget.store.atendimentoPorId(
          _atendimento.solicitacao.id,
        );
        if (atualizado != null) setState(() => _atendimento = atualizado);
        _notificar(
          ok
              ? 'Avaliação registrada.'
              : 'Avaliação indisponível para este status.',
        );
      }
    } catch (_) {
      _notificar('Avaliação indisponível para este status.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atendimento = _atendimento;
    final solicitacao = atendimento.solicitacao;
    final data = solicitacao.dataServico;
    final dataFormatada =
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitação #${solicitacao.id}',
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  solicitacao.status.rotulo,
                  style: const TextStyle(
                    color: AppColors.verdeEscuro,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _DetalheLinha(
                  icon: Icons.person_outline,
                  label: 'Profissional',
                  value: atendimento.profissional,
                ),
                _DetalheLinha(
                  icon: Icons.event_outlined,
                  label: 'Data e horário',
                  value: '$dataFormatada às ${solicitacao.horarioServico}',
                ),
                _DetalheLinha(
                  icon: Icons.location_on_outlined,
                  label: 'Endereço',
                  value: solicitacao.status == StatusSolicitacao.aceitaAgendada
                      ? 'Endereço completo liberado somente ao participante autorizado.'
                      : 'Bairro visível. Endereço completo protegido até aceita_agendada.',
                ),
                _DetalheLinha(
                  icon: Icons.home_repair_service_outlined,
                  label: 'Descrição',
                  value: solicitacao.descricao,
                ),
                _DetalheLinha(
                  icon: Icons.payments_outlined,
                  label: 'Preço inicial',
                  value:
                      'R\$ ${solicitacao.precoInicial.toStringAsFixed(0)} - pagamento fora do app',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AcoesAtendimento(
          solicitacao: solicitacao,
          avaliado: atendimento.avaliado,
          onConversar: () => Navigator.pushNamed(
            context,
            AppRoutes.conversa,
            arguments: solicitacao.id,
          ),
          onCancelar: () => _cancelar(),
          onAceitar: () => _aceitar(),
          onRecusar: () => _recusar(),
          onConcluir: () => _concluir(),
        ),
        if (solicitacao.status == StatusSolicitacao.conclusaoConfirmada &&
            !atendimento.avaliado) ...[
          const SizedBox(height: 16),
          _FormularioAvaliacao(
            nota: _nota,
            controller: _comentarioController,
            onNotaChanged: (nota) => setState(() => _nota = nota),
            onAvaliar: () => _avaliar(),
          ),
        ],
        const SizedBox(height: 16),
        const _RegraStatus(),
      ],
    );
  }
}

class _AcoesAtendimento extends StatelessWidget {
  const _AcoesAtendimento({
    required this.solicitacao,
    required this.avaliado,
    required this.onConversar,
    required this.onCancelar,
    required this.onAceitar,
    required this.onRecusar,
    required this.onConcluir,
  });

  final Solicitacao solicitacao;
  final bool avaliado;
  final VoidCallback onConversar;
  final VoidCallback onCancelar;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final VoidCallback onConcluir;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ações do fluxo',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (solicitacao.status ==
                        StatusSolicitacao.aguardandoResposta ||
                    solicitacao.status == StatusSolicitacao.aceitaAgendada)
                  OutlinedButton.icon(
                    onPressed: onConversar,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Conversar'),
                  ),
                if (solicitacao.status == StatusSolicitacao.aguardandoResposta)
                  FilledButton.icon(
                    key: const ValueKey('detalhes-aceitar'),
                    onPressed: onAceitar,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aceitar como profissional'),
                  ),
                if (solicitacao.status == StatusSolicitacao.aguardandoResposta)
                  OutlinedButton.icon(
                    onPressed: onRecusar,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Recusar'),
                  ),
                if (solicitacao.status ==
                        StatusSolicitacao.aguardandoResposta ||
                    solicitacao.status == StatusSolicitacao.aceitaAgendada)
                  OutlinedButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                if (solicitacao.status == StatusSolicitacao.aceitaAgendada)
                  FilledButton.icon(
                    key: const ValueKey('detalhes-concluir'),
                    onPressed: onConcluir,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Confirmar conclusão'),
                  ),
                if (solicitacao.status == StatusSolicitacao.conclusaoConfirmada)
                  Chip(
                    avatar: Icon(
                      avaliado ? Icons.star : Icons.rate_review_outlined,
                    ),
                    label: Text(avaliado ? 'Avaliado' : 'Avaliação liberada'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioAvaliacao extends StatelessWidget {
  const _FormularioAvaliacao({
    required this.nota,
    required this.controller,
    required this.onNotaChanged,
    required this.onAvaliar,
  });

  final int nota;
  final TextEditingController controller;
  final ValueChanged<int> onNotaChanged;
  final VoidCallback onAvaliar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avaliar profissional',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              key: const ValueKey('avaliacao-nota'),
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 5, label: Text('5')),
              ],
              selected: {nota},
              onSelectionChanged: (value) => onNotaChanged(value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('avaliacao-comentario'),
              controller: controller,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentário',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('avaliacao-enviar'),
                onPressed: onAvaliar,
                icon: const Icon(Icons.star_rounded),
                label: const Text('Enviar avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalheLinha extends StatelessWidget {
  const _DetalheLinha({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.verdeEscuro),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegraStatus extends StatelessWidget {
  const _RegraStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'A solicitação só vira agendamento confirmado quando o profissional '
        'aceita e o sistema registra a confirmação do agendamento. A proteção real '
        'de ações, endereço e chat deve ser validada pela API.',
        style: TextStyle(
          color: AppColors.texto,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _DetalhesVazio extends StatelessWidget {
  const _DetalhesVazio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhuma solicitação foi selecionada.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DetalhesErro extends StatelessWidget {
  const _DetalhesErro();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Não foi possível carregar esta solicitação.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
