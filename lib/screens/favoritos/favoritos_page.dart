import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/profissional_card.dart';

class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  late Future<List<Profissional>> _favoritosFuture;

  @override
  void initState() {
    super.initState();
    _favoritosFuture = _carregarFavoritos();
  }

  Future<List<Profissional>> _carregarFavoritos() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return ConectaLarMockStore.instance.profissionaisFavoritos;
    }

    final response = await services.clientes.listarFavoritos();
    final favoritos = response['favoritos'];
    if (favoritos is! List) return const [];
    return favoritos
        .whereType<Map<String, dynamic>>()
        .map((favorito) => favorito['profissional'])
        .whereType<Map<String, dynamic>>()
        .map(profissionalFromApi)
        .toList(growable: false);
  }

  void _recarregarFavoritos() {
    setState(() {
      _favoritosFuture = _carregarFavoritos();
      _favoritosFuture.ignore();
    });
  }

  Future<void> _removerFavorito(
    ConectaLarMockStore store,
    int profissionalId,
  ) async {
    if (AppServices.instance.auth.autenticado) {
      try {
        await AppServices.instance.clientes.removerFavorito(profissionalId);
        setState(() {
          _favoritosFuture = _carregarFavoritos();
          _favoritosFuture.ignore();
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover o favorito.')),
        );
      }
      return;
    }

    if (AppServices.instance.emDemonstracao) {
      store.toggleFavorito(profissionalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: const AppBarCustom(title: 'Meus favoritos'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => FutureBuilder<List<Profissional>>(
          future: _favoritosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AsyncLoadingView(label: 'Carregando favoritos.');
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar seus favoritos agora.',
                onRetry: _recarregarFavoritos,
                icon: Icons.favorite_border_rounded,
              );
            }
            final favoritos = snapshot.data ?? const <Profissional>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                const Text(
                  'Profissionais salvos',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Consulte os perfis que você adicionou aos favoritos.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.verdeClaro,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Profissionais',
                        style: TextStyle(
                          color: AppColors.verdeEscuro,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${favoritos.length} ${favoritos.length == 1 ? 'salvo' : 'salvos'}',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (favoritos.isEmpty)
                  const EmptyStateView(
                    title: 'Sua lista está vazia',
                    message: 'Os profissionais salvos aparecerão aqui.',
                    icon: Icons.favorite_border_rounded,
                  )
                else
                  for (final profissional in favoritos) ...[
                    _FavoritoItem(
                      profissional: profissional,
                      onRemover: () => _removerFavorito(store, profissional.id),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationCustom(
        currentIndex: 2,
        onDestinationSelected: (index) =>
            navigateToMainDestination(context, index),
      ),
    );
  }
}

class _FavoritoItem extends StatelessWidget {
  const _FavoritoItem({required this.profissional, required this.onRemover});

  final Profissional profissional;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return ProfissionalCard(
      profissional: profissional,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.perfilProfissional,
        arguments: profissional,
      ),
      trailingAction: IconButton.filledTonal(
        key: ValueKey('favorito-remover-${profissional.id}'),
        tooltip: 'Remover dos favoritos',
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFFCEEEE),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
        ),
        onPressed: onRemover,
        icon: const Icon(Icons.favorite, color: Color(0xFFC53030)),
      ),
    );
  }
}
