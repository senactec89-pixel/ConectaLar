import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_mappers.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class DetalhesServicoPage extends StatefulWidget {
  const DetalhesServicoPage({super.key});

  @override
  State<DetalhesServicoPage> createState() => _DetalhesServicoPageState();
}

class _DetalhesServicoPageState extends State<DetalhesServicoPage> {
  int? _solicitacaoId;
  bool _argumentosLidos = false;
  late Future<AtendimentoResumo?> _atendimentoFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final id = arguments is Solicitacao
        ? arguments.id
        : arguments is int
        ? arguments
        : null;
    _solicitacaoId = id != null && id > 0 ? id : null;
    _atendimentoFuture = _carregarAtendimento();
    _argumentosLidos = true;
  }

  Future<AtendimentoResumo?> _carregarAtendimento() async {
    final solicitacaoId = _solicitacaoId;
    if (solicitacaoId == null) return null;

    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return ConectaLarMockStore.instance.atendimentoPorId(solicitacaoId);
    }

    try {
      final response = await services.servicos.obter(solicitacaoId);
      final solicitacao = response['solicitacao'];
      if (solicitacao is! Map<String, dynamic> ||
          intValue(solicitacao['id']) != solicitacaoId) {
        throw const FormatException('Resposta da solicitação inválida.');
      }
      return atendimentoResumoFromApi(solicitacao);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  void _recarregar() {
    setState(() {
      _atendimentoFuture = _carregarAtendimento();
      _atendimentoFuture.ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Detalhes do serviço'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: _solicitacaoId == null
            ? const _DetalhesVazio(selecionada: false)
            : AppServices.instance.emDemonstracao
            ? AnimatedBuilder(
                animation: store,
                builder: (context, _) {
                  final atualizado = store.atendimentoPorId(_solicitacaoId!);
                  return atualizado == null
                      ? const _DetalhesVazio()
                      : _DetalhesSolicitacao(
                          atendimento: atualizado,
                          store: store,
                        );
                },
              )
            : FutureBuilder<AtendimentoResumo?>(
                future: _atendimentoFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AsyncLoadingView(
                      label: 'Carregando solicitação.',
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return AsyncErrorView(
                      message: error is FormatException
                          ? 'Não foi possível ler os dados desta solicitação. Tente novamente.'
                          : error is ApiException && error.statusCode == 403
                          ? 'Sua conta não tem acesso a esta solicitação.'
                          : 'Não foi possível carregar esta solicitação.',
                      onRetry: _recarregar,
                    );
                  }
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

  Map<String, dynamic> get _ator =>
      AppServices.instance.auth.usuarioAtual ??
      (AppServices.instance.emDemonstracao
          ? {
              'id': widget.store.usuarioAtual.id,
              'tipo': widget.store.usuarioAtual.tipo.valorBanco,
            }
          : <String, dynamic>{});
  bool get _clienteParticipante =>
      _ator['tipo'] == 'cliente' &&
      _atendimento.solicitacao.clienteId == intValue(_ator['id']);
  bool get _profissionalParticipante =>
      {'profissional', 'empresa'}.contains(_ator['tipo']) &&
      _atendimento.solicitacao.profissionalUsuarioId == intValue(_ator['id']);

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

  Future<void> _atualizarAposConflito() async {
    try {
      final response = await AppServices.instance.servicos.obter(
        _atendimento.solicitacao.id,
      );
      final pedido = response['solicitacao'];
      if (mounted && pedido is Map<String, dynamic>) {
        setState(() => _atendimento = atendimentoResumoFromApi(pedido));
      }
    } catch (_) {
      // A mensagem original permanece quando não for possível recarregar.
    }
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
        if (!mounted) return;
        final solicitacao = response['solicitacao'];
        if (solicitacao is Map<String, dynamic>) {
          setState(() => _atendimento = atendimentoResumoFromApi(solicitacao));
        }
        _notificar(sucesso);
      } else if (AppServices.instance.emDemonstracao) {
        final ok = fallback(_atendimento.solicitacao.id);
        final atualizado = widget.store.atendimentoPorId(
          _atendimento.solicitacao.id,
        );
        if (atualizado != null) setState(() => _atendimento = atualizado);
        _notificar(ok ? sucesso : falha);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 409) await _atualizarAposConflito();
      if (mounted) _notificar(error.message);
    } catch (_) {
      if (mounted) _notificar(falha);
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
      'Solicitação aceita e agendada.',
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
      'A conclusão só pode ser confirmada após o aceite e agendamento.',
    );
  }

  Future<void> _avaliar() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        final avaliar = _profissionalParticipante
            ? AppServices.instance.avaliacoes.avaliarCliente
            : AppServices.instance.avaliacoes.avaliarProfissional;
        await avaliar(
          solicitacaoId: _atendimento.solicitacao.id,
          nota: _nota,
          comentario: _comentarioController.text,
        );
        if (!mounted) return;
        await _atualizarAvaliacaoRegistrada();
        _notificar('Avaliação registrada e enviada para moderação.');
      } else if (AppServices.instance.emDemonstracao) {
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
    } on ApiException catch (error) {
      if (error.statusCode == 409) await _atualizarAposConflito();
      if (mounted) _notificar(error.message);
    } catch (_) {
      if (mounted) _notificar('Avaliação indisponível para este status.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _atualizarAvaliacaoRegistrada() async {
    try {
      final response = await AppServices.instance.servicos.obter(
        _atendimento.solicitacao.id,
      );
      final solicitacao = response['solicitacao'];
      if (!mounted || solicitacao is! Map<String, dynamic>) return;
      setState(() => _atendimento = atendimentoResumoFromApi(solicitacao));
    } catch (_) {
      if (mounted) {
        setState(() => _atendimento = _atendimento.copyWith(avaliado: true));
      }
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
                      : 'Bairro visível. O endereço completo fica protegido até o aceite e agendamento.',
                ),
                _DetalheLinha(
                  icon: Icons.home_repair_service_outlined,
                  label: 'Descrição',
                  value: solicitacao.descricao,
                ),
                _DetalheLinha(
                  icon: Icons.payments_outlined,
                  label: 'Preço inicial',
                  value: solicitacao.precoInicial == null
                      ? 'A combinar fora do app'
                      : 'R\$ ${solicitacao.precoInicial!.toStringAsFixed(2).replaceAll('.', ',')} - pagamento fora do app',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AcoesAtendimento(
          solicitacao: solicitacao,
          avaliado: atendimento.avaliado,
          cliente: _clienteParticipante,
          profissional: _profissionalParticipante,
          ocupada: _enviando,
          onConversar: () => Navigator.pushNamed(
            context,
            AppRoutes.conversa,
            arguments: solicitacao.id,
          ),
          onDenunciar: () => Navigator.pushNamed(
            context,
            AppRoutes.denunciarServico,
            arguments: atendimento,
          ),
          onCancelar: () => _cancelar(),
          onAceitar: () => _aceitar(),
          onRecusar: () => _recusar(),
          onConcluir: () => _concluir(),
        ),
        if (solicitacao.status == StatusSolicitacao.conclusaoConfirmada &&
            !atendimento.avaliado &&
            (_clienteParticipante || _profissionalParticipante)) ...[
          const SizedBox(height: 16),
          _FormularioAvaliacao(
            titulo: _profissionalParticipante
                ? 'Avaliar cliente'
                : 'Avaliar profissional',
            nota: _nota,
            controller: _comentarioController,
            onNotaChanged: (nota) => setState(() => _nota = nota),
            onAvaliar: _enviando ? null : () => _avaliar(),
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
    required this.onDenunciar,
    required this.onCancelar,
    required this.onAceitar,
    required this.onRecusar,
    required this.onConcluir,
    required this.cliente,
    required this.profissional,
    required this.ocupada,
  });

  final Solicitacao solicitacao;
  final bool avaliado;
  final VoidCallback onConversar;
  final VoidCallback onDenunciar;
  final VoidCallback onCancelar;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final VoidCallback onConcluir;
  final bool cliente;
  final bool profissional;
  final bool ocupada;

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
                if ((cliente || profissional) &&
                    (solicitacao.status ==
                            StatusSolicitacao.aguardandoResposta ||
                        solicitacao.status == StatusSolicitacao.aceitaAgendada))
                  OutlinedButton.icon(
                    onPressed: ocupada ? null : onConversar,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Conversar'),
                  ),
                if (cliente || profissional)
                  OutlinedButton.icon(
                    onPressed: ocupada ? null : onDenunciar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.erro,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Denunciar'),
                  ),
                if (profissional &&
                    solicitacao.status == StatusSolicitacao.aguardandoResposta)
                  FilledButton.icon(
                    key: const ValueKey('detalhes-aceitar'),
                    onPressed: ocupada ? null : onAceitar,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aceitar solicitação'),
                  ),
                if (profissional &&
                    solicitacao.status == StatusSolicitacao.aguardandoResposta)
                  OutlinedButton.icon(
                    onPressed: ocupada ? null : onRecusar,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Recusar'),
                  ),
                if (cliente &&
                    (solicitacao.status ==
                            StatusSolicitacao.aguardandoResposta ||
                        solicitacao.status == StatusSolicitacao.aceitaAgendada))
                  OutlinedButton.icon(
                    onPressed: ocupada ? null : onCancelar,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                if (cliente &&
                    solicitacao.status == StatusSolicitacao.aceitaAgendada)
                  FilledButton.icon(
                    key: const ValueKey('detalhes-concluir'),
                    onPressed: ocupada ? null : onConcluir,
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
    required this.titulo,
  });

  final int nota;
  final TextEditingController controller;
  final ValueChanged<int> onNotaChanged;
  final VoidCallback? onAvaliar;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Depois do envio, a avaliação fica salva e aguarda moderação antes de aparecer no perfil público.',
              style: TextStyle(color: AppColors.textoSuave),
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
        'de ações, endereço e chat segue as permissões da sua conta.',
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
  const _DetalhesVazio({this.selecionada = true});

  final bool selecionada;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      title: selecionada
          ? 'Solicitação não encontrada'
          : 'Nenhuma solicitação foi selecionada.',
      message: selecionada
          ? 'Este atendimento não está disponível. Volte à lista de serviços para conferir seus pedidos.'
          : 'Abra um atendimento na lista de serviços para ver os detalhes.',
      icon: Icons.event_busy_outlined,
    );
  }
}
