import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/disponibilidade.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import 'avaliacoes_recebidas_page.dart';

class PerfilProfissionalPage extends StatefulWidget {
  const PerfilProfissionalPage({super.key});

  @override
  State<PerfilProfissionalPage> createState() => _PerfilProfissionalPageState();
}

class _PerfilProfissionalPageState extends State<PerfilProfissionalPage> {
  Profissional? _argumento;
  Future<_PerfilProfissionalData?>? _future;
  Future<List<Disponibilidade>>? _disponibilidadeFuture;
  bool _argumentosLidos = false;
  bool _mutandoFavorito = false;
  bool _recarregandoPerfil = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    _argumento = arguments is Profissional ? arguments : null;
    _future = _carregarPerfil();
    _future?.ignore();
    if (_argumento != null) {
      _disponibilidadeFuture = _carregarDisponibilidade(_argumento!.id);
      _disponibilidadeFuture?.ignore();
    }
    _argumentosLidos = true;
  }

  Future<List<Disponibilidade>> _carregarDisponibilidade(int id) async {
    final response = await AppServices.instance.profissionais
        .disponibilidadePublica(id);
    if (response['disponibilidades'] is! List) {
      throw const FormatException('Resposta de disponibilidade inválida.');
    }
    return listFromApi(response['disponibilidades'], disponibilidadeFromApi);
  }

  void _recarregarDisponibilidade() {
    final id = _argumento?.id;
    if (id == null) return;
    setState(() {
      _disponibilidadeFuture = _carregarDisponibilidade(id);
      _disponibilidadeFuture?.ignore();
    });
  }

  Future<_PerfilProfissionalData?> _carregarPerfil() async {
    final argumento = _argumento;
    if (argumento == null) return null;
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return _PerfilProfissionalData(
        profissional: argumento,
        favorito: ConectaLarMockStore.instance.isFavorito(argumento.id),
      );
    }

    Profissional profissional = argumento;
    bool favorito = false;
    bool favoritosIndisponiveis = false;
    if (services.auth.autenticado) {
      final tipo = services.auth.usuarioAtual?['tipo'];
      final response = await services.profissionais.obter(argumento.id);
      final perfil = response['profissional'];
      if (perfil is Map<String, dynamic>) {
        profissional = profissionalFromApi(perfil);
      }
      if (tipo == 'cliente') {
        try {
          final response = await services.clientes.consultarFavorito(
            profissional.id,
          );
          favorito = response['favorito'] == true;
        } catch (_) {
          favoritosIndisponiveis = true;
        }
      }
    } else {
      final response = await services.profissionais.obter(argumento.id);
      final perfil = response['profissional'];
      if (perfil is Map<String, dynamic>) {
        profissional = profissionalFromApi(perfil);
      }
    }

    return _PerfilProfissionalData(
      profissional: profissional,
      favorito: favorito,
      favoritosIndisponiveis: favoritosIndisponiveis,
    );
  }

  Future<void> _recarregar() async {
    final future = _carregarPerfil();
    setState(() {
      _recarregandoPerfil = true;
      _future = future;
    });
    _recarregarDisponibilidade();
    try {
      await future;
    } catch (_) {
      // O FutureBuilder apresenta a falha e mantém a opção de nova tentativa.
    } finally {
      if (mounted) setState(() => _recarregandoPerfil = false);
    }
  }

  Future<void> _alternarFavorito(_PerfilProfissionalData data) async {
    if (_mutandoFavorito) return;
    final services = AppServices.instance;
    final profissional = data.profissional;
    if (!services.auth.autenticado) {
      if (services.emDemonstracao) {
        ConectaLarMockStore.instance.toggleFavorito(profissional.id);
        setState(() {
          _future = Future.value(data.copyWith(favorito: !data.favorito));
        });
      } else {
        Navigator.pushNamed(context, AppRoutes.login);
      }
      return;
    }

    setState(() => _mutandoFavorito = true);
    try {
      if (data.favorito) {
        await services.clientes.removerFavorito(profissional.id);
      } else {
        await services.clientes.adicionarFavorito(profissional.id);
      }
      if (!mounted) return;
      setState(() {
        _future = Future.value(data.copyWith(favorito: !data.favorito));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data.favorito
                ? 'Perfil removido dos favoritos.'
                : 'Perfil salvo nos favoritos.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data.favorito
                ? 'Não foi possível remover este favorito.'
                : 'Não foi possível salvar este favorito.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _mutandoFavorito = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.instance;
    final acoesCliente =
        !services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] == 'cliente';

    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: const AppBarCustom(title: 'Perfil profissional'),
      body: AnimatedBuilder(
        animation: ConectaLarMockStore.instance,
        builder: (context, _) => FutureBuilder<_PerfilProfissionalData?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AsyncLoadingView(
                label: 'Carregando perfil profissional.',
              );
            }
            if (snapshot.hasError) {
              return AsyncErrorView(
                message: 'Não foi possível carregar este perfil.',
                onRetry: _recarregar,
              );
            }
            final data = snapshot.data;
            if (data == null) return const _PerfilIndisponivel();
            return _PerfilProfissionalContent(
              data: data,
              mutandoFavorito: _mutandoFavorito,
              recarregandoFavoritos: _recarregandoPerfil,
              disponibilidadeFuture: _disponibilidadeFuture,
              onRetryDisponibilidade: _recarregarDisponibilidade,
              onRetryFavoritos: () {
                _recarregar();
              },
              onFavoritoTap: acoesCliente && !data.favoritosIndisponiveis
                  ? () => _alternarFavorito(data)
                  : null,
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<_PerfilProfissionalData?>(
        future: _future,
        builder: (context, snapshot) {
          final profissional = snapshot.data?.profissional ?? _argumento;
          if (profissional == null || !acoesCliente) {
            return const SizedBox.shrink();
          }
          return _SolicitarServicoBar(profissional: profissional);
        },
      ),
    );
  }
}

class _PerfilProfissionalData {
  const _PerfilProfissionalData({
    required this.profissional,
    required this.favorito,
    this.favoritosIndisponiveis = false,
  });

  final Profissional profissional;
  final bool favorito;
  final bool favoritosIndisponiveis;

  _PerfilProfissionalData copyWith({bool? favorito}) {
    return _PerfilProfissionalData(
      profissional: profissional,
      favorito: favorito ?? this.favorito,
      favoritosIndisponiveis: favoritosIndisponiveis,
    );
  }
}

class _PerfilProfissionalContent extends StatefulWidget {
  const _PerfilProfissionalContent({
    required this.data,
    required this.mutandoFavorito,
    required this.onFavoritoTap,
    required this.onRetryFavoritos,
    required this.recarregandoFavoritos,
    required this.disponibilidadeFuture,
    required this.onRetryDisponibilidade,
  });

  final _PerfilProfissionalData data;
  final bool mutandoFavorito;
  final VoidCallback? onFavoritoTap;
  final VoidCallback onRetryFavoritos;
  final bool recarregandoFavoritos;
  final Future<List<Disponibilidade>>? disponibilidadeFuture;
  final VoidCallback onRetryDisponibilidade;

  @override
  State<_PerfilProfissionalContent> createState() =>
      _PerfilProfissionalContentState();
}

class _PerfilProfissionalContentState
    extends State<_PerfilProfissionalContent> {
  final _sobreKey = GlobalKey();
  final _servicosKey = GlobalKey();
  final _avaliacoesKey = GlobalKey();

  _PerfilProfissionalData get data => widget.data;
  Profissional get profissional => widget.data.profissional;

  void _irPara(GlobalKey key) {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotoAsset = profissional.fotoAsset;
    final fotoUrl = profissional.fotoUrl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final margem = constraints.maxWidth > 760
            ? (constraints.maxWidth - 720) / 2
            : AppSpace.pageGutter;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            margem,
            AppSpace.lg,
            margem,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CabecalhoPerfil(
                profissional: profissional,
                fotoAsset: fotoAsset,
                fotoUrl: fotoUrl,
                favorito: data.favorito,
                favoritoCarregando: widget.mutandoFavorito,
                onFavoritoTap: widget.onFavoritoTap,
              ),
              if (!profissional.podeReceberSolicitacoes) ...[
                const SizedBox(height: AppSpace.sm),
                const _AvisoAtendimentoIndisponivel(),
              ],
              if (data.favoritosIndisponiveis) ...[
                const SizedBox(height: AppSpace.sm),
                SectionErrorView(
                  message: 'Não foi possível verificar seus favoritos.',
                  onRetry: widget.onRetryFavoritos,
                  retrying: widget.recarregandoFavoritos,
                ),
              ],
              const SizedBox(height: AppSpace.md),
              _DestaquesPerfil(profissional: profissional),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.xs,
                children: [
                  for (final atalho in [
                    ('sobre', 'Sobre', _sobreKey),
                    ('servicos', 'Serviços', _servicosKey),
                    ('avaliacoes', 'Avaliações', _avaliacoesKey),
                  ])
                    TextButton(
                      key: ValueKey('perfil-atalho-${atalho.$1}'),
                      onPressed: () => _irPara(atalho.$3),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(atalho.$2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              _SecaoPerfil(
                key: _sobreKey,
                title: 'Apresentação',
                child: Text(
                  profissional.descricao.trim().isEmpty
                      ? 'Apresentação não informada.'
                      : profissional.descricao,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _SecaoPerfil(
                key: _servicosKey,
                title: 'Serviços oferecidos',
                child: _ServicosPerfil(profissional: profissional),
              ),
              const SizedBox(height: AppSpace.lg),
              _SecaoPerfil(
                title: 'Atendimento',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLinha(
                      icon: Icons.location_on_outlined,
                      text: _regiaoProfissional(profissional),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _InfoLinha(
                      icon: Icons.payments_outlined,
                      text: _precoTexto(profissional.precoInicial),
                    ),
                    const SizedBox(height: AppSpace.md),
                    const _InfoLinha(
                      icon: Icons.handshake_outlined,
                      text: 'Pagamento combinado diretamente entre as partes',
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Antes de solicitar',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'A solicitação será enviada ao prestador e começará aguardando '
                      'resposta. O serviço só fica agendado após aceite válido.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _SecaoPerfil(
                title: 'Disponibilidade semanal',
                child: _DisponibilidadePublica(
                  future: widget.disponibilidadeFuture,
                  onRetry: widget.onRetryDisponibilidade,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              _SecaoPerfil(
                key: _avaliacoesKey,
                title: 'Avaliações de clientes',
                emCard: false,
                child: AvaliacoesPublicadasView(
                  profissionalId: profissional.id,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CabecalhoPerfil extends StatelessWidget {
  const _CabecalhoPerfil({
    required this.profissional,
    required this.fotoAsset,
    required this.fotoUrl,
    required this.favorito,
    required this.favoritoCarregando,
    required this.onFavoritoTap,
  });

  final Profissional profissional;
  final String? fotoAsset;
  final String? fotoUrl;
  final bool favorito;
  final bool favoritoCarregando;
  final VoidCallback? onFavoritoTap;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(16) > 24;
    final temFoto =
        (fotoAsset?.isNotEmpty ?? false) || (fotoUrl?.isNotEmpty ?? false);
    final avatar = _FotoPerfil(
      fotoAsset: fotoAsset,
      fotoUrl: fotoUrl,
      nome: profissional.nome,
    );
    final identificacao = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profissional.nome,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.texto,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        _InfoLinha(
          icon: Icons.location_on_outlined,
          text: _regiaoProfissional(profissional),
        ),
      ],
    );
    final favoritoButton = onFavoritoTap == null
        ? null
        : IconButton(
            key: ValueKey('perfil-favorito-${profissional.id}'),
            tooltip: favorito ? 'Remover favorito' : 'Salvar favorito',
            onPressed: favoritoCarregando ? null : onFavoritoTap,
            icon: favoritoCarregando
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    favorito ? Icons.favorite : Icons.favorite_border,
                    color: favorito ? const Color(0xFFC53030) : AppColors.texto,
                  ),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (temFoto)
            _FotoPerfil(
              fotoAsset: fotoAsset,
              fotoUrl: fotoUrl,
              nome: profissional.nome,
              destaque: true,
            ),
          Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!temFoto) avatar,
                    if (!temFoto && textoAmpliado)
                      const Spacer()
                    else if (!temFoto)
                      const SizedBox(width: AppSpace.lg),
                    if (temFoto || !textoAmpliado)
                      Expanded(child: identificacao),
                    ?favoritoButton,
                  ],
                ),
                if (!temFoto && textoAmpliado) ...[
                  const SizedBox(height: AppSpace.md),
                  identificacao,
                ],
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (profissional.notaMedia == null)
                      const _ResumoChip(
                        icon: Icons.star_border_rounded,
                        text: 'Ainda sem avaliações',
                      )
                    else
                      _ResumoChip(
                        icon: Icons.star_rounded,
                        text:
                            '${profissional.notaMedia!.toStringAsFixed(1).replaceAll('.', ',')} · '
                            '${profissional.quantidadeAvaliacoes ?? 0} '
                            '${profissional.quantidadeAvaliacoes == 1 ? 'avaliação' : 'avaliações'}',
                      ),
                    if (profissional.verificado)
                      const _ResumoChip(
                        icon: Icons.verified_rounded,
                        text: 'Documentos verificados',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestaquesPerfil extends StatelessWidget {
  const _DestaquesPerfil({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final servicos = profissional.ofertas.isNotEmpty
        ? profissional.ofertas.length
        : profissional.servicos.length;
    return Card(
      key: const ValueKey('perfil-resumo'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final preco = _DestaqueInfo(
              icon: Icons.payments_outlined,
              label: 'Preço inicial',
              value: profissional.precoInicial == null
                  ? 'Sob consulta'
                  : 'R\$ ${profissional.precoInicial!.toStringAsFixed(2).replaceAll('.', ',')}',
            );
            final ofertas = _DestaqueInfo(
              icon: Icons.home_repair_service_outlined,
              label: 'Serviços',
              value:
                  '$servicos ${servicos == 1 ? 'oferta ativa' : 'ofertas ativas'}',
            );
            final empilhar =
                constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            if (empilhar) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  preco,
                  const Divider(height: AppSpace.xl, color: AppColors.borda),
                  ofertas,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: preco),
                  const VerticalDivider(
                    width: AppSpace.xl,
                    color: AppColors.borda,
                  ),
                  Expanded(child: ofertas),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DestaqueInfo extends StatelessWidget {
  const _DestaqueInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.verde),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _SecaoPerfil extends StatelessWidget {
  const _SecaoPerfil({
    required this.title,
    required this.child,
    this.emCard = true,
    super.key,
  });

  final String title;
  final Widget child;
  final bool emCard;

  @override
  Widget build(BuildContext context) {
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpace.md),
        child,
      ],
    );
    return emCard
        ? Card(
            child: Padding(padding: AppInsets.card, child: conteudo),
          )
        : conteudo;
  }
}

class _ServicosPerfil extends StatelessWidget {
  const _ServicosPerfil({required this.profissional});
  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final itens = profissional.ofertas.isNotEmpty
        ? [
            for (final oferta in profissional.ofertas)
              (oferta.nome, oferta.precoInicial),
          ]
        : [for (final nome in profissional.servicos) (nome, null)];
    if (itens.isEmpty) {
      return const Text('Este perfil ainda não apresenta serviços oferecidos.');
    }
    return Column(
      children: [
        for (var index = 0; index < itens.length; index++) ...[
          if (index > 0)
            const Divider(height: AppSpace.xl, color: AppColors.borda),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.home_repair_service_outlined,
                color: AppColors.verdeEscuro,
                size: 20,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itens[index].$1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      _precoTexto(itens[index].$2),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DisponibilidadePublica extends StatelessWidget {
  const _DisponibilidadePublica({required this.future, required this.onRetry});

  final Future<List<Disponibilidade>>? future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Disponibilidade>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppSpace.sm),
              Expanded(child: Text('Consultando horários informados…')),
            ],
          );
        }
        if (snapshot.hasError) {
          return SectionErrorView(
            message: 'Não foi possível consultar os horários informados.',
            onRetry: onRetry,
          );
        }
        final horarios =
            (snapshot.data ?? const <Disponibilidade>[])
                .where((item) => item.ativo)
                .toList()
              ..sort((a, b) {
                final diaA = (a.diaSemana + 6) % 7;
                final diaB = (b.diaSemana + 6) % 7;
                final diferenca = diaA.compareTo(diaB);
                return diferenca == 0
                    ? a.horaInicio.compareTo(b.horaInicio)
                    : diferenca;
              });
        if (horarios.isEmpty) {
          return const Text('Este perfil ainda não informa horários semanais.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final horario in horarios)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.verdeClaro,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: AppSpace.sm,
                      ),
                      child: Text(
                        '${_diaDisponibilidade(horario.diaSemana)} · '
                        '${horario.horaInicio}–${horario.horaFim}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'Horários informados pelo prestador. Eles podem mudar e não '
              'garantem vaga nem agendamento.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textoSuave),
            ),
          ],
        );
      },
    );
  }
}

String _diaDisponibilidade(int dia) => switch (dia) {
  0 => 'Domingo',
  1 => 'Segunda-feira',
  2 => 'Terça-feira',
  3 => 'Quarta-feira',
  4 => 'Quinta-feira',
  5 => 'Sexta-feira',
  6 => 'Sábado',
  _ => 'Dia informado',
};

class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({
    required this.fotoAsset,
    required this.fotoUrl,
    required this.nome,
    this.destaque = false,
  });
  final String? fotoAsset;
  final String? fotoUrl;
  final String nome;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.trim().characters.first;
    final fallback = ColoredBox(
      color: AppColors.verdeClaro,
      child: Center(
        child: Text(
          inicial.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.verde),
        ),
      ),
    );
    final imagem = fotoUrl != null
        ? Image.network(
            fotoUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'Foto de $nome',
            errorBuilder: (_, _, _) => fallback,
          )
        : fotoAsset == null
        ? fallback
        : Image.asset(
            fotoAsset!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'Foto de $nome',
            errorBuilder: (_, _, _) => fallback,
          );
    if (destaque) {
      return AspectRatio(aspectRatio: 16 / 9, child: imagem);
    }
    return ClipOval(child: SizedBox.square(dimension: 84, child: imagem));
  }
}

class _ResumoChip extends StatelessWidget {
  const _ResumoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.verdeClaro,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.verde),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  const _InfoLinha({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.verdeEscuro, size: 20),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.texto),
          ),
        ),
      ],
    );
  }
}

class _SolicitarServicoBar extends StatelessWidget {
  const _SolicitarServicoBar({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borda)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!profissional.podeReceberSolicitacoes) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.textoSuave,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Não recebe novos pedidos agora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Por que o atendimento está indisponível?',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        scrollable: true,
                        title: const Text('Atendimento indisponível'),
                        content: const Text(
                          'A liberação de novas solicitações depende das verificações de segurança da plataforma. Um documento aprovado sozinho não libera atendimentos.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Entendi'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ],
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('perfil-solicitar-servico'),
                onPressed: !profissional.podeReceberSolicitacoes
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.solicitarServico,
                        arguments: profissional,
                      ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(
                  profissional.podeReceberSolicitacoes
                      ? 'Solicitar atendimento'
                      : 'Atendimento indisponível',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoAtendimentoIndisponivel extends StatelessWidget {
  const _AvisoAtendimentoIndisponivel();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.verdePastel,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.verdeEscuro,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atendimento indisponível',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'A liberação de novas solicitações depende das '
                    'verificações de segurança da plataforma.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfilIndisponivel extends StatelessWidget {
  const _PerfilIndisponivel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Não foi possível carregar este perfil.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _precoTexto(double? preco) {
  if (preco == null) return 'Preço inicial sob consulta';
  return 'A partir de R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
}

String _regiaoProfissional(Profissional profissional) {
  final bairro = profissional.bairro.trim();
  final cidade = profissional.cidade?.trim() ?? '';
  final uf = profissional.uf?.trim() ?? '';
  final cidadeUf = [cidade, uf].where((parte) => parte.isNotEmpty).join('/');
  final partes = [bairro, cidadeUf].where((parte) => parte.isNotEmpty);
  return partes.isEmpty
      ? 'Região de atendimento não informada'
      : 'Atende em ${partes.join(' · ')}';
}
