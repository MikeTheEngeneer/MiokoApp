import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/brand_logos.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/auth_provider.dart';
import '../providers/login_methods_provider.dart';
import 'oauth_web_page.dart';

// «Настройки → Способы входа»: почта, Google, Яндекс — как на сайте
class LoginMethodsScreen extends ConsumerStatefulWidget {
  const LoginMethodsScreen({super.key});

  @override
  ConsumerState<LoginMethodsScreen> createState() => _LoginMethodsScreenState();
}

class _LoginMethodsScreenState extends ConsumerState<LoginMethodsScreen> {
  // Способ, который сейчас подключается/отключается
  String? _busy;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _unlink(String method, String name) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Отключить «$name»?'),
        content: const Text(
          'Войти этим способом больше не получится. '
          'Остальные способы продолжат работать.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = method);
    try {
      await unlinkLoginMethod(ref, method);
      if (!mounted) return;
      _toast('Способ входа отключён');
    } catch (e) {
      if (!mounted) return;
      _toast(apiErrorMessage(e, 'Не удалось отключить'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _linkYandex() async {
    final token = await ref.read(authProvider.notifier).readToken();
    if (!mounted || token == null) return;

    final result = await openOAuthWebView(
      context,
      provider: 'yandex',
      title: 'Подключение Яндекса',
      linkToken: token,
    );
    if (!mounted || result == null) return; // окно закрыли

    // Тексты — как на сайте
    _toast(switch (result) {
      OAuthLinked(status: 'ok') => 'Яндекс подключён',
      OAuthLinked(status: 'taken') =>
        'Этот аккаунт Яндекс уже привязан к другому профилю',
      OAuthLinked(status: 'busy') =>
        'К профилю уже привязан другой аккаунт Яндекс. Сначала отключи его',
      OAuthError(:final message) => message,
      _ => 'Не удалось подключить, попробуй ещё раз',
    });
    ref.invalidate(loginMethodsProvider);
  }

  void _googleInfo() => _toast(
    'Google не разрешает вход внутри приложений. '
    'Подключить его пока можно только на сайте mioko.ai',
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(loginMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Способы входа')),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(loginMethodsProvider),
        ),
        data: (m) => RefreshIndicator(
          onRefresh: () => ref.refresh(loginMethodsProvider.future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Intro(count: m.count),
              const SizedBox(height: 20),
              _MethodCard(
                logo: Icon(
                  Icons.mail_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: 'Email и пароль',
                subtitle: m.password ? m.email : 'Пароль не задан',
                connected: m.password,
                busy: _busy == 'password',
                locked: m.password && m.isLast,
                // Задать пароль можно только через код из письма — пока на сайте
                actionLabel: m.password ? 'Отключить' : null,
                onAction: () => _unlink('password', 'Email и пароль'),
              ),
              _MethodCard(
                logo: const GoogleLogo(size: 24),
                title: 'Google',
                subtitle: m.google ? 'Подключён' : 'Не подключён',
                connected: m.google,
                busy: _busy == 'google',
                locked: m.google && m.isLast,
                actionLabel: m.google ? 'Отключить' : 'На сайте',
                onAction: m.google
                    ? () => _unlink('google', 'Google')
                    : _googleInfo,
              ),
              _MethodCard(
                logo: const YandexLogo(size: 26),
                title: 'Яндекс',
                subtitle: m.yandex ? 'Подключён' : 'Не подключён',
                connected: m.yandex,
                busy: _busy == 'yandex',
                locked: m.yandex && m.isLast,
                actionLabel: m.yandex ? 'Отключить' : 'Подключить',
                onAction: m.yandex
                    ? () => _unlink('yandex', 'Яндекс')
                    : _linkYandex,
              ),
              if (m.isLast) const _LastMethodNote(),
            ],
          ),
        ),
      ),
    );
  }
}

// Шапка: щит в мягком свечении, пояснение и «подключено N из 3»
class _Intro extends StatelessWidget {
  const _Intro({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.30),
                scheme.primary.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Icon(Icons.shield_outlined, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'Один аккаунт — несколько входов',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Подключай удобные способы, чтобы не потерять доступ к аккаунту Mioko.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        // Три «лампочки» — сколько способов подключено
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i < count ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i < count
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              'подключено $count из 3',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.busy,
    required this.locked,
    required this.actionLabel,
    required this.onAction,
  });

  final Widget logo;
  final String title;
  final String subtitle;
  final bool connected;
  final bool busy;
  // Единственный способ входа — отключать нельзя
  final bool locked;
  // null — действия нет, только статус
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    final Widget action;
    if (busy) {
      action = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (actionLabel == null) {
      action = Text(
        'Не подключено',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (connected) {
      final button = TextButton(
        style: TextButton.styleFrom(
          foregroundColor: scheme.error,
          shape: shape,
        ),
        onPressed: locked ? null : onAction,
        child: Text(actionLabel!),
      );
      action = locked
          ? Tooltip(message: 'Это единственный способ войти', child: button)
          : button;
    } else {
      action = FilledButton.tonal(
        style: FilledButton.styleFrom(shape: shape),
        onPressed: onAction,
        child: Text(actionLabel!),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: connected
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: logo,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Точка-статус: акцентная — подключён, серая — нет
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected ? scheme.primary : scheme.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _LastMethodNote extends StatelessWidget {
  const _LastMethodNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, size: 20, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Остался один способ входа. Подключи ещё один, прежде чем '
              'отключать этот — иначе доступ к аккаунту будет потерян.',
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
