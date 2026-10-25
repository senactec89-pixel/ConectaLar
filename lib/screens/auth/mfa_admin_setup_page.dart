import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/action_label.dart';
import '../../widgets/app_bar_custom.dart';

class MfaAdminSetupPage extends StatefulWidget {
  const MfaAdminSetupPage({required this.setupToken, super.key});

  final String setupToken;

  @override
  State<MfaAdminSetupPage> createState() => _MfaAdminSetupPageState();
}

class _MfaAdminSetupPageState extends State<MfaAdminSetupPage> {
  final _codigo = TextEditingController();
  String? _secret;
  String? _erro;
  bool _carregando = true;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
        _secret = null;
      });
    }
    try {
      final response = await AppServices.instance.auth
          .iniciarConfiguracaoMfaAdmin(setupToken: widget.setupToken);
      final secret = response['secret'];
      if (secret is! String || secret.isEmpty) {
        throw const FormatException('Chave de configuração inválida.');
      }
      if (mounted) setState(() => _secret = secret);
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível iniciar a configuração.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _confirmar() async {
    if (_confirmando) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_codigo.text)) {
      setState(() => _erro = 'Informe o código atual de seis dígitos.');
      return;
    }
    setState(() {
      _confirmando = true;
      _erro = null;
    });
    try {
      await AppServices.instance.auth.confirmarConfiguracaoMfaAdmin(
        setupToken: widget.setupToken,
        codigo: _codigo.text,
      );
      if (!mounted) return;
      final rota = AppServices.instance.auth.termosAceitos
          ? AppRoutes.admin
          : AppRoutes.aceiteTermos;
      Navigator.pushNamedAndRemoveUntil(context, rota, (_) => false);
    } on ApiException catch (error) {
      if (mounted) setState(() => _erro = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = 'Não foi possível validar o código. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Proteger conta administrativa'),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: AppInsets.page,
        children: [
          Text(
            'Configurar autenticador',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'A conta administrativa só será liberada depois que você confirmar o código do aplicativo autenticador.',
          ),
          const SizedBox(height: AppSpace.lg),
          if (_carregando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_erro != null && _secret == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_erro!, style: const TextStyle(color: AppColors.erro)),
                const SizedBox(height: AppSpace.md),
                OutlinedButton.icon(
                  onPressed: _iniciar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            )
          else if (_secret != null) ...[
            const Card(
              child: Padding(
                padding: AppInsets.card,
                child: Text(
                  'Abra o Google Authenticator, Microsoft Authenticator ou outro app TOTP e adicione uma conta usando a chave abaixo. Não compartilhe nem salve a chave em locais públicos.',
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SelectableText(
              _secret!,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _secret!));
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
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Código do autenticador',
                prefixIcon: Icon(Icons.password_outlined),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(_erro!, style: const TextStyle(color: AppColors.erro)),
            ],
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: _confirmando ? null : _confirmar,
              icon: _confirmando
                  ? const ButtonProgressIndicator()
                  : const Icon(Icons.verified_user_outlined),
              label: ActionLabel(
                text: _confirmando ? 'Confirmando...' : 'Confirmar e entrar',
                busy: _confirmando,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
