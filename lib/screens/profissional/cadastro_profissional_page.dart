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

double? _precoInicialFromText(String value) {
  final preco = double.tryParse(value.trim().replaceAll(',', '.'));
  return preco != null && preco.isFinite && preco >= 0 ? preco : null;
}

class CadastroProfissionalPage extends StatefulWidget {
  const CadastroProfissionalPage({super.key});

  @override
  State<CadastroProfissionalPage> createState() =>
      _CadastroProfissionalPageState();
}

class _CadastroProfissionalPageState extends State<CadastroProfissionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _bairroController = TextEditingController(text: 'Jardim das Flores');
  final _precoController = TextEditingController(text: '80');
  bool _empresa = false;
  bool _perfilSalvo = false;
  bool _salvando = false;
  late Future<List<AtendimentoResumo>> _pendentesFuture;

  @override
  void initState() {
    super.initState();
    _pendentesFuture = _carregarPendentes();
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
    if (!services.auth.autenticado) {
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
    final precoInicial = _precoInicialFromText(_precoController.text);
    if (precoInicial == null) return;

    setState(() => _salvando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        final profissionais = AppServices.instance.profissionais;
        final resposta = await profissionais.meuPerfil();
        final servicosAtuais = _servicosExistentes(resposta['profissional']);
        await profissionais.salvarMeuPerfil({
          'descricao': _descricaoController.text.trim(),
          'bairro': _bairroController.text.trim(),
          'precoInicial': precoInicial,
          'servicos': servicosAtuais,
        });
      }
      if (mounted) setState(() => _perfilSalvo = true);
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
      appBar: const AppBarCustom(title: 'Cadastro profissional'),
      backgroundColor: AppColors.fundo,
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const Text(
              'Profissional/Empresa',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Complete os dados de atuação. Depois, configure suas ofertas e envie documentos para análise.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 16),
            _EtapasCadastro(
              onServicos: () =>
                  Navigator.pushNamed(context, AppRoutes.servicosProfissional),
              onDocumentos: () => Navigator.pushNamed(
                context,
                AppRoutes.documentosProfissional,
              ),
            ),
            const SizedBox(height: 16),
            _FormularioProfissional(
              formKey: _formKey,
              descricaoController: _descricaoController,
              bairroController: _bairroController,
              precoController: _precoController,
              empresa: _empresa,
              perfilSalvo: _perfilSalvo,
              salvando: _salvando,
              onEmpresaChanged: (value) => setState(() => _empresa = value),
              onContinuar: () => _continuar(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Solicitações recebidas',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
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
                    onRetry: () =>
                        setState(() => _pendentesFuture = _carregarPendentes()),
                  );
                }
                final pendentes = snapshot.data ?? const <AtendimentoResumo>[];
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
                        onAtualizado: () => setState(
                          () => _pendentesFuture = _carregarPendentes(),
                        ),
                      ),
                      const SizedBox(height: 12),
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
    required this.perfilSalvo,
    required this.salvando,
    required this.onEmpresaChanged,
    required this.onContinuar,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descricaoController;
  final TextEditingController bairroController;
  final TextEditingController precoController;
  final bool empresa;
  final bool perfilSalvo;
  final bool salvando;
  final ValueChanged<bool> onEmpresaChanged;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: empresa,
                onChanged: onEmpresaChanged,
                title: const Text('Atuar como empresa'),
                subtitle: const Text('Vínculos e integrantes dependem de P12.'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição profissional',
                  hintText: 'Ex.: eletricista residencial',
                  border: OutlineInputBorder(),
                ),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bairroController,
                decoration: const InputDecoration(
                  labelText: 'Bairro/região de atuação',
                  border: OutlineInputBorder(),
                ),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: precoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Preço inicial',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _precoInicialFromText(value ?? '') == null
                    ? 'Informe um preço válido.'
                    : null,
              ),
              const SizedBox(height: 12),
              const _DocumentoAviso(),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
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
            const SizedBox(height: 12),
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
