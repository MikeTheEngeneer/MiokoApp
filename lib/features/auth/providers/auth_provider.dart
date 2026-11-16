import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../profile/providers/profile_provider.dart';
import '../../chat/providers/chats_provider.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../personas/providers/personas_provider.dart';

// Состояние авторизации
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? error,
    bool? isLoading,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        error: error,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  // Проверяем при запуске: есть ли сохранённый токен?
  Future<void> _init() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      await _fetchMe();
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(apiClientProvider);
      final resp = await dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final token = resp.data['token'] as String;
      final user = resp.data['user'] as Map<String, dynamic>;

      await _storage.write(key: 'auth_token', value: token);

      // Сбрасываем кэш всех данных — новый пользователь, новые данные
      _invalidateUserData();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: user['id'] as String?,
        displayName: user['display_name'] as String?,
        avatarUrl: user['avatar_url'] as String?,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e),
      );
    }
  }

  Future<void> _fetchMe() async {
    try {
      final dio = _ref.read(apiClientProvider);
      final resp = await dio.get(ApiConstants.me);
      final user = resp.data['user'] as Map<String, dynamic>;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: user['id'] as String?,
        displayName: user['display_name'] as String?,
        avatarUrl: user['avatar_url'] as String?,
      );
    } catch (_) {
      await _storage.delete(key: 'auth_token');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    // Сбрасываем кэш — следующий пользователь увидит чистые данные
    _invalidateUserData();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Сбрасывает кэш всех провайдеров, привязанных к аккаунту
  void _invalidateUserData() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(paymentProvider);
    _ref.invalidate(profileStatsProvider);
    _ref.invalidate(chatsProvider);
    _ref.invalidate(catalogFeedProvider);
    _ref.invalidate(catalogSectionsProvider);
    _ref.invalidate(catalogAuthorsProvider);
    _ref.invalidate(personasProvider);
  }

  String _parseError(Object e) {
    // TODO: разобрать DioException коды
    return 'Неверный email или пароль';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
