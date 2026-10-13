import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_mappers.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class DenunciarServicoPage extends StatefulWidget {
  const DenunciarServicoPage({super.key});

  @override
  State<DenunciarServicoPage> createState() => _DenunciarServicoPageState();
}

class _DenunciarServicoPageState extends State<DenunciarServicoPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  Future<AtendimentoResumo?>? _future;
  int? _solicitacaoId;
  String _motivo = _motivos.first;
  bool _enviando = false;

  static const _motivos = [
    'Conduta inadequada',
    'Dados falsos',
    'Problema no atendimento',
    'Conteudo ofensivo',
    'Outro',
  ];

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  int? _idFromArguments(Object? arguments) {
    if (arguments is int) return arguments;
    if (arguments is Solicitacao) return arguments.id;
    if (arguments is AtendimentoResumo) return arguments.solicitacao.id;
    return null;
  }

  Future<AtendimentoResumo?> _carregar(Object? arguments) async {
    if (arguments is AtendimentoResumo) return arguments;
    final id = _idFromArguments(arguments);
    if (id == null) return null;
    final response = await AppServices.instance.servicos.obter(id);
    final solicitacao = response['solicitacao'];
    return solicitacao is Map<String, dynamic>
        ? atendimentoResumoFromApi(solicitacao)
        : null;
  }

  int? _denunciadoId(AtendimentoResumo atendimento) {
    final usuario = AppServices.instance.auth.usuarioAtual;
    final usuarioId = intValue(usuario?['id']);
    final tipo = usuario?['tipo'];
    final solicitacao = atendimento.solicitacao;
    if (tipo == 'cliente' && solicitacao.clienteId == usuarioId) {
      return solicitacao.profissionalUsuarioId;
    }
    if ({'profissional', 'empresa'}.contains(tipo) &&
        solicitacao.profissionalUsuarioId == usuarioId) {
      return solicitacao.clienteId;
    }
    return null;
  }

  Future<void> _enviar(AtendimentoResumo atendimento) async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    final denunciadoId = _denunciadoId(atendimento);
    if (denunciadoId == null || denunciadoId <= 0) {
      _snack('Não foi possível identificar a outra parte do atendimento.');
      return;
    }

    setState(() => _enviando = true);
    try {
      await AppServices.instance.denuncias.criar(
        solicitacaoId: atendimento.solicitacao.id,
        denunciadoId: denunciadoId,
        motivo: _motivo,
        descricao: _descricaoController.text,
      );
      if (!mounted) return;
      _snack('Denúncia enviada para análise administrativa.');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _snack(error.message);
    } catch (_) {
      _snack('Não foi possível enviar a denúncia. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _snack(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final id = _idFromArguments(arguments);
    if (_future == null || _solicitacaoId != id) {
      _solicitacaoId = id;
      _future = _carregar(arguments);
      _future?.ignore();
    }

    return Scaffold(
      appBar: const AppBarCustom(title: 'Denunciar atendimento'),
      backgroundColor: AppColors.fundo,
      body: FutureBuilder<AtendimentoResumo?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(label: 'Carregando atendimento.');
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar este atendimento.',
              onRetry: () => setState(() {
                _future = _carregar(arguments);
                _future?.ignore();
              }),
            );
          }
          final atendimento = snapshot.data;
          if (atendimento == null) {
            return const EmptyStateView(
              title: 'Atendimento indisponível',
              message: 'Abra a denúncia pelos detalhes de um atendimento.',
              icon: Icons.flag_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relato para moderação',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${atendimento.profissional} - ${atendimento.categoria}',
                        style: const TextStyle(color: AppColors.textoSuave),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Explique o que aconteceu com clareza. A equipe administrativa analisará o relato e poderá solicitar mais informações.',
                        style: TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _motivo,
                          decoration: const InputDecoration(
                            labelText: 'Motivo',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final motivo in _motivos)
                              DropdownMenuItem(
                                value: motivo,
                                child: Text(
                                  motivo == 'Conteudo ofensivo'
                                      ? 'Conteúdo ofensivo'
                                      : motivo,
                                ),
                              ),
                          ],
                          onChanged: _enviando
                              ? null
                              : (value) => setState(
                                  () => _motivo = value ?? _motivos.first,
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descricaoController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText:
                                'Descreva o problema com pelo menos 20 caracteres.',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 5,
                          maxLines: 8,
                          validator: (value) {
                            final erro = validarCampoObrigatorio(value);
                            if (erro != null) return erro;
                            return value!.trim().length < 20
                                ? 'Descreva melhor o ocorrido.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _enviando
                              ? null
                              : () => _enviar(atendimento),
                          icon: _enviando
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.flag_outlined),
                          label: Text(
                            _enviando ? 'Enviando...' : 'Enviar denúncia',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
