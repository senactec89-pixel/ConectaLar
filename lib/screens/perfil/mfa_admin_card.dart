import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/action_label.dart';

/// Configuração do autenticador disponível somente para a conta administrativa.
class MfaAdminCard extends StatefulWidget {
  const MfaAdminCard({super.key});

  @override
  State<MfaAdminCard> createState() => _MfaAdminCardState();
}

class _MfaAdminCardState extends State<MfaAdminCard> {
  final _codigo = TextEditingController();
  final _senhaAtual = TextEditingController();

  bool _carregando = true;
  bool _ocupado = false;
  bool _ativo = false;
  bool _desativando = false;
  bool _ocultarSenha = true;
  String? _segredo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (AppServices.instance.modoDemo) {
      _carregando = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _carregar();
      });
    }
  }

  @override
  void dispose() {
    _codigo.dispose();
    _senhaAtual.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_ocupado) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final response = await AppServices.instance.auth.statusMfaAdmin();
      final ativo = response['mfaAtivo'];
      if (ativo is! bool) throw const FormatException('Status MFA inválido.');
      if (!mounted) return;
      setState(() {
        _ativo = ativo;
        _segredo = null;
        _desativando = false;
        _codigo.clear();
        _senhaAtual.clear();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível consultar o autenticador.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _iniciar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final response = await AppServices.instance.auth.iniciarMfaAdmin();
      final segredo = response['secret'];
      if (segredo is! String || segredo.trim().isEmpty) {
        throw const FormatException('Chave MFA inválida.');
      }
      if (!mounted) return;
      setState(() {
        _segredo = segredo.trim();
        _codigo.clear();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível iniciar a configuração.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmar() async {
    if (_ocupado || _segredo == null) return;
    if (!_codigoValido) {
      setState(() => _erro = 'Digite os seis números do autenticador.');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await AppServices.instance.auth.confirmarMfaAdmin(codigo: _codigo.text);
      await _voltarAoLogin(
        'Autenticador ativado. Entre novamente com seu código.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível ativar. Confira o código.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _desativar() async {
    if (_ocupado) return;
    if (_senhaAtual.text.isEmpty || !_codigoValido) {
      setState(
        () => _erro = 'Informe a senha atual e o código de seis números.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await AppServices.instance.auth.desativarMfaAdmin(
        senhaAtual: _senhaAtual.text,
        codigo: _codigo.text,
      );
      await _voltarAoLogin('Autenticador desativado. Entre novamente.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível desativar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _voltarAoLogin(String mensagem) async {
    // Ativar e desativar incrementam tokenVersion na API. O token atual não serve
    // mais; removê-lo localmente evita deixar uma sessão visualmente aberta.
    await AppServices.instance.auth.encerrarSessaoAposMfa();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    messenger.showSnackBar(SnackBar(content: Text(mensagem)));
  }

  bool get _codigoValido => RegExp(r'^\d{6}$').hasMatch(_codigo.text);

  @override
  Widget build(BuildContext context) {
    final demo = AppServices.instance.modoDemo;
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.phonelink_lock_outlined,
                  color: AppColors.verdeEscuro,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Autenticador administrativo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Adicione uma segunda etapa de proteção à sua conta administrativa.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.md),
            if (demo)
              const Text(
                'Entre com uma conta administrativa na API para configurar o autenticador. A prévia não altera a segurança da conta.',
              )
            else if (_carregando)
              const Row(
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpace.md),
                  Expanded(child: Text('Consultando o autenticador...')),
                ],
              )
            else ...[
              if (_erro != null) ...[
                Text(
                  _erro!,
                  key: const ValueKey('mfa-admin-erro'),
                  style: const TextStyle(color: AppColors.erro),
                ),
                const SizedBox(height: AppSpace.md),
              ],
              if (!_ativo && _segredo == null && _erro != null)
                OutlinedButton.icon(
                  key: const ValueKey('mfa-admin-tentar-novamente'),
                  onPressed: _ocupado ? null : _carregar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                )
              else if (_ativo)
                _conteudoAtivo(context)
              else
                _conteudoInativo(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _conteudoInativo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Situação: desativado'),
        const SizedBox(height: AppSpace.md),
        if (_segredo == null)
          FilledButton.icon(
            key: const ValueKey('mfa-admin-iniciar'),
            onPressed: _ocupado ? null : _iniciar,
            icon: _ocupado
                ? const ButtonProgressIndicator()
                : const Icon(Icons.add_moderator_outlined),
            label: ActionLabel(
              busy: _ocupado,
              text: _ocupado ? 'Preparando...' : 'Configurar autenticador',
            ),
          )
        else ...[
          const Text(
            'No aplicativo autenticador, adicione uma conta manualmente e informe esta chave. Escolha código baseado em tempo (TOTP). Não compartilhe a chave.',
          ),
          const SizedBox(height: AppSpace.md),
          SelectableText(
            _segredo!,
            key: const ValueKey('mfa-admin-segredo'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('mfa-admin-copiar'),
              onPressed: _ocupado
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _segredo!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chave copiada.')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar chave'),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _campoCodigo(),
          const SizedBox(height: AppSpace.md),
          FilledButton.icon(
            key: const ValueKey('mfa-admin-confirmar'),
            onPressed: _ocupado ? null : _confirmar,
            icon: _ocupado
                ? const ButtonProgressIndicator()
                : const Icon(Icons.verified_user_outlined),
            label: ActionLabel(
              busy: _ocupado,
              text: _ocupado ? 'Ativando...' : 'Ativar autenticador',
            ),
          ),
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() {
                    _segredo = null;
                    _codigo.clear();
                    _erro = null;
                  }),
            child: const Text('Fechar configuração'),
          ),
          const Text('Após ativar, você precisará entrar novamente.'),
        ],
      ],
    );
  }

  Widget _conteudoAtivo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Situação: ativado'),
        const SizedBox(height: AppSpace.sm),
        const Text('O login administrativo pede um código do autenticador.'),
        const SizedBox(height: AppSpace.md),
        if (!_desativando)
          OutlinedButton.icon(
            key: const ValueKey('mfa-admin-desativar-abrir'),
            onPressed: _ocupado
                ? null
                : () => setState(() {
                    _desativando = true;
                    _erro = null;
                  }),
            icon: const Icon(Icons.phonelink_erase_outlined),
            label: const Text('Desativar autenticador'),
          )
        else ...[
          const Text(
            'Confirme sua senha e um código atual. Ao desativar, sua conta terá menos proteção e você precisará entrar novamente.',
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            key: const ValueKey('mfa-admin-senha'),
            controller: _senhaAtual,
            obscureText: _ocultarSenha,
            enabled: !_ocupado,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Senha atual',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                icon: Icon(
                  _ocultarSenha
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _campoCodigo(),
          const SizedBox(height: AppSpace.md),
          FilledButton.icon(
            key: const ValueKey('mfa-admin-desativar'),
            onPressed: _ocupado ? null : _desativar,
            icon: _ocupado
                ? const ButtonProgressIndicator()
                : const Icon(Icons.lock_open_outlined),
            label: ActionLabel(
              busy: _ocupado,
              text: _ocupado ? 'Desativando...' : 'Confirmar desativação',
            ),
          ),
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() {
                    _desativando = false;
                    _senhaAtual.clear();
                    _codigo.clear();
                    _erro = null;
                  }),
            child: const Text('Cancelar'),
          ),
        ],
      ],
    );
  }

  Widget _campoCodigo() => TextField(
    key: const ValueKey('mfa-admin-codigo'),
    controller: _codigo,
    enabled: !_ocupado,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: const InputDecoration(
      labelText: 'Código de seis números',
      prefixIcon: Icon(Icons.pin_outlined),
    ),
  );
}
