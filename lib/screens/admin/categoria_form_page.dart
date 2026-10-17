import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/categoria_icons.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/session_gate.dart';
import '../../widgets/unsaved_form_guard.dart';

class CategoriaFormPage extends StatelessWidget {
  const CategoriaFormPage({this.categoria, super.key});

  final Map<String, dynamic>? categoria;

  @override
  Widget build(BuildContext context) => SessionGate(
    papeis: const {'administrador'},
    builder: (_) => _CategoriaForm(categoria: categoria),
  );
}

class _CategoriaForm extends StatefulWidget {
  const _CategoriaForm({this.categoria});

  final Map<String, dynamic>? categoria;

  @override
  State<_CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<_CategoriaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final String _nomeInicial;
  late String? _icone;
  late String? _iconeInicial;
  late bool _ativo;
  late bool _ativoInicial;
  bool _salvando = false;
  bool _mostrarErroIcone = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nomeInicial = '${widget.categoria?['nome'] ?? ''}';
    _nome = TextEditingController(text: _nomeInicial);
    final icone = '${widget.categoria?['icone'] ?? 'home_repair'}';
    _icone = categoriaIconOptions.any((option) => option.id == icone)
        ? icone
        : null;
    _iconeInicial = _icone;
    _ativo = widget.categoria?['ativo'] != false;
    _ativoInicial = _ativo;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) {
      return;
    }
    final services = AppServices.instance;
    if (!services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] != 'administrador') {
      setState(() => _erro = 'Entre com uma conta administrativa autorizada.');
      return;
    }
    final formValido = _formKey.currentState?.validate() == true;
    setState(() => _mostrarErroIcone = _icone == null);
    if (!formValido || _icone == null) {
      return;
    }
    final id = int.tryParse('${widget.categoria?['id'] ?? ''}');
    if (widget.categoria != null && (id == null || id < 1)) {
      setState(
        () => _erro =
            'Não foi possível identificar a categoria. Volte à lista e tente novamente.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await services.admin.salvarCategoria(
        id: id,
        nome: _nome.text.trim(),
        icone: _icone!,
        ativo: _ativo,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro = switch (error.statusCode) {
          409 => 'Já existe uma categoria com este nome. Escolha outro nome.',
          403 => 'Sua conta não tem permissão para alterar categorias.',
          401 => 'Sua sessão expirou. Entre novamente para continuar.',
          _ => error.message,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = 'Não foi possível salvar a categoria. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedFormGuard(
    controllers: [_nome],
    initialValues: [_nomeInicial],
    isDirty: () => _icone != _iconeInicial || _ativo != _ativoInicial,
    busy: _salvando,
    child: Scaffold(
      appBar: AppBarCustom(
        title: widget.categoria == null ? 'Nova categoria' : 'Editar categoria',
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppInsets.page,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Organize o catálogo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'Escolha um nome claro e o ícone que melhor representa a categoria.',
                    ),
                    const SizedBox(height: AppSpace.xl),
                    TextFormField(
                      key: const ValueKey('categoria-form-nome'),
                      controller: _nome,
                      enabled: !_salvando,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nome da categoria',
                        helperText: 'De 2 a 80 caracteres.',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      validator: (value) {
                        final length = (value ?? '').trim().length;
                        return length < 2 || length > 80
                            ? 'Informe um nome entre 2 e 80 caracteres.'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Card(
                      child: ExpansionTile(
                        key: const ValueKey('categoria-form-icones'),
                        enabled: !_salvando,
                        maintainState: true,
                        leading: Icon(
                          categoriaIconData(_icone),
                          color: AppColors.verde,
                        ),
                        title: const Text('Ícone da categoria'),
                        subtitle: Text(
                          _icone == null
                              ? 'Escolha um ícone'
                              : _rotuloIcone(_icone!),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          for (final option in categoriaIconOptions)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.sm),
                              child: Semantics(
                                selected: _icone == option.id,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    key: ValueKey(
                                      'categoria-icone-${option.id}',
                                    ),
                                    onPressed: _salvando
                                        ? null
                                        : () => setState(() {
                                            _icone = option.id;
                                            _mostrarErroIcone = false;
                                          }),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _icone == option.id
                                          ? AppColors.verdeClaro
                                          : AppColors.branco,
                                      side: BorderSide(
                                        color: _icone == option.id
                                            ? AppColors.verde
                                            : AppColors.borda,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpace.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(option.icon),
                                          const SizedBox(width: AppSpace.sm),
                                          Expanded(
                                            child: Text(
                                              _rotuloIcone(option.id),
                                            ),
                                          ),
                                          if (_icone == option.id) ...[
                                            const SizedBox(width: AppSpace.sm),
                                            const Icon(Icons.check_rounded),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_mostrarErroIcone) ...[
                      const SizedBox(height: AppSpace.sm),
                      const Text(
                        'Selecione um ícone do catálogo.',
                        style: TextStyle(color: AppColors.erro),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    SwitchListTile(
                      key: const ValueKey('categoria-form-ativo'),
                      contentPadding: EdgeInsets.zero,
                      value: _ativo,
                      onChanged: _salvando
                          ? null
                          : (value) => setState(() => _ativo = value),
                      title: const Text('Categoria ativa'),
                      subtitle: const Text(
                        'Categorias inativas deixam de aparecer no catálogo público. O histórico é preservado.',
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Card(
                      key: const ValueKey('categoria-form-previa'),
                      child: Padding(
                        padding: AppInsets.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prévia da categoria',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpace.lg),
                            Row(
                              children: [
                                Icon(
                                  categoriaIconData(_icone),
                                  color: AppColors.verde,
                                  size: 32,
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Text(
                                    _nome.text.trim().isEmpty
                                        ? 'Nome da categoria'
                                        : _nome.text.trim(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(_ativo ? 'Ativa' : 'Inativa'),
                          ],
                        ),
                      ),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _erro!,
                          key: const ValueKey('categoria-form-erro'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.erro),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.xl),
                    FilledButton.icon(
                      key: const ValueKey('categoria-form-salvar'),
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.check_rounded),
                      label: ActionLabel(
                        text: _salvando ? 'Salvando...' : 'Salvar categoria',
                        busy: _salvando,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _rotuloIcone(String id) => switch (id) {
  'home_repair' => 'Serviços',
  'electrical_services' => 'Elétrica',
  'plumbing' => 'Hidráulica',
  'format_paint' => 'Pintura',
  'cleaning_services' => 'Limpeza',
  'build' => 'Manutenção',
  'ac_unit' => 'Ar-condicionado',
  'construction' => 'Reformas',
  'grass' => 'Jardim',
  _ => 'Outros',
};
