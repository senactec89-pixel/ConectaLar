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

  void _recarregar() {
    setState(() {
      _conversasFuture = _carregarConversas(pagina: 1);
      _conversasFuture.ignore();
    });
  }

  Future<void> _carregarMais() async {
    if (_carregandoMais) return;
    setState(() => _carregandoMais = true);
    try {
      final atual = await _conversasFuture;
      if (!atual.hasMore) return;
      final proxima = await _carregarConversas(pagina: atual.page + 1);
      final porId = <int, AtendimentoResumo>{
        for (final item in atual.items) item.solicitacao.id: item,
        for (final item in proxima.items) item.solicitacao.id: item,
      };
      if (!mounted) return;
      setState(() {
        _conversasFuture = Future.value(
          proxima.copyWith(items: porId.values.toList(growable: false)),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar mais conversas.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoMais = false);
    }
  }

  Future<void> _abrirConversa(int solicitacaoId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.conversa,
      arguments: solicitacaoId,
    );
    if (mounted) _recarregar();
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
            if (snapshot.connectionState != ConnectionState.done) {
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
            final conversas = pagina.items
                .where(
                  (servico) =>
                      servico.solicitacao.status ==
                          StatusSolicitacao.aguardandoResposta ||
                      servico.solicitacao.status ==
                          StatusSolicitacao.aceitaAgendada ||
                      servico.solicitacao.status ==
                          StatusSolicitacao.conclusaoPendente ||
                      servico.solicitacao.status ==
                          StatusSolicitacao.conclusaoContestada ||
                      servico.solicitacao.status ==
                          StatusSolicitacao.naoComparecimentoInformado,
                )
                .toList(growable: false);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                const Text(
                  'Chat e negociação',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conversas ficam vinculadas a uma solicitação e não confirmam agendamento por si só.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.35),
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
                  )
                else
                  for (final conversa in conversas) ...[
                    _ConversaCard(
                      conversa: conversa,
                      onTap: () => _abrirConversa(conversa.solicitacao.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                if (pagina.hasMore) ...[
                  const SizedBox(height: 4),
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
  const _ConversaCard({required this.conversa, required this.onTap});

  final AtendimentoResumo conversa;
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
          conversa.profissional,
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
