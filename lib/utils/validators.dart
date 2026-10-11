String? validarCampoObrigatorio(String? valor) {
  if (valor == null || valor.trim().isEmpty) {
    return 'Este campo é obrigatório.';
  }
  return null;
}

String? validarEmail(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;

  final email = valor!.trim();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validarSenha(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;
  if (valor!.length < 8) return 'A senha deve ter pelo menos 8 caracteres.';
  return null;
}

double? parsePrecoInicial(String valor) {
  final preco = double.tryParse(valor.trim().replaceAll(',', '.'));
  return preco != null && preco.isFinite && preco >= 0 && preco <= 99999999.99
      ? preco
      : null;
}

String? validarPrecoOpcional(String? valor) {
  if ((valor ?? '').trim().isEmpty) return null;
  return parsePrecoInicial(valor!) == null
      ? 'Informe um valor entre 0 e 99.999.999,99.'
      : null;
}
