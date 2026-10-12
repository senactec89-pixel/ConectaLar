import 'dart:convert';

import 'package:http/http.dart' as http;

import '../screens/home/home_mock_data.dart';

/// Respostas fictícias locais para prévia visual explicitamente ativada.
/// Não possui cliente de rede, não grava arquivos e não executa mutações.
class FrontendPreviewClient extends http.BaseClient {
  FrontendPreviewClient({String papel = 'cliente'})
    : papel =
          const {
            'cliente',
            'profissional',
            'empresa',
            'administrador',
          }.contains(papel)
          ? papel
          : 'cliente';

  final String papel;

  Map<String, dynamic> get usuario => {
    'id': papel == 'cliente'
        ? 501
        : papel == 'administrador'
        ? 900
        : 101,
    'nome': switch (papel) {
      'administrador' => 'Admin — demonstração',
      'empresa' => 'Empresa — demonstração',
      'profissional' => 'Profissional — demonstração',
      _ => 'Cliente — demonstração',
    },
    'email': 'previa@example.invalid',
    'telefone': '(00) 00000-0000',
    'tipo': papel,
    'ativo': true,
  };

  List<Map<String, dynamic>> get categorias => [
    for (final c in HomeMockData.content.categories)
      {'id': c.id, 'nome': c.nome, 'ativo': true},
  ];

  List<Map<String, dynamic>> get profissionais => [
    for (final p in HomeMockData.content.featuredProfessionals)
      {
        'id': p.id,
        'usuarioId': p.usuarioId,
        'nome': '${p.nome} — demonstração',
        'descricao': p.descricao,
        'bairro': p.bairro,
        'precoInicial': p.precoInicial,
        'verificado': p.verificado,
        'notaMedia': 4.5,
        'quantidadeAvaliacoes': 2,
        'servicos': [
          for (var i = 0; i < p.servicos.length; i++)
            {
              'id': p.id * 10 + i,
              'nome': p.servicos[i],
              'ativo': true,
              'categoriaId': p.categoriaIds.first,
              'categoria': categorias.firstWhere(
                (c) => c['id'] == p.categoriaIds.first,
              ),
              'precoInicial': p.precoInicial,
            },
        ],
      },
  ];

  Map<String, dynamic>? _profissionalPorId(String id) {
    for (final profissional in profissionais) {
      if ('${profissional['id']}' == id) return profissional;
    }
    return null;
  }

  Map<String, dynamic> get endereco => {
    'id': 1,
    'apelido': 'Endereço fictício',
    'logradouro': 'Rua de exemplo',
    'numero': '100',
    'bairro': 'Centro',
    'cidade': 'Cidade de exemplo',
    'uf': 'MG',
    'cep': '00000-000',
    'principal': true,
  };

  List<Map<String, dynamic>> get pedidos => [
    for (var i = 0; i < 3; i++)
      {
        'id': 1001 + i,
        'cliente': {'id': 501, 'nome': 'Cliente de demonstração'},
        'profissional': profissionais.first,
        'categoria': categorias.first,
        'servicoId': 10,
        'nomeServico': 'Instalação elétrica',
        'descricao': 'Exemplo fictício de atendimento para revisar a tela.',
        'bairroAtendimento': 'Centro',
        'precoInicial': 80,
        'dataServico': DateTime.now()
            .add(Duration(days: i + 1))
            .toIso8601String()
            .substring(0, 10),
        'horarioServico': '14:00',
        'status': [
          'aguardando_resposta',
          'aceita_agendada',
          'conclusao_confirmada',
        ][i],
        'avaliado': i == 2,
        'enderecoId': 1,
        'enderecoProtegido': i == 0,
        'enderecoCompletoLiberado': i > 0,
        if (i > 0) 'enderecoAtendimento': endereco,
        'criadoEm': '2026-10-11T12:00:00Z',
        'atualizadoEm': '2026-10-11T12:00:00Z',
      },
  ];

  List<Map<String, dynamic>> get documentos => [
    for (var i = 0; i < 3; i++)
      {
        'id': i + 1,
        'tipoDocumento': 'documento_identidade',
        'status': ['pendente', 'aprovado', 'rejeitado'][i],
        'nomeArquivo': 'documento-ficticio-${i + 1}.pdf',
        'referenciaArquivo': 'previa-visual',
        'profissional': profissionais.first,
        'motivoRejeicao': i == 2 ? 'Exemplo de documento ilegível.' : null,
        'criadoEm': '2026-10-11T12:00:00Z',
      },
  ];

  Map<String, dynamic> get avaliacoes => {
    'resumo': {'notaMedia': 4.5, 'quantidadeAvaliacoes': 2},
    'avaliacoes': [
      for (var i = 0; i < 2; i++)
        {
          'id': i + 1,
          'nota': 4 + i,
          'comentario': 'Comentário fictício para prévia visual.',
          'avaliador': {'nome': 'Cliente de demonstração'},
          'avaliado': profissionais.first,
          'moderacaoStatus': 'aprovada',
          'criadoEm': '2026-10-11T12:00:00Z',
        },
    ],
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final Object? data;
    var status = 200;
    if (request.method == 'POST' && path == '/auth/login') {
      data = {
        'usuario': usuario,
        'token': {'accessToken': 'previa-local-sem-validade-na-api'},
      };
    } else if (request.method == 'POST' && path == '/auth/logout') {
      data = {'ok': true};
    } else if (request.method != 'GET') {
      status = 409;
      data = {
        'message':
            'Prévia visual: esta ação não salva nem envia dados. Use a versão integrada para realizar operações.',
      };
    } else {
      data = _consulta(path, request.url.queryParameters);
      if (data == null) {
        status = 404;
      }
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            data ?? {'message': 'Conteúdo indisponível nesta prévia.'},
          ),
        ),
      ),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  Object? _consulta(String path, Map<String, String> query) {
    if (path.endsWith('/avaliacoes') || path == '/avaliacoes/moderacao') {
      return avaliacoes;
    }
    if (path.endsWith('/disponibilidade')) {
      return {
        'disponibilidades': [
          {
            'id': 1,
            'diaSemana': DateTime.now().weekday % 7,
            'horaInicio': '08:00',
            'horaFim': '18:00',
            'ativo': true,
          },
        ],
      };
    }
    if (RegExp(r'^/profissionais/\d+$').hasMatch(path)) {
      final id = path.split('/').last;
      return {'profissional': _profissionalPorId(id)};
    }
    if (RegExp(r'^/solicitacoes/\d+/mensagens$').hasMatch(path)) {
      return {
        'mensagens': [
          {
            'id': 1,
            'autor': {'id': 501, 'nome': 'Cliente demonstração'},
            'solicitacaoId': int.tryParse(path.split('/')[2]),
            'conteudo': 'Olá! Esta conversa contém somente dados fictícios.',
            'criadoEm': '2026-10-11T12:00:00Z',
          },
        ],
      };
    }
    if (RegExp(r'^/solicitacoes/\d+$').hasMatch(path)) {
      return {
        'solicitacao': pedidos.firstWhere(
          (p) => '${p['id']}' == path.split('/').last,
          orElse: () => pedidos.first,
        ),
      };
    }
    if (RegExp(r'^/profissionais/\d+$').hasMatch(path)) {
      final id = path.split('/').last;
      return {'profissional': _profissionalPorId(id)};
    }
    return switch (path) {
      '/categorias' || '/categorias/admin' => {'categorias': categorias},
      '/profissionais' => {'profissionais': profissionais},
      '/profissionais/me' => {'profissional': profissionais.first},
      '/profissionais/me/servicos' => {
        'servicos': profissionais.first['servicos'],
      },
      '/profissionais/me/painel' => {
        'perfil': profissionais.first,
        'resumo': {'solicitacoesNovas': 1, 'agendados': 1, 'concluidos': 1},
        'solicitacoesRecentes': pedidos,
        'proximosAtendimentos': [pedidos[1]],
      },
      '/profissionais/me/agenda' => {
        'atendimentos': [pedidos[1]],
        'disponibilidade': [],
      },
      '/solicitacoes/me' => {'solicitacoes': pedidos},
      '/historico/atendimentos/me' => {'atendimentos': pedidos},
      '/clientes/me' => {
        'cliente': {...usuario, 'bairro': 'Centro'},
      },
      '/clientes/me/enderecos' => {
        'enderecos': [endereco],
      },
      '/clientes/me/favoritos' => {
        'favoritos': [
          for (final p in profissionais) {'profissional': p},
        ],
      },
      '/profissionais/me/documentos' => {'documentos': documentos},
      '/documentos-verificacao' => {
        'documentos': documentos
            .where(
              (d) => query['status'] == null || d['status'] == query['status'],
            )
            .toList(),
      },
      '/notificacoes/me/resumo' => {'naoLidas': 1},
      '/notificacoes/me' => {
        'notificacoes': [
          {
            'id': 1,
            'titulo': 'Exemplo de notificação',
            'mensagem': 'Dados fictícios da prévia visual.',
            'lida': false,
            'recursoTipo': 'solicitacao',
            'recursoId': 1001,
            'criadoEm': '2026-10-11T12:00:00Z',
          },
        ],
      },
      '/admin/painel' => {
        'usuarios': {'ativos': 3, 'profissionais': 1},
        'profissionais': {'perfisAtivos': 1},
        'moderacao': {
          'documentosPendentes': 1,
          'denunciasAbertas': 1,
          'avaliacoesPendentes': 2,
        },
        'catalogo': {'categoriasAtivas': 8},
        'atendimentos': {'aguardandoResposta': 1, 'aceitaAgendada': 1},
      },
      '/admin/usuarios' => {
        'usuarios': [
          usuario,
          {
            'id': 501,
            'nome': 'Cliente de demonstração',
            'email': 'cliente@example.invalid',
            'tipo': 'cliente',
            'ativo': true,
          },
        ],
      },
      '/admin/painel/auditoria' => {
        'eventos': [
          {
            'id': 1,
            'acao': 'documento_analisado',
            'ator': usuario,
            'alvoTipo': 'documento_verificacao',
            'alvoId': 2,
            'detalhe': 'Evento fictício de demonstração.',
            'criadoEm': '2026-10-11T12:00:00Z',
          },
        ],
      },
      '/denuncias/moderacao' => {
        'denuncias': [
          {
            'id': 1,
            'motivo': 'Exemplo fictício',
            'status': 'aberta',
            'descricao': 'Relato de demonstração para conferir o layout.',
            'solicitacaoId': 1001,
          },
        ],
      },
      '/termos/atuais' => {
        'termos': {
          'versao': 'previa',
          'titulo': 'Termos — prévia visual',
          'resumo':
              'Conteúdo fictício. Consulte os termos reais na versão integrada.',
          'secoes': [
            {
              'titulo': 'Demonstração',
              'texto': 'Esta versão não salva nem envia dados para a API.',
            },
          ],
        },
      },
      '/termos/aceites/me' => {'aceites': [], 'aceitouVersaoAtual': false},
      _ => null,
    };
  }
}
