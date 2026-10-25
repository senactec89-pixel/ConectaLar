import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';

class VerificacaoEmailPage extends StatefulWidget {
  const VerificacaoEmailPage({super.key});

  @override
  State<VerificacaoEmailPage> createState() => _VerificacaoEmailPageState();
}

class _VerificacaoEmailPageState extends State<VerificacaoEmailPage> {
  final _codigoController = TextEditingController();
  bool _confirmando = false;
  bool _reenviando = false;
  String? _mensagem;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final codigo = _codigoController.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(
        () => _mensagem = 'Digite o código de 6 dígitos enviado por e-mail.',
      );
      return;
    }

    setState(() {
      _confirmando = true;
      _mensagem = null;
    });
    try {
      await AppServices.instance.auth.confirmarVerificacaoEmail(codigo: codigo);
      if (!mounted) return;
      if (AppServices.instance.auth.usuarioAtual?['tipo'] == 'administrador') {
        await AppServices.instance.auth.logout();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'E-mail confirmado. Entre novamente para configurar o autenticador administrativo.',
            ),
          ),
        );
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        _rotaPosVerificacao(),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _mensagem = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _mensagem =
            'Não foi possível confirmar o código. Verifique sua conexão.',
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() {
      _reenviando = true;
      _mensagem = null;
    });
    try {
      await AppServices.instance.auth.solicitarVerificacaoEmail();
      if (!mounted) return;
      setState(
        () => _mensagem =
            'Enviamos um novo código. Confira sua caixa de entrada e spam.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _mensagem = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _mensagem =
            'Não foi possível reenviar agora. Verifique sua conexão.',
      );
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  String _rotaPosVerificacao() {
    final tipo = AppServices.instance.auth.usuarioAtual?['tipo'];
    return switch (tipo) {
      'profissional' || 'empresa' => AppRoutes.cadastroProfissional,
      'administrador' => AppRoutes.admin,
      _ => AppRoutes.home,
    };
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AppServices.instance.auth.usuarioAtual;
    final email = usuario?['email'] is String
        ? usuario!['email'] as String
        : '';
    final ocupado = _confirmando || _reenviando;

    return Scaffold(
      appBar: const AppBarCustom(title: 'Confirmar e-mail'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppInsets.page.copyWith(top: AppSpace.xl),
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.verdeEscuro,
              size: 48,
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'Verifique sua caixa de entrada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              email.isEmpty
                  ? 'Digite o código de 6 dígitos que enviamos para sua conta.'
                  : 'Digite o código de 6 dígitos enviado para $email.',
              style: const TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
            const SizedBox(height: AppSpace.lg),
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('email-verificacao-codigo'),
                      enabled: !ocupado,
                      controller: _codigoController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Código de verificação',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      onSubmitted: ocupado ? null : (_) => _confirmar(),
                    ),
                    if (_mensagem != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        _mensagem!,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    FilledButton.icon(
                      key: const ValueKey('email-verificacao-confirmar'),
                      onPressed: ocupado ? null : _confirmar,
                      icon: _confirmando
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.verified_user_outlined),
                      label: ActionLabel(
                        busy: _confirmando,
                        text: _confirmando ? 'Confirmando...' : 'Confirmar',
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('email-verificacao-reenviar'),
                      onPressed: ocupado ? null : _reenviar,
                      icon: _reenviando
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.refresh_outlined),
                      label: ActionLabel(
                        busy: _reenviando,
                        text: _reenviando ? 'Enviando...' : 'Reenviar código',
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('email-verificacao-privacidade'),
                      onPressed: ocupado
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              AppRoutes.seguranca,
                            ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Seguranca e privacidade da conta'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
