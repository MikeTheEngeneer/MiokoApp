import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_error.dart';

// Сервер вообще не ответил — значит, проблема со связью, а не с запросом
bool isOfflineError(Object? e) {
  if (e is! DioException) return e is SocketException;
  return switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout => true,
    DioExceptionType.unknown => e.error is SocketException,
    _ => false,
  };
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object? error;
  final VoidCallback? onRetry;
  // Компактный вариант — для блока внутри экрана, а не на весь экран
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final offline = isOfflineError(error);

    final title = offline ? 'Нет интернета' : 'Что-то пошло не так';
    final text = offline
        ? 'Котик запутался в проводах… Проверь Wi‑Fi или мобильный интернет и попробуй ещё раз'
        : apiErrorMessage(
            error ?? '',
            'Не удалось загрузить. Попробуй ещё раз',
          );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 16 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Bounce(child: OfflineCat(height: compact ? 150 : 240)),
            SizedBox(height: compact ? 12 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: compact ? 14 : 22),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Попробовать снова'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Котик мягко «дышит» — покачивается вверх-вниз
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
      child: child,
    ),
    child: widget.child,
  );
}

// Кошка-девочка с выдернутой вилкой (assets/images/no_internet_catgirl.svg).
// Сияние за ней нарисовано через currentColor — подставляем акцент темы, чтобы работал Monet
class OfflineCat extends StatelessWidget {
  const OfflineCat({super.key, this.height = 240});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/no_internet_catgirl.svg',
    height: height,
    theme: SvgTheme(currentColor: Theme.of(context).colorScheme.primary),
  );
}
