import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';
import 'mfa_admin_setup_page.dart';

class AdminInvitePage extends StatefulWidget {
  const AdminInvitePage({super.key});

  @override
  State<AdminInvitePage> createState() => _AdminInvitePageState();
}

class _AdminInvitePageState extends State<AdminInvitePage> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _aceitouTermos = false;
  bool _ocupado = false;
  bool _mostrarSenha = false;
  String? _erro;

  @override
  void dispose() {
    _token.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _aceitar() async {
    if (_ocupado || !_formKey.currentState!.validate()) return;
    if (!_aceitouTermos) {
      setState(() => _erro = 'Leia e aceite os termos para continuar.');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final atuais = await AppServices.instance.termos.atuais();
      final termos = atuais['termos'];
      final versao = termos is Map<String, dynamic>
          ? termos['versao']?.toString().trim()
          : null;
      if (versao == null || versao.isEmpty) {
        throw const ApiException('Nao foi possivel validar os termos atuais.');
      }
      final response = await AppServices.instance.auth.aceitarConviteAdmin(
        token: _token.text.replaceAll(RegExp(r'\s'), ''),
        senha: _senha.text,
        versaoTermos: versao,
      );
      final setupToken = response['mfaSetupToken'];
      if (setupToken is! String || setupToken.isEmpty) {
        throw const ApiException('O convite nao pode ser concluido agora.');
      }
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MfaAdminSetupPage(setupToken: setupToken),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Nao foi possivel aceitar o convite.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Convite administrativo'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: AppInsets.page,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Aceitar convite',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'O convite e individual e expira em 24 horas. Defina sua senha e configure um autenticador antes de acessar as ferramentas administrativas.',
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const ValueKey('admin-convite-token'),
                      controller: _token,
                      enabled: !_ocupado,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Codigo do convite',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) =>
                          (value ?? '').replaceAll(RegExp(r'\s'), '').length !=
                              43
                          ? 'Informe o codigo completo recebido no e-mail.'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      key: const ValueKey('admin-convite-senha'),
                      controller: _senha,
                      enabled: !_ocupado,
                      obscureText: !_mostrarSenha,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Crie sua senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _mostrarSenha
                              ? 'Ocultar senha'
                              : 'Mostrar senha',
                          onPressed: _ocupado
                              ? null
                              : () => setState(
                                  () => _mostrarSenha = !_mostrarSenha,
                                ),
                          icon: Icon(
                            _mostrarSenha
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: validarSenhaForte,
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      key: const ValueKey('admin-convite-confirmacao'),
                      controller: _confirmacao,
                      enabled: !_ocupado,
                      obscureText: !_mostrarSenha,
                      decoration: const InputDecoration(
                        labelText: 'Confirme a senha',
                      ),
                      validator: (value) => value != _senha.text
                          ? 'As senhas precisam ser iguais.'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.md),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _aceitouTermos,
                      title: const Text(
                        'Li e aceito os termos e o aviso de privacidade.',
                      ),
                      onChanged: _ocupado
                          ? null
                          : (value) => setState(() {
                              _aceitouTermos = value ?? false;
                              _erro = null;
                            }),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _ocupado
                            ? null
                            : () => Navigator.pushNamed(
                                context,
                                AppRoutes.termos,
                              ),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Ler termos e aviso de privacidade'),
                      ),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        _erro!,
                        style: const TextStyle(color: AppColors.erro),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _aceitar,
                      icon: _ocupado
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.verified_user_outlined),
                      label: ActionLabel(
                        text: _ocupado
                            ? 'Validando convite...'
                            : 'Aceitar e configurar MFA',
                        busy: _ocupado,
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
