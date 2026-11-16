import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../catalog/models/catalog_item.dart';
import '../models/user.dart';
import '../../pearls/models/billing.dart';

final profileProvider = FutureProvider<User>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/auth/me', queryParameters: {'lite': '1'});
  return User.fromJson(resp.data['user'] as Map<String, dynamic>);
});

class ProfileStats {
  final int followers;
  final int following;
  final int interactions;

  const ProfileStats({
    required this.followers,
    required this.following,
    required this.interactions,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
    followers: json['followers'] as int? ?? 0,
    following: json['following'] as int? ?? 0,
    interactions: json['interactions'] as int? ?? 0,
  );
}

// Мой публичный профиль автора: GET /api/authors/<id>
// → {author, characters, stories, stats}. Отсюда — статистика и вкладки
// «Персонажи»/«Истории» (как на сайте). autoDispose — свежий при каждом заходе
class MyWorks {
  final List<CatalogItem> characters;
  final List<CatalogItem> stories;
  final ProfileStats stats;

  const MyWorks({
    required this.characters,
    required this.stories,
    required this.stats,
  });
}

// Сервер не пишет item_type в этих списках — подставляем сами
List<CatalogItem> _items(Object? list, String type) => [
  for (final e in (list as List? ?? const []))
    CatalogItem.fromJson({...(e as Map<String, dynamic>), 'item_type': type}),
];

final myWorksProvider = FutureProvider.autoDispose<MyWorks>((ref) async {
  final user = await ref.watch(profileProvider.future);
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/authors/${user.id}');
  final data = resp.data as Map<String, dynamic>;
  return MyWorks(
    characters: _items(data['characters'], 'character'),
    stories: _items(data['stories'], 'story'),
    stats: ProfileStats.fromJson(
      data['stats'] as Map<String, dynamic>? ?? const {},
    ),
  );
});

final profileStatsProvider = FutureProvider.autoDispose<ProfileStats>(
  (ref) async => (await ref.watch(myWorksProvider.future)).stats,
);

// Вкладка «Коллекции»: GET /api/favorites → {characters, stories},
// у каждого fav_at. Сайт смешивает оба списка, свежие сверху
final favoritesProvider = FutureProvider.autoDispose<List<CatalogItem>>((
  ref,
) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/favorites');
  final data = resp.data as Map<String, dynamic>;
  final all = <(DateTime?, int, CatalogItem)>[];
  var i = 0;
  for (final (key, type) in const [
    ('characters', 'character'),
    ('stories', 'story'),
  ]) {
    for (final e in (data[key] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      all.add((
        DateTime.tryParse('${m['fav_at']}'),
        i++,
        CatalogItem.fromJson({...m, 'item_type': type}),
      ));
    }
  }
  // Без даты — в конец, при равенстве — исходный порядок
  all.sort((a, b) {
    final (ta, ia, _) = a;
    final (tb, ib, _) = b;
    if (ta == null || tb == null) {
      if (ta == null && tb == null) return ia - ib;
      return ta == null ? 1 : -1;
    }
    final c = tb.compareTo(ta);
    return c != 0 ? c : ia - ib;
  });
  return [for (final (_, _, item) in all) item];
});

// Вкладка «Подарки»: GET /api/gifts/received/<id>[?before=…] → {total, next, gifts}
class ReceivedGift {
  final int id;
  final String name;
  final String emoji;
  // Картинка: https://mioko.ai/gifts/shelf/<file>.webp
  final String file;
  final int price;
  final DateTime? createdAt;
  // Отправитель скрыл имя — показываем «Аноним»
  final bool hidden;
  final String? senderName;
  final String? senderUsername;
  final String? senderAvatar;

  const ReceivedGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.file,
    required this.price,
    this.createdAt,
    required this.hidden,
    this.senderName,
    this.senderUsername,
    this.senderAvatar,
  });

  String get imageUrl => 'https://mioko.ai/gifts/shelf/$file.webp';

  factory ReceivedGift.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ReceivedGift(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      file: json['file'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      hidden: json['hidden'] == true,
      senderName: sender?['name'] as String?,
      senderUsername: sender?['username'] as String?,
      senderAvatar: sender?['avatar_url'] as String?,
    );
  }
}

class GiftsPage {
  final int total;
  final List<ReceivedGift> gifts;
  // Курсор следующей страницы (null — больше нет)
  final String? next;

  const GiftsPage({required this.total, required this.gifts, this.next});
}

final receivedGiftsProvider = FutureProvider.autoDispose<GiftsPage>((
  ref,
) async {
  final user = await ref.watch(profileProvider.future);
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/gifts/received/${user.id}');
  final data = resp.data as Map<String, dynamic>;
  return GiftsPage(
    total: (data['total'] as num?)?.toInt() ?? 0,
    gifts: [
      for (final g in (data['gifts'] as List? ?? const []))
        ReceivedGift.fromJson(g as Map<String, dynamic>),
    ],
    next: data['next']?.toString(),
  );
});

// Данные подписки и жемчужин
class PaymentInfo {
  final int pearls;
  final DateTime? waveUntil;

  const PaymentInfo({required this.pearls, this.waveUntil});

  bool get hasWave => waveUntil != null && waveUntil!.isAfter(DateTime.now());

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    pearls: json['pearls'] as int? ?? 0,
    waveUntil: json['wave_until'] != null
        ? DateTime.parse(json['wave_until'] as String)
        : null,
  );
}

final billingConfigProvider = FutureProvider<BillingConfig>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/payments/config');
  return BillingConfig.fromJson(resp.data as Map<String, dynamic>);
});

final paymentProvider = FutureProvider<PaymentInfo>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/payments/me');
  return PaymentInfo.fromJson(resp.data as Map<String, dynamic>);
});
