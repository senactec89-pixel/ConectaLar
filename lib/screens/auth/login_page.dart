import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
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
            const Text(
              'ConectaLar',
              style: TextStyle(
                color: AppColors.verdeEscuro,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
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
