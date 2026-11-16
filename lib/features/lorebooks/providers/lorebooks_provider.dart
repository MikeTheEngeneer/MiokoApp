import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/lorebook.dart';

// Место, куда подключают лорбук. Как на сайте:
// ('mine', 'me') — все мои чаты, ('persona', <public_id персоны>) — персона
typedef LorePlace = (String kind, String id);

const LorePlace allChatsPlace = ('mine', 'me');
LorePlace personaPlace(String personaId) => ('persona', personaId);

String _placePath(LorePlace p) =>
    '/api/lorebooks/places/${p.$1}/${Uri.encodeComponent(p.$2)}';

final myLorebooksProvider = FutureProvider<MyLorebooks>((ref) async {
  final resp = await ref.read(apiClientProvider).get('/api/lorebooks/mine');
  return MyLorebooks.fromJson(resp.data as Map<String, dynamic>);
});

final lorebookPlaceProvider = FutureProvider.family<PlaceLorebooks, LorePlace>((
  ref,
  place,
) async {
  final resp = await ref.read(apiClientProvider).get(_placePath(place));
  return PlaceLorebooks.fromJson(resp.data as Map<String, dynamic>);
});

final lorebookProvider = FutureProvider.autoDispose
    .family<LorebookDetail, String>((ref, id) async {
      final resp = await ref
          .read(apiClientProvider)
          .get('/api/lorebooks/${Uri.encodeComponent(id)}');
      return LorebookDetail.fromJson(resp.data as Map<String, dynamic>);
    });

final lorebookTargetsProvider = FutureProvider.autoDispose
    .family<LorebookTargets, String>((ref, id) async {
      final resp = await ref
          .read(apiClientProvider)
          .get('/api/lorebooks/${Uri.encodeComponent(id)}/targets');
      return LorebookTargets.fromJson(resp.data as Map<String, dynamic>);
    });

// Поиск опубликованных лорбуков; страницы листаются курсором before
Future<LorebookPage> fetchPublicLorebooks(
  Ref ref,
  String query, {
  String? before,
}) async {
  final q = query.trim();
  final resp = await ref
      .read(apiClientProvider)
      .get(
        '/api/lorebooks/public',
        queryParameters: {'q': ?(q.isEmpty ? null : q), 'before': ?before},
      );
  return LorebookPage.fromJson(resp.data as Map<String, dynamic>);
}

// Подключить/отключить лорбук к месту. Сервер отвечает новым списком места.
// У персоны лорбук один — новый сервер ставит вместо прежнего сам
Future<void> setLorebookConnected(
  Ref ref, {
  required LorePlace place,
  required String lorebookId,
  required bool connect,
}) async {
  final dio = ref.read(apiClientProvider);
  if (connect) {
    await dio.post(_placePath(place), data: {'lorebook': lorebookId});
  } else {
    await dio.delete('${_placePath(place)}/${Uri.encodeComponent(lorebookId)}');
  }
  // Перезапрашиваем всё, что показывает подключения этого места и этого лорбука
  ref.invalidate(lorebookPlaceProvider(place));
  // Всё семейство: у персоны новый лорбук вытесняет прежний, и его страница тоже должна обновиться
  ref.invalidate(lorebookTargetsProvider);
}

// Чтобы экраны могли звать действия через WidgetRef
final lorebookActionsProvider = Provider<LorebookActions>(LorebookActions.new);

class LorebookActions {
  LorebookActions(this._ref);
  final Ref _ref;

  Future<void> setConnected({
    required LorePlace place,
    required String lorebookId,
    required bool connect,
  }) => setLorebookConnected(
    _ref,
    place: place,
    lorebookId: lorebookId,
    connect: connect,
  );

  Future<LorebookPage> search(String query, {String? before}) =>
      fetchPublicLorebooks(_ref, query, before: before);
}
