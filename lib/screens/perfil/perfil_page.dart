import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/usuario.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/bottom_navigation.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<Usuario> _usuarioFuture;
  bool _saindo = false;

  @override
  void initState() {
    super.initState();
    _usuarioFuture = _carregarUsuario();
  }

  Future<Usuario> _carregarUsuario() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return ConectaLarMockStore.instance.usuarioAtual;
    }
    if (services.auth.usuarioAtual?['tipo'] != 'cliente') {
      final usuario = services.auth.usuarioAtual;
      if (usuario == null) throw StateError('Sessão encerrada.');
      return usuarioFromApi(usuario);
    }

    final response = await services.clientes.meuPerfil();
    final cliente = response['cliente'];
    return cliente is Map<String, dynamic>
        ? usuarioFromApi(cliente)
        : throw StateError('Perfil indisponível.');
  }

  Future<void> _sair() async {
    if (_saindo) return;
    setState(() => _saindo = true);
    await AppServices.instance.auth.logout();
    ConectaLarMockStore.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Meu perfil'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<Usuario>(
          future: _usuarioFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AsyncLoadingView(label: 'Carregando seu perfil.');
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar seu perfil agora.',
                onRetry: () => setState(() {
                  _usuarioFuture = _carregarUsuario();
                  _usuarioFuture.ignore();
                }),
              );
            }
            final usuario = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.verdeClaro,
                          foregroundColor: AppColors.verdeEscuro,
                          child: Text(
                            usuario.nome.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                usuario.nome,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                usuario.tipo.valorBanco,
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _DadosProtegidos(),
                const SizedBox(height: 14),
                _PerfilOpcao(
                  icon: Icons.badge_outlined,
                  title: 'Meus dados',
                  subtitle: 'Nome, e-mail e telefone',
                  onTap: () async {
                    if (usuario.tipo.valorBanco != 'cliente') {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          scrollable: true,
                          title: const Text('Dados da conta'),
                          content: Text(
                            '${usuario.nome}\n${usuario.email}\n${usuario.telefone ?? 'Telefone não informado'}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final atualizado = await Navigator.pushNamed(
                      context,
                      AppRoutes.editarDados,
                    );
                    if (atualizado == true && mounted) {
                      setState(() {
                        _usuarioFuture = _carregarUsuario();
                        _usuarioFuture.ignore();
                      });
                    }
                  },
                ),
                if (usuario.tipo.valorBanco == 'cliente')
                  _PerfilOpcao(
                    icon: Icons.location_on_outlined,
                    title: 'Endereço de atendimento',
                    subtitle: 'Oculto até aceite válido do profissional',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.enderecos),
                  ),
                _PerfilOpcao(
                  icon: Icons.notifications_outlined,
                  title: 'Notificações',
                  subtitle: 'Eventos reais do atendimento',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notificacoes),
                ),
                _PerfilOpcao(
                  icon: Icons.lock_outline,
                  title: 'Segurança',
                  subtitle: 'Sessão, senha e recuperação de acesso',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.seguranca),
                ),
                _PerfilOpcao(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacidade',
                  subtitle: 'Dados privados e LGPD',
                  onTap: () => _mostrarInfo(
                    context,
                    'Dados sensíveis não devem aparecer em logs, links públicos ou telas sem vínculo.',
                  ),
                ),
                _PerfilOpcao(
                  icon: Icons.logout_rounded,
                  title: _saindo ? 'Saindo…' : 'Sair da conta',
                  subtitle: 'Encerrar sessão da conta',
                  onTap: _saindo ? null : _sair,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar:
          AppServices.instance.auth.usuarioAtual?['tipo'] != null &&
              AppServices.instance.auth.usuarioAtual?['tipo'] != 'cliente'
          ? null
          : BottomNavigationCustom(
              currentIndex: 4,
              onDestinationSelected: (index) =>
                  navigateToMainDestination(context, index),
            ),
    );
  }

  void _mostrarInfo(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }
}

class _DadosProtegidos extends StatelessWidget {
  const _DadosProtegidos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.verdeEscuro),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Endereço completo, documentos e conversas são informações privadas. Compartilhe seus dados com cuidado.',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfilOpcao extends StatelessWidget {
  const _PerfilOpcao({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.verdeEscuro),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
