import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/categoria.dart';
import '../../models/busca_estado.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
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
  final _cidadeController = TextEditingController();
  final _scrollController = ScrollController();
  late final BuscaEstado _memoria;
  late final int _revisaoMemoria;
  bool _restaurarRolagem = true;

  Categoria? _categoriaSelecionada;
  bool _argumentosLidos = false;
  late Future<HomeContent> _contentFuture;
  Timer? _debounceBusca;
  int _versaoBusca = 0;
  bool _buscaServidorAplicada = false;
  bool _buscando = false;
  String? _erroBusca;

  List<Categoria> _categorias = const [];
  List<Profissional> _profissionais = const [];

  @override
  void initState() {
    super.initState();
    _memoria = AppServices.instance.buscaEstado;
    _revisaoMemoria = _memoria.revisao;
    _termoController.text = _memoria.termo;
    _bairroController.text = _memoria.bairro;
    _cidadeController.text = _memoria.cidade;
    _categoriaSelecionada = _memoria.categoria;
    _scrollController.addListener(() {
      if (!_restaurarRolagem && _memoria.revisao == _revisaoMemoria) {
        _memoria.rolagem = _scrollController.offset;
      }
    });
    _contentFuture = _carregarConteudo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Categoria) {
      _termoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _memoria.rolagem = 0;
      _categoriaSelecionada = arguments;
    }
    _argumentosLidos = true;
    if (_temFiltros) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _agendarBuscaRemota(imediata: true);
      });
    }
  }

  @override
  void dispose() {
    if (_memoria.revisao == _revisaoMemoria) {
      _memoria
        ..termo = _termoController.text
        ..bairro = _bairroController.text
        ..cidade = _cidadeController.text
        ..categoria = _categoriaSelecionada;
      if (!_restaurarRolagem && _scrollController.hasClients) {
        _memoria.rolagem = _scrollController.offset;
      }
    }
    _scrollController.dispose();
    _debounceBusca?.cancel();
    _termoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  Future<HomeContent> _carregarConteudo() async {
    if (AppServices.instance.emDemonstracao) return HomeMockData.content;
    return AppServices.instance.carregarHome();
  }

  void _recarregarConteudo() => setState(() {
    _contentFuture = _carregarConteudo();
    _contentFuture.ignore();
  });

  List<Profissional> get _resultados {
    final termo = _normalizar(_termoController.text);
    final bairro = _normalizar(_bairroController.text);
    final cidade = _normalizar(_cidadeController.text);

    if (_buscaServidorAplicada && !AppServices.instance.emDemonstracao) {
      return _profissionais;
    }

    return _profissionais
        .where((profissional) {
          final correspondeCategoria =
              _categoriaSelecionada == null ||
              profissional.categoriaIds.contains(_categoriaSelecionada!.id);
          final correspondeBairro =
              bairro.isEmpty ||
              _normalizar(profissional.bairro).contains(bairro);
          final correspondeCidade =
              cidade.isEmpty ||
              _normalizar(profissional.cidade ?? '').contains(cidade);
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

          return correspondeCategoria &&
              correspondeBairro &&
              correspondeCidade &&
              correspondeTermo;
        })
        .toList(growable: false);
  }

  void _filtrosAlterados(String _) {
    setState(() {});
    _agendarBuscaRemota();
  }

  void _agendarBuscaRemota({bool imediata = false}) {
    if (AppServices.instance.emDemonstracao) return;

    _debounceBusca?.cancel();
    final versao = ++_versaoBusca;
    setState(() {
      _buscando = true;
      _erroBusca = null;
    });

    if (imediata) {
      _buscarProfissionais(versao);
      return;
    }
    _debounceBusca = Timer(const Duration(milliseconds: 350), () {
      _buscarProfissionais(versao);
    });
  }

  Future<void> _buscarProfissionais(int versao) async {
    try {
      final resposta = await AppServices.instance.profissionais.buscar(
        termo: _termoController.text.trim(),
        categoriaId: _categoriaSelecionada?.id.toString(),
        bairro: _bairroController.text.trim(),
        cidade: _cidadeController.text.trim(),
      );
      final lista = resposta['profissionais'];
      if (lista is! List) throw const FormatException();
      final profissionais = listFromApi(lista, profissionalFromApi);

      if (!mounted || versao != _versaoBusca) return;
      setState(() {
        _profissionais = profissionais;
        _buscaServidorAplicada = true;
        _buscando = false;
        _erroBusca = null;
      });
    } catch (_) {
      if (!mounted || versao != _versaoBusca) return;
      setState(() {
        _buscando = false;
        _erroBusca = 'Não foi possível atualizar a busca.';
      });
    }
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
    _agendarBuscaRemota();
  }

  void _limparFiltros() {
    setState(() {
      _termoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _categoriaSelecionada = null;
    });
    _agendarBuscaRemota();
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
      _cidadeController.text.trim().isNotEmpty ||
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
              onRetry: _recarregarConteudo,
            );
          }
          if (snapshot.hasData) {
            _categorias = snapshot.data!.categories;
            if (!_buscaServidorAplicada) {
              _profissionais = snapshot.data!.featuredProfessionals;
            }
          }
          final resultados = _resultados;
          if (_restaurarRolagem && snapshot.hasData && !_buscando) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients || _buscando) {
                return;
              }
              _scrollController.jumpTo(
                _memoria.rolagem.clamp(
                  0,
                  _scrollController.position.maxScrollExtent,
                ),
              );
              _restaurarRolagem = false;
            });
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 720) / 2
                  : AppSpace.pageGutter;
              return ListView(
                controller: _scrollController,
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
                  Card(
                    child: Padding(
                      padding: AppInsets.card,
                      child: _FiltrosBusca(
                        termoController: _termoController,
                        bairroController: _bairroController,
                        cidadeController: _cidadeController,
                        categorias: _categorias,
                        categoriaSelecionada: _categoriaSelecionada,
                        onTextoAlterado: _filtrosAlterados,
                        onCategoriaSelecionada: _selecionarCategoria,
                        onLimparFiltros: _temFiltros ? _limparFiltros : null,
                        categoriesLoadFailed:
                            snapshot.data?.categoriesLoadFailed ?? false,
                        onRetry: _recarregarConteudo,
                        retrying:
                            snapshot.connectionState == ConnectionState.waiting,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData)
                    const AsyncLoadingView(label: 'Carregando profissionais.')
                  else if (_erroBusca != null)
                    SectionErrorView(
                      message: _erroBusca!,
                      onRetry: () => _agendarBuscaRemota(imediata: true),
                      retrying: _buscando,
                    )
                  else if ((snapshot.data?.professionalsLoadFailed ?? false) &&
                      !_buscaServidorAplicada)
                    SectionErrorView(
                      message: 'Não foi possível carregar os profissionais.',
                      onRetry: _recarregarConteudo,
                      retrying:
                          snapshot.connectionState == ConnectionState.waiting,
                    )
                  else ...[
                    if (_buscando) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: AppSpace.sm),
                    ],
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
    required this.cidadeController,
    required this.categorias,
    required this.categoriaSelecionada,
    required this.onTextoAlterado,
    required this.onCategoriaSelecionada,
    required this.onLimparFiltros,
    required this.categoriesLoadFailed,
    required this.onRetry,
    required this.retrying,
  });

  final TextEditingController termoController;
  final TextEditingController bairroController;
  final TextEditingController cidadeController;
  final List<Categoria> categorias;
  final Categoria? categoriaSelecionada;
  final ValueChanged<String> onTextoAlterado;
  final ValueChanged<Categoria> onCategoriaSelecionada;
  final VoidCallback? onLimparFiltros;
  final bool categoriesLoadFailed;
  final VoidCallback onRetry;
  final bool retrying;

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
        TextField(
          key: const ValueKey('busca-cidade'),
          controller: cidadeController,
          onChanged: onTextoAlterado,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_city_outlined),
            labelText: 'Cidade',
            hintText: 'Ex.: Belo Horizonte',
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (categoriesLoadFailed)
          SectionErrorView(
            message: 'Não foi possível carregar as categorias.',
            onRetry: onRetry,
            retrying: retrying,
          )
        else if (categorias.isNotEmpty) ...[
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
