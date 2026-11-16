import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';
import 'chat_stream.dart';
import 'chats_provider.dart';

class ChatRoomState {
  // По порядку: старые → новые
  final List<ChatMessage> messages;
  final bool loading;
  final Object? error;
  final bool hasMore;
  final bool loadingOlder;
  // Идёт ответ персонажа (поток открыт)
  final bool generating;
  // Ответ уже идёт, но ни одной буквы ещё нет — показываем «печатает…»
  final bool waiting;
  final TideStatus? tide;

  const ChatRoomState({
    this.messages = const [],
    this.loading = true,
    this.error,
    this.hasMore = false,
    this.loadingOlder = false,
    this.generating = false,
    this.waiting = false,
    this.tide,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? hasMore,
    bool? loadingOlder,
    bool? generating,
    bool? waiting,
    TideStatus? tide,
  }) => ChatRoomState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    hasMore: hasMore ?? this.hasMore,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    generating: generating ?? this.generating,
    waiting: waiting ?? this.waiting,
    tide: tide ?? this.tide,
  );

  // Можно ли «ответить заново»: последнее сообщение — сохранённый ответ персонажа
  bool get canRegenerate =>
      !generating &&
      messages.isNotEmpty &&
      !messages.last.fromUser &&
      messages.last.isSaved &&
      messages.length > 1;

  // Первое сообщение персонажа (приветствие) — его сайт удалять не даёт.
  // Пока не догрузили начало чата, первым его не считаем.
  String? get firstAssistantId => hasMore
      ? null
      : messages.where((m) => !m.fromUser).firstOrNull?.id;
}

// Что показать пользователю после действия (тост на экране)
typedef ChatNotice = void Function(String text, {bool tideLimit});

class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  ChatRoomNotifier(this._ref, this.chatId) : super(const ChatRoomState()) {
    load();
  }

  final Ref _ref;
  final String chatId;
  StreamSubscription<StreamEvent>? _sub;
  // Кто показывает тосты — экран подставляет себя
  ChatNotice? onNotice;

  Dio get _dio => _ref.read(apiClientProvider);
  String get _base => '/api/chats/$chatId';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<MessagesPage> _fetch({String? before}) async {
    final resp = await _dio.get(
      '$_base/messages',
      queryParameters: {'limit': 50, 'before': ?before},
    );
    return MessagesPage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _fetch();
      if (!mounted) return;
      state = state.copyWith(
        messages: page.messages,
        hasMore: page.hasMore,
        loading: false,
        clearError: true,
      );
      // Чат открыли посреди ответа — подключаемся к потоку
      if (page.generating && !state.generating) _subscribe();
    } catch (e) {
      if (!mounted) return;
      if (quiet) return;
      state = state.copyWith(loading: false, error: e);
    }
    unawaited(refreshTide());
  }

  Future<void> refreshTide() async {
    try {
      final resp = await _dio.get('/api/chats/tide-status');
      if (!mounted) return;
      state = state.copyWith(
        tide: TideStatus.fromJson(resp.data as Map<String, dynamic>),
      );
    } catch (_) {
      // Счётчик лимита не главное — без него экран работает
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore || state.loadingOlder || state.messages.isEmpty) return;
    final oldest = state.messages.firstWhere(
      (m) => m.isSaved,
      orElse: () => state.messages.first,
    );
    if (!oldest.isSaved) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _fetch(before: oldest.id);
      if (!mounted) return;
      final have = state.messages.map((m) => m.id).toSet();
      state = state.copyWith(
        messages: [
          ...page.messages.where((m) => !have.contains(m.id)),
          ...state.messages,
        ],
        hasMore: page.hasMore,
        loadingOlder: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  // ── Отправка и потоки ────────────────────────────────────────────

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.generating) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final userId = 'u-$stamp', botId = 'a-$stamp';
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(id: userId, fromUser: true, content: content),
        ChatMessage(id: botId, fromUser: false, content: ''),
      ],
    );
    await _run(
      openEventStream(_dio, '$_base/messages', data: {'content': content}),
      botId: botId,
      userId: userId,
      // Отказ до начала ответа: сообщение не принято — убираем обе заготовки
      onDenied: () => _drop({userId, botId}),
    );
  }

  Future<void> regenerate() async {
    if (!state.canRegenerate) return;
    final last = state.messages.last;
    _update(last.id, (m) => m.copyWith(content: ''));
    await _run(
      openEventStream(_dio, '$_base/regenerate', data: const {}),
      botId: last.id,
      onDenied: () => _update(last.id, (_) => last),
    );
  }

  void _subscribe() {
    final bot = state.messages.lastWhere(
      (m) => !m.fromUser,
      orElse: () => const ChatMessage(id: '', fromUser: false, content: ''),
    );
    if (bot.id.isEmpty) return;
    _run(
      openEventStream(_dio, '$_base/stream', method: 'GET'),
      botId: bot.id,
      onDenied: () {},
    );
  }

  Future<void> _run(
    Stream<StreamEvent> stream, {
    required String botId,
    String? userId,
    required void Function() onDenied,
  }) async {
    state = state.copyWith(generating: true, waiting: true);
    var current = botId;
    final done = Completer<void>();

    _sub = stream.listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case DeltaEvent(:final text):
            _update(current, (m) => m.copyWith(content: m.content + text));
            state = state.copyWith(waiting: false);
          case ReplaceEvent(:final text):
            _update(current, (m) => m.copyWith(content: text));
            if (text.isNotEmpty) state = state.copyWith(waiting: false);
          case IdsEvent(:final user, :final assistant):
            if (userId != null && user != null) {
              _update(userId, (m) => m.copyWith(id: user));
            }
            if (assistant != null) {
              _update(current, (m) => m.copyWith(id: assistant));
              current = assistant;
            }
          case ErrorEvent(:final message):
            // «Дождитесь…» — ответ ещё пишется; перечитаем чат после потока
            if (!RegExp('дождитесь', caseSensitive: false).hasMatch(message)) {
              _update(
                current,
                (m) =>
                    m.content.isEmpty ? m.copyWith(content: '⚠️ $message') : m,
              );
            }
          case DoneEvent():
            break;
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        if (e is StreamDenied) {
          onDenied();
          onNotice?.call(
            e.isTideLimit
                ? 'Сообщения на сегодня закончились. С M.Wave — без дневных лимитов'
                : e.message,
            tideLimit: e.isTideLimit,
          );
        } else {
          onNotice?.call('Связь прервалась — проверь интернет');
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    await done.future;
    _sub = null;
    if (!mounted) return;
    state = state.copyWith(generating: false, waiting: false);
    // Перечитываем, чтобы получить настоящие id и варианты ответа
    await load(quiet: true);
    _ref.invalidate(chatsProvider);
  }

  // ── Варианты ответа ──────────────────────────────────────────────

  Future<void> pickVariant(int index) async {
    final last = state.messages.isEmpty ? null : state.messages.last;
    if (last == null ||
        last.fromUser ||
        state.generating ||
        index < 0 ||
        index >= last.variants.length) {
      return;
    }
    _update(
      last.id,
      (m) => m.copyWith(content: m.variants[index], variant: index),
    );
    try {
      await _dio.post(
        '$_base/messages/${last.id}/variant',
        queryParameters: {'from': last.id},
        data: {'index': index},
      );
      _ref.invalidate(chatsProvider);
    } catch (_) {
      onNotice?.call('Не удалось переключить вариант');
      await load(quiet: true);
    }
  }

  // ── Действия с сообщением (меню по долгому нажатию) ─────────────
  // Пути и тела — из бандла сайта; `from` = id сообщения, с которого
  // сервер присылает свежий кусок переписки. Мы просто перечитываем чат.

  // PATCH …/messages/<id>?from=<id> {content}
  Future<void> editMessage(String id, String content) async {
    final old = state.messages.where((m) => m.id == id).firstOrNull;
    _update(id, (m) => m.copyWith(content: content));
    try {
      await _dio.patch(
        '$_base/messages/$id',
        queryParameters: {'from': id},
        data: {'content': content},
      );
      _ref.invalidate(chatsProvider);
    } catch (e) {
      if (old != null) _update(id, (_) => old);
      rethrow;
    } finally {
      await load(quiet: true);
    }
  }

  // DELETE …/messages/<id>?from=<id>
  Future<void> deleteMessage(String id) async {
    await _dio.delete('$_base/messages/$id', queryParameters: {'from': id});
    _drop({id});
    _ref.invalidate(chatsProvider);
    await load(quiet: true);
  }

  // POST …/branch?limit=50 {messageId} → {chat: {id…}, messages…}
  // Копия чата до этого сообщения; возвращает id новой копии
  Future<String> branchFrom(String id) async {
    final resp = await _dio.post(
      '$_base/branch',
      queryParameters: {'limit': 50},
      data: {'messageId': int.tryParse(id) ?? id},
    );
    _ref.invalidate(chatsProvider);
    return '${((resp.data as Map)['chat'] as Map)['id']}';
  }

  // POST …/messages/<id>/report {reason, note}
  Future<void> reportMessage(String id, String reason, String note) =>
      _dio.post(
        '$_base/messages/$id/report',
        data: {'reason': reason, 'note': note},
      );

  Future<void> deleteChat() async {
    await _dio.delete(_base);
    _ref.invalidate(chatsProvider);
  }

  void _update(String id, ChatMessage Function(ChatMessage) f) {
    state = state.copyWith(
      messages: [for (final m in state.messages) m.id == id ? f(m) : m],
    );
  }

  void _drop(Set<String> ids) {
    state = state.copyWith(
      messages: state.messages.where((m) => !ids.contains(m.id)).toList(),
    );
  }
}

final chatRoomProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomNotifier, ChatRoomState, String>(
      (ref, chatId) => ChatRoomNotifier(ref, chatId),
    );

// Открыть чат с персонажем/историей: сначала ищем уже существующий,
// иначе создаём (POST /api/chats {characterId} | {storyId})
Future<String> openChatWith(
  WidgetRef ref, {
  required bool isStory,
  required String id,
}) async {
  try {
    final chats = await ref.read(chatsProvider.future);
    for (final c in chats) {
      if ((isStory ? c.storyId : c.characterId) == id) return c.id;
    }
  } catch (_) {
    // Список не загрузился — просто создадим чат
  }
  final resp = await ref
      .read(apiClientProvider)
      .post(
        '/api/chats',
        data: isStory ? {'storyId': id} : {'characterId': id},
      );
  ref.invalidate(chatsProvider);
  return ((resp.data as Map)['chat'] as Map)['id'] as String;
}
