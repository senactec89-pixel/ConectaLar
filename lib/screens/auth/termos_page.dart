import 'package:flutter/material.dart';

import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class TermosPage extends StatefulWidget {
  const TermosPage({super.key});

  @override
  State<TermosPage> createState() => _TermosPageState();
}

class _TermosPageState extends State<TermosPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _future = AppServices.instance.termos.atuais();
    _future.ignore();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Termos e privacidade'),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(label: 'Carregando termos.');
        }
        final termos = snapshot.data?['termos'];
        if (snapshot.hasError || termos is! Map<String, dynamic>) {
          return AsyncErrorView(
            message: 'Não foi possível carregar os termos agora.',
            onRetry: () => setState(_carregar),
          );
        }
        final secoes = (termos['secoes'] as List? ?? [])
            .whereType<Map<String, dynamic>>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${termos['titulo'] ?? 'Termos de uso'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Versão: ${termos['versao'] ?? 'Não informada'}'),
                if (termos['publicadoEm'] != null)
                  Text('Publicado em: ${termos['publicadoEm']}'),
                const SizedBox(height: 16),
                if (termos['resumo'] != null) Text('${termos['resumo']}'),
                const SizedBox(height: 16),
                for (final secao in secoes) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${secao['titulo'] ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${secao['texto'] ?? ''}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
