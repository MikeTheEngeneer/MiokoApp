import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_provider.dart';

class SearchState {
  final String query;
  final List<CatalogItem> items;
  final int? total;
  final String? cursor;
  final bool loading;
  // Сама ошибка, а не текст: экран сам решит, «нет интернета» это или другое
  final Object? error;

  const SearchState({
    this.query = '',
    this.items = const [],
    this.total,
    this.cursor,
    this.loading = false,
    this.error,
  });

  bool get hasMore => cursor != null;

  SearchState copyWith({
    List<CatalogItem>? items,
    String? cursor,
    bool clearCursor = false,
    bool? loading,
    Object? error,
  }) => SearchState(
    query: query,
    items: items ?? this.items,
    total: total,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    loading: loading ?? false,
    error: error,
  );
}

// Поиск как на сайте: /api/catalog?sort=random&seed=…&q=…, страницы — через cursor
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  static const _pageSize = 24;
  String _seed = '';
  // Ответ на устаревший запрос (пользователь уже напечатал дальше) отбрасываем
  int _generation = 0;

  Dio get _dio => _ref.read(apiClientProvider);

  Map<String, Object> _params(String q) => {
    'q': q,
    'sort': 'random',
    'seed': _seed,
    'limit': _pageSize,
  };

  Future<void> search(String query) async {
    final q = query.trim();
    final gen = ++_generation;
    if (q.isEmpty) {
      state = const SearchState();
      return;
    }
    _seed = randomSeed();
    state = SearchState(query: q, loading: true);

    try {
      final [page, facets] = await Future.wait([
        _dio.get('/api/catalog', queryParameters: _params(q)),
        _dio.get('/api/catalog/facets', queryParameters: {'q': q}),
      ]);
      if (gen != _generation) return;
      state = SearchState(
        query: q,
        items: _parse(page.data),
        cursor: page.data['nextCursor'] as String?,
        total: facets.data['total'] as int?,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = SearchState(query: q, error: e);
    }
  }

  // После ошибки прокрутка не перезапрашивает страницу сама — только кнопкой (retry)
  Future<void> loadMore({bool retry = false}) async {
    final s = state;
    if (s.loading || !s.hasMore || s.query.isEmpty) return;
    if (s.error != null && !retry) return;
    final gen = _generation;
    state = s.copyWith(loading: true);

    try {
      final page = await _dio.get(
        '/api/catalog',
        queryParameters: {..._params(s.query), 'cursor': s.cursor!},
      );
      if (gen != _generation) return;
      final next = page.data['nextCursor'] as String?;
      state = s.copyWith(
        items: [...s.items, ..._parse(page.data)],
        cursor: next,
        clearCursor: next == null,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = s.copyWith(error: e);
    }
  }

  static List<CatalogItem> _parse(dynamic data) => (data['items'] as List)
      .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>(
      (ref) => SearchNotifier(ref),
    );
