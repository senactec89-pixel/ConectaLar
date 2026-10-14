import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../widgets/async_state_view.dart';
import '../../models/categoria.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/service_registry.dart';
import '../../widgets/bottom_navigation.dart';
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
              onSearchTap: () => _openRoute(AppRoutes.busca),
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
    required this.onNotificationsTap,
    required this.onCategoryTap,
    required this.onProfessionalTap,
  });

  final HomeContent content;
  final VoidCallback onRetry;
  final bool retrying;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;
  final ValueChanged<Categoria> onCategoryTap;
  final ValueChanged<Profissional> onProfessionalTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HomeHero(
              onSearchTap: onSearchTap,
              onNotificationsTap: onNotificationsTap,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
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
                              final larguraMinima = textoAmpliado
                                  ? 160.0
                                  : tamanhoTexto > 13.2
                                  ? 92.0
                                  : 64.0;
                              final colunas =
                                  ((constraints.maxWidth + 10) /
                                          (larguraMinima + 10))
                                      .floor()
                                      .clamp(2, 4);
                              return GridView.builder(
                                shrinkWrap: true,
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: content.categories.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: colunas,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 10,
                                      mainAxisExtent: textoAmpliado
                                          ? 168
                                          : tamanhoTexto > 13.2
                                          ? 124
                                          : 104,
                                    ),
                                itemBuilder: (context, index) {
                                  final category = content.categories[index];
                                  final style = _categoryStyle(
                                    category.nome,
                                    index,
                                  );
                                  return _CategoryTile(
                                    category: category,
                                    icon: style.icon,
                                    background: style.background,
                                    color: style.foreground,
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
      return const _CategoryStyle(
        Icons.bolt_rounded,
        Color(0xFFEAF6E2),
        Color(0xFF69BC36),
      );
    }
    if (normalized.contains('hidrá') ||
        normalized.contains('hidra') ||
        normalized.contains('encan')) {
      return const _CategoryStyle(
        Icons.water_drop_rounded,
        Color(0xFFE5F2FC),
        Color(0xFF1687C9),
      );
    }
    if (normalized.contains('pint')) {
      return const _CategoryStyle(
        Icons.format_paint_rounded,
        Color(0xFFFFF0E4),
        Color(0xFFF28A18),
      );
    }
    if (normalized.contains('limp')) {
      return const _CategoryStyle(
        Icons.cleaning_services_rounded,
        Color(0xFFE3F5EF),
        Color(0xFF13856A),
      );
    }
    if (normalized.contains('manut') || normalized.contains('mont')) {
      return const _CategoryStyle(
        Icons.handyman_rounded,
        Color(0xFFF1EAFE),
        Color(0xFF8051C5),
      );
    }
    if (normalized.contains('ar-cond')) {
      return const _CategoryStyle(
        Icons.ac_unit_rounded,
        Color(0xFFFCE8F0),
        Color(0xFFDA5485),
      );
    }
    if (normalized.contains('reform')) {
      return const _CategoryStyle(
        Icons.wallpaper_rounded,
        Color(0xFFFFF4D8),
        Color(0xFFE4A000),
      );
    }
    const styles = [
      _CategoryStyle(
        Icons.home_repair_service_rounded,
        Color(0xFFE8F2FC),
        Color(0xFF297CB5),
      ),
      _CategoryStyle(
        Icons.grid_view_rounded,
        Color(0xFFEAF6E2),
        Color(0xFF69BC36),
      ),
    ];
    return styles[index % styles.length];
  }
}

class _CategoryStyle {
  const _CategoryStyle(this.icon, this.background, this.foreground);

  final IconData icon;
  final Color background;
  final Color foreground;
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.onSearchTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textoAmpliado = MediaQuery.textScalerOf(context).scale(16) > 24;
        final compact = constraints.maxWidth < 380 || textoAmpliado;
        final baseImageSize = (constraints.maxWidth * 0.43).clamp(144.0, 170.0);
        final imageSize = baseImageSize * (compact ? 1.06 : 1.1);
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
        final imagem = Positioned(
          top: textoAmpliado && constraints.maxWidth < 380 ? 165 : 128,
          right: 8,
          child: SizedBox.square(
            dimension: imageSize,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFD8F0E1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.08,
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    'assets/images/home/hero_house_cutout.png',
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.65, 0),
                    semanticLabel: 'Casa com jardim',
                  ),
                ),
              ),
            ),
          ),
        );
        if (textoAmpliado) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              fundo,
              imagem,
              SizedBox(
                width: constraints.maxWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(
                        compact: compact,
                        onNotificationsTap: onNotificationsTap,
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: EdgeInsets.only(right: imageSize - 2),
                        child: _Greeting(compact: compact, fullText: true),
                      ),
                      const SizedBox(height: 24),
                      _SearchButton(onTap: onSearchTap, compact: compact),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          height: 306,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              fundo,
              imagem,
              Positioned(
                top: 12,
                left: 20,
                right: 20,
                child: _BrandHeader(
                  compact: compact,
                  onNotificationsTap: onNotificationsTap,
                ),
              ),
              Positioned(
                top: 86,
                left: 20,
                right: imageSize + 18,
                child: _Greeting(compact: compact),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 12,
                child: _SearchButton(onTap: onSearchTap, compact: compact),
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
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.home_work_rounded,
            color: AppColors.verde,
            size: 29,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Conecta'),
                    TextSpan(
                      text: 'Lar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: compact ? 19 : 21,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Serviços residenciais mais perto de você',
                maxLines: textoAmpliado ? null : 2,
                overflow: textoAmpliado
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 12,
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
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE84E55),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        total > 9 ? '9+' : '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
          'Encontre profissionais para cuidar do seu lar',
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
  const _SearchButton({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Semantics(
      button: true,
      label: 'Buscar serviço ou profissional e informar o bairro',
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: const Color(0x1A1E5E41),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          key: const ValueKey('home-search'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ExcludeSemantics(
            child: SizedBox(
              height: 66,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 15),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.textoSuave,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        textoAmpliado
                            ? 'Busca'
                            : 'Digite o serviço ou categoria',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: const Color(0xFFE4EAE6),
                    ),
                    SizedBox(width: compact ? 8 : 11),
                    Icon(
                      Icons.location_on_rounded,
                      color: AppColors.verdeEscuro,
                      size: 19,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      compact ? 'Bairro' : 'Seu bairro',
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!textoAmpliado) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textoSuave,
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
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.background,
    required this.color,
    required this.onTap,
  });

  final Categoria category;
  final IconData icon;
  final Color background;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.nome,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 29),
                const SizedBox(height: 5),
                Text(
                  category.nome,
                  maxLines: 3,
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
                            professional.bairro,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
