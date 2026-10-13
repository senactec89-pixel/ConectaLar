import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/categoria.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/service_registry.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/profissional_card.dart';
import '../home/home_mock_data.dart';

class BuscaPage extends StatefulWidget {
  const BuscaPage({super.key});

  @override
  State<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends State<BuscaPage> {
  final _termoController = TextEditingController();
  final _bairroController = TextEditingController();

  Categoria? _categoriaSelecionada;
  bool _argumentosLidos = false;
  late Future<HomeContent> _contentFuture;

  List<Categoria> _categorias = const [];
  List<Profissional> _profissionais = const [];

  @override
  void initState() {
    super.initState();
    _contentFuture = _carregarConteudo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Categoria) {
      _categoriaSelecionada = arguments;
    }
    _argumentosLidos = true;
  }

  @override
  void dispose() {
    _termoController.dispose();
    _bairroController.dispose();
    super.dispose();
  }

  Future<HomeContent> _carregarConteudo() async {
    if (AppServices.instance.emDemonstracao) return HomeMockData.content;
    return AppServices.instance.carregarHome();
  }

  List<Profissional> get _resultados {
    final termo = _normalizar(_termoController.text);
    final bairro = _normalizar(_bairroController.text);

    return _profissionais
        .where((profissional) {
          final correspondeCategoria =
              _categoriaSelecionada == null ||
              profissional.categoriaIds.contains(_categoriaSelecionada!.id);
          final correspondeBairro =
              bairro.isEmpty ||
              _normalizar(profissional.bairro).contains(bairro);
          final correspondeTermo =
              termo.isEmpty ||
              _normalizar(profissional.nome).contains(termo) ||
              _normalizar(profissional.descricao).contains(termo) ||
              profissional.servicos.any(
                (servico) => _normalizar(servico).contains(termo),
              ) ||
              profissional.categoriaIds.any((categoriaId) {
                final categoria = _categoriaPorId(categoriaId);
                return categoria != null &&
                    _normalizar(categoria.nome).contains(termo);
              });

          return correspondeCategoria && correspondeBairro && correspondeTermo;
        })
        .toList(growable: false);
  }

  Categoria? _categoriaPorId(int id) {
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria;
    }
    return null;
  }

  void _selecionarCategoria(Categoria categoria) {
    setState(() {
      _categoriaSelecionada = _categoriaSelecionada?.id == categoria.id
          ? null
          : categoria;
    });
  }

  void _limparFiltros() {
    setState(() {
      _termoController.clear();
      _bairroController.clear();
      _categoriaSelecionada = null;
    });
  }

  void _abrirProfissional(Profissional profissional) {
    Navigator.pushNamed(
      context,
      AppRoutes.perfilProfissional,
      arguments: profissional,
    );
  }

  bool get _temFiltros =>
      _termoController.text.trim().isNotEmpty ||
      _bairroController.text.trim().isNotEmpty ||
      _categoriaSelecionada != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: const AppBarCustom(title: 'ConectaLar'),
      body: FutureBuilder<HomeContent>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar os profissionais.',
              onRetry: () => setState(() {
                _contentFuture = _carregarConteudo();
                _contentFuture.ignore();
              }),
            );
          }
          if (snapshot.hasData) {
            _categorias = snapshot.data!.categories;
            _profissionais = snapshot.data!.featuredProfessionals;
          }
          final resultados = _resultados;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 720) / 2
                  : AppSpace.pageGutter;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpace.lg,
                  horizontalPadding,
                  AppSpace.xxl,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Buscar profissionais',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Encontre o serviço ideal para seu lar.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textoSuave,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _FiltrosBusca(
                    termoController: _termoController,
                    bairroController: _bairroController,
                    categorias: _categorias,
                    categoriaSelecionada: _categoriaSelecionada,
                    onTextoAlterado: (_) => setState(() {}),
                    onCategoriaSelecionada: _selecionarCategoria,
                    onLimparFiltros: _temFiltros ? _limparFiltros : null,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const AsyncLoadingView(label: 'Carregando profissionais.')
                  else ...[
                    _CabecalhoResultados(total: resultados.length),
                    const SizedBox(height: AppSpace.md),
                    if (resultados.isEmpty)
                      const _EstadoVazioBusca()
                    else
                      ...resultados.map(
                        (profissional) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.md),
                          child: ProfissionalCard(
                            profissional: profissional,
                            onTap: () => _abrirProfissional(profissional),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationCustom(
        currentIndex: 1,
        onDestinationSelected: (index) =>
            navigateToMainDestination(context, index),
      ),
    );
  }
}

class _FiltrosBusca extends StatelessWidget {
  const _FiltrosBusca({
    required this.termoController,
    required this.bairroController,
    required this.categorias,
    required this.categoriaSelecionada,
    required this.onTextoAlterado,
    required this.onCategoriaSelecionada,
    required this.onLimparFiltros,
  });

  final TextEditingController termoController;
  final TextEditingController bairroController;
  final List<Categoria> categorias;
  final Categoria? categoriaSelecionada;
  final ValueChanged<String> onTextoAlterado;
  final ValueChanged<Categoria> onCategoriaSelecionada;
  final VoidCallback? onLimparFiltros;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('busca-termo'),
          controller: termoController,
          onChanged: onTextoAlterado,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Serviço ou profissional',
            hintText: 'Ex.: elétrica, limpeza, Carlos',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        TextField(
          key: const ValueKey('busca-bairro'),
          controller: bairroController,
          onChanged: onTextoAlterado,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
            labelText: 'Bairro',
            hintText: 'Ex.: Vila Nova',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (categorias.isNotEmpty) ...[
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Categorias',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.texto),
              ),
              Text(
                'Deslize para ver mais →',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final categoria in categorias)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: FilterChip(
                      label: Text(categoria.nome),
                      selected: categoriaSelecionada?.id == categoria.id,
                      onSelected: (_) => onCategoriaSelecionada(categoria),
                      showCheckmark: false,
                      avatar: categoriaSelecionada?.id == categoria.id
                          ? const Icon(Icons.check_rounded, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (categoriaSelecionada != null || onLimparFiltros != null) ...[
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: categoriaSelecionada == null
                  ? WrapAlignment.end
                  : WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.md,
              runSpacing: AppSpace.xs,
              children: [
                if (categoriaSelecionada != null)
                  Text(
                    'Categoria: ${categoriaSelecionada!.nome}',
                    style: const TextStyle(
                      color: AppColors.verdeEscuro,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                if (onLimparFiltros != null)
                  TextButton.icon(
                    onPressed: onLimparFiltros,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Limpar filtros'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CabecalhoResultados extends StatelessWidget {
  const _CabecalhoResultados({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final texto = total == 1
        ? '1 profissional encontrado'
        : '$total profissionais encontrados';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpace.md,
      runSpacing: AppSpace.sm,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Resultados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EstadoVazioBusca extends StatelessWidget {
  const _EstadoVazioBusca();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: EmptyStateView(
        title: 'Nenhum profissional corresponde a esta busca.',
        message: 'Tente ajustar o serviço, a categoria ou o bairro.',
        icon: Icons.search_off_rounded,
      ),
    );
  }
}

String _normalizar(String valor) {
  return valor
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàãâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòõôö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');
}
