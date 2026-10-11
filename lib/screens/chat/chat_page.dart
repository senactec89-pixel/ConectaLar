import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
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
  late Future<List<AtendimentoResumo>> _conversasFuture;

  @override
  void initState() {
    super.initState();
    _conversasFuture = _carregarConversas();
  }

  Future<List<AtendimentoResumo>> _carregarConversas() async {
    final services = AppServices.instance;
    if (!services.auth.autenticado) {
      return ConectaLarMockStore.instance.servicos;
    }

    final response = await services.servicos.minhas();
    return listFromApi(response['solicitacoes'], atendimentoResumoFromApi);
  }

  void _recarregar() {
    setState(() => _conversasFuture = _carregarConversas());
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Conversas'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<List<AtendimentoResumo>>(
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
            final conversas = (snapshot.data ?? const <AtendimentoResumo>[])
                .where(
                  (servico) =>
                      servico.solicitacao.status ==
                          StatusSolicitacao.aguardandoResposta ||
                      servico.solicitacao.status ==
                          StatusSolicitacao.aceitaAgendada,
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
                  const EmptyStateView(
                    title: 'Nenhuma conversa ativa',
                    message:
                        'As conversas ficam disponíveis enquanto a solicitação estiver ativa.',
                    icon: Icons.chat_bubble_outline_rounded,
                  )
                else
                  for (final conversa in conversas) ...[
                    _ConversaCard(
                      conversa: conversa,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.conversa,
                        arguments: conversa.solicitacao.id,
                      ),
                    ),
                    const SizedBox(height: 12),
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
