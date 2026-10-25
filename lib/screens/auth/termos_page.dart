import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class TermosPage extends StatefulWidget {
  const TermosPage({
    this.apenasPoliticaComercial = false,
    this.exigirAceite = false,
    super.key,
  });

  final bool apenasPoliticaComercial;
  final bool exigirAceite;

  @override
  State<TermosPage> createState() => _TermosPageState();
}

class _TermosPageState extends State<TermosPage> {
  late Future<Map<String, dynamic>> _future;
  bool _aceitando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _future = _carregarDados();
    _future.ignore();
  }

  Future<Map<String, dynamic>> _carregarDados() async {
    final services = AppServices.instance;
    final atuais = await services.termos.atuais();
    if (!widget.exigirAceite || !services.auth.autenticado) return atuais;
    final status = await services.termos.meusAceites();
    final aceitou = status['aceitouVersaoAtual'] == true;
    final versao = status['versaoAtual'];
    if (aceitou && versao is String) {
      await services.auth.registrarTermosAceitos(versao);
    }
    return {...atuais, 'aceitouVersaoAtual': aceitou};
  }

  Future<void> _aceitar(Map<String, dynamic> termos) async {
    if (_aceitando) return;
    if (!AppServices.instance.auth.autenticado) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }
    final versao = termos['versao'];
    if (versao is! String || versao.trim().isEmpty) return;
    setState(() => _aceitando = true);
    try {
      final services = AppServices.instance;
      await services.termos.aceitar(versao);
      await services.auth.registrarTermosAceitos(versao);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, _rotaDaConta(), (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nao foi possivel registrar o aceite. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _aceitando = false);
    }
  }

  Future<void> _sair() async {
    await AppServices.instance.auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  String _rotaDaConta() =>
      switch (AppServices.instance.auth.usuarioAtual?['tipo']) {
        'profissional' || 'empresa' => AppRoutes.areaProfissional,
        'administrador' => AppRoutes.admin,
        _ => AppRoutes.home,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBarCustom(
      title: widget.apenasPoliticaComercial
          ? 'Política comercial e cancelamento'
          : 'Termos e privacidade',
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(label: 'Carregando termos.');
        }
        final termos = snapshot.data?['termos'];
        if (snapshot.hasError || termos is! Map<String, dynamic>) {
          return AsyncErrorView(
            message: 'Não foi possível carregar os termos agora.',
            onRetry: () => setState(_carregar),
          );
        }
        final secoesTodas = (termos['secoes'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final secoesComerciais = secoesTodas
            .where((secao) => secao['grupo'] == 'comercial')
            .toList();
        final secoes =
            widget.apenasPoliticaComercial && secoesComerciais.isNotEmpty
            ? secoesComerciais
            : secoesTodas;
        final aceitouVersaoAtual = snapshot.data?['aceitouVersaoAtual'] == true;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.apenasPoliticaComercial
                      ? 'Preços, pagamentos, responsabilidades e cancelamentos'
                      : '${termos['titulo'] ?? 'Termos de uso'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Versão: ${termos['versao'] ?? 'Não informada'}'),
                if (termos['publicadoEm'] != null)
                  Text('Publicado em: ${termos['publicadoEm']}'),
                const SizedBox(height: 16),
                if (termos['resumo'] != null) Text('${termos['resumo']}'),
                const SizedBox(height: 16),
                for (final secao in secoes) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${secao['titulo'] ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${secao['texto'] ?? ''}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.exigirAceite) ...[
                  FilledButton.icon(
                    key: const ValueKey('termos-aceitar-atual'),
                    onPressed: _aceitando
                        ? null
                        : aceitouVersaoAtual
                        ? () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            _rotaDaConta(),
                            (_) => false,
                          )
                        : () => _aceitar(termos),
                    icon: _aceitando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      aceitouVersaoAtual
                          ? 'Continuar'
                          : 'Li e aceito os termos',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _aceitando ? null : _sair,
                    child: const Text('Sair da conta'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Voltar'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
