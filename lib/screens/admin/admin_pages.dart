import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/service_registry.dart';
import '../../utils/categoria_icons.dart';
import 'categoria_form_page.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/async_state_view.dart';

enum AdminModulo {
  painel,
  usuarios,
  documentos,
  denuncias,
  avaliacoes,
  categorias,
  auditoria,
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, this.modulo = AdminModulo.painel});
  final AdminModulo modulo;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late AdminModulo _modulo = widget.modulo;
  late Future<List<Map<String, dynamic>>> _future = _carregar(_modulo);
  String _tipo = '';
  String _termo = '';
  String _buscaLocal = '';
  final _buscaLocalController = TextEditingController();
  String _statusCategoria = '';
  String _statusDocumento = 'pendente';
  bool _mutando = false;

  @override
  void dispose() {
    _buscaLocalController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _carregar(AdminModulo modulo) async {
    final service = AppServices.instance.admin;
    final Map<String, dynamic> result;
    final String key;
    switch (modulo) {
      case AdminModulo.usuarios:
        result = await service.usuarios(
          tipo: _tipo.isEmpty ? null : _tipo,
          termo: _termo.isEmpty ? null : _termo,
        );
        key = 'usuarios';
      case AdminModulo.documentos:
        result = await service.documentos(
          status: _statusDocumento.isEmpty ? null : _statusDocumento,
        );
        key = 'documentos';
      case AdminModulo.denuncias:
        result = await service.denuncias();
        key = 'denuncias';
      case AdminModulo.avaliacoes:
        result = await service.avaliacoes();
        key = 'avaliacoes';
      case AdminModulo.categorias:
        result = await service.categorias();
        key = 'categorias';
      case AdminModulo.auditoria:
        result = await service.auditoria();
        key = 'eventos';
      case AdminModulo.painel:
        return const [];
    }
    final values = result[key];
    return values is List
        ? values.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  void _abrir(AdminModulo modulo) => setState(() {
    _modulo = modulo;
    _buscaLocal = '';
    _buscaLocalController.clear();
    _future = _carregar(modulo);
  });

  @override
  Widget build(BuildContext context) {
    final tipoUsuario = AppServices.instance.auth.usuarioAtual?['tipo']
        ?.toString();
    if (tipoUsuario != 'administrador') {
      return Scaffold(
        appBar: const AppBarCustom(title: 'Área administrativa'),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.verdeClaro,
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.verdeEscuro,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Acesso administrativo restrito',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entre com uma conta administrativa autorizada para acessar estas ferramentas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Voltar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final titulo = switch (_modulo) {
      AdminModulo.painel => 'Central administrativa',
      AdminModulo.usuarios => 'Usuários',
      AdminModulo.documentos => 'Verificação documental',
      AdminModulo.denuncias => 'Denúncias',
      AdminModulo.avaliacoes => 'Avaliações',
      AdminModulo.categorias => 'Categorias',
      AdminModulo.auditoria => 'Registro de auditoria',
    };
    return Scaffold(
      appBar: AppBarCustom(
        title: titulo,
        actions: [
          if (_modulo == AdminModulo.usuarios)
            IconButton(
              tooltip: 'Criar administrador',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: _mutando ? null : _criarAdministrador,
            ),
          IconButton(
            tooltip: 'Conta e segurança',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.perfil),
          ),
          if (_modulo != AdminModulo.painel)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _abrir(AdminModulo.painel),
            ),
        ],
      ),
      backgroundColor: AppColors.fundo,
      body: Column(
        children: [
          if (_mutando) const LinearProgressIndicator(),
          if (_modulo == AdminModulo.documentos)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filtro in const {
                      'pendente': 'Pendentes',
                      'aprovado': 'Aprovados',
                      'rejeitado': 'Rejeitados',
                      '': 'Todos',
                    }.entries)
                      ChoiceChip(
                        key: ValueKey('admin-documentos-${filtro.key}'),
                        label: Text(filtro.value),
                        selected: _statusDocumento == filtro.key,
                        onSelected: _mutando
                            ? null
                            : (_) => setState(() {
                                _statusDocumento = filtro.key;
                                _future = _carregar(_modulo);
                                _future.ignore();
                              }),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: _modulo == AdminModulo.painel ? _painel() : _lista()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (_modulo) {
          AdminModulo.painel => 0,
          AdminModulo.usuarios => 1,
          AdminModulo.categorias => 3,
          AdminModulo.auditoria => 4,
          _ => 2,
        },
        onDestinationSelected: (i) => _abrir(switch (i) {
          1 => AdminModulo.usuarios,
          2 => AdminModulo.denuncias,
          3 => AdminModulo.categorias,
          4 => AdminModulo.auditoria,
          _ => AdminModulo.painel,
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Central',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Contas',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            label: 'Moderação',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            label: 'Auditoria',
          ),
        ],
      ),
    );
  }

  Widget _painel() => FutureBuilder<Map<String, dynamic>>(
    future: AppServices.instance.admin.painel(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AsyncLoadingView(
          label: 'Carregando painel administrativo.',
        );
      }
      if (snapshot.hasError) {
        return AsyncErrorView(
          message: 'Não foi possível carregar o resumo administrativo.',
          icon: Icons.dashboard_outlined,
          onRetry: () => setState(() {}),
        );
      }
      final data = snapshot.data ?? const <String, dynamic>{};
      final usuarios = _map(data['usuarios']);
      final profissionais = _map(data['profissionais']);
      final moderacao = _map(data['moderacao']);
      final catalogo = _map(data['catalogo']);
      final atendimentos = _map(data['atendimentos']);
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Visão geral', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          const Text('Acompanhe os indicadores e acesse as áreas de gestão.'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final escala = MediaQuery.textScalerOf(context).scale(1);
              final colunas = constraints.maxWidth < 300 || escala > 1.3
                  ? 1
                  : 2;
              final indicadores = [
                _Indicador(
                  label: 'Usuários ativos',
                  value: '${usuarios['ativos'] ?? '—'}',
                  icon: Icons.people_outline,
                ),
                _Indicador(
                  label: 'Profissionais ativos',
                  value: '${usuarios['profissionais'] ?? '—'}',
                  icon: Icons.work_outline,
                ),
                _Indicador(
                  label: 'Perfis profissionais',
                  value: '${profissionais['perfisAtivos'] ?? '—'}',
                  icon: Icons.badge_outlined,
                ),
                _Indicador(
                  label: 'Documentos em análise',
                  value: '${moderacao['documentosPendentes'] ?? '—'}',
                  icon: Icons.verified_user_outlined,
                ),
                _Indicador(
                  label: 'Denúncias abertas',
                  value: '${moderacao['denunciasAbertas'] ?? '—'}',
                  icon: Icons.report_outlined,
                ),
                _Indicador(
                  label: 'Avaliações em moderação',
                  value: '${moderacao['avaliacoesPendentes'] ?? '—'}',
                  icon: Icons.star_outline,
                ),
                _Indicador(
                  label: 'Categorias ativas',
                  value: '${catalogo['categoriasAtivas'] ?? '—'}',
                  icon: Icons.category_outlined,
                ),
                _Indicador(
                  label: 'Solicitações aguardando',
                  value: '${atendimentos['aguardandoResposta'] ?? '—'}',
                  icon: Icons.inbox_outlined,
                ),
                _Indicador(
                  label: 'Atendimentos agendados',
                  value: '${atendimentos['aceitaAgendada'] ?? '—'}',
                  icon: Icons.event_available_outlined,
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final indicador in indicadores)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (colunas - 1) * 10) / colunas,
                      child: indicador,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Acessos rápidos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          _AdminAtalho(
            icon: Icons.people_outline,
            title: 'Gerenciar usuários',
            subtitle: 'Consultar perfis e status',
            onTap: () => _abrir(AdminModulo.usuarios),
          ),
          _AdminAtalho(
            icon: Icons.verified_user_outlined,
            title: 'Analisar documentos',
            subtitle: 'Aprovar ou rejeitar com motivo',
            onTap: () => _abrir(AdminModulo.documentos),
          ),
          _AdminAtalho(
            icon: Icons.report_outlined,
            title: 'Revisar denúncias',
            subtitle: 'Registrar decisão sem punição automática',
            onTap: () => _abrir(AdminModulo.denuncias),
          ),
          _AdminAtalho(
            icon: Icons.star_outline,
            title: 'Moderar avaliações',
            subtitle: 'Preservar o histórico da análise',
            onTap: () => _abrir(AdminModulo.avaliacoes),
          ),
          _AdminAtalho(
            icon: Icons.category_outlined,
            title: 'Categorias',
            subtitle: 'Gerenciar itens do catálogo',
            onTap: () => _abrir(AdminModulo.categorias),
          ),
          _AdminAtalho(
            icon: Icons.history,
            title: 'Histórico de atendimentos',
            subtitle: 'Consultar solicitações e filtrar por situação',
            onTap: () => Navigator.pushNamed(context, AppRoutes.adminHistorico),
          ),
          _AdminAtalho(
            icon: Icons.manage_search_outlined,
            title: 'Registro de auditoria',
            subtitle: 'Consultar as ações administrativas recentes',
            onTap: () => _abrir(AdminModulo.auditoria),
          ),
        ],
      );
    },
  );

  Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  Future<void> _criarAdministrador() async {
    final criado = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.adminCriarAdministrador,
    );
    if (!mounted || criado != true) return;
    _avisar('Administrador criado.');
    setState(() {
      _future = _carregar(_modulo);
      _future.ignore();
    });
  }

  Widget _lista() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AsyncLoadingView(
          label: 'Carregando módulo administrativo.',
        );
      }
      if (snapshot.hasError) {
        return AsyncErrorView(
          message:
              'Não foi possível carregar esta lista. Confira sua sessão administrativa.',
          icon: Icons.admin_panel_settings_outlined,
          onRetry: () => setState(() {
            _future = _carregar(_modulo);
            _future.ignore();
          }),
        );
      }
      final items = snapshot.data ?? const <Map<String, dynamic>>[];
      final permiteBuscaLocal =
          _modulo == AdminModulo.avaliacoes ||
          _modulo == AdminModulo.categorias;
      final filtrados =
          _modulo != AdminModulo.categorias || _statusCategoria.isEmpty
          ? items
          : items
                .where(
                  (item) =>
                      (item['ativo'] == true) == (_statusCategoria == 'ativa'),
                )
                .toList(growable: false);
      final itensVisiveis = !permiteBuscaLocal || _buscaLocal.trim().isEmpty
          ? filtrados
          : filtrados
                .where(
                  (item) => _textoIndexavel(
                    item,
                  ).contains(_buscaLocal.trim().toLowerCase()),
                )
                .toList(growable: false);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _descricaoModulo(_modulo),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textoSuave),
              ),
            ),
          ),
          if (permiteBuscaLocal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _buscaLocalController,
                onChanged: (value) => setState(() => _buscaLocal = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: _modulo == AdminModulo.categorias
                      ? 'Buscar categoria'
                      : 'Buscar avaliação',
                  suffixIcon: _buscaLocal.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _buscaLocalController.clear();
                            setState(() => _buscaLocal = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          if (_modulo == AdminModulo.usuarios)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar nome ou e-mail',
                    ),
                    onChanged: (value) => _termo = value,
                    onSubmitted: (_) => setState(() {
                      _future = _carregar(_modulo);
                      _future.ignore();
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _tipo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de conta',
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'cliente',
                        child: Text('Cliente'),
                      ),
                      DropdownMenuItem(
                        value: 'profissional',
                        child: Text('Profissional'),
                      ),
                      DropdownMenuItem(
                        value: 'empresa',
                        child: Text('Empresa'),
                      ),
                      DropdownMenuItem(
                        value: 'administrador',
                        child: Text('Administrador'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _tipo = value ?? '';
                      _future = _carregar(_modulo);
                    }),
                  ),
                ],
              ),
            ),
          if (_modulo == AdminModulo.categorias)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filtro in const {
                            '': 'Todas',
                            'ativa': 'Ativas',
                            'inativa': 'Inativas',
                          }.entries) ...[
                            ChoiceChip(
                              key: ValueKey('admin-categorias-${filtro.key}'),
                              label: Text(filtro.value),
                              selected: _statusCategoria == filtro.key,
                              onSelected: (_) =>
                                  setState(() => _statusCategoria = filtro.key),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('admin-categorias-nova'),
                    tooltip: 'Nova categoria',
                    onPressed: _mutando ? null : () => _editarCategoria(),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          Expanded(
            child: itensVisiveis.isEmpty
                ? EmptyStateView(
                    title: items.isEmpty
                        ? _modulo == AdminModulo.documentos
                              ? 'Nenhum documento neste filtro'
                              : _tituloVazio(_modulo)
                        : _modulo == AdminModulo.categorias && filtrados.isEmpty
                        ? 'Nenhuma categoria neste filtro'
                        : 'Nenhum resultado encontrado',
                    message: items.isEmpty
                        ? _modulo == AdminModulo.documentos
                              ? 'Escolha outro status ou aguarde novos envios.'
                              : _mensagemVazia(_modulo)
                        : _modulo == AdminModulo.categorias && filtrados.isEmpty
                        ? 'Escolha outro status para ver as categorias cadastradas.'
                        : 'Tente outro termo de busca.',
                    icon: items.isEmpty
                        ? _iconeModulo(_modulo)
                        : Icons.search_off_rounded,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: itensVisiveis.length,
                    itemBuilder: (context, i) => _item(itensVisiveis[i]),
                  ),
          ),
        ],
      );
    },
  );

  Widget _item(Map<String, dynamic> item) {
    switch (_modulo) {
      case AdminModulo.usuarios:
        final ativo = item['ativo'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.verde),
            title: Text('${item['nome'] ?? 'Usuário'}'),
            subtitle: Text(
              '${item['email'] ?? ''}\n${_rotuloTipoConta(item['tipo'])} • ${ativo ? 'Ativo' : 'Desativado'}',
            ),
            isThreeLine: true,
            onTap: () => _detalhesUsuario(item),
            trailing: Switch(
              value: ativo,
              onChanged: _mutando ? null : (_) => _mudarStatus(item, ativo),
            ),
          ),
        );
      case AdminModulo.documentos:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              '${_rotuloTipoDocumento(item['tipoDocumento'])} • ${item['profissional']?['nome'] ?? 'Profissional'}',
            ),
            subtitle: Text(
              'Status: ${_rotuloStatusDocumento(item['status'])}\n${item['nomeArquivo'] ?? item['referenciaArquivo'] ?? ''}',
            ),
            isThreeLine: true,
            onTap: _mutando ? null : () => _analisarDocumento(item),
          ),
        );
      case AdminModulo.denuncias:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(
              Icons.report_outlined,
              color: Color(0xFFC53030),
            ),
            title: Text(
              '${_rotuloMotivoDenuncia(item['motivo'])} • ${_rotuloStatusDenuncia(item['status'])}',
            ),
            subtitle: Text(
              'Relato: ${item['descricao'] ?? ''}\nSolicitação #${item['solicitacaoId'] ?? ''}',
            ),
            isThreeLine: true,
            onTap: _mutando ? null : () => _analisarDenuncia(item),
          ),
        );
      case AdminModulo.avaliacoes:
        final nota = num.tryParse('${item['nota']}');
        final textoNota = nota == null
            ? 'Nota não informada'
            : '${item['nota']} ${nota == 1 ? 'estrela' : 'estrelas'}';
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.star_outline, color: AppColors.estrela),
            title: Text(
              '$textoNota • ${item['avaliador']?['nome'] ?? 'Usuário'}',
            ),
            subtitle: Text(
              'Avaliação de ${item['avaliado']?['nome'] ?? 'usuário'}\n${item['comentario'] ?? 'Sem comentário'}',
            ),
            isThreeLine: true,
            onTap: _mutando ? null : () => _analisarAvaliacao(item),
          ),
        );
      case AdminModulo.categorias:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: Icon(categoriaIconData('${item['icone'] ?? ''}')),
            title: Text('${item['nome']}'),
            subtitle: Text(item['ativo'] == true ? 'Ativa' : 'Inativa'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _mutando ? null : () => _editarCategoria(item),
            ),
          ),
        );
      case AdminModulo.auditoria:
        final ator = _map(item['ator']);
        final detalhe = '${item['detalhe'] ?? ''}'.trim();
        final alvo = _rotuloAlvoAuditoria(item['alvoTipo']?.toString());
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.history, color: AppColors.verde),
            title: Text(_rotuloAcaoAuditoria(item['acao']?.toString())),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por ${ator['nome'] ?? 'Administrador'} • ${_rotuloTipoConta(ator['tipo'])}',
                  ),
                  Text('Alvo: $alvo #${item['alvoId'] ?? '—'}'),
                  if (detalhe.isNotEmpty) Text(detalhe),
                  Text(_dataAuditoria(item['criadoEm'])),
                ],
              ),
            ),
            isThreeLine: true,
          ),
        );
      case AdminModulo.painel:
        return const SizedBox.shrink();
    }
  }

  Future<void> _detalhesUsuario(Map<String, dynamic> item) async {
    try {
      final response = await AppServices.instance.admin.usuario(
        int.parse('${item['id']}'),
      );
      if (!mounted) return;
      final usuario = response['usuario'];
      if (usuario is! Map<String, dynamic>) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text('${usuario['nome'] ?? 'Usuário'}'),
          content: Text(
            'Tipo: ${_rotuloTipoConta(usuario['tipo'])}\nE-mail: ${usuario['email']}\nTelefone: ${usuario['telefone'] ?? 'Não informado'}\nStatus: ${usuario['ativo'] == true ? 'Ativo' : 'Desativado'}\nCriado em: ${usuario['criadoEm'] ?? '—'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _avisar('Não foi possível carregar os detalhes do usuário.');
    }
  }

  Future<void> _mudarStatus(Map<String, dynamic> u, bool ativo) async {
    if (_mutando) return;
    final motivo = TextEditingController();
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(ativo ? 'Desativar conta?' : 'Reativar conta?'),
        content: TextField(
          controller: motivo,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirma != true) return;
    setState(() => _mutando = true);
    try {
      await AppServices.instance.admin.atualizarStatus(
        int.parse('${u['id']}'),
        !ativo,
        motivo: motivo.text.trim(),
      );
      if (mounted) {
        _avisar('Status da conta atualizado.');
        setState(() {
          _future = _carregar(_modulo);
          _future.ignore();
        });
      }
    } catch (_) {
      if (mounted) {
        _avisar('Não foi possível atualizar o status desta conta.');
      }
    } finally {
      if (mounted) setState(() => _mutando = false);
    }
  }

  Future<void> _analisarDocumento(Map<String, dynamic> item) async {
    if (_mutando) return;
    final motivo = TextEditingController();
    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Análise documental'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profissional: ${item['profissional']?['nome'] ?? '—'}'),
            Text('Tipo: ${_rotuloTipoDocumento(item['tipoDocumento'])}'),
            Text('Status atual: ${_rotuloStatusDocumento(item['status'])}'),
            if (item['motivoRejeicao'] != null)
              Text('Motivo registrado: ${item['motivoRejeicao']}'),
            Text(
              'Arquivo: ${item['nomeArquivo'] ?? item['referenciaArquivo'] ?? '—'}',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo da rejeição',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'rejeitado'),
            child: const Text('Rejeitar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'aprovado'),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (acao == null) return;
    if (acao == 'rejeitado' && motivo.text.trim().isEmpty) {
      _avisar('Informe o motivo para rejeitar.');
      return;
    }
    setState(() => _mutando = true);
    try {
      await AppServices.instance.admin.analisarDocumento(
        int.parse('${item['id']}'),
        acao,
        motivo: motivo.text.trim(),
      );
      if (mounted) {
        _avisar('Análise documental registrada.');
        setState(() {
          _future = _carregar(_modulo);
          _future.ignore();
        });
      }
    } catch (_) {
      if (mounted) _avisar('Não foi possível registrar a análise documental.');
    } finally {
      if (mounted) setState(() => _mutando = false);
    }
  }

  Future<void> _analisarDenuncia(Map<String, dynamic> item) async {
    if (_mutando) return;
    final decisao = TextEditingController(text: '${item['decisao'] ?? ''}');
    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Denúncia #${item['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Denunciante: ${item['denunciante']?['nome'] ?? '—'}'),
            Text('Denunciado: ${item['denunciado']?['nome'] ?? '—'}'),
            const SizedBox(height: 8),
            Text('${item['descricao'] ?? ''}'),
            TextField(
              controller: decisao,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Decisão ou nota de análise',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'em_analise'),
            child: const Text('Em análise'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'rejeitada'),
            child: const Text('Rejeitar denúncia'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'resolvida'),
            child: const Text('Registrar decisão'),
          ),
        ],
      ),
    );
    if (acao == null) return;
    if (acao != 'em_analise' && decisao.text.trim().isEmpty) {
      _avisar('Informe a decisão antes de concluir a análise.');
      return;
    }
    setState(() => _mutando = true);
    try {
      await AppServices.instance.admin.moderarDenuncia(
        int.parse('${item['id']}'),
        acao,
        decisao.text.trim(),
      );
      if (mounted) {
        _avisar('Decisão registrada.');
        setState(() {
          _future = _carregar(_modulo);
          _future.ignore();
        });
      }
    } catch (_) {
      if (mounted) _avisar('Não foi possível registrar a decisão.');
    } finally {
      if (mounted) setState(() => _mutando = false);
    }
  }

  Future<void> _analisarAvaliacao(Map<String, dynamic> item) async {
    if (_mutando) return;
    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Avaliação #${item['id']}'),
        content: Text(
          '“${item['comentario'] ?? 'Sem comentário'}”\n\nAção preserva o registro histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'rejeitada'),
            child: const Text('Ocultar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'aprovada'),
            child: const Text('Manter'),
          ),
        ],
      ),
    );
    if (status == null) return;
    setState(() => _mutando = true);
    try {
      await AppServices.instance.admin.moderarAvaliacao(
        int.parse('${item['id']}'),
        status,
      );
      if (mounted) {
        _avisar('Moderação da avaliação atualizada.');
        setState(() {
          _future = _carregar(_modulo);
          _future.ignore();
        });
      }
    } catch (_) {
      if (mounted) _avisar('Não foi possível atualizar a moderação.');
    } finally {
      if (mounted) setState(() => _mutando = false);
    }
  }

  Future<void> _editarCategoria([Map<String, dynamic>? categoria]) async {
    if (_mutando) return;
    final salvo = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CategoriaFormPage(categoria: categoria),
      ),
    );
    if (!mounted || salvo != true) return;
    _avisar('Categoria salva.');
    setState(() {
      _future = _carregar(_modulo);
      _future.ignore();
    });
  }

  void _avisar(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String _rotuloAcaoAuditoria(String? acao) => switch (acao) {
  'usuario_ativado' => 'Conta ativada',
  'usuario_desativado' => 'Conta desativada',
  'administrador_criado' => 'Administrador criado',
  'categoria_criada' => 'Categoria criada',
  'categoria_atualizada' => 'Categoria atualizada',
  'documento_analisado' => 'Documento analisado',
  'denuncia_moderada' => 'Denúncia moderada',
  'avaliacao_moderada' => 'Avaliação moderada',
  _ => 'Ação administrativa',
};

String _rotuloAlvoAuditoria(String? alvo) => switch (alvo) {
  'usuario' => 'Usuário',
  'documento_verificacao' => 'Documento',
  'categoria' => 'Categoria',
  'denuncia' => 'Denúncia',
  'avaliacao' => 'Avaliação',
  _ => alvo ?? 'Registro',
};

String _rotuloTipoConta(Object? tipo) => switch (tipo) {
  'cliente' => 'Cliente',
  'profissional' => 'Profissional',
  'empresa' => 'Empresa',
  'administrador' => 'Administrador',
  _ => 'Tipo não informado',
};

String _rotuloTipoDocumento(Object? tipo) => switch (tipo) {
  'documento_identidade' => 'Documento de identificação',
  'comprovante_endereco' => 'Comprovante de endereço',
  'certificado_opcional' => 'Certificado profissional',
  _ => 'Documento',
};

String _rotuloStatusDocumento(Object? status) => switch (status) {
  'pendente' => 'Em análise',
  'aprovado' => 'Aprovado',
  'rejeitado' => 'Rejeitado',
  _ => 'Status não informado',
};

String _rotuloStatusDenuncia(Object? status) => switch (status) {
  'pendente' => 'Pendente',
  'aberta' => 'Aberta',
  'em_analise' => 'Em análise',
  'resolvida' => 'Resolvida',
  'rejeitada' => 'Rejeitada',
  _ => 'Status não informado',
};

String _rotuloMotivoDenuncia(Object? motivo) => switch (motivo) {
  'Conteudo ofensivo' => 'Conteúdo ofensivo',
  String texto when texto.trim().isNotEmpty => texto,
  _ => 'Denúncia',
};

String _dataAuditoria(Object? valor) {
  final data = valor is String ? DateTime.tryParse(valor)?.toLocal() : null;
  if (data == null) return 'Data indisponível';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year} às $hora:$minuto';
}

String _descricaoModulo(AdminModulo modulo) => switch (modulo) {
  AdminModulo.usuarios => 'Consulte perfis e gerencie o acesso à plataforma.',
  AdminModulo.documentos =>
    'Revise os documentos enviados pelos profissionais.',
  AdminModulo.denuncias => 'Acompanhe relatos e registre decisões de análise.',
  AdminModulo.avaliacoes => 'Revise avaliações que aguardam moderação.',
  AdminModulo.categorias => 'Organize as categorias disponíveis no catálogo.',
  AdminModulo.auditoria => 'Consulte as ações administrativas recentes.',
  AdminModulo.painel => 'Indicadores e ferramentas administrativas.',
};

String _tituloVazio(AdminModulo modulo) => switch (modulo) {
  AdminModulo.usuarios => 'Nenhuma conta encontrada',
  AdminModulo.documentos => 'Nenhum documento pendente',
  AdminModulo.denuncias => 'Nenhuma denúncia para analisar',
  AdminModulo.avaliacoes => 'Nenhuma avaliação pendente',
  AdminModulo.categorias => 'Nenhuma categoria cadastrada',
  AdminModulo.auditoria => 'Nenhuma ação registrada',
  AdminModulo.painel => 'Sem informações para exibir',
};

String _mensagemVazia(AdminModulo modulo) => switch (modulo) {
  AdminModulo.usuarios =>
    'Tente outra busca ou altere o filtro de tipo de conta.',
  AdminModulo.documentos => 'Novos envios aparecerão nesta lista.',
  AdminModulo.denuncias => 'Novos relatos aparecerão nesta lista.',
  AdminModulo.avaliacoes => 'Não há avaliações aguardando moderação agora.',
  AdminModulo.categorias => 'Use “Nova categoria” para cadastrar uma.',
  AdminModulo.auditoria => 'As ações administrativas aparecerão aqui.',
  AdminModulo.painel => 'Tente carregar o painel novamente.',
};

String _textoIndexavel(Map<String, dynamic> item) {
  final avaliador = item['avaliador'] is Map
      ? (item['avaliador'] as Map)['nome']
      : null;
  final avaliado = item['avaliado'] is Map
      ? (item['avaliado'] as Map)['nome']
      : null;
  return [
    item['nome'],
    item['categoria'],
    item['status'],
    item['comentario'],
    avaliador,
    avaliado,
  ].whereType<Object>().join(' ').toLowerCase();
}

IconData _iconeModulo(AdminModulo modulo) => switch (modulo) {
  AdminModulo.usuarios => Icons.people_outline_rounded,
  AdminModulo.documentos => Icons.verified_user_outlined,
  AdminModulo.denuncias => Icons.flag_outlined,
  AdminModulo.avaliacoes => Icons.star_outline_rounded,
  AdminModulo.categorias => Icons.category_outlined,
  AdminModulo.auditoria => Icons.history_rounded,
  AdminModulo.painel => Icons.dashboard_outlined,
};

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppColors.verde),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _AdminAtalho extends StatelessWidget {
  const _AdminAtalho({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.verde),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
