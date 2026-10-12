import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/disponibilidade.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
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
          content: Text('Confira os horários. Eles não podem se sobrepor.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _adicionar() async {
    if (_salvando) return;
    final item = await showModalBottomSheet<Disponibilidade>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DisponibilidadeForm(),
    );
    if (item == null) return;
    setState(() => _itens.add(item));
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
                                    'Cadastre os horários em que você pode receber solicitações. Os pedidos devem respeitar os horários disponíveis.',
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
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _salvando ? 'Salvando...' : 'Salvar disponibilidade',
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
  const _DisponibilidadeForm();

  @override
  State<_DisponibilidadeForm> createState() => _DisponibilidadeFormState();
}

class _DisponibilidadeFormState extends State<_DisponibilidadeForm> {
  final _formKey = GlobalKey<FormState>();
  final _inicio = TextEditingController(text: '09:00');
  final _fim = TextEditingController(text: '18:00');
  int _dia = 1;

  @override
  void dispose() {
    _inicio.dispose();
    _fim.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Disponibilidade(
        id: 0,
        diaSemana: _dia,
        horaInicio: _inicio.text.trim(),
        horaFim: _fim.text.trim(),
      ),
    );
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
                  'Selecione o dia e o período de atendimento.',
                  style: TextStyle(color: AppColors.textoSuave, height: 1.4),
                ),
                const SizedBox(height: AppSpace.xl),
                DropdownButtonFormField<int>(
                  initialValue: _dia,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dia da semana'),
                  items: [
                    for (var dia = 0; dia <= 6; dia++)
                      DropdownMenuItem(value: dia, child: Text(_diaLabel(dia))),
                  ],
                  onChanged: (value) => setState(() => _dia = value ?? 1),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _inicio,
                        decoration: const InputDecoration(labelText: 'Início'),
                        validator: validarCampoObrigatorio,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: TextFormField(
                        controller: _fim,
                        decoration: const InputDecoration(labelText: 'Fim'),
                        validator: validarCampoObrigatorio,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
