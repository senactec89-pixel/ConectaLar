import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/profissional.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import 'avaliacoes_recebidas_page.dart';

class PerfilProfissionalPage extends StatelessWidget {
  const PerfilProfissionalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final profissional = arguments is Profissional ? arguments : null;
    final store = ConectaLarMockStore.instance;
    final services = AppServices.instance;
    final acoesCliente =
        !services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] == 'cliente';

    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: const AppBarCustom(title: 'Perfil profissional'),
      body: profissional == null
          ? const _PerfilIndisponivel()
          : AnimatedBuilder(
              animation: store,
              builder: (context, _) => _PerfilProfissionalContent(
                profissional: profissional,
                store: store,
              ),
            ),
      bottomNavigationBar: profissional == null || !acoesCliente
          ? null
          : _SolicitarServicoBar(profissional: profissional),
    );
  }
}

class _PerfilProfissionalContent extends StatefulWidget {
  const _PerfilProfissionalContent({
    required this.profissional,
    required this.store,
  });

  final Profissional profissional;
  final ConectaLarMockStore store;

  @override
  State<_PerfilProfissionalContent> createState() =>
      _PerfilProfissionalContentState();
}

class _PerfilProfissionalContentState
    extends State<_PerfilProfissionalContent> {
  final _sobreKey = GlobalKey();
  final _servicosKey = GlobalKey();
  final _avaliacoesKey = GlobalKey();

  Profissional get profissional => widget.profissional;
  ConectaLarMockStore get store => widget.store;

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
    final foto = profissional.fotoAsset;
    final services = AppServices.instance;
    final acoesCliente =
        !services.auth.autenticado ||
        services.auth.usuarioAtual?['tipo'] == 'cliente';
    Future<void> salvarFavorito() async {
      if (AppServices.instance.auth.autenticado) {
        try {
          await AppServices.instance.clientes.adicionarFavorito(
            profissional.id,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profissional salvo nos favoritos.')),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível salvar este favorito.'),
            ),
          );
        }
        return;
      }

      if (AppServices.instance.emDemonstracao) {
        store.toggleFavorito(profissional.id);
      } else {
        Navigator.pushNamed(context, AppRoutes.login);
      }
    }

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
                fotoAsset: foto,
                favorito:
                    AppServices.instance.emDemonstracao &&
                    store.isFavorito(profissional.id),
                onFavoritoTap: acoesCliente ? salvarFavorito : null,
              ),
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
                title: 'Sobre o profissional',
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
                      text: 'Atende em ${profissional.bairro}',
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
                      'A solicitação será enviada ao profissional e começará aguardando '
                      'resposta. O serviço só fica agendado após aceite válido.',
                    ),
                  ],
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
    required this.favorito,
    required this.onFavoritoTap,
  });

  final Profissional profissional;
  final String? fotoAsset;
  final bool favorito;
  final VoidCallback? onFavoritoTap;

  @override
  Widget build(BuildContext context) {
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(16) > 24;
    final avatar = _FotoPerfil(fotoAsset: fotoAsset, nome: profissional.nome);
    final identificacao = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profissional.nome,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.texto,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(profissional.bairro, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final favoritoButton = onFavoritoTap == null
        ? null
        : IconButton(
            key: ValueKey('perfil-favorito-${profissional.id}'),
            tooltip: favorito ? 'Remover favorito' : 'Salvar favorito',
            onPressed: onFavoritoTap,
            icon: Icon(
              favorito ? Icons.favorite : Icons.favorite_border,
              color: favorito ? const Color(0xFFC53030) : AppColors.texto,
            ),
          );
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                if (textoAmpliado)
                  const Spacer()
                else
                  const SizedBox(width: AppSpace.lg),
                if (!textoAmpliado) Expanded(child: identificacao),
                ?favoritoButton,
              ],
            ),
            if (textoAmpliado) ...[
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
                    text: 'Novo profissional',
                  )
                else
                  _ResumoChip(
                    icon: Icons.star_rounded,
                    text:
                        '${profissional.notaMedia!.toStringAsFixed(1).replaceAll('.', ',')} '
                        '(${profissional.quantidadeAvaliacoes ?? 0})',
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
      return const Text(
        'Consulte o profissional sobre os serviços oferecidos.',
      );
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

class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({required this.fotoAsset, required this.nome});
  final String? fotoAsset;
  final String nome;

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
    return ClipOval(
      child: SizedBox.square(
        dimension: 84,
        child: fotoAsset == null
            ? fallback
            : Image.asset(
                fotoAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                semanticLabel: 'Foto de $nome',
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
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
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 12,
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
        child: FilledButton.icon(
          key: const ValueKey('perfil-solicitar-servico'),
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.solicitarServico,
            arguments: profissional,
          ),
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Solicitar atendimento'),
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
          'Não foi possível carregar os dados deste profissional.',
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
