import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_page.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/page_intro.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late Future<ApiPage<AtendimentoResumo>> _conversasFuture;
  bool _carregandoMais = false;

  @override
  void initState() {
    super.initState();
    _conversasFuture = _carregarConversas();
  }

  Future<ApiPage<AtendimentoResumo>> _carregarConversas({
    int pagina = 1,
  }) async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      final items = ConectaLarMockStore.instance.servicos;
      return ApiPage(
        items: items,
        page: 1,
        limit: items.length,
        total: items.length,
        hasMore: false,
      );
    }

    final response = await services.servicos.minhas(pagina: pagina);
    return apiPageFromResponse(
      response,
      itemsKey: 'solicitacoes',
      mapper: atendimentoResumoFromApi,
      fallbackPage: pagina,
    );
  }

  Future<ApiPage<AtendimentoResumo>> _atualizarPaginas(int atePagina) async {
    final porId = <int, AtendimentoResumo>{};
    ApiPage<AtendimentoResumo>? ultima;
    for (var pagina = 1; pagina <= atePagina; pagina++) {
      final carregada = await _carregarConversas(pagina: pagina);
      for (final item in carregada.items) {
        porId[item.solicitacao.id] = item;
      }
      ultima = carregada;
      if (!carregada.hasMore) break;
    }
    return ultima!.copyWith(items: porId.values.toList(growable: false));
  }

  Future<void> _recarregar() async {
    var atePagina = 1;
    try {
      atePagina = (await _conversasFuture).page;
    } catch (_) {
      // O estado de erro ainda permite tentar novamente desde a primeira página.
    }
    if (!mounted) return;
    setState(() {
      _conversasFuture = _atualizarPaginas(atePagina);
      _conversasFuture.ignore();
    });
  }

  Future<void> _carregarMais() async {
    if (_carregandoMais) return;
    setState(() => _carregandoMais = true);
    final carregamentoAtual = _conversasFuture;
    ApiPage<AtendimentoResumo>? paginasEncontradas;
    try {
      var atual = await carregamentoAtual;
      if (!atual.hasMore) return;
      for (var paginaLida = 0; paginaLida < 5 && atual.hasMore; paginaLida++) {
        final proxima = await _carregarConversas(pagina: atual.page + 1);
        if (!mounted || !identical(carregamentoAtual, _conversasFuture)) {
          return;
        }
        final porId = <int, AtendimentoResumo>{
          for (final item in atual.items) item.solicitacao.id: item,
          for (final item in proxima.items) item.solicitacao.id: item,
        };
        atual = proxima.copyWith(items: porId.values.toList(growable: false));
        paginasEncontradas = atual;
        if (proxima.items.any(_conversaAtiva)) break;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar mais conversas.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (paginasEncontradas != null &&
              identical(carregamentoAtual, _conversasFuture)) {
            _conversasFuture = Future.value(paginasEncontradas);
          }
          _carregandoMais = false;
        });
      }
    }
  }

  bool _conversaAtiva(AtendimentoResumo servico) =>
      switch (servico.solicitacao.status) {
        StatusSolicitacao.aguardandoResposta ||
        StatusSolicitacao.aceitaAgendada ||
        StatusSolicitacao.conclusaoPendente ||
        StatusSolicitacao.conclusaoContestada ||
        StatusSolicitacao.naoComparecimentoInformado => true,
        _ => false,
      };

  Future<void> _abrirConversa(int solicitacaoId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.conversa,
      arguments: solicitacaoId,
    );
    if (mounted) await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Conversas'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<ApiPage<AtendimentoResumo>>(
          future: _conversasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AsyncLoadingView(label: 'Carregando conversas.');
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar suas conversas agora.',
                onRetry: _recarregar,
                icon: Icons.chat_bubble_outline_rounded,
              );
            }
            final pagina = snapshot.requireData;
            final services = AppServices.instance;
            final papelAtual = services.emDemonstracao
                ? store.usuarioAtual.tipo.valorBanco
                : '${services.auth.usuarioAtual?['tipo'] ?? ''}';
            final conversas = pagina.items
                .where(_conversaAtiva)
                .toList(growable: false);

            return ListView(
              key: const PageStorageKey('conversas-lista'),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                if (snapshot.connectionState != ConnectionState.done) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                const PageIntro(
                  title: 'Chat e negociação',
                  subtitle:
                      'Conversas ficam vinculadas a uma solicitação e não confirmam agendamento por si só.',
                ),
                const SizedBox(height: 16),
                if (conversas.isEmpty)
                  EmptyStateView(
                    title: pagina.hasMore
                        ? 'Ainda há pedidos para conferir'
                        : 'Nenhuma conversa ativa',
                    message: pagina.hasMore
                        ? 'Não há conversas ativas entre os pedidos carregados. Carregue mais para continuar procurando.'
                        : 'As conversas ficam disponíveis enquanto a solicitação estiver ativa.',
                    icon: Icons.chat_bubble_outline_rounded,
                    action: pagina.hasMore
                        ? OutlinedButton.icon(
                            onPressed: _carregandoMais ? null : _carregarMais,
                            icon: _carregandoMais
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.expand_more_rounded),
                            label: Text(
                              _carregandoMais
                                  ? 'Carregando conversas'
                                  : 'Procurar em mais pedidos',
                            ),
                          )
                        : null,
                  )
                else
                  for (final conversa in conversas) ...[
                    _ConversaCard(
                      conversa: conversa,
                      papelAtual: papelAtual,
                      onTap: () => _abrirConversa(conversa.solicitacao.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                if (pagina.hasMore && conversas.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Há mais pedidos para conferir. Carregue mais para encontrar outras conversas ativas.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Center(
                    child: OutlinedButton.icon(
                      key: const ValueKey('chat-carregar-mais'),
                      onPressed: _carregandoMais ? null : _carregarMais,
                      icon: _carregandoMais
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _carregandoMais
                            ? 'Carregando conversas'
                            : 'Carregar mais conversas',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversaCard extends StatelessWidget {
  const _ConversaCard({
    required this.conversa,
    required this.papelAtual,
    required this.onTap,
  });

  final AtendimentoResumo conversa;
  final String papelAtual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: ValueKey('chat-solicitacao-${conversa.solicitacao.id}'),
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: AppColors.verdeClaro,
          foregroundColor: AppColors.verdeEscuro,
          child: Icon(Icons.chat_bubble_outline),
        ),
        title: Text(
          conversa.nomeDaOutraParte(papelAtual),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${conversa.categoria} • ${conversa.solicitacao.status.rotulo}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
