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
  late Future<Map<String, dynamic>> _future = _carregar();

  Future<Map<String, dynamic>> _carregar() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return {'avaliacoes': [], 'resumo': {}};
    }
    final id = widget.profissionalId;
    return id == null
        ? services.profissionais.minhasAvaliacoes()
        : services.profissionais.avaliacoesPublicas(id);
  }

  @override
  void didUpdateWidget(covariant AvaliacoesPublicadasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profissionalId != widget.profissionalId) {
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
          onRetry: () => setState(() {
            _future = _carregar();
            _future.ignore();
          }),
        );
      }
      final data = snapshot.data ?? {};
      final rawResumo = data['resumo'];
      final resumo = rawResumo is Map
          ? Map<String, dynamic>.from(rawResumo)
          : <String, dynamic>{};
      final nota = doubleValueOrNull(resumo['notaMedia']);
      final quantidade = intValue(resumo['quantidadeAvaliacoes']);
      final avaliacoes = (data['avaliacoes'] as List? ?? [])
          .whereType<Map<String, dynamic>>();
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
            'Avaliações de atendimentos concluídos, aprovadas pela moderação. Mostramos as 50 mais recentes.',
            style: TextStyle(color: AppColors.textoSuave),
          ),
          const SizedBox(height: 12),
          if (avaliacoes.isEmpty)
            const EmptyStateView(
              title: 'Nenhuma avaliação publicada',
              message: 'As avaliações aprovadas aparecerão aqui.',
              icon: Icons.star_outline_rounded,
            )
          else
            for (final avaliacao in avaliacoes)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${avaliacao['nota']} de 5 estrelas',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ('${avaliacao['comentario'] ?? ''}'
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('${avaliacao['comentario']}'),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _data(avaliacao['criadoEm']),
                        style: const TextStyle(color: AppColors.textoSuave),
                      ),
                    ],
                  ),
                ),
              ),
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
