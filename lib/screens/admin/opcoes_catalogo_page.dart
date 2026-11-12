import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class OpcoesCatalogoPage extends StatefulWidget {
  const OpcoesCatalogoPage({
    super.key,
    required this.categoriaId,
    required this.servico,
  });
  final int categoriaId;
  final Map<String, dynamic> servico;
  @override
  State<OpcoesCatalogoPage> createState() => _OpcoesCatalogoPageState();
}

class _OpcoesCatalogoPageState extends State<OpcoesCatalogoPage> {
  late final int _servicoId = int.parse('${widget.servico['id']}');
  late Future<Map<String, dynamic>> _future = _carregar();
  int _pagina = 1;
  bool _salvando = false;

  Future<Map<String, dynamic>> _carregar() async {
    final resposta = await AppServices.instance.admin.opcoesServico(
      widget.categoriaId,
      _servicoId,
      pagina: _pagina,
    );
    if (resposta['opcoes'] is! List) {
      throw const FormatException('Resposta invalida.');
    }
    return resposta;
  }

  void _atualizar() => setState(() {
    _future = _carregar();
  });

  Future<void> _salvar(Map<String, dynamic> dados, {int? id}) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await AppServices.instance.admin.salvarOpcaoServico(
        widget.categoriaId,
        _servicoId,
        dados,
        id: id,
      );
      if (mounted) _atualizar();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a opção.')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editar([Map<String, dynamic>? item]) async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) =>
          _OpcaoDialog(nome: item?['nome'] as String?, editando: item != null),
    );
    if (nome != null && mounted) {
      await _salvar({'nome': nome}, id: item?['id'] as int?);
    }
  }

  Future<void> _status(Map<String, dynamic> item) async {
    final ativo = item['ativo'] == true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ativo ? 'Pausar opção?' : 'Ativar opção?'),
        content: Text(
          ativo
              ? 'A opção não poderá ser escolhida em novos pedidos.'
              : 'A opção ficará disponível no catálogo. Isso não libera contratações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ativo ? 'Pausar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await _salvar({'ativo': !ativo}, id: item['id'] as int);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarCustom(title: 'Opções do serviço'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _salvando ? null : _editar,
      icon: const Icon(Icons.add),
      label: const Text('Nova opção'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(label: 'Carregando opções.');
        }
        if (snapshot.hasError) {
          return AsyncErrorView(
            message: 'Não foi possível carregar as opções.',
            onRetry: _atualizar,
          );
        }
        final opcoes = (snapshot.data!['opcoes'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final paginacao = snapshot.data!['paginacao'];
        final temMais = paginacao is Map && paginacao['temMais'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            if (_salvando) const LinearProgressIndicator(),
            Text(
              '${widget.servico['nome']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (opcoes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhuma opção cadastrada neste serviço.'),
              ),
            for (final item in opcoes)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.checklist, color: AppColors.verde),
                  title: Text('${item['nome']}'),
                  subtitle: Text(item['ativo'] == true ? 'Ativa' : 'Pausada'),
                  onTap: _salvando ? null : () => _editar(item),
                  trailing: PopupMenuButton<String>(
                    enabled: !_salvando,
                    tooltip: 'Ações da opção',
                    onSelected: (valor) {
                      if (valor == 'editar') {
                        _editar(item);
                      } else {
                        _status(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(
                          item['ativo'] == true ? 'Pausar' : 'Ativar',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_pagina > 1 || temMais)
              Row(
                children: [
                  TextButton(
                    onPressed: _pagina > 1
                        ? () {
                            _pagina--;
                            _atualizar();
                          }
                        : null,
                    child: const Text('Anterior'),
                  ),
                  Expanded(
                    child: Text('Página $_pagina', textAlign: TextAlign.center),
                  ),
                  TextButton(
                    onPressed: temMais
                        ? () {
                            _pagina++;
                            _atualizar();
                          }
                        : null,
                    child: const Text('Próxima'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _OpcaoDialog extends StatefulWidget {
  const _OpcaoDialog({required this.nome, required this.editando});
  final String? nome;
  final bool editando;
  @override
  State<_OpcaoDialog> createState() => _OpcaoDialogState();
}

class _OpcaoDialogState extends State<_OpcaoDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.nome ?? '');
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.editando ? 'Editar opção' : 'Nova opção'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Nome da opção'),
        validator: (value) => (value ?? '').trim().length < 2
            ? 'Informe ao menos dois caracteres.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Salvar'),
      ),
    ],
  );
}
