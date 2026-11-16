import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/open_url.dart';
import '../providers/auth_provider.dart';
import 'oauth_web_page.dart';

// ConsumerStatefulWidget — как StatefulWidget, но с доступом к Riverpod
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _emailOpen = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref
        .read(authProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);

    // Проверяем mounted ПЕРЕД использованием ref/context после await
    if (!mounted) return;
    if (ref.read(authProvider).status == AuthStatus.authenticated) {
      context.go('/home');
    }
  }

  Future<void> _showGoogleSoon() async {
    final useEmail = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _GoogleSoonSheet(),
    );
    if (useEmail == true && mounted) setState(() => _emailOpen = true);
  }

  Future<void> _loginWithYandex() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await openOAuthWebView(
      context,
      provider: 'yandex',
      title: 'Вход через Яндекс',
    );
    if (!mounted || result == null) return; // окно закрыли — ничего не делаем

    final String? error = switch (result) {
      OAuthError(:final message) => message,
      OAuthCode(:final code, :final secret) =>
        await ref.read(authProvider.notifier).loginWithOAuthCode(code, secret),
    };
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final bannerHeight = size.height * 0.5;

    return Scaffold(
      body: Stack(
        children: [
          // Баннер сверху, нижняя часть растворяется в фоне страницы
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: _Banner(background: scheme.surface),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Текст начинается там, где баннер уже растворился
                        SizedBox(height: bannerHeight * 0.72),
                        _FadeIn(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Присоединяйся к Mioko AI',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Открой персонажей, истории и roleplay за пару секунд.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _AuthButton(
                                icon: const _GoogleLogo(),
                                label: 'Продолжить с Google',
                                onTap: _showGoogleSoon,
                              ),
                              const SizedBox(height: 10),
                              _AuthButton(
                                icon: const _YandexLogo(),
                                label: 'Продолжить с Яндексом',
                                onTap: _loginWithYandex,
                              ),
                              const _OrDivider(),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _emailOpen
                                    ? _EmailForm(
                                        formKey: _formKey,
                                        email: _emailController,
                                        password: _passwordController,
                                        obscure: _obscurePassword,
                                        onToggleObscure: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        onSubmit: _onLogin,
                                      )
                                    : _AuthButton(
                                        icon: Icon(
                                          Icons.mail_outline,
                                          size: 22,
                                          color: scheme.onSurface,
                                        ),
                                        label: 'Электронная почта',
                                        onTap: () =>
                                            setState(() => _emailOpen = true),
                                      ),
                              ),
                              const SizedBox(height: 20),
                              const _LegalText(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.background});
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Лёгкий «наезд» камеры при открытии экрана
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.08, end: 1),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Image.asset(
            'assets/images/login_banner.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.45, 0.85, 1],
              colors: [
                background.withValues(alpha: 0.15),
                background.withValues(alpha: 0),
                background.withValues(alpha: 0.85),
                background,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (_, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
    ),
    child: child,
  );
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: icon)),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  // Официальный четырёхцветный знак «G»
  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: 20, height: 20);
}

class _GoogleSoonSheet extends StatelessWidget {
  const _GoogleSoonSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Значок Google в мягком круге с акцентной подсветкой
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Transform.scale(scale: 1.6, child: const _GoogleLogo()),
            ),
            const SizedBox(height: 18),
            Text(
              'Вход через Google скоро появится',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Мы доделываем его, чтобы он работал так же удобно, как на сайте. '
              'А пока можно войти по почте или через Яндекс — аккаунт тот же.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Войти по почте'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YandexLogo extends StatelessWidget {
  const _YandexLogo();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFFFC3F1D),
      shape: BoxShape.circle,
    ),
    child: const Text(
      'Я',
      style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'или',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _EmailForm extends ConsumerWidget {
  const _EmailForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (authState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                authState.error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Введите email';
              if (!v.contains('@')) return 'Неверный формат email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Введите пароль';
              if (v.length < 6) return 'Минимум 6 символов';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: authState.isLoading ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: authState.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Войти'),
          ),
        ],
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      height: 1.5,
    );

    InlineSpan link(String text, String url) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => openUrl(context, url),
        child: Text(
          text,
          style: base.copyWith(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary,
          ),
        ),
      ),
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text: 'Сервис предназначен для пользователей 18+. Продолжая, вы принимаете ',
          ),
          link('Политику конфиденциальности', Links.privacy),
          const TextSpan(text: ', '),
          link('Пользовательское соглашение', Links.terms),
          const TextSpan(text: ' и '),
          link('Правила сервиса', Links.rules),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
