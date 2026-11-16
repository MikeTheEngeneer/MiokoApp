import 'dart:convert';

import 'package:dio/dio.dart';

// Ответ персонажа приходит потоком (SSE): строки `data: {...}`, разделённые пустой строкой.
// Поля — как разбирает сайт: reset, ids, delta, replace, error, done
sealed class StreamEvent {
  const StreamEvent();
}

// Кусочек текста — дописать в конец
class DeltaEvent extends StreamEvent {
  final String text;
  const DeltaEvent(this.text);
}

// Заменить весь текст ответа (reset и replace)
class ReplaceEvent extends StreamEvent {
  final String text;
  const ReplaceEvent(this.text);
}

// Настоящие id сообщений на сервере вместо временных
class IdsEvent extends StreamEvent {
  final String? user;
  final String? assistant;
  const IdsEvent({this.user, this.assistant});
}

class ErrorEvent extends StreamEvent {
  final String message;
  const ErrorEvent(this.message);
}

class DoneEvent extends StreamEvent {
  const DoneEvent();
}

// Сервер отказал ещё до начала ответа (не 200): тело — JSON {error, code, …}
class StreamDenied implements Exception {
  final int? status;
  final Map<String, dynamic> body;
  const StreamDenied(this.status, this.body);

  String? get code => body['code'] as String?;
  String get message =>
      body['error'] as String? ?? 'Не удалось отправить сообщение';
  bool get isTideLimit => code == 'tide_limit';
}

Stream<StreamEvent> openEventStream(
  Dio dio,
  String path, {
  String method = 'POST',
  Object? data,
}) async* {
  final Response<ResponseBody> resp;
  try {
    resp = await dio.request<ResponseBody>(
      path,
      data: data,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        // Персонаж может «думать» дольше обычного таймаута
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
  } on DioException catch (e) {
    final body = e.response?.data;
    if (body is ResponseBody) {
      throw StreamDenied(e.response?.statusCode, await _readJson(body));
    }
    rethrow;
  }

  var buffer = '';
  await for (final chunk in utf8.decoder.bind(resp.data!.stream)) {
    buffer += chunk;
    final blocks = buffer.split('\n\n');
    buffer = blocks.removeLast();
    for (final block in blocks) {
      yield* _parse(block);
    }
  }
  if (buffer.trim().isNotEmpty) yield* _parse(buffer);
}

Stream<StreamEvent> _parse(String block) async* {
  final line = block.trim();
  if (!line.startsWith('data:')) return;
  final Object? json;
  try {
    json = jsonDecode(line.substring(5).trim());
  } catch (_) {
    return;
  }
  if (json is! Map) return;
  if (json['reset'] is String) yield ReplaceEvent(json['reset'] as String);
  final ids = json['ids'];
  if (ids is Map) {
    yield IdsEvent(
      user: ids['user']?.toString(),
      assistant: ids['assistant']?.toString(),
    );
  }
  if (json['delta'] is String && (json['delta'] as String).isNotEmpty) {
    yield DeltaEvent(json['delta'] as String);
  }
  if (json['replace'] is String) yield ReplaceEvent(json['replace'] as String);
  if (json['error'] is String) yield ErrorEvent(json['error'] as String);
  if (json['done'] == true) yield const DoneEvent();
}

Future<Map<String, dynamic>> _readJson(ResponseBody body) async {
  try {
    final text = await utf8.decoder.bind(body.stream).join();
    final json = jsonDecode(text);
    return json is Map<String, dynamic> ? json : const {};
  } catch (_) {
    return const {};
  }
}
