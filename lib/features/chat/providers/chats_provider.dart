import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/chat.dart';

// AsyncValue — встроенный тип Riverpod для трёх состояний: loading / data / error
final chatsProvider = FutureProvider<List<Chat>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final response = await dio.get(ApiConstants.chats);

  final List<dynamic> list = response.data['chats'] as List<dynamic>;
  return list.map((e) => Chat.fromJson(e as Map<String, dynamic>)).toList();
});
