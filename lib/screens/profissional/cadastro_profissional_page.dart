import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/solicitacao.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class CadastroProfissionalPage extends StatefulWidget {
  const CadastroProfissionalPage({super.key});

  @override
  State<CadastroProfissionalPage> createState() =>
      _CadastroProfissionalPageState();
}

class _CadastroProfissionalPageState extends State<CadastroProfissionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _precoController = TextEditingController();
  bool _empresa = false;
  bool _perfilSalvo = false;
  bool _salvando = false;
  bool _carregandoPerfil = true;
  bool _editando = false;
  String? _erroPerfil;
  List<Map<String, dynamic>> _ofertasAtuais = [];
  late Future<List<AtendimentoResumo>> _pendentesFuture;

  @override
  void initState() {
    super.initState();
    _pendentesFuture = _carregarPendentes();
    _empresa = AppServices.instance.auth.usuarioAtual?['tipo'] == 'empresa';
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    setState(() {
      _carregandoPerfil = true;
      _erroPerfil = null;
    });
    try {
      if (!AppServices.instance.emDemonstracao) {
        final response = await AppServices.instance.profissionais.meuPerfil();
        if (!mounted) return;
        final perfil = response['profissional'];
        if (perfil is Map<String, dynamic>) {
          _editando = true;
          _descricaoController.text = '${perfil['descricao'] ?? ''}';
          _bairroController.text = '${perfil['bairro'] ?? ''}';
          _precoController.text = '${perfil['precoInicial'] ?? ''}'.replaceAll(
            '.',
            ',',
          );
          _ofertasAtuais = _servicosExistentes(perfil);
        }
      }
    } catch (_) {
      _erroPerfil = 'Não foi possível carregar seus dados profissionais.';
    } finally {
      if (mounted) setState(() => _carregandoPerfil = false);
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _bairroController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  Future<List<AtendimentoResumo>> _carregarPendentes() async {
    final services = AppServices.instance;
    if (services.emDemonstracao) {
      return ConectaLarMockStore.instance.servicos
          .where(
            (servico) =>
                servico.solicitacao.status ==
                StatusSolicitacao.aguardandoResposta,
          )
          .toList(growable: false);
    }

    final response = await services.servicos.minhas();
    return listFromApi(response['solicitacoes'], atendimentoResumoFromApi)
        .where(
          (servico) =>
              servico.solicitacao.status ==
              StatusSolicitacao.aguardandoResposta,
        )
        .toList(growable: false);
  }

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salvando) return;
    final precoInicial = parsePrecoInicial(_precoController.text);
    if (_precoController.text.trim().isNotEmpty && precoInicial == null) return;

    setState(() => _salvando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        final profissionais = AppServices.instance.profissionais;
        final resposta = await profissionais.meuPerfil();
        _ofertasAtuais = _servicosExistentes(resposta['profissional']);
        await profissionais.salvarMeuPerfil({
          'descricao': _descricaoController.text.trim(),
          'bairro': _bairroController.text.trim(),
          'precoInicial': precoInicial,
          'servicos': _ofertasAtuais,
        });
      } else if (!AppServices.instance.emDemonstracao) {
        throw StateError('Entre na sua conta para continuar.');
      }
      if (!mounted) return;
      setState(() => _perfilSalvo = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil profissional salvo.')),
      );
      if (_editando) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.servicosProfissional);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o perfil profissional.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  List<Map<String, dynamic>> _servicosExistentes(Object? perfil) {
    if (perfil is! Map<String, dynamic> || perfil['servicos'] is! List) {
      return const [];
    }

    return (perfil['servicos'] as List)
        .whereType<Map>()
        .map((servico) {
          final categoria = servico['categoria'];
          final categoriaId =
              servico['categoriaId'] ??
              (categoria is Map ? categoria['id'] : null);
          final preco = servico['precoInicial'];
          return <String, dynamic>{
            'id': servico['id'],
            'nome': servico['nome'],
            'categoriaId': ?categoriaId,
            'precoInicial': ?preco,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final store = ConectaLarMockStore.instance;
    return Scaffold(
      appBar: AppBarCustom(
        title: _editando
            ? 'Editar perfil profissional'
            : 'Cadastro profissional',
      ),
      backgroundColor: AppColors.fundo,
      body: _carregandoPerfil
          ? const AsyncLoadingView(label: 'Carregando dados profissionais.')
          : _erroPerfil != null
          ? AsyncErrorView(message: _erroPerfil!, onRetry: _carregarPerfil)
          : AnimatedBuilder(
              animation: store,
              builder: (context, _) => ListView(
                padding: AppInsets.page,
                children: [
                  const Text(
                    'Profissional/Empresa',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  const Text(
                    'Complete os dados de atuação. Depois, configure suas ofertas e envie documentos para análise.',
                    style: TextStyle(color: AppColors.textoSuave),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _EtapasCadastro(
                    onServicos: () => Navigator.pushNamed(
                      context,
                      AppRoutes.servicosProfissional,
                    ),
                    onDocumentos: () => Navigator.pushNamed(
                      context,
                      AppRoutes.documentosProfissional,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _FormularioProfissional(
                    formKey: _formKey,
                    descricaoController: _descricaoController,
                    bairroController: _bairroController,
                    precoController: _precoController,
                    empresa: _empresa,
                    editando: _editando,
                    perfilSalvo: _perfilSalvo,
                    salvando: _salvando,
                    onContinuar: () => _continuar(),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const Text(
                    'Solicitações recebidas',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  FutureBuilder<List<AtendimentoResumo>>(
                    future: _pendentesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const AsyncLoadingView(
                          label: 'Carregando solicitações recebidas.',
                        );
                      }
                      if (snapshot.hasError) {
                        return AsyncErrorView(
                          message: 'Não foi possível carregar as solicitações.',
                          icon: Icons.inbox_outlined,
                          onRetry: () => setState(() {
                            _pendentesFuture = _carregarPendentes();
                            _pendentesFuture.ignore();
                          }),
                        );
                      }
                      final pendentes =
                          snapshot.data ?? const <AtendimentoResumo>[];
                      if (pendentes.isEmpty) {
                        return const EmptyStateView(
                          title: 'Nenhuma solicitação nova',
                          message:
                              'Quando um cliente enviar um pedido, ele aparecerá aqui para sua análise.',
                          icon: Icons.inbox_outlined,
                        );
                      }
                      return Column(
                        children: [
                          for (final atendimento in pendentes) ...[
                            _PedidoRecebidoCard(
                              atendimento: atendimento,
                              store: store,
                              onAtualizado: () => setState(() {
                                _pendentesFuture = _carregarPendentes();
                                _pendentesFuture.ignore();
                              }),
                            ),
                            const SizedBox(height: AppSpace.md),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _FormularioProfissional extends StatelessWidget {
  const _FormularioProfissional({
    required this.formKey,
    required this.descricaoController,
    required this.bairroController,
    required this.precoController,
    required this.empresa,
    required this.editando,
    required this.perfilSalvo,
    required this.salvando,
    required this.onContinuar,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descricaoController;
  final TextEditingController bairroController;
  final TextEditingController precoController;
  final bool empresa;
  final bool editando;
  final bool perfilSalvo;
  final bool salvando;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  empresa ? Icons.business_outlined : Icons.person_outline,
                ),
                title: Text(
                  empresa ? 'Conta de empresa' : 'Profissional autônomo',
                ),
                subtitle: const Text('Tipo de conta definido no cadastro.'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição profissional',
                  hintText: 'Ex.: eletricista residencial',
                ),
                maxLength: 280,
                minLines: 2,
                maxLines: 4,
                validator: (v) => (v ?? '').trim().length < 20
                    ? 'Descreva sua atuação com pelo menos 20 caracteres.'
                    : null,
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: bairroController,
                decoration: const InputDecoration(
                  labelText: 'Bairro/região de atuação',
                ),
                maxLength: 120,
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Informe o bairro ou região.'
                    : null,
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: precoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Preço inicial (opcional)',
                  prefixText: 'R\$ ',
                ),
                validator: validarPrecoOpcional,
              ),
              const SizedBox(height: AppSpace.md),
              const _DocumentoAviso(),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.disponibilidadeProfissional,
                    ),
                    icon: const Icon(Icons.schedule_outlined),
                    label: const Text('Disponibilidade'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.documentosProfissional,
                    ),
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Documentos'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('profissional-continuar'),
                  onPressed: salvando ? null : onContinuar,
                  icon: Icon(
                    salvando
                        ? Icons.hourglass_top_rounded
                        : perfilSalvo
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    salvando
                        ? 'Salvando...'
                        : perfilSalvo
                        ? 'Perfil profissional salvo'
                        : editando
                        ? 'Salvar alterações'
                        : 'Salvar e continuar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtapasCadastro extends StatelessWidget {
  const _EtapasCadastro({required this.onServicos, required this.onDocumentos});

  final VoidCallback onServicos;
  final VoidCallback onDocumentos;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      const _EtapaCadastroPill(numero: '1', titulo: 'Dados', ativa: true),
      _EtapaCadastroPill(numero: '2', titulo: 'Serviços', onTap: onServicos),
      _EtapaCadastroPill(
        numero: '3',
        titulo: 'Documentos',
        onTap: onDocumentos,
      ),
    ],
  );
}

class _EtapaCadastroPill extends StatelessWidget {
  const _EtapaCadastroPill({
    required this.numero,
    required this.titulo,
    this.ativa = false,
    this.onTap,
  });

  final String numero;
  final String titulo;
  final bool ativa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = ativa ? AppColors.verde : AppColors.textoSuave;
    return ActionChip(
      onPressed: onTap,
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: ativa ? AppColors.verde : AppColors.verdeClaro,
        child: Text(
          numero,
          style: TextStyle(
            color: ativa ? Colors.white : AppColors.verdeEscuro,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      label: Text(titulo),
      labelStyle: TextStyle(color: cor, fontWeight: FontWeight.w700),
      backgroundColor: ativa ? AppColors.verdeClaro : Colors.white,
      side: const BorderSide(color: AppColors.borda),
    );
  }
}

class _DocumentoAviso extends StatelessWidget {
  const _DocumentoAviso();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined, color: AppColors.verdeEscuro),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Documentos ficam restritos à administração. O selo só aparece após aprovação e não garante resultado.',
            style: TextStyle(color: AppColors.textoSuave, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _PedidoRecebidoCard extends StatelessWidget {
  const _PedidoRecebidoCard({
    required this.atendimento,
    required this.store,
    required this.onAtualizado,
  });

  final AtendimentoResumo atendimento;
  final ConectaLarMockStore store;
  final VoidCallback onAtualizado;

  @override
  Widget build(BuildContext context) {
    Future<void> transicionar({
      required Future<Map<String, dynamic>> Function(int id) api,
      required bool Function(int id) mock,
      required String sucesso,
    }) async {
      if (AppServices.instance.auth.autenticado) {
        try {
          await api(atendimento.solicitacao.id);
          onAtualizado();
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(sucesso)));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível atualizar a solicitação.'),
            ),
          );
        }
        return;
      }

      mock(atendimento.solicitacao.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sucesso)));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              atendimento.categoria,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              atendimento.solicitacao.descricao,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: ValueKey(
                    'profissional-aceitar-${atendimento.solicitacao.id}',
                  ),
                  onPressed: () => transicionar(
                    api: AppServices.instance.servicos.aceitar,
                    mock: store.aceitarSolicitacaoComoProfissional,
                    sucesso: 'Solicitação aceita.',
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aceitar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => transicionar(
                    api: AppServices.instance.servicos.recusar,
                    mock: store.recusarSolicitacaoComoProfissional,
                    sucesso: 'Solicitação recusada.',
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Recusar'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.conversa,
                    arguments: atendimento.solicitacao.id,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Conversar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
