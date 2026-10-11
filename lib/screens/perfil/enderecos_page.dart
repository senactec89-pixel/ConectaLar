import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/cliente_endereco.dart';
import '../../services/api_mappers.dart';
import '../../services/service_registry.dart';
import '../../utils/validators.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

class EnderecosPage extends StatefulWidget {
  const EnderecosPage({super.key});

  @override
  State<EnderecosPage> createState() => _EnderecosPageState();
}

class _EnderecosPageState extends State<EnderecosPage> {
  late Future<List<ClienteEndereco>> _enderecosFuture;

  @override
  void initState() {
    super.initState();
    _enderecosFuture = _carregar();
  }

  Future<List<ClienteEndereco>> _carregar() async {
    if (!AppServices.instance.auth.autenticado) return const [];
    final response = await AppServices.instance.clientes.listarEnderecos();
    return listFromApi(response['enderecos'], clienteEnderecoFromApi);
  }

  void _recarregar() {
    setState(() {
      _enderecosFuture = _carregar();
      _enderecosFuture.ignore();
    });
  }

  Future<void> _abrirFormulario([ClienteEndereco? endereco]) async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EnderecoForm(endereco: endereco),
    );
    if (salvou == true) _recarregar();
  }

  Future<void> _remover(ClienteEndereco endereco) async {
    try {
      await AppServices.instance.clientes.removerEndereco(endereco.id);
      _recarregar();
    } catch (_) {
      _snack('Não foi possível remover este endereço.');
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
    return Scaffold(
      appBar: const AppBarCustom(title: 'Endereços'),
      backgroundColor: AppColors.fundo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Adicionar'),
      ),
      body: FutureBuilder<List<ClienteEndereco>>(
        future: _enderecosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AsyncLoadingView(label: 'Carregando endereços.');
          }
          if (snapshot.hasError) {
            return AsyncErrorView(
              message: 'Não foi possível carregar seus endereços agora.',
              onRetry: _recarregar,
              icon: Icons.location_on_outlined,
            );
          }
          final enderecos = snapshot.data ?? const <ClienteEndereco>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
            children: [
              const _AvisoEndereco(),
              const SizedBox(height: 16),
              if (enderecos.isEmpty)
                const EmptyStateView(
                  title: 'Nenhum endereço salvo',
                  message:
                      'Adicione um endereço para agilizar suas solicitações.',
                  icon: Icons.location_on_outlined,
                )
              else
                for (final endereco in enderecos) ...[
                  _EnderecoCard(
                    endereco: endereco,
                    onEditar: () => _abrirFormulario(endereco),
                    onRemover: () => _remover(endereco),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _AvisoEndereco extends StatelessWidget {
  const _AvisoEndereco();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.verdeEscuro),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'O endereço completo é privado. Antes do aceite, o profissional vê somente o bairro do atendimento.',
                style: TextStyle(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnderecoCard extends StatelessWidget {
  const _EnderecoCard({
    required this.endereco,
    required this.onEditar,
    required this.onRemover,
  });

  final ClienteEndereco endereco;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.verdeClaro,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      endereco.principal
                          ? Icons.home_rounded
                          : Icons.location_on_outlined,
                      color: AppColors.verdeEscuro,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    endereco.apelido,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              endereco.completo,
              style: const TextStyle(color: AppColors.textoSuave, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borda),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.verdeEscuro,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: onRemover,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.erro,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnderecoForm extends StatefulWidget {
  const _EnderecoForm({this.endereco});

  final ClienteEndereco? endereco;

  @override
  State<_EnderecoForm> createState() => _EnderecoFormState();
}

class _EnderecoFormState extends State<_EnderecoForm> {
  final _formKey = GlobalKey<FormState>();
  late final _apelido = TextEditingController(text: widget.endereco?.apelido);
  late final _cep = TextEditingController(text: widget.endereco?.cep);
  late final _logradouro = TextEditingController(
    text: widget.endereco?.logradouro,
  );
  late final _numero = TextEditingController(text: widget.endereco?.numero);
  late final _complemento = TextEditingController(
    text: widget.endereco?.complemento,
  );
  late final _bairro = TextEditingController(text: widget.endereco?.bairro);
  late final _cidade = TextEditingController(text: widget.endereco?.cidade);
  late final _uf = TextEditingController(text: widget.endereco?.uf ?? 'MG');
  late bool _principal = widget.endereco?.principal ?? true;
  bool _salvando = false;

  @override
  void dispose() {
    _apelido.dispose();
    _cep.dispose();
    _logradouro.dispose();
    _numero.dispose();
    _complemento.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _uf.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate() || _salvando) return;
    setState(() => _salvando = true);
    final body = {
      'apelido': _apelido.text.trim(),
      'cep': _cep.text.trim().isEmpty ? null : _cep.text.trim(),
      'logradouro': _logradouro.text.trim(),
      'numero': _numero.text.trim(),
      'complemento': _complemento.text.trim().isEmpty
          ? null
          : _complemento.text.trim(),
      'bairro': _bairro.text.trim(),
      'cidade': _cidade.text.trim(),
      'uf': _uf.text.trim().toUpperCase(),
      'principal': _principal,
    };

    try {
      final id = widget.endereco?.id;
      if (id == null) {
        await AppServices.instance.clientes.criarEndereco(body);
      } else {
        await AppServices.instance.clientes.atualizarEndereco(id, body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o endereço.')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                widget.endereco == null ? 'Novo endereço' : 'Editar endereço',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _apelido,
                decoration: const InputDecoration(labelText: 'Apelido'),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cep,
                decoration: const InputDecoration(labelText: 'CEP'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _logradouro,
                decoration: const InputDecoration(labelText: 'Logradouro'),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numero,
                      decoration: const InputDecoration(labelText: 'Número'),
                      validator: validarCampoObrigatorio,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _uf,
                      decoration: const InputDecoration(labelText: 'UF'),
                      validator: validarCampoObrigatorio,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _complemento,
                decoration: const InputDecoration(labelText: 'Complemento'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bairro,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: validarCampoObrigatorio,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cidade,
                decoration: const InputDecoration(labelText: 'Cidade'),
                validator: validarCampoObrigatorio,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _principal,
                onChanged: (value) => setState(() => _principal = value),
                title: const Text('Endereço principal'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.save_outlined),
                label: Text(_salvando ? 'Salvando...' : 'Salvar endereço'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
