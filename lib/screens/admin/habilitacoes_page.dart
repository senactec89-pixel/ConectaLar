import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/habilitacao_resumo.dart';
import 'dossie_profissional_page.dart';

class HabilitacoesPage extends StatefulWidget {
  const HabilitacoesPage({super.key});
  @override
  State<HabilitacoesPage> createState() => _HabilitacoesPageState();
}

class _HabilitacoesPageState extends State<HabilitacoesPage> {
  int _pagina = 1;
  String _termo = '';
  String _estado = '';
  final _buscaController = TextEditingController();
  bool _salvando = false;
  late Future<Map<String, dynamic>> _future = _carregar();

  Future<Map<String, dynamic>> _carregar() => AppServices.instance.admin
      .habilitacoes(pagina: _pagina, termo: _termo, estado: _estado);

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _recarregar() => setState(() {
    _future = _carregar();
    _future.ignore();
  });

  Future<void> _analisar(Map<String, dynamic> item) async {
    if (_salvando) return;
    String acao = 'iniciar_analise';
    final raw = item['habilitacao'];
    final dados = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (dados['estado'] == 'suspenso') {
      acao = 'reabrir';
    } else if (dados['estado'] == 'aprovado') {
      acao = 'suspender';
    } else if (dados['aguardandoSegundoRevisor'] == true) {
      acao = 'aprovar';
    }
    String motivo = acao == 'aprovar'
        ? 'revisao_concluida'
        : 'revisao_cadastral';
    final tamanhoTela = MediaQuery.sizeOf(context);
    final larguraDialogo = (tamanhoTela.width - 32)
        .clamp(240.0, 420.0)
        .toDouble();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SizedBox(
            width: larguraDialogo,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: tamanhoTela.height - 48),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${item['nome'] ?? 'Profissional'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    HabilitacaoResumo(dados: dados),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: acao,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ação'),
                      items: [
                        if (dados['testeLocalElegivel'] == true &&
                            dados['podeAtender'] != true)
                          const DropdownMenuItem(
                            value: 'aprovar_teste_local',
                            child: Text('Liberar somente para teste'),
                          ),
                        if (dados['estado'] != 'suspenso' &&
                            dados['estado'] != 'aprovado')
                          const DropdownMenuItem(
                            value: 'iniciar_analise',
                            child: Text('Iniciar análise'),
                          ),
                        if (dados['estado'] == 'pendente' ||
                            dados['estado'] == 'em_analise')
                          DropdownMenuItem(
                            value: 'aprovar',
                            child: Text(
                              dados['aguardandoSegundoRevisor'] == true
                                  ? 'Registrar aprovação final'
                                  : 'Registrar primeira aprovação',
                            ),
                          ),
                        if (dados['estado'] != 'suspenso')
                          const DropdownMenuItem(
                            value: 'suspender',
                            child: Text('Suspender habilitação'),
                          ),
                        if (dados['estado'] == 'suspenso')
                          const DropdownMenuItem(
                            value: 'reabrir',
                            child: Text('Voltar para pendente'),
                          ),
                      ],
                      onChanged: (value) => setDialogState(() {
                        acao = value!;
                        motivo = acao == 'aprovar'
                            ? 'revisao_concluida'
                            : acao == 'aprovar_teste_local'
                            ? 'teste_fluxo_local'
                            : 'revisao_cadastral';
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: motivo,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                      items: acao == 'aprovar'
                          ? const [
                              DropdownMenuItem(
                                value: 'revisao_concluida',
                                child: Text('Revisão documental concluída'),
                              ),
                            ]
                          : acao == 'aprovar_teste_local'
                          ? const [
                              DropdownMenuItem(
                                value: 'teste_fluxo_local',
                                child: Text('Teste local'),
                              ),
                            ]
                          : const [
                              DropdownMenuItem(
                                value: 'revisao_cadastral',
                                child: Text('Revisão cadastral'),
                              ),
                              DropdownMenuItem(
                                value: 'suspeita_fraude',
                                child: Text('Suspeita de fraude'),
                              ),
                              DropdownMenuItem(
                                value: 'solicitacao_titular',
                                child: Text('Solicitação do titular'),
                              ),
                            ],
                      onChanged: (value) =>
                          setDialogState(() => motivo = value!),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Abra o dossiê antes de decidir. A aprovação real exige dois administradores diferentes, documento de identificação aprovado e ao menos uma oferta do piloto revisada em duas etapas.',
                    ),
                    if (acao == 'aprovar_teste_local') ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Libera este perfil apenas para testar os fluxos. Não habilita atendimentos em produção.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirmar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _salvando = true);
    try {
      await AppServices.instance.admin.analisarHabilitacao(
        item['id'] as int,
        acao,
        acao == 'aprovar_teste_local' ? 'teste_fluxo_local' : motivo,
      );
      if (mounted) _recarregar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Não foi possível registrar a análise.',
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
    appBar: const AppBarCustom(title: 'Habilitações profissionais'),
    body: Column(
      children: [
        if (_salvando) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AsyncLoadingView(
                  label: 'Carregando habilitações.',
                );
              }
              if (snapshot.hasError) {
                return AsyncErrorView(
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Não foi possível carregar as habilitações.',
                  onRetry: _recarregar,
                );
              }
              final data = snapshot.data ?? {};
              final itens = (data['profissionais'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final total = data['total'] as int? ?? 0;
              final pagination = data['paginacao'] is Map
                  ? Map<String, dynamic>.from(data['paginacao'] as Map)
                  : const <String, dynamic>{};
              final totalPaginas =
                  int.tryParse('${pagination['totalPaginas']}') ?? 1;
              return RefreshIndicator(
                onRefresh: () async {
                  _recarregar();
                  try {
                    await _future;
                  } catch (_) {}
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    TextField(
                      controller: _buscaController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar profissional',
                      ),
                      onSubmitted: (value) {
                        _termo = value.trim();
                        _pagina = 1;
                        _recarregar();
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _estado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Habilitacao',
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Todas')),
                        DropdownMenuItem(
                          value: 'pendente',
                          child: Text('Pendente'),
                        ),
                        DropdownMenuItem(
                          value: 'em_analise',
                          child: Text('Em analise'),
                        ),
                        DropdownMenuItem(
                          value: 'suspenso',
                          child: Text('Suspenso'),
                        ),
                        DropdownMenuItem(
                          value: 'aprovado',
                          child: Text('Habilitados'),
                        ),
                        DropdownMenuItem(
                          value: 'teste_local_aprovado',
                          child: Text('Habilitados (teste)'),
                        ),
                      ],
                      onChanged: (value) {
                        _estado = value ?? '';
                        _pagina = 1;
                        _recarregar();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'A aprovação real exige revisão de documento e oferta por dois administradores diferentes. Telefone é apenas contato; antecedentes não são verificados automaticamente.',
                    ),
                    const SizedBox(height: 16),
                    if (itens.isEmpty)
                      const EmptyStateView(
                        title: 'Nenhum profissional',
                        message: 'Não há perfis nesta página.',
                        icon: Icons.person_outline,
                      ),
                    for (final item in itens)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                title: Text('${item['nome']}'),
                                subtitle: Text(_rotuloEstado(item)),
                                trailing: IconButton(
                                  tooltip: 'Gerenciar habilitação',
                                  icon: const Icon(Icons.more_horiz),
                                  onPressed: _salvando
                                      ? null
                                      : () => _analisar(item),
                                ),
                                onTap: _salvando
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              DossieProfissionalPage(
                                                profissionalId:
                                                    item['id'] as int,
                                              ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        Text(
                          'Pagina $_pagina de $totalPaginas - $total registros',
                          textAlign: TextAlign.center,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Página anterior',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _pagina == 1 || _salvando
                                  ? null
                                  : () {
                                      _pagina--;
                                      _recarregar();
                                    },
                            ),
                            IconButton(
                              tooltip: 'Próxima página',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _pagina >= totalPaginas || _salvando
                                  ? null
                                  : () {
                                      _pagina++;
                                      _recarregar();
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

String _rotuloEstado(Map<String, dynamic> item) {
  final habilitacao = item['habilitacao'];
  if (habilitacao is! Map) return 'Atendimentos bloqueados';
  if (habilitacao['estado'] == 'aprovado' &&
      habilitacao['podeAtender'] == true) {
    return 'Habilitado para receber solicitações';
  }
  if (habilitacao['aguardandoSegundoRevisor'] == true) {
    return 'Aguardando segundo administrador';
  }
  if (habilitacao['estado'] == 'teste_local_aprovado' &&
      habilitacao['podeAtender'] == true) {
    return 'Habilitado somente para teste local';
  }
  if (habilitacao['estado'] == 'suspenso') return 'Habilitação suspensa';
  if (habilitacao['podeAtender'] == true) {
    return 'Habilitação de teste local';
  }
  if (habilitacao['revisaoSolicitadaEm'] != null) {
    return 'Revisão solicitada pelo profissional';
  }
  return 'Atendimentos bloqueados';
}
