import 'categoria.dart';
import 'profissional.dart';

enum CampoBuscaInicial { servico, bairro }

/// Estado temporário da interface; não é persistido no aparelho.
class BuscaEstado {
  String termo = '';
  String bairro = '';
  String cidade = '';
  Categoria? categoria;
  bool localizacaoExpandida = false;
  double? latitude;
  double? longitude;
  double? precisaoMetros;
  int raioKm = 25;
  bool mostrarMapa = false;
  List<Profissional> comparacao = [];
  double rolagem = 0;
  int revisao = 0;

  void limpar() {
    termo = bairro = cidade = '';
    categoria = null;
    localizacaoExpandida = false;
    latitude = longitude = precisaoMetros = null;
    raioKm = 25;
    mostrarMapa = false;
    comparacao = [];
    rolagem = 0;
    revisao++;
  }
}
