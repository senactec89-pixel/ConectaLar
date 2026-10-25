class Profissional {
  const Profissional({
    required this.id,
    required this.usuarioId,
    required this.nome,
    required this.descricao,
    required this.bairro,
    this.cidade,
    this.uf,
    this.raioAtendimentoKm = 15,
    this.latitudeAproximada,
    this.longitudeAproximada,
    this.distanciaKm,
    this.precoInicial,
    this.categoriaIds = const [],
    this.verificado = false,
    this.podeReceberSolicitacoes = false,
    this.habilitacaoInformada = false,
    this.fotoAsset,
    this.fotoUrl,
    this.notaMedia,
    this.quantidadeAvaliacoes,
    this.servicos = const [],
    this.ofertas = const [],
  });

  final int id;
  final int usuarioId;
  final String nome;
  final String descricao;
  final String bairro;
  final String? cidade;
  final String? uf;
  final int raioAtendimentoKm;
  final double? latitudeAproximada;
  final double? longitudeAproximada;
  final double? distanciaKm;
  final double? precoInicial;
  final List<int> categoriaIds;
  final String? fotoAsset;
  final String? fotoUrl;
  final double? notaMedia;
  final int? quantidadeAvaliacoes;
  final List<String> servicos;
  final List<OfertaProfissional> ofertas;

  List<OfertaProfissional> get ofertasParaSolicitacao {
    if (ofertas.isNotEmpty) return ofertas;
    final nomes = servicos.isEmpty ? [descricao] : servicos;
    return nomes
        .asMap()
        .entries
        .map(
          (e) => OfertaProfissional(
            id: -e.key - 1,
            nome: e.value,
            categoriaId: categoriaIds.isEmpty ? null : categoriaIds.first,
            precoInicial: precoInicial,
          ),
        )
        .toList(growable: false);
  }

  // Este valor é uma projeção da API baseada em documentos aprovados.
  final bool verificado;
  final bool podeReceberSolicitacoes;
  final bool habilitacaoInformada;
}

class OfertaProfissional {
  const OfertaProfissional({
    required this.id,
    required this.nome,
    this.categoriaId,
    this.precoInicial,
    this.duracaoMinutos = 60,
    this.intervaloMinutos = 30,
  });
  final int id;
  final String nome;
  final int? categoriaId;
  final double? precoInicial;
  final int duracaoMinutos;
  final int intervaloMinutos;
}
