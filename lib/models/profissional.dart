class Profissional {
  const Profissional({
    required this.id,
    required this.usuarioId,
    required this.nome,
    required this.descricao,
    required this.bairro,
    this.precoInicial,
    this.categoriaIds = const [],
    this.verificado = false,
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
}

class OfertaProfissional {
  const OfertaProfissional({
    required this.id,
    required this.nome,
    this.categoriaId,
    this.precoInicial,
  });
  final int id;
  final String nome;
  final int? categoriaId;
  final double? precoInicial;
}
