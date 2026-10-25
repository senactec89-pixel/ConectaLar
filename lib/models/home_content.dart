import 'categoria.dart';
import 'profissional.dart';

class HomeContent {
  const HomeContent({
    this.categories = const [],
    this.featuredProfessionals = const [],
    this.featuredProfessionalsTotal = 0,
    this.featuredProfessionalsHasMore = false,
    this.regionalAddressUnavailable = false,
    this.nearbySearchAvailable = false,
    this.categoriesLoadFailed = false,
    this.professionalsLoadFailed = false,
  });

  final List<Categoria> categories;
  final List<Profissional> featuredProfessionals;
  final int featuredProfessionalsTotal;
  final bool featuredProfessionalsHasMore;
  final bool regionalAddressUnavailable;
  final bool nearbySearchAvailable;
  final bool categoriesLoadFailed;
  final bool professionalsLoadFailed;
}
