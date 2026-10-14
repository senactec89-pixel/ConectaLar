import 'categoria.dart';
import 'profissional.dart';

class HomeContent {
  const HomeContent({
    this.categories = const [],
    this.featuredProfessionals = const [],
    this.categoriesLoadFailed = false,
    this.professionalsLoadFailed = false,
  });

  final List<Categoria> categories;
  final List<Profissional> featuredProfessionals;
  final bool categoriesLoadFailed;
  final bool professionalsLoadFailed;
}
