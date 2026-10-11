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

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<Notificacao>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    final response = await AppServices.instance.notificacoes.listar();
    return listFromApi(response['notificacoes'], notificacaoFromApi);
  }

  void _recarregar() {
    setState(() {
      _future = _carregar();
      _future.ignore();
    });
  }

  Future<void> _marcarTodas() async {
    await AppServices.instance.notificacoes.marcarTodasComoLidas();
    _recarregar();
  }

  Future<void> _abrir(Notificacao notificacao) async {
    if (!notificacao.lida) {
      await AppServices.instance.notificacoes.marcarComoLida(notificacao.id);
    }
    if (!mounted) return;
    if (notificacao.recursoTipo == 'solicitacao' &&
        notificacao.recursoId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.detalhesServico,
        arguments: notificacao.recursoId,
      );
    } else if (notificacao.recursoTipo == 'documento_verificacao') {
      Navigator.pushNamed(context, AppRoutes.documentosProfissional);
    } else {
      _recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarCustom(
        title: 'Notificações',
        actions: [
          IconButton(
            tooltip: 'Marcar todas como lidas',
            onPressed: _marcarTodas,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: FutureBuilder<List<Notificacao>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(label: 'Carregando notificações.');
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar suas notificações agora.',
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemCount: notificacoes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notificacao = notificacoes[index];
              return Card(
                child: ListTile(
                  onTap: () => _abrir(notificacao),
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
          );
        },
      ),
    );
  }
}
