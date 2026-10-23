import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/documento_verificacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../services/api_service.dart';
import '../../utils/situacao_documental.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/adaptive_navigation_bar.dart';
import '../../widgets/async_state_view.dart';

class AreaProfissionalPage extends StatefulWidget {
  const AreaProfissionalPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AreaProfissionalPage> createState() => _AreaProfissionalPageState();
}

class _AreaProfissionalPageState extends State<AreaProfissionalPage> {
  late int _tab = widget.initialTab;
  late Future<Map<String, dynamic>> _future;
  String _filtro = 'Todas';
  DateTime _mesAgenda = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaSelecionado;
  bool _agendaEmLista = false;
  final Set<int> _decidindo = {};

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<Map<String, dynamic>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) {
      return {'solicitacoes': <dynamic>[]};
    }
    if (_tab == 0) return AppServices.instance.profissionais.meuPainel();
    if (_tab == 2) {
      return AppServices.instance.profissionais.minhaAgenda(
        mes: _chaveMes(_mesAgenda),
      );
    }
    return AppServices.instance.servicos.minhas();
  }

  void _abrirTab(int tab) {
    if (tab == 3) {
      Navigator.pushNamed(context, AppRoutes.servicosProfissional);
      return;
    }
    if (tab == 4) {
      Navigator.pushNamed(context, AppRoutes.perfilProfissionalPrivado);
      return;
    }
    setState(() {
      _tab = tab;
      _future = _carregar();
    });
  }

  void _mudarMesAgenda(int variacao) {
    setState(() {
      _mesAgenda = DateTime(_mesAgenda.year, _mesAgenda.month + variacao);
      _diaSelecionado = null;
      _future = _carregar();
    });
  }

  void _irParaHoje() {
    final hoje = DateTime.now();
    setState(() {
      final mudouMes =
          _mesAgenda.year != hoje.year || _mesAgenda.month != hoje.month;
      _mesAgenda = DateTime(hoje.year, hoje.month);
      _diaSelecionado = DateTime(hoje.year, hoje.month, hoje.day);
      if (mudouMes) _future = _carregar();
    });
  }

  Future<void> _atualizar() async {
    final carregamento = _carregar();
    setState(() {
      _future = carregamento;
    });
    try {
      await carregamento;
    } catch (_) {
      // O FutureBuilder exibe a falha e oferece uma nova tentativa.
    }
  }

  Future<void> _decidir(int id, bool aceitar) async {
    if (_decidindo.contains(id)) return;
    setState(() => _decidindo.add(id));
    try {
      final api = AppServices.instance.servicos;
      await (aceitar ? api.aceitar(id) : api.recusar(id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aceitar
                ? 'Solicitação aceita e agendada.'
                : 'Solicitação recusada.',
          ),
        ),
      );
      setState(() {
        _future = _carregar();
        _future.ignore();
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        setState(() {
          _future = _carregar();
          _future.ignore();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a solicitação.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _decidindo.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome =
        AppServices.instance.auth.usuarioAtual?['nome']?.toString() ??
        'Profissional';
    return Scaffold(
      appBar: AppBarCustom(
        title: switch (_tab) {
          0 => 'ConectaLar Profissional',
          1 => 'Solicitações recebidas',
          2 => 'ConectaLar Profissional',
          _ => 'Área profissional',
        },
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notificacoes),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(
              label: 'Carregando área profissional.',
            );
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar seus atendimentos agora.',
              onRetry: () => setState(() {
                _future = _carregar();
                _future.ignore();
              }),
              icon: Icons.home_repair_service_outlined,
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final raw = _tab == 0
              ? data['solicitacoesRecentes']
              : _tab == 2
              ? data['atendimentos']
              : data['solicitacoes'];
          final pedidos = raw is List
              ? raw.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
          final novos = pedidos
              .where((p) => p['status'] == 'aguardando_resposta')
              .toList();
          final proximosRaw = data['proximosAtendimentos'];
          final agendados = _tab == 0 && proximosRaw is List
              ? proximosRaw.whereType<Map<String, dynamic>>().toList()
              : pedidos.where((p) => p['status'] == 'aceita_agendada').toList();
          final concluidos = pedidos
              .where((p) => p['status'] == 'conclusao_confirmada')
              .toList();
          final atendimentosDoMes =
              agendados
                  .where(
                    (p) =>
                        _mesDaData(p['dataServico']) == _chaveMes(_mesAgenda),
                  )
                  .toList()
                ..sort((a, b) {
                  final data = _dataDoServico(
                    a['dataServico'],
                  ).compareTo(_dataDoServico(b['dataServico']));
                  return data != 0
                      ? data
                      : '${a['horarioServico'] ?? ''}'.compareTo(
                          '${b['horarioServico'] ?? ''}',
                        );
                });
          final atendimentosPorDia = <DateTime, int>{};
          for (final pedido in atendimentosDoMes) {
            final dia = _dataDoServico(pedido['dataServico']);
            atendimentosPorDia.update(
              dia,
              (total) => total + 1,
              ifAbsent: () => 1,
            );
          }
          final disponibilidade = data['disponibilidade'] is List
              ? (data['disponibilidade'] as List)
                    .whereType<Map<String, dynamic>>()
                    .where((item) => item['ativo'] != false)
                    .toList()
              : <Map<String, dynamic>>[];
          final diaInicial = atendimentosDoMes.isNotEmpty
              ? _dataDoServico(atendimentosDoMes.first['dataServico'])
              : DateTime.now().year == _mesAgenda.year &&
                    DateTime.now().month == _mesAgenda.month
              ? DateTime.now()
              : _mesAgenda;
          final diaSelecionado = _diaSelecionado ?? diaInicial;
          final horariosDoDia =
              disponibilidade
                  .where(
                    (item) =>
                        int.tryParse('${item['diaSemana']}') ==
                        diaSelecionado.weekday % 7,
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      '${a['horaInicio']}'.compareTo('${b['horaInicio']}'),
                );
          final lista = _tab == 0
              ? novos.take(3).toList()
              : _tab == 2
              ? _agendaEmLista
                    ? atendimentosDoMes
                    : atendimentosDoMes
                          .where(
                            (p) => _mesmoDia(
                              _dataDoServico(p['dataServico']),
                              diaSelecionado,
                            ),
                          )
                          .toList()
              : _filtrar(pedidos);
          return RefreshIndicator(
            onRefresh: _atualizar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                if (_tab == 0) ...[
                  Text(
                    'Olá, $nome',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Organize seus atendimentos e responda aos clientes.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ResumoCard(
                        label: 'Novas',
                        valor: _resumo(data, 'solicitacoesNovas', novos.length),
                        icon: Icons.mark_email_unread_outlined,
                      ),
                      const SizedBox(width: 8),
                      _ResumoCard(
                        label: 'Agendados',
                        valor: _resumo(data, 'agendados', agendados.length),
                        icon: Icons.event_available_outlined,
                      ),
                      const SizedBox(width: 8),
                      _ResumoCard(
                        label: 'Concluídos',
                        valor: _resumo(data, 'concluidos', concluidos.length),
                        icon: Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    'Aguardando sua resposta',
                    onTap: () => _abrirTab(1),
                  ),
                  const SizedBox(height: 8),
                  if (novos.isEmpty)
                    const _EmptyCard(
                      text: 'Nenhuma solicitação aguardando resposta.',
                    )
                  else
                    ...novos
                        .take(3)
                        .map(
                          (p) => _PedidoCard(
                            pedido: p,
                            onChanged: () => _atualizar(),
                            onAccept: _decidindo.contains(_id(p))
                                ? null
                                : () => _decidir(_id(p), true),
                            onDecline: _decidindo.contains(_id(p))
                                ? null
                                : () => _decidir(_id(p), false),
                          ),
                        ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    'Próximos atendimentos',
                    onTap: () => _abrirTab(2),
                  ),
                  const SizedBox(height: 8),
                  if (agendados.isEmpty)
                    const _EmptyCard(
                      text: 'Nenhum atendimento agendado no momento.',
                    )
                  else
                    _PedidoCard(
                      pedido: agendados.first,
                      onAccept: null,
                      onDecline: null,
                    ),
                  const SizedBox(height: AppSpace.md),
                  FutureBuilder<Map<String, dynamic>>(
                    future: AppServices.instance.profissionais.meuPerfil(),
                    builder: (context, profile) {
                      final p = profile.data?['profissional'];
                      final verificado =
                          p is Map<String, dynamic> && p['verificado'] == true;
                      return _BadgeCard(
                        icon: verificado
                            ? Icons.verified_rounded
                            : Icons.verified_user_outlined,
                        title: verificado
                            ? 'Documento analisado'
                            : 'Verificação documental',
                        text: verificado
                            ? 'Documento aprovado. A habilitação de segurança continua pendente e os atendimentos estão bloqueados.'
                            : 'Envie seus documentos para análise administrativa. O selo não é uma garantia absoluta.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.documentosProfissional,
                        ),
                      );
                    },
                  ),
                ] else if (_tab == 2) ...[
                  Text(
                    'Minha agenda',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Veja os dias com atendimentos e confira seus horários antes de aceitar novos pedidos.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Calendário'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.view_agenda_outlined),
                              label: Text('Lista'),
                            ),
                          ],
                          selected: {_agendaEmLista},
                          onSelectionChanged: (value) =>
                              setState(() => _agendaEmLista = value.first),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      IconButton.filledTonal(
                        tooltip: 'Ir para hoje',
                        onPressed: _irParaHoje,
                        icon: const Icon(Icons.today_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (!_agendaEmLista)
                    _CalendarioAgenda(
                      mes: _mesAgenda,
                      diaSelecionado: diaSelecionado,
                      atendimentosPorDia: atendimentosPorDia,
                      diasSemanaComDisponibilidade: disponibilidade
                          .map((item) => int.tryParse('${item['diaSemana']}'))
                          .whereType<int>()
                          .toSet(),
                      onDiaSelecionado: (dia) =>
                          setState(() => _diaSelecionado = dia),
                      onMudarMes: _mudarMesAgenda,
                    )
                  else
                    _CabecalhoMesAgenda(
                      mes: _mesAgenda,
                      onMudarMes: _mudarMesAgenda,
                      quantidade: atendimentosDoMes.length,
                    ),
                ] else ...[
                  Text(
                    'Pedidos recebidos',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confira a região e o horário. O endereço completo fica protegido até o aceite.',
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in [
                          'Todas',
                          'Novas / aguardando',
                          'Agendadas',
                          'Histórico',
                        ]) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: _filtro == f,
                              onSelected: (_) => setState(() => _filtro = f),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_tab == 2 && !_agendaEmLista) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    '${diaSelecionado.day} de ${_nomeMes(diaSelecionado).toLowerCase()}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    lista.isEmpty
                        ? 'Sem atendimentos agendados'
                        : lista.length == 1
                        ? '1 atendimento agendado'
                        : '${lista.length} atendimentos agendados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _DisponibilidadeDoDia(
                    itens: horariosDoDia,
                    dia: diaSelecionado,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.disponibilidadeProfissional,
                      );
                      if (mounted) await _atualizar();
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Editar disponibilidade semanal'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  const _SectionTitle('Atendimentos do dia'),
                  const SizedBox(height: 8),
                ],
                if (_tab != 0 && lista.isEmpty)
                  _tab == 2
                      ? EmptyStateView(
                          title: _agendaEmLista
                              ? 'Nenhum atendimento neste mês'
                              : 'Nenhum atendimento neste dia',
                          message: _agendaEmLista
                              ? 'Use as setas para consultar outro mês ou configure sua disponibilidade.'
                              : 'Somente pedidos aceitos aparecem na agenda. Solicitações aguardando resposta ainda não reservam horário.',
                          icon: Icons.event_available_outlined,
                        )
                      : _EmptyCard(
                          text: switch (_tab) {
                            0 => 'Nenhuma solicitação aguardando resposta.',
                            2 => 'Nenhum atendimento aceito para este mês.',
                            _ => switch (_filtro) {
                              'Novas / aguardando' =>
                                'Nenhuma solicitação aguardando resposta.',
                              'Agendadas' => 'Nenhum atendimento agendado.',
                              'Histórico' =>
                                'Seu histórico de atendimentos está vazio.',
                              _ => 'Nenhum pedido recebido ainda.',
                            },
                          },
                        )
                else if (_tab != 0)
                  ...lista.map(
                    (pedido) => _agendaEmLista && _tab == 2
                        ? _AgendaItemCompacto(pedido: pedido)
                        : _PedidoCard(
                            pedido: pedido,
                            onChanged: () => setState(() {
                              _future = _carregar();
                              _future.ignore();
                            }),
                            onAccept:
                                !_decidindo.contains(_id(pedido)) &&
                                    pedido['status'] == 'aguardando_resposta'
                                ? () => _decidir(_id(pedido), true)
                                : null,
                            onDecline:
                                !_decidindo.contains(_id(pedido)) &&
                                    pedido['status'] == 'aguardando_resposta'
                                ? () => _decidir(_id(pedido), false)
                                : null,
                          ),
                  ),
                if (_tab == 2) ...[
                  const SizedBox(height: AppSpace.md),
                  const Text(
                    'Antes de aceitar outro pedido, considere a duração dos atendimentos e o tempo de deslocamento. Um dia com atendimento pode ter outros horários livres.',
                    style: TextStyle(color: AppColors.textoSuave),
                  ),
                ],
                if (!AppServices.instance.auth.autenticado)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Entre com uma conta profissional para carregar seus dados.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AdaptiveNavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _abrirTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Pedidos',
            tooltip: 'Solicitações recebidas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_repair_service_outlined),
            label: 'Serviços',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> pedidos) =>
      switch (_filtro) {
        'Novas / aguardando' =>
          pedidos.where((p) => p['status'] == 'aguardando_resposta').toList(),
        'Agendadas' =>
          pedidos.where((p) => p['status'] == 'aceita_agendada').toList(),
        'Histórico' =>
          pedidos
              .where(
                (p) => [
                  'recusada',
                  'cancelada',
                  'conclusao_confirmada',
                ].contains(p['status']),
              )
              .toList(),
        _ => pedidos,
      };

  int _resumo(Map<String, dynamic> data, String chave, int fallback) {
    final resumo = data['resumo'];
    if (resumo is! Map<String, dynamic>) return fallback;
    return int.tryParse('${resumo[chave]}') ?? fallback;
  }

  int _id(Map<String, dynamic> p) => int.tryParse('${p['id']}') ?? 0;
}

class DetalheSolicitacaoProfissionalPage extends StatefulWidget {
  const DetalheSolicitacaoProfissionalPage({super.key});
  @override
  State<DetalheSolicitacaoProfissionalPage> createState() =>
      _DetalheSolicitacaoProfissionalPageState();
}

class _DetalheSolicitacaoProfissionalPageState
    extends State<DetalheSolicitacaoProfissionalPage> {
  Future<Map<String, dynamic>>? _future;
  int? _id;
  bool _decidindo = false;
  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final id = arg is int ? arg : int.tryParse('$arg');
    if (id != _id && id != null) {
      _id = id;
      _future = AppServices.instance.servicos.obter(id);
    }
    return Scaffold(
      appBar: const AppBarCustom(title: 'Detalhes da solicitação'),
      backgroundColor: AppColors.fundo,
      body: _future == null
          ? const Center(child: Text('Solicitação não identificada.'))
          : FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final p = s.data?['solicitacao'];
                if (s.hasError || p is! Map<String, dynamic>) {
                  return AsyncErrorView(
                    message: 'Não foi possível carregar esta solicitação.',
                    icon: Icons.receipt_long_outlined,
                    onRetry: () {
                      final solicitacaoId = _id;
                      if (solicitacaoId != null) {
                        setState(() {
                          _future = AppServices.instance.servicos.obter(
                            solicitacaoId,
                          );
                          _future?.ignore();
                        });
                      }
                    },
                  );
                }
                final aceito = p['status'] == 'aceita_agendada';
                final enderecoLiberado = p['enderecoCompletoLiberado'] == true;
                final enderecoTexto = _enderecoTexto(p);
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _BadgeCard(
                      icon: Icons.home_repair_service_outlined,
                      title:
                          '${p['nomeServico'] ?? p['categoria']?['nome'] ?? 'Serviço solicitado'}',
                      text: 'Solicitação #${p['id']} ⬢ ${_status(p['status'])}',
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Cliente',
                      value: '${p['cliente']?['nome'] ?? 'Cliente'}',
                    ),
                    _InfoCard(
                      title: 'Descrição',
                      value: '${p['descricao'] ?? 'Sem descrição'}',
                    ),
                    _InfoCard(
                      title: 'Data e horário',
                      value: _dataHoraPedido(
                        p['dataServico'],
                        p['horarioServico'],
                      ),
                    ),
                    _InfoCard(
                      title: 'Região',
                      value: '${p['bairroAtendimento'] ?? 'Não informada'}',
                    ),
                    _InfoCard(
                      title: 'Duração do atendimento',
                      value:
                          '${p['duracaoMinutos'] ?? 120} min ⬢ horário de São Paulo',
                    ),
                    _InfoCard(
                      title: 'Referência de preço inicial',
                      value: p['precoInicial'] == null
                          ? 'A combinar fora do aplicativo'
                          : 'R\$ ${p['precoInicial']} ⬢ valor de referência; negociação fora do app.',
                    ),
                    const SizedBox(height: 8),
                    _BadgeCard(
                      icon: Icons.lock_outline,
                      title: enderecoLiberado
                          ? 'Endereço completo liberado'
                          : aceito
                          ? 'Aceite confirmado'
                          : 'Endereço completo protegido',
                      text: enderecoLiberado
                          ? 'O endereço está disponível para este atendimento.'
                          : aceito
                          ? 'O endereço completo ainda não está disponível para este atendimento.'
                          : 'O endereço completo fica disponível após o aceite, quando o acesso for autorizado para este atendimento.',
                    ),
                    if (enderecoLiberado)
                      _InfoCard(
                        title: 'Endereço completo disponível',
                        value: enderecoTexto,
                      ),
                    const SizedBox(height: 14),
                    if (_decidindo) const LinearProgressIndicator(),
                    if (p['status'] == 'aguardando_resposta')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _decidindo
                                  ? null
                                  : () => _decidir(id!, false),
                              child: const Text('Recusar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _decidindo
                                  ? null
                                  : () => _decidir(id!, true),
                              child: const Text('Aceitar'),
                            ),
                          ),
                        ],
                      ),
                    if (aceito)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.conversa,
                          arguments: id,
                        ),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Conversar sobre este atendimento'),
                      ),
                    if (p['status'] == 'conclusao_confirmada')
                      FilledButton.icon(
                        onPressed: p['avaliado'] == true
                            ? null
                            : () async {
                                await Navigator.pushNamed(
                                  context,
                                  AppRoutes.detalhesServico,
                                  arguments: id,
                                );
                                if (mounted) {
                                  setState(() {
                                    _future = AppServices.instance.servicos
                                        .obter(id!);
                                    _future?.ignore();
                                  });
                                }
                              },
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(
                          p['avaliado'] == true
                              ? 'Avaliação registrada'
                              : 'Avaliar cliente',
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _decidir(int id, bool aceitar) async {
    if (_decidindo) return;
    setState(() => _decidindo = true);
    try {
      if (aceitar) {
        await AppServices.instance.servicos.aceitar(id);
      } else {
        await AppServices.instance.servicos.recusar(id);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        setState(() {
          _future = AppServices.instance.servicos.obter(id);
          _future?.ignore();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível confirmar a alteração. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _decidindo = false);
    }
  }
}

class ServicosProfissionalPage extends StatefulWidget {
  const ServicosProfissionalPage({super.key});
  @override
  State<ServicosProfissionalPage> createState() =>
      _ServicosProfissionalPageState();
}

class _ServicosProfissionalPageState extends State<ServicosProfissionalPage> {
  late Future<Map<String, dynamic>> _future = AppServices.instance.profissionais
      .meusServicos();
  bool _salvando = false;

  Future<void> _editar({Map<String, dynamic>? servico}) async {
    final nome = TextEditingController(text: '${servico?['nome'] ?? ''}');
    if (_salvando) return;
    setState(() => _salvando = true);
    List<Map<String, dynamic>> categorias;
    Map<String, dynamic> atual;
    try {
      final response = await AppServices.instance.categorias.listar();
      categorias = (response['categorias'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      atual = await AppServices.instance.profissionais.meusServicos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar as categorias. Tente novamente.',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
    if (!mounted) return;
    int? categoriaId = int.tryParse(
      '${servico?['categoriaId'] ?? servico?['categoria']?['id'] ?? ''}',
    );
    if (!categorias.any((c) => c['id'] == categoriaId)) categoriaId = null;
    final preco = TextEditingController(
      text: '${servico?['precoInicial'] ?? ''}',
    );
    var duracaoMinutos =
        int.tryParse('${servico?['duracaoMinutos'] ?? 60}') ?? 60;
    var intervaloMinutos =
        int.tryParse('${servico?['intervaloMinutos'] ?? 30}') ?? 30;
    final form = GlobalKey<FormState>();
    var enviando = false;
    String? erro;
    final salvo = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(servico == null ? 'Adicionar serviço' : 'Editar serviço'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nome,
                  enabled: !enviando,
                  decoration: const InputDecoration(
                    labelText: 'Nome do serviço',
                  ),
                  maxLength: 90,
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Informe o nome.' : null,
                ),
                DropdownButtonFormField<int>(
                  initialValue: categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Sem categoria'),
                    ),
                    for (final categoria in categorias)
                      DropdownMenuItem(
                        value: int.tryParse('${categoria['id']}'),
                        child: Text('${categoria['nome']}'),
                      ),
                  ],
                  onChanged: enviando ? null : (value) => categoriaId = value,
                ),
                TextFormField(
                  controller: preco,
                  enabled: !enviando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Preço inicial (R\$)',
                  ),
                  validator: validarPrecoOpcional,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: '$duracaoMinutos',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Duração estimada',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  items: const [30, 45, 60, 90, 120, 180, 240]
                      .map(
                        (value) => DropdownMenuItem(
                          value: '$value',
                          child: Text('$value minutos'),
                        ),
                      )
                      .toList(),
                  onChanged: enviando
                      ? null
                      : (value) =>
                            duracaoMinutos = int.tryParse(value ?? '') ?? 60,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: '$intervaloMinutos',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Intervalo para deslocamento',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  items: const [0, 15, 30, 45, 60]
                      .map(
                        (value) => DropdownMenuItem(
                          value: '$value',
                          child: Text('$value minutos'),
                        ),
                      )
                      .toList(),
                  onChanged: enviando
                      ? null
                      : (value) =>
                            intervaloMinutos = int.tryParse(value ?? '') ?? 30,
                ),
                if (erro != null) ...[
                  const SizedBox(height: 12),
                  Text(erro!, style: const TextStyle(color: AppColors.erro)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: enviando
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialogState(() {
                        enviando = true;
                        erro = null;
                      });
                      try {
                        final servicos = _servicosParaSalvar(atual);
                        final novo = <String, dynamic>{
                          if (servico != null) 'id': servico['id'],
                          'nome': nome.text.trim(),
                          'categoriaId': categoriaId,
                          'precoInicial': parsePrecoInicial(preco.text),
                          'ativo': servico?['ativo'] != false,
                          'duracaoMinutos': duracaoMinutos,
                          'intervaloMinutos': intervaloMinutos,
                        };
                        if (servico == null) {
                          if (servicos.length >= 12) {
                            throw const ApiException(
                              'Você pode cadastrar até 12 serviços.',
                            );
                          }
                          servicos.add(novo);
                        } else {
                          final index = servicos.indexWhere(
                            (item) => item['id'] == servico['id'],
                          );
                          if (index < 0) {
                            throw const ApiException(
                              'Este serviço não está mais disponível. Atualize a lista.',
                            );
                          }
                          servicos[index] = novo;
                        }
                        final response = await AppServices
                            .instance
                            .profissionais
                            .salvarMeusServicos(servicos);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, response);
                        }
                      } on ApiException catch (error) {
                        setDialogState(() {
                          enviando = false;
                          erro = error.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          enviando = false;
                          erro =
                              'Não foi possível salvar. Verifique sua conexão e tente novamente.';
                        });
                      }
                    },
              icon: enviando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(enviando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvo != null && mounted) {
      setState(() {
        _future = Future.value(salvo);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Serviço salvo.')));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nome.dispose();
    preco.dispose();
  }

  List<Map<String, dynamic>> _servicosParaSalvar(
    Map<String, dynamic> response,
  ) => (response['servicos'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(
        (item) => <String, dynamic>{
          'id': item['id'],
          'nome': item['nome'],
          'categoriaId': item['categoriaId'] ?? item['categoria']?['id'],
          'precoInicial': item['precoInicial'],
          'ativo': item['ativo'] != false,
          'duracaoMinutos': item['duracaoMinutos'] ?? 60,
          'intervaloMinutos': item['intervaloMinutos'] ?? 30,
        },
      )
      .toList();

  Future<void> _alterarStatus(Map<String, dynamic> servico) async {
    if (_salvando) return;
    final ativo = servico['ativo'] == true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ativo ? 'Pausar oferta?' : 'Reativar oferta?'),
        content: Text(
          ativo
              ? 'Ela deixará de aparecer para clientes, mas seus dados serão preservados.'
              : 'Ela voltará a aparecer no catálogo para novos pedidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ativo ? 'Pausar' : 'Reativar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _salvando = true);
    try {
      final atual = await AppServices.instance.profissionais.meusServicos();
      final servicos = _servicosParaSalvar(atual);
      final index = servicos.indexWhere((item) => item['id'] == servico['id']);
      if (index < 0) {
        throw const ApiException(
          'Este serviço não está mais disponível. Atualize a lista.',
        );
      }
      servicos[index]['ativo'] = !ativo;
      final response = await AppServices.instance.profissionais
          .salvarMeusServicos(servicos);
      if (!mounted) return;
      setState(() {
        _future = Future.value(response);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ativo ? 'Oferta pausada.' : 'Oferta reativada.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível alterar a oferta. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Meus serviços'),
    backgroundColor: AppColors.fundo,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _salvando ? null : () => _editar(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar serviço'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _salvando
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.disponibilidadeProfissional,
                      ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        if (_salvando) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const AsyncLoadingView(label: 'Carregando serviços.');
              }
              if (s.hasError) {
                return AsyncErrorView(
                  message: 'Não foi possível carregar seus serviços.',
                  icon: Icons.home_repair_service_outlined,
                  onRetry: () => setState(() {
                    _future = AppServices.instance.profissionais.meusServicos();
                    _future.ignore();
                  }),
                );
              }
              final list = (s.data?['servicos'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const _BadgeCard(
                    icon: Icons.info_outline,
                    title: 'Ofertas profissionais',
                    text:
                        'Cadastre os serviços que você oferece e seus preços iniciais. O valor final e o pagamento são combinados fora do aplicativo.',
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const EmptyStateView(
                      title: 'Nenhum serviço cadastrado',
                      message:
                          'Adicione as ofertas que você realiza. O preço final é combinado fora do aplicativo.',
                      icon: Icons.home_repair_service_outlined,
                    ),
                  if (list.isEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _salvando ? null : () => _editar(),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar primeiro serviço'),
                    ),
                  ],
                  ...list.map(
                    (e) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.home_repair_service_outlined,
                          color: AppColors.verde,
                        ),
                        title: Text('${e['nome']}'),
                        subtitle: Text(
                          '${e['categoria']?['nome'] ?? 'Sem categoria'} ⬢ ${e['precoInicial'] == null ? 'Preço a informar' : 'A partir de R\$ ${e['precoInicial']}'}\n${e['duracaoMinutos'] ?? 60} min + ${e['intervaloMinutos'] ?? 30} min de intervalo ⬢ ${e['ativo'] == true ? 'Ativa' : 'Pausada'}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Ações da oferta',
                          enabled: !_salvando,
                          onSelected: (acao) {
                            if (acao == 'editar') {
                              _editar(servico: e);
                            } else {
                              _alterarStatus(e);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editar'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'status',
                              child: ListTile(
                                leading: Icon(
                                  e['ativo'] == true
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                ),
                                title: Text(
                                  e['ativo'] == true ? 'Pausar' : 'Reativar',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class PerfilProfissionalPrivadoPage extends StatefulWidget {
  const PerfilProfissionalPrivadoPage({super.key});
  @override
  State<PerfilProfissionalPrivadoPage> createState() =>
      _PerfilProfissionalPrivadoPageState();
}

class _PerfilProfissionalPrivadoPageState
    extends State<PerfilProfissionalPrivadoPage> {
  late Future<Map<String, dynamic>> _future = _carregar();

  Future<Map<String, dynamic>> _carregar() async {
    final perfil = await AppServices.instance.profissionais.meuPerfil();
    try {
      final response = await AppServices.instance.verificacao.meusDocumentos();
      return {
        ...perfil,
        'documentos': listFromApi(
          response['documentos'],
          documentoVerificacaoFromApi,
        ),
      };
    } catch (_) {
      return {...perfil, 'documentosIndisponiveis': true};
    }
  }

  Future<void> _abrirDocumentos() async {
    await Navigator.pushNamed(context, AppRoutes.documentosProfissional);
    if (mounted) setState(() => _future = _carregar());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Meu perfil profissional'),
    backgroundColor: AppColors.fundo,
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(
            label: 'Carregando perfil profissional.',
          );
        }
        if (s.hasError) {
          return AsyncErrorView(
            message: 'Não foi possível carregar seu perfil profissional.',
            icon: Icons.person_outline_rounded,
            onRetry: () => setState(() {
              _future = _carregar();
              _future.ignore();
            }),
          );
        }
        final documentos = s.data?['documentos'];
        final situacao = documentos is List<DocumentoVerificacao>
            ? situacaoDocumentoIdentidade(documentos)
            : null;
        final usuario = AppServices.instance.auth.usuarioAtual ?? {};
        final perfilRaw = s.data?['profissional'];
        final perfilPublico = perfilRaw is Map<String, dynamic>
            ? profissionalFromApi(perfilRaw)
            : null;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.verdeClaro,
                      backgroundImage:
                          '${usuario['fotoPerfilUrl'] ?? ''}'.trim().isEmpty
                          ? null
                          : NetworkImage('${usuario['fotoPerfilUrl']}'),
                      child: '${usuario['fotoPerfilUrl'] ?? ''}'.trim().isEmpty
                          ? Text(
                              _inicialNome(usuario['nome']),
                              style: const TextStyle(
                                color: AppColors.verdeEscuro,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${usuario['nome'] ?? 'Profissional'}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${usuario['tipo'] == 'empresa' ? 'Empresa' : 'Autônomo'} ⬢ dados privados',
                            style: const TextStyle(color: AppColors.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (perfilPublico != null) ...[
              const SizedBox(height: AppSpace.sm),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.perfilProfissional,
                  arguments: perfilPublico,
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver meu perfil público'),
              ),
            ],
            const SizedBox(height: 12),
            _BadgeCard(
              icon: switch (situacao?.estado) {
                SituacaoDocumentalEstado.aprovado => Icons.verified,
                SituacaoDocumentalEstado.rejeitado => Icons.error_outline,
                SituacaoDocumentalEstado.emAnalise => Icons.hourglass_top,
                _ => Icons.upload_file_outlined,
              },
              title: situacao?.titulo ?? 'Situação documental indisponível',
              text: situacao == null
                  ? 'Abra seus documentos para atualizar a situação.'
                  : [
                      situacao.orientacao,
                      if (situacao.motivo?.trim().isNotEmpty == true)
                        'Motivo: ${situacao.motivo}',
                    ].join('\n'),
              onTap: _abrirDocumentos,
            ),
            const SizedBox(height: AppSpace.lg),
            const _PerfilSecaoTitulo(
              titulo: 'Dados pessoais',
              descricao: 'Informações privadas da sua conta.',
            ),
            _MenuRow(
              icon: Icons.person_outline_rounded,
              label: 'Nome, telefone e foto',
              onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
            ),
            const SizedBox(height: AppSpace.md),
            const _PerfilSecaoTitulo(
              titulo: 'Apresentação pública',
              descricao: 'O que os clientes veem no catálogo.',
            ),
            _MenuRow(
              icon: Icons.badge_outlined,
              label: 'Região atendida',
              onTap: _editarDadosProfissionais,
            ),
            _MenuRow(
              icon: Icons.home_repair_service_outlined,
              label: 'Serviços oferecidos',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.servicosProfissional),
            ),
            const SizedBox(height: AppSpace.md),
            const _PerfilSecaoTitulo(
              titulo: 'Configurações do trabalho',
              descricao: 'Agenda, segurança e histórico profissional.',
            ),
            _MenuRow(
              icon: Icons.schedule_outlined,
              label: 'Disponibilidade e bloqueios',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.disponibilidadeProfissional,
              ),
            ),
            _MenuRow(
              icon: Icons.folder_outlined,
              label: 'Documentos e verificação',
              onTap: _abrirDocumentos,
            ),
            _MenuRow(
              icon: Icons.star_outline_rounded,
              label: 'Avaliações recebidas',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.avaliacoesRecebidas),
            ),
            _MenuRow(
              icon: Icons.settings_outlined,
              label: 'Segurança e configurações da conta',
              onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
            ),
          ],
        );
      },
    ),
  );
  Future<void> _editarDadosProfissionais() async {
    final atualizado = await Navigator.pushNamed(
      context,
      AppRoutes.cadastroProfissional,
    );
    if (atualizado == true && mounted) {
      setState(() {
        _future = _carregar();
        _future.ignore();
      });
    }
  }
}

String _inicialNome(Object? value) {
  final nome = '${value ?? ''}'.trim();
  return nome.isEmpty ? 'P' : nome.characters.first.toUpperCase();
}

String _status(Object? value) => switch (value) {
  'aguardando_resposta' => 'Aguardando resposta',
  'aceita_agendada' => 'Aceita e agendada',
  'recusada' => 'Recusada',
  'cancelada' => 'Cancelada',
  'conclusao_confirmada' => 'Conclusão confirmada',
  _ => 'Status desconhecido',
};

String _enderecoTexto(Map<String, dynamic> pedido) {
  final endereco = pedido['enderecoAtendimento'] ?? pedido['enderecoCompleto'];
  if (endereco is! Map<String, dynamic>) {
    return '${pedido['bairroAtendimento'] ?? 'Região não informada'}';
  }
  final complemento = '${endereco['complemento'] ?? ''}'.trim();
  final extra = complemento.isEmpty ? '' : ' - $complemento';
  return '${endereco['logradouro'] ?? ''}, ${endereco['numero'] ?? ''}$extra - '
      '${endereco['bairro'] ?? ''}, ${endereco['cidade'] ?? ''}/${endereco['uf'] ?? ''}';
}

class _PedidoCard extends StatelessWidget {
  const _PedidoCard({
    required this.pedido,
    required this.onAccept,
    required this.onDecline,
    this.onChanged,
  });
  final Map<String, dynamic> pedido;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${pedido['id']}') ?? 0;
    final aguardando = pedido['status'] == 'aguardando_resposta';
    final enderecoLiberado = pedido['enderecoCompletoLiberado'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.home_repair_service_outlined,
                      color: AppColors.verde,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pedido['nomeServico'] ?? pedido['categoria']?['nome'] ?? 'Serviço solicitado'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(text: _status(pedido['status'])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${pedido['cliente']?['nome'] ?? 'Cliente'} ⬢ ${pedido['bairroAtendimento'] ?? 'Região não informada'}',
            ),
            Text(
              _dataHoraPedido(pedido['dataServico'], pedido['horarioServico']),
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            if (pedido['duracaoMinutos'] != null)
              Text(
                '${pedido['duracaoMinutos']} min ⬢ horário de São Paulo',
                style: const TextStyle(color: AppColors.textoSuave),
              ),
            const SizedBox(height: 6),
            Text(
              enderecoLiberado
                  ? _enderecoTexto(pedido)
                  : 'Endereço completo protegido até o aceite válido.',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.detalhesServico,
                        arguments: id,
                      );
                      onChanged?.call();
                    },
                    child: const Text('Ver detalhes'),
                  ),
                ),
                if (aguardando) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Recusar solicitação',
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, color: Color(0xFFC53030)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Aceitar'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({
    required this.label,
    required this.valor,
    required this.icon,
  });
  final String label;
  final int valor;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.verdeClaro,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.verde, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.icon,
    required this.title,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String title, text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.verdeClaro,
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.verde),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(text),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value});
  final String title, value;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onTap});
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (onTap != null)
        TextButton(onPressed: onTap, child: const Text('Ver todos')),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.verdeClaro,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.verdeEscuro,
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.verde),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _PerfilSecaoTitulo extends StatelessWidget {
  const _PerfilSecaoTitulo({required this.titulo, required this.descricao});
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.xs),
        Text(descricao, style: const TextStyle(color: AppColors.textoSuave)),
      ],
    ),
  );
}

class _CabecalhoMesAgenda extends StatelessWidget {
  const _CabecalhoMesAgenda({
    required this.mes,
    required this.onMudarMes,
    required this.quantidade,
  });
  final DateTime mes;
  final ValueChanged<int> onMudarMes;
  final int quantidade;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Mês anterior',
        onPressed: () => onMudarMes(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Column(
          children: [
            Text(
              '${_nomeMes(mes)} ${mes.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '$quantidade ${quantidade == 1 ? 'atendimento' : 'atendimentos'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Próximo mês',
        onPressed: () => onMudarMes(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _AgendaItemCompacto extends StatelessWidget {
  const _AgendaItemCompacto({required this.pedido});
  final Map<String, dynamic> pedido;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${pedido['id']}') ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      child: ListTile(
        onTap: id <= 0
            ? null
            : () => Navigator.pushNamed(
                context,
                AppRoutes.detalhesSolicitacaoProfissional,
                arguments: id,
              ),
        leading: const Icon(Icons.event_available_outlined),
        title: Text(
          '${pedido['nomeServico'] ?? pedido['categoria']?['nome'] ?? 'Atendimento'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_dataHoraPedido(pedido['dataServico'], pedido['horarioServico'])}\n${pedido['bairroAtendimento'] ?? 'Região não informada'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CalendarioAgenda extends StatelessWidget {
  const _CalendarioAgenda({
    required this.mes,
    required this.diaSelecionado,
    required this.atendimentosPorDia,
    required this.diasSemanaComDisponibilidade,
    required this.onDiaSelecionado,
    required this.onMudarMes,
  });

  final DateTime mes;
  final DateTime diaSelecionado;
  final Map<DateTime, int> atendimentosPorDia;
  final Set<int> diasSemanaComDisponibilidade;
  final ValueChanged<DateTime> onDiaSelecionado;
  final ValueChanged<int> onMudarMes;

  @override
  Widget build(BuildContext context) {
    final primeiroDia = DateTime(mes.year, mes.month, 1);
    final deslocamento = primeiroDia.weekday % 7;
    final totalDias = DateTime(mes.year, mes.month + 1, 0).day;
    final totalAtendimentos = atendimentosPorDia.values.fold(
      0,
      (a, b) => a + b,
    );
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final alturaCelula = 48 * escala.clamp(1.0, 1.5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => onMudarMes(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _nomeMes(mes),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => onMudarMes(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Text(
                atendimentosPorDia.isEmpty
                    ? 'Nenhum atendimento agendado neste mês'
                    : '$totalAtendimentos '
                          '${totalAtendimentos == 1 ? 'atendimento' : 'atendimentos'} em '
                          '${atendimentosPorDia.length} ${atendimentosPorDia.length == 1 ? 'dia' : 'dias'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Row(
              children: [
                for (var indice = 0; indice < 7; indice++)
                  Expanded(
                    child: Center(
                      child: Semantics(
                        label: _nomeDia(indice),
                        child: ExcludeSemantics(
                          child: Text(
                            const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'][indice],
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((deslocamento + totalDias + 6) ~/ 7) * 7,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: alturaCelula,
              ),
              itemBuilder: (context, index) {
                final diaDoMes = index - deslocamento + 1;
                if (diaDoMes < 1 || diaDoMes > totalDias) {
                  return const SizedBox.shrink();
                }
                final dia = DateTime(mes.year, mes.month, diaDoMes);
                final selecionado = _mesmoDia(dia, diaSelecionado);
                final quantidade = atendimentosPorDia[dia] ?? 0;
                final temAtendimento = quantidade > 0;
                final horarioSemanal = diasSemanaComDisponibilidade.contains(
                  dia.weekday % 7,
                );
                return Semantics(
                  key: ValueKey('agenda-dia-${_chaveMes(dia)}-$diaDoMes'),
                  button: true,
                  selected: selecionado,
                  label:
                      '$diaDoMes de ${_nomeMes(mes)}'
                      ', ${quantidade == 0
                          ? 'sem atendimentos agendados'
                          : quantidade == 1
                          ? '1 atendimento agendado'
                          : '$quantidade atendimentos agendados'}'
                      ', ${horarioSemanal ? 'com horário semanal cadastrado' : 'sem horário semanal cadastrado'}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onDiaSelecionado(dia),
                    child: Center(
                      child: ExcludeSemantics(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (selecionado)
                                const CircleAvatar(
                                  radius: 19,
                                  backgroundColor: AppColors.verde,
                                ),
                              if (!selecionado &&
                                  (horarioSemanal || temAtendimento))
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.verdeClaro,
                                      shape: BoxShape.circle,
                                      border: !temAtendimento
                                          ? Border.all(color: AppColors.verde)
                                          : null,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '$diaDoMes',
                                  style: TextStyle(
                                    color: selecionado
                                        ? AppColors.branco
                                        : AppColors.texto,
                                    height: 1,
                                    fontWeight: selecionado
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (temAtendimento)
                                Positioned(
                                  bottom: 2,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: selecionado
                                          ? AppColors.branco
                                          : AppColors.verde,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.sm,
                  children: [
                    _LegendaAgenda(label: 'Selecionado'),
                    _LegendaAgenda(label: 'Com atendimento', ponto: true),
                    _LegendaAgenda(
                      label: 'Horário semanal sem agendamento',
                      contorno: true,
                    ),
                  ],
                ),
                const Divider(height: AppSpace.xl),
                Text(
                  'Toque em um dia para conferir os horários.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendaAgenda extends StatelessWidget {
  const _LegendaAgenda({
    required this.label,
    this.ponto = false,
    this.contorno = false,
  });

  final String label;
  final bool ponto;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ponto ? 6 : 12,
          height: ponto ? 6 : 12,
          decoration: BoxDecoration(
            color: contorno ? AppColors.verdeClaro : AppColors.verde,
            shape: BoxShape.circle,
            border: contorno ? Border.all(color: AppColors.verde) : null,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _DisponibilidadeDoDia extends StatelessWidget {
  const _DisponibilidadeDoDia({required this.itens, required this.dia});

  final List<Map<String, dynamic>> itens;
  final DateTime dia;

  @override
  Widget build(BuildContext context) {
    final diaLabel = _nomeDia(dia.weekday % 7);
    return Card(
      color: AppColors.verdePastel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule_outlined, color: AppColors.verde),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horários semanais de $diaLabel',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    itens.isEmpty
                        ? 'Nenhum horário semanal cadastrado para este dia.'
                        : itens
                              .map(
                                (item) =>
                                    '${_horaAgenda(item['horaInicio'])} às ${_horaAgenda(item['horaFim'])}',
                              )
                              .join(' ⬢ '),
                  ),
                  if (itens.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'Esses períodos se repetem toda semana e não descontam os atendimentos agendados.',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _chaveMes(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}';

String _horaAgenda(Object? valor) =>
    RegExp(r'^\d{2}:\d{2}').stringMatch('$valor') ?? '--:--';

String _dataHoraPedido(Object? valorData, Object? valorHorario) {
  final textoData = valorData?.toString() ?? '';
  final data = DateTime.tryParse(
    textoData.length >= 10 ? textoData.substring(0, 10) : textoData,
  );
  final dataFormatada = data == null
      ? 'Data não informada'
      : '${data.day.toString().padLeft(2, '0')}/'
            '${data.month.toString().padLeft(2, '0')}/${data.year}';
  final horario = valorHorario?.toString().trim() ?? '';
  if (horario.isEmpty) return dataFormatada;
  final horarioFormatado =
      RegExp(r'^\d{2}:\d{2}').stringMatch(horario) ?? horario;
  return '$dataFormatada às $horarioFormatado';
}

DateTime _dataDoServico(Object? valor) {
  final texto = '$valor';
  final data = DateTime.tryParse(
    texto.length >= 10 ? texto.substring(0, 10) : texto,
  );
  return data ?? DateTime(2000);
}

String _mesDaData(Object? valor) => _chaveMes(_dataDoServico(valor));

bool _mesmoDia(DateTime primeira, DateTime segunda) =>
    primeira.year == segunda.year &&
    primeira.month == segunda.month &&
    primeira.day == segunda.day;

String _nomeMes(DateTime data) {
  const nomes = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${nomes[data.month - 1]} de ${data.year}';
}

String _nomeDia(int dia) => switch (dia) {
  0 => 'domingo',
  1 => 'segunda-feira',
  2 => 'terça-feira',
  3 => 'quarta-feira',
  4 => 'quinta-feira',
  5 => 'sexta-feira',
  6 => 'sábado',
  _ => 'dia selecionado',
};
