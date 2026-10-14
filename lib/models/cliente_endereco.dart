class ClienteEndereco {
  const ClienteEndereco({
    required this.id,
    required this.apelido,
    required this.logradouro,
    required this.numero,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.cep,
    this.latitude,
    this.longitude,
    this.complemento,
    this.principal = false,
  });

  final int id;
  final String apelido;
  final String? cep;
  final double? latitude;
  final double? longitude;
  final String logradouro;
  final String numero;
  final String? complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final bool principal;

  String get resumo => '$bairro, $cidade/$uf';
  String get completo {
    final extra = complemento == null ? '' : ' - $complemento';
    return '$logradouro, $numero$extra - $bairro, $cidade/$uf';
  }
}
