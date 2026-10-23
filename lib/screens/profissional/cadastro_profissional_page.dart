import 'package:flutter/material.dart';

import '../../widgets/unsaved_form_guard.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../services/api_service.dart';
import '../../utils/situacao_documental.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import '../../widgets/async_state_view.dart';

class CadastroProfissionalPage extends StatefulWidget {
  const CadastroProfissionalPage({super.key});

  @override
  State<CadastroProfissionalPage> createState() =>
      _CadastroProfissionalPageState();
}

class _CadastroProfissionalPageState extends State<CadastroProfissionalPage> {
  final _formKey = GlobalKey<FormState>();
  List<String> _valoresIniciais = [];
  List<TextEditingController> get _campos => [
    _descricaoController,
    _bairroController,
    _cepController,
    _cidadeController,
    _ufController,
    _raioController,
    _precoController,
  ];
  final _descricaoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cepController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _raioController = TextEditingController(text: '15');
  final _precoController = TextEditingController();
  bool _empresa = false;
  bool _perfilSalvo = false;
  bool _salvando = false;
  bool _carregandoPerfil = true;
  bool _editando = false;
  String? _erroPerfil;
  List<Map<String, dynamic>> _ofertasAtuais = [];
  bool _consultandoCep = false;
  String? _ultimoCepConsultado;
  Map<String, dynamic>? _perfilAtual;
  List<Map<String, dynamic>> _disponibilidades = const [];
  SituacaoDocumental? _situacaoDocumental;
  Map<String, dynamic> _habilitacao = const {};

  @override
  void initState() {
    super.initState();
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
          _perfilAtual = Map<String, dynamic>.from(perfil);
          _editando = true;
          _descricaoController.text = '${perfil['descricao'] ?? ''}';
          _bairroController.text = '${perfil['bairro'] ?? ''}';
          _cepController.text = '${perfil['cep'] ?? ''}';
          _cidadeController.text = '${perfil['cidade'] ?? ''}';
          _ufController.text = '${perfil['uf'] ?? ''}';
          _raioController.text = '${perfil['raioAtendimentoKm'] ?? 15}';
          _precoController.text = '${perfil['precoInicial'] ?? ''}'.replaceAll(
            '.',
            ',',
          );
          _ofertasAtuais = _servicosExistentes(perfil);
        }
      }
      _valoresIniciais = _campos.map((c) => c.text).toList();
    } catch (_) {
      _erroPerfil = 'Não foi possível carregar seus dados profissionais.';
    } finally {
      if (mounted) {
        setState(() => _carregandoPerfil = false);
        _carregarProgressoComplementar().then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  Future<void> _carregarProgressoComplementar() async {
    try {
      final response = await AppServices.instance.profissionais.meusServicos();
      if (response['servicos'] is List) {
        _ofertasAtuais = _servicosExistentes({
          'servicos': response['servicos'],
        });
      }
    } catch (_) {
      // O perfil ainda mantém as ofertas ativas disponíveis para edição.
    }
    try {
      final response = await AppServices.instance.profissionais
          .minhaDisponibilidade();
      _disponibilidades = (response['disponibilidades'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      _disponibilidades = const [];
    }
    try {
      final response = await AppServices.instance.verificacao.meusDocumentos();
      final documentos = listFromApi(
        response['documentos'],
        documentoVerificacaoFromApi,
      );
      _situacaoDocumental = situacaoDocumentoIdentidade(documentos);
      final habilitacao = response['habilitacao'];
      _habilitacao = habilitacao is Map
          ? Map<String, dynamic>.from(habilitacao)
          : const {};
    } catch (_) {
      _situacaoDocumental = null;
      _habilitacao = const {};
    }
  }

  Future<void> _abrirEtapa(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) await _carregarPerfil();
  }

  void _abrirPerfilPublico() {
    final perfil = _perfilAtual;
    if (perfil == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.perfilProfissional,
      arguments: profissionalFromApi(perfil),
    );
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _bairroController.dispose();
    _cepController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _raioController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salvando) return;
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    final uf = _ufController.text.trim();
    final raio = int.tryParse(_raioController.text.trim());
    if ((cep.isNotEmpty && cep.length != 8) ||
        (uf.isNotEmpty && uf.length != 2) ||
        raio == null ||
        raio < 1 ||
        raio > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confira o CEP, a UF e o raio de atendimento.'),
        ),
      );
      return;
    }
    final precoInicial = parsePrecoInicial(_precoController.text);
    if (_precoController.text.trim().isNotEmpty && precoInicial == null) return;

    setState(() => _salvando = true);
    try {
      if (AppServices.instance.auth.autenticado) {
        final profissionais = AppServices.instance.profissionais;
        final respostas = await Future.wait([
          profissionais.meuPerfil(),
          profissionais.meusServicos(),
        ]);
        final perfilAtual = respostas[0]['profissional'];
        final resposta = respostas[1];
        if (resposta['servicos'] is List) {
          _ofertasAtuais = _servicosExistentes({
            'servicos': resposta['servicos'],
          });
        } else if (perfilAtual is Map<String, dynamic>) {
          _ofertasAtuais = _servicosExistentes(perfilAtual);
        }
        final salvo = await profissionais.salvarMeuPerfil({
          'descricao': _descricaoController.text.trim(),
          'bairro': _bairroController.text.trim(),
          'cep': _cepController.text.trim().isEmpty
              ? null
              : _cepController.text.trim(),
          'cidade': _cidadeController.text.trim().isEmpty
              ? null
              : _cidadeController.text.trim(),
          'uf': _ufController.text.trim().isEmpty
              ? null
              : _ufController.text.trim().toUpperCase(),
          'raioAtendimentoKm': raio,
          'precoInicial': precoInicial,
          'servicos': _ofertasAtuais,
        });
        final perfil = salvo['profissional'];
        if (perfil is Map<String, dynamic>) {
          _perfilAtual = Map<String, dynamic>.from(perfil);
          _ofertasAtuais = _servicosExistentes(perfil);
        }
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

  Future<void> _consultarCep([String? valor]) async {
    final cep = (valor ?? _cepController.text).replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8 || _consultandoCep || cep == _ultimoCepConsultado) {
      return;
    }
    setState(() => _consultandoCep = true);
    try {
      final endereco = await AppServices.instance.localizacao.consultarCep(cep);
      if (!mounted) return;
      _ultimoCepConsultado = cep;
      _cepController.text = '${endereco['cep'] ?? cep}';
      _bairroController.text = '${endereco['bairro'] ?? ''}';
      _cidadeController.text = '${endereco['cidade'] ?? ''}';
      _ufController.text = '${endereco['uf'] ?? ''}';
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Região de atendimento preenchida pelo CEP.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
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
            'duracaoMinutos': servico['duracaoMinutos'] ?? 60,
            'intervaloMinutos': servico['intervaloMinutos'] ?? 30,
            'ativo': servico['ativo'] != false,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedFormGuard(
      controllers: _campos,
      initialValues: _valoresIniciais,
      busy: _salvando,
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
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
                    dadosConcluidos: _perfilAtual != null,
                    servicosConcluidos: _ofertasAtuais.any(
                      (item) => item['ativo'] != false,
                    ),
                    disponibilidadeConcluida: _disponibilidades.any(
                      (item) => item['ativo'] != false,
                    ),
                    documentosConcluidos:
                        _situacaoDocumental?.estado ==
                        SituacaoDocumentalEstado.aprovado,
                    onServicos: () =>
                        _abrirEtapa(AppRoutes.servicosProfissional),
                    onDisponibilidade: () =>
                        _abrirEtapa(AppRoutes.disponibilidadeProfissional),
                    onDocumentos: () =>
                        _abrirEtapa(AppRoutes.documentosProfissional),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _FormularioProfissional(
                    formKey: _formKey,
                    descricaoController: _descricaoController,
                    bairroController: _bairroController,
                    cepController: _cepController,
                    cidadeController: _cidadeController,
                    ufController: _ufController,
                    raioController: _raioController,
                    precoController: _precoController,
                    empresa: _empresa,
                    editando: _editando,
                    perfilSalvo: _perfilSalvo,
                    salvando: _salvando,
                    consultandoCep: _consultandoCep,
                    onConsultarCep: _consultarCep,
                    onContinuar: () => _continuar(),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _ChecklistCadastro(
                    perfilCriado: _perfilAtual != null,
                    possuiServico: _ofertasAtuais.any(
                      (item) => item['ativo'] != false,
                    ),
                    possuiDisponibilidade: _disponibilidades.any(
                      (item) => item['ativo'] != false,
                    ),
                    emailConfirmado: AppServices.instance.auth.emailVerificado,
                    situacaoDocumental: _situacaoDocumental,
                    habilitado: _habilitacao['podeAtender'] == true,
                    onVerPerfil: _perfilAtual == null
                        ? null
                        : _abrirPerfilPublico,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const _PedidosNoPerfilRemovidos(),
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
    required this.cepController,
    required this.cidadeController,
    required this.ufController,
    required this.raioController,
    required this.precoController,
    required this.empresa,
    required this.editando,
    required this.perfilSalvo,
    required this.salvando,
    required this.consultandoCep,
    required this.onConsultarCep,
    required this.onContinuar,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descricaoController;
  final TextEditingController bairroController;
  final TextEditingController cepController;
  final TextEditingController cidadeController;
  final TextEditingController ufController;
  final TextEditingController raioController;
  final TextEditingController precoController;
  final bool empresa;
  final bool editando;
  final bool perfilSalvo;
  final bool salvando;
  final bool consultandoCep;
  final ValueChanged<String?> onConsultarCep;
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
              TextField(
                controller: cepController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'CEP da região de atendimento',
                  hintText: '00000-000',
                  helperText: 'O endereço exato não será exibido publicamente.',
                  suffixIcon: consultandoCep
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Buscar CEP',
                          onPressed: () => onConsultarCep(cepController.text),
                          icon: const Icon(Icons.search_rounded),
                        ),
                ),
                onChanged: (value) {
                  if (value.replaceAll(RegExp(r'\D'), '').length == 8) {
                    onConsultarCep(value);
                  }
                },
                onSubmitted: onConsultarCep,
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
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: cidadeController,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: ufController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'UF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: raioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Raio de atendimento',
                  suffixText: 'km',
                  helperText: 'De 1 a 200 km a partir da região informada.',
                ),
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
                  icon: salvando
                      ? const ButtonProgressIndicator()
                      : Icon(
                          perfilSalvo
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward_rounded,
                        ),
                  label: ActionLabel(
                    busy: salvando,
                    text: salvando
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
  const _EtapasCadastro({
    required this.dadosConcluidos,
    required this.servicosConcluidos,
    required this.disponibilidadeConcluida,
    required this.documentosConcluidos,
    required this.onServicos,
    required this.onDisponibilidade,
    required this.onDocumentos,
  });

  final bool dadosConcluidos;
  final bool servicosConcluidos;
  final bool disponibilidadeConcluida;
  final bool documentosConcluidos;
  final VoidCallback onServicos;
  final VoidCallback onDisponibilidade;
  final VoidCallback onDocumentos;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _EtapaCadastroPill(
        numero: '1',
        titulo: 'Dados',
        ativa: true,
        concluida: dadosConcluidos,
      ),
      _EtapaCadastroPill(
        numero: '2',
        titulo: 'Serviços',
        concluida: servicosConcluidos,
        onTap: onServicos,
      ),
      _EtapaCadastroPill(
        numero: '3',
        titulo: 'Disponibilidade',
        concluida: disponibilidadeConcluida,
        onTap: onDisponibilidade,
      ),
      _EtapaCadastroPill(
        numero: '4',
        titulo: 'Documentos',
        concluida: documentosConcluidos,
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
    this.concluida = false,
    this.onTap,
  });

  final String numero;
  final String titulo;
  final bool ativa;
  final bool concluida;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = ativa || concluida ? AppColors.verde : AppColors.textoSuave;
    return ActionChip(
      onPressed: onTap,
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: ativa ? AppColors.verde : AppColors.verdeClaro,
        child: concluida
            ? Icon(
                Icons.check,
                size: 15,
                color: ativa ? Colors.white : AppColors.verdeEscuro,
              )
            : Text(
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

class _ChecklistCadastro extends StatelessWidget {
  const _ChecklistCadastro({
    required this.perfilCriado,
    required this.possuiServico,
    required this.possuiDisponibilidade,
    required this.emailConfirmado,
    required this.situacaoDocumental,
    required this.habilitado,
    required this.onVerPerfil,
  });

  final bool perfilCriado;
  final bool possuiServico;
  final bool possuiDisponibilidade;
  final bool emailConfirmado;
  final SituacaoDocumental? situacaoDocumental;
  final bool habilitado;
  final VoidCallback? onVerPerfil;

  @override
  Widget build(BuildContext context) {
    final documentoAprovado =
        situacaoDocumental?.estado == SituacaoDocumentalEstado.aprovado;
    final itens = [
      (
        'Dados profissionais',
        perfilCriado,
        'Preencha sua apresentação e região.',
      ),
      ('Serviço ativo', possuiServico, 'Cadastre ao menos uma oferta ativa.'),
      (
        'Disponibilidade',
        possuiDisponibilidade,
        'Informe ao menos um período semanal.',
      ),
      (
        'E-mail confirmado',
        emailConfirmado,
        'Confirme o código enviado por e-mail.',
      ),
      (
        'Documento de identificação',
        documentoAprovado,
        situacaoDocumental?.orientacao ?? 'Envie o documento para análise.',
      ),
    ];
    final concluidos = itens.where((item) => item.$2).length;
    return Card(
      key: const ValueKey('checklist-cadastro-profissional'),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preparação para receber solicitações',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '$concluidos de ${itens.length} itens básicos concluídos',
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: AppSpace.sm),
            LinearProgressIndicator(value: concluidos / itens.length),
            const SizedBox(height: AppSpace.md),
            for (final item in itens)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.$2
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: item.$2 ? AppColors.verde : AppColors.textoSuave,
                      size: 21,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (!item.$2)
                            Text(
                              item.$3,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  habilitado
                      ? Icons.verified_user_rounded
                      : Icons.security_outlined,
                  color: habilitado ? AppColors.verde : AppColors.textoSuave,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    habilitado
                        ? 'Habilitação de segurança concluída. Seu perfil pode receber solicitações.'
                        : 'Mesmo após concluir os itens básicos, o atendimento só é liberado quando todas as verificações de segurança forem aprovadas.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            OutlinedButton.icon(
              onPressed: onVerPerfil,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver meu perfil público'),
            ),
          ],
        ),
      ),
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

class _PedidosNoPerfilRemovidos extends StatelessWidget {
  const _PedidosNoPerfilRemovidos();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.inbox_outlined, color: AppColors.verde),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedidos ficam na área profissional',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Aceitar, recusar e conversar com clientes aparece em Pedidos ou Agenda. Esta tela fica dedicada aos seus dados profissionais.',
                    style: TextStyle(color: AppColors.textoSuave, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
