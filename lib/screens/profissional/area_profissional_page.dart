import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';

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
    if (_tab == 2) return AppServices.instance.profissionais.minhaAgenda();
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

  Future<void> _decidir(int id, bool aceitar) async {
    try {
      final api = AppServices.instance.servicos;
      if (aceitar) {
        await api.aceitar(id);
      } else {
        await api.recusar(id);
      }
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
      setState(() => _future = _carregar());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar a solicitação.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome =
        AppServices.instance.auth.usuarioAtual?['nome']?.toString() ??
        'Profissional';
    return Scaffold(
      appBar: AppBarCustom(
        title: _tab == 0 ? 'ConectaLar Profissional' : 'Solicitações recebidas',
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _erro(_carregar);
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
          final lista = _tab == 0
              ? novos.take(3).toList()
              : _tab == 2
              ? agendados
              : _filtrar(pedidos);
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _carregar()),
            child: ListView(
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
                  const SizedBox(height: 12),
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
                            ? 'Perfil verificado'
                            : 'Verificação documental',
                        text: verificado
                            ? 'A análise documental foi aprovada. O selo não garante segurança, qualidade ou resultado.'
                            : 'Envie seus documentos para análise administrativa. O selo não é uma garantia absoluta.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.documentosProfissional,
                        ),
                      );
                    },
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
                    'Próximos atendimentos',
                    onTap: () => _abrirTab(1),
                  ),
                  const SizedBox(height: 8),
                  if (agendados.isEmpty)
                    const _EmptyCard(
                      text: 'Nenhum atendimento agendado no momento.',
                    )
                  else
                    ...agendados
                        .take(2)
                        .map(
                          (p) => _PedidoCard(
                            pedido: p,
                            onAccept: null,
                            onDecline: null,
                          ),
                        ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    'Solicitações recentes',
                    onTap: () => _abrirTab(1),
                  ),
                  const SizedBox(height: 8),
                ] else if (_tab == 2) ...[
                  Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Atendimentos aceitos no mes ${data['mes'] ?? 'atual'}. O endereco completo aparece somente quando a API liberar.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.disponibilidadeProfissional,
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Editar disponibilidade semanal'),
                  ),
                  const SizedBox(height: 12),
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
                if (lista.isEmpty)
                  _EmptyCard(
                    text: _tab == 0
                        ? 'Nenhuma solicitação aguardando resposta.'
                        : 'Nenhum pedido neste filtro.',
                  )
                else
                  ...lista.map(
                    (pedido) => _PedidoCard(
                      pedido: pedido,
                      onChanged: () => setState(() => _future = _carregar()),
                      onAccept: pedido['status'] == 'aguardando_resposta'
                          ? () => _decidir(_id(pedido), true)
                          : null,
                      onDecline: pedido['status'] == 'aguardando_resposta'
                          ? () => _decidir(_id(pedido), false)
                          : null,
                    ),
                  ),
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
      bottomNavigationBar: NavigationBar(
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
                  return const Center(
                    child: Text('Não foi possível carregar a solicitação.'),
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
                          '${p['categoria']?['nome'] ?? 'Serviço solicitado'}',
                      text: 'Solicitação #${p['id']} • ${_status(p['status'])}',
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
                      value:
                          '${p['dataServico'] ?? ''} • ${p['horarioServico'] ?? ''}',
                    ),
                    _InfoCard(
                      title: 'Região',
                      value: '${p['bairroAtendimento'] ?? 'Não informada'}',
                    ),
                    _InfoCard(
                      title: 'Referência de preço inicial',
                      value: p['precoInicial'] == null
                          ? 'A combinar fora do aplicativo'
                          : 'R\$ ${p['precoInicial']} • valor de referência; negociação fora do app.',
                    ),
                    const SizedBox(height: 8),
                    _BadgeCard(
                      icon: Icons.lock_outline,
                      title: aceito
                          ? 'Aceite confirmado'
                          : 'Endereço completo protegido',
                      text: aceito
                          ? 'A API atual ainda não fornece o endereço completo nesta tela. Consulte apenas os dados retornados para esta solicitação.'
                          : 'O endereço completo só fica disponível após o aceite válido registrado pela API.',
                    ),
                    if (enderecoLiberado)
                      _InfoCard(
                        title: 'Endereço completo liberado pela API',
                        value: enderecoTexto,
                      ),
                    const SizedBox(height: 14),
                    if (p['status'] == 'aguardando_resposta')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _decidir(id!, false),
                              child: const Text('Recusar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _decidir(id!, true),
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
                  ],
                );
              },
            ),
    );
  }

  Future<void> _decidir(int id, bool aceitar) async {
    try {
      if (aceitar) {
        await AppServices.instance.servicos.aceitar(id);
      } else {
        await AppServices.instance.servicos.recusar(id);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A API não confirmou a alteração.')),
        );
      }
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
  Future<void> _editar({Map<String, dynamic>? servico}) async {
    final nome = TextEditingController(text: '${servico?['nome'] ?? ''}');
    final categoriaId = TextEditingController(
      text: '${servico?['categoriaId'] ?? servico?['categoria']?['id'] ?? ''}',
    );
    final preco = TextEditingController(
      text: '${servico?['precoInicial'] ?? ''}',
    );
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(servico == null ? 'Adicionar serviço' : 'Editar serviço'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome do serviço'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Informe o nome.' : null,
              ),
              TextFormField(
                controller: categoriaId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID da categoria aprovada',
                ),
              ),
              TextFormField(
                controller: preco,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Preço inicial (R\$)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final atual = await AppServices.instance.profissionais.meusServicos();
      final servicos = (atual['servicos'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => <String, dynamic>{
              'nome': e['nome'],
              'categoriaId': e['categoriaId'] ?? e['categoria']?['id'],
              'precoInicial': e['precoInicial'],
            },
          )
          .toList();
      final novo = <String, dynamic>{
        'nome': nome.text.trim(),
        if (int.tryParse(categoriaId.text.trim()) != null)
          'categoriaId': int.parse(categoriaId.text.trim()),
        if (double.tryParse(preco.text.replaceAll(',', '.')) != null)
          'precoInicial': double.parse(preco.text.replaceAll(',', '.')),
      };
      if (servico == null) {
        servicos.add(novo);
      } else {
        final index = servicos.indexWhere((e) => e['nome'] == servico['nome']);
        if (index >= 0) servicos[index] = novo;
      }
      await AppServices.instance.profissionais.salvarMeusServicos(servicos);
      if (mounted) {
        setState(
          () => _future = AppServices.instance.profissionais.meusServicos(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar. Verifique o perfil e a categoria.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Meus serviços'),
    backgroundColor: AppColors.fundo,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editar(),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
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
                  'Serviços e preços iniciais são gerenciados pela API. O valor final é combinado fora do aplicativo.',
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const _EmptyCard(
                text:
                    'Nenhum serviço cadastrado. Complete também os dados profissionais do perfil.',
              ),
            ...list.map(
              (e) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.home_repair_service_outlined,
                    color: AppColors.verde,
                  ),
                  title: Text('${e['nome']}'),
                  subtitle: Text(
                    '${e['categoria']?['nome'] ?? 'Sem categoria'} • ${e['precoInicial'] == null ? 'Preço a informar' : 'A partir de R\$ ${e['precoInicial']}'}\n${e['ativo'] == true ? 'Ativo' : 'Inativo'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _editar(servico: e),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
  late Future<Map<String, dynamic>> _future = AppServices.instance.profissionais
      .meuPerfil();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Meu perfil profissional'),
    backgroundColor: AppColors.fundo,
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final perfil = s.data?['profissional'];
        final usuario = AppServices.instance.auth.usuarioAtual ?? {};
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person_outline, size: 32),
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
                            '${usuario['tipo'] == 'empresa' ? 'Empresa' : 'Autônomo'} • dados privados',
                            style: const TextStyle(color: AppColors.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _BadgeCard(
              icon:
                  perfil is Map<String, dynamic> && perfil['verificado'] == true
                  ? Icons.verified
                  : Icons.verified_user_outlined,
              title:
                  perfil is Map<String, dynamic> && perfil['verificado'] == true
                  ? 'Verificado'
                  : 'Verificação pendente',
              text:
                  'O selo depende da aprovação da administração e não garante segurança, qualidade ou resultado.',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.documentosProfissional,
              ),
            ),
            const SizedBox(height: 10),
            _MenuRow(
              icon: Icons.badge_outlined,
              label: 'Dados profissionais',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.cadastroProfissional),
            ),
            _MenuRow(
              icon: Icons.home_repair_service_outlined,
              label: 'Serviços oferecidos',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.servicosProfissional),
            ),
            _MenuRow(
              icon: Icons.location_on_outlined,
              label: 'Região atendida',
              onTap: () => _editarRegiao(perfil),
            ),
            _MenuRow(
              icon: Icons.folder_outlined,
              label: 'Documentos e verificação',
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.documentosProfissional,
              ),
            ),
            _MenuRow(
              icon: Icons.star_outline_rounded,
              label: 'Avaliações recebidas',
              onTap: () => _aviso(
                'Avaliações públicas podem ser consultadas no seu perfil exibido ao cliente.',
              ),
            ),
            _MenuRow(
              icon: Icons.settings_outlined,
              label: 'Configurações da conta',
              onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
            ),
          ],
        );
      },
    ),
  );
  Future<void> _editarRegiao(Object? raw) async {
    final perfil = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final bairro = TextEditingController(text: '${perfil['bairro'] ?? ''}');
    final descricao = TextEditingController(
      text: '${perfil['descricao'] ?? ''}',
    );
    final preco = TextEditingController(
      text: '${perfil['precoInicial'] ?? ''}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dados profissionais'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descricao,
              decoration: const InputDecoration(
                labelText: 'Descrição (mín. 20 caracteres)',
              ),
            ),
            TextField(
              controller: bairro,
              decoration: const InputDecoration(labelText: 'Bairro/região'),
            ),
            TextField(
              controller: preco,
              decoration: const InputDecoration(labelText: 'Preço inicial'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppServices.instance.profissionais.salvarMeuPerfil({
        'descricao': descricao.text.trim(),
        'bairro': bairro.text.trim(),
        'precoInicial': double.tryParse(preco.text.replaceAll(',', '.')),
        'servicos': (perfil['servicos'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(
              (e) => {
                'nome': e['nome'],
                'categoriaId': e['categoria']?['id'],
                'precoInicial': e['precoInicial'],
              },
            )
            .toList(),
      });
      if (mounted) {
        setState(
          () => _future = AppServices.instance.profissionais.meuPerfil(),
        );
      }
    } catch (_) {
      if (mounted) _aviso('Não foi possível salvar os dados profissionais.');
    }
  }

  void _aviso(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
  final endereco = pedido['enderecoAtendimento'];
  if (endereco is! Map<String, dynamic>) {
    return '${pedido['bairroAtendimento'] ?? 'Regiao nao informada'}';
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
            Row(
              children: [
                const Icon(
                  Icons.home_repair_service_outlined,
                  color: AppColors.verde,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pedido['categoria']?['nome'] ?? 'Serviço solicitado'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(text: _status(pedido['status'])),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${pedido['cliente']?['nome'] ?? 'Cliente'} • ${pedido['bairroAtendimento'] ?? 'Região não informada'}',
            ),
            Text(
              '${pedido['dataServico'] ?? ''} • ${pedido['horarioServico'] ?? ''}',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 6),
            Text(
              enderecoLiberado
                  ? _enderecoTexto(pedido)
                  : 'Endereco completo protegido ate o aceite valido.',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.detalhesSolicitacaoProfissional,
                        arguments: id,
                      );
                      if (result == true) onChanged?.call();
                    },
                    child: const Text('Ver detalhes'),
                  ),
                ),
                if (aguardando) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Recusar',
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, color: Color(0xFFC53030)),
                  ),
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('Aceitar'),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
        child: Column(
          children: [
            Icon(icon, color: AppColors.verde),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
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
        fontSize: 10,
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

Widget _erro(VoidCallback retry) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Não foi possível carregar seus pedidos.'),
      TextButton(onPressed: retry, child: const Text('Tentar novamente')),
    ],
  ),
);
