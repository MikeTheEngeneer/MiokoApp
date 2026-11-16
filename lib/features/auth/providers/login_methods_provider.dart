import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/login_methods.dart';

final loginMethodsProvider = FutureProvider<LoginMethods>((ref) async {
  final resp = await ref.read(apiClientProvider).get('/api/auth/methods');
  return LoginMethods.fromJson(resp.data as Map<String, dynamic>);
});

// method: 'password' | 'google' | 'yandex'
Future<void> unlinkLoginMethod(WidgetRef ref, String method) async {
  await ref
      .read(apiClientProvider)
      .post('/api/auth/unlink', data: {'method': method});
  ref.invalidate(loginMethodsProvider);
  await ref.read(loginMethodsProvider.future);
}
