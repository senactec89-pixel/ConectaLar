import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import 'mfa_admin_card.dart';

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
  bool _exportando = false;
  bool _excluindo = false;

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

  Future<void> _exportarDados() async {
    if (_exportando || _excluindo) return;
    final senha = await showDialog<String>(
      context: context,
      builder: (_) => const _SenhaAtualDialog(),
    );
    if (senha == null || !mounted) return;

    setState(() => _exportando = true);
    try {
      final response = await AppServices.instance.auth.exportarDados(
        senhaAtual: senha,
      );
      final nome = response['nomeArquivo'];
      final dados = response['dados'];
      if (nome is! String || dados is! Map<String, dynamic>) {
        throw const FormatException('Exportação inválida.');
      }
      final conteudo = const JsonEncoder.withIndent('  ').convert(dados);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(conteudo)),
              name: nome,
              mimeType: 'application/json',
            ),
          ],
          subject: 'Meus dados do ConectaLar',
          text: 'Exportação dos meus dados pessoais no ConectaLar.',
          downloadFallbackEnabled: true,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted) {
        _mensagem('Exportação gerada. Escolha onde guardar o arquivo.');
      }
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível exportar seus dados. Tente novamente.');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _excluirConta() async {
    if (_exportando || _excluindo) return;
    final credenciais = await showDialog<_CredenciaisExclusao>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ExclusaoContaDialog(),
    );
    if (credenciais == null || !mounted) return;

    setState(() => _excluindo = true);
    try {
      await AppServices.instance.auth.excluirConta(
        senhaAtual: credenciais.senhaAtual,
        confirmacao: credenciais.confirmacao,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } on ApiException catch (error) {
      _mensagem(error.message);
    } catch (_) {
      _mensagem('Não foi possível excluir a conta. Tente novamente.');
    } finally {
      if (mounted) setState(() => _excluindo = false);
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
          padding: AppInsets.page,
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
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Atualize sua senha periodicamente e não compartilhe seus dados de acesso.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textoSuave,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    const _DicaSeguranca(),
                    const SizedBox(height: AppSpace.lg),
                    Card(
                      child: Padding(
                        padding: AppInsets.card,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Alterar senha',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpace.lg),
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
                              const SizedBox(height: AppSpace.md),
                              _CampoSenha(
                                key: const ValueKey('seguranca-senha-nova'),
                                controller: _novaSenha,
                                label: 'Nova senha',
                                ocultar: _ocultarNova,
                                onToggle: () => setState(
                                  () => _ocultarNova = !_ocultarNova,
                                ),
                                validator: validarSenhaForte,
                              ),
                              const SizedBox(height: AppSpace.md),
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
                                  final erro = validarSenhaForte(valor);
                                  if (erro != null) return erro;
                                  if (valor != _novaSenha.text) {
                                    return 'As senhas não coincidem.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpace.lg),
                              FilledButton.icon(
                                key: const ValueKey('seguranca-salvar'),
                                onPressed: _salvando ? null : _alterarSenha,
                                icon: _salvando
                                    ? const ButtonProgressIndicator()
                                    : const Icon(Icons.lock_reset_rounded),
                                label: ActionLabel(
                                  busy: _salvando,
                                  text: _salvando
                                      ? 'Atualizando...'
                                      : 'Atualizar senha',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
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
                    if (AppServices.instance.auth.usuarioAtual?['tipo'] ==
                        'administrador') ...[
                      const SizedBox(height: AppSpace.md),
                      const MfaAdminCard(),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Privacidade e seus dados',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Pela LGPD, você pode receber uma cópia dos dados ligados à sua conta ou solicitar a exclusão.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textoSuave,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            key: const ValueKey('seguranca-exportar-dados'),
                            leading: const Icon(
                              Icons.download_outlined,
                              color: AppColors.verdeEscuro,
                            ),
                            title: const Text('Exportar meus dados'),
                            subtitle: const Text(
                              'Gera um arquivo JSON. Senhas e segredos de acesso nunca são incluídos.',
                            ),
                            trailing: _exportando
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: _exportando || _excluindo
                                ? null
                                : _exportarDados,
                          ),
                          const Divider(height: 1),
                          if (AppServices.instance.auth.usuarioAtual?['tipo'] ==
                              'administrador')
                            const ListTile(
                              leading: Icon(
                                Icons.admin_panel_settings_outlined,
                                color: AppColors.textoSuave,
                              ),
                              title: Text('Conta administrativa'),
                              subtitle: Text(
                                'Para preservar a auditoria, outro administrador deve desativar esta conta.',
                              ),
                            )
                          else
                            ListTile(
                              key: const ValueKey('seguranca-excluir-conta'),
                              leading: const Icon(
                                Icons.delete_forever_outlined,
                                color: AppColors.erro,
                              ),
                              title: const Text(
                                'Excluir minha conta',
                                style: TextStyle(color: AppColors.erro),
                              ),
                              subtitle: const Text(
                                'Remove seus dados pessoais e encerra todas as sessões. Atendimentos em aberto precisam ser finalizados antes.',
                              ),
                              trailing: _excluindo
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _exportando || _excluindo
                                  ? null
                                  : _excluirConta,
                            ),
                        ],
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

class _SenhaAtualDialog extends StatefulWidget {
  const _SenhaAtualDialog();

  @override
  State<_SenhaAtualDialog> createState() => _SenhaAtualDialogState();
}

class _SenhaAtualDialogState extends State<_SenhaAtualDialog> {
  final _senha = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar exportação'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirme sua senha atual. O arquivo pode conter informações sensíveis e deve ser guardado com cuidado.',
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            key: const ValueKey('exportacao-senha-atual'),
            controller: _senha,
            obscureText: _ocultar,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Senha atual',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _ocultar = !_ocultar),
                icon: Icon(
                  _ocultar
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onSubmitted: _senha.text.length >= 8
                ? (_) => Navigator.pop(context, _senha.text)
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _senha.text.length < 8
              ? null
              : () => Navigator.pop(context, _senha.text),
          child: const Text('Gerar arquivo'),
        ),
      ],
    );
  }
}

class _CredenciaisExclusao {
  const _CredenciaisExclusao(this.senhaAtual, this.confirmacao);

  final String senhaAtual;
  final String confirmacao;
}

class _ExclusaoContaDialog extends StatefulWidget {
  const _ExclusaoContaDialog();

  @override
  State<_ExclusaoContaDialog> createState() => _ExclusaoContaDialogState();
}

class _ExclusaoContaDialogState extends State<_ExclusaoContaDialog> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _ocultar = true;

  bool get _podeExcluir =>
      _senha.text.length >= 8 && _confirmacao.text.trim() == 'EXCLUIR';

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.erro,
        size: 36,
      ),
      title: const Text('Excluir conta permanentemente?'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Seu acesso, perfil, contatos, endereços, foto e documentos serão removidos. Registros mínimos de atendimentos e moderação podem ser mantidos anonimizados para segurança e obrigações legais.',
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Antes de continuar, exporte seus dados se quiser guardar uma cópia. Esta ação não pode ser desfeita.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            key: const ValueKey('exclusao-senha-atual'),
            controller: _senha,
            obscureText: _ocultar,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Senha atual',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _ocultar = !_ocultar),
                icon: Icon(
                  _ocultar
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            key: const ValueKey('exclusao-confirmacao'),
            controller: _confirmacao,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Digite EXCLUIR',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Manter minha conta'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.erro),
          onPressed: !_podeExcluir
              ? null
              : () => Navigator.pop(
                  context,
                  _CredenciaisExclusao(_senha.text, _confirmacao.text.trim()),
                ),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Excluir definitivamente'),
        ),
      ],
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
