import 'dart:convert';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/documento_verificacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../utils/situacao_documental.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/habilitacao_resumo.dart';
import '../../services/api_service.dart';

class DocumentosVerificacaoPage extends StatefulWidget {
  const DocumentosVerificacaoPage({super.key});

  @override
  State<DocumentosVerificacaoPage> createState() =>
      _DocumentosVerificacaoPageState();
}

class _DocumentosVerificacaoPageState extends State<DocumentosVerificacaoPage> {
  late Future<Map<String, dynamic>> _future;
  bool _solicitandoRevisao = false;
  bool _iniciandoIdentidade = false;
  bool _consultandoIdentidade = false;
  bool _iniciandoTelefone = false;
  bool _confirmandoTelefone = false;
  bool _consultandoTelefone = false;
  Map<String, dynamic> _identidade = const {};
  Map<String, dynamic> _telefone = const {};
  String? _tentativaTelefoneId;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<Map<String, dynamic>> _carregar({
    bool consultarIdentidade = true,
  }) async {
    if (!AppServices.instance.auth.autenticado) return const {};
    final dados = await AppServices.instance.verificacao.meusDocumentos();
    if (consultarIdentidade) {
      try {
        final respostaIdentidade = await AppServices.instance.verificacao
            .consultarIdentidade();
        final rawIdentidade = respostaIdentidade['identidade'];
        _identidade = rawIdentidade is Map
            ? Map<String, dynamic>.from(rawIdentidade)
            : const {};
      } catch (_) {
        _identidade = {..._identidade, 'falhaConsulta': true};
      }
    }
    try {
      final respostaTelefone = await AppServices.instance.verificacao
          .consultarPosseTelefone();
      final rawTelefone = respostaTelefone['telefone'];
      _telefone = rawTelefone is Map
          ? Map<String, dynamic>.from(rawTelefone)
          : const {};
      _tentativaTelefoneId = _telefone['tentativaId']?.toString();
    } catch (_) {
      _telefone = {..._telefone, 'falhaConsulta': true};
    }
    final rawHabilitacao = dados['habilitacao'];
    if (rawHabilitacao is Map) {
      final habilitacao = Map<String, dynamic>.from(rawHabilitacao);
      final etapas = (habilitacao['etapas'] as List? ?? const [])
          .map((item) => item is Map ? Map<String, dynamic>.from(item) : item)
          .toList();
      final indice = etapas.indexWhere(
        (item) => item is Map && item['codigo'] == 'identidade',
      );
      if (indice >= 0 && etapas[indice] is Map) {
        (etapas[indice] as Map<String, dynamic>)['status'] =
            _statusEtapaIdentidade(_identidade['estado']);
      }
      final indiceTelefone = etapas.indexWhere(
        (item) => item is Map && item['codigo'] == 'telefone',
      );
      if (indiceTelefone >= 0 && etapas[indiceTelefone] is Map) {
        (etapas[indiceTelefone] as Map<String, dynamic>)['status'] =
            _statusEtapaTelefone(_telefone['estado']);
      }
      habilitacao['etapas'] = etapas;
      dados['habilitacao'] = habilitacao;
    }
    return dados;
  }

  Future<void> _iniciarIdentidade() async {
    if (_iniciandoIdentidade) return;
    final aceitou = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConsentimentoIdentidadeDialog(),
    );
    if (aceitou != true || !mounted) return;
    setState(() => _iniciandoIdentidade = true);
    try {
      final resposta = await AppServices.instance.verificacao
          .iniciarIdentidade();
      final raw = resposta['identidade'];
      final identidade = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      _identidade = identidade;
      final url = identidade['url']?.toString();
      if (url == null ||
          !await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          )) {
        throw const ApiException('Não foi possível abrir a verificação.');
      }
      if (mounted) _recarregar(consultarIdentidade: false);
    } catch (error) {
      if (mounted) _mostrarErroIdentidade(error);
    } finally {
      if (mounted) setState(() => _iniciandoIdentidade = false);
    }
  }

  Future<void> _consultarIdentidade() async {
    if (_consultandoIdentidade) return;
    setState(() => _consultandoIdentidade = true);
    try {
      final resposta = await AppServices.instance.verificacao
          .consultarIdentidade();
      final raw = resposta['identidade'];
      _identidade = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      if (mounted) _recarregar(consultarIdentidade: false);
    } catch (error) {
      if (mounted) _mostrarErroIdentidade(error);
    } finally {
      if (mounted) setState(() => _consultandoIdentidade = false);
    }
  }

  Future<void> _iniciarTelefone() async {
    if (_iniciandoTelefone) return;
    final aceitou = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConsentimentoTelefoneDialog(),
    );
    if (aceitou != true || !mounted) return;
    setState(() => _iniciandoTelefone = true);
    try {
      final resposta = await AppServices.instance.verificacao
          .iniciarPosseTelefone();
      final raw = resposta['telefone'];
      _telefone = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      _tentativaTelefoneId = null;
      if (mounted) _recarregar(consultarIdentidade: false);
    } catch (error) {
      if (mounted) _mostrarErroTelefone(error);
    } finally {
      if (mounted) setState(() => _iniciandoTelefone = false);
    }
  }

  Future<void> _confirmarTelefone() async {
    if (_confirmandoTelefone) return;
    final codigo = await showDialog<String>(
      context: context,
      builder: (_) => _CodigoTelefoneDialog(
        tentativasRestantes: _telefone['tentativasRestantes'] as int?,
      ),
    );
    if (codigo == null || !mounted) return;
    setState(() => _confirmandoTelefone = true);
    _tentativaTelefoneId ??= _uuidV4();
    try {
      final resposta = await AppServices.instance.verificacao
          .confirmarPosseTelefone(
            codigo: codigo,
            tentativaId: _tentativaTelefoneId!,
          );
      final raw = resposta['telefone'];
      _telefone = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      _tentativaTelefoneId = null;
      if (mounted) _recarregar(consultarIdentidade: false);
    } catch (error) {
      if (mounted) _mostrarErroTelefone(error);
    } finally {
      if (mounted) setState(() => _confirmandoTelefone = false);
    }
  }

  Future<void> _consultarTelefone() async {
    if (_consultandoTelefone) return;
    setState(() => _consultandoTelefone = true);
    try {
      final resposta = await AppServices.instance.verificacao
          .consultarPosseTelefone();
      final raw = resposta['telefone'];
      _telefone = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      _tentativaTelefoneId = _telefone['tentativaId']?.toString();
      if (mounted) _recarregar(consultarIdentidade: false);
    } catch (error) {
      if (mounted) _mostrarErroTelefone(error);
    } finally {
      if (mounted) setState(() => _consultandoTelefone = false);
    }
  }

  void _mostrarErroTelefone(Object error) {
    final mensagem = error is ApiException
        ? error.message
        : 'Não foi possível consultar a confirmação do telefone.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  void _mostrarErroIdentidade(Object error) {
    final mensagem = error is ApiException
        ? error.message
        : 'Não foi possível consultar a verificação de identidade.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _solicitarRevisao() async {
    if (_solicitandoRevisao) return;
    setState(() => _solicitandoRevisao = true);
    try {
      await AppServices.instance.verificacao.solicitarRevisao();
      if (mounted) _recarregar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Não foi possível solicitar revisão.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _solicitandoRevisao = false);
    }
  }

  void _recarregar({bool consultarIdentidade = true}) {
    setState(() {
      _future = _carregar(consultarIdentidade: consultarIdentidade);
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
      body: FutureBuilder<Map<String, dynamic>>(
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
          final data = snapshot.data ?? const <String, dynamic>{};
          final documentos = listFromApi(
            data['documentos'],
            documentoVerificacaoFromApi,
          );
          final situacao = situacaoDocumentoIdentidade(documentos);
          final raw = data['habilitacao'];
          final habilitacao = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          return RefreshIndicator(
            onRefresh: () async {
              _recarregar();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
              children: [
                HabilitacaoResumo(dados: habilitacao),
                const SizedBox(height: 12),
                if (documentos.isEmpty &&
                    habilitacao['podeAtender'] != true) ...[
                  Card(
                    child: Padding(
                      padding: AppInsets.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prefere enviar depois?',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          const Text(
                            'Você pode conhecer a área profissional agora. Seu perfil ainda precisa ser habilitado para receber solicitações; envie os documentos e acompanhe a análise quando estiver pronto.',
                          ),
                          const SizedBox(height: AppSpace.md),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey('continuar-sem-documentos'),
                              onPressed: () =>
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRoutes.areaProfissional,
                                    (_) => false,
                                  ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Continuar sem enviar agora'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                _SituacaoDocumentalCard(
                  situacao: situacao,
                  onAtualizar: _recarregar,
                  onEnviar: _abrirEnvio,
                ),
                const SizedBox(height: 12),
                _CartaoIdentidade(
                  estado: _identidade['estado']?.toString() ?? 'nao_iniciada',
                  disponivel: _identidade['disponivel'] == true,
                  falhaConsulta: _identidade['falhaConsulta'] == true,
                  iniciando: _iniciandoIdentidade,
                  consultando: _consultandoIdentidade,
                  onIniciar: _iniciarIdentidade,
                  onConsultar: _consultarIdentidade,
                ),
                const SizedBox(height: 12),
                _CartaoTelefone(
                  dados: _telefone,
                  iniciando: _iniciandoTelefone,
                  confirmando: _confirmandoTelefone,
                  consultando: _consultandoTelefone,
                  onIniciar: _iniciarTelefone,
                  onConfirmar: _confirmarTelefone,
                  onConsultar: _consultarTelefone,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('solicitar-revisao-habilitacao'),
                  onPressed:
                      _solicitandoRevisao ||
                          habilitacao['revisaoSolicitadaEm'] != null
                      ? null
                      : _solicitarRevisao,
                  icon: const Icon(Icons.support_agent),
                  label: Text(
                    _solicitandoRevisao ? 'Enviando...' : 'Solicitar revisão',
                  ),
                ),
                const SizedBox(height: 16),
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
            ),
          );
        },
      ),
    );
  }
}

class _SituacaoDocumentalCard extends StatelessWidget {
  const _SituacaoDocumentalCard({
    required this.situacao,
    required this.onAtualizar,
    required this.onEnviar,
  });

  final SituacaoDocumental situacao;
  final VoidCallback onAtualizar;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (situacao.estado) {
      SituacaoDocumentalEstado.aprovado => (Icons.verified, AppColors.verde),
      SituacaoDocumentalEstado.rejeitado => (
        Icons.error_outline,
        AppColors.erro,
      ),
      SituacaoDocumentalEstado.emAnalise => (
        Icons.hourglass_top,
        const Color(0xFF9A6415),
      ),
      SituacaoDocumentalEstado.naoEnviado => (
        Icons.upload_file_outlined,
        AppColors.textoSuave,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documento necessário para o selo',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icone, color: cor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    situacao.titulo,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(situacao.orientacao),
            if (situacao.motivo?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo informado: ${situacao.motivo}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (situacao.estado == SituacaoDocumentalEstado.naoEnviado ||
                    situacao.estado == SituacaoDocumentalEstado.rejeitado)
                  FilledButton.icon(
                    key: const ValueKey('enviar-documento-identidade'),
                    onPressed: onEnviar,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      situacao.estado == SituacaoDocumentalEstado.rejeitado
                          ? 'Reenviar documento'
                          : 'Enviar documento de identificação',
                    ),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('atualizar-situacao-documental'),
                  onPressed: onAtualizar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar situação'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoIdentidade extends StatelessWidget {
  const _CartaoIdentidade({
    required this.estado,
    required this.disponivel,
    required this.falhaConsulta,
    required this.iniciando,
    required this.consultando,
    required this.onIniciar,
    required this.onConsultar,
  });

  final String estado;
  final bool disponivel;
  final bool falhaConsulta;
  final bool iniciando;
  final bool consultando;
  final VoidCallback onIniciar;
  final VoidCallback onConsultar;

  @override
  Widget build(BuildContext context) {
    final concluida = estado == 'confirmada';
    final pendente = estado == 'pendente' || estado == 'iniciando';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identidade e prova de vida',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(_rotuloIdentidade(estado, disponivel, falhaConsulta)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (disponivel && !concluida)
                  FilledButton.icon(
                    onPressed: iniciando ? null : onIniciar,
                    icon: iniciando
                        ? const ButtonProgressIndicator()
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      iniciando
                          ? 'Preparando...'
                          : pendente
                          ? 'Continuar verificação'
                          : 'Iniciar verificação',
                    ),
                  ),
                if (falhaConsulta ||
                    disponivel && (pendente || estado == 'revisao_necessaria'))
                  OutlinedButton.icon(
                    onPressed: consultando ? null : onConsultar,
                    icon: consultando
                        ? const ButtonProgressIndicator()
                        : const Icon(Icons.refresh),
                    label: Text(
                      consultando ? 'Consultando...' : 'Atualizar status',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoTelefone extends StatelessWidget {
  const _CartaoTelefone({
    required this.dados,
    required this.iniciando,
    required this.confirmando,
    required this.consultando,
    required this.onIniciar,
    required this.onConfirmar,
    required this.onConsultar,
  });

  final Map<String, dynamic> dados;
  final bool iniciando;
  final bool confirmando;
  final bool consultando;
  final VoidCallback onIniciar;
  final VoidCallback onConfirmar;
  final VoidCallback onConsultar;

  @override
  Widget build(BuildContext context) {
    final estado = dados['estado']?.toString() ?? 'nao_iniciada';
    final disponivel = dados['disponivel'] == true;
    final falhaConsulta = dados['falhaConsulta'] == true;
    final pendente = estado == 'pendente';
    final confirmado = estado == 'confirmada';
    final podeIniciar = disponivel && !pendente && !confirmado;
    final telefone = dados['telefoneMascarado']?.toString();
    final tentativas = dados['tentativasRestantes'] is num
        ? (dados['tentativasRestantes'] as num).toInt()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmação de telefone',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(_rotuloTelefone(estado, disponivel, falhaConsulta)),
            if (telefone != null) ...[
              const SizedBox(height: 6),
              Text('Número cadastrado: $telefone'),
            ],
            if (pendente && tentativas != null) ...[
              const SizedBox(height: 6),
              Text('Tentativas restantes: $tentativas'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (podeIniciar)
                  FilledButton.icon(
                    key: const ValueKey('iniciar-confirmacao-telefone'),
                    onPressed: iniciando ? null : onIniciar,
                    icon: iniciando
                        ? const ButtonProgressIndicator()
                        : const Icon(Icons.sms_outlined),
                    label: Text(
                      iniciando
                          ? 'Enviando...'
                          : estado == 'nao_iniciada' ||
                                estado == 'telefone_ausente'
                          ? 'Confirmar por WhatsApp'
                          : 'Tentar novamente',
                    ),
                  ),
                if (pendente && disponivel)
                  FilledButton.icon(
                    key: const ValueKey('informar-codigo-telefone'),
                    onPressed: confirmando ? null : onConfirmar,
                    icon: confirmando
                        ? const ButtonProgressIndicator()
                        : const Icon(Icons.lock_open_outlined),
                    label: Text(
                      confirmando ? 'Confirmando...' : 'Informar código',
                    ),
                  ),
                if (falhaConsulta || disponivel && pendente)
                  OutlinedButton.icon(
                    key: const ValueKey('atualizar-confirmacao-telefone'),
                    onPressed: consultando ? null : onConsultar,
                    icon: consultando
                        ? const ButtonProgressIndicator()
                        : const Icon(Icons.refresh),
                    label: Text(
                      consultando ? 'Consultando...' : 'Atualizar status',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentimentoTelefoneDialog extends StatefulWidget {
  const _ConsentimentoTelefoneDialog();

  @override
  State<_ConsentimentoTelefoneDialog> createState() =>
      _ConsentimentoTelefoneDialogState();
}

class _ConsentimentoTelefoneDialogState
    extends State<_ConsentimentoTelefoneDialog> {
  bool _aceito = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirmar acesso ao telefone'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'O ID ZapSign enviará um código pelo WhatsApp ao número cadastrado. '
            'O ConectaLar receberá somente o resultado da confirmação e não '
            'armazena o código. Esta etapa confirma acesso ao número; não '
            'confirma sua identidade nem habilita automaticamente o perfil '
            'para receber solicitações.',
          ),
          CheckboxListTile(
            key: const ValueKey('consentimento-confirmacao-telefone'),
            contentPadding: EdgeInsets.zero,
            value: _aceito,
            onChanged: (value) => setState(() => _aceito = value == true),
            title: const Text(
              'Li o aviso e autorizo o envio do código para o telefone cadastrado.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('confirmar-consentimento-telefone'),
        onPressed: _aceito ? () => Navigator.pop(context, true) : null,
        child: const Text('Continuar'),
      ),
    ],
  );
}

class _CodigoTelefoneDialog extends StatefulWidget {
  const _CodigoTelefoneDialog({required this.tentativasRestantes});

  final int? tentativasRestantes;

  @override
  State<_CodigoTelefoneDialog> createState() => _CodigoTelefoneDialogState();
}

class _CodigoTelefoneDialogState extends State<_CodigoTelefoneDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Código do WhatsApp'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('codigo-confirmacao-telefone'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: const InputDecoration(
              labelText: 'Código recebido',
              hintText: 'Digite o código numérico',
            ),
          ),
          if (widget.tentativasRestantes != null) ...[
            const SizedBox(height: 8),
            Text('Tentativas restantes: ${widget.tentativasRestantes}'),
          ],
          const SizedBox(height: 8),
          const Text(
            'Se ocorrer um erro de conexão, tente novamente com o mesmo código.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('enviar-codigo-confirmacao-telefone'),
        onPressed: () {
          final codigo = _controller.text;
          if (codigo.isNotEmpty) Navigator.pop(context, codigo);
        },
        child: const Text('Confirmar'),
      ),
    ],
  );
}

String _statusEtapaTelefone(Object? estado) => switch (estado) {
  'confirmada' || 'confirmado' => 'confirmado',
  'pendente' || 'iniciando' || 'em_analise' => 'em_analise',
  'revisao_necessaria' || 'falha' => 'revisao_necessaria',
  'expirada' => 'expirada',
  'invalidada' => 'invalidada',
  'telefone_ausente' => 'telefone_ausente',
  _ => 'aguardando_integracao',
};

String _rotuloTelefone(String estado, bool disponivel, bool falhaConsulta) {
  if (falhaConsulta) {
    return 'Não foi possível consultar o estado agora. Tente atualizar.';
  }
  if (!disponivel && estado == 'nao_iniciada') {
    return 'A confirmação por WhatsApp ainda não está ativada no servidor.';
  }
  if (!disponivel && (estado == 'pendente' || estado == 'iniciando')) {
    return 'Confirmação pendente. O envio está temporariamente desativado.';
  }
  return switch (estado) {
    'telefone_ausente' =>
      'Cadastre um telefone válido nos seus dados antes de iniciar.',
    'iniciando' ||
    'pendente' => 'Aguardando a confirmação do código enviado ao WhatsApp.',
    'confirmada' => 'Acesso ao telefone confirmado.',
    'expirada' => 'O código expirou. Você pode iniciar uma nova confirmação.',
    'invalidada' =>
      'O telefone foi alterado. Inicie uma nova confirmação para o número atual.',
    'revisao_necessaria' || 'falha' =>
      'Não foi possível confirmar automaticamente. Tente novamente mais tarde.',
    _ =>
      disponivel
          ? 'Confirme que você tem acesso ao telefone cadastrado.'
          : 'A confirmação por WhatsApp ainda não está disponível.',
  };
}

String _uuidV4() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class _ConsentimentoIdentidadeDialog extends StatefulWidget {
  const _ConsentimentoIdentidadeDialog();

  @override
  State<_ConsentimentoIdentidadeDialog> createState() =>
      _ConsentimentoIdentidadeDialogState();
}

class _ConsentimentoIdentidadeDialogState
    extends State<_ConsentimentoIdentidadeDialog> {
  bool _aceito = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verificação de identidade'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'A ID ZapSign fará a leitura do seu documento e uma prova de vida com comparação facial. O ConectaLar receberá o resultado. O app não envia imagens biométricas diretamente à API do ConectaLar.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _aceito,
            onChanged: (value) => setState(() => _aceito = value == true),
            title: const Text('Li e autorizo esta verificação de identidade.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _aceito ? () => Navigator.pop(context, true) : null,
        child: const Text('Continuar'),
      ),
    ],
  );
}

String _statusEtapaIdentidade(Object? estado) => switch (estado) {
  'confirmada' => 'confirmado',
  'pendente' || 'iniciando' => 'em_analise',
  'revisao_necessaria' => 'revisao_necessaria',
  _ => 'aguardando_integracao',
};

String _rotuloIdentidade(String estado, bool disponivel, bool falhaConsulta) {
  if (falhaConsulta) {
    return 'Não foi possível consultar agora. Seus documentos continuam disponíveis nesta tela.';
  }
  if (!disponivel && estado == 'nao_iniciada') {
    return 'Verificação ainda não ativada no servidor.';
  }
  if (!disponivel && (estado == 'pendente' || estado == 'iniciando')) {
    return 'Verificação pendente. O serviço está temporariamente desativado.';
  }
  return switch (estado) {
    'pendente' || 'iniciando' => 'Aguardando conclusão da verificação.',
    'confirmada' => 'Identidade confirmada pelo fornecedor.',
    'revisao_necessaria' =>
      'Não foi possível confirmar automaticamente. A equipe precisa revisar o caso.',
    'expirada' => 'O link expirou. Você pode iniciar uma nova verificação.',
    'falha' => 'A verificação não foi concluída. Tente novamente.',
    _ => 'Ainda não iniciada.',
  };
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
          _rotuloTipoDocumento(documento.tipoDocumento),
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

String _rotuloTipoDocumento(String tipo) => switch (tipo) {
  'documento_identidade' => 'Documento de identificação',
  'comprovante_endereco' => 'Comprovante de endereço',
  'certificado_opcional' => 'Certificado profissional',
  _ => 'Documento',
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mensagemErroDocumento(error))));
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

String _mensagemErroDocumento(Object error) {
  final mensagem = error.toString().trim();
  if (mensagem.isEmpty || mensagem == 'Exception') {
    return 'Não foi possível enviar o documento.';
  }
  return mensagem;
}
