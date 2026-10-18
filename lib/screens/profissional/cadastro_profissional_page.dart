import 'package:flutter/material.dart';

import '../../widgets/unsaved_form_guard.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../services/service_registry.dart';
import '../../services/api_service.dart';
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
      if (mounted) setState(() => _carregandoPerfil = false);
    }
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
        final resposta = await profissionais.meuPerfil();
        _ofertasAtuais = _servicosExistentes(resposta['profissional']);
        await profissionais.salvarMeuPerfil({
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
            'duracaoMinutos': servico['duracaoMinutos'] ?? 120,
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
