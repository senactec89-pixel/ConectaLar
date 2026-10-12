import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/documento_verificacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
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
    setState(() {
      _future = _carregar();
      _future.ignore();
    });
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
              const SizedBox(height: AppSpace.md),
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
                      SizedBox(height: AppSpace.sm),
                      Text('• Documento de identificação'),
                      Text('• Comprovante de endereço'),
                      Text('• Certificados profissionais (opcionais)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
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
                  const SizedBox(height: AppSpace.md),
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
  static const _tamanhoMaximoArquivo = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  String _tipo = 'documento_identidade';
  String? _arquivoBase64;
  String? _nomeArquivo;
  int? _tamanhoArquivo;
  final _observacao = TextEditingController();
  String _mimeType = 'application/pdf';
  bool _selecionandoArquivo = false;
  bool _enviando = false;

  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    if (_selecionandoArquivo || _enviando) return;
    setState(() => _selecionandoArquivo = true);

    try {
      final arquivo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PDF, JPEG ou PNG',
            extensions: ['pdf', 'jpg', 'jpeg', 'png'],
            uniformTypeIdentifiers: [
              'com.adobe.pdf',
              'public.jpeg',
              'public.png',
            ],
          ),
        ],
        confirmButtonText: 'Selecionar',
      );
      if (!mounted || arquivo == null) return;

      final extensao = arquivo.name.split('.').last.toLowerCase();
      final mimeType = switch (extensao) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => null,
      };
      if (mimeType == null) {
        _limparArquivoSelecionado();
        _mostrarMensagem('Selecione um arquivo PDF, JPEG ou PNG.');
        return;
      }

      final tamanho = await arquivo.length();
      if (tamanho > _tamanhoMaximoArquivo) {
        _limparArquivoSelecionado();
        _mostrarMensagem('O arquivo deve ter no máximo 5 MB.');
        return;
      }

      final bytes = await arquivo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _tamanhoMaximoArquivo) {
        _limparArquivoSelecionado();
        _mostrarMensagem('O arquivo deve ter no máximo 5 MB.');
        return;
      }

      setState(() {
        _arquivoBase64 = base64Encode(bytes);
        _nomeArquivo = arquivo.name;
        _tamanhoArquivo = bytes.length;
        _mimeType = mimeType;
      });
      _formKey.currentState?.validate();
    } catch (_) {
      if (mounted) {
        _mostrarMensagem('Não foi possível abrir o arquivo selecionado.');
      }
    } finally {
      if (mounted) setState(() => _selecionandoArquivo = false);
    }
  }

  void _limparArquivoSelecionado() {
    if (!mounted) return;
    setState(() {
      _arquivoBase64 = null;
      _nomeArquivo = null;
      _tamanhoArquivo = null;
      _mimeType = 'application/pdf';
    });
    _formKey.currentState?.validate();
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || _enviando) return;
    setState(() => _enviando = true);
    try {
      await AppServices.instance.verificacao.enviarDocumento(
        tipoDocumento: _tipo,
        arquivoBase64: _arquivoBase64,
        mimeType: _mimeType,
        nomeArquivo: _nomeArquivo,
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
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                isExpanded: true,
                itemHeight: null,
                selectedItemBuilder: (context) => const [
                  Text(
                    'Identificação',
                    semanticsLabel: 'Documento de identificação',
                  ),
                  Text('Endereço', semanticsLabel: 'Comprovante de endereço'),
                  Text(
                    'Certificado',
                    semanticsLabel: 'Certificado profissional opcional',
                  ),
                ],
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
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                onPressed: _enviando || _selecionandoArquivo
                    ? null
                    : _selecionarArquivo,
                icon: _selecionandoArquivo
                    ? const ButtonProgressIndicator()
                    : const Icon(Icons.attach_file),
                label: ActionLabel(
                  busy: _selecionandoArquivo,
                  text: _selecionandoArquivo
                      ? 'Abrindo arquivos...'
                      : _nomeArquivo == null
                      ? 'Selecionar arquivo'
                      : 'Trocar arquivo',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                _nomeArquivo == null
                    ? 'PDF, JPEG ou PNG • até 5 MB'
                    : '$_nomeArquivo • ${_formatarTamanho(_tamanhoArquivo ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              FormField<String>(
                validator: (_) => _arquivoBase64 == null
                    ? 'Selecione um arquivo para enviar.'
                    : null,
                builder: (field) => field.hasError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _observacao,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Observação'),
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const ButtonProgressIndicator()
                    : const Icon(Icons.upload_file_outlined),
                label: ActionLabel(
                  busy: _enviando,
                  text: _enviando ? 'Enviando...' : 'Enviar documento',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatarTamanho(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
