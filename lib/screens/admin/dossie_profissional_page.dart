import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/habilitacao_resumo.dart';
import 'admin_pages.dart';

class DossieProfissionalPage extends StatefulWidget {
  const DossieProfissionalPage({required this.profissionalId, super.key});

  final int profissionalId;

  @override
  State<DossieProfissionalPage> createState() => _DossieProfissionalPageState();
}

class _DossieProfissionalPageState extends State<DossieProfissionalPage> {
  int _pagina = 1;
  bool _abrindoDocumento = false;
  late Future<Map<String, dynamic>> _future = _carregar();

  Future<Map<String, dynamic>> _carregar() => AppServices.instance.admin
      .dossieProfissional(widget.profissionalId, pagina: _pagina);

  void _recarregar() => setState(() {
    _future = _carregar();
    _future.ignore();
  });

  String _data(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return 'Data não informada';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  }

  String _tipoDocumento(Object? tipo) => switch (tipo) {
    'documento_identidade' => 'Identidade',
    'comprovante_endereco' => 'Comprovante de endereço',
    'certificado_opcional' => 'Certificado profissional',
    'certificado_curso' => 'Certificado de curso',
    _ => 'Documento',
  };

  Future<void> _abrirDocumento(Map documento) async {
    if (_abrindoDocumento) return;
    final id = documento['id'];
    if (id is! int) return;
    setState(() => _abrindoDocumento = true);
    try {
      final arquivo = await AppServices.instance.admin.arquivoDocumento(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Arquivo do documento'),
          content: DocumentoPreview(
            bytes: arquivo.bytes,
            contentType: arquivo.contentType,
            fileName: arquivo.fileName ?? 'Documento $id',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Não foi possível abrir o documento.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _abrindoDocumento = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBarCustom(title: 'Dossiê profissional'),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AsyncLoadingView(label: 'Carregando dossiê.');
        }
        if (snapshot.hasError) {
          return AsyncErrorView(
            message: snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Não foi possível carregar o dossiê.',
            onRetry: _recarregar,
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final profissional = data['profissional'] is Map
            ? Map<String, dynamic>.from(data['profissional'] as Map)
            : <String, dynamic>{};
        final habilitacao = profissional['habilitacao'] is Map
            ? Map<String, dynamic>.from(profissional['habilitacao'] as Map)
            : <String, dynamic>{};
        final ofertas = (profissional['ofertas'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final documentos = (data['documentos'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final paginacao = data['paginacao'] is Map
            ? Map<String, dynamic>.from(data['paginacao'] as Map)
            : <String, dynamic>{};
        final totalPaginas = paginacao['totalPaginas'] as int? ?? 1;
        return RefreshIndicator(
          onRefresh: () async {
            _recarregar();
            try {
              await _future;
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                '${profissional['nome'] ?? 'Profissional'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (profissional['cidade'] != null)
                    '${profissional['cidade']}',
                  if (profissional['uf'] != null) '${profissional['uf']}',
                ].join(' - '),
              ),
              const SizedBox(height: 16),
              HabilitacaoResumo(dados: habilitacao),
              const SizedBox(height: 20),
              Text(
                'Ofertas cadastradas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (ofertas.isEmpty)
                const ListTile(title: Text('Nenhuma oferta cadastrada.')),
              for (final oferta in ofertas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${oferta['nome'] ?? 'Oferta'}'),
                  subtitle: Text('${oferta['categoria'] ?? 'Sem categoria'}'),
                  trailing: Text(oferta['ativo'] == true ? 'Ativa' : 'Pausada'),
                ),
              const SizedBox(height: 20),
              Text(
                'Documentos enviados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'O estado de um documento não comprova identidade nem libera atendimentos.',
              ),
              if (documentos.isEmpty)
                const ListTile(title: Text('Nenhum documento nesta página.')),
              for (final documento in documentos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tipoDocumento(documento['tipoDocumento'])),
                  subtitle: Text(
                    [
                      'Estado: ${documento['status'] ?? 'desconhecido'}',
                      'Enviado: ${_data(documento['criadoEm'] as String?)}',
                      if (documento['analisadoEm'] != null)
                        'Analisado: ${_data(documento['analisadoEm'] as String?)}',
                      if (documento['motivoRejeicao'] != null)
                        'Motivo: ${documento['motivoRejeicao']}',
                    ].join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: 'Abrir arquivo',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: _abrindoDocumento
                        ? null
                        : () => _abrirDocumento(documento),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: _pagina <= 1
                        ? null
                        : () {
                            _pagina--;
                            _recarregar();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('$_pagina de $totalPaginas'),
                  IconButton(
                    tooltip: 'Próxima página',
                    onPressed: _pagina >= totalPaginas
                        ? null
                        : () {
                            _pagina++;
                            _recarregar();
                          },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
