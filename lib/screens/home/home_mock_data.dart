import '../../models/categoria.dart';
import '../../models/home_content.dart';
import '../../models/profissional.dart';

abstract final class HomeMockData {
  static const content = HomeContent(
    categories: [
      Categoria(id: 1, nome: 'Elétrica', icone: 'electrical_services'),
      Categoria(id: 2, nome: 'Hidráulica', icone: 'plumbing'),
      Categoria(id: 3, nome: 'Pintura', icone: 'format_paint'),
      Categoria(id: 4, nome: 'Limpeza', icone: 'cleaning_services'),
      Categoria(id: 5, nome: 'Manutenção', icone: 'build'),
      Categoria(id: 6, nome: 'Ar-condicionado', icone: 'ac_unit'),
      Categoria(id: 7, nome: 'Reformas', icone: 'construction'),
      Categoria(id: 8, nome: 'Outros', icone: 'category'),
    ],
    featuredProfessionals: [
      Profissional(
        id: 1,
        usuarioId: 101,
        nome: 'Carlos Silva',
        descricao: 'Eletricista residencial',
        bairro: 'Jardim das Flores',
        cidade: 'Belo Horizonte',
        uf: 'MG',
        precoInicial: 80,
        categoriaIds: [1, 5],
        verificado: true,
        fotoAsset: 'assets/images/home/professional_carlos.png',
        notaMedia: 4.8,
        quantidadeAvaliacoes: 120,
        servicos: ['Elétrica', 'Manutenção'],
      ),
      Profissional(
        id: 2,
        usuarioId: 102,
        nome: 'Ana Souza',
        descricao: 'Limpeza e organização residencial',
        bairro: 'Vila Nova',
        cidade: 'Belo Horizonte',
        uf: 'MG',
        precoInicial: 70,
        categoriaIds: [4],
        verificado: true,
        fotoAsset: 'assets/images/home/professional_ana.png',
        notaMedia: 4.9,
        quantidadeAvaliacoes: 98,
        servicos: ['Limpeza', 'Organização'],
      ),
    ],
    nearbySearchAvailable: true,
  );
}
