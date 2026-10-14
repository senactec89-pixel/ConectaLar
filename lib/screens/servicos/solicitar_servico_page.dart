import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/conectalar_mock_store.dart';
import '../../models/cliente_endereco.dart';
import '../../models/disponibilidade.dart';
import '../../models/profissional.dart';
import '../../services/api_mappers.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';

class SolicitarServicoPage extends StatefulWidget {
  const SolicitarServicoPage({super.key});

  @override
  State<SolicitarServicoPage> createState() => _SolicitarServicoPageState();
}

class _SolicitarServicoPageState extends State<SolicitarServicoPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _dataController = TextEditingController();
  final _horarioController = TextEditingController();

  Profissional? _profissional;
  int? _ofertaSelecionadaId;
  OfertaProfissional? get _ofertaSelecionada {
    for (final oferta
        in _profissional?.ofertasParaSolicitacao ?? <OfertaProfissional>[]) {
      if (oferta.id == _ofertaSelecionadaId) return oferta;
    }
    return null;
  }

  bool _argumentosLidos = false;
  bool _solicitacaoEnviada = false;
  bool _enviando = false;
  int? _solicitacaoId;
  int? _enderecoSelecionadoId;
  int? _enderecoInicialId;
  int? _ofertaInicialId;
  String _bairroInicial = '';
  bool _confirmandoSaida = false;
  Future<List<ClienteEndereco>>? _enderecosFuture;
  Future<List<Disponibilidade>>? _disponibilidadeFuture;
  List<ClienteEndereco> _enderecos = const [];
  List<Disponibilidade> _disponibilidades = const [];
  bool _enderecosCarregados = false;
  bool _erroEnderecos = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Profissional) {
      _profissional = arguments;
      _ofertaSelecionadaId = arguments.ofertasParaSolicitacao.first.id;
      _ofertaInicialId = _ofertaSelecionadaId;
      _bairroController.text = arguments.bairro;
      _bairroInicial = arguments.bairro;
      _enderecosFuture = _carregarEnderecos();
      _disponibilidadeFuture = _carregarDisponibilidade(arguments.id);
    }
    _argumentosLidos = true;
  }

  Future<List<ClienteEndereco>> _carregarEnderecos() async {
    _enderecosCarregados = false;
    _erroEnderecos = false;
    if (!AppServices.instance.auth.autenticado) return const [];
    try {
      final response = await AppServices.instance.clientes.listarEnderecos();
      if (response['enderecos'] is! List) {
        throw const FormatException('Resposta de endereços inválida.');
      }
      final enderecos = listFromApi(
        response['enderecos'],
        clienteEnderecoFromApi,
      );
      ClienteEndereco? selecionado;
      for (final endereco in enderecos) {
        if (endereco.id == _enderecoSelecionadoId) {
          selecionado = endereco;
          break;
        }
      }
      if (selecionado == null) {
        for (final endereco in enderecos) {
          if (endereco.principal) {
            selecionado = endereco;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _enderecos = enderecos;
          _enderecosCarregados = true;
          _enderecoSelecionadoId = selecionado?.id;
          _enderecoInicialId ??= selecionado?.id;
          if (selecionado != null) {
            _bairroController.text = selecionado.bairro;
            _bairroInicial = selecionado.bairro;
          }
        });
      }
      return enderecos;
    } catch (_) {
      if (mounted) {
        setState(() {
          _enderecos = const [];
          _erroEnderecos = true;
        });
      }
      rethrow;
    }
  }

  Future<List<Disponibilidade>> _carregarDisponibilidade(
    int profissionalId,
  ) async {
    if (AppServices.instance.emDemonstracao) return const [];
    final response = await AppServices.instance.profissionais
        .disponibilidadePublica(profissionalId);
    if (response['disponibilidades'] is! List) {
      throw const FormatException('Resposta de disponibilidade inválida.');
    }
    final disponibilidades = listFromApi(
      response['disponibilidades'],
      disponibilidadeFromApi,
    );
    if (mounted) {
      setState(() => _disponibilidades = disponibilidades);
    }
    return disponibilidades;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _bairroController.dispose();
    _dataController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitacao() async {
    if (_enviando) return;
    if (AppServices.instance.auth.autenticado && !_enderecosCarregados) {
      _mostrarErro(
        _erroEnderecos
            ? 'Não foi possível consultar seus endereços. Tente novamente antes de enviar.'
            : 'Aguarde o carregamento dos seus endereços antes de enviar.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final profissional = _profissional;
    if (profissional == null) return;
    if (AppServices.instance.auth.autenticado && _enderecos.isEmpty) {
      _mostrarErro(
        'Cadastre um endereço antes de solicitar atendimento para liberar o local com segurança após o aceite.',
      );
      return;
    }
    if (AppServices.instance.auth.autenticado &&
        _enderecos.isNotEmpty &&
        _enderecoSelecionadoId == null) {
      _mostrarErro('Selecione um endereço cadastrado.');
      return;
    }
    final data = _parseData(_dataController.text);
    if (data == null) {
      _mostrarErro('Informe uma data válida no formato DD/MM/AAAA.');
      return;
    }
    final horario = _normalizarHorario(_horarioController.text);
    if (horario == null) {
      _mostrarErro('Informe um horário válido no formato HH:MM.');
      return;
    }
    if (!_dataNaoPassou(data)) {
      _mostrarErro('Escolha uma data de hoje em diante.');
      return;
    }
    if (_disponibilidades.isNotEmpty &&
        !_horarioDentroDaDisponibilidade(data, horario, _disponibilidades)) {
      _mostrarErro(
        'Escolha uma data e horário dentro da disponibilidade informada pelo profissional.',
      );
      return;
    }

    if (AppServices.instance.emDemonstracao) {
      _criarSolicitacaoMock(profissional);
      return;
    }
    setState(() => _enviando = true);
    try {
      final response = await AppServices.instance.servicos.solicitar({
        'profissionalId': profissional.id,
        'categoriaId': _ofertaSelecionada?.categoriaId,
        if ((_ofertaSelecionada?.id ?? 0) > 0)
          'servicoId': _ofertaSelecionada!.id,
        'enderecoId': _enderecoSelecionadoId,
        'descricao': _descricaoController.text,
        'bairroAtendimento': _bairroController.text,
        'dataServico': _dataApi(data),
        'horarioServico': horario,
      });
      if (!mounted) return;
      final solicitacao = response['solicitacao'];
      setState(() {
        _solicitacaoEnviada = true;
        _solicitacaoId = solicitacao is Map<String, dynamic>
            ? solicitacao['id'] as int?
            : null;
      });
    } on ApiException catch (error) {
      _mostrarErro(error.message);
    } catch (_) {
      _mostrarErro('Não foi possível enviar a solicitação. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _criarSolicitacaoMock(Profissional profissional) {
    final solicitacaoId = ConectaLarMockStore.instance.criarSolicitacao(
      profissional: profissional,
      servico: _ofertaSelecionada?.nome ?? profissional.descricao,
      descricao: _descricaoController.text,
      bairro: _bairroController.text,
      data: _parseData(_dataController.text) ?? DateTime.now(),
      horario: _horarioController.text,
    );

    setState(() {
      _solicitacaoEnviada = true;
      _solicitacaoId = solicitacaoId;
    });
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  bool get _temRascunho =>
      _descricaoController.text.trim().isNotEmpty ||
      _dataController.text.trim().isNotEmpty ||
      _horarioController.text.trim().isNotEmpty ||
      _bairroController.text.trim() != _bairroInicial.trim() ||
      _ofertaSelecionadaId != _ofertaInicialId ||
      _enderecoSelecionadoId != _enderecoInicialId;

  Future<void> _confirmarSaida() async {
    if (_confirmandoSaida) return;
    if (_enviando) {
      _mostrarErro('Aguarde o envio da solicitação antes de sair.');
      return;
    }
    if (_solicitacaoEnviada || !_temRascunho) {
      Navigator.of(context).pop();
      return;
    }
    _confirmandoSaida = true;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar solicitação?'),
        content: const Text(
          'Os dados preenchidos serão perdidos se você sair agora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar preenchendo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _confirmandoSaida = false;
    if (mounted && descartar == true) Navigator.of(context).pop();
  }

  Future<void> _cadastrarEndereco() async {
    await Navigator.pushNamed(context, AppRoutes.enderecos);
    if (!mounted) return;
    _recarregarEnderecos();
  }

  void _recarregarEnderecos() {
    setState(() {
      _enderecosFuture = _carregarEnderecos();
      _enderecosFuture?.ignore();
    });
  }

  void _recarregarDisponibilidade() {
    final profissional = _profissional;
    if (profissional == null) return;
    setState(() {
      _disponibilidades = const [];
      _disponibilidadeFuture = _carregarDisponibilidade(profissional.id);
      _disponibilidadeFuture?.ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profissional = _profissional;
    return PopScope(
      canPop: _solicitacaoEnviada,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSaida();
      },
      child: Scaffold(
        backgroundColor: AppColors.fundo,
        appBar: const AppBarCustom(title: 'Solicitar serviço'),
        body: profissional == null
            ? const _SolicitacaoIndisponivel()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  _ResumoProfissional(
                    profissional: profissional,
                    precoInicial: _ofertaSelecionada == null
                        ? profissional.precoInicial
                        : _ofertaSelecionada!.precoInicial,
                  ),
                  const SizedBox(height: 14),
                  if (_solicitacaoEnviada)
                    _SolicitacaoEnviada(
                      profissional: profissional,
                      servico:
                          _ofertaSelecionada?.nome ?? profissional.descricao,
                      solicitacaoId: _solicitacaoId,
                      onVerServicos: () =>
                          Navigator.pushNamed(context, AppRoutes.meusServicos),
                    )
                  else
                    _FormularioSolicitacao(
                      formKey: _formKey,
                      profissional: profissional,
                      ofertaSelecionadaId: _ofertaSelecionadaId,
                      descricaoController: _descricaoController,
                      bairroController: _bairroController,
                      dataController: _dataController,
                      horarioController: _horarioController,
                      enderecoSelecionadoId: _enderecoSelecionadoId,
                      enderecosFuture: _enderecosFuture,
                      disponibilidadeFuture: _disponibilidadeFuture,
                      onOfertaChanged: (id) =>
                          setState(() => _ofertaSelecionadaId = id),
                      onEnderecoChanged: (endereco) => setState(() {
                        _enderecoSelecionadoId = endereco.id;
                        _bairroController.text = endereco.bairro;
                      }),
                      onCadastrarEndereco: _cadastrarEndereco,
                      onRetryEnderecos: _recarregarEnderecos,
                      onRetryDisponibilidade: _recarregarDisponibilidade,
                      onSubmit: _enviarSolicitacao,
                      enviando: _enviando,
                    ),
                ],
              ),
      ),
    );
  }
}

class _ResumoProfissional extends StatelessWidget {
  const _ResumoProfissional({required this.profissional, this.precoInicial});

  final double? precoInicial;

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.verdeClaro,
              foregroundColor: AppColors.verde,
              backgroundImage: profissional.fotoUrl != null
                  ? NetworkImage(profissional.fotoUrl!)
                  : profissional.fotoAsset == null
                  ? null
                  : AssetImage(profissional.fotoAsset!),
              child:
                  profissional.fotoUrl == null && profissional.fotoAsset == null
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profissional.nome,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _precoTexto(precoInicial),
                    style: const TextStyle(
                      color: AppColors.verde,
                      fontWeight: FontWeight.w700,
                    ),
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

class _FormularioSolicitacao extends StatelessWidget {
  const _FormularioSolicitacao({
    required this.formKey,
    required this.profissional,
    required this.ofertaSelecionadaId,
    required this.descricaoController,
    required this.bairroController,
    required this.dataController,
    required this.horarioController,
    required this.enderecoSelecionadoId,
    required this.enderecosFuture,
    required this.disponibilidadeFuture,
    required this.onOfertaChanged,
    required this.onEnderecoChanged,
    required this.onCadastrarEndereco,
    required this.onRetryEnderecos,
    required this.onRetryDisponibilidade,
    required this.onSubmit,
    required this.enviando,
  });

  final GlobalKey<FormState> formKey;
  final Profissional profissional;
  final int? ofertaSelecionadaId;
  final TextEditingController descricaoController;
  final TextEditingController bairroController;
  final TextEditingController dataController;
  final TextEditingController horarioController;
  final int? enderecoSelecionadoId;
  final Future<List<ClienteEndereco>>? enderecosFuture;
  final Future<List<Disponibilidade>>? disponibilidadeFuture;
  final ValueChanged<int?> onOfertaChanged;
  final ValueChanged<ClienteEndereco> onEnderecoChanged;
  final Future<void> Function() onCadastrarEndereco;
  final VoidCallback onRetryEnderecos;
  final VoidCallback onRetryDisponibilidade;
  final Future<void> Function() onSubmit;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final ofertas = profissional.ofertasParaSolicitacao;

    return Form(
      key: formKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10153B31),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dados da solicitação',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: const ValueKey('solicitar-servico'),
                isExpanded: true,
                initialValue: ofertaSelecionadaId,
                decoration: const InputDecoration(
                  labelText: 'Serviço desejado',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final oferta in ofertas)
                    DropdownMenuItem(
                      value: oferta.id,
                      child: Text(oferta.nome, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onOfertaChanged,
                validator: (id) => id == null ? 'Selecione um serviço.' : null,
              ),
              const SizedBox(height: 12),
              if (enderecosFuture != null)
                FutureBuilder<List<ClienteEndereco>>(
                  future: enderecosFuture,
                  builder: (context, snapshot) {
                    final enderecos =
                        snapshot.data ?? const <ClienteEndereco>[];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _ConsultaAviso(
                          titulo: 'Carregando seus endereços…',
                          carregando: true,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EnderecoErroAviso(onRetry: onRetryEnderecos),
                      );
                    }
                    if (enderecos.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EnderecoObrigatorioAviso(
                          onCadastrar: onCadastrarEndereco,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue:
                              enderecos.any(
                                (endereco) =>
                                    endereco.id == enderecoSelecionadoId,
                              )
                              ? enderecoSelecionadoId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Endereço cadastrado',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final endereco in enderecos)
                              DropdownMenuItem(
                                value: endereco.id,
                                child: Text(
                                  endereco.resumo,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) {
                            for (final endereco in enderecos) {
                              if (endereco.id == id) {
                                onEnderecoChanged(endereco);
                                break;
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              TextFormField(
                key: const ValueKey('solicitar-bairro'),
                controller: bairroController,
                decoration: const InputDecoration(
                  labelText: 'Bairro do atendimento',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 12),
              if (disponibilidadeFuture != null)
                FutureBuilder<List<Disponibilidade>>(
                  future: disponibilidadeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _ConsultaAviso(
                          titulo: 'Consultando disponibilidade…',
                          carregando: true,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ConsultaAviso(
                          titulo:
                              'Não foi possível consultar a disponibilidade.',
                          mensagem:
                              'Tente novamente para ver os horários informados pelo profissional.',
                          icon: Icons.wifi_off_outlined,
                          onRetry: onRetryDisponibilidade,
                          retryKey: const ValueKey(
                            'disponibilidade-tentar-novamente',
                          ),
                        ),
                      );
                    }
                    final itens = snapshot.data ?? const <Disponibilidade>[];
                    if (itens.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _ConsultaAviso(
                          titulo: 'Nenhum horário informado',
                          mensagem:
                              'O profissional ainda não informou sua disponibilidade. A data desejada depende do aceite dele.',
                          icon: Icons.event_note_outlined,
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DisponibilidadeResumo(itens: itens),
                          const SizedBox(height: 10),
                          _SugestoesAgenda(
                            itens: itens,
                            dataController: dataController,
                            horarioController: horarioController,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final data = TextFormField(
                    key: const ValueKey('solicitar-data'),
                    controller: dataController,
                    decoration: const InputDecoration(
                      labelText: 'Data desejada',
                      hintText: 'DD/MM/AAAA',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    onTap: () => _selecionarData(context, dataController),
                    validator: validarDataSolicitacao,
                  );
                  final horario = TextFormField(
                    key: const ValueKey('solicitar-horario'),
                    controller: horarioController,
                    decoration: const InputDecoration(
                      labelText: 'Horário',
                      hintText: 'HH:MM',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.schedule_rounded),
                    ),
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    onTap: () => _selecionarHorario(context, horarioController),
                    validator: validarHorarioSolicitacao,
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20) {
                    return Column(
                      children: [data, const SizedBox(height: 12), horario],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: data),
                      const SizedBox(width: 10),
                      Expanded(child: horario),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('solicitar-descricao'),
                controller: descricaoController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Descreva a necessidade',
                  hintText: 'Ex.: instalar chuveiro no banheiro social',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 14),
              const _AvisoSolicitacao(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('solicitar-enviar'),
                  onPressed: enviando ? null : () => onSubmit(),
                  icon: enviando
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(enviando ? 'Enviando...' : 'Enviar solicitação'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoSolicitacao extends StatelessWidget {
  const _AvisoSolicitacao();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.verdeEscuro),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'O envio não confirma o agendamento. A solicitação começa '
                'aguardando resposta e só será agendada após aceite válido '
                'do profissional.',
                style: TextStyle(color: AppColors.texto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisponibilidadeResumo extends StatelessWidget {
  const _DisponibilidadeResumo({required this.itens});

  final List<Disponibilidade> itens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.verdeClaro,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disponibilidade informada',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              itens
                  .take(4)
                  .map(
                    (item) =>
                        '${_diaSemana(item.diaSemana)} ${item.horaInicio}-${item.horaFim}',
                  )
                  .join(', '),
              style: const TextStyle(color: AppColors.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnderecoObrigatorioAviso extends StatelessWidget {
  const _EnderecoObrigatorioAviso({required this.onCadastrar});

  final VoidCallback onCadastrar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.verdePastel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: AppColors.verdeEscuro),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cadastre um endereço antes de solicitar atendimento. O profissional só vê o endereço completo depois do aceite.',
                    style: TextStyle(color: AppColors.texto, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCadastrar,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Cadastrar endereço'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnderecoErroAviso extends StatelessWidget {
  const _EnderecoErroAviso({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ConsultaAviso(
      titulo: 'Não foi possível carregar seus endereços.',
      mensagem:
          'Confira a conexão e tente novamente antes de enviar a solicitação.',
      icon: Icons.wifi_off_outlined,
      onRetry: onRetry,
      retryKey: const ValueKey('enderecos-tentar-novamente'),
    );
  }
}

class _ConsultaAviso extends StatelessWidget {
  const _ConsultaAviso({
    required this.titulo,
    this.mensagem,
    this.icon = Icons.info_outline_rounded,
    this.carregando = false,
    this.onRetry,
    this.retryKey,
  });

  final String titulo;
  final String? mensagem;
  final IconData icon;
  final bool carregando;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.verdePastel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borda),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: carregando
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(icon, color: AppColors.verdeEscuro),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (mensagem != null) ...[
                const SizedBox(height: 8),
                Text(
                  mensagem!,
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: retryKey,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SugestoesAgenda extends StatelessWidget {
  const _SugestoesAgenda({
    required this.itens,
    required this.dataController,
    required this.horarioController,
  });

  final List<Disponibilidade> itens;
  final TextEditingController dataController;
  final TextEditingController horarioController;

  @override
  Widget build(BuildContext context) {
    final sugestoes = _proximasSugestoes(itens);
    if (sugestoes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Horários sugeridos',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toque em uma opção para preencher data e horário conforme a disponibilidade cadastrada.',
          style: TextStyle(color: AppColors.textoSuave),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sugestao in sugestoes)
              ActionChip(
                label: Text(
                  '${_formatarDataCurta(sugestao.data)} ${sugestao.horario}',
                ),
                onPressed: () {
                  dataController.text = _formatarDataCampo(sugestao.data);
                  horarioController.text = sugestao.horario;
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _SugestaoAgenda {
  const _SugestaoAgenda({required this.data, required this.horario});

  final DateTime data;
  final String horario;
}

class _SolicitacaoEnviada extends StatelessWidget {
  const _SolicitacaoEnviada({
    required this.profissional,
    required this.servico,
    required this.solicitacaoId,
    required this.onVerServicos,
  });

  final Profissional profissional;
  final String servico;
  final int? solicitacaoId;
  final VoidCallback onVerServicos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.verdeClaro,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.verde,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solicitação enviada',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seu pedido de $servico para ${profissional.nome} foi preparado '
              'e aguarda resposta do profissional.',
              style: const TextStyle(color: AppColors.texto),
            ),
            const SizedBox(height: 10),
            const Text(
              'Status: Aguardando resposta',
              style: TextStyle(
                color: AppColors.verdeEscuro,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ainda não há agendamento confirmado. Aguarde o aceite do '
              'profissional para que o atendimento fique aceito e agendado.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: solicitacaoId == null
                    ? onVerServicos
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.detalhesServico,
                        arguments: solicitacaoId,
                      ),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Ver detalhes'),
              ),
            ),
            TextButton(
              onPressed: onVerServicos,
              child: const Text('Ir para meus serviços'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitacaoIndisponivel extends StatelessWidget {
  const _SolicitacaoIndisponivel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Selecione um profissional antes de solicitar o serviço.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _precoTexto(double? preco) {
  if (preco == null) return 'Preço inicial sob consulta';
  return 'A partir de R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
}

DateTime? _parseData(String valor) {
  final partes = valor.trim().split('/');
  if (partes.length != 3) return null;
  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final ano = int.tryParse(partes[2]);
  if (dia == null || mes == null || ano == null) return null;
  final data = DateTime(ano, mes, dia);
  if (data.day != dia || data.month != mes || data.year != ano) return null;
  return data;
}

String _dataApi(DateTime? data) {
  final value = data ?? DateTime.now();
  final mes = value.month.toString().padLeft(2, '0');
  final dia = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mes-$dia';
}

String? validarDataSolicitacao(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;
  final data = _parseData(valor!);
  if (data == null) return 'Informe uma data válida no formato DD/MM/AAAA.';
  if (!_dataNaoPassou(data)) return 'Escolha uma data de hoje em diante.';
  return null;
}

String? validarHorarioSolicitacao(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;
  return _normalizarHorario(valor!) == null
      ? 'Informe um horário válido no formato HH:MM.'
      : null;
}

String? _normalizarHorario(String valor) {
  final texto = valor.trim();
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(texto);
  if (match == null) return null;
  final hora = match.group(1)!.padLeft(2, '0');
  final minuto = match.group(2)!;
  return '$hora:$minuto';
}

bool _dataNaoPassou(DateTime data) {
  final hoje = DateTime.now();
  final hojeCivil = DateTime(hoje.year, hoje.month, hoje.day);
  final dataCivil = DateTime(data.year, data.month, data.day);
  return !dataCivil.isBefore(hojeCivil);
}

bool _horarioDentroDaDisponibilidade(
  DateTime data,
  String horario,
  List<Disponibilidade> disponibilidades,
) {
  final diaApi = _diaSemanaApi(data);
  return disponibilidades.any(
    (item) =>
        item.ativo &&
        item.diaSemana == diaApi &&
        item.horaInicio.compareTo(horario) <= 0 &&
        horario.compareTo(item.horaFim) < 0,
  );
}

int _diaSemanaApi(DateTime data) =>
    data.weekday == DateTime.sunday ? 0 : data.weekday;

List<_SugestaoAgenda> _proximasSugestoes(List<Disponibilidade> itens) {
  final hoje = DateTime.now();
  final sugestoes = <_SugestaoAgenda>[];
  for (var offset = 0; offset < 21 && sugestoes.length < 8; offset++) {
    final data = DateTime(hoje.year, hoje.month, hoje.day + offset);
    final diaApi = _diaSemanaApi(data);
    final intervalos = itens.where(
      (item) => item.ativo && item.diaSemana == diaApi,
    );
    for (final intervalo in intervalos) {
      final inicio = _minutos(intervalo.horaInicio);
      final fim = _minutos(intervalo.horaFim);
      if (inicio == null || fim == null || inicio >= fim) continue;
      for (
        var minuto = inicio;
        minuto < fim && sugestoes.length < 8;
        minuto += 60
      ) {
        final horario = _horarioTexto(minuto);
        if (offset == 0 && !_horarioFuturoHoje(horario)) continue;
        sugestoes.add(_SugestaoAgenda(data: data, horario: horario));
      }
    }
  }
  return sugestoes;
}

bool _horarioFuturoHoje(String horario) {
  final agora = DateTime.now();
  final minutos = _minutos(horario);
  if (minutos == null) return false;
  return minutos > (agora.hour * 60 + agora.minute);
}

int? _minutos(String horario) {
  final normalizado = _normalizarHorario(horario);
  if (normalizado == null) return null;
  final partes = normalizado.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes[1]);
}

String _horarioTexto(int minutos) {
  final hora = (minutos ~/ 60).toString().padLeft(2, '0');
  final minuto = (minutos % 60).toString().padLeft(2, '0');
  return '$hora:$minuto';
}

String _formatarDataCampo(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

String _formatarDataCurta(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes';
}

Future<void> _selecionarData(
  BuildContext context,
  TextEditingController controller,
) async {
  final hoje = DateTime.now();
  final inicial = _parseData(controller.text) ?? hoje;
  final data = await showDatePicker(
    context: context,
    initialDate: _dataNaoPassou(inicial) ? inicial : hoje,
    firstDate: DateTime(hoje.year, hoje.month, hoje.day),
    lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
  );
  if (data != null) controller.text = _formatarDataCampo(data);
}

Future<void> _selecionarHorario(
  BuildContext context,
  TextEditingController controller,
) async {
  final minutos = _minutos(controller.text);
  final horario = await showTimePicker(
    context: context,
    initialTime: minutos == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60),
  );
  if (horario != null) {
    controller.text =
        '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
  }
}

String _diaSemana(int dia) {
  return switch (dia) {
    0 => 'Dom',
    1 => 'Seg',
    2 => 'Ter',
    3 => 'Qua',
    4 => 'Qui',
    5 => 'Sex',
    6 => 'Sáb',
    _ => 'Dia',
  };
}
