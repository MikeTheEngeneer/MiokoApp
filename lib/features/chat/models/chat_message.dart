// Сообщение чата: GET /api/chats/<id>/messages → {messages: [...], page, generating}
class ChatMessage {
  // У сервера id — число строкой. Пока ответ не сохранён — временный 'u-…' / 'a-…'
  final String id;
  final bool fromUser;
  final String content;
  // Варианты ответа (после «Ответить заново») и какой выбран
  final List<String> variants;
  final int variant;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.content,
    this.variants = const [],
    this.variant = 0,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    final variants = meta is Map && meta['variants'] is List
        ? [for (final v in meta['variants'] as List) '$v']
        : const <String>[];
    final variant = meta is Map && meta['variant'] is num
        ? (meta['variant'] as num).toInt()
        : (variants.isEmpty ? 0 : variants.length - 1);
    return ChatMessage(
      id: '${json['id']}',
      fromUser: json['role'] == 'user',
      content: json['content'] as String? ?? '',
      variants: variants,
      variant: variant,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  // Сохранён ли на сервере (у временных id не число)
  bool get isSaved => int.tryParse(id) != null;

  ChatMessage copyWith({
    String? id,
    String? content,
    List<String>? variants,
    int? variant,
  }) => ChatMessage(
    id: id ?? this.id,
    fromUser: fromUser,
    content: content ?? this.content,
    variants: variants ?? this.variants,
    variant: variant ?? this.variant,
    createdAt: createdAt,
  );
}

class MessagesPage {
  final List<ChatMessage> messages;
  final bool hasMore;
  // Сервер ещё пишет ответ (например, чат открыли посреди генерации)
  final bool generating;

  const MessagesPage({
    required this.messages,
    required this.hasMore,
    required this.generating,
  });

  factory MessagesPage.fromJson(Map<String, dynamic> json) => MessagesPage(
    messages: [
      for (final m in (json['messages'] as List? ?? const []))
        ChatMessage.fromJson(m as Map<String, dynamic>),
    ],
    hasMore: (json['page'] as Map?)?['has_more'] == true,
    generating: json['generating'] == true,
  );
}

// GET /api/chats/tide-status — дневной лимит сообщений без M.Wave
class TideStatus {
  final bool wave;
  final int used;
  final int limit;
  final int warnAt;

  const TideStatus({
    required this.wave,
    required this.used,
    required this.limit,
    required this.warnAt,
  });

  factory TideStatus.fromJson(Map<String, dynamic> json) {
    int n(Object? v) => v is num ? v.toInt() : 0;
    return TideStatus(
      wave: json['wave'] == true,
      used: n(json['used']),
      limit: n(json['limit']),
      warnAt: n(json['warnAt']),
    );
  }

  int get left => (limit - used).clamp(0, limit);
  bool get showWarning => !wave && limit > 0 && used >= warnAt;
  bool get exhausted => !wave && limit > 0 && used >= limit;
}
