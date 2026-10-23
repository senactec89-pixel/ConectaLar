import 'categoria.dart';

enum CampoBuscaInicial { servico, bairro }

/// Estado temporário da interface; não é persistido no aparelho.
class BuscaEstado {
  String termo = '';
  String bairro = '';
  String cidade = '';
  Categoria? categoria;
  bool localizacaoExpandida = false;
  double rolagem = 0;
  int revisao = 0;

  void limpar() {
    termo = bairro = cidade = '';
    categoria = null;
    localizacaoExpandida = false;
    rolagem = 0;
    revisao++;
  }
}
