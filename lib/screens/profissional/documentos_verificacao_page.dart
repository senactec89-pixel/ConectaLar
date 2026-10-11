import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/documento_verificacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class DocumentosVerificacaoPage extends StatefulWidget {
  const DocumentosVerificacaoPage({super.key});

  @override
  State<DocumentosVerificacaoPage> createState() =>
      _DocumentosVerificacaoPageState();
}

class _DocumentosVerificacaoPageState extends State<DocumentosVerificacaoPage> {
  late Future<List<DocumentoVerificacao>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<DocumentoVerificacao>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    final response = await AppServices.instance.verificacao.meusDocumentos();
    return listFromApi(response['documentos'], documentoVerificacaoFromApi);
  }

  void _recarregar() {
    setState(() => _future = _carregar());
  }

  Future<void> _abrirEnvio() async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DocumentoForm(),
    );
    if (salvou == true) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Verificação documental'),
      backgroundColor: AppColors.fundo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirEnvio,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Enviar'),
      ),
      body: FutureBuilder<List<DocumentoVerificacao>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(label: 'Carregando documentos.');
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar seus documentos agora.',
              onRetry: _recarregar,
              icon: Icons.upload_file_outlined,
            );
          }
          final documentos = snapshot.data ?? const <DocumentoVerificacao>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Documentos são analisados pela administração. O selo indica análise documental aprovada, não garantia absoluta de segurança, qualidade ou resultado.',
                    style: TextStyle(height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documentos que você pode enviar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text('• Documento de identificação'),
                      Text('• Comprovante de endereço'),
                      Text('• Certificados profissionais (opcionais)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (documentos.isEmpty)
                const EmptyStateView(
                  title: 'Nenhum documento enviado',
                  message:
                      'Quando você enviar documentos, o andamento da análise aparecerá aqui.',
                  icon: Icons.folder_open_outlined,
                )
              else
                for (final documento in documentos) ...[
                  _DocumentoCard(documento: documento),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DocumentoCard extends StatelessWidget {
  const _DocumentoCard({required this.documento});

  final DocumentoVerificacao documento;

  @override
  Widget build(BuildContext context) {
    final color = switch (documento.status) {
      'aprovado' => AppColors.verde,
      'rejeitado' => const Color(0xFFC53030),
      _ => const Color(0xFFB7791F),
    };
    return Card(
      child: ListTile(
        leading: Icon(Icons.description_outlined, color: color),
        title: Text(
          documento.tipoDocumento,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            documento.nomeArquivo ?? documento.referenciaArquivo,
            'Status: ${_statusDocumento(documento.status)}',
            if (documento.motivoRejeicao != null)
              'Motivo: ${documento.motivoRejeicao}',
          ].join('\n'),
        ),
      ),
    );
  }
}

String _statusDocumento(String status) => switch (status) {
  'pendente' => 'Em análise',
  'aprovado' => 'Aprovado',
  'rejeitado' => 'Rejeitado',
  _ => 'Enviado',
};

class _DocumentoForm extends StatefulWidget {
  const _DocumentoForm();

  @override
  State<_DocumentoForm> createState() => _DocumentoFormState();
}

class _DocumentoFormState extends State<_DocumentoForm> {
  final _formKey = GlobalKey<FormState>();
  String _tipo = 'documento_identidade';
  final _referencia = TextEditingController();
  final _arquivoBase64 = TextEditingController();
  final _nomeArquivo = TextEditingController();
  final _observacao = TextEditingController();
  String _mimeType = 'application/pdf';
  bool _enviando = false;

  @override
  void dispose() {
    _referencia.dispose();
    _arquivoBase64.dispose();
    _nomeArquivo.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || _enviando) return;
    setState(() => _enviando = true);
    try {
      await AppServices.instance.verificacao.enviarDocumento(
        tipoDocumento: _tipo,
        referenciaArquivo: _referencia.text.trim().isEmpty
            ? null
            : _referencia.text.trim(),
        arquivoBase64: _arquivoBase64.text.trim().isEmpty
            ? null
            : _arquivoBase64.text.trim(),
        mimeType: _arquivoBase64.text.trim().isEmpty ? null : _mimeType,
        nomeArquivo: _nomeArquivo.text.trim().isEmpty
            ? null
            : _nomeArquivo.text.trim(),
        observacao: _observacao.text.trim().isEmpty
            ? null
            : _observacao.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar o documento.')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Enviar documento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'documento_identidade',
                    child: Text('Documento de identificação'),
                  ),
                  DropdownMenuItem(
                    value: 'comprovante_endereco',
                    child: Text('Comprovante de endereço'),
                  ),
                  DropdownMenuItem(
                    value: 'certificado_opcional',
                    child: Text('Certificado profissional (opcional)'),
                  ),
                ],
                onChanged: (value) => setState(() => _tipo = value ?? _tipo),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _referencia,
                decoration: const InputDecoration(
                  labelText: 'Referência interna do arquivo',
                  hintText: 'Ex.: local/documentos/rg-frente.pdf',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty &&
                      _arquivoBase64.text.trim().isEmpty) {
                    return 'Informe uma referencia ou arquivo base64.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _mimeType,
                decoration: const InputDecoration(labelText: 'Tipo do arquivo'),
                items: const [
                  DropdownMenuItem(
                    value: 'application/pdf',
                    child: Text('PDF'),
                  ),
                  DropdownMenuItem(
                    value: 'image/jpeg',
                    child: Text('Imagem JPEG'),
                  ),
                  DropdownMenuItem(
                    value: 'image/png',
                    child: Text('Imagem PNG'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _mimeType = value ?? _mimeType),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _arquivoBase64,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Arquivo em base64',
                  hintText:
                      'Cole o conteudo base64 quando nao houver referencia',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nomeArquivo,
                decoration: const InputDecoration(labelText: 'Nome do arquivo'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _observacao,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Observação'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_enviando ? 'Enviando...' : 'Enviar documento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
