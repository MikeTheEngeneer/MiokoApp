import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/catalog_item.dart';

enum CatalogSort { hot, new_ }

// Ленты главной: «Популярное» (sort=hot) и «Новинки» (sort=new), как на сайте
final catalogFeedProvider =
    FutureProvider.family<List<CatalogItem>, CatalogSort>((ref, sort) async {
      final dio = ref.read(apiClientProvider);
      final resp = await dio.get(
        '/api/catalog',
        queryParameters: {
          'sort': sort == CatalogSort.hot ? 'hot' : 'new',
          'limit': 15,
        },
      );
      final List<dynamic> items = resp.data['items'] as List<dynamic>;
      return items
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// Жанры и их порядок — как зашито в коде сайта
const catalogGenres = [
  'Аниме',
  'Фэнтези',
  'Романтика',
  'Драма',
  'Приключения',
  'Мистика и паранормальное',
];

String randomSeed() {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  final r = Random.secure();
  return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
}

// seed задаёт перемешивание карточек: один и тот же seed — одна и та же выдача.
// Сбрасывается вместе с секциями при обновлении свайпом
final catalogSeedProvider = Provider<String>((ref) => randomSeed());

final catalogSectionsProvider = FutureProvider<Map<String, List<CatalogItem>>>((
  ref,
) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get(
    '/api/catalog/sections',
    queryParameters: {
      'genres': catalogGenres.join(','),
      'limit': 15,
      'seed': ref.watch(catalogSeedProvider),
    },
  );
  final raw = resp.data['sections'] as Map<String, dynamic>;
  return raw.map((key, value) {
    final items = (value as List<dynamic>)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return MapEntry(key, items);
  });
});

// autoDispose: при каждом открытии страницы данные запрашиваются заново
final itemDetailProvider = FutureProvider.autoDispose
    .family<CatalogItem, ({bool isStory, String id})>((ref, key) async {
      final dio = ref.read(apiClientProvider);
      final kind = key.isStory ? 'story' : 'character';
      final resp = await dio.get(
        '/api/${key.isStory ? 'stories' : 'characters'}/${key.id}',
      );
      final json = Map<String, dynamic>.from(resp.data[kind] as Map);
      return CatalogItem.fromJson({...json, 'item_type': kind});
    });

final catalogAuthorsProvider = FutureProvider<List<CatalogAuthor>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/catalog/authors');
  final List<dynamic> authors = resp.data['authors'] as List<dynamic>;
  return authors
      .map((e) => CatalogAuthor.fromJson(e as Map<String, dynamic>))
      .toList();
});
