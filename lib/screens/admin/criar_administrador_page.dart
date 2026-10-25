import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/session_gate.dart';
import '../../widgets/unsaved_form_guard.dart';

class CriarAdministradorPage extends StatelessWidget {
  const CriarAdministradorPage({super.key});

  @override
  Widget build(BuildContext context) => SessionGate(
    papeis: const {'administrador'},
    builder: (_) => const _FormularioAdministrador(),
  );
}

class _FormularioAdministrador extends StatefulWidget {
  const _FormularioAdministrador();

  @override
  State<_FormularioAdministrador> createState() =>
      _FormularioAdministradorState();
}

class _FormularioAdministradorState extends State<_FormularioAdministrador> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _enviarConvite() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    final services = AppServices.instance;
    if (!services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] != 'administrador') {
      setState(() => _erro = 'Entre com uma conta administrativa autorizada.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await services.admin.criarAdministrador(
        nome: _nome.text.trim(),
        email: _email.text.trim(),
        telefone: _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = switch (error.statusCode) {
          403 => 'Sua conta nao tem permissao para convidar administradores.',
          409 => 'Nao foi possivel criar o convite. Confira e-mail e telefone.',
          503 =>
            'O envio de e-mail esta indisponivel. Nenhum convite foi criado.',
          401 => 'Sua sessao expirou. Entre novamente para continuar.',
          _ => error.message,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _erro = 'Nao foi possivel enviar o convite.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedFormGuard(
    controllers: [_nome, _email, _telefone],
    initialValues: const ['', '', ''],
    busy: _salvando,
    child: Scaffold(
      appBar: const AppBarCustom(title: 'Convidar administrador'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppInsets.page,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enviar convite administrativo',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      const Text(
                        'A pessoa convidada definira a propria senha, confirmara o e-mail e configurara um autenticador antes de receber acesso administrativo.',
                      ),
                      const SizedBox(height: AppSpace.lg),
                      const Card(
                        child: Padding(
                          padding: AppInsets.card,
                          child: Text(
                            'O convite e individual, vale por 24 horas e so pode ser usado uma vez. O codigo nao e mostrado nesta tela; sera enviado ao e-mail informado.',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        key: const ValueKey('admin-criar-nome'),
                        controller: _nome,
                        enabled: !_salvando,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          final name = (value ?? '').trim();
                          return name.length < 3 || name.length > 140
                              ? 'Informe um nome entre 3 e 140 caracteres.'
                              : null;
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('admin-criar-email'),
                        controller: _email,
                        enabled: !_salvando,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail do convidado',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final error = validarEmail(value);
                          if (error != null) return error;
                          return value!.trim().length > 180
                              ? 'Use um e-mail com ate 180 caracteres.'
                              : null;
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        key: const ValueKey('admin-criar-telefone'),
                        controller: _telefone,
                        enabled: !_salvando,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _enviarConvite(),
                        decoration: const InputDecoration(
                          labelText: 'Telefone (opcional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                          helperText: 'Inclua o DDD.',
                        ),
                        validator: (value) => (value ?? '').trim().length > 32
                            ? 'Use ate 32 caracteres.'
                            : validarTelefoneOpcional(value),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: AppSpace.md),
                        Text(
                          _erro!,
                          key: const ValueKey('admin-criar-erro'),
                          style: const TextStyle(color: AppColors.erro),
                        ),
                      ],
                      const SizedBox(height: AppSpace.lg),
                      FilledButton.icon(
                        key: const ValueKey('admin-criar-salvar'),
                        onPressed: _salvando ? null : _enviarConvite,
                        icon: _salvando
                            ? const ButtonProgressIndicator()
                            : const Icon(Icons.mail_lock_outlined),
                        label: ActionLabel(
                          text: _salvando
                              ? 'Enviando convite...'
                              : 'Enviar convite',
                          busy: _salvando,
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
    ),
  );
}
