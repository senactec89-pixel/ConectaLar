import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class AvaliacoesRecebidasPage extends StatelessWidget {
  const AvaliacoesRecebidasPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: AppBarCustom(title: 'Avaliações recebidas'),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: AvaliacoesPublicadasView(),
    ),
  );
}

class AvaliacoesPublicadasView extends StatefulWidget {
  const AvaliacoesPublicadasView({this.profissionalId, super.key});
  final int? profissionalId;

  @override
  State<AvaliacoesPublicadasView> createState() =>
      _AvaliacoesPublicadasViewState();
}

class _AvaliacoesPublicadasViewState extends State<AvaliacoesPublicadasView> {
  static const _limite = 10;
  int _pagina = 1;
  int? _nota;
  bool _comComentario = false;
  late Future<Map<String, dynamic>> _future = _carregar();

  Future<Map<String, dynamic>> _carregar() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return {'avaliacoes': [], 'resumo': {}};
    }
    final id = widget.profissionalId;
    return id == null
        ? services.profissionais.minhasAvaliacoes(
            pagina: _pagina,
            limite: _limite,
            nota: _nota,
            comComentario: _comComentario,
          )
        : services.profissionais.avaliacoesPublicas(
            id,
            pagina: _pagina,
            limite: _limite,
            nota: _nota,
            comComentario: _comComentario,
          );
  }

  void _recarregar({int? pagina}) {
    setState(() {
      if (pagina != null) _pagina = pagina;
      _future = _carregar();
      _future.ignore();
    });
  }

  @override
  void didUpdateWidget(covariant AvaliacoesPublicadasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profissionalId != widget.profissionalId) {
      _pagina = 1;
      _future = _carregar();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: AsyncLoadingView(label: 'Carregando avaliações.'),
        );
      }
      if (snapshot.hasError) {
        return AsyncErrorView(
          message: 'Não foi possível carregar as avaliações.',
          onRetry: _recarregar,
        );
      }
      final data = snapshot.data ?? {};
      final rawResumo = data['resumo'];
      final resumo = rawResumo is Map
          ? Map<String, dynamic>.from(rawResumo)
          : <String, dynamic>{};
      final nota = doubleValueOrNull(resumo['notaMedia']);
      final quantidade = intValue(resumo['quantidadeAvaliacoes']);
      final rawPaginacao = data['paginacao'];
      final paginacao = rawPaginacao is Map
          ? Map<String, dynamic>.from(rawPaginacao)
          : <String, dynamic>{};
      final totalFiltrado = paginacao.containsKey('total')
          ? intValue(paginacao['total'])
          : (data['avaliacoes'] as List? ?? const []).length;
      final totalPaginasInformado = intValue(paginacao['totalPaginas']);
      final totalPaginas = totalPaginasInformado < 1
          ? 1
          : totalPaginasInformado;
      final avaliacoes = (data['avaliacoes'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nota == null
                ? 'Sem avaliações publicadas'
                : '${nota.toStringAsFixed(1).replaceAll('.', ',')} ★ • $quantidade ${quantidade == 1 ? 'avaliação' : 'avaliações'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Avaliações de atendimentos concluídos e aprovadas pela moderação.',
            style: TextStyle(color: AppColors.textoSuave),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filtrar por nota',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpace.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filtro in <(int?, String)>[
                      (null, 'Todas as notas'),
                      (5, '5 estrelas'),
                      (4, '4 estrelas'),
                      (3, '3 estrelas'),
                      (2, '2 estrelas'),
                      (1, '1 estrela'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: ChoiceChip(
                          label: Text(filtro.$2),
                          selected: _nota == filtro.$1,
                          onSelected: (_) {
                            _nota = filtro.$1;
                            _recarregar(pagina: 1);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Com comentário'),
                    selected: _comComentario,
                    onSelected: (value) {
                      _comComentario = value;
                      _recarregar(pagina: 1);
                    },
                  ),
                  Text(
                    '$totalFiltrado ${totalFiltrado == 1 ? 'resultado' : 'resultados'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (avaliacoes.isEmpty)
            EmptyStateView(
              title: _nota != null || _comComentario
                  ? 'Nenhuma avaliação com estes filtros'
                  : 'Nenhuma avaliação publicada',
              message: _nota != null || _comComentario
                  ? 'Altere os filtros para consultar outras avaliações.'
                  : 'As avaliações aprovadas aparecerão aqui.',
              icon: Icons.star_outline_rounded,
            )
          else
            for (final avaliacao in avaliacoes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Card(
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.estrela,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(
                                '${avaliacao['nota']} de 5 estrelas',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        if ('${avaliacao['comentario'] ?? ''}'
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: AppSpace.md),
                          Text(
                            '${avaliacao['comentario']}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          _data(avaliacao['criadoEm']),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if (totalPaginas > 1) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: _pagina > 1
                      ? () => _recarregar(pagina: _pagina - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Página $_pagina de $totalPaginas'),
                IconButton(
                  tooltip: 'Próxima página',
                  onPressed: _pagina < totalPaginas
                      ? () => _recarregar(pagina: _pagina + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );

  String _data(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
