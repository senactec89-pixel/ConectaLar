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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FotoProfissional(profissional: profissional),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profissional.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (profissional.verificado)
                              const _SeloVerificado(),
                            _AvaliacaoProfissional(profissional: profissional),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textoSuave,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                profissional.bairro,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                ],
              ),
              if (profissional.descricao.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profissional.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF586B63),
                    height: 1.35,
                  ),
                ),
              ],
              if (profissional.servicos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final servico in profissional.servicos.take(3))
                      _ServicoTag(servico: servico),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preco == null
                          ? 'Preço sob consulta'
                          : 'A partir de R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.verde,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailingAction != null) ...[
                    const SizedBox(width: 4),
                    trailingAction!,
                  ],
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.verde,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 40),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FotoProfissional extends StatelessWidget {
  const _FotoProfissional({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final foto = profissional.fotoAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.verdeClaro,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: AppColors.verde, size: 14),
            SizedBox(width: 3),
            Text(
              'Verificado',
              style: TextStyle(
                color: AppColors.verdeEscuro,
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            nota == null
                ? 'Novo profissional'
                : '${nota.toStringAsFixed(1).replaceAll('.', ',')} · ${profissional.quantidadeAvaliacoes ?? 0} avaliações',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  const _ServicoTag({required this.servico});

  final String servico;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        servico,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF426257),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
