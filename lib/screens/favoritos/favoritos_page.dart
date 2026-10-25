import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
import '../../services/api_page.dart';
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
  late Future<ApiPage<Profissional>> _favoritosFuture;
  bool _carregandoMais = false;
  int _versaoCarregamento = 0;

  @override
  void initState() {
    super.initState();
    _favoritosFuture = _carregarFavoritos();
  }

  Future<ApiPage<Profissional>> _carregarFavoritos({int pagina = 1}) async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      final profissionais = ConectaLarMockStore.instance.profissionaisFavoritos;
      return ApiPage<Profissional>(
        items: profissionais,
        page: 1,
        limit: profissionais.length,
        total: profissionais.length,
        hasMore: false,
      );
    }

    final response = await services.clientes.listarFavoritos(pagina: pagina);
    return apiPageFromResponse<Profissional>(
      response,
      itemsKey: 'favoritos',
      mapper: (favorito) => profissionalFromApi(
        Map<String, dynamic>.from(favorito['profissional'] as Map),
      ),
      fallbackPage: pagina,
    );
  }

  Future<void> _recarregarFavoritos() async {
    if (!mounted) return;
    _versaoCarregamento++;
    final carregamento = _carregarFavoritos();
    setState(() {
      _favoritosFuture = carregamento;
      _carregandoMais = false;
    });
    try {
      await carregamento;
    } catch (_) {
      // O FutureBuilder apresenta o erro e permite uma nova tentativa.
    }
  }

  Future<void> _carregarMais(ApiPage<Profissional> atual) async {
    if (_carregandoMais || !atual.hasMore) return;
    final versao = _versaoCarregamento;
    setState(() => _carregandoMais = true);
    try {
      final proxima = await _carregarFavoritos(pagina: atual.page + 1);
      if (!mounted || versao != _versaoCarregamento) return;
      setState(() {
        _favoritosFuture = Future.value(
          ApiPage<Profissional>(
            items: [...atual.items, ...proxima.items],
            page: proxima.page,
            limit: proxima.limit,
            total: proxima.total,
            hasMore: proxima.hasMore,
          ),
        );
        _carregandoMais = false;
      });
    } catch (_) {
      if (!mounted || versao != _versaoCarregamento) return;
      setState(() => _carregandoMais = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NÃ£o foi possÃ­vel carregar mais favoritos.'),
        ),
      );
    }
  }

  Future<void> _removerFavorito(
    ConectaLarMockStore store,
    int profissionalId,
  ) async {
    if (AppServices.instance.auth.autenticado) {
      try {
        await AppServices.instance.clientes.removerFavorito(profissionalId);
        _versaoCarregamento++;
        setState(() {
          _favoritosFuture = _carregarFavoritos();
          _carregandoMais = false;
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
        builder: (context, _) => FutureBuilder<ApiPage<Profissional>>(
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
            final pagina = snapshot.data!;
            final favoritos = pagina.items;
            return RefreshIndicator(
              onRefresh: _recarregarFavoritos,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppInsets.page,
                children: [
                  Text(
                    'Profissionais salvos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Consulte os perfis que você adicionou aos favoritos.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textoSuave,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Wrap(
                    spacing: AppSpace.md,
                    runSpacing: AppSpace.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                          vertical: AppSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.verdeClaro,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'Profissionais',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.verdeEscuro),
                        ),
                      ),
                      Text(
                        '${pagina.total} ${pagina.total == 1 ? 'salvo' : 'salvos'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (favoritos.isEmpty)
                    EmptyStateView(
                      title: 'Sua lista está vazia',
                      message: 'Os profissionais salvos aparecerão aqui.',
                      icon: Icons.favorite_border_rounded,
                      action: FilledButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.busca),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Buscar profissionais'),
                      ),
                    )
                  else
                    for (final profissional in favoritos) ...[
                      _FavoritoItem(
                        profissional: profissional,
                        onRemover: () =>
                            _removerFavorito(store, profissional.id),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  if (pagina.hasMore)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _carregandoMais
                            ? null
                            : () => _carregarMais(pagina),
                        icon: _carregandoMais
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _carregandoMais ? 'Carregando...' : 'Carregar mais',
                        ),
                      ),
                    ),
                ],
              ),
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
