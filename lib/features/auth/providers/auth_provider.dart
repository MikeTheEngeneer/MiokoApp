import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/constants/api_constants.dart';
import '../../profile/providers/profile_provider.dart';
import '../../chat/providers/chats_provider.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../personas/providers/personas_provider.dart';
import '../../lorebooks/providers/lorebooks_provider.dart';
import 'login_methods_provider.dart';

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
  }) => AuthState(
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
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  // Вход через Google/Яндекс: одноразовый code из редиректа + наш secret → обычный токен.
  // Возвращает текст ошибки или null при успехе.
  Future<String?> loginWithOAuthCode(String code, String secret) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await _ref
          .read(apiClientProvider)
          .post(
            '/api/auth/session/exchange',
            data: {'code': code, 'secret': secret},
          );
      final data = resp.data as Map<String, dynamic>;
      if (data['kind'] == 'signup') {
        state = state.copyWith(isLoading: false);
        return 'Аккаунта с этим входом ещё нет. Зарегистрируйся на сайте или войди по почте';
      }
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        state = state.copyWith(isLoading: false);
        return 'Не удалось войти, попробуй ещё раз';
      }

      await _storage.write(key: 'auth_token', value: token);
      _invalidateUserData();
      await _fetchMe();
      state = state.copyWith(isLoading: false);
      return state.status == AuthStatus.authenticated
          ? null
          : 'Не удалось загрузить профиль, попробуй ещё раз';
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return apiErrorMessage(e, 'Ссылка входа не подошла, попробуй ещё раз');
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
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // Токен протух или отозван — правда нужно войти заново
        await _storage.delete(key: 'auth_token');
        state = state.copyWith(status: AuthStatus.unauthenticated);
      } else {
        // Нет интернета или сервер прилёг — токен не трогаем: пускаем
        // в приложение, а экраны сами покажут котика «нет интернета»
        state = state.copyWith(status: AuthStatus.authenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.authenticated);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    // Сбрасываем кэш — следующий пользователь увидит чистые данные
    _invalidateUserData();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Нужен для привязки способа входа: WebView передаёт его серверу как cookie
  Future<String?> readToken() => _storage.read(key: 'auth_token');

  // Сбрасывает кэш всех провайдеров, привязанных к аккаунту
  void _invalidateUserData() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(paymentProvider);
    _ref.invalidate(profileStatsProvider);
    _ref.invalidate(myWorksProvider);
    _ref.invalidate(favoritesProvider);
    _ref.invalidate(receivedGiftsProvider);
    _ref.invalidate(chatsProvider);
    _ref.invalidate(catalogFeedProvider);
    _ref.invalidate(catalogSectionsProvider);
    _ref.invalidate(catalogAuthorsProvider);
    _ref.invalidate(personasProvider);
    _ref.invalidate(myLorebooksProvider);
    _ref.invalidate(loginMethodsProvider);
    _ref.invalidate(lorebookPlaceProvider);
    _ref.invalidate(lorebookProvider);
    _ref.invalidate(lorebookTargetsProvider);
  }

  String _parseError(Object e) {
    // TODO: разобрать DioException коды
    return 'Неверный email или пароль';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
