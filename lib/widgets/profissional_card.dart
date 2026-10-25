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
    final espacamento = textoAmpliado ? AppSpace.md : AppSpace.sm;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(textoAmpliado ? AppSpace.lg : AppSpace.md),
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!textoAmpliado) ...[
                          const SizedBox(height: AppSpace.xs),
                          _AvaliacaoProfissional(profissional: profissional),
                          if (!profissional.podeReceberSolicitacoes) ...[
                            const SizedBox(height: AppSpace.xs),
                            const _AtendimentoIndisponivel(),
                          ],
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
                SizedBox(height: espacamento),
                _AvaliacaoProfissional(profissional: profissional),
                if (!profissional.podeReceberSolicitacoes) ...[
                  const SizedBox(height: AppSpace.xs),
                  const _AtendimentoIndisponivel(),
                ],
                const SizedBox(height: AppSpace.sm),
                _InformacoesProfissional(
                  profissional: profissional,
                  textoAmpliado: true,
                ),
              ],
              if (profissional.descricao.trim().isNotEmpty) ...[
                SizedBox(height: espacamento),
                Text(
                  profissional.descricao,
                  maxLines: textoAmpliado ? null : 2,
                  overflow: textoAmpliado
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textoSuave,
                    height: 1.35,
                  ),
                ),
              ],
              if (profissional.servicos.isNotEmpty) ...[
                SizedBox(height: espacamento),
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
              const Divider(
                height: AppSpace.lg,
                thickness: 1,
                color: AppColors.borda,
              ),
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

class _AtendimentoIndisponivel extends StatelessWidget {
  const _AtendimentoIndisponivel();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Perfil em verificacao. Ainda nao recebe solicitacoes.',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: AppColors.textoSuave,
          ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              'Em verificacao - pedidos indisponiveis',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
                profissional.distanciaKm == null
                    ? profissional.bairro
                    : '${profissional.bairro} · ${profissional.distanciaKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                maxLines: textoAmpliado ? null : 1,
                overflow: textoAmpliado
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
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
    final estiloPreco = Theme.of(
      context,
    ).textTheme.titleSmall!.copyWith(color: AppColors.verde);
    final partesPreco = textoPreco.startsWith('A partir de ')
        ? ['A partir de', textoPreco.substring('A partir de '.length)]
        : [textoPreco];
    final preco = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.verdePastel,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.borda),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: partesPreco.length == 1
            ? Text(textoPreco, style: estiloPreco)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partesPreco.first,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.verdeEscuro,
                    ),
                  ),
                  Text(
                    partesPreco.last.replaceFirst(' ', '\u00A0'),
                    maxLines: 1,
                    softWrap: false,
                    style: estiloPreco,
                  ),
                ],
              ),
      ),
    );
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
            backgroundColor: AppColors.verde,
            foregroundColor: AppColors.branco,
            disabledBackgroundColor: AppColors.verdeClaro,
            disabledForegroundColor: AppColors.textoSuave,
            padding: const EdgeInsets.all(AppSpace.sm),
            minimumSize: const Size(0, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
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
        // O preço pode ocupar duas linhas, mas o valor monetário deve caber
        // inteiro. Inclui o padding na decisão de empilhar preço e ações.
        final larguraPreco =
            partesPreco
                .map(
                  (parte) => _larguraTexto(
                    context,
                    parte,
                    DefaultTextStyle.of(context).style.merge(estiloPreco),
                  ),
                )
                .reduce((a, b) => a > b ? a : b) +
            AppSpace.md * 2;
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
    final fotoAsset = profissional.fotoAsset;
    final fotoUrl = profissional.fotoUrl;
    final imagem = fotoUrl != null
        ? Image.network(
            fotoUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'Foto de ${profissional.nome}',
            errorBuilder: (_, _, _) => _FotoAusente(nome: profissional.nome),
          )
        : fotoAsset == null
        ? _FotoAusente(nome: profissional.nome)
        : Image.asset(
            fotoAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'Foto de ${profissional.nome}',
            errorBuilder: (_, _, _) => _FotoAusente(nome: profissional.nome),
          );
    return SizedBox(
      width: 76,
      height: 94,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: imagem,
            ),
          ),
          if (profissional.verificado)
            Positioned(
              right: 4,
              bottom: 4,
              child: Tooltip(
                message: 'Documentos verificados',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.branco,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borda),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.verde,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
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
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.verdeEscuro),
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
    final quantidade = profissional.quantidadeAvaliacoes ?? 0;
    final resumo = nota == null
        ? 'Novo profissional'
        : '${nota.toStringAsFixed(1).replaceAll('.', ',')} · $quantidade';
    final descricao = nota == null
        ? 'Novo profissional'
        : '$resumo ${quantidade == 1 ? 'avaliação' : 'avaliações'}';
    return Tooltip(
      message: descricao,
      excludeFromSemantics: true,
      child: Semantics(
        label: descricao,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.estrela,
                size: 17,
              ),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  descricao,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicoTag extends StatelessWidget {
  const _ServicoTag({required this.servico, required this.textoAmpliado});

  final String servico;
  final bool textoAmpliado;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: textoAmpliado ? double.infinity : 180,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.circle, size: 4, color: AppColors.textoSuave),
          ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              servico,
              maxLines: textoAmpliado ? null : 1,
              overflow: textoAmpliado
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}
