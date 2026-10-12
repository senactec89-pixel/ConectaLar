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

class _PerfilProfissionalContent extends StatelessWidget {
  const _PerfilProfissionalContent({
    required this.profissional,
    required this.store,
  });

  final Profissional profissional;
  final ConectaLarMockStore store;

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _CabecalhoPerfil(
          profissional: profissional,
          fotoAsset: foto,
          favorito:
              AppServices.instance.emDemonstracao &&
              store.isFavorito(profissional.id),
          onFavoritoTap: acoesCliente ? salvarFavorito : null,
        ),
        const SizedBox(height: 18),
        _SecaoPerfil(
          title: 'Serviços oferecidos',
          child: profissional.servicos.isEmpty
              ? Text(
                  profissional.descricao,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final servico in profissional.servicos)
                      Chip(
                        label: Text(servico),
                        avatar: const Icon(Icons.home_repair_service, size: 18),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _SecaoPerfil(
          title: 'Atendimento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLinha(
                icon: Icons.location_on_outlined,
                text: 'Atende em ${profissional.bairro}',
              ),
              const SizedBox(height: 10),
              _InfoLinha(
                icon: Icons.payments_outlined,
                text: _precoTexto(profissional.precoInicial),
              ),
              const SizedBox(height: 10),
              const _InfoLinha(
                icon: Icons.handshake_outlined,
                text: 'Pagamento combinado diretamente entre as partes',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SecaoPerfil(
          title: 'Antes de solicitar',
          child: Text(
            'A solicitação será enviada ao profissional e começará aguardando '
            'resposta. O serviço só fica agendado após aceite válido.',
          ),
        ),
        const SizedBox(height: 12),
        _SecaoPerfil(
          title: 'Avaliações de clientes',
          child: AvaliacoesPublicadasView(profissionalId: profissional.id),
        ),
      ],
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
    final avatar = CircleAvatar(
      radius: 42,
      backgroundColor: AppColors.verdeClaro,
      foregroundColor: AppColors.verde,
      backgroundImage: fotoAsset == null ? null : AssetImage(fotoAsset!),
      child: fotoAsset == null
          ? const Icon(Icons.person_rounded, size: 42)
          : null,
    );
    final identificacao = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profissional.nome,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profissional.descricao,
          style: const TextStyle(color: AppColors.textoSuave),
        ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                if (textoAmpliado)
                  const Spacer()
                else
                  const SizedBox(width: 14),
                if (!textoAmpliado) Expanded(child: identificacao),
                ?favoritoButton,
              ],
            ),
            if (textoAmpliado) ...[const SizedBox(height: 12), identificacao],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
  const _SecaoPerfil({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(16),
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
        const SizedBox(width: 8),
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
          boxShadow: [
            BoxShadow(
              color: Color(0x14153B31),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
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
