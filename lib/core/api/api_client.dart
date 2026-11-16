import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

// Провайдер Dio-клиента — один на всё приложение
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Интерцептор — автоматически добавляет токен к каждому запросу
  dio.interceptors.add(AuthInterceptor());

  // Логирование в debug-режиме
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  return dio;
});

/// Интерцептор авторизации:
/// - Перед каждым запросом берёт токен из безопасного хранилища
/// - Добавляет `Authorization: Bearer <token>` в заголовок
class AuthInterceptor extends Interceptor {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
