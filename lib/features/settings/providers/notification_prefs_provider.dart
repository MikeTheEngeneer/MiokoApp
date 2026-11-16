import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

// Ключи настроек уведомлений — как на сайте. 'all' — общий выключатель
const notificationPrefKeys = [
  'all',
  'chat',
  'moderation',
  'new_work',
  'gift',
  'tip',
  'comment',
  'reply',
  'lore_split',
];

typedef NotificationPrefs = Map<String, bool>;

// Сервер должен прислать все ключи булевыми — иначе ответ считаем неверным (как сайт)
NotificationPrefs _parse(Object? data) {
  final prefs = data is Map ? data['prefs'] : null;
  if (prefs is! Map) throw const FormatException('Неверный ответ сервера');
  return {
    for (final k in notificationPrefKeys)
      k: prefs[k] is bool
          ? prefs[k] as bool
          : throw const FormatException('Неверный ответ сервера'),
  };
}

// GET /api/notifications/prefs → {prefs: {all, chat, …}}
// PUT /api/notifications/prefs {<ключ>: bool} → те же prefs целиком
class NotificationPrefsNotifier
    extends StateNotifier<AsyncValue<NotificationPrefs>> {
  NotificationPrefsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  // Последнее, что подтвердил сервер, — к нему откатываемся при ошибке
  NotificationPrefs _confirmed = const {};
  // Переключения, которые ещё не сохранены
  final _pending = <MapEntry<String, bool>>[];
  // Запросы идут строго по очереди, чтобы быстрые нажатия не перепутались
  Future<void> _queue = Future.value();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final resp = await _ref
          .read(apiClientProvider)
          .get('/api/notifications/prefs');
      if (!mounted) return;
      _confirmed = _parse(resp.data);
      state = AsyncValue.data(_confirmed);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  NotificationPrefs get _shown => {
    ..._confirmed,
    for (final p in _pending) p.key: p.value,
  };

  // Экран меняется сразу; future завершается ошибкой, если сохранить не вышло
  Future<void> set(String key, bool value) {
    final entry = MapEntry(key, value);
    _pending.add(entry);
    state = AsyncValue.data(_shown);

    final done = _queue.then((_) async {
      try {
        final resp = await _ref
            .read(apiClientProvider)
            .put('/api/notifications/prefs', data: {key: value});
        _confirmed = _parse(resp.data);
      } finally {
        _pending.remove(entry);
        if (mounted) state = AsyncValue.data(_shown);
      }
    });
    // Ошибка одного сохранения не должна ломать очередь следующих
    _queue = done.catchError((_) {});
    return done;
  }
}

final notificationPrefsProvider =
    StateNotifierProvider.autoDispose<
      NotificationPrefsNotifier,
      AsyncValue<NotificationPrefs>
    >((ref) => NotificationPrefsNotifier(ref));
