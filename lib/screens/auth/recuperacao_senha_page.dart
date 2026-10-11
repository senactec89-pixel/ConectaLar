import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';

class RecuperacaoSenhaPage extends StatefulWidget {
  const RecuperacaoSenhaPage({super.key});

  @override
  State<RecuperacaoSenhaPage> createState() => _RecuperacaoSenhaPageState();
}

class _RecuperacaoSenhaPageState extends State<RecuperacaoSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _novaSenha = TextEditingController();
  final _confirmacao = TextEditingController();

  bool _solicitado = false;
  bool _concluido = false;
  bool _enviando = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _novaSenha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _solicitarCodigo() async {
    if (!_solicitado && !_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final response = await AppServices.instance.auth
          .solicitarRecuperacaoSenha(email: _email.text.trim());
      final devToken = response['devToken'];
      if (devToken is String) _token.text = devToken;
      if (!mounted) return;
      setState(() => _solicitado = true);
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível solicitar o código. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await AppServices.instance.auth.confirmarRecuperacaoSenha(
        token: _token.text.trim(),
        novaSenha: _novaSenha.text,
      );
      if (mounted) setState(() => _concluido = true);
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível redefinir a senha. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
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
      appBar: const AppBarCustom(title: 'Recuperar acesso'),
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _concluido
                    ? _SucessoRecuperacao(
                        onEntrar: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        ),
                      )
                    : _solicitado
                    ? _FormularioCodigo(
                        formKey: _formKey,
                        token: _token,
                        novaSenha: _novaSenha,
                        confirmacao: _confirmacao,
                        ocultarSenha: _ocultarSenha,
                        enviando: _enviando,
                        onToggleSenha: () =>
                            setState(() => _ocultarSenha = !_ocultarSenha),
                        onConfirmar: _confirmar,
                        onReenviar: _solicitarCodigo,
                        tokenDemonstracao: _token.text.isNotEmpty,
                      )
                    : _FormularioEmail(
                        formKey: _formKey,
                        email: _email,
                        enviando: _enviando,
                        onSolicitar: _solicitarCodigo,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioEmail extends StatelessWidget {
  const _FormularioEmail({
    required this.formKey,
    required this.email,
    required this.enviando,
    required this.onSolicitar,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final bool enviando;
  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CabecalhoRecuperacao(
            icone: Icons.mark_email_read_outlined,
            titulo: 'Vamos recuperar sua conta',
            descricao:
                'Informe o e-mail cadastrado. Se a conta estiver ativa, enviaremos as instruções para redefinir sua senha.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('recuperacao-email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: validarEmail,
                    onFieldSubmitted: (_) => onSolicitar(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('recuperacao-solicitar'),
                      onPressed: enviando ? null : onSolicitar,
                      icon: enviando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        enviando ? 'Solicitando...' : 'Enviar instruções',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioCodigo extends StatelessWidget {
  const _FormularioCodigo({
    required this.formKey,
    required this.token,
    required this.novaSenha,
    required this.confirmacao,
    required this.ocultarSenha,
    required this.enviando,
    required this.onToggleSenha,
    required this.onConfirmar,
    required this.onReenviar,
    required this.tokenDemonstracao,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController token;
  final TextEditingController novaSenha;
  final TextEditingController confirmacao;
  final bool ocultarSenha;
  final bool enviando;
  final VoidCallback onToggleSenha;
  final VoidCallback onConfirmar;
  final VoidCallback onReenviar;
  final bool tokenDemonstracao;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CabecalhoRecuperacao(
            icone: Icons.password_rounded,
            titulo: 'Defina uma nova senha',
            descricao:
                'Digite o código recebido e escolha uma senha com pelo menos 8 caracteres.',
          ),
          const SizedBox(height: 20),
          if (tokenDemonstracao) ...[
            const _AvisoTokenDemonstracao(),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('recuperacao-token'),
                    controller: token,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Código de recuperação',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    validator: validarCampoObrigatorio,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('recuperacao-nova-senha'),
                    controller: novaSenha,
                    obscureText: ocultarSenha,
                    validator: validarSenha,
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: ocultarSenha
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: onToggleSenha,
                        icon: Icon(
                          ocultarSenha
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('recuperacao-confirmacao'),
                    obscureText: ocultarSenha,
                    controller: confirmacao,
                    validator: (valor) {
                      final erro = validarSenha(valor);
                      if (erro != null) return erro;
                      if (valor != novaSenha.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Confirme a nova senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('recuperacao-confirmar'),
                      onPressed: enviando ? null : onConfirmar,
                      icon: enviando
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(enviando ? 'Salvando...' : 'Redefinir senha'),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: enviando ? null : onReenviar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Solicitar outro código'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoRecuperacao extends StatelessWidget {
  const _CabecalhoRecuperacao({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.verdeClaro,
            shape: BoxShape.circle,
          ),
          child: Icon(icone, color: AppColors.verdeEscuro, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textoSuave),
        ),
      ],
    );
  }
}

class _AvisoTokenDemonstracao extends StatelessWidget {
  const _AvisoTokenDemonstracao();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DF),
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF805B00)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Código de demonstração preenchido para este ambiente local.',
              style: TextStyle(height: 1.35, color: Color(0xFF553D00)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SucessoRecuperacao extends StatelessWidget {
  const _SucessoRecuperacao({required this.onEntrar});

  final VoidCallback onEntrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.verde,
          size: 72,
        ),
        const SizedBox(height: 18),
        Text(
          'Senha redefinida',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Agora você pode entrar usando sua nova senha.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onEntrar,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Voltar para entrar'),
          ),
        ),
      ],
    );
  }
}
