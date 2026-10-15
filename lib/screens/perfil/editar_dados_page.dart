import 'package:flutter/material.dart';

import '../../widgets/unsaved_form_guard.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import '../../widgets/async_state_view.dart';

class EditarDadosPage extends StatefulWidget {
  const EditarDadosPage({super.key});

  @override
  State<EditarDadosPage> createState() => _EditarDadosPageState();
}

class _EditarDadosPageState extends State<EditarDadosPage> {
  final _formKey = GlobalKey<FormState>();
  List<String> _valoresIniciais = [];
  List<TextEditingController> get _campos => [
    _nome,
    _email,
    _telefone,
    _bairro,
    _cidade,
    _uf,
    _observacoes,
  ];
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _uf = TextEditingController();
  final _observacoes = TextEditingController();

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _uf.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final Map<String, dynamic> dados;
      if (AppServices.instance.auth.autenticado) {
        final response = await AppServices.instance.clientes.meuPerfil();
        final cliente = response['cliente'];
        if (cliente is! Map<String, dynamic>) {
          throw const ApiException('Não foi possível carregar seus dados.');
        }
        dados = cliente;
      } else if (AppServices.instance.emDemonstracao) {
        final usuario = ConectaLarMockStore.instance.usuarioAtual;
        dados = {
          'nome': usuario.nome,
          'email': usuario.email,
          'telefone': usuario.telefone,
          'bairroPrincipal': usuario.bairro,
        };
      } else {
        throw const ApiException('Entre na sua conta para continuar.');
      }

      _nome.text = _valor(dados['nome']);
      _email.text = _valor(dados['email']);
      _telefone.text = _valor(dados['telefone']);
      _bairro.text = _valor(dados['bairroPrincipal']);
      _cidade.text = _valor(dados['cidade']);
      _uf.text = _valor(dados['uf']);
      _observacoes.text = _valor(dados['observacoes']);
      _valoresIniciais = _campos.map((c) => c.text).toList();
    } catch (_) {
      _erro = 'Não foi possível carregar seus dados. Tente novamente.';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AppServices.instance.auth.autenticado) {
      _mensagem('Entre na sua conta para salvar seus dados.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await AppServices.instance.clientes.atualizarMeuPerfil({
        'nome': _nome.text.trim(),
        'telefone': _telefone.text.trim(),
        'bairroPrincipal': _bairro.text.trim(),
        'cidade': _cidade.text.trim(),
        'uf': _uf.text.trim().toUpperCase(),
        'observacoes': _observacoes.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível salvar seus dados. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedFormGuard(
      controllers: _campos,
      initialValues: _valoresIniciais,
      busy: _salvando,
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Meus dados'),
      backgroundColor: AppColors.fundo,
      body: _carregando
          ? const AsyncLoadingView(label: 'Carregando seus dados.')
          : _erro != null
          ? AsyncErrorView(message: _erro!, onRetry: _carregar)
          : SafeArea(
              top: false,
              child: ListView(
                padding: AppInsets.page,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Mantenha seu perfil atualizado',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'Essas informações ajudam a identificar sua conta e organizar seus atendimentos.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textoSuave),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            Card(
                              child: Padding(
                                padding: AppInsets.card,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      key: const ValueKey('perfil-nome'),
                                      controller: _nome,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome completo',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (valor) {
                                        final erro = validarCampoObrigatorio(
                                          valor,
                                        );
                                        if (erro != null) return erro;
                                        if (valor!.trim().length < 3) {
                                          return 'Informe seu nome completo.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    TextFormField(
                                      key: const ValueKey('perfil-email'),
                                      controller: _email,
                                      readOnly: true,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        prefixIcon: Icon(Icons.mail_outline),
                                        helperText:
                                            'Para alterar o e-mail, confirme a titularidade da conta.',
                                        helperMaxLines: 10,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    TextFormField(
                                      key: const ValueKey('perfil-telefone'),
                                      controller: _telefone,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Telefone',
                                        prefixIcon: Icon(Icons.phone_outlined),
                                      ),
                                      validator: validarTelefoneOpcional,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            Card(
                              child: Padding(
                                padding: AppInsets.card,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sua região',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    TextFormField(
                                      key: const ValueKey('perfil-bairro'),
                                      controller: _bairro,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Bairro principal',
                                        prefixIcon: Icon(
                                          Icons.location_on_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            key: const ValueKey(
                                              'perfil-cidade',
                                            ),
                                            controller: _cidade,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: const InputDecoration(
                                              labelText: 'Cidade',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            key: const ValueKey('perfil-uf'),
                                            controller: _uf,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(
                                                2,
                                              ),
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'UF',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    TextFormField(
                                      key: const ValueKey('perfil-observacoes'),
                                      controller: _observacoes,
                                      minLines: 2,
                                      maxLines: 4,
                                      maxLength: 280,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: const InputDecoration(
                                        labelText: 'Observações (opcional)',
                                        alignLabelWithHint: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            FilledButton.icon(
                              key: const ValueKey('perfil-salvar'),
                              onPressed: _salvando ? null : _salvar,
                              icon: _salvando
                                  ? const ButtonProgressIndicator()
                                  : const Icon(Icons.check_rounded),
                              label: ActionLabel(
                                busy: _salvando,
                                text: _salvando
                                    ? 'Salvando...'
                                    : 'Salvar alterações',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _valor(Object? value) => value?.toString() ?? '';
