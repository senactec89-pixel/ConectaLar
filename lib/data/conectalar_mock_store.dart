import 'package:flutter/foundation.dart';

import '../models/avaliacao.dart';
import '../models/mensagem.dart';
import '../models/profissional.dart';
import '../models/solicitacao.dart';
import '../models/usuario.dart';
import '../screens/home/home_mock_data.dart';

class AtendimentoResumo {
  const AtendimentoResumo({
    required this.profissional,
    required this.categoria,
    required this.solicitacao,
    this.cliente,
    this.avaliado = false,
  });

  final String profissional;
  final String? cliente;
  final String categoria;
  final Solicitacao solicitacao;
  final bool avaliado;

  String nomeDaOutraParte(String papelAtual) =>
      {'profissional', 'empresa'}.contains(papelAtual)
      ? cliente ?? 'Cliente'
      : profissional;

  AtendimentoResumo copyWith({Solicitacao? solicitacao, bool? avaliado}) {
    return AtendimentoResumo(
      profissional: profissional,
      cliente: cliente,
      categoria: categoria,
      solicitacao: solicitacao ?? this.solicitacao,
      avaliado: avaliado ?? this.avaliado,
    );
  }
}

class ConectaLarMockStore extends ChangeNotifier {
  ConectaLarMockStore._();

  static final instance = ConectaLarMockStore._();

  Usuario _usuarioAtual = const Usuario(
    id: 501,
    nome: 'Mariana Alves',
    email: 'mariana@email.com',
    tipo: TipoUsuario.cliente,
    telefone: '(31) 99999-0000',
    bairro: 'Jardim das Flores',
  );

  final Set<int> _favoritos = {1, 2};
  final List<Mensagem> _mensagens = [
    Mensagem(
      id: 1,
      solicitacaoId: 1002,
      remetenteId: 102,
      conteudo:
          'Olá, Mariana. Posso atender no dia e horário solicitados. O valor final combinamos no local.',
      lida: true,
      criadoEm: DateTime(2026, 10, 8, 18, 4),
    ),
    Mensagem(
      id: 2,
      solicitacaoId: 1002,
      remetenteId: 501,
      conteudo:
          'Perfeito, obrigada. O endereço completo aparece após o aceite?',
      lida: true,
      criadoEm: DateTime(2026, 10, 8, 18, 8),
    ),
    Mensagem(
      id: 3,
      solicitacaoId: 1001,
      remetenteId: 501,
      conteudo:
          'Preciso instalar um chuveiro novo. O bairro é Jardim das Flores.',
      lida: false,
      criadoEm: DateTime(2026, 10, 10, 9, 3),
    ),
  ];

  final List<Avaliacao> _avaliacoes = [];

  late final List<AtendimentoResumo> _servicos = [
    AtendimentoResumo(
      profissional: 'Carlos Silva',
      cliente: 'Mariana Alves',
      categoria: 'Elétrica',
      solicitacao: Solicitacao(
        id: 1001,
        clienteId: 501,
        profissionalId: 1,
        categoriaId: 1,
        descricao: 'Instalar chuveiro no banheiro social.',
        dataServico: DateTime(2026, 10, 15),
        horarioServico: '14:00',
        precoInicial: 80,
        status: StatusSolicitacao.aguardandoResposta,
        criadoEm: DateTime(2026, 10, 10, 9),
        atualizadoEm: DateTime(2026, 10, 10, 9),
      ),
    ),
    AtendimentoResumo(
      profissional: 'Ana Souza',
      cliente: 'Mariana Alves',
      categoria: 'Limpeza',
      solicitacao: Solicitacao(
        id: 1002,
        clienteId: 501,
        profissionalId: 2,
        categoriaId: 4,
        descricao: 'Limpeza completa antes da vistoria.',
        dataServico: DateTime(2026, 10, 18),
        horarioServico: '09:00',
        precoInicial: 70,
        status: StatusSolicitacao.aceitaAgendada,
        criadoEm: DateTime(2026, 10, 8, 14),
        atualizadoEm: DateTime(2026, 10, 8, 18),
      ),
    ),
    AtendimentoResumo(
      profissional: 'Carlos Silva',
      cliente: 'Mariana Alves',
      categoria: 'Manutenção',
      avaliado: true,
      solicitacao: Solicitacao(
        id: 1003,
        clienteId: 501,
        profissionalId: 1,
        categoriaId: 5,
        descricao: 'Revisão de tomadas da cozinha.',
        dataServico: DateTime(2026, 9, 28),
        horarioServico: '16:00',
        precoInicial: 120,
        status: StatusSolicitacao.conclusaoConfirmada,
        criadoEm: DateTime(2026, 9, 23, 10),
        atualizadoEm: DateTime(2026, 9, 28, 18),
      ),
    ),
    AtendimentoResumo(
      profissional: 'Ana Souza',
      cliente: 'Mariana Alves',
      categoria: 'Organização',
      solicitacao: Solicitacao(
        id: 1004,
        clienteId: 501,
        profissionalId: 2,
        categoriaId: 4,
        descricao: 'Organização dos armários da área de serviço.',
        dataServico: DateTime(2026, 9, 20),
        horarioServico: '10:30',
        precoInicial: 90,
        status: StatusSolicitacao.recusada,
        criadoEm: DateTime(2026, 9, 15, 11),
        atualizadoEm: DateTime(2026, 9, 15, 15),
      ),
    ),
  ];

  Usuario get usuarioAtual => _usuarioAtual;
  List<AtendimentoResumo> get servicos => List.unmodifiable(_servicos);
  List<Avaliacao> get avaliacoes => List.unmodifiable(_avaliacoes);

  List<Profissional> get profissionais =>
      HomeMockData.content.featuredProfessionals;

  List<Profissional> get profissionaisFavoritos => profissionais
      .where((profissional) => _favoritos.contains(profissional.id))
      .toList(growable: false);

  bool isFavorito(int profissionalId) => _favoritos.contains(profissionalId);

  Profissional? profissionalPorId(int profissionalId) {
    for (final profissional in profissionais) {
      if (profissional.id == profissionalId) return profissional;
    }
    return null;
  }

  AtendimentoResumo? atendimentoPorId(int solicitacaoId) {
    for (final atendimento in _servicos) {
      if (atendimento.solicitacao.id == solicitacaoId) return atendimento;
    }
    return null;
  }

  List<Mensagem> mensagensDaSolicitacao(int solicitacaoId) {
    return _mensagens
        .where((mensagem) => mensagem.solicitacaoId == solicitacaoId)
        .toList(growable: false)
      ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
  }

  void loginComoCliente({required String email}) {
    _usuarioAtual = Usuario(
      id: 501,
      nome: 'Mariana Alves',
      email: email.trim(),
      tipo: TipoUsuario.cliente,
      telefone: '(31) 99999-0000',
      bairro: 'Jardim das Flores',
    );
    notifyListeners();
  }

  void registrarConta({
    required String nome,
    required String email,
    required TipoUsuario tipo,
    String? telefone,
  }) {
    // Senha não é guardada no mock. Em produção, hash e sessão pertencem ao backend.
    _usuarioAtual = Usuario(
      id: tipo == TipoUsuario.cliente ? 501 : 601,
      nome: nome.trim(),
      email: email.trim(),
      tipo: tipo,
      telefone: telefone?.trim(),
      bairro: 'Jardim das Flores',
    );
    notifyListeners();
  }

  void logout() {
    notifyListeners();
  }

  void toggleFavorito(int profissionalId) {
    if (_favoritos.contains(profissionalId)) {
      _favoritos.remove(profissionalId);
    } else {
      _favoritos.add(profissionalId);
    }
    notifyListeners();
  }

  int criarSolicitacao({
    required Profissional profissional,
    required String servico,
    required String descricao,
    required String bairro,
    required DateTime data,
    required String horario,
  }) {
    final id = 1100 + _servicos.length + 1;
    final categoriaId = profissional.categoriaIds.isEmpty
        ? 8
        : profissional.categoriaIds.first;

    _servicos.insert(
      0,
      AtendimentoResumo(
        profissional: profissional.nome,
        cliente: _usuarioAtual.nome,
        categoria: servico,
        solicitacao: Solicitacao(
          id: id,
          clienteId: _usuarioAtual.id,
          profissionalId: profissional.id,
          categoriaId: categoriaId,
          descricao: descricao.trim(),
          dataServico: data,
          horarioServico: horario.trim(),
          precoInicial: profissional.precoInicial ?? 0,
          status: StatusSolicitacao.aguardandoResposta,
          criadoEm: DateTime.now(),
          atualizadoEm: DateTime.now(),
        ),
      ),
    );

    enviarMensagem(
      solicitacaoId: id,
      conteudo:
          'Solicitação criada para $servico em $bairro. Endereço completo protegido até aceite.',
    );
    notifyListeners();
    return id;
  }

  bool aceitarSolicitacaoComoProfissional(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.aguardandoResposta],
      novoStatus: StatusSolicitacao.aceitaAgendada,
    );
  }

  bool recusarSolicitacaoComoProfissional(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.aguardandoResposta],
      novoStatus: StatusSolicitacao.recusada,
    );
  }

  bool cancelarSolicitacao(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [
        StatusSolicitacao.aguardandoResposta,
        StatusSolicitacao.aceitaAgendada,
      ],
      novoStatus: StatusSolicitacao.cancelada,
    );
  }

  bool marcarServicoRealizado(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.aceitaAgendada],
      novoStatus: StatusSolicitacao.conclusaoPendente,
    );
  }

  bool confirmarConclusao(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [
        StatusSolicitacao.conclusaoPendente,
        StatusSolicitacao.conclusaoContestada,
      ],
      novoStatus: StatusSolicitacao.conclusaoConfirmada,
    );
  }

  bool contestarConclusao(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.conclusaoPendente],
      novoStatus: StatusSolicitacao.conclusaoContestada,
    );
  }

  bool informarNaoComparecimento(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.aceitaAgendada],
      novoStatus: StatusSolicitacao.naoComparecimentoInformado,
    );
  }

  bool contestarNaoComparecimento(int solicitacaoId) {
    return _transicionar(
      solicitacaoId,
      permitido: [StatusSolicitacao.naoComparecimentoInformado],
      novoStatus: StatusSolicitacao.conclusaoContestada,
    );
  }

  bool avaliarAtendimento({
    required int solicitacaoId,
    required int nota,
    String? comentario,
  }) {
    final index = _servicos.indexWhere(
      (servico) => servico.solicitacao.id == solicitacaoId,
    );
    if (index == -1) return false;

    final atendimento = _servicos[index];
    if (atendimento.solicitacao.status !=
            StatusSolicitacao.conclusaoConfirmada ||
        atendimento.avaliado) {
      return false;
    }

    _avaliacoes.add(
      Avaliacao(
        id: _avaliacoes.length + 1,
        solicitacaoId: solicitacaoId,
        avaliadorId: atendimento.solicitacao.clienteId,
        avaliadoId: atendimento.solicitacao.profissionalId,
        nota: nota,
        comentario: comentario?.trim().isEmpty ?? true
            ? null
            : comentario!.trim(),
        criadoEm: DateTime.now(),
      ),
    );
    _servicos[index] = atendimento.copyWith(avaliado: true);
    notifyListeners();
    return true;
  }

  void enviarMensagem({
    required int solicitacaoId,
    required String conteudo,
    int? remetenteId,
  }) {
    final texto = conteudo.trim();
    if (texto.isEmpty || atendimentoPorId(solicitacaoId) == null) return;

    _mensagens.add(
      Mensagem(
        id: _mensagens.length + 1,
        solicitacaoId: solicitacaoId,
        remetenteId: remetenteId ?? _usuarioAtual.id,
        conteudo: texto,
        lida: false,
        criadoEm: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  bool _transicionar(
    int solicitacaoId, {
    required List<StatusSolicitacao> permitido,
    required StatusSolicitacao novoStatus,
  }) {
    final index = _servicos.indexWhere(
      (servico) => servico.solicitacao.id == solicitacaoId,
    );
    if (index == -1) return false;

    final atendimento = _servicos[index];
    if (!permitido.contains(atendimento.solicitacao.status)) return false;

    _servicos[index] = atendimento.copyWith(
      solicitacao: _copiarSolicitacao(
        atendimento.solicitacao,
        status: novoStatus,
      ),
    );
    notifyListeners();
    return true;
  }

  Solicitacao _copiarSolicitacao(
    Solicitacao solicitacao, {
    required StatusSolicitacao status,
  }) {
    return Solicitacao(
      id: solicitacao.id,
      clienteId: solicitacao.clienteId,
      profissionalId: solicitacao.profissionalId,
      categoriaId: solicitacao.categoriaId,
      descricao: solicitacao.descricao,
      bairroAtendimento: solicitacao.bairroAtendimento,
      enderecoProtegido: solicitacao.enderecoProtegido,
      enderecoCompletoLiberado: solicitacao.enderecoCompletoLiberado,
      enderecoId: solicitacao.enderecoId,
      enderecoAtendimento: solicitacao.enderecoAtendimento,
      profissionalUsuarioId: solicitacao.profissionalUsuarioId,
      servicoId: solicitacao.servicoId,
      nomeServico: solicitacao.nomeServico,
      dataServico: solicitacao.dataServico,
      horarioServico: solicitacao.horarioServico,
      duracaoMinutos: solicitacao.duracaoMinutos,
      intervaloMinutos: solicitacao.intervaloMinutos,
      reagendamento: solicitacao.reagendamento,
      reagendamentos: solicitacao.reagendamentos,
      orcamento: solicitacao.orcamento,
      orcamentos: solicitacao.orcamentos,
      cancelamentoMotivo: solicitacao.cancelamentoMotivo,
      conclusaoContestacaoMotivo: solicitacao.conclusaoContestacaoMotivo,
      naoComparecimentoMotivo: solicitacao.naoComparecimentoMotivo,
      naoComparecimentoPorId: solicitacao.naoComparecimentoPorId,
      eventos: solicitacao.eventos,
      precoInicial: solicitacao.precoInicial,
      precoFinal: solicitacao.precoFinal,
      status: status,
      criadoEm: solicitacao.criadoEm,
      atualizadoEm: DateTime.now(),
    );
  }
}
