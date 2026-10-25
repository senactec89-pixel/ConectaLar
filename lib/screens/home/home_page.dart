import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../widgets/async_state_view.dart';
import '../../models/categoria.dart';
import '../../models/busca_estado.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/service_registry.dart';
import '../../utils/categoria_icons.dart';
import '../../utils/constants.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/conectalar_brand.dart';
import 'home_mock_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.loadContent});

  final Future<HomeContent> Function()? loadContent;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    _contentFuture = widget.loadContent?.call() ?? _carregarConteudoPadrao();
    // O FutureBuilder continua recebendo o erro; este listener protege o
    // intervalo entre criar a consulta e renderizar o próximo frame.
    _contentFuture.ignore();
  }

  Future<HomeContent> _carregarConteudoPadrao() async {
    if (AppServices.instance.emDemonstracao) return HomeMockData.content;
    return AppServices.instance.carregarHome();
  }

  void _retry() {
    setState(_loadContent);
  }

  void _openRoute(String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  void _onDestinationSelected(int index) {
    navigateToMainDestination(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<HomeContent>(
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AsyncLoadingView(
                label: 'Carregando conteúdo da página inicial',
              );
            }

            if (snapshot.hasError) {
              return _HomeErrorState(error: snapshot.error!, onRetry: _retry);
            }

            return _HomeContentView(
              content: snapshot.data ?? const HomeContent(),
              onRetry: _retry,
              retrying: snapshot.connectionState == ConnectionState.waiting,
              onSearchTap: () => _openRoute(
                AppRoutes.busca,
                arguments: CampoBuscaInicial.servico,
              ),
              onBairroTap: () => _openRoute(
                AppRoutes.busca,
                arguments: CampoBuscaInicial.bairro,
              ),
              onNotificationsTap: () => _openRoute(AppRoutes.notificacoes),
              onCategoryTap: (category) =>
                  _openRoute(AppRoutes.busca, arguments: category),
              onProfessionalTap: (professional) => _openRoute(
                AppRoutes.perfilProfissional,
                arguments: professional,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationCustom(
        currentIndex: 0,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

class _HomeContentView extends StatelessWidget {
  const _HomeContentView({
    required this.content,
    required this.onRetry,
    required this.retrying,
    required this.onSearchTap,
    required this.onBairroTap,
    required this.onNotificationsTap,
    required this.onCategoryTap,
    required this.onProfessionalTap,
  });

  final HomeContent content;
  final VoidCallback onRetry;
  final bool retrying;
  final VoidCallback onSearchTap;
  final VoidCallback onBairroTap;
  final VoidCallback onNotificationsTap;
  final ValueChanged<Categoria> onCategoryTap;
  final ValueChanged<Profissional> onProfessionalTap;

  @override
  Widget build(BuildContext context) {
    final categoriasEmDestaque = content.categories
        .take(8)
        .toList(growable: false);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HomeHero(
              onSearchTap: onSearchTap,
              onBairroTap: onBairroTap,
              onNotificationsTap: onNotificationsTap,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeading(
                          title: 'Categorias',
                          suffix: 'de serviços',
                          action: 'Ver todas',
                          onActionTap: onSearchTap,
                        ),
                        const SizedBox(height: 16),
                        if (content.categoriesLoadFailed)
                          SectionErrorView(
                            message: 'Não foi possível carregar as categorias.',
                            onRetry: onRetry,
                            retrying: retrying,
                          )
                        else if (content.categories.isEmpty)
                          const _EmptySectionMessage(
                            message: 'Nenhuma categoria disponível.',
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final tamanhoTexto = MediaQuery.textScalerOf(
                                context,
                              ).scale(12);
                              final textoAmpliado = tamanhoTexto > 16.8;
                              final espacoHorizontal = textoAmpliado
                                  ? 10.0
                                  : 6.0;
                              final larguraMinima = textoAmpliado
                                  ? 160.0
                                  : tamanhoTexto > 13.2
                                  ? 86.0
                                  : 75.0;
                              final colunas =
                                  ((constraints.maxWidth + espacoHorizontal) /
                                          (larguraMinima + espacoHorizontal))
                                      .floor()
                                      .clamp(2, 4);
                              return GridView.builder(
                                shrinkWrap: true,
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: categoriasEmDestaque.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: colunas,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: espacoHorizontal,
                                      mainAxisExtent: textoAmpliado
                                          ? 190
                                          : tamanhoTexto > 13.2
                                          ? 140
                                          : colunas == 3
                                          ? 104
                                          : 124,
                                    ),
                                itemBuilder: (context, index) {
                                  final category = categoriasEmDestaque[index];
                                  final style = _categoryStyle(
                                    category.nome,
                                    index,
                                  );
                                  return _CategoryTile(
                                    category: category,
                                    icon: categoriaIconData(category.icone),
                                    background: style.background,
                                    color: style.foreground,
                                    compact: colunas == 3,
                                    onTap: () => onCategoryTap(category),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeading(
                    title: 'Profissionais em destaque',
                    action: 'Ver todos',
                    onActionTap: onSearchTap,
                  ),
                  const SizedBox(height: 14),
                  if (content.professionalsLoadFailed)
                    SectionErrorView(
                      message: 'Não foi possível carregar os profissionais.',
                      onRetry: onRetry,
                      retrying: retrying,
                    )
                  else if (content.featuredProfessionals.isEmpty)
                    const _EmptySectionMessage(
                      message: 'Nenhum profissional disponível no momento.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textoAmpliado =
                            MediaQuery.textScalerOf(context).scale(13) > 19.5;
                        final columns =
                            constraints.maxWidth < 300 || textoAmpliado ? 1 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          primary: false,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: content.featuredProfessionals.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: columns == 1
                                    ? textoAmpliado
                                          ? 0.75
                                          : 0.92
                                    : constraints.maxWidth > 600
                                    ? 1.2
                                    : 0.52,
                              ),
                          itemBuilder: (context, index) {
                            final professional =
                                content.featuredProfessionals[index];
                            return _FeaturedProfessionalCard(
                              professional: professional,
                              onTap: () => onProfessionalTap(professional),
                            );
                          },
                        );
                      },
                    ),
                  if (!content.professionalsLoadFailed &&
                      content.featuredProfessionals.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _NearbyProfessionals(
                      professionals: content.featuredProfessionals,
                      onSeeAll: onSearchTap,
                      onProfessionalTap: onProfessionalTap,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CategoryStyle _categoryStyle(String name, int index) {
    final normalized = name.toLowerCase();
    if (normalized.contains('elét') || normalized.contains('elet')) {
      return const _CategoryStyle(Color(0xFFEAF6E2), Color(0xFF69BC36));
    }
    if (normalized.contains('hidrá') ||
        normalized.contains('hidra') ||
        normalized.contains('encan')) {
      return const _CategoryStyle(Color(0xFFE5F2FC), Color(0xFF1687C9));
    }
    if (normalized.contains('pint')) {
      return const _CategoryStyle(Color(0xFFFFF0E4), Color(0xFFF28A18));
    }
    if (normalized.contains('limp')) {
      return const _CategoryStyle(Color(0xFFE3F5EF), Color(0xFF13856A));
    }
    if (normalized.contains('manut') || normalized.contains('mont')) {
      return const _CategoryStyle(Color(0xFFF1EAFE), Color(0xFF8051C5));
    }
    if (normalized.contains('ar-cond')) {
      return const _CategoryStyle(Color(0xFFFCE8F0), Color(0xFFDA5485));
    }
    if (normalized.contains('reform')) {
      return const _CategoryStyle(Color(0xFFFFF4D8), Color(0xFFE4A000));
    }
    const styles = [
      _CategoryStyle(Color(0xFFE8F2FC), Color(0xFF297CB5)),
      _CategoryStyle(Color(0xFFEAF6E2), Color(0xFF69BC36)),
    ];
    return styles[index % styles.length];
  }
}

class _CategoryStyle {
  const _CategoryStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _NearbyProfessionals extends StatelessWidget {
  const _NearbyProfessionals({
    required this.professionals,
    required this.onSeeAll,
    required this.onProfessionalTap,
  });

  final List<Profissional> professionals;
  final VoidCallback onSeeAll;
  final ValueChanged<Profissional> onProfessionalTap;

  @override
  Widget build(BuildContext context) {
    final located = professionals
        .where(
          (professional) =>
              professional.latitudeAproximada != null &&
              professional.longitudeAproximada != null,
        )
        .toList(growable: false);
    final supportedPlatform =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final showMap =
        AppConstants.googleMapsEnabled &&
        supportedPlatform &&
        located.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Perto de você',
          action: 'Ver todos',
          onActionTap: onSeeAll,
        ),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            height: 176,
            child: showMap
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _mapCenter(located),
                      zoom: 11,
                    ),
                    markers: {
                      for (final professional in located)
                        Marker(
                          markerId: MarkerId('profissional-${professional.id}'),
                          position: LatLng(
                            professional.latitudeAproximada!,
                            professional.longitudeAproximada!,
                          ),
                          infoWindow: InfoWindow(
                            title: professional.nome,
                            snippet: professional.bairro,
                            onTap: () => onProfessionalTap(professional),
                          ),
                        ),
                    },
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                  )
                : _MapFallback(onTap: onSeeAll),
          ),
        ),
      ],
    );
  }

  LatLng _mapCenter(List<Profissional> professionals) {
    final latitude =
        professionals
            .map((item) => item.latitudeAproximada!)
            .reduce((a, b) => a + b) /
        professionals.length;
    final longitude =
        professionals
            .map((item) => item.longitudeAproximada!)
            .reduce((a, b) => a + b) /
        professionals.length;
    return LatLng(latitude, longitude);
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F2ED),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            const Positioned(
              left: 28,
              top: 32,
              child: Icon(Icons.location_on, color: AppColors.verde, size: 34),
            ),
            const Positioned(
              right: 52,
              bottom: 30,
              child: Icon(
                Icons.location_on,
                color: Color(0xFF1687C9),
                size: 30,
              ),
            ),
            Center(
              child: FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver profissionais da região'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.onSearchTap,
    required this.onBairroTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onBairroTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textoAmpliado = MediaQuery.textScalerOf(context).scale(16) > 24;
        final compact = constraints.maxWidth < 380 || textoAmpliado;
        final imageSize = (constraints.maxWidth * 0.37).clamp(132.0, 152.0);
        const heroHeight = 318.0;
        const searchBottom = 16.0;
        const imageGap = 8.0;
        final imageTop =
            heroHeight -
            searchBottom -
            _SearchButton.height -
            imageGap -
            imageSize;
        const fundo = Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3FBF6), Color(0xFFE6F5EC)],
              ),
            ),
          ),
        );
        Widget imagemCircular(double tamanho) => SizedBox.square(
          dimension: tamanho,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.verdeClaro,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.branco, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.24,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/images/home/hero_house_cutout.png',
                    width: tamanho,
                    height: tamanho,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.3, 0.65),
                    semanticLabel: 'Casa com jardim',
                  ),
                ),
              ),
            ),
          ),
        );
        final imagem = Positioned(
          top: imageTop,
          right: 20,
          child: imagemCircular(imageSize),
        );
        if (textoAmpliado) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              fundo,
              SizedBox(
                width: constraints.maxWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(
                        compact: compact,
                        onNotificationsTap: onNotificationsTap,
                      ),
                      const SizedBox(height: AppSpace.xl),
                      _Greeting(compact: compact, fullText: true),
                      const SizedBox(height: AppSpace.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: imagemCircular(96),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _SearchButton(
                        onTap: onSearchTap,
                        onBairroTap: onBairroTap,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          height: heroHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              fundo,
              imagem,
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: _BrandHeader(
                  compact: compact,
                  onNotificationsTap: onNotificationsTap,
                ),
              ),
              Positioned(
                top: 98,
                left: 20,
                right: imageSize + 30,
                child: _Greeting(compact: compact),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 12,
                child: _SearchButton(
                  onTap: onSearchTap,
                  onBairroTap: onBairroTap,
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact, required this.onNotificationsTap});

  final bool compact;
  final VoidCallback onNotificationsTap;

  Future<int> _naoLidas() async {
    if (!AppServices.instance.auth.autenticado) return 0;
    final response = await AppServices.instance.notificacoes.resumo();
    return response['naoLidas'] is int ? response['naoLidas'] as int : 0;
  }

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Row(
      children: [
        Semantics(
          label: 'Marca ConectaLar',
          image: true,
          child: Container(
            width: compact ? 46 : 50,
            height: compact ? 46 : 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(15),
            ),
            clipBehavior: Clip.antiAlias,
            child: const ConectaLarSymbol(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConectaLarWordmark(fontSize: textoAmpliado ? 15 : 21),
              const SizedBox(height: 4),
              Text(
                'Serviços para cuidar do seu lar',
                maxLines: textoAmpliado ? null : 1,
                overflow: textoAmpliado
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        FutureBuilder<int>(
          future: _naoLidas(),
          builder: (context, snapshot) {
            final total = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNotificationsTap,
                  tooltip: 'Notificações',
                  icon: const Icon(Icons.notifications_none_rounded, size: 27),
                  color: AppColors.texto,
                ),
                if (total > 0)
                  Positioned(
                    right: 3,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE84E55),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        total > 9 ? '9+' : '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.compact, this.fullText = false});

  final bool compact;
  final bool fullText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá!',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Que serviço você precisa?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.texto,
            fontSize: compact ? 21 : 23,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Busque, compare e solicite atendimento.',
          maxLines: fullText ? null : 2,
          overflow: fullText ? TextOverflow.clip : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textoSuave,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({
    required this.onTap,
    required this.onBairroTap,
    required this.compact,
  });

  static const height = 66.0;

  final VoidCallback onTap;
  final VoidCallback onBairroTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Material(
      color: AppColors.branco,
      elevation: 4,
      shadowColor: const Color(0x1A1E5E41),
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Buscar serviço ou profissional',
                  child: InkWell(
                    key: const ValueKey('home-search'),
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: height,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: AppColors.verdeEscuro,
                              size: 26,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                textoAmpliado
                                    ? 'Buscar'
                                    : compact
                                    ? 'Buscar serviços'
                                    : 'Buscar serviço ou profissional',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!textoAmpliado) ...[
                              const SizedBox(width: AppSpace.xs),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.verdeEscuro,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Semantics(
                button: true,
                label: 'Filtrar por bairro',
                child: Material(
                  color: AppColors.verdeClaro,
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  child: InkWell(
                    key: const ValueKey('home-bairro'),
                    onTap: onBairroTap,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: textoAmpliado
                                ? AppSpace.md
                                : AppSpace.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.verdeEscuro,
                                size: 19,
                              ),
                              if (!textoAmpliado) ...[
                                const SizedBox(width: AppSpace.xs),
                                const Text(
                                  'Bairro',
                                  style: TextStyle(
                                    color: AppColors.verdeEscuro,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.background,
    required this.color,
    required this.compact,
    required this.onTap,
  });

  final Categoria category;
  final IconData icon;
  final Color background;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.nome,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 0,
              vertical: compact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 36 : 44,
                  height: compact ? 36 : 44,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: compact ? 22 : 25),
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  category.nome.replaceAll('-', '-\n'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedProfessionalCard extends StatefulWidget {
  const _FeaturedProfessionalCard({
    required this.professional,
    required this.onTap,
  });

  final Profissional professional;
  final VoidCallback onTap;

  @override
  State<_FeaturedProfessionalCard> createState() =>
      _FeaturedProfessionalCardState();
}

class _FeaturedProfessionalCardState extends State<_FeaturedProfessionalCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final professional = widget.professional;
    final price = professional.precoInicial;
    final image = professional.fotoAsset;
    final imageUrl = professional.fotoUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 136,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.verdeClaro,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.verde,
                          size: 50,
                        ),
                      ),
                    )
                  else if (image != null)
                    Image.asset(
                      image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.verdeClaro,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.verde,
                          size: 50,
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: AppColors.verdeClaro,
                      child: Icon(
                        Icons.person,
                        color: AppColors.verde,
                        size: 50,
                      ),
                    ),
                  if (professional.verificado)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF1A9A67),
                              size: 15,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verificado',
                              style: TextStyle(
                                color: AppColors.texto,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 9,
                    top: 8,
                    child: Material(
                      color: const Color(0x55000000),
                      shape: const CircleBorder(),
                      child: IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        tooltip: _isFavorite
                            ? 'Remover dos favoritos'
                            : 'Adicionar aos favoritos',
                        onPressed: () =>
                            setState(() => _isFavorite = !_isFavorite),
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.verdeClaro,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : image == null
                              ? null
                              : AssetImage(image),
                          child: imageUrl == null && image == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.verde,
                                  size: 18,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                professional.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.texto,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: AppColors.estrela,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      professional.notaMedia == null
                                          ? 'Novo profissional'
                                          : '${professional.notaMedia!.toStringAsFixed(1).replaceAll('.', ',')} (${professional.quantidadeAvaliacoes ?? 0})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textoSuave,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.textoSuave,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            professional.distanciaKm == null
                                ? professional.bairro
                                : '${professional.bairro} · ${professional.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (professional.servicos.isNotEmpty)
                      Text(
                        'Serviços: ${professional.servicos.take(2).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        professional.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      price == null
                          ? 'Preço sob consulta'
                          : 'A partir de R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF15935F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.suffix,
    this.action,
    this.onActionTap,
  });

  final String title;
  final String? suffix;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(18) > 27;
    final botao = action == null
        ? null
        : TextButton.icon(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 8),
              minimumSize: const Size(0, 48),
              foregroundColor: const Color(0xFF15935F),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: Text(
              action!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          );
    if (textoAmpliado) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 18, color: AppColors.texto),
          ),
          if (botao != null)
            Align(alignment: Alignment.centerRight, child: botao),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texto,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    suffix!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.texto,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?botao,
      ],
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.inbox_outlined, color: AppColors.verde),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncErrorView(
      message: switch (error) {
        TimeoutException() =>
          'O carregamento demorou mais que o esperado. Tente novamente.',
        http.ClientException() =>
          'Não foi possível conectar ao serviço. Verifique sua conexão e tente novamente.',
        _ => 'Não foi possível carregar a página inicial. Tente novamente.',
      },
      onRetry: onRetry,
    );
  }
}
