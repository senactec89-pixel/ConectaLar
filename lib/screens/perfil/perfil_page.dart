import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
import '../../widgets/profile_menu_tile.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<Usuario> _usuarioFuture;
  bool _saindo = false;
  bool _alterandoFoto = false;

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

  Future<void> _selecionarFoto() async {
    if (_alterandoFoto || AppServices.instance.emDemonstracao) return;
    setState(() => _alterandoFoto = true);
    try {
      final arquivo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JPEG, PNG ou WebP',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            uniformTypeIdentifiers: [
              'public.jpeg',
              'public.png',
              'org.webmproject.webp',
            ],
          ),
        ],
        confirmButtonText: 'Selecionar',
      );
      if (arquivo == null) return;
      final bytes = await arquivo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2 * 1024 * 1024) {
        _mostrarInfo(context, 'A foto precisa ter no máximo 2 MB.');
        return;
      }
      final mimeType = _mimeDaFoto(arquivo.name);
      if (mimeType == null) {
        _mostrarInfo(context, 'Use uma foto JPEG, PNG ou WebP.');
        return;
      }
      await AppServices.instance.auth.atualizarFotoPerfil(
        arquivoBase64: base64Encode(bytes),
        mimeType: mimeType,
        nomeArquivo: arquivo.name,
      );
      if (!mounted) return;
      setState(() {
        _usuarioFuture = _carregarUsuario();
        _usuarioFuture.ignore();
      });
      _mostrarInfo(context, 'Foto de perfil atualizada.');
    } catch (_) {
      if (mounted) {
        _mostrarInfo(context, 'Não foi possível atualizar a foto.');
      }
    } finally {
      if (mounted) setState(() => _alterandoFoto = false);
    }
  }

  Future<void> _removerFoto() async {
    if (_alterandoFoto || AppServices.instance.emDemonstracao) return;
    setState(() => _alterandoFoto = true);
    try {
      await AppServices.instance.auth.removerFotoPerfil();
      if (!mounted) return;
      setState(() {
        _usuarioFuture = _carregarUsuario();
        _usuarioFuture.ignore();
      });
      _mostrarInfo(context, 'Foto de perfil removida.');
    } catch (_) {
      if (mounted) {
        _mostrarInfo(context, 'Não foi possível remover a foto.');
      }
    } finally {
      if (mounted) setState(() => _alterandoFoto = false);
    }
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
            final administrador = usuario.tipo == TipoUsuario.administrador;
            final textoAmpliado =
                MediaQuery.textScalerOf(context).scale(20) > 30;
            final foto = _FotoPerfilUsuario(
              usuario: usuario,
              alterando: _alterandoFoto,
              onAlterar: _selecionarFoto,
              onRemover: usuario.fotoPerfilUrl == null ? null : _removerFoto,
            );
            final identificacao = Column(
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
                const SizedBox(height: AppSpace.xs),
                Text(
                  _tipoConta(usuario),
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Flex(
                      direction: textoAmpliado
                          ? Axis.vertical
                          : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        foto,
                        if (textoAmpliado)
                          const SizedBox(height: AppSpace.lg)
                        else
                          const SizedBox(width: 14),
                        if (textoAmpliado)
                          identificacao
                        else
                          Expanded(child: identificacao),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _DadosProtegidos(administrador: administrador),
                const SizedBox(height: AppSpace.xl),
                Text(
                  administrador ? 'Conta administrativa' : 'Perfil e contato',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                ProfileMenuTile(
                  icon: Icons.badge_outlined,
                  title: 'Meus dados',
                  subtitle: 'Nome, telefone e e-mail da conta',
                  onTap: () async {
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
                  ProfileMenuTile(
                    icon: Icons.location_on_outlined,
                    title: 'Endereço de atendimento',
                    subtitle: 'Oculto até aceite válido do profissional',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.enderecos),
                  ),
                ProfileMenuTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notificações',
                  subtitle: 'Eventos reais do atendimento',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notificacoes),
                ),
                if (usuario.tipo.valorBanco != 'administrador')
                  ProfileMenuTile(
                    icon: Icons.flag_outlined,
                    title: 'Minhas denúncias',
                    subtitle: 'Acompanhar relatos e decisões da análise',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.minhasDenuncias),
                  ),
                if (!administrador) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'Contratação e pagamentos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  ProfileMenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Política comercial e cancelamento',
                    subtitle:
                        'Preços, pagamentos externos e regras para cancelar',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.politicaComercial,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Acesso e privacidade',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                ProfileMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Segurança',
                  subtitle: 'Senha, recuperação e autenticação',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.seguranca),
                ),
                ProfileMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacidade',
                  subtitle: 'Controle dos seus dados pessoais',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.privacidade),
                ),
                ProfileMenuTile(
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

String? _mimeDaFoto(String nomeArquivo) {
  final nome = nomeArquivo.toLowerCase();
  if (nome.endsWith('.jpg') || nome.endsWith('.jpeg')) return 'image/jpeg';
  if (nome.endsWith('.png')) return 'image/png';
  if (nome.endsWith('.webp')) return 'image/webp';
  return null;
}

String _tipoConta(Usuario usuario) => switch (usuario.tipo) {
  TipoUsuario.cliente => 'Cliente',
  TipoUsuario.profissional => 'Profissional',
  TipoUsuario.empresa => 'Empresa',
  TipoUsuario.administrador => 'Administrador',
};

class _FotoPerfilUsuario extends StatelessWidget {
  const _FotoPerfilUsuario({
    required this.usuario,
    required this.alterando,
    required this.onAlterar,
    required this.onRemover,
  });

  final Usuario usuario;
  final bool alterando;
  final VoidCallback onAlterar;
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    final inicial = usuario.nome.trim().isEmpty
        ? '?'
        : usuario.nome.characters.first.toUpperCase();
    final fallback = ColoredBox(
      color: AppColors.verdeClaro,
      child: Center(
        child: Text(
          inicial,
          style: const TextStyle(
            color: AppColors.verdeEscuro,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 68,
                child: usuario.fotoPerfilUrl == null
                    ? fallback
                    : Image.network(
                        usuario.fotoPerfilUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Foto de ${usuario.nome}',
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Material(
                color: AppColors.verde,
                shape: const CircleBorder(),
                child: IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 42,
                    height: 42,
                  ),
                  tooltip: 'Alterar foto',
                  onPressed: alterando ? null : onAlterar,
                  icon: alterando
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.branco,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          color: AppColors.branco,
                          size: 19,
                        ),
                ),
              ),
            ),
          ],
        ),
        if (onRemover != null)
          TextButton(
            onPressed: alterando ? null : onRemover,
            child: const Text('Remover'),
          ),
      ],
    );
  }
}

class _DadosProtegidos extends StatelessWidget {
  const _DadosProtegidos({required this.administrador});

  final bool administrador;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.verdeEscuro),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              administrador
                  ? 'Dados consultados na moderação são privados. Acesse-os somente para as tarefas da sua conta.'
                  : 'Endereço completo, documentos e conversas são informações privadas. Compartilhe seus dados com cuidado.',
              style: const TextStyle(
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
