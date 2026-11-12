import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import 'opcoes_catalogo_page.dart';

class CatalogoCategoriaPage extends StatefulWidget {
  const CatalogoCategoriaPage({required this.categoria, super.key});

  final Map<String, dynamic> categoria;

  @override
  State<CatalogoCategoriaPage> createState() => _CatalogoCategoriaPageState();
}

class _CatalogoCategoriaPageState extends State<CatalogoCategoriaPage> {
  late final int _categoriaId = int.parse('${widget.categoria['id']}');
  late Future<Map<String, dynamic>> _future = _carregar();
  int _pagina = 1;
  bool _salvando = false;

  Future<Map<String, dynamic>> _carregar() => AppServices.instance.admin
      .servicosCategoria(_categoriaId, pagina: _pagina);

  void _recarregar() => setState(() {
    _future = _carregar();
  });

  Future<void> _editar([Map<String, dynamic>? item]) async {
    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _ServicoCatalogoForm(categoriaId: _categoriaId, item: item),
      ),
    );
    if (alterado == true && mounted) _recarregar();
  }

  Future<void> _alterarStatus(Map<String, dynamic> item) async {
    final ativo = item['ativo'] == true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ativo ? 'Pausar serviço?' : 'Ativar serviço?'),
        content: Text(
          ativo
              ? 'Novas ofertas deixarão de estar disponíveis. O histórico será preservado.'
              : 'O serviço ficará disponível no catálogo, sem liberar contratações por si só.',
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
    if (confirmar != true || !mounted) return;
    setState(() => _salvando = true);
    try {
      await AppServices.instance.admin.salvarServicoCatalogo(_categoriaId, {
        'ativo': !ativo,
      }, id: int.parse('${item['id']}'));
      if (mounted) _recarregar();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível alterar o serviço.')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarCustom(title: '${widget.categoria['nome']}'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _salvando ? null : () => _editar(),
      icon: const Icon(Icons.add),
      label: const Text('Novo serviço'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(label: 'Carregando serviços.');
        }
        if (snapshot.hasError) {
          return AsyncErrorView(
            message: 'Não foi possível carregar os serviços.',
            onRetry: _recarregar,
          );
        }
        final itens = (snapshot.data?['servicos'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final paginacao = snapshot.data?['paginacao'] as Map?;
        final temMais = paginacao?['temMais'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            if (_salvando) const LinearProgressIndicator(),
            Text('Serviços', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (itens.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhum serviço cadastrado nesta categoria.'),
              ),
            for (final item in itens)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.home_repair_service_outlined,
                    color: AppColors.verde,
                  ),
                  title: Text('${item['nome']}'),
                  subtitle: Text(item['ativo'] == true ? 'Ativo' : 'Pausado'),
                  onTap: _salvando ? null : () => _editar(item),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Ações do serviço',
                    enabled: !_salvando,
                    onSelected: (value) {
                      if (value == 'editar') {
                        _editar(item);
                      } else if (value == 'opcoes') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OpcoesCatalogoPage(
                              categoriaId: _categoriaId,
                              servico: item,
                            ),
                          ),
                        );
                      } else {
                        _alterarStatus(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem(
                        value: 'opcoes',
                        child: Text('Opções do serviço'),
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
                  TextButton.icon(
                    onPressed: _pagina > 1
                        ? () {
                            _pagina--;
                            _recarregar();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Anterior'),
                  ),
                  Expanded(
                    child: Text('Página $_pagina', textAlign: TextAlign.center),
                  ),
                  TextButton.icon(
                    onPressed: temMais
                        ? () {
                            _pagina++;
                            _recarregar();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Próxima'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _ServicoCatalogoForm extends StatefulWidget {
  const _ServicoCatalogoForm({required this.categoriaId, this.item});
  final int categoriaId;
  final Map<String, dynamic>? item;
  @override
  State<_ServicoCatalogoForm> createState() => _ServicoCatalogoFormState();
}

class _ServicoCatalogoFormState extends State<_ServicoCatalogoForm> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(
    text: '${widget.item?['nome'] ?? ''}',
  );
  late final _descricao = TextEditingController(
    text: '${widget.item?['descricao'] ?? ''}',
  );
  late final _inclusoes = TextEditingController(
    text: '${widget.item?['inclusoes'] ?? ''}',
  );
  late final _exclusoes = TextEditingController(
    text: '${widget.item?['exclusoes'] ?? ''}',
  );
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _inclusoes.dispose();
    _exclusoes.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    String? texto(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await AppServices.instance.admin.salvarServicoCatalogo(
        widget.categoriaId,
        {
          'nome': _nome.text.trim(),
          'descricao': texto(_descricao),
          'inclusoes': texto(_inclusoes),
          'exclusoes': texto(_exclusoes),
        },
        id: widget.item == null ? null : int.parse('${widget.item!['id']}'),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível salvar o serviço.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarCustom(
      title: widget.item == null ? 'Novo serviço' : 'Editar serviço',
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: AppInsets.page,
        children: [
          TextFormField(
            controller: _nome,
            enabled: !_salvando,
            maxLength: 90,
            decoration: const InputDecoration(labelText: 'Nome do serviço'),
            validator: (value) => (value ?? '').trim().length < 2
                ? 'Informe o nome do serviço.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descricao,
            enabled: !_salvando,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inclusoes,
            enabled: !_salvando,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'O que está incluído'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _exclusoes,
            enabled: !_salvando,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'O que não está incluído',
            ),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _erro!,
                style: const TextStyle(color: AppColors.erro),
              ),
            ),
          FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: const Icon(Icons.save_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    ),
  );
}
