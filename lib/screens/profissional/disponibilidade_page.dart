import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/disponibilidade.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/action_label.dart';
import '../../widgets/async_state_view.dart';

class DisponibilidadePage extends StatefulWidget {
  const DisponibilidadePage({super.key});

  @override
  State<DisponibilidadePage> createState() => _DisponibilidadePageState();
}

class _DisponibilidadePageState extends State<DisponibilidadePage> {
  late Future<List<Disponibilidade>> _future;
  final List<Disponibilidade> _itens = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<Disponibilidade>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    final response = await AppServices.instance.profissionais
        .minhaDisponibilidade();
    final itens = listFromApi(
      response['disponibilidades'],
      disponibilidadeFromApi,
    );
    _itens
      ..clear()
      ..addAll(itens);
    return itens;
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await AppServices.instance.profissionais.salvarMinhaDisponibilidade(
        _itens.map((item) => item.toApi()).toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disponibilidade salva.')));
      setState(() {
        _future = _carregar();
        _future.ignore();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar seus horários. Seu preenchimento foi mantido. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _adicionar() async {
    if (_salvando) return;
    final itens = await showModalBottomSheet<List<Disponibilidade>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DisponibilidadeForm(existentes: List.of(_itens)),
    );
    if (itens == null || !mounted) return;
    setState(() {
      _itens.addAll(itens);
      _itens.sort((a, b) {
        final dia = ((a.diaSemana + 6) % 7).compareTo((b.diaSemana + 6) % 7);
        return dia != 0 ? dia : a.horaInicio.compareTo(b.horaInicio);
      });
    });
  }

  void _remover(int index) {
    if (_salvando) return;
    setState(() => _itens.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(title: 'Disponibilidade'),
      backgroundColor: AppColors.fundo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _salvando ? null : _adicionar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Horário'),
      ),
      body: Column(
        children: [
          if (_salvando) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<Disponibilidade>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AsyncLoadingView(
                    label: 'Carregando disponibilidade.',
                  );
                }
                if (snapshot.hasError) {
                  return AsyncErrorView(
                    message: 'Não foi possível carregar seus horários agora.',
                    onRetry: () => setState(() {
                      _future = _carregar();
                      _future.ignore();
                    }),
                    icon: Icons.calendar_month_outlined,
                  );
                }
                return ListView(
                  padding: AppInsets.page.copyWith(bottom: 96),
                  children: [
                    const Card(
                      color: AppColors.verdeClaro,
                      child: Padding(
                        padding: AppInsets.card,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              color: AppColors.verdeEscuro,
                            ),
                            SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Organize seus horários',
                                    style: TextStyle(
                                      color: AppColors.verdeEscuro,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: AppSpace.sm),
                                  Text(
                                    'Defina os períodos em que você atende: dias úteis, fim de semana ou dias personalizados. Eles se repetem toda semana; os pedidos só ficam agendados após o aceite.',
                                    style: TextStyle(height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const Text(
                      'Horários disponíveis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (_itens.isEmpty)
                      const EmptyStateView(
                        title: 'Agenda sem horários',
                        message:
                            'Adicione os períodos em que você pode receber solicitações.',
                        icon: Icons.calendar_month_outlined,
                      )
                    else
                      for (var index = 0; index < _itens.length; index++) ...[
                        _DisponibilidadeCard(
                          item: _itens[index],
                          onRemover: () => _remover(index),
                        ),
                        const SizedBox(height: AppSpace.md),
                      ],
                    const SizedBox(height: AppSpace.md),
                    FilledButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const ButtonProgressIndicator()
                          : const Icon(Icons.save_outlined),
                      label: ActionLabel(
                        busy: _salvando,
                        text: _salvando
                            ? 'Salvando...'
                            : 'Salvar disponibilidade',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DisponibilidadeCard extends StatelessWidget {
  const _DisponibilidadeCard({required this.item, required this.onRemover});

  final Disponibilidade item;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.verdeClaro,
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
              child: const SizedBox.square(
                dimension: 44,
                child: Icon(
                  Icons.schedule_rounded,
                  color: AppColors.verdeEscuro,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _diaLabel(item.diaSemana),
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${item.horaInicio} às ${item.horaFim}',
                    style: const TextStyle(color: AppColors.textoSuave),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remover horário de ${_diaLabel(item.diaSemana)}',
              onPressed: onRemover,
              icon: const Icon(Icons.delete_outline, color: AppColors.erro),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisponibilidadeForm extends StatefulWidget {
  const _DisponibilidadeForm({required this.existentes});

  final List<Disponibilidade> existentes;

  @override
  State<_DisponibilidadeForm> createState() => _DisponibilidadeFormState();
}

class _DisponibilidadeFormState extends State<_DisponibilidadeForm> {
  final _formKey = GlobalKey<FormState>();
  final _inicio = TextEditingController(text: '09:00');
  final _fim = TextEditingController(text: '18:00');
  final Set<int> _dias = {1};
  String _grupo = 'Personalizado';
  String? _erro;

  @override
  void dispose() {
    _inicio.dispose();
    _fim.dispose();
    super.dispose();
  }

  void _salvar() {
    setState(() => _erro = null);
    if (!_formKey.currentState!.validate()) return;
    if (_dias.isEmpty) {
      setState(() => _erro = 'Selecione pelo menos um dia da semana.');
      return;
    }
    final inicio = _normalizarHorario(_inicio.text);
    final fim = _normalizarHorario(_fim.text);
    if (inicio == null || fim == null) return;
    for (final item in widget.existentes.where(
      (item) => item.ativo && _dias.contains(item.diaSemana),
    )) {
      final inicioExistente = _minutos(
        item.horaInicio.length >= 5
            ? item.horaInicio.substring(0, 5)
            : item.horaInicio,
      );
      final fimExistente = _minutos(
        item.horaFim.length >= 5 ? item.horaFim.substring(0, 5) : item.horaFim,
      );
      if (inicioExistente != null &&
          fimExistente != null &&
          _minutos(inicio)! < fimExistente &&
          _minutos(fim)! > inicioExistente) {
        setState(
          () => _erro =
              '${_diaLabel(item.diaSemana)} já tem um período de ${item.horaInicio} às ${item.horaFim}. Escolha outro horário ou ajuste os dias selecionados.',
        );
        return;
      }
    }
    Navigator.pop(context, [
      for (final dia in _dias)
        Disponibilidade(
          id: 0,
          diaSemana: dia,
          horaInicio: inicio,
          horaFim: fim,
        ),
    ]);
  }

  Future<void> _selecionarHorario(TextEditingController controller) async {
    final minutos = _minutos(controller.text);
    final horario = await showTimePicker(
      context: context,
      initialTime: minutos == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60),
    );
    if (horario == null) return;
    controller.text =
        '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.pageGutter,
            AppSpace.xl,
            AppSpace.pageGutter,
            AppSpace.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Adicionar horário',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                const Text(
                  'Escolha os dias e aplique o mesmo período a todos eles. Você poderá revisar a lista antes de salvar.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.4),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'Dias de atendimento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final grupo in [
                      'Dias úteis',
                      'Fim de semana',
                      'Personalizado',
                    ])
                      ChoiceChip(
                        label: Text(grupo),
                        selected: _grupo == grupo,
                        onSelected: (_) => setState(() {
                          _grupo = grupo;
                          _erro = null;
                          if (grupo != 'Personalizado') {
                            _dias
                              ..clear()
                              ..addAll(
                                grupo == 'Dias úteis'
                                    ? [1, 2, 3, 4, 5]
                                    : [6, 0],
                              );
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                if (_grupo == 'Personalizado')
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    children: [
                      for (final dia in [1, 2, 3, 4, 5, 6, 0])
                        FilterChip(
                          label: Text(_diaLabel(dia)),
                          selected: _dias.contains(dia),
                          onSelected: (selecionado) => setState(() {
                            _erro = null;
                            selecionado ? _dias.add(dia) : _dias.remove(dia);
                          }),
                        ),
                    ],
                  )
                else
                  Text(
                    _grupo == 'Dias úteis'
                        ? 'Segunda a sexta-feira'
                        : 'Sábado e domingo',
                  ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _inicio,
                        decoration: const InputDecoration(
                          labelText: 'Início',
                          hintText: 'HH:MM',
                          suffixIcon: Icon(Icons.schedule_rounded),
                        ),
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.next,
                        onTap: () => _selecionarHorario(_inicio),
                        validator: validarHorarioDisponibilidade,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: TextFormField(
                        controller: _fim,
                        decoration: const InputDecoration(
                          labelText: 'Fim',
                          hintText: 'HH:MM',
                          suffixIcon: Icon(Icons.schedule_rounded),
                        ),
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.done,
                        onTap: () => _selecionarHorario(_fim),
                        validator: (value) {
                          final erro = validarHorarioDisponibilidade(value);
                          if (erro != null) return erro;
                          final inicio = _normalizarHorario(_inicio.text);
                          final fim = _normalizarHorario(value ?? '');
                          if (inicio != null &&
                              fim != null &&
                              inicio.compareTo(fim) >= 0) {
                            return 'O fim deve ser depois do início.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_erro != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: AppColors.erro),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                FilledButton.icon(
                  onPressed: _salvar,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Adicionar horário'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _diaLabel(int dia) {
  return switch (dia) {
    0 => 'Domingo',
    1 => 'Segunda-feira',
    2 => 'Terça-feira',
    3 => 'Quarta-feira',
    4 => 'Quinta-feira',
    5 => 'Sexta-feira',
    6 => 'Sábado',
    _ => 'Dia inválido',
  };
}

String? validarHorarioDisponibilidade(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;
  return _normalizarHorario(valor!) == null
      ? 'Informe no formato HH:MM, como 09:00.'
      : null;
}

String? _normalizarHorario(String valor) {
  final texto = valor.trim();
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(texto);
  if (match == null) return null;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
}

int? _minutos(String horario) {
  final normalizado = _normalizarHorario(horario);
  if (normalizado == null) return null;
  final partes = normalizado.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes[1]);
}
