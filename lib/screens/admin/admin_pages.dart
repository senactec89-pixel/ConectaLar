import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/service_registry.dart';
import '../../widgets/app_bar_custom.dart';

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
        result = await service.documentos(status: 'pendente');
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
    _future = _carregar(modulo);
  });

  @override
  Widget build(BuildContext context) {
    final tipoUsuario = AppServices.instance.auth.usuarioAtual?['tipo']
        ?.toString();
    if (tipoUsuario != 'administrador') {
      return Scaffold(
        appBar: const AppBarCustom(title: 'Área administrativa'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Acesso restrito a uma conta administrativa autorizada.',
              textAlign: TextAlign.center,
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
        actions: _modulo == AdminModulo.painel
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _abrir(AdminModulo.painel),
                ),
              ],
      ),
      backgroundColor: AppColors.fundo,
      body: _modulo == AdminModulo.painel ? _painel() : _lista(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (_modulo) {
          AdminModulo.painel => 0,
          AdminModulo.usuarios => 1,
          AdminModulo.categorias => 3,
          AdminModulo.auditoria => 0,
          _ => 2,
        },
        onDestinationSelected: (i) => _abrir(switch (i) {
          1 => AdminModulo.usuarios,
          2 => AdminModulo.denuncias,
          3 => AdminModulo.categorias,
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
        ],
      ),
    );
  }

  Widget _painel() => FutureBuilder<Map<String, dynamic>>(
    future: AppServices.instance.admin.painel(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar o resumo administrativo.'),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
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
          const Text('Indicadores consolidados pela API administrativa.'),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
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

  Widget _lista() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Não foi possível carregar este módulo. Confira sua sessão administrativa.',
              ),
              TextButton(
                onPressed: () => setState(() => _future = _carregar(_modulo)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
      }
      final items = snapshot.data ?? const <Map<String, dynamic>>[];
      return Column(
        children: [
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
                    onSubmitted: (_) =>
                        setState(() => _future = _carregar(_modulo)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _tipo,
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
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => _editarCategoria(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova categoria'),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _modulo == AdminModulo.auditoria
                          ? 'Nenhuma ação administrativa registrada.'
                          : 'Nenhum item para revisar.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _item(items[i]),
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
              '${item['email'] ?? ''}\n${item['tipo'] ?? ''} • ${ativo ? 'Ativo' : 'Desativado'}',
            ),
            isThreeLine: true,
            onTap: () => _detalhesUsuario(item),
            trailing: Switch(
              value: ativo,
              onChanged: (_) => _mudarStatus(item, ativo),
            ),
          ),
        );
      case AdminModulo.documentos:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              '${item['tipoDocumento'] ?? 'Documento'} • ${item['profissional']?['nome'] ?? 'Profissional'}',
            ),
            subtitle: Text(
              'Status: ${item['status']}\n${item['nomeArquivo'] ?? item['referenciaArquivo'] ?? ''}',
            ),
            isThreeLine: true,
            onTap: () => _analisarDocumento(item),
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
            title: Text('${item['motivo'] ?? 'Denúncia'} • ${item['status']}'),
            subtitle: Text(
              'Relato: ${item['descricao'] ?? ''}\nSolicitação #${item['solicitacaoId'] ?? ''}',
            ),
            isThreeLine: true,
            onTap: () => _analisarDenuncia(item),
          ),
        );
      case AdminModulo.avaliacoes:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.star_outline, color: AppColors.estrela),
            title: Text(
              '${item['nota'] ?? '-'} estrelas • ${item['avaliador']?['nome'] ?? 'Usuário'}',
            ),
            subtitle: Text(
              'Avaliação de ${item['avaliado']?['nome'] ?? 'usuário'}\n${item['comentario'] ?? 'Sem comentário'}',
            ),
            isThreeLine: true,
            onTap: () => _analisarAvaliacao(item),
          ),
        );
      case AdminModulo.categorias:
        return Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text('${item['nome']}'),
            subtitle: Text(item['ativo'] == true ? 'Ativa' : 'Inativa'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editarCategoria(item),
            ),
          ),
        );
      case AdminModulo.auditoria:
        final ator = _map(item['ator']);
        final detalhe = '${item['detalhe'] ?? ''}'.trim();
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
                    'Por ${ator['nome'] ?? 'Administrador'} • ${ator['tipo'] ?? 'administrador'}',
                  ),
                  Text(
                    'Alvo: ${item['alvoTipo'] ?? 'registro'} #${item['alvoId'] ?? '—'}',
                  ),
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
          title: Text('${usuario['nome'] ?? 'Usuário'}'),
          content: Text(
            'Tipo: ${usuario['tipo']}\nE-mail: ${usuario['email']}\nTelefone: ${usuario['telefone'] ?? 'Não informado'}\nStatus: ${usuario['ativo'] == true ? 'Ativo' : 'Desativado'}\nCriado em: ${usuario['criadoEm'] ?? '—'}',
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
    final motivo = TextEditingController();
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    try {
      await AppServices.instance.admin.atualizarStatus(
        int.parse('${u['id']}'),
        !ativo,
        motivo: motivo.text.trim(),
      );
      if (mounted) setState(() => _future = _carregar(_modulo));
    } catch (_) {
      if (mounted) {
        _avisar('A API não permitiu atualizar o status desta conta.');
      }
    }
  }

  Future<void> _analisarDocumento(Map<String, dynamic> item) async {
    final motivo = TextEditingController();
    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Análise documental'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profissional: ${item['profissional']?['nome'] ?? '—'}'),
            Text('Tipo: ${item['tipoDocumento'] ?? '—'}'),
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
    try {
      await AppServices.instance.admin.analisarDocumento(
        int.parse('${item['id']}'),
        acao,
        motivo: motivo.text.trim(),
      );
      if (mounted) setState(() => _future = _carregar(_modulo));
    } catch (_) {
      if (mounted) _avisar('Não foi possível registrar a análise documental.');
    }
  }

  Future<void> _analisarDenuncia(Map<String, dynamic> item) async {
    final decisao = TextEditingController(text: '${item['decisao'] ?? ''}');
    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
    try {
      await AppServices.instance.admin.moderarDenuncia(
        int.parse('${item['id']}'),
        acao,
        decisao.text.trim(),
      );
      if (mounted) setState(() => _future = _carregar(_modulo));
    } catch (_) {
      if (mounted) _avisar('Não foi possível registrar a decisão.');
    }
  }

  Future<void> _analisarAvaliacao(Map<String, dynamic> item) async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
    try {
      await AppServices.instance.admin.moderarAvaliacao(
        int.parse('${item['id']}'),
        status,
      );
      if (mounted) setState(() => _future = _carregar(_modulo));
    } catch (_) {
      if (mounted) _avisar('Não foi possível atualizar a moderação.');
    }
  }

  Future<void> _editarCategoria([Map<String, dynamic>? categoria]) async {
    final nome = TextEditingController(text: '${categoria?['nome'] ?? ''}');
    var ativo = categoria?['ativo'] != false;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            categoria == null ? 'Nova categoria' : 'Editar categoria',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              SwitchListTile(
                value: ativo,
                onChanged: (v) => setDialog(() => ativo = v),
                title: const Text('Ativa'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => nome.text.trim().length < 2
                  ? null
                  : Navigator.pop(context, (nome.text.trim(), ativo)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await AppServices.instance.admin.salvarCategoria(
        id: categoria == null ? null : int.parse('${categoria['id']}'),
        nome: result.$1,
        ativo: result.$2,
      );
      if (mounted) setState(() => _future = _carregar(_modulo));
    } catch (_) {
      if (mounted) {
        _avisar(
          'Não foi possível salvar a categoria. O nome pode já estar em uso.',
        );
      }
    }
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

String _dataAuditoria(Object? valor) {
  final data = valor is String ? DateTime.tryParse(valor)?.toLocal() : null;
  if (data == null) return 'Data indisponível';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year} às $hora:$minuto';
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: AppColors.verde),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
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
