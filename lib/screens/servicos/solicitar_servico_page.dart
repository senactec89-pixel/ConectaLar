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
  Future<List<ClienteEndereco>>? _enderecosFuture;
  Future<List<Disponibilidade>>? _disponibilidadeFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Profissional) {
      _profissional = arguments;
      _ofertaSelecionadaId = arguments.ofertasParaSolicitacao.first.id;
      _bairroController.text = arguments.bairro;
      _enderecosFuture = _carregarEnderecos();
      _disponibilidadeFuture = _carregarDisponibilidade(arguments.id);
    }
    _argumentosLidos = true;
  }

  Future<List<ClienteEndereco>> _carregarEnderecos() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    try {
      final response = await AppServices.instance.clientes.listarEnderecos();
      final enderecos = listFromApi(
        response['enderecos'],
        clienteEnderecoFromApi,
      );
      ClienteEndereco? principal;
      for (final endereco in enderecos) {
        if (endereco.principal) {
          principal = endereco;
          break;
        }
      }
      if (principal != null && mounted) {
        setState(() {
          _enderecoSelecionadoId = principal!.id;
          _bairroController.text = principal.bairro;
        });
      }
      return enderecos;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Disponibilidade>> _carregarDisponibilidade(
    int profissionalId,
  ) async {
    if (AppServices.instance.emDemonstracao) return const [];
    try {
      final response = await AppServices.instance.profissionais
          .disponibilidadePublica(profissionalId);
      return listFromApi(response['disponibilidades'], disponibilidadeFromApi);
    } catch (_) {
      return const [];
    }
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
    if (!_formKey.currentState!.validate()) return;

    final profissional = _profissional;
    if (profissional == null) return;

    if (AppServices.instance.emDemonstracao) {
      _criarSolicitacaoMock(profissional);
      return;
    }
    setState(() => _enviando = true);
    try {
      final data = _parseData(_dataController.text);
      final response = await AppServices.instance.servicos.solicitar({
        'profissionalId': profissional.id,
        'categoriaId': _ofertaSelecionada?.categoriaId,
        if ((_ofertaSelecionada?.id ?? 0) > 0)
          'servicoId': _ofertaSelecionada!.id,
        'enderecoId': _enderecoSelecionadoId,
        'descricao': _descricaoController.text,
        'bairroAtendimento': _bairroController.text,
        'dataServico': _dataApi(data),
        'horarioServico': _horarioController.text,
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
      _mostrarErro('Não foi possível enviar a solicitação.');
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

  @override
  Widget build(BuildContext context) {
    final profissional = _profissional;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      appBar: const AppBarCustom(title: 'Solicitar serviço'),
      body: profissional == null
          ? const _SolicitacaoIndisponivel()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _ResumoProfissional(
                  profissional: profissional,
                  precoInicial:
                      _ofertaSelecionada?.precoInicial ??
                      profissional.precoInicial,
                ),
                const SizedBox(height: 14),
                if (_solicitacaoEnviada)
                  _SolicitacaoEnviada(
                    profissional: profissional,
                    servico: _ofertaSelecionada?.nome ?? profissional.descricao,
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
                    onSubmit: _enviarSolicitacao,
                    enviando: _enviando,
                  ),
              ],
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
              backgroundImage: profissional.fotoAsset == null
                  ? null
                  : AssetImage(profissional.fotoAsset!),
              child: profissional.fotoAsset == null
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
                      child: Text(oferta.nome),
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
                    if (enderecos.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
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
                                child: Text(endereco.resumo),
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
                    final itens = snapshot.data ?? const <Disponibilidade>[];
                    if (itens.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DisponibilidadeResumo(itens: itens),
                    );
                  },
                ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('solicitar-data'),
                      controller: dataController,
                      decoration: const InputDecoration(
                        labelText: 'Data desejada',
                        hintText: 'DD/MM/AAAA',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      validator: validarCampoObrigatorio,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('solicitar-horario'),
                      controller: horarioController,
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        hintText: 'HH:MM',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      validator: validarCampoObrigatorio,
                    ),
                  ),
                ],
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
  return DateTime(ano, mes, dia);
}

String _dataApi(DateTime? data) {
  final value = data ?? DateTime.now();
  final mes = value.month.toString().padLeft(2, '0');
  final dia = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mes-$dia';
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
