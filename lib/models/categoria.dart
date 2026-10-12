class Categoria {
  const Categoria({
    required this.id,
    required this.nome,
    this.descricao,
    this.icone = 'home_repair',
    this.ativa = true,
  });

  final int id;
  final String nome;
  final String? descricao;
  final String icone;
  final bool ativa;
}
