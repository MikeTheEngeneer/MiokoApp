import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Тексты ошибок входа — те же, что показывает сайт (сервер возвращает ?error=код)
const _authErrors = {
  'provider_off': 'Этот способ входа сейчас недоступен',
  'cancelled': 'Вход отменён',
  'link_expired': 'Ссылка входа устарела, попробуй ещё раз',
  'provider_failed': 'Не удалось войти, попробуй ещё раз',
  'no_email': 'В этом аккаунте нет почты, а без неё войти нельзя. Войди через Google или по почте',
  'no_account_id': 'Провайдер не передал идентификатор аккаунта',
  'email_unverified':
      'Почта не подтверждена у провайдера. Подтверди её и попробуй снова',
  'yandex_needs_link':
      'Сначала войди по почте и подключи Яндекс в настройках аккаунта на сайте',
  'bad_link': 'Ссылка входа не подошла. Войди заново',
  'bad_token': 'Не удалось войти, попробуй ещё раз',
  'account_banned': 'Аккаунт заблокирован за нарушение Правил. Если это ошибка — напиши в поддержку',
  'session_expired': 'Сессия истекла — войди снова',
};

sealed class OAuthResult {
  const OAuthResult();
}

class OAuthCode extends OAuthResult {
  final String code;
  final String secret;
  const OAuthCode(this.code, this.secret);
}

// Итог привязки способа входа: ok | taken | busy (сайт получает его в ?link=…)
class OAuthLinked extends OAuthResult {
  final String status;
  const OAuthLinked(this.status);
}

class OAuthError extends OAuthResult {
  final String message;
  const OAuthError(this.message);
}

// secret («m» в ссылке) — как на сайте: 16 случайных байт в hex
String _newSecret() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Future<OAuthResult?> openOAuthWebView(
  BuildContext context, {
  required String provider,
  required String title,
  // Привязка способа входа к текущему аккаунту: сюда передают его токен.
  // Сайт делает то же самое переходом в браузере, где токен лежит в cookie mk_token
  String? linkToken,
}) {
  return Navigator.of(context).push<OAuthResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _OAuthWebPage(provider: provider, title: title, linkToken: linkToken),
    ),
  );
}

class _OAuthWebPage extends StatefulWidget {
  const _OAuthWebPage({
    required this.provider,
    required this.title,
    this.linkToken,
  });
  final String provider;
  final String title;
  final String? linkToken;

  @override
  State<_OAuthWebPage> createState() => _OAuthWebPageState();
}

class _OAuthWebPageState extends State<_OAuthWebPage> {
  late final WebViewController _controller;
  final String _secret = _newSecret();
  int _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (req) => _intercept(req.url)
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
          // Подстраховка: если редирект прошёл мимо onNavigationRequest
          onPageStarted: _intercept,
        ),
      );
    _start();
  }

  static const _cookieDomain = 'api.mioko.ai';

  Future<void> _setSessionCookie(String value) =>
      WebViewCookieManager().setCookie(
        WebViewCookie(name: 'mk_token', value: value, domain: _cookieDomain),
      );

  Future<void> _start() async {
    final token = widget.linkToken;
    // По этой cookie сервер понимает, к какому аккаунту привязывать
    if (token != null) await _setSessionCookie(token);
    if (!mounted) return;
    await _controller.loadRequest(
      Uri.parse(
        'https://api.mioko.ai/api/auth/${widget.provider}'
        '?${token != null ? 'link=1&' : ''}m=$_secret',
      ),
    );
  }

  @override
  void dispose() {
    // Токен не должен оставаться в cookie встроенного браузера
    if (widget.linkToken != null) _setSessionCookie('');
    super.dispose();
  }

  // Ловим возврат на mioko.ai: там в #code — одноразовый код, в ?error — причина отказа
  bool _intercept(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      // Ссылки на приложение Яндекса и т.п. — во встроенном окне не открыть
      return true;
    }
    if (uri.host != 'mioko.ai' && uri.host != 'www.mioko.ai') return false;

    final error = uri.queryParameters['error'];
    final code = Uri.splitQueryString(uri.fragment)['code'];
    final link = uri.queryParameters['link'];
    final OAuthResult result;
    if (widget.linkToken != null && link != null) {
      result = OAuthLinked(link);
    } else if (code != null && code.isNotEmpty) {
      result = OAuthCode(code, _secret);
    } else {
      result = OAuthError(
        _authErrors[error] ?? 'Не удалось войти, попробуй ещё раз',
      );
    }
    _finish(result);
    return true;
  }

  void _finish(OAuthResult result) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
