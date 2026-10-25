import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/mensagem.dart';
import '../../models/solicitacao.dart';
import '../../services/api_page.dart';
import '../../services/api_mappers.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class ConversaPage extends StatefulWidget {
  const ConversaPage({super.key});

  @override
  State<ConversaPage> createState() => _ConversaPageState();
}

class _ConversaPageState extends State<ConversaPage> {
  final _controller = TextEditingController();
  final _mensagensScroll = ScrollController();
  Future<_ConversaData?>? _dataFuture;
  _ConversaData? _dadosExibidos;
  int? _solicitacaoAtual;
  bool _enviando = false;
  bool _atualizando = false;
  bool _carregandoAnteriores = false;
  bool _seguirRecentes = true;
  bool _mostrarIrRecentes = false;
  double _posicaoAnterior = 0;
  double? _extensaoAntesDeCarregar;
  double? _posicaoAntesDeCarregar;

  @override
  void initState() {
    super.initState();
    _mensagensScroll.addListener(() {
      if (!_mensagensScroll.hasClients) return;
      final mostrar = _mensagensScroll.position.extentAfter > 120;
      if (mostrar != _mostrarIrRecentes && mounted) {
        setState(() => _mostrarIrRecentes = mostrar);
      }
    });
  }

  void _registrarPosicao({bool aposEnvio = false}) {
    _seguirRecentes =
        aposEnvio ||
        !_mensagensScroll.hasClients ||
        _mensagensScroll.position.extentAfter < 120;
    _posicaoAnterior = _mensagensScroll.hasClients
        ? _mensagensScroll.offset
        : 0;
  }

  void _restaurarPosicao(_ConversaData data) {
    if (identical(data, _dadosExibidos)) return;
    _dadosExibidos = data;
    final extensaoAntesDeCarregar = _extensaoAntesDeCarregar;
    final posicaoAntesDeCarregar = _posicaoAntesDeCarregar;
    _extensaoAntesDeCarregar = null;
    _posicaoAntesDeCarregar = null;
    void aplicar() {
      if (!mounted ||
          !_mensagensScroll.hasClients ||
          !identical(data, _dadosExibidos)) {
        return;
      }
      final limite = _mensagensScroll.position.maxScrollExtent;
      if (extensaoAntesDeCarregar != null && posicaoAntesDeCarregar != null) {
        final deslocamento = limite - extensaoAntesDeCarregar;
        _mensagensScroll.jumpTo(
          (posicaoAntesDeCarregar + deslocamento).clamp(0, limite),
        );
        return;
      }
      _mensagensScroll.jumpTo(
        _seguirRecentes ? limite : _posicaoAnterior.clamp(0, limite),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      aplicar();
      // A lista pode recalcular sua extensão depois de receber uma mensagem.
      if (_seguirRecentes) {
        WidgetsBinding.instance.addPostFrameCallback((_) => aplicar());
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  Future<void> _irParaRecentes() async {
    if (!_mensagensScroll.hasClients) return;
    await _mensagensScroll.animateTo(
      _mensagensScroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (mounted && _mensagensScroll.hasClients) {
      _mensagensScroll.jumpTo(_mensagensScroll.position.maxScrollExtent);
    }
  }

  Future<void> _atualizar() async {
    if (_atualizando ||
        _enviando ||
        _carregandoAnteriores ||
        _solicitacaoAtual == null) {
      return;
    }
    await _recarregarDados();
  }

  Future<void> _carregarMensagensAnteriores(_ConversaData data) async {
    if (_carregandoAnteriores || !data.temMensagensAnteriores) return;
    if (_mensagensScroll.hasClients) {
      _extensaoAntesDeCarregar = _mensagensScroll.position.maxScrollExtent;
      _posicaoAntesDeCarregar = _mensagensScroll.offset;
    }
    _seguirRecentes = false;
    setState(() => _carregandoAnteriores = true);
    try {
      final response = await AppServices.instance.mensagens.listar(
        data.atendimento.solicitacao.id,
        pagina: data.paginaMensagens + 1,
      );
      final anterior = apiPageFromResponse(
        response,
        itemsKey: 'mensagens',
        mapper: mensagemFromApi,
        fallbackPage: data.paginaMensagens + 1,
      );
      final ids = <int>{};
      final mensagens = <Mensagem>[
        for (final mensagem in [...anterior.items, ...data.mensagens])
          if (ids.add(mensagem.id)) mensagem,
      ];
      if (!mounted) return;
      final atualizada = data.copyWith(
        mensagens: mensagens,
        paginaMensagens: anterior.page,
        temMensagensAnteriores: anterior.hasMore,
      );
      setState(() {
        _dataFuture = Future.value(atualizada);
        _dataFuture?.ignore();
      });
    } catch (_) {
      _extensaoAntesDeCarregar = null;
      _posicaoAntesDeCarregar = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar mensagens anteriores.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoAnteriores = false);
    }
  }

  Future<_ConversaData?> _recarregarDados() async {
    _registrarPosicao();
    final future = _carregarConversa(_solicitacaoAtual);
    future.ignore();
    setState(() {
      _atualizando = true;
      _dataFuture = future;
    });
    try {
      return await future;
    } catch (_) {
      // O FutureBuilder apresenta o erro e permite uma nova tentativa.
      return null;
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  Future<void> _abrirDetalhes() async {
    if (_solicitacaoAtual == null) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.detalhesServico,
      arguments: _solicitacaoAtual,
    );
    if (mounted) await _atualizar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _mensagensScroll.dispose();
    super.dispose();
  }

  int? _solicitacaoId(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is int) return arguments;
    if (arguments is Solicitacao) return arguments.id;
    return null;
  }

  Future<_ConversaData?> _carregarConversa(int? solicitacaoId) async {
    if (solicitacaoId == null) return null;
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      final store = ConectaLarMockStore.instance;
      final atendimento = store.atendimentoPorId(solicitacaoId);
      if (atendimento == null) return null;
      return _ConversaData(
        atendimento: atendimento,
        mensagens: store.mensagensDaSolicitacao(solicitacaoId),
        usuarioAtualId: store.usuarioAtual.id,
        papelAtual: store.usuarioAtual.tipo.valorBanco,
        paginaMensagens: 1,
        temMensagensAnteriores: false,
        consultadoEm: DateTime.now(),
      );
    }

    final responses = await Future.wait([
      services.servicos.obter(solicitacaoId),
      services.mensagens.listar(solicitacaoId),
    ]);
    final solicitacao = responses[0]['solicitacao'];
    if (solicitacao is! Map<String, dynamic>) return null;

    final paginaMensagens = apiPageFromResponse(
      responses[1],
      itemsKey: 'mensagens',
      mapper: mensagemFromApi,
    );
    return _ConversaData(
      atendimento: atendimentoResumoFromApi(solicitacao),
      mensagens: paginaMensagens.items,
      usuarioAtualId: intValue(services.auth.usuarioAtual?['id']),
      papelAtual: stringValue(services.auth.usuarioAtual?['tipo']),
      paginaMensagens: paginaMensagens.page,
      temMensagensAnteriores: paginaMensagens.hasMore,
      consultadoEm: DateTime.now(),
    );
  }

  Future<void> _enviar(_ConversaData data) async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando || _atualizando || !data.podeEnviar) return;
    final solicitacaoId = data.atendimento.solicitacao.id;

    setState(() => _enviando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        await AppServices.instance.mensagens.enviar(
          solicitacaoId: solicitacaoId,
          texto: texto,
        );
      } else if (AppServices.instance.emDemonstracao) {
        ConectaLarMockStore.instance.enviarMensagem(
          solicitacaoId: solicitacaoId,
          conteudo: texto,
        );
      } else {
        throw StateError('Sessão encerrada.');
      }
      if (!mounted) return;
      _controller.clear();
      _registrarPosicao(aposEnvio: true);
      setState(() {
        _dataFuture = _carregarConversa(solicitacaoId);
        _dataFuture?.ignore();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      _ConversaData? atualizada;
      if ({400, 403, 404, 409}.contains(error.statusCode)) {
        // O pedido pode ter sido encerrado em outro aparelho. A API continua
        // decidindo a permissão, sem repetir o envio nem apagar o rascunho.
        atualizada = await _recarregarDados();
      }
      if (!mounted) return;
      _mostrarFalhaEnvio(
        atualizada != null && !atualizada.conversaAberta
            ? 'Este atendimento foi encerrado. Novas mensagens não podem ser enviadas.'
            : atualizada != null && !atualizada.podeEnviar
            ? 'Esta conversa está disponível somente para consulta.'
            : 'Não foi possível enviar a mensagem.',
      );
    } catch (_) {
      if (!mounted) return;
      _mostrarFalhaEnvio('Não foi possível enviar a mensagem.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarFalhaEnvio(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    final solicitacaoId = _solicitacaoId(context);
    if (_dataFuture == null || _solicitacaoAtual != solicitacaoId) {
      _solicitacaoAtual = solicitacaoId;
      _dadosExibidos = null;
      _seguirRecentes = true;
      _dataFuture = _carregarConversa(solicitacaoId);
      _dataFuture?.ignore();
    }

    return Scaffold(
      appBar: AppBarCustom(
        title: 'Conversa',
        actions: [
          IconButton(
            tooltip: 'Atualizar conversa',
            onPressed: _atualizando || _enviando ? null : _atualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<_ConversaData?>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AsyncLoadingView(label: 'Carregando conversa.');
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar a conversa.',
                onRetry: _atualizar,
              );
            }
            final data = snapshot.data;
            if (data == null) return const _ConversaIndisponivel();
            _restaurarPosicao(data);
            return Column(
              children: [
                if (_atualizando || _enviando || _carregandoAnteriores)
                  const LinearProgressIndicator(),
                _ContextoServico(
                  atendimento: data.atendimento,
                  papelAtual: data.papelAtual,
                  consultadoEm: data.consultadoEm,
                  onDetalhes: _enviando || _atualizando ? null : _abrirDetalhes,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _atualizar,
                        child: ListView(
                          controller: _mensagensScroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          children: [
                            if (data.temMensagensAnteriores) ...[
                              Center(
                                child: OutlinedButton.icon(
                                  key: const ValueKey(
                                    'chat-carregar-anteriores',
                                  ),
                                  onPressed: _carregandoAnteriores
                                      ? null
                                      : () =>
                                            _carregarMensagensAnteriores(data),
                                  icon: const Icon(Icons.expand_less_rounded),
                                  label: const Text('Mensagens anteriores'),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (data.mensagens.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  !data.conversaAberta
                                      ? 'Não houve mensagens nesta conversa. Este atendimento está encerrado.'
                                      : data.podeEnviar
                                      ? 'Ainda não há mensagens. Use a conversa para alinhar os detalhes do serviço.'
                                      : 'Ainda não há mensagens nesta conversa.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            for (final mensagem in data.mensagens)
                              _MensagemBolha(
                                mensagem: mensagem,
                                enviadaPorMim:
                                    mensagem.remetenteId == data.usuarioAtualId,
                              ),
                            if (data.atendimento.solicitacao.status ==
                                StatusSolicitacao.aceitaAgendada)
                              _PropostaAgendada(atendimento: data.atendimento),
                          ],
                        ),
                      ),
                      if (_mostrarIrRecentes)
                        Positioned(
                          left: AppSpace.md,
                          right: AppSpace.md,
                          bottom: AppSpace.md,
                          child: FilledButton.icon(
                            key: const ValueKey('chat-ir-recentes'),
                            onPressed: _irParaRecentes,
                            icon: const Icon(Icons.arrow_downward_rounded),
                            label: const Text('Mensagens recentes'),
                          ),
                        ),
                    ],
                  ),
                ),
                if (data.podeEnviar)
                  _CampoMensagem(
                    controller: _controller,
                    onEnviar: _enviando || _atualizando
                        ? null
                        : () => _enviar(data),
                  )
                else
                  _ConversaSomenteLeitura(
                    mensagem: data.conversaAberta
                        ? 'Conversa somente para consulta.'
                        : 'Conversa encerrada: ${data.atendimento.solicitacao.status.rotulo}.',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversaData {
  const _ConversaData({
    required this.atendimento,
    required this.mensagens,
    required this.usuarioAtualId,
    required this.papelAtual,
    required this.paginaMensagens,
    required this.temMensagensAnteriores,
    required this.consultadoEm,
  });

  final AtendimentoResumo atendimento;
  final List<Mensagem> mensagens;
  final int usuarioAtualId;
  final String papelAtual;
  final int paginaMensagens;
  final bool temMensagensAnteriores;
  final DateTime consultadoEm;

  _ConversaData copyWith({
    List<Mensagem>? mensagens,
    int? paginaMensagens,
    bool? temMensagensAnteriores,
  }) {
    return _ConversaData(
      atendimento: atendimento,
      mensagens: mensagens ?? this.mensagens,
      usuarioAtualId: usuarioAtualId,
      papelAtual: papelAtual,
      paginaMensagens: paginaMensagens ?? this.paginaMensagens,
      temMensagensAnteriores:
          temMensagensAnteriores ?? this.temMensagensAnteriores,
      consultadoEm: consultadoEm,
    );
  }

  bool get conversaAberta =>
      atendimento.solicitacao.status == StatusSolicitacao.aguardandoResposta ||
      atendimento.solicitacao.status == StatusSolicitacao.aceitaAgendada ||
      atendimento.solicitacao.status == StatusSolicitacao.conclusaoPendente ||
      atendimento.solicitacao.status == StatusSolicitacao.conclusaoContestada ||
      atendimento.solicitacao.status ==
          StatusSolicitacao.naoComparecimentoInformado;

  bool get podeEnviar {
    final solicitacao = atendimento.solicitacao;
    final participante =
        (papelAtual == 'cliente' && solicitacao.clienteId == usuarioAtualId) ||
        ({'profissional', 'empresa'}.contains(papelAtual) &&
            solicitacao.profissionalUsuarioId == usuarioAtualId);
    return conversaAberta && participante;
  }
}

class _ContextoServico extends StatelessWidget {
  const _ContextoServico({
    required this.atendimento,
    required this.papelAtual,
    required this.consultadoEm,
    required this.onDetalhes,
  });

  final AtendimentoResumo atendimento;
  final String papelAtual;
  final DateTime consultadoEm;
  final VoidCallback? onDetalhes;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.verdeClaro,
            foregroundColor: AppColors.verdeEscuro,
            child: Icon(Icons.home_repair_service_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atendimento.nomeDaOutraParte(papelAtual),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${atendimento.categoria} • ${atendimento.solicitacao.status.rotulo}',
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Atualizada às ${consultadoEm.hour.toString().padLeft(2, '0')}:${consultadoEm.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ver detalhes',
            onPressed: onDetalhes,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}

class _MensagemBolha extends StatelessWidget {
  const _MensagemBolha({required this.mensagem, required this.enviadaPorMim});

  final Mensagem mensagem;
  final bool enviadaPorMim;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: enviadaPorMim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: enviadaPorMim ? AppColors.verde : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          mensagem.conteudo,
          style: TextStyle(
            color: enviadaPorMim ? Colors.white : AppColors.texto,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _PropostaAgendada extends StatelessWidget {
  const _PropostaAgendada({required this.atendimento});

  final AtendimentoResumo atendimento;

  @override
  Widget build(BuildContext context) {
    final data = atendimento.solicitacao.dataServico;
    final dataFormatada =
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agendamento registrado',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$dataFormatada às ${atendimento.solicitacao.horarioServico}',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 10),
            const Text(
              'A conversa ajuda a alinhar detalhes, mas não muda o status do atendimento.',
              style: TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoMensagem extends StatelessWidget {
  const _CampoMensagem({required this.controller, required this.onEnviar});

  final TextEditingController controller;
  final VoidCallback? onEnviar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-mensagem'),
                controller: controller,
                enabled: onEnviar != null,
                decoration: const InputDecoration(
                  hintText: 'Digite sua mensagem',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('chat-enviar'),
              tooltip: 'Enviar',
              onPressed: onEnviar,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversaSomenteLeitura extends StatelessWidget {
  const _ConversaSomenteLeitura({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.textoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagem,
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversaIndisponivel extends StatelessWidget {
  const _ConversaIndisponivel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Conversa indisponível. Selecione uma solicitação autorizada.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
