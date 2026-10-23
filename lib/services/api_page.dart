class ApiPage<T> {
  const ApiPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  ApiPage<T> copyWith({List<T>? items}) {
    return ApiPage<T>(
      items: items ?? this.items,
      page: page,
      limit: limit,
      total: total,
      hasMore: hasMore,
    );
  }
}

ApiPage<T> apiPageFromResponse<T>(
  Map<String, dynamic> response, {
  required String itemsKey,
  required T Function(Map<String, dynamic>) mapper,
  int fallbackPage = 1,
}) {
  final rawItems = response[itemsKey];
  if (rawItems is! List) {
    throw FormatException('Lista "$itemsKey" ausente na resposta da API.');
  }
  final items = rawItems
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .toList(growable: false);
  final rawPagination = response['paginacao'];
  if (rawPagination is! Map) {
    return ApiPage<T>(
      items: items,
      page: fallbackPage,
      limit: items.length,
      total: items.length,
      hasMore: false,
    );
  }

  final pagination = Map<String, dynamic>.from(rawPagination);
  final page = _positiveInt(pagination['pagina']) ?? fallbackPage;
  final limit = _positiveInt(pagination['limite']) ?? items.length;
  final total = _nonNegativeInt(pagination['total']) ?? items.length;
  final totalPages = _positiveInt(pagination['totalPaginas']);
  final hasMore =
      pagination['temMais'] == true ||
      (totalPages != null && page < totalPages);
  return ApiPage<T>(
    items: items,
    page: page,
    limit: limit,
    total: total,
    hasMore: hasMore,
  );
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : null;
}
