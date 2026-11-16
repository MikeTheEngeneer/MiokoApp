// Лорбук — справочник о мире: персонаж узнаёт о месте или герое,
// когда о нём заговорят в чате

int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

// Строка списка: поиск опубликованных, «мои», подключённые к месту
class LorebookSummary {
  final String publicId;
  final String title;
  final String? coverUrl;
  final bool isPublic;
  final bool entriesHidden;
  final int entriesCount;
  final String? authorUsername;
  final bool authorVerified;

  const LorebookSummary({
    required this.publicId,
    required this.title,
    this.coverUrl,
    required this.isPublic,
    required this.entriesHidden,
    required this.entriesCount,
    this.authorUsername,
    required this.authorVerified,
  });

  factory LorebookSummary.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    // В поиске число записей — entriesCount, в «моих» — entries
    final entries = json['entriesCount'] ?? json['entries'];
    return LorebookSummary(
      publicId: json['public_id'] as String,
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      entriesHidden: json['entries_hidden'] as bool? ?? false,
      entriesCount: entries is List ? entries.length : _int(entries),
      authorUsername: author is Map ? author['username'] as String? : null,
      authorVerified: author is Map && author['verified'] == true,
    );
  }
}

List<LorebookSummary> _summaries(Object? list) => [
  for (final e in (list as List<dynamic>? ?? const []))
    LorebookSummary.fromJson(e as Map<String, dynamic>),
];

// GET /api/lorebooks/mine — свои лорбуки и сколько их можно создать
class MyLorebooks {
  final List<LorebookSummary> lorebooks;
  final int limit;

  const MyLorebooks({required this.lorebooks, required this.limit});

  factory MyLorebooks.fromJson(Map<String, dynamic> json) => MyLorebooks(
    lorebooks: _summaries(json['lorebooks']),
    limit: _int((json['limits'] as Map?)?['lorebooks']),
  );
}

// GET /api/lorebooks/places/<kind>/<id> — что подключено к месту (персона, «все мои чаты»)
class PlaceLorebooks {
  final List<LorebookSummary> lorebooks;
  final int limit;

  const PlaceLorebooks({required this.lorebooks, required this.limit});

  factory PlaceLorebooks.fromJson(Map<String, dynamic> json) => PlaceLorebooks(
    lorebooks: _summaries(json['lorebooks']),
    limit: _int(json['limit']),
  );

  bool get isFull => lorebooks.length >= limit;
  bool has(String publicId) => lorebooks.any((l) => l.publicId == publicId);
}

// GET /api/lorebooks/public?q=…&before=… — страница поиска
class LorebookPage {
  final List<LorebookSummary> lorebooks;
  final String? next;

  const LorebookPage({required this.lorebooks, this.next});

  factory LorebookPage.fromJson(Map<String, dynamic> json) => LorebookPage(
    lorebooks: _summaries(json['lorebooks']),
    next: json['next']?.toString(),
  );
}

enum LoreEntryKind { keys, always, semantic }

class LoreEntry {
  final String title;
  final List<String> keys;
  final String body;
  final LoreEntryKind kind;
  // Только для своих лорбуков: запись выключена автором
  final bool disabled;

  const LoreEntry({
    required this.title,
    required this.keys,
    required this.body,
    required this.kind,
    required this.disabled,
  });

  factory LoreEntry.fromJson(Map<String, dynamic> json) => LoreEntry(
    title: json['title'] as String? ?? '',
    keys: [for (final k in (json['keys'] as List? ?? const [])) '$k'],
    body: json['body'] as String? ?? '',
    kind: switch (json['kind']) {
      'always' => LoreEntryKind.always,
      'semantic' => LoreEntryKind.semantic,
      _ => LoreEntryKind.keys,
    },
    disabled: json['enabled'] == false,
  );
}

// Карточка (персонаж или история), где работает лорбук
class LoreCard {
  final String publicId;
  final String title;
  final bool isStory;
  final bool isPublic;

  const LoreCard({
    required this.publicId,
    required this.title,
    required this.isStory,
    required this.isPublic,
  });

  factory LoreCard.fromJson(Map<String, dynamic> json) => LoreCard(
    publicId: json['public_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    isStory: json['kind'] == 'story',
    isPublic: json['is_public'] as bool? ?? false,
  );
}

// GET /api/lorebooks/<id> — лорбук целиком
class LorebookDetail {
  final LorebookSummary summary;
  final String description;
  // Теги по группам сайта: genre_theme, setting, mood
  final List<String> tags;
  final List<LoreEntry> entries;
  final bool own;
  final List<LoreCard> cards;

  const LorebookDetail({
    required this.summary,
    required this.description,
    required this.tags,
    required this.entries,
    required this.own,
    required this.cards,
  });

  factory LorebookDetail.fromJson(Map<String, dynamic> json) {
    final lb = json['lorebook'] as Map<String, dynamic>;
    final tags = lb['tags'];
    return LorebookDetail(
      summary: LorebookSummary.fromJson(lb),
      description: lb['description'] as String? ?? '',
      tags: [
        // Порядок групп как на сайте
        for (final g in const ['genre_theme', 'setting', 'mood'])
          if (tags is Map && tags[g] is List)
            for (final t in tags[g] as List) '$t',
      ],
      entries: [
        for (final e in (lb['entries'] as List? ?? const []))
          LoreEntry.fromJson(e as Map<String, dynamic>),
      ],
      own: json['own'] as bool? ?? false,
      cards: [
        for (final c in (json['cards'] as List? ?? const []))
          LoreCard.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

// GET /api/lorebooks/<id>/targets — куда этот лорбук можно подключить
class MineTarget {
  final bool connected;
  final int count;
  final int limit;

  const MineTarget({
    required this.connected,
    required this.count,
    required this.limit,
  });

  bool get isFull => !connected && count >= limit;
}

class PersonaTarget {
  final String publicId;
  final String name;
  final String? avatarUrl;
  final bool connected;
  // Сколько лорбуков у персоны сейчас (максимум один: новый заменит прежний)
  final int count;

  const PersonaTarget({
    required this.publicId,
    required this.name,
    this.avatarUrl,
    required this.connected,
    required this.count,
  });
}

class LorebookTargets {
  final MineTarget? mine;
  final List<PersonaTarget> personas;

  const LorebookTargets({this.mine, required this.personas});

  // Те же места в виде (kind, id) для запроса отключения
  List<(String, String)> get connectedPlaces => [
    if (mine?.connected ?? false) ('mine', 'me'),
    for (final p in personas)
      if (p.connected) ('persona', p.publicId),
  ];

  // Куда подключён: «все чаты» и имена персон
  List<String> get connectedTo => [
    if (mine?.connected ?? false) 'все чаты',
    for (final p in personas)
      if (p.connected) p.name.isEmpty ? 'персона' : p.name,
  ];

  factory LorebookTargets.fromJson(Map<String, dynamic> json) {
    final mine = json['mine'];
    return LorebookTargets(
      mine: mine is Map
          ? MineTarget(
              connected: mine['connected'] == true,
              count: _int(mine['count']),
              limit: _int(mine['limit']),
            )
          : null,
      personas: [
        for (final p in (json['personas'] as List? ?? const []))
          if (p is Map)
            PersonaTarget(
              publicId: '${p['public_id']}',
              name: p['name'] as String? ?? '',
              avatarUrl: p['avatar_url'] as String?,
              connected: p['connected'] == true,
              count: _int(p['count']),
            ),
      ],
    );
  }
}

// «87 записей», «1 запись», «3 записи»
String entriesLabel(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'запись'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'записи'
      : 'записей';
  return '$n $word';
}
