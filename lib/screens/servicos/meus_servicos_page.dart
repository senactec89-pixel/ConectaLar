import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/bottom_navigation.dart';

class MeusServicosPage extends StatefulWidget {
  const MeusServicosPage({super.key});

  @override
  State<MeusServicosPage> createState() => _MeusServicosPageState();
}

class _MeusServicosPageState extends State<MeusServicosPage> {
  _FiltroServicos _filtro = _FiltroServicos.todos;
  late Future<List<AtendimentoResumo>> _servicosFuture;

  @override
  void initState() {
    super.initState();
    _servicosFuture = _carregarServicos();
  }

  Future<List<AtendimentoResumo>> _carregarServicos() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return ConectaLarMockStore.instance.servicos;
    }

    final response = await services.servicos.minhas();
    return listFromApi(response['solicitacoes'], atendimentoResumoFromApi);
  }

  Future<void> _recarregarServicos() async {
    if (!mounted) return;
    final carregamento = _carregarServicos();
    setState(() {
      _servicosFuture = carregamento;
    });
    try {
      await carregamento;
    } catch (_) {
      // O FutureBuilder apresenta o erro e permite uma nova tentativa.
    }
  }

  List<AtendimentoResumo> _servicosFiltrados(List<AtendimentoResumo> servicos) {
    return servicos.where((servico) {
      return _filtro.statuses == null ||
          _filtro.statuses!.contains(servico.solicitacao.status);
    }).toList();
  }

  Future<void> _abrirDetalhes(int solicitacaoId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.detalhesServico,
      arguments: solicitacaoId,
    );
    if (mounted) _recarregarServicos();
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Meus serviços'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<List<AtendimentoResumo>>(
          future: _servicosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AsyncLoadingView(label: 'Carregando seus serviços.');
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar seus serviços agora.',
                onRetry: _recarregarServicos,
                icon: Icons.event_busy_outlined,
              );
            }
            final servicos = _servicosFiltrados(snapshot.data ?? const []);
            return SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _recarregarServicos,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    const _AvisoStatus(),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filtro in _FiltroServicos.values) ...[
                            _FiltroChip(
                              filtro: filtro,
                              selecionado: filtro == _filtro,
                              onSelected: () =>
                                  setState(() => _filtro = filtro),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (servicos.isEmpty)
                      _ListaVazia(
                        filtro: _filtro,
                        onBuscar: () =>
                            Navigator.pushNamed(context, AppRoutes.busca),
                        onVerTodos: () =>
                            setState(() => _filtro = _FiltroServicos.todos),
                      )
                    else
                      for (final servico in servicos) ...[
                        _ServicoCard(
                          resumo: servico,
                          onTap: () => _abrirDetalhes(servico.solicitacao.id),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationCustom(
        currentIndex: 3,
        onDestinationSelected: (index) =>
            navigateToMainDestination(context, index),
      ),
    );
  }
}

class _AvisoStatus extends StatelessWidget {
  const _AvisoStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.verdeEscuro),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pedidos enviados aguardam resposta. O agendamento só existe '
              'quando o profissional aceita a solicitação.',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({
    required this.filtro,
    required this.selecionado,
    required this.onSelected,
  });

  final _FiltroServicos filtro;
  final bool selecionado;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: ValueKey('servicos-filtro-${filtro.key}'),
      label: Text(filtro.label),
      selected: selecionado,
      selectedColor: AppColors.verdeClaro,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selecionado ? AppColors.verdeEscuro : AppColors.texto,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selecionado ? AppColors.verde : const Color(0xFFE0E7E3),
      ),
      showCheckmark: false,
    );
  }
}

class _ServicoCard extends StatelessWidget {
  const _ServicoCard({required this.resumo, required this.onTap});

  final AtendimentoResumo resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final solicitacao = resumo.solicitacao;
    final data = solicitacao.dataServico;
    final dataFormatada =
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';

    return Card(
      child: InkWell(
        key: ValueKey('servico-${solicitacao.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resumo.categoria,
                          style: const TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resumo.profissional,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: solicitacao.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                solicitacao.descricao,
                style: const TextStyle(color: AppColors.texto, height: 1.35),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _ResumoIcone(
                    icon: Icons.event_outlined,
                    text: '$dataFormatada às ${solicitacao.horarioServico}',
                  ),
                  _ResumoIcone(
                    icon: Icons.payments_outlined,
                    text: solicitacao.precoInicial == null
                        ? 'Preço a combinar fora do app'
                        : 'A partir de R\$ ${solicitacao.precoInicial!.toStringAsFixed(2).replaceAll('.', ',')}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (solicitacao.status ==
                            StatusSolicitacao.aguardandoResposta ||
                        solicitacao.status ==
                            StatusSolicitacao.aceitaAgendada ||
                        solicitacao.status ==
                            StatusSolicitacao.conclusaoPendente ||
                        solicitacao.status ==
                            StatusSolicitacao.conclusaoContestada ||
                        solicitacao.status ==
                            StatusSolicitacao.naoComparecimentoInformado)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.conversa,
                          arguments: solicitacao.id,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Conversar'),
                      ),
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Ver detalhes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final StatusSolicitacao status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StatusSolicitacao.aguardandoResposta => const Color(0xFF9A6415),
      StatusSolicitacao.aceitaAgendada => AppColors.verde,
      StatusSolicitacao.recusada => AppColors.erro,
      StatusSolicitacao.cancelada => AppColors.textoSuave,
      StatusSolicitacao.conclusaoPendente => const Color(0xFF9A6415),
      StatusSolicitacao.conclusaoContestada => AppColors.erro,
      StatusSolicitacao.naoComparecimentoInformado => AppColors.erro,
      StatusSolicitacao.conclusaoConfirmada => AppColors.verdeEscuro,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 142),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          status.rotulo,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ResumoIcone extends StatelessWidget {
  const _ResumoIcone({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.verdeEscuro),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia({
    required this.filtro,
    required this.onBuscar,
    required this.onVerTodos,
  });

  final _FiltroServicos filtro;
  final VoidCallback onBuscar;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    final (titulo, mensagem) = switch (filtro) {
      _FiltroServicos.todos => (
        'Você ainda não tem solicitações',
        'Seus pedidos aparecerão aqui após solicitar um atendimento.',
      ),
      _FiltroServicos.aguardando => (
        'Nenhuma solicitação aguardando resposta',
        'Pedidos enviados que ainda aguardam a decisão do profissional aparecem aqui.',
      ),
      _FiltroServicos.agendados => (
        'Nenhum atendimento agendado',
        'Quando o profissional aceitar uma solicitação, ela aparecerá neste filtro.',
      ),
      _FiltroServicos.historico => (
        'Seu histórico ainda está vazio',
        'Atendimentos concluídos, cancelados ou recusados aparecem aqui.',
      ),
    };
    return EmptyStateView(
      title: titulo,
      message: mensagem,
      icon: Icons.event_busy_outlined,
      action: filtro == _FiltroServicos.todos
          ? FilledButton.icon(
              onPressed: onBuscar,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar profissionais'),
            )
          : OutlinedButton.icon(
              onPressed: onVerTodos,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Ver todos os pedidos'),
            ),
    );
  }
}

enum _FiltroServicos {
  todos('todos', 'Todos', null),
  aguardando('aguardando', 'Aguardando', [
    StatusSolicitacao.aguardandoResposta,
  ]),
  agendados('agendados', 'Em andamento', [
    StatusSolicitacao.aceitaAgendada,
    StatusSolicitacao.conclusaoPendente,
    StatusSolicitacao.conclusaoContestada,
    StatusSolicitacao.naoComparecimentoInformado,
  ]),
  historico('historico', 'Histórico', [
    StatusSolicitacao.recusada,
    StatusSolicitacao.cancelada,
    StatusSolicitacao.conclusaoConfirmada,
  ]);

  const _FiltroServicos(this.key, this.label, this.statuses);

  final String key;
  final String label;
  final List<StatusSolicitacao>? statuses;
}
