// GET /api/auth/methods — какими способами можно войти в этот аккаунт
class LoginMethods {
  final String email;
  final bool password;
  final bool google;
  final bool yandex;

  const LoginMethods({
    required this.email,
    required this.password,
    required this.google,
    required this.yandex,
  });

  factory LoginMethods.fromJson(Map<String, dynamic> json) => LoginMethods(
    email: json['email'] as String? ?? '',
    password: json['password'] == true,
    google: json['google'] == true,
    yandex: json['yandex'] == true,
  );

  int get count => [password, google, yandex].where((on) => on).length;

  // Последний способ отключать нельзя — иначе в аккаунт будет не войти
  bool get isLast => count <= 1;
}
