import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/session_gate.dart';

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
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;
  bool _mostrarSenha = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) {
      return;
    }
    final services = AppServices.instance;
    if (!services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] != 'administrador') {
      setState(() => _erro = 'Entre com uma conta administrativa autorizada.');
      return;
    }
    if (_formKey.currentState?.validate() != true) {
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
        senha: _senha.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro = switch (error.statusCode) {
          403 => 'Sua conta não tem permissão para criar administradores.',
          409 =>
            'Não foi possível criar a conta com estes dados. Confira o e-mail e o telefone.',
          401 => 'Sua sessão expirou. Entre novamente para continuar.',
          _ => error.message,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível criar a conta. Tente novamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_salvando,
    child: Scaffold(
      appBar: const AppBarCustom(title: 'Nova conta admin'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppInsets.page,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Criar administrador',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Cadastre uma conta individual para uma pessoa autorizada a administrar o ConectaLar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    const Card(
                      child: Padding(
                        padding: AppInsets.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppColors.verde,
                            ),
                            SizedBox(height: AppSpace.sm),
                            Text(
                              'Use um e-mail próprio para cada administrador. A nova conta terá acesso às ferramentas administrativas conforme as permissões da plataforma.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
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
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const ValueKey('admin-criar-email'),
                      controller: _email,
                      enabled: !_salvando,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final error = validarEmail(value);
                        if (error != null) {
                          return error;
                        }
                        return value!.trim().length > 180
                            ? 'Use um e-mail com até 180 caracteres.'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const ValueKey('admin-criar-telefone'),
                      controller: _telefone,
                      enabled: !_salvando,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefone (opcional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        helperText: 'Inclua o DDD.',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().length > 32) {
                          return 'Use até 32 caracteres para o telefone.';
                        }
                        return validarTelefoneOpcional(value);
                      },
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const ValueKey('admin-criar-senha'),
                      controller: _senha,
                      enabled: !_salvando,
                      obscureText: !_mostrarSenha,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _mostrarSenha
                              ? 'Ocultar senha'
                              : 'Mostrar senha',
                          onPressed: _salvando
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
                        helperText:
                            'De 8 a 128 caracteres, com maiúscula, minúscula, número e símbolo.',
                      ),
                      validator: (value) {
                        final error = validarSenhaForte(value);
                        if (error != null) {
                          return error;
                        }
                        if (value!.length > 128) {
                          return 'Use até 128 caracteres.';
                        }
                        if (value != value.trim()) {
                          return 'A senha não pode começar ou terminar com espaços.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const ValueKey('admin-criar-confirmacao'),
                      controller: _confirmacao,
                      enabled: !_salvando,
                      obscureText: !_mostrarSenha,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _salvar(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty || value != _senha.text
                          ? 'As senhas precisam ser iguais.'
                          : null,
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _erro!,
                          key: const ValueKey('admin-criar-erro'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.erro),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.xl),
                    FilledButton.icon(
                      key: const ValueKey('admin-criar-salvar'),
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.person_add_outlined),
                      label: ActionLabel(
                        text: _salvando
                            ? 'Criando conta...'
                            : 'Criar administrador',
                        busy: _salvando,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
