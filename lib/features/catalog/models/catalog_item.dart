import '../../../shared/models/media_avatar.dart';

class CatalogItem {
  final String itemType; // "character" or "story"
  final String id;
  final String? publicId;
  final String name;
  final String? subtitle;
  final String? description;
  final String? personality;
  final String? firstMeeting;
  final String? appearance;
  final String? backstory;
  final List<String> tags;
  final int interactionsCount;
  final int likesCount;
  final int collectionsCount;
  final MediaAvatar avatar;
  final String? slug;
  // Автор приходит только в запросе одного элемента, в каталоге его нет
  final String? authorName;
  final String? authorUsername;
  final String? authorAvatar;

  const CatalogItem({
    required this.itemType,
    required this.id,
    this.publicId,
    required this.name,
    this.subtitle,
    this.description,
    this.personality,
    this.firstMeeting,
    this.appearance,
    this.backstory,
    this.tags = const [],
    this.interactionsCount = 0,
    this.likesCount = 0,
    this.collectionsCount = 0,
    required this.avatar,
    this.slug,
    this.authorName,
    this.authorUsername,
    this.authorAvatar,
  });

  bool get isStory => itemType == 'story';

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    itemType:
        json['item_type'] as String? ??
        (json['title'] != null && json['name'] == null ? 'story' : 'character'),
    id: json['id'] as String,
    publicId: json['public_id'] as String?,
    // у историй имя приходит в title
    name: ((json['name'] ?? json['title']) as String? ?? '').trim(),
    subtitle: _text(json['subtitle']),
    description: _text(json['description']),
    personality: _text(json['personality']),
    firstMeeting: _text(json['first_meeting']),
    appearance: _text(json['appearance']),
    backstory: _text(json['backstory']),
    tags: _tags(json['tags']),
    interactionsCount: _int(json['interactions_count']),
    likesCount: _int(json['likes_count']),
    collectionsCount: _int(json['collections_count']),
    avatar: MediaAvatar.fromJson(json['avatar'] as Map<String, dynamic>?),
    slug: json['slug'] as String?,
    authorName: _text(json['author_name']),
    authorUsername: _text(json['author_username']),
    authorAvatar: _text(json['author_avatar']),
  );

  static String? _text(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  // Счётчики приходят то числом, то строкой ("15"), то null
  static int _int(Object? v) => switch (v) {
    int n => n,
    String s => int.tryParse(s) ?? 0,
    _ => 0,
  };

  static List<String> _tags(Object? v) {
    if (v is! Map) return const [];
    return [
      for (final group in const ['genre_theme', 'mood', 'setting'])
        ...((v[group] as List?)?.whereType<String>() ?? const <String>[]),
    ];
  }
}

class CatalogAuthor {
  final String id;
  final String username;
  final String name;
  final String? avatarUrl;
  final int works;
  final int interactions;
  final bool verified;

  const CatalogAuthor({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
    required this.works,
    required this.interactions,
    required this.verified,
  });

  factory CatalogAuthor.fromJson(Map<String, dynamic> json) => CatalogAuthor(
    id: json['id'] as String,
    username: json['username'] as String,
    name: (json['name'] as String? ?? '').trim(),
    avatarUrl: json['avatar_url'] as String?,
    works: json['works'] as int? ?? 0,
    interactions: json['interactions'] as int? ?? 0,
    verified: json['verified'] as bool? ?? false,
  );
}
