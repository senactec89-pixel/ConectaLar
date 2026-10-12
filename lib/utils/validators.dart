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
  if (!RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$',
  ).hasMatch(email)) {
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

String? validarSenhaForte(String? valor) {
  final erro = validarSenha(valor);
  if (erro != null) return erro;
  final senha = valor!;
  final forte =
      RegExp(r'[A-Z]').hasMatch(senha) &&
      RegExp(r'[a-z]').hasMatch(senha) &&
      RegExp(r'\d').hasMatch(senha) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(senha);
  return forte
      ? null
      : 'Use maiuscula, minuscula, numero e caractere especial.';
}

String? validarCepOpcional(String? valor) {
  final texto = (valor ?? '').trim();
  if (texto.isEmpty) return null;
  final digitos = texto.replaceAll(RegExp(r'\D'), '');
  return digitos.length == 8 ? null : 'Informe um CEP com 8 digitos.';
}

String? validarUf(String? valor) {
  final erroObrigatorio = validarCampoObrigatorio(valor);
  if (erroObrigatorio != null) return erroObrigatorio;
  return RegExp(r'^[A-Za-z]{2}$').hasMatch(valor!.trim())
      ? null
      : 'Informe a UF com 2 letras.';
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
