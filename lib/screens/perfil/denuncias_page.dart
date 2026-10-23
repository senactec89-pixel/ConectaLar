import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/api_page.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class DenunciasPage extends StatefulWidget {
  const DenunciasPage({super.key});

  @override
  State<DenunciasPage> createState() => _DenunciasPageState();
}

class _DenunciasPageState extends State<DenunciasPage> {
  late Future<ApiPage<Map<String, dynamic>>> _denunciasFuture;
  bool _carregandoMais = false;

  @override
  void initState() {
    super.initState();
    _denunciasFuture = _carregar();
  }

  Future<ApiPage<Map<String, dynamic>>> _carregar({int pagina = 1}) async {
    final response = await AppServices.instance.denuncias.minhas(
      pagina: pagina,
    );
    return apiPageFromResponse(
      response,
      itemsKey: 'denuncias',
      mapper: (item) => item,
      fallbackPage: pagina,
    );
  }

  Future<void> _atualizar() async {
    final future = _carregar(pagina: 1);
    setState(() => _denunciasFuture = future);
    await future;
  }

  Future<void> _carregarMais() async {
    if (_carregandoMais) return;
    setState(() => _carregandoMais = true);
    try {
      final atual = await _denunciasFuture;
      if (!atual.hasMore) return;
      final proxima = await _carregar(pagina: atual.page + 1);
      final porId = <int, Map<String, dynamic>>{
        for (final item in atual.items) intValue(item['id']): item,
        for (final item in proxima.items) intValue(item['id']): item,
      };
      if (!mounted) return;
      setState(() {
        _denunciasFuture = Future.value(
          proxima.copyWith(items: porId.values.toList(growable: false)),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar mais denúncias.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoMais = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarCustom(
        title: 'Minhas denúncias',
        actions: [
          IconButton(
            tooltip: 'Atualizar denúncias',
            onPressed: _atualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: FutureBuilder<ApiPage<Map<String, dynamic>>>(
        future: _denunciasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(label: 'Carregando suas denúncias.');
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar suas denúncias.',
              onRetry: _atualizar,
            );
          }
          final pagina = snapshot.requireData;
          final denuncias = pagina.items;
          if (denuncias.isEmpty) {
            return const EmptyStateView(
              title: 'Nenhuma denúncia enviada',
              message:
                  'Os relatos enviados por você e o andamento das análises aparecerão aqui.',
              icon: Icons.flag_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: _atualizar,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppInsets.page,
              itemCount: denuncias.length + 1 + (pagina.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) {
                if (index == 0) return const _CabecalhoDenuncias();
                if (index == denuncias.length + 1) {
                  return Center(
                    child: OutlinedButton.icon(
                      key: const ValueKey('denuncias-carregar-mais'),
                      onPressed: _carregandoMais ? null : _carregarMais,
                      icon: _carregandoMais
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _carregandoMais
                            ? 'Carregando denúncias'
                            : 'Carregar mais denúncias',
                      ),
                    ),
                  );
                }
                return _DenunciaCard(denuncia: denuncias[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CabecalhoDenuncias extends StatelessWidget {
  const _CabecalhoDenuncias();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpace.xs),
      child: Text(
        'Acompanhe apenas os relatos enviados por você. Uma denúncia não aplica punição automática: a equipe administrativa analisa cada caso.',
        style: TextStyle(color: AppColors.textoSuave, height: 1.45),
      ),
    );
  }
}

class _DenunciaCard extends StatelessWidget {
  const _DenunciaCard({required this.denuncia});

  final Map<String, dynamic> denuncia;

  @override
  Widget build(BuildContext context) {
    final status = '${denuncia['status'] ?? 'pendente'}';
    final visual = _statusVisual(status);
    final atendimento = denuncia['atendimento'] is Map<String, dynamic>
        ? denuncia['atendimento'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final denunciado = denuncia['denunciado'] is Map<String, dynamic>
        ? denuncia['denunciado'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final solicitacaoId = intValue(
      atendimento['id'] ?? denuncia['solicitacaoId'],
    );
    final decisao = _textoOpcional(denuncia['decisao']);
    final analisadoEm = _dataHora(denuncia['analisadoEm']);

    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${atendimento['nomeServico'] ?? 'Atendimento'} #$solicitacaoId',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Chip(
                  avatar: Icon(visual.icon, size: 18, color: visual.cor),
                  label: Text(visual.rotulo),
                  side: BorderSide(color: visual.cor),
                  backgroundColor: visual.cor.withValues(alpha: 0.08),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              '${denuncia['motivo'] ?? 'Relato enviado'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpace.xs),
            Text('${denuncia['descricao'] ?? ''}'),
            const SizedBox(height: AppSpace.md),
            _LinhaInfo(
              icon: Icons.person_outline,
              texto:
                  'Pessoa denunciada: ${denunciado['nome'] ?? 'Participante do atendimento'}',
            ),
            _LinhaInfo(
              icon: Icons.event_outlined,
              texto: 'Enviada em ${_dataHora(denuncia['criadoEm'])}',
            ),
            if (decisao != null) ...[
              const Divider(height: AppSpace.xl),
              Text(
                'Retorno da análise',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(decisao),
              if (analisadoEm != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Concluida em $analisadoEm',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ] else ...[
              const Divider(height: AppSpace.xl),
              Text(
                status == 'em_analise'
                    ? 'A equipe está analisando o relato. Atualize esta tela para acompanhar.'
                    : 'O relato aguarda o início da análise administrativa.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: solicitacaoId <= 0
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.detalhesServico,
                        arguments: solicitacaoId,
                      ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver atendimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  const _LinhaInfo({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textoSuave),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

({String rotulo, IconData icon, Color cor}) _statusVisual(String status) {
  return switch (status) {
    'em_analise' => (
      rotulo: 'Em análise',
      icon: Icons.manage_search_outlined,
      cor: const Color(0xFF8A5B12),
    ),
    'resolvida' => (
      rotulo: 'Resolvida',
      icon: Icons.check_circle_outline,
      cor: AppColors.verdeEscuro,
    ),
    'rejeitada' => (
      rotulo: 'Encerrada',
      icon: Icons.block_outlined,
      cor: AppColors.erro,
    ),
    _ => (
      rotulo: 'Pendente',
      icon: Icons.schedule_outlined,
      cor: AppColors.textoSuave,
    ),
  };
}

String? _textoOpcional(Object? value) {
  final texto = value?.toString().trim() ?? '';
  return texto.isEmpty ? null : texto;
}

String? _dataHora(Object? value) {
  final data = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (data == null) return null;
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year} às $hora:$minuto';
}
