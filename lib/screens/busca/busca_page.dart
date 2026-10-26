import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/categoria.dart';
import '../../models/busca_estado.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
import '../../services/api_page.dart';
import '../../services/device_location_service.dart';
import '../../services/service_registry.dart';
import '../../utils/constants.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/profissional_card.dart';
import '../profissional/comparar_profissionais_page.dart';
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
  final _termoFocusNode = FocusNode();
  final _bairroFocusNode = FocusNode();
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
  bool _carregandoMais = false;
  int _paginaBusca = 1;
  int _totalBusca = 0;
  String? _erroBusca;
  DevicePosition? _posicao;
  DeviceLocationFailure? _falhaLocalizacao;
  String? _erroLocalizacao;
  bool _obtendoLocalizacao = false;
  bool _mostrarMapa = false;
  int _raioKm = 25;

  List<Categoria> _categorias = const [];
  List<Profissional> _profissionais = const [];
  final List<Profissional> _comparacao = [];

  static const int _limiteComparacao = 2;
  static const int _limitePaginaBusca = 20;

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
    } else if (arguments is CampoBuscaInicial) {
      if (arguments == CampoBuscaInicial.bairro) {
        _memoria.localizacaoExpandida = true;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (arguments == CampoBuscaInicial.bairro) {
          _bairroFocusNode.requestFocus();
        } else {
          _termoFocusNode.requestFocus();
        }
      });
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
    _termoFocusNode.dispose();
    _bairroFocusNode.dispose();
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
      _carregandoMais = false;
      _paginaBusca = 1;
      _totalBusca = 0;
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

  Future<void> _buscarProfissionais(
    int versao, {
    int pagina = 1,
    bool anexar = false,
  }) async {
    try {
      final posicao = _posicao;
      final resposta = posicao == null
          ? await AppServices.instance.profissionais.buscar(
              termo: _termoController.text.trim(),
              categoriaId: _categoriaSelecionada?.id.toString(),
              bairro: _bairroController.text.trim(),
              cidade: _cidadeController.text.trim(),
              pagina: pagina,
              limite: _limitePaginaBusca,
            )
          : await AppServices.instance.profissionais.buscarPorDistancia(
              latitude: _coordenadaBusca(posicao.latitude),
              longitude: _coordenadaBusca(posicao.longitude),
              raioKm: _raioKm,
              termo: _termoController.text.trim(),
              categoriaId: _categoriaSelecionada?.id.toString(),
              pagina: pagina,
              limite: _limitePaginaBusca,
            );
      final paginaResposta = apiPageFromResponse<Profissional>(
        resposta,
        itemsKey: 'profissionais',
        mapper: profissionalFromApi,
        fallbackPage: pagina,
      );

      if (!mounted || versao != _versaoBusca) return;
      setState(() {
        _profissionais = anexar
            ? [..._profissionais, ...paginaResposta.items]
            : paginaResposta.items;
        _paginaBusca = paginaResposta.page;
        _totalBusca = paginaResposta.total;
        _buscaServidorAplicada = true;
        _buscando = false;
        _carregandoMais = false;
        _erroBusca = null;
      });
    } catch (_) {
      if (!mounted || versao != _versaoBusca) return;
      if (anexar) {
        setState(() {
          _buscando = false;
          _carregandoMais = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel carregar mais resultados.'),
          ),
        );
        return;
      }
      setState(() {
        _buscando = false;
        _erroBusca = 'Não foi possível atualizar a busca.';
      });
    }
  }

  void _carregarMaisProfissionais() {
    if (_buscando || _paginaBusca * _limitePaginaBusca >= _totalBusca) return;
    final versao = _versaoBusca;
    setState(() {
      _buscando = true;
      _carregandoMais = true;
    });
    _buscarProfissionais(versao, pagina: _paginaBusca + 1, anexar: true);
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

  List<String> _servicosDaCategoria(List<Profissional> profissionais) {
    final categoria = _categoriaSelecionada;
    if (categoria == null || _termoController.text.trim().isNotEmpty) {
      return const [];
    }
    final nomesCategorias =
        _categorias.map((item) => _normalizar(item.nome)).toSet()
          ..add(_normalizar(categoria.nome));
    final servicos = <String, String>{};
    for (final profissional in profissionais) {
      final nomes = profissional.ofertas.isNotEmpty
          ? profissional.ofertas
                .where((oferta) => oferta.categoriaId == categoria.id)
                .map((oferta) => oferta.nome)
          : profissional.categoriaIds.length == 1 &&
                profissional.categoriaIds.single == categoria.id
          ? profissional.servicos
          : const <String>[];
      for (final nome in nomes) {
        final rotulo = nome.trim();
        final chave = _normalizar(rotulo);
        if (chave.isEmpty || nomesCategorias.contains(chave)) continue;
        servicos.putIfAbsent(chave, () => rotulo);
        if (servicos.length == 6) return servicos.values.toList();
      }
    }
    return servicos.values.toList();
  }

  void _buscarServicoDaCategoria(String nome) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _termoController.text = nome);
    _agendarBuscaRemota(imediata: true);
  }

  void _limparFiltros() {
    setState(() {
      _termoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _categoriaSelecionada = null;
      _posicao = null;
      _erroLocalizacao = null;
      _falhaLocalizacao = null;
      _mostrarMapa = false;
      _raioKm = 25;
    });
    _agendarBuscaRemota();
  }

  Future<void> _usarMinhaLocalizacao() async {
    if (_obtendoLocalizacao) return;
    setState(() {
      _obtendoLocalizacao = true;
      _erroLocalizacao = null;
      _falhaLocalizacao = null;
    });
    try {
      final posicao = await AppServices.instance.deviceLocation
          .currentPosition();
      if (!mounted) return;
      setState(() {
        _posicao = posicao;
        _bairroController.clear();
        _cidadeController.clear();
        _memoria.localizacaoExpandida = false;
      });
      _agendarBuscaRemota(imediata: true);
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _erroLocalizacao = error.message;
        _falhaLocalizacao = error.failure;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroLocalizacao =
            'Nao foi possivel obter sua localizacao. Tente novamente.';
        _falhaLocalizacao = DeviceLocationFailure.unavailable;
      });
    } finally {
      if (mounted) setState(() => _obtendoLocalizacao = false);
    }
  }

  void _removerMinhaLocalizacao() {
    setState(() {
      _posicao = null;
      _erroLocalizacao = null;
      _falhaLocalizacao = null;
      _mostrarMapa = false;
    });
    _agendarBuscaRemota(imediata: true);
  }

  void _alterarRaio(int raio) {
    if (_raioKm == raio) return;
    setState(() => _raioKm = raio);
    _agendarBuscaRemota(imediata: true);
  }

  Future<void> _abrirConfiguracoesLocalizacao() async {
    final falha = _falhaLocalizacao;
    if (falha == DeviceLocationFailure.permissionDeniedForever) {
      await AppServices.instance.deviceLocation.openAppSettings();
    } else if (falha == DeviceLocationFailure.serviceDisabled) {
      await AppServices.instance.deviceLocation.openLocationSettings();
    }
  }

  void _abrirProfissional(Profissional profissional) {
    Navigator.pushNamed(
      context,
      AppRoutes.perfilProfissional,
      arguments: profissional,
    );
  }

  void _alternarComparacao(Profissional profissional) {
    final indice = _comparacao.indexWhere(
      (selecionado) => selecionado.id == profissional.id,
    );
    if (indice >= 0) {
      setState(() => _comparacao.removeAt(indice));
      return;
    }
    if (_comparacao.length >= _limiteComparacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compare até dois profissionais por vez.'),
        ),
      );
      return;
    }
    setState(() => _comparacao.add(profissional));
  }

  void _abrirComparacao() {
    if (_comparacao.length < _limiteComparacao) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompararProfissionaisPage(
          profissionais: List<Profissional>.unmodifiable(_comparacao),
        ),
      ),
    );
  }

  bool get _temFiltros =>
      _termoController.text.trim().isNotEmpty ||
      _bairroController.text.trim().isNotEmpty ||
      _cidadeController.text.trim().isNotEmpty ||
      _categoriaSelecionada != null ||
      _posicao != null;

  bool get _podeComparar =>
      AppServices.instance.auth.usuarioAtual?['tipo'] == 'cliente';

  bool get _mapaDisponivel =>
      AppConstants.googleMapsEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

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
              _totalBusca = snapshot.data!.featuredProfessionalsTotal;
            }
          }
          final resultados = _resultados;
          final servicosDaCategoria = _servicosDaCategoria(resultados);
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
                        termoFocusNode: _termoFocusNode,
                        bairroController: _bairroController,
                        bairroFocusNode: _bairroFocusNode,
                        cidadeController: _cidadeController,
                        localizacaoExpandida: _memoria.localizacaoExpandida,
                        onAlternarLocalizacao: () => setState(
                          () => _memoria.localizacaoExpandida =
                              !_memoria.localizacaoExpandida,
                        ),
                        posicao: _posicao,
                        raioKm: _raioKm,
                        obtendoLocalizacao: _obtendoLocalizacao,
                        erroLocalizacao: _erroLocalizacao,
                        falhaLocalizacao: _falhaLocalizacao,
                        onUsarMinhaLocalizacao: _usarMinhaLocalizacao,
                        onRemoverMinhaLocalizacao: _removerMinhaLocalizacao,
                        onRaioAlterado: _alterarRaio,
                        onAbrirConfiguracoes: _abrirConfiguracoesLocalizacao,
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
                  else if (_erroBusca != null && resultados.isEmpty)
                    SectionErrorView(
                      message: _erroBusca!,
                      onRetry: () => _agendarBuscaRemota(imediata: true),
                      retrying: _buscando,
                    )
                  else if (_erroBusca == null &&
                      (snapshot.data?.professionalsLoadFailed ?? false) &&
                      !_buscaServidorAplicada)
                    SectionErrorView(
                      message: 'Não foi possível carregar os profissionais.',
                      onRetry: _recarregarConteudo,
                      retrying:
                          snapshot.connectionState == ConnectionState.waiting,
                    )
                  else ...[
                    if (_erroBusca != null) ...[
                      SectionErrorView(
                        message:
                            'Não foi possível atualizar a busca. Os resultados abaixo são da pesquisa anterior e podem não corresponder aos filtros atuais.',
                        onRetry: () => _agendarBuscaRemota(imediata: true),
                        retrying: _buscando,
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    if (_buscando) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: AppSpace.sm),
                    ],
                    if (servicosDaCategoria.isNotEmpty) ...[
                      _ServicosDaCategoria(
                        servicos: servicosDaCategoria,
                        onSelecionar: _buscarServicoDaCategoria,
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                    _CabecalhoResultados(
                      total: _buscaServidorAplicada
                          ? _totalBusca
                          : (snapshot.data?.featuredProfessionalsTotal ??
                                resultados.length),
                      mapaDisponivel: _mapaDisponivel,
                      mostrarMapa: _mostrarMapa,
                      onModoAlterado: (mapa) =>
                          setState(() => _mostrarMapa = mapa),
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (resultados.isEmpty)
                      const _EstadoVazioBusca()
                    else if (_mostrarMapa && _mapaDisponivel)
                      _MapaResultados(
                        profissionais: resultados,
                        posicao: _posicao,
                        raioKm: _raioKm,
                        onProfissionalTap: _abrirProfissional,
                      )
                    else
                      ...resultados.map(
                        (profissional) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.md),
                          child: ProfissionalCard(
                            profissional: profissional,
                            onTap: () => _abrirProfissional(profissional),
                            trailingAction: _podeComparar
                                ? Semantics(
                                    button: true,
                                    label:
                                        _comparacao.any(
                                          (item) => item.id == profissional.id,
                                        )
                                        ? 'Remover ${profissional.nome} da comparação'
                                        : 'Adicionar ${profissional.nome} à comparação',
                                    child: IconButton.filledTonal(
                                      key: ValueKey(
                                        'busca-comparar-${profissional.id}',
                                      ),
                                      tooltip:
                                          _comparacao.any(
                                            (item) =>
                                                item.id == profissional.id,
                                          )
                                          ? 'Remover da comparação'
                                          : 'Adicionar à comparação',
                                      onPressed: () =>
                                          _alternarComparacao(profissional),
                                      icon: Icon(
                                        _comparacao.any(
                                              (item) =>
                                                  item.id == profissional.id,
                                            )
                                            ? Icons.check_rounded
                                            : Icons.compare_arrows_rounded,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    if (_erroBusca == null &&
                        ((_buscaServidorAplicada &&
                                _paginaBusca * _limitePaginaBusca <
                                    _totalBusca) ||
                            (!_buscaServidorAplicada &&
                                !AppServices.instance.emDemonstracao &&
                                (snapshot.data?.featuredProfessionalsHasMore ??
                                    false)))) ...[
                      const SizedBox(height: AppSpace.sm),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _buscando
                              ? null
                              : _carregarMaisProfissionais,
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
                  ],
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_comparacao.isNotEmpty)
            _BarraComparacao(
              profissionais: _comparacao,
              limite: _limiteComparacao,
              onRemover: (profissional) => _alternarComparacao(profissional),
              onLimpar: () => setState(_comparacao.clear),
              onComparar: _abrirComparacao,
            ),
          BottomNavigationCustom(
            currentIndex: 1,
            onDestinationSelected: (index) =>
                navigateToMainDestination(context, index),
          ),
        ],
      ),
    );
  }
}

class _BarraComparacao extends StatelessWidget {
  const _BarraComparacao({
    required this.profissionais,
    required this.limite,
    required this.onRemover,
    required this.onLimpar,
    required this.onComparar,
  });

  final List<Profissional> profissionais;
  final int limite;
  final ValueChanged<Profissional> onRemover;
  final VoidCallback onLimpar;
  final VoidCallback onComparar;

  @override
  Widget build(BuildContext context) {
    final faltam = limite - profissionais.length;
    return Material(
      key: const ValueKey('busca-barra-comparacao'),
      color: AppColors.branco,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.pageGutter,
          AppSpace.sm,
          AppSpace.pageGutter,
          AppSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${profissionais.length} de $limite selecionados',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('busca-comparacao-limpar'),
                  onPressed: onLimpar,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Limpar'),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                for (final profissional in profissionais)
                  InputChip(
                    key: ValueKey('busca-comparacao-chip-${profissional.id}'),
                    label: Text(profissional.nome),
                    onDeleted: () => onRemover(profissional),
                  ),
              ],
            ),
            if (faltam > 0) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                'Selecione mais $faltam para comparar.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textoSuave),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
            FilledButton.icon(
              key: const ValueKey('busca-comparacao-abrir'),
              onPressed: profissionais.length == limite ? onComparar : null,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Comparar profissionais'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltrosBusca extends StatelessWidget {
  const _FiltrosBusca({
    required this.termoController,
    required this.termoFocusNode,
    required this.bairroController,
    required this.bairroFocusNode,
    required this.cidadeController,
    required this.localizacaoExpandida,
    required this.onAlternarLocalizacao,
    required this.posicao,
    required this.raioKm,
    required this.obtendoLocalizacao,
    required this.erroLocalizacao,
    required this.falhaLocalizacao,
    required this.onUsarMinhaLocalizacao,
    required this.onRemoverMinhaLocalizacao,
    required this.onRaioAlterado,
    required this.onAbrirConfiguracoes,
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
  final FocusNode termoFocusNode;
  final TextEditingController bairroController;
  final FocusNode bairroFocusNode;
  final TextEditingController cidadeController;
  final bool localizacaoExpandida;
  final VoidCallback onAlternarLocalizacao;
  final DevicePosition? posicao;
  final int raioKm;
  final bool obtendoLocalizacao;
  final String? erroLocalizacao;
  final DeviceLocationFailure? falhaLocalizacao;
  final VoidCallback onUsarMinhaLocalizacao;
  final VoidCallback onRemoverMinhaLocalizacao;
  final ValueChanged<int> onRaioAlterado;
  final VoidCallback onAbrirConfiguracoes;
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
          focusNode: termoFocusNode,
          onChanged: onTextoAlterado,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: 'Serviço ou profissional',
            hintText: 'Ex.: elétrica, limpeza, Carlos',
            suffixIcon: posicao == null
                ? IconButton(
                    key: const ValueKey('busca-usar-gps'),
                    tooltip: 'Usar minha localização',
                    onPressed: obtendoLocalizacao
                        ? null
                        : onUsarMinhaLocalizacao,
                    icon: obtendoLocalizacao
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (posicao == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('busca-localizacao-toggle'),
              onPressed: onAlternarLocalizacao,
              icon: Icon(
                localizacaoExpandida
                    ? Icons.expand_less_rounded
                    : Icons.location_on_outlined,
              ),
              label: Text(
                localizacaoExpandida
                    ? 'Ocultar bairro e cidade'
                    : 'Filtrar por bairro e cidade',
              ),
            ),
          )
        else
          _GpsAtivo(
            raioKm: raioKm,
            onRaioAlterado: onRaioAlterado,
            onRemover: onRemoverMinhaLocalizacao,
          ),
        if (erroLocalizacao != null) ...[
          const SizedBox(height: AppSpace.sm),
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(erroLocalizacao!)),
                  if (falhaLocalizacao ==
                          DeviceLocationFailure.permissionDeniedForever ||
                      falhaLocalizacao == DeviceLocationFailure.serviceDisabled)
                    IconButton(
                      key: const ValueKey('busca-configuracao-gps'),
                      tooltip: 'Abrir configurações',
                      onPressed: onAbrirConfiguracoes,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (posicao == null &&
            !localizacaoExpandida &&
            (bairroController.text.trim().isNotEmpty ||
                cidadeController.text.trim().isNotEmpty)) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            [
              bairroController.text.trim(),
              cidadeController.text.trim(),
            ].where((valor) => valor.isNotEmpty).join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.verdeEscuro),
          ),
        ],
        if (posicao == null && localizacaoExpandida) ...[
          const SizedBox(height: AppSpace.sm),
          TextField(
            key: const ValueKey('busca-bairro'),
            controller: bairroController,
            focusNode: bairroFocusNode,
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
        ],
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

class _GpsAtivo extends StatelessWidget {
  const _GpsAtivo({
    required this.raioKm,
    required this.onRaioAlterado,
    required this.onRemover,
  });

  final int raioKm;
  final ValueChanged<int> onRaioAlterado;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.verdeClaro,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: AppColors.verde),
                const SizedBox(width: AppSpace.sm),
                const Expanded(
                  child: Text(
                    'Localização atual',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const ValueKey('busca-remover-gps'),
                  tooltip: 'Remover localização',
                  onPressed: onRemover,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Usada somente nesta busca e não salva no seu perfil.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Distância máxima',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final raio in const [5, 10, 25, 50])
                  ChoiceChip(
                    key: ValueKey('busca-raio-$raio'),
                    label: Text('$raio km'),
                    selected: raioKm == raio,
                    onSelected: (_) => onRaioAlterado(raio),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicosDaCategoria extends StatelessWidget {
  const _ServicosDaCategoria({
    required this.servicos,
    required this.onSelecionar,
  });

  final List<String> servicos;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.verdePastel,
    borderRadius: BorderRadius.circular(AppRadii.card),
    child: Padding(
      padding: AppInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serviços nesta categoria',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Ofertas dos profissionais encontrados. Toque para buscar pelo serviço.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              for (final servico in servicos)
                ActionChip(
                  key: ValueKey('busca-servico-$servico'),
                  avatar: const Icon(Icons.search_rounded, size: 18),
                  label: Text(servico),
                  onPressed: () => onSelecionar(servico),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CabecalhoResultados extends StatelessWidget {
  const _CabecalhoResultados({
    required this.total,
    required this.mapaDisponivel,
    required this.mostrarMapa,
    required this.onModoAlterado,
  });

  final int total;
  final bool mapaDisponivel;
  final bool mostrarMapa;
  final ValueChanged<bool> onModoAlterado;

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
        if (mapaDisponivel)
          IconButton(
            key: const ValueKey('busca-modo-lista'),
            tooltip: 'Ver lista',
            isSelected: !mostrarMapa,
            style: IconButton.styleFrom(
              backgroundColor: !mostrarMapa
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onPressed: () => onModoAlterado(false),
            icon: const Icon(Icons.view_list_rounded),
          ),
        if (mapaDisponivel)
          IconButton(
            key: const ValueKey('busca-modo-mapa'),
            tooltip: 'Ver mapa',
            isSelected: mostrarMapa,
            style: IconButton.styleFrom(
              backgroundColor: mostrarMapa
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onPressed: () => onModoAlterado(true),
            icon: const Icon(Icons.map_outlined),
          ),
      ],
    );
  }
}

class _MapaResultados extends StatelessWidget {
  const _MapaResultados({
    required this.profissionais,
    required this.posicao,
    required this.raioKm,
    required this.onProfissionalTap,
  });

  final List<Profissional> profissionais;
  final DevicePosition? posicao;
  final int raioKm;
  final ValueChanged<Profissional> onProfissionalTap;

  @override
  Widget build(BuildContext context) {
    final localizados = profissionais
        .where(
          (item) =>
              item.latitudeAproximada != null &&
              item.longitudeAproximada != null,
        )
        .toList(growable: false);
    if (localizados.isEmpty) {
      return const EmptyStateView(
        title: 'Nenhuma localização disponível no mapa.',
        message: 'Use a lista para consultar os profissionais encontrados.',
        icon: Icons.location_off_outlined,
      );
    }

    final centro = posicao == null
        ? _centroProfissionais(localizados)
        : LatLng(posicao!.latitude, posicao!.longitude);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.map_outlined, color: AppColors.verdeEscuro),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profissionais no mapa',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        localizados.length == 1
                            ? '1 profissional com região aproximada'
                            : '${localizados.length} profissionais com região aproximada',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            key: const ValueKey('busca-mapa'),
            height: 320,
            child: GoogleMap(
              key: ValueKey(
                'map-${centro.latitude}-${centro.longitude}-${localizados.length}',
              ),
              initialCameraPosition: CameraPosition(
                target: centro,
                zoom: posicao == null ? 10.5 : _zoomParaRaio(raioKm),
              ),
              markers: {
                if (posicao != null)
                  Marker(
                    markerId: const MarkerId('minha-localizacao'),
                    position: centro,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      HSVColor.fromColor(AppColors.verdeEscuro).hue,
                    ),
                    infoWindow: const InfoWindow(
                      title: 'Sua região aproximada',
                    ),
                  ),
                for (final profissional in localizados)
                  Marker(
                    markerId: MarkerId('profissional-${profissional.id}'),
                    position: LatLng(
                      profissional.latitudeAproximada!,
                      profissional.longitudeAproximada!,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      HSVColor.fromColor(AppColors.verde).hue,
                    ),
                    infoWindow: InfoWindow(
                      title: profissional.nome,
                      snippet: profissional.distanciaKm == null
                          ? profissional.bairro
                          : '${profissional.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                      onTap: () => onProfissionalTap(profissional),
                    ),
                  ),
              },
              circles: {
                if (posicao != null)
                  Circle(
                    circleId: const CircleId('raio-busca'),
                    center: centro,
                    radius: raioKm * 1000,
                    fillColor: AppColors.verde.withValues(alpha: 0.08),
                    strokeColor: AppColors.verde.withValues(alpha: 0.55),
                    strokeWidth: 2,
                  ),
              },
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              zoomGesturesEnabled: true,
            ),
          ),
          Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.lg,
                  runSpacing: AppSpace.sm,
                  children: [
                    const _LegendaMapa(
                      cor: AppColors.verde,
                      titulo: 'Profissional',
                    ),
                    if (posicao != null)
                      const _LegendaMapa(
                        cor: AppColors.verdeEscuro,
                        titulo: 'Sua região',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'As posições são aproximadas. Toque em um marcador para consultar o perfil.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LatLng _centroProfissionais(List<Profissional> profissionais) {
    final latitude =
        profissionais
            .map((item) => item.latitudeAproximada!)
            .reduce((a, b) => a + b) /
        profissionais.length;
    final longitude =
        profissionais
            .map((item) => item.longitudeAproximada!)
            .reduce((a, b) => a + b) /
        profissionais.length;
    return LatLng(latitude, longitude);
  }

  double _zoomParaRaio(int raioKm) => switch (raioKm) {
    <= 5 => 12.5,
    <= 10 => 11.5,
    <= 25 => 10.5,
    _ => 9.5,
  };
}

class _LegendaMapa extends StatelessWidget {
  const _LegendaMapa({required this.cor, required this.titulo});

  final Color cor;
  final String titulo;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.location_on_rounded, size: 18, color: cor),
      const SizedBox(width: AppSpace.xs),
      Text(titulo, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
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

double _coordenadaBusca(double value) =>
    (value * 10000).roundToDouble() / 10000;
