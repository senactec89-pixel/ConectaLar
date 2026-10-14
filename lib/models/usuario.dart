enum TipoUsuario {
  cliente('cliente'),
  profissional('profissional'),
  empresa('empresa'),
  administrador('administrador');

  const TipoUsuario(this.valorBanco);

  final String valorBanco;
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipo,
    this.telefone,
    this.bairro,
    this.fotoPerfilUrl,
  });

  final int id;
  final String nome;
  final String email;
  final TipoUsuario tipo;
  final String? telefone;
  final String? bairro;
  final String? fotoPerfilUrl;
}
