import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/solicitacao.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/session_gate.dart';

class HistoricoAdminPage extends StatelessWidget {
  const HistoricoAdminPage({super.key});

  @override
  Widget build(BuildContext context) => SessionGate(
    papeis: const {'administrador'},
    builder: (_) => const _HistoricoAdminView(),
  );
}

class _HistoricoAdminView extends StatefulWidget {
  const _HistoricoAdminView();

  @override
  State<_HistoricoAdminView> createState() => _HistoricoAdminViewState();
}

class _HistoricoAdminViewState extends State<_HistoricoAdminView> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  StatusSolicitacao? _status;
  bool _finalizados = false;
  StatusSolicitacao? _statusAplicado;
  bool _finalizadosAplicado = false;
  int? _usuarioAplicado;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
    _future.ignore();
  }

  Future<List<Map<String, dynamic>>> _carregar() async {
    final response = await AppServices.instance.admin.historicoAtendimentos(
      status: _statusAplicado?.valorBanco,
      finalizados: _finalizadosAplicado ? true : null,
      usuarioId: _usuarioAplicado,
    );
    final registros = response['atendimentos'];
    if (registros is! List ||
        registros.any((item) => item is! Map<String, dynamic>)) {
      throw const ApiException('Não foi possível interpretar o histórico.');
    }
    return registros.cast<Map<String, dynamic>>();
  }

  Future<void> _atualizar() async {
    final future = _carregar();
    future.ignore();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // O estado de erro apresenta uma nova tentativa com os mesmos filtros.
    }
  }

  void _aplicar() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _statusAplicado = _status;
    _finalizadosAplicado = _finalizados;
    _usuarioAplicado = int.tryParse(_usuarioController.text.trim());
    _atualizar();
  }

  void _limpar() {
    _usuarioController.clear();
    setState(() {
      _status = null;
      _finalizados = false;
    });
    _aplicar();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarCustom(
      title: 'Histórico de atendimentos',
      actions: [
        IconButton(
          tooltip: 'Atualizar histórico',
          onPressed: _atualizar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _atualizar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppInsets.page,
          children: [
            Text(
              'Consultar atendimentos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Acompanhe as solicitações e seus estados. Esta área é somente para consulta.',
            ),
            const SizedBox(height: AppSpace.lg),
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<StatusSolicitacao?>(
                        key: ValueKey(
                          'historico-status-${_status?.valorBanco}',
                        ),
                        initialValue: _status,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText: 'Situação',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas'),
                          ),
                          for (final status in StatusSolicitacao.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.rotulo),
                            ),
                        ],
                        onChanged: (value) => setState(() => _status = value),
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('historico-usuario'),
                        controller: _usuarioController,
                        decoration: const InputDecoration(
                          labelText: 'ID da conta (opcional)',
                          helperText:
                              'Filtra a participação de um cliente ou profissional.',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) => _aplicar(),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          return text.isEmpty ||
                                  RegExp(r'^[1-9]\d{0,9}$').hasMatch(text)
                              ? null
                              : 'Informe um ID válido, maior que zero.';
                        },
                      ),
                      const SizedBox(height: AppSpace.sm),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _finalizados,
                        onChanged: (value) =>
                            setState(() => _finalizados = value ?? false),
                        title: const Text('Somente finalizados'),
                        subtitle: const Text(
                          'Concluídos, cancelados ou recusados.',
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      FilledButton.icon(
                        onPressed: _aplicar,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Aplicar filtros'),
                      ),
                      TextButton(
                        onPressed: _limpar,
                        child: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AsyncLoadingView(label: 'Carregando histórico.');
                }
                if (snapshot.hasError) {
                  return AsyncErrorView(
                    message:
                        'Não foi possível carregar o histórico de atendimentos.',
                    onRetry: _atualizar,
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const EmptyStateView(
                    title: 'Nenhum atendimento neste filtro',
                    message:
                        'Altere os filtros ou atualize para consultar novos registros.',
                    icon: Icons.history_outlined,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? 'atendimento' : 'atendimentos'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (items.length >= 200)
                      const Text(
                        'Exibindo os 200 mais recentes. Use os filtros para refinar a consulta.',
                      ),
                    const SizedBox(height: AppSpace.md),
                    for (final item in items) _HistoricoCard(item: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _HistoricoCard extends StatelessWidget {
  const _HistoricoCard({required this.item});
  final Map<String, dynamic> item;

  String _nome(String key) {
    final value = item[key];
    return value is Map && value['nome'] is String
        ? value['nome'] as String
        : 'Não informado';
  }

  String _data(Object? value) {
    final data = DateTime.tryParse('$value');
    if (data == null) return 'Não informada';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rotulos = {
      for (final status in StatusSolicitacao.values)
        status.valorBanco: status.rotulo,
    };
    final preco = num.tryParse('${item['precoInicial']}');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atendimento #${item['id']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              rotulos[item['status']] ?? 'Situação não informada',
              style: const TextStyle(
                color: AppColors.verdeEscuro,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Cliente: ${_nome('cliente')}'),
            Text('Profissional: ${_nome('profissional')}'),
            Text('Categoria: ${_nome('categoria')}'),
            Text('Bairro: ${item['bairroAtendimento'] ?? 'Não informado'}'),
            Text(
              'Data solicitada: ${_data(item['dataServico'])} às ${item['horarioServico'] ?? '—'}',
            ),
            const SizedBox(height: AppSpace.sm),
            if (item['descricao'] is String) Text(item['descricao'] as String),
            const SizedBox(height: AppSpace.sm),
            Text(
              preco == null
                  ? 'Preço inicial: a combinar'
                  : 'Preço inicial: R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
            ),
            const Text(
              'Valores finais e pagamentos são combinados fora do app.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Criado em ${_data(item['criadoEm'])} • Atualizado em ${_data(item['atualizadoEm'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
