import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/usuario.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  TipoUsuario _tipo = TipoUsuario.cliente;
  bool _aceitouTermos = false;
  bool _enviando = false;
  bool _contaCriada = false;
  bool _senhaOculta = true;
  bool _confirmacaoOculta = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate() || !_aceitouTermos) {
      setState(() {});
      return;
    }

    if (!_contaCriada) {
      FocusScope.of(context).unfocus();
      final confirmouEmail = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confira seu e-mail'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enviaremos o código de confirmação para:'),
              const SizedBox(height: AppSpace.sm),
              SelectableText(
                _emailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('cadastro-corrigir-email'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Corrigir e-mail'),
            ),
            FilledButton(
              key: const ValueKey('cadastro-confirmar-email'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar e criar conta'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmouEmail != true) {
        _emailFocusNode.requestFocus();
        return;
      }
    }

    setState(() => _enviando = true);
    try {
      final services = AppServices.instance;
      if (!_contaCriada) {
        await services.auth.cadastrar(
          nome: _nomeController.text,
          email: _emailController.text.trim(),
          senha: _senhaController.text,
          telefone: _telefoneController.text,
          tipo: _tipo.valorBanco,
        );
        _contaCriada = true;
      }
      await _aceitarTermosAtuais();

      if (!mounted) return;
      if (!services.auth.emailVerificado) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.verificacaoEmail,
          (_) => false,
        );
        return;
      }
      if (_tipo == TipoUsuario.cliente) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.cadastroProfissional);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _mostrarErro(
        _contaCriada
            ? 'Sua conta foi criada, mas não foi possível registrar o aceite dos termos. Tente concluir o cadastro novamente.'
            : error.message,
      );
    } catch (_) {
      if (!mounted) return;
      _mostrarErro(
        _contaCriada
            ? 'Sua conta foi criada. Verifique sua conexão e tente concluir o aceite dos termos.'
            : 'Não foi possível criar a conta. Verifique sua conexão.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _aceitarTermosAtuais() async {
    final termos = await AppServices.instance.termos.atuais();
    final payload = termos['termos'];
    if (payload is! Map<String, dynamic>) {
      throw StateError('Termos indisponíveis.');
    }
    final versao = payload['versao'];
    if (versao is String && versao.isNotEmpty) {
      await AppServices.instance.termos.aceitar(versao);
    } else {
      throw StateError('Versão dos termos indisponível.');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Criar conta'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppInsets.page,
          children: [
            const Text(
              'Crie sua conta',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _tipo == TipoUsuario.cliente
                  ? 'Preencha os dados básicos da sua conta.'
                  : 'Crie sua conta e depois complete o perfil, os serviços e a documentação.',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: AppSpace.lg),
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: AppInsets.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<TipoUsuario>(
                        key: const ValueKey('cadastro-tipo-conta'),
                        segments: const [
                          ButtonSegment(
                            value: TipoUsuario.cliente,
                            icon: Icon(Icons.person_outline),
                            label: Text('Cliente'),
                          ),
                          ButtonSegment(
                            value: TipoUsuario.profissional,
                            icon: Icon(Icons.home_repair_service_outlined),
                            label: Text('Profissional'),
                          ),
                        ],
                        selected: {
                          _tipo == TipoUsuario.empresa
                              ? TipoUsuario.profissional
                              : _tipo,
                        },
                        onSelectionChanged: _enviando || _contaCriada
                            ? null
                            : (value) => setState(() => _tipo = value.first),
                      ),
                      if (_tipo != TipoUsuario.cliente) ...[
                        const SizedBox(height: AppSpace.md),
                        DropdownButtonFormField<TipoUsuario>(
                          key: ValueKey(_tipo),
                          initialValue: _tipo,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de prestador',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TipoUsuario.profissional,
                              child: Text('Autônomo'),
                            ),
                            DropdownMenuItem(
                              value: TipoUsuario.empresa,
                              child: Text('Empresa'),
                            ),
                          ],
                          onChanged: _enviando || _contaCriada
                              ? null
                              : (value) => setState(
                                  () =>
                                      _tipo = value ?? TipoUsuario.profissional,
                                ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        key: const ValueKey('cadastro-nome'),
                        enabled: !_enviando && !_contaCriada,
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: validarCampoObrigatorio,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('cadastro-email'),
                        enabled: !_enviando && !_contaCriada,
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: validarEmail,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('cadastro-telefone'),
                        enabled: !_enviando && !_contaCriada,
                        controller: _telefoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: validarTelefoneObrigatorio,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('cadastro-senha'),
                        enabled: !_enviando && !_contaCriada,
                        controller: _senhaController,
                        obscureText: _senhaOculta,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          suffixIcon: IconButton(
                            key: const ValueKey('cadastro-ver-senha'),
                            tooltip: _senhaOculta
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: _enviando || _contaCriada
                                ? null
                                : () => setState(
                                    () => _senhaOculta = !_senhaOculta,
                                  ),
                            icon: Icon(
                              _senhaOculta
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validarSenhaForte,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('cadastro-confirmar-senha'),
                        enabled: !_enviando && !_contaCriada,
                        controller: _confirmarSenhaController,
                        obscureText: _confirmacaoOculta,
                        decoration: InputDecoration(
                          labelText: 'Confirmar senha',
                          suffixIcon: IconButton(
                            key: const ValueKey('cadastro-ver-confirmacao'),
                            tooltip: _confirmacaoOculta
                                ? 'Mostrar confirmação da senha'
                                : 'Ocultar confirmação da senha',
                            onPressed: _enviando || _contaCriada
                                ? null
                                : () => setState(
                                    () => _confirmacaoOculta =
                                        !_confirmacaoOculta,
                                  ),
                            icon: Icon(
                              _confirmacaoOculta
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (valor) {
                          final erro = validarSenhaForte(valor);
                          if (erro != null) return erro;
                          if (valor != _senhaController.text) {
                            return 'As senhas devem ser iguais.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      CheckboxListTile(
                        key: const ValueKey('cadastro-termos'),
                        contentPadding: EdgeInsets.zero,
                        value: _aceitouTermos,
                        onChanged: _enviando || _contaCriada
                            ? null
                            : (value) => setState(
                                () => _aceitouTermos = value ?? false,
                              ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Li e aceito os termos e o aviso de privacidade.',
                        ),
                        subtitle: !_aceitouTermos
                            ? const Text('Obrigatório para continuar.')
                            : null,
                      ),
                      TextButton.icon(
                        onPressed: _enviando
                            ? null
                            : () => Navigator.pushNamed(
                                context,
                                AppRoutes.termos,
                              ),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Ler termos e aviso de privacidade'),
                      ),
                      const SizedBox(height: AppSpace.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('cadastro-criar-conta'),
                          onPressed: _enviando ? null : _criarConta,
                          icon: _enviando
                              ? const ButtonProgressIndicator()
                              : const Icon(Icons.person_add_alt_1),
                          label: ActionLabel(
                            busy: _enviando,
                            text: _enviando
                                ? 'Aguarde...'
                                : _contaCriada
                                ? 'Concluir cadastro'
                                : 'Criar conta',
                          ),
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
