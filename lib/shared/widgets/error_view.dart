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
            _Bounce(child: OfflineCat(size: compact ? 130 : 200)),
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

// Котик-девочка, запутавшаяся в проводе с выдернутой вилкой. Цвета чёлки и провода — из темы
class OfflineCat extends StatelessWidget {
  const OfflineCat({super.key, this.size = 200});
  final double size;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _hex(scheme.primaryContainer);
    final accent = _hex(scheme.primary);
    final socket = _hex(scheme.surfaceContainerHighest);
    final socketLine = _hex(scheme.outline);
    const fur = '#FFF6EF';
    const line = '#3B3550';
    const pink = '#F6A5C0';
    const spark = '#FFC857';

    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 200">
  <circle cx="120" cy="108" r="86" fill="$bg"/>

  <!-- хвост -->
  <path d="M158 158 C192 160 198 128 182 116" fill="none" stroke="$line" stroke-width="13" stroke-linecap="round"/>
  <path d="M158 158 C192 160 198 128 182 116" fill="none" stroke="$fur" stroke-width="9" stroke-linecap="round"/>

  <!-- тело -->
  <ellipse cx="120" cy="150" rx="44" ry="30" fill="$fur" stroke="$line" stroke-width="2.5"/>

  <!-- уши -->
  <path d="M80 82 L84 38 L110 62 Z" fill="$fur" stroke="$line" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M160 82 L156 38 L130 62 Z" fill="$fur" stroke="$line" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M88 72 L89 50 L103 63 Z" fill="$pink"/>
  <path d="M152 72 L151 50 L137 63 Z" fill="$pink"/>

  <!-- голова -->
  <ellipse cx="120" cy="100" rx="46" ry="40" fill="$fur" stroke="$line" stroke-width="2.5"/>

  <!-- чёлка -->
  <path d="M74 100 C72 44 168 44 166 100 C156 84 146 92 138 80 C130 94 112 94 104 80 C96 92 84 86 74 100 Z" fill="$accent" stroke="$line" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M96 66 Q104 60 112 62" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" stroke-linecap="round"/>

  <!-- зажмуренные грустные глазки -->
  <path d="M99 104 Q105 110 111 104" fill="none" stroke="$line" stroke-width="3" stroke-linecap="round"/>
  <path d="M129 104 Q135 110 141 104" fill="none" stroke="$line" stroke-width="3" stroke-linecap="round"/>
  <!-- слезинка -->
  <path d="M146 106 Q151 114 146 118 Q141 114 146 106 Z" fill="$accent" stroke="$line" stroke-width="1"/>

  <!-- щёчки -->
  <circle cx="97" cy="114" r="5.5" fill="$pink" opacity="0.7"/>
  <circle cx="141" cy="115" r="5.5" fill="$pink" opacity="0.7"/>

  <!-- ротик-«w» -->
  <path d="M113 117 Q116.5 121 120 117 Q123.5 121 127 117" fill="none" stroke="$line" stroke-width="2.2" stroke-linecap="round"/>

  <!-- усы -->
  <path d="M84 108 L68 104 M84 113 L68 116 M156 108 L172 104 M156 113 L172 116" stroke="$line" stroke-width="1.8" stroke-linecap="round"/>

  <!-- лапки -->
  <ellipse cx="104" cy="150" rx="9" ry="6.5" fill="$fur" stroke="$line" stroke-width="2"/>
  <ellipse cx="136" cy="150" rx="9" ry="6.5" fill="$fur" stroke="$line" stroke-width="2"/>

  <!-- спутанный провод с вилкой -->
  <path d="M76 168 C54 168 42 152 54 144 C66 136 70 158 52 162 C36 166 28 178 14 186" fill="none" stroke="$accent" stroke-width="5" stroke-linecap="round"/>
  <rect x="74" y="160" width="22" height="16" rx="4" fill="$accent"/>
  <path d="M96 164 L104 164 M96 172 L104 172" stroke="$line" stroke-width="3" stroke-linecap="round"/>

  <!-- розетка с проводом -->
  <path d="M162 168 C184 168 200 180 228 186" fill="none" stroke="$accent" stroke-width="5" stroke-linecap="round"/>
  <rect x="138" y="158" width="24" height="20" rx="5" fill="$socket" stroke="$socketLine" stroke-width="2"/>
  <rect x="141" y="162" width="6" height="3" rx="1" fill="$line"/>
  <rect x="141" y="171" width="6" height="3" rx="1" fill="$line"/>

  <!-- искорки -->
  <path d="M114 160 L119 165 L115 167 L121 173" fill="none" stroke="$spark" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M126 158 L129 162 M131 168 L135 169" stroke="$spark" stroke-width="2.5" stroke-linecap="round"/>
</svg>''';

    return SvgPicture.string(svg, width: size, height: size * 200 / 240);
  }
}
