import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/profissional.dart';

class ProfissionalCard extends StatelessWidget {
  const ProfissionalCard({
    required this.profissional,
    this.onTap,
    this.trailingAction,
    super.key,
  });

  final Profissional profissional;
  final VoidCallback? onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final preco = profissional.precoInicial;
    final textoAmpliado = MediaQuery.textScalerOf(context).scale(16) > 24;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FotoProfissional(profissional: profissional),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profissional.nome,
                          maxLines: textoAmpliado ? null : 2,
                          overflow: textoAmpliado
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!textoAmpliado) ...[
                          const SizedBox(height: AppSpace.sm),
                          _InformacoesProfissional(
                            profissional: profissional,
                            textoAmpliado: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (textoAmpliado) ...[
                const SizedBox(height: AppSpace.md),
                _InformacoesProfissional(
                  profissional: profissional,
                  textoAmpliado: true,
                ),
              ],
              if (profissional.descricao.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  profissional.descricao,
                  maxLines: textoAmpliado ? null : 2,
                  overflow: textoAmpliado
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF586B63),
                    height: 1.35,
                  ),
                ),
              ],
              if (profissional.servicos.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final servico in profissional.servicos.take(3))
                      _ServicoTag(
                        servico: servico,
                        textoAmpliado: textoAmpliado,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.md),
              _RodapeProfissional(
                textoPreco: preco == null
                    ? 'Preço sob consulta'
                    : 'A partir de R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                onTap: onTap,
                trailingAction: trailingAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformacoesProfissional extends StatelessWidget {
  const _InformacoesProfissional({
    required this.profissional,
    required this.textoAmpliado,
  });

  final Profissional profissional;
  final bool textoAmpliado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (profissional.verificado) const _SeloVerificado(),
            _AvaliacaoProfissional(profissional: profissional),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.textoSuave,
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                profissional.bairro,
                maxLines: textoAmpliado ? null : 1,
                overflow: textoAmpliado
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RodapeProfissional extends StatelessWidget {
  const _RodapeProfissional({
    required this.textoPreco,
    this.onTap,
    this.trailingAction,
  });

  final String textoPreco;
  final VoidCallback? onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    const estiloPreco = TextStyle(
      color: AppColors.verde,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w800,
    );
    final preco = Text(textoPreco, style: estiloPreco);
    final acoes = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?trailingAction,
        TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.verde,
            padding: const EdgeInsets.all(AppSpace.sm),
            minimumSize: const Size(0, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text(
            'Ver perfil',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraPreco = _larguraTexto(
          context,
          textoPreco,
          DefaultTextStyle.of(context).style.merge(estiloPreco),
        );
        final larguraAcoes =
            _larguraTexto(
              context,
              'Ver perfil',
              Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
            ) +
            40 +
            (trailingAction == null ? 0 : 52);
        if (larguraPreco + 8 + larguraAcoes > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              preco,
              const SizedBox(height: AppSpace.sm),
              Align(alignment: Alignment.centerRight, child: acoes),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: preco),
            const SizedBox(width: AppSpace.sm),
            SizedBox(width: larguraAcoes, child: acoes),
          ],
        );
      },
    );
  }
}

double _larguraTexto(BuildContext context, String texto, TextStyle estilo) {
  final painter = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final largura = painter.width;
  painter.dispose();
  return largura;
}

class _FotoProfissional extends StatelessWidget {
  const _FotoProfissional({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final foto = profissional.fotoAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: SizedBox(
        width: 76,
        height: 94,
        child: foto == null
            ? _FotoAusente(nome: profissional.nome)
            : Image.asset(
                foto,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                semanticLabel: 'Foto de ${profissional.nome}',
                errorBuilder: (_, _, _) =>
                    _FotoAusente(nome: profissional.nome),
              ),
      ),
    );
  }
}

class _FotoAusente extends StatelessWidget {
  const _FotoAusente({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.characters.first;
    return ColoredBox(
      color: AppColors.verdeClaro,
      child: Center(
        child: Text(
          inicial.toUpperCase(),
          style: const TextStyle(
            color: AppColors.verdeEscuro,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SeloVerificado extends StatelessWidget {
  const _SeloVerificado();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verificação documental administrativa',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.verdeClaro,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: AppColors.verde, size: 14),
            SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text(
                'Verificado',
                style: TextStyle(
                  color: AppColors.verdeEscuro,
                  fontSize: 10,
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

class _AvaliacaoProfissional extends StatelessWidget {
  const _AvaliacaoProfissional({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final nota = profissional.notaMedia;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.estrela, size: 17),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            nota == null
                ? 'Novo profissional'
                : '${nota.toStringAsFixed(1).replaceAll('.', ',')} · ${profissional.quantidadeAvaliacoes ?? 0} avaliações',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicoTag extends StatelessWidget {
  const _ServicoTag({required this.servico, required this.textoAmpliado});

  final String servico;
  final bool textoAmpliado;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: textoAmpliado ? double.infinity : 180,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        servico,
        maxLines: textoAmpliado ? null : 1,
        overflow: textoAmpliado ? TextOverflow.clip : TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF426257),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
