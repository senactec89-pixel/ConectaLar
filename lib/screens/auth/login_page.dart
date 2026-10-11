import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'mariana@email.com');
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
      final tipo = AppServices.instance.auth.usuarioAtual?['tipo'];
      final rota = switch (tipo) {
        'profissional' || 'empresa' => AppRoutes.areaProfissional,
        'administrador' => AppRoutes.admin,
        _ => AppRoutes.home,
      };
      Navigator.pushNamedAndRemoveUntil(context, rota, (_) => false);
    } on ApiException catch (error) {
      if (!mounted) return;
      _mostrarErro(error.message);
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Nao foi possivel entrar. Verifique sua conexao.');
    } finally {
      if (mounted) setState(() => _enviando = false);
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
      appBar: const AppBarCustom(title: 'Entrar'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'ConectaLar',
              style: TextStyle(
                color: AppColors.verdeEscuro,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Acesse sua conta para acompanhar solicitações, conversas e favoritos.',
              style: TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('login-email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: validarEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('login-senha'),
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: () =>
                                setState(() => _ocultarSenha = !_ocultarSenha),
                            icon: Icon(
                              _ocultarSenha
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: validarSenha,
                        onFieldSubmitted: (_) => _entrar(),
                      ),
                      const SizedBox(height: 12),
                      const _AvisoSegurancaAuth(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('login-entrar'),
                          onPressed: _enviando ? null : _entrar,
                          icon: _enviando
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_enviando ? 'Entrando...' : 'Entrar'),
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
            'Sua senha e sessao sao validadas pela API do ConectaLar. Nunca compartilhe seus dados de acesso.',
            style: TextStyle(color: AppColors.textoSuave, height: 1.35),
          ),
        ),
      ],
    );
  }
}
