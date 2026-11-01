import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/habilitacao_resumo.dart';

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

  void _aplicarBusca() {
    FocusScope.of(context).unfocus();
    _termo = _buscaController.text.trim();
    _pagina = 1;
    _recarregar();
  }

  Future<void> _analisar(Map<String, dynamic> item) async {
    if (_salvando) return;
    String acao = 'iniciar_analise';
    String motivo = 'revisao_cadastral';
    final raw = item['habilitacao'];
    final dados = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (dados['estado'] == 'suspenso') acao = 'reabrir';
    var enviando = false;
    String? erro;
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !enviando,
          child: AlertDialog(
            scrollable: true,
            title: Text('${item['nome'] ?? 'Profissional'}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HabilitacaoResumo(dados: dados),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('habilitacao-acao'),
                    initialValue: acao,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ação'),
                    items: [
                      if (dados['estado'] != 'suspenso')
                        const DropdownMenuItem(
                          value: 'iniciar_analise',
                          child: Text('Iniciar análise'),
                        ),
                      const DropdownMenuItem(
                        value: 'suspender',
                        child: Text('Suspender habilitação'),
                      ),
                      const DropdownMenuItem(
                        value: 'reabrir',
                        child: Text('Voltar para pendente'),
                      ),
                    ],
                    onChanged: enviando
                        ? null
                        : (value) => setDialogState(() => acao = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('habilitacao-motivo'),
                    initialValue: motivo,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Motivo'),
                    items: const [
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
                    onChanged: enviando
                        ? null
                        : (value) => setDialogState(() => motivo = value!),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esta decisão não aprova identidade ou antecedentes e não libera atendimentos.',
                  ),
                  if (erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      erro!,
                      key: const ValueKey('habilitacao-erro-envio'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: enviando
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const ValueKey('habilitacao-confirmar'),
                onPressed: enviando
                    ? null
                    : () async {
                        setDialogState(() {
                          enviando = true;
                          erro = null;
                        });
                        setState(() => _salvando = true);
                        try {
                          await AppServices.instance.admin.analisarHabilitacao(
                            item['id'] as int,
                            acao,
                            motivo,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              erro = error is ApiException
                                  ? error.message
                                  : 'Não foi possível registrar a análise. Tente novamente.';
                            });
                          }
                        } finally {
                          if (mounted) setState(() => _salvando = false);
                          if (dialogContext.mounted) {
                            setDialogState(() => enviando = false);
                          }
                        }
                      },
                child: Text(enviando ? 'Enviando…' : 'Confirmar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmar != true || !mounted) return;
    _recarregar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Análise registrada.')));
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
              final filtrosAtivos = _termo.isNotEmpty || _estado.isNotEmpty;
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
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Buscar profissional',
                        suffixIcon: IconButton(
                          tooltip: 'Aplicar busca',
                          onPressed: _aplicarBusca,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                      onSubmitted: (_) => _aplicarBusca(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _estado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Habilitação',
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Todas')),
                        DropdownMenuItem(
                          value: 'pendente',
                          child: Text('Pendente'),
                        ),
                        DropdownMenuItem(
                          value: 'em_analise',
                          child: Text('Em análise'),
                        ),
                        DropdownMenuItem(
                          value: 'suspenso',
                          child: Text('Suspenso'),
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
                      'Identidade, telefone e antecedentes aguardam integração e política de análise. Nenhum profissional pode ser liberado nesta etapa.',
                    ),
                    const SizedBox(height: 16),
                    if (itens.isEmpty)
                      EmptyStateView(
                        title: _pagina > 1
                            ? 'Nenhum profissional nesta página'
                            : filtrosAtivos
                            ? 'Nenhum profissional encontrado'
                            : 'Nenhum profissional cadastrado',
                        message: _pagina > 1
                            ? 'Volte para a página anterior.'
                            : filtrosAtivos
                            ? 'Tente outro nome ou altere o filtro de habilitação.'
                            : 'Os perfis aparecerão aqui quando forem cadastrados.',
                        icon: Icons.person_outline,
                      ),
                    for (final item in itens)
                      Card(
                        child: ListTile(
                          title: Text('${item['nome']}'),
                          subtitle: Text(
                            item['habilitacao']?['revisaoSolicitadaEm'] != null
                                ? 'Revisão solicitada pelo profissional'
                                : 'Atendimentos bloqueados',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _salvando ? null : () => _analisar(item),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        Expanded(
                          child: Text(
                            'Página $_pagina de $totalPaginas - $total registros',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
              );
            },
          ),
        ),
      ],
    ),
  );
}
