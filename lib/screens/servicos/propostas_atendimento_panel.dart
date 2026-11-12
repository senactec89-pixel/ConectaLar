import 'package:flutter/material.dart';

import '../../models/solicitacao.dart';
import '../../services/api_service.dart';
import '../../services/service_registry.dart';

class PropostasAtendimentoPanel extends StatefulWidget {
  const PropostasAtendimentoPanel({
    super.key,
    required this.solicitacao,
    required this.opcoesSolicitadas,
    required this.cliente,
    required this.profissional,
    required this.negociacaoIniciada,
  });

  final Solicitacao solicitacao;
  final List<Map<String, dynamic>> opcoesSolicitadas;
  final bool cliente;
  final bool profissional;
  final bool negociacaoIniciada;

  @override
  State<PropostasAtendimentoPanel> createState() =>
      _PropostasAtendimentoPanelState();
}

class _PropostasAtendimentoPanelState extends State<PropostasAtendimentoPanel> {
  late Future<Map<String, dynamic>> _future = _carregar();
  int _pagina = 1;
  bool _ocupado = false;
  bool _confirmada = false;

  Future<Map<String, dynamic>> _carregar() async {
    final resposta = await AppServices.instance.servicos.propostas(
      widget.solicitacao.id,
      pagina: _pagina,
    );
    if (resposta['propostas'] is! List) {
      throw const FormatException('Resposta invalida.');
    }
    return resposta;
  }

  void _atualizar() => setState(() {
    _future = _carregar();
  });

  Future<void> _recusar(int id) async {
    if (_ocupado) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Recusar proposta?'),
        content: const Text(
          'Vocês poderão conversar novamente e combinar outra proposta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await AppServices.instance.servicos.recusarProposta(
        widget.solicitacao.id,
        id,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proposta recusada.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível recusar a proposta.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _pagina = 1;
          _future = _carregar();
        });
      }
    }
  }

  Future<void> _confirmar(int id) async {
    if (_ocupado) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Confirmar atendimento?'),
        content: const Text(
          'Ao confirmar, esta proposta e o horário serão registrados e o horário '
          'será reservado na agenda do profissional. O aplicativo não processa, '
          'confirma nem reembolsa pagamentos nesta etapa. Confirme somente se '
          'o serviço, valor, data e horário acima estão corretos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar atendimento'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await AppServices.instance.servicos.confirmarProposta(
        widget.solicitacao.id,
        id,
      );
      if (mounted) {
        setState(() => _confirmada = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atendimento confirmado.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível confirmar o atendimento.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _pagina = 1;
          _future = _carregar();
        });
      }
    }
  }

  Future<void> _novaProposta() async {
    final categoria = widget.solicitacao.categoriaId;
    final servico = widget.solicitacao.servicoCatalogoId;
    if (categoria <= 0 || servico == null || servico <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço do catálogo indisponível.')),
      );
      return;
    }
    final salva = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioProposta(
        solicitacao: widget.solicitacao,
        categoriaId: categoria,
        servicoId: servico,
        selecionadas: widget.opcoesSolicitadas
            .map((item) => item['id'] as int)
            .toSet(),
      ),
    );
    if (salva == true && mounted) {
      setState(() {
        _pagina = 1;
        _future = _carregar();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativa =
        widget.solicitacao.status == StatusSolicitacao.aguardandoResposta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Itens solicitados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final opcao in widget.opcoesSolicitadas)
              Text('• ${opcao['nome']}'),
            const SizedBox(height: 16),
            Text(
              'Propostas de atendimento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!widget.negociacaoIniciada)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Aguardando a resposta do profissional.'),
              ),
            if (widget.negociacaoIniciada && widget.profissional)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Negociação iniciada. Converse com o cliente ou envie a proposta-resumo.',
                ),
              ),
            if (widget.negociacaoIniciada && widget.cliente)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Negociação iniciada. Aguarde a proposta-resumo do profissional ou converse pelo chat.',
                ),
              ),
            if (widget.negociacaoIniciada)
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return TextButton.icon(
                      onPressed: _atualizar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar carregar novamente'),
                    );
                  }
                  final propostas = (snapshot.data!['propostas'] as List)
                      .whereType<Map<String, dynamic>>()
                      .toList();
                  final paginacao = snapshot.data!['paginacao'];
                  final temMais =
                      paginacao is Map && paginacao['temMais'] == true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (propostas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Nenhuma proposta enviada.'),
                        ),
                      for (final proposta in propostas) ...[
                        const Divider(height: 24),
                        Text(
                          'Proposta ${proposta['versao']} • ${_status(proposta['status'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        for (final item
                            in (proposta['opcoes'] is List
                                    ? proposta['opcoes'] as List
                                    : const [])
                                .whereType<Map>())
                          Text('• ${item['nome']}'),
                        Text(
                          'Valor: R\$ ${_valorFormatado(proposta['valor'])}',
                        ),
                        Text(
                          'Data: ${_dataFormatada(proposta['dataServico'])} às ${proposta['horarioServico']}',
                        ),
                        Text(
                          'Duração: ${_duracaoFormatada(proposta['duracaoMinutos'])}',
                        ),
                        if (_confirmada && proposta['status'] == 'aceita')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Atendimento confirmado; horário reservado.',
                            ),
                          ),
                        if (widget.cliente &&
                            !_confirmada &&
                            ativa &&
                            _pagina == 1 &&
                            proposta == propostas.first &&
                            proposta['status'] == 'pendente') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: _ocupado
                                    ? null
                                    : () => _confirmar(proposta['id'] as int),
                                child: const Text('Confirmar atendimento'),
                              ),
                              OutlinedButton(
                                onPressed: _ocupado
                                    ? null
                                    : () => _recusar(proposta['id'] as int),
                                child: const Text('Recusar proposta'),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (_pagina > 1 || temMais)
                        Row(
                          children: [
                            TextButton(
                              onPressed: _pagina > 1
                                  ? () {
                                      _pagina--;
                                      _atualizar();
                                    }
                                  : null,
                              child: const Text('Anterior'),
                            ),
                            Expanded(
                              child: Text(
                                'Página $_pagina',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed: temMais
                                  ? () {
                                      _pagina++;
                                      _atualizar();
                                    }
                                  : null,
                              child: const Text('Próxima'),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            if (widget.profissional && widget.negociacaoIniciada && ativa) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _novaProposta,
                icon: const Icon(Icons.add),
                label: const Text('Criar proposta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _valorFormatado(Object? valor) {
  final numero = double.tryParse('$valor');
  return numero == null
      ? 'Indisponível'
      : numero.toStringAsFixed(2).replaceAll('.', ',');
}

String _dataFormatada(Object? valor) {
  final texto = '$valor';
  final partes = texto.split('-');
  return partes.length == 3 ? '${partes[2]}/${partes[1]}/${partes[0]}' : texto;
}

String _duracaoFormatada(Object? valor) {
  final minutos = int.tryParse('$valor');
  if (minutos == null || minutos < 1) return 'Indisponível';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  if (horas == 0) return '$minutos min';
  if (resto == 0) return horas == 1 ? '1 hora' : '$horas horas';
  return '${horas}h${resto.toString().padLeft(2, '0')}';
}

String _status(Object? status) => switch (status) {
  'pendente' => 'Aguardando resposta',
  'recusada' => 'Recusada',
  'substituida' => 'Substituída',
  'aceita' => 'Aceita',
  _ => 'Indisponível',
};

class _FormularioProposta extends StatefulWidget {
  const _FormularioProposta({
    required this.solicitacao,
    required this.categoriaId,
    required this.servicoId,
    required this.selecionadas,
  });
  final Solicitacao solicitacao;
  final int categoriaId;
  final int servicoId;
  final Set<int> selecionadas;
  @override
  State<_FormularioProposta> createState() => _FormularioPropostaState();
}

class _FormularioPropostaState extends State<_FormularioProposta> {
  final _form = GlobalKey<FormState>();
  final _valor = TextEditingController();
  static const _duracoesPreset = <int, String>{
    30: '30 min',
    60: '1 hora',
    90: '1h30',
    120: '2 horas',
    180: '3 horas',
    240: '4 horas',
    360: '6 horas',
    480: '8 horas',
    720: '12 horas',
    1440: '24 horas',
  };
  late int _duracaoSelecionada =
      _duracoesPreset.containsKey(widget.solicitacao.duracaoMinutos)
      ? widget.solicitacao.duracaoMinutos
      : -1;
  late final _horasPersonalizadas = TextEditingController(
    text: '${widget.solicitacao.duracaoMinutos ~/ 60}',
  );
  late final _minutosPersonalizados = TextEditingController(
    text: '${widget.solicitacao.duracaoMinutos % 60}',
  );
  late DateTime _data = widget.solicitacao.dataServico;
  late TimeOfDay _hora = _horaInicial();
  late final Set<int> _selecionadas = {...widget.selecionadas};
  late Future<List<Map<String, dynamic>>> _opcoes = _carregarOpcoes();
  bool _salvando = false;

  int get _duracaoEmMinutos => _duracaoSelecionada == -1
      ? (int.tryParse(_horasPersonalizadas.text) ?? 0) * 60 +
            (int.tryParse(_minutosPersonalizados.text) ?? 0)
      : _duracaoSelecionada;

  TimeOfDay _horaInicial() {
    final partes = widget.solicitacao.horarioServico.split(':');
    final hora = int.tryParse(partes.first) ?? 9;
    final minuto = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
    return TimeOfDay(hour: hora.clamp(0, 23), minute: minuto.clamp(0, 59));
  }

  Future<List<Map<String, dynamic>>> _carregarOpcoes() => AppServices
      .instance
      .categorias
      .opcoes(widget.categoriaId, widget.servicoId);
  @override
  void dispose() {
    _valor.dispose();
    _horasPersonalizadas.dispose();
    _minutosPersonalizados.dispose();
    super.dispose();
  }

  Future<void> _enviar(List<Map<String, dynamic>> opcoes) async {
    if (_salvando || !_form.currentState!.validate()) return;
    final idsAtivos = opcoes.map((item) => item['id'] as int).toSet();
    final ids = _selecionadas.intersection(idsAtivos).toList()..sort();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma opção.')),
      );
      return;
    }
    if (ids.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione no máximo 30 opções.')),
      );
      return;
    }
    final instante = DateTime(
      _data.year,
      _data.month,
      _data.day,
      _hora.hour,
      _hora.minute,
    );
    if (!instante.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha uma data e horário futuros.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      String dois(int numero) => numero.toString().padLeft(2, '0');
      await AppServices.instance.servicos
          .enviarProposta(widget.solicitacao.id, {
            'opcoesIds': ids,
            'valor': _valor.text.trim().replaceAll(',', '.'),
            'dataServico':
                '${_data.year}-${dois(_data.month)}-${dois(_data.day)}',
            'horarioServico': '${dois(_hora.hour)}:${dois(_hora.minute)}',
            'duracaoMinutos': _duracaoEmMinutos,
          });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a proposta.')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Nova proposta'),
    content: FutureBuilder<List<Map<String, dynamic>>>(
      future: _opcoes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(() {
              _opcoes = _carregarOpcoes();
            }),
            child: const Text('Tentar novamente'),
          );
        }
        final opcoes = snapshot.data ?? [];
        return Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (opcoes.isEmpty)
                  const Text('Nenhuma opção ativa disponível.'),
                for (final item in opcoes)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['nome']}'),
                    value: _selecionadas.contains(item['id']),
                    onChanged: _salvando
                        ? null
                        : (valor) => setState(() {
                            if (valor == true) {
                              _selecionadas.add(item['id'] as int);
                            } else {
                              _selecionadas.remove(item['id']);
                            }
                          }),
                  ),
                TextFormField(
                  controller: _valor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor em reais',
                  ),
                  validator: (valor) {
                    final texto = (valor ?? '').trim().replaceAll(',', '.');
                    return RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(texto) &&
                            (double.tryParse(texto) ?? 0) > 0
                        ? null
                        : 'Informe um valor válido.';
                  },
                ),
                DropdownButtonFormField<int>(
                  key: const Key('proposal-duration-select'),
                  initialValue: _duracaoSelecionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Duração estimada',
                  ),
                  items: [
                    for (final item in _duracoesPreset.entries)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Personalizada'),
                    ),
                  ],
                  onChanged: _salvando
                      ? null
                      : (valor) {
                          if (valor != null) {
                            setState(() => _duracaoSelecionada = valor);
                          }
                        },
                ),
                if (_duracaoSelecionada == -1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('proposal-duration-hours'),
                          controller: _horasPersonalizadas,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Horas'),
                          validator: (valor) {
                            final horas = int.tryParse((valor ?? '').trim());
                            if (horas == null || horas < 0 || horas > 24) {
                              return 'Use 0 a 24.';
                            }
                            return horas == 24 &&
                                    (int.tryParse(
                                              _minutosPersonalizados.text,
                                            ) ??
                                            0) !=
                                        0
                                ? '24 h exige 0 min.'
                                : null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('proposal-duration-minutes'),
                          controller: _minutosPersonalizados,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minutos',
                          ),
                          validator: (valor) {
                            final minutos = int.tryParse((valor ?? '').trim());
                            if (minutos == null ||
                                minutos < 0 ||
                                minutos > 59) {
                              return 'Use 0 a 59.';
                            }
                            return _duracaoEmMinutos >= 1 &&
                                    _duracaoEmMinutos <= 1440
                                ? null
                                : 'Informe uma duração entre 1 min e 24 h.';
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Total: ${_duracaoFormatada(_duracaoEmMinutos)}',
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: _salvando
                      ? null
                      : () async {
                          final hoje = DateTime.now();
                          final limite = DateTime(
                            hoje.year + 2,
                            hoje.month,
                            hoje.day,
                          );
                          final inicial = _data.isAfter(limite)
                              ? limite
                              : _data.isBefore(
                                  DateTime(hoje.year, hoje.month, hoje.day),
                                )
                              ? hoje
                              : _data;
                          final data = await showDatePicker(
                            context: context,
                            initialDate: inicial,
                            firstDate: DateTime(
                              hoje.year,
                              hoje.month,
                              hoje.day,
                            ),
                            lastDate: limite,
                          );
                          if (data != null && mounted) {
                            setState(() => _data = data);
                          }
                        },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${_data.day}/${_data.month}/${_data.year}'),
                ),
                TextButton.icon(
                  onPressed: _salvando
                      ? null
                      : () async {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime: _hora,
                          );
                          if (hora != null && mounted) {
                            setState(() => _hora = hora);
                          }
                        },
                  icon: const Icon(Icons.schedule),
                  label: Text(_hora.format(context)),
                ),
                FilledButton(
                  onPressed: _salvando || opcoes.isEmpty
                      ? null
                      : () => _enviar(opcoes),
                  child: Text(_salvando ? 'Enviando...' : 'Enviar proposta'),
                ),
              ],
            ),
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: _salvando ? null : () => Navigator.pop(context, false),
        child: const Text('Voltar'),
      ),
    ],
  );
}
