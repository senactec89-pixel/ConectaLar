import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/categoria.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/service_registry.dart';
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

  List<Categoria> _categorias = HomeMockData.content.categories;
  List<Profissional> _profissionais =
      HomeMockData.content.featuredProfessionals;

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
    try {
      return await AppServices.instance.carregarHome();
    } catch (_) {
      return HomeMockData.content;
    }
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
      appBar: const AppBarCustom(title: 'Buscar profissionais'),
      body: FutureBuilder<HomeContent>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _categorias = snapshot.data!.categories;
            _profissionais = snapshot.data!.featuredProfessionals;
          }
          final resultados = _resultados;
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 720) / 2
                  : 20.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  28,
                ),
                children: [
                  Text(
                    'Encontre profissionais',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pesquise por serviço, profissional ou bairro.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  _FiltrosBusca(
                    termoController: _termoController,
                    bairroController: _bairroController,
                    categorias: _categorias,
                    categoriaSelecionada: _categoriaSelecionada,
                    onTextoAlterado: (_) => setState(() {}),
                    onCategoriaSelecionada: _selecionarCategoria,
                    onLimparFiltros: _temFiltros ? _limparFiltros : null,
                  ),
                  const SizedBox(height: 22),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _CabecalhoResultados(total: resultados.length),
                    const SizedBox(height: 12),
                    if (resultados.isEmpty)
                      const _EstadoVazioBusca()
                    else
                      ...resultados.map(
                        (profissional) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10153B31),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('busca-bairro'),
              controller: bairroController,
              onChanged: onTextoAlterado,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                labelText: 'Bairro',
                hintText: 'Ex.: Vila Nova',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final categoria in categorias)
                  FilterChip(
                    label: Text(categoria.nome),
                    selected: categoriaSelecionada?.id == categoria.id,
                    onSelected: (_) => onCategoriaSelecionada(categoria),
                    showCheckmark: false,
                    avatar: categoriaSelecionada?.id == categoria.id
                        ? const Icon(Icons.check_rounded, size: 18)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onLimparFiltros,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Limpar filtros'),
              ),
            ),
          ],
        ),
      ),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            'Resultados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          texto,
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EstadoVazioBusca extends StatelessWidget {
  const _EstadoVazioBusca();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhum profissional encontrado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.texto,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tente ajustar o serviço, a categoria ou o bairro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSuave),
          ),
        ],
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
