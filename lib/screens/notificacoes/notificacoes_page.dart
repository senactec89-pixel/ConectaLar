import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/notificacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  late Future<List<Notificacao>> _future;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
    _future.ignore();
  }

  Future<List<Notificacao>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    final response = await AppServices.instance.notificacoes.listar();
    return listFromApi(response['notificacoes'], notificacaoFromApi);
  }

  Future<void> _recarregar() async {
    if (!mounted) return;
    final carregamento = _carregar();
    setState(() {
      _future = carregamento;
    });
    try {
      await carregamento;
    } catch (_) {
      // O FutureBuilder apresenta a falha e oferece nova tentativa.
    }
  }

  Future<void> _marcarTodas() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await AppServices.instance.notificacoes.marcarTodasComoLidas();
      _recarregar();
    } catch (_) {
      _mostrarErro();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir(Notificacao notificacao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    // Abrir o recurso não depende da confirmação de leitura.
    final marcacao = _marcarComoLida(notificacao);
    try {
      if (notificacao.recursoTipo == 'solicitacao' &&
          notificacao.recursoId != null) {
        await Navigator.pushNamed(
          context,
          AppRoutes.detalhesServico,
          arguments: notificacao.recursoId,
        );
      } else if (notificacao.recursoTipo == 'documento_verificacao') {
        await Navigator.pushNamed(context, AppRoutes.documentosProfissional);
      }
      await marcacao;
      if (!mounted) return;
      _recarregar();
    } catch (_) {
      _mostrarErro();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _marcarComoLida(Notificacao notificacao) async {
    if (notificacao.lida) return;
    try {
      await AppServices.instance.notificacoes.marcarComoLida(notificacao.id);
    } catch (_) {
      if (mounted && AppServices.instance.auth.autenticado) _mostrarErro();
    }
  }

  void _mostrarErro() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível atualizar suas notificações. Tente novamente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarCustom(
        title: 'Notificações',
        actions: [
          IconButton(
            tooltip: 'Atualizar notificações',
            onPressed: _ocupado ? null : _recarregar,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Marcar todas como lidas',
            onPressed: _ocupado ? null : _marcarTodas,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: Column(
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Notificacao>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AsyncLoadingView(
                    label: 'Carregando notificações.',
                  );
                }
                if (snapshot.hasError) {
                  return AsyncErrorView(
                    message:
                        'Não foi possível carregar suas notificações agora.',
                    onRetry: _recarregar,
                    icon: Icons.notifications_none_rounded,
                  );
                }
                final notificacoes = snapshot.data ?? const <Notificacao>[];
                if (notificacoes.isEmpty) {
                  return const EmptyStateView(
                    title: 'Tudo em dia',
                    message: 'Suas notificações aparecerão aqui.',
                    icon: Icons.notifications_none_rounded,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _recarregar,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    itemCount: notificacoes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notificacao = notificacoes[index];
                      return Card(
                        child: ListTile(
                          onTap: _ocupado ? null : () => _abrir(notificacao),
                          leading: Icon(
                            notificacao.lida
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: notificacao.lida
                                ? AppColors.textoSuave
                                : AppColors.verdeEscuro,
                          ),
                          title: Text(
                            notificacao.titulo,
                            style: TextStyle(
                              fontWeight: notificacao.lida
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(notificacao.mensagem),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
