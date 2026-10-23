import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/usuario.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_identity_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import '../../widgets/google_web_button.dart';
import '../../widgets/conectalar_brand.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _enviando = false;
  bool _googlePronto = false;
  StreamSubscription<String>? _googleTokens;

  @override
  void initState() {
    super.initState();
    final google = AppServices.instance.googleIdentity;
    if (!google.configured) return;
    _googleTokens = google.idTokens.listen(
      _entrarComTokenGoogle,
      onError: (Object error) {
        if (!mounted || error is GoogleIdentityCanceledException) return;
        _mostrarErro(
          error is GoogleIdentityException
              ? error.message
              : 'Nao foi possivel entrar com o Google.',
        );
      },
    );
    unawaited(_prepararGoogle());
  }

  @override
  void dispose() {
    unawaited(_googleTokens?.cancel());
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _prepararGoogle() async {
    try {
      await AppServices.instance.googleIdentity.initialize();
      if (mounted) setState(() => _googlePronto = true);
    } catch (_) {
      if (mounted) setState(() => _googlePronto = false);
    }
  }

  Future<void> _entrarGoogle() async {
    if (_enviando) return;
    try {
      final idToken = await AppServices.instance.googleIdentity.authenticate();
      await _entrarComTokenGoogle(idToken);
    } on GoogleIdentityCanceledException {
      return;
    } on GoogleIdentityException catch (error) {
      if (mounted) _mostrarErro(error.message);
    }
  }

  Future<void> _entrarComTokenGoogle(String idToken) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      var response = await AppServices.instance.auth.loginGoogle(
        idToken: idToken,
      );
      TipoUsuario? tipoCriado;
      if (response['cadastroNecessario'] == true) {
        if (!mounted) return;
        final perfil = response['perfilGoogle'];
        final escolha = await showDialog<_GoogleCadastroEscolha>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _GoogleCadastroDialog(
            nome: perfil is Map<String, dynamic>
                ? perfil['nome']?.toString() ?? 'Conta Google'
                : 'Conta Google',
            email: perfil is Map<String, dynamic>
                ? perfil['email']?.toString() ?? ''
                : '',
          ),
        );
        if (escolha == null) {
          await AppServices.instance.googleIdentity.signOut();
          return;
        }
        tipoCriado = escolha.tipo;
        response = await AppServices.instance.auth.loginGoogle(
          idToken: idToken,
          tipo: escolha.tipo.valorBanco,
          senha: escolha.senha,
          aceitouTermos: true,
        );
      }
      if (!mounted) return;
      final contaProfissionalCriada =
          response['contaCriada'] == true &&
          tipoCriado != null &&
          tipoCriado != TipoUsuario.cliente;
      Navigator.pushNamedAndRemoveUntil(
        context,
        contaProfissionalCriada
            ? AppRoutes.cadastroProfissional
            : _rotaPosLogin(),
        (_) => false,
      );
    } on MfaRequiredException catch (mfa) {
      if (mounted) await _confirmarMfa(mfa.mfaToken);
    } on ApiException catch (error) {
      if (mounted) _mostrarErro(error.message);
    } catch (_) {
      if (mounted) {
        _mostrarErro('Nao foi possivel entrar com o Google. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await AppServices.instance.auth.login(
        email: _emailController.text,
        senha: _senhaController.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, _rotaPosLogin(), (_) => false);
    } on MfaRequiredException catch (mfa) {
      if (!mounted) return;
      await _confirmarMfa(mfa.mfaToken);
    } on ApiException catch (error) {
      if (!mounted) return;
      _mostrarErro(error.message);
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Não foi possível entrar. Verifique sua conexão.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmarMfa(String mfaToken) async {
    try {
      final codigo = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _MfaCodigoDialog(),
      );
      if (codigo == null || codigo.trim().isEmpty) return;
      await AppServices.instance.auth.confirmarLoginMfa(
        mfaToken: mfaToken,
        codigo: codigo.trim(),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, _rotaPosLogin(), (_) => false);
    } on ApiException catch (error) {
      if (!mounted) return;
      _mostrarErro(error.message);
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Não foi possível validar o código. Tente novamente.');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  String _rotaPosLogin() {
    final auth = AppServices.instance.auth;
    if (!auth.emailVerificado) return AppRoutes.verificacaoEmail;
    final tipo = auth.usuarioAtual?['tipo'];
    return switch (tipo) {
      'profissional' || 'empresa' => AppRoutes.areaProfissional,
      'administrador' => AppRoutes.admin,
      _ => AppRoutes.home,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Entrar'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppInsets.page.copyWith(top: AppSpace.xl),
          children: [
            const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.md,
              runSpacing: AppSpace.sm,
              children: [ConectaLarSymbol(size: 48), ConectaLarWordmark()],
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Acesse sua conta para acompanhar solicitações, conversas e favoritos.',
              style: TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
            const SizedBox(height: AppSpace.xl),
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: AppInsets.card,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('login-email'),
                        enabled: !_enviando,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: validarEmail,
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('login-senha'),
                        enabled: !_enviando,
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: _enviando
                                ? null
                                : () => setState(
                                    () => _ocultarSenha = !_ocultarSenha,
                                  ),
                            icon: Icon(
                              _ocultarSenha
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validarSenha,
                        onFieldSubmitted: _enviando ? null : (_) => _entrar(),
                      ),
                      const SizedBox(height: AppSpace.md),
                      const _AvisoSegurancaAuth(),
                      const SizedBox(height: AppSpace.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('login-entrar'),
                          onPressed: _enviando ? null : _entrar,
                          icon: _enviando
                              ? const ButtonProgressIndicator()
                              : const Icon(Icons.login_rounded),
                          label: ActionLabel(
                            busy: _enviando,
                            text: _enviando ? 'Entrando...' : 'Entrar',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.recuperacaoSenha,
                        ),
                        child: const Text('Esqueci minha senha'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.cadastro),
                        child: const Text('Criar conta'),
                      ),
                      if (_googlePronto) ...[
                        const SizedBox(height: AppSpace.sm),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ou',
                                style: TextStyle(color: AppColors.textoSuave),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpace.md),
                        if (kIsWeb)
                          AbsorbPointer(
                            absorbing: _enviando,
                            child: SizedBox(
                              height: 44,
                              width: double.infinity,
                              child: Center(child: googleWebButton()),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey('login-google'),
                              onPressed: _enviando ? null : _entrarGoogle,
                              icon: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                              label: const Text('Continuar com o Google'),
                            ),
                          ),
                      ],
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

class _GoogleCadastroEscolha {
  const _GoogleCadastroEscolha(this.tipo, this.senha);

  final TipoUsuario tipo;
  final String senha;
}

class _GoogleCadastroDialog extends StatefulWidget {
  const _GoogleCadastroDialog({required this.nome, required this.email});

  final String nome;
  final String email;

  @override
  State<_GoogleCadastroDialog> createState() => _GoogleCadastroDialogState();
}

class _GoogleCadastroDialogState extends State<_GoogleCadastroDialog> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  TipoUsuario _tipo = TipoUsuario.cliente;
  bool _aceitouTermos = false;
  bool _mostrarErro = false;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!_formKey.currentState!.validate() || !_aceitouTermos) {
      setState(() => _mostrarErro = true);
      return;
    }
    Navigator.pop(
      context,
      _GoogleCadastroEscolha(_tipo, _senhaController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Concluir cadastro'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nome,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: const TextStyle(color: AppColors.textoSuave),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                SegmentedButton<TipoUsuario>(
                  key: const ValueKey('google-cadastro-tipo'),
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
                  onSelectionChanged: (value) => setState(() {
                    _tipo = value.first;
                    if (_tipo == TipoUsuario.profissional) {
                      _tipo = TipoUsuario.profissional;
                    }
                  }),
                ),
                if (_tipo != TipoUsuario.cliente) ...[
                  const SizedBox(height: AppSpace.md),
                  DropdownButtonFormField<TipoUsuario>(
                    initialValue: _tipo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de prestador',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TipoUsuario.profissional,
                        child: Text('Autonomo'),
                      ),
                      DropdownMenuItem(
                        value: TipoUsuario.empresa,
                        child: Text('Empresa'),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _tipo = value ?? TipoUsuario.profissional,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                const Text(
                  'Crie uma senha de recuperacao do ConectaLar. Ela nao e a senha da sua conta Google.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  key: const ValueKey('google-cadastro-senha'),
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha do ConectaLar',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: validarSenhaForte,
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  key: const ValueKey('google-cadastro-confirmar-senha'),
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) {
                    final error = validarSenhaForte(value);
                    if (error != null) return error;
                    if (value != _senhaController.text) {
                      return 'As senhas devem ser iguais.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.md),
                CheckboxListTile(
                  key: const ValueKey('google-cadastro-termos'),
                  contentPadding: EdgeInsets.zero,
                  value: _aceitouTermos,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Li e aceito os termos e o aviso de privacidade.',
                  ),
                  subtitle: _mostrarErro && !_aceitouTermos
                      ? const Text('Obrigatorio para continuar.')
                      : null,
                  onChanged: (value) => setState(() {
                    _aceitouTermos = value ?? false;
                    _mostrarErro = false;
                  }),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.termos),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ler termos e aviso de privacidade'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('google-cadastro-continuar'),
          onPressed: _continuar,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _MfaCodigoDialog extends StatefulWidget {
  const _MfaCodigoDialog();

  @override
  State<_MfaCodigoDialog> createState() => _MfaCodigoDialogState();
}

class _MfaCodigoDialogState extends State<_MfaCodigoDialog> {
  final _codigoController = TextEditingController();

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verificação do administrador'),
      content: TextField(
        key: const ValueKey('login-mfa-codigo'),
        controller: _codigoController,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'Código de 6 dígitos',
          helperText: 'Use o app autenticador configurado na conta.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('login-mfa-confirmar'),
          onPressed: () => Navigator.pop(context, _codigoController.text),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _AvisoSegurancaAuth extends StatelessWidget {
  const _AvisoSegurancaAuth();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.verdeEscuro, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Use os dados da sua conta. Nunca compartilhe sua senha ou seus códigos de acesso.',
            style: TextStyle(color: AppColors.textoSuave, height: 1.35),
          ),
        ),
      ],
    );
  }
}
