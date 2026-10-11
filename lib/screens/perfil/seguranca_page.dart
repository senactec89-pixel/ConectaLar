import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';

class SegurancaPage extends StatefulWidget {
  const SegurancaPage({super.key});

  @override
  State<SegurancaPage> createState() => _SegurancaPageState();
}

class _SegurancaPageState extends State<SegurancaPage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtual = TextEditingController();
  final _novaSenha = TextEditingController();
  final _confirmarSenha = TextEditingController();

  bool _ocultarAtual = true;
  bool _ocultarNova = true;
  bool _ocultarConfirmacao = true;
  bool _salvando = false;

  @override
  void dispose() {
    _senhaAtual.dispose();
    _novaSenha.dispose();
    _confirmarSenha.dispose();
    super.dispose();
  }

  Future<void> _alterarSenha() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AppServices.instance.auth.autenticado) {
      _mensagem('Entre na sua conta para alterar a senha.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await AppServices.instance.auth.alterarSenha(
        senhaAtual: _senhaAtual.text,
        novaSenha: _novaSenha.text,
      );
      if (!mounted) return;
      _mensagem('Senha atualizada. Entre novamente com a nova senha.');
      await AppServices.instance.auth.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível atualizar a senha. Tente novamente.');
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
    return Scaffold(
      appBar: const AppBarCustom(title: 'Segurança'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cuide do acesso à sua conta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Atualize sua senha periodicamente e não compartilhe seus dados de acesso.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textoSuave,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _DicaSeguranca(),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Alterar senha',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _CampoSenha(
                                key: const ValueKey('seguranca-senha-atual'),
                                controller: _senhaAtual,
                                label: 'Senha atual',
                                ocultar: _ocultarAtual,
                                onToggle: () => setState(
                                  () => _ocultarAtual = !_ocultarAtual,
                                ),
                                validator: validarSenha,
                              ),
                              const SizedBox(height: 14),
                              _CampoSenha(
                                key: const ValueKey('seguranca-senha-nova'),
                                controller: _novaSenha,
                                label: 'Nova senha',
                                ocultar: _ocultarNova,
                                onToggle: () => setState(
                                  () => _ocultarNova = !_ocultarNova,
                                ),
                                validator: validarSenha,
                              ),
                              const SizedBox(height: 14),
                              _CampoSenha(
                                key: const ValueKey(
                                  'seguranca-confirmar-senha',
                                ),
                                controller: _confirmarSenha,
                                label: 'Confirme a nova senha',
                                ocultar: _ocultarConfirmacao,
                                onToggle: () => setState(
                                  () => _ocultarConfirmacao =
                                      !_ocultarConfirmacao,
                                ),
                                validator: (valor) {
                                  final erro = validarSenha(valor);
                                  if (erro != null) return erro;
                                  if (valor != _novaSenha.text) {
                                    return 'As senhas não coincidem.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                key: const ValueKey('seguranca-salvar'),
                                onPressed: _salvando ? null : _alterarSenha,
                                icon: _salvando
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_reset_rounded),
                                label: Text(
                                  _salvando
                                      ? 'Atualizando...'
                                      : 'Atualizar senha',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.verdeEscuro,
                        ),
                        title: const Text('Esqueceu sua senha?'),
                        subtitle: const Text(
                          'Solicite um código para recuperar o acesso.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.recuperacaoSenha,
                        ),
                      ),
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

class _CampoSenha extends StatelessWidget {
  const _CampoSenha({
    required this.controller,
    required this.label,
    required this.ocultar,
    required this.onToggle,
    required this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool ocultar;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: ocultar,
      validator: validator,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: ocultar ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: onToggle,
          icon: Icon(
            ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _DicaSeguranca extends StatelessWidget {
  const _DicaSeguranca();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.verdeEscuro),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use uma senha exclusiva e difícil de adivinhar. A confirmação da senha atual é necessária para fazer a alteração.',
              style: TextStyle(color: AppColors.texto, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
