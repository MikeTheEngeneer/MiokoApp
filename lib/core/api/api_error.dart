import 'package:dio/dio.dart';

String apiErrorMessage(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Нет соединения с сервером';
    }
  }
  return fallback;
}
