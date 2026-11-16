import 'package:material_ui/material_ui.dart';

// Разметка ролевых ответов — как её показывает сайт:
//   *действие* или _действие_ — курсивом и приглушённо
//   **важное** — жирным
//   > мысль — отдельной строкой с полоской слева
//   «прямая речь» целой строкой — курсивом
//   @Имя: — имя говорящего акцентным цветом
class MessageText extends StatelessWidget {
  const MessageText(this.text, {super.key, required this.color});

  final String text;
  // Основной цвет текста (на пузыре пользователя он свой)
  final Color color;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_');
  static final _speaker = RegExp(r'^@\s*([^@\n]+?):?$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyLarge!.copyWith(
      color: color,
      height: 1.45,
      fontSize: 15.5,
    );
    final soft = color.withValues(alpha: 0.72);

    TextSpan inline(String line, TextStyle style) {
      final spans = <InlineSpan>[];
      var last = 0;
      for (final m in _inline.allMatches(line)) {
        if (m.start > last) {
          spans.add(TextSpan(text: line.substring(last, m.start)));
        }
        if (m.group(1) != null) {
          spans.add(
            TextSpan(
              text: m.group(1),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: m.group(2) ?? m.group(3),
              style: TextStyle(fontStyle: FontStyle.italic, color: soft),
            ),
          );
        }
        last = m.end;
      }
      if (last < line.length) spans.add(TextSpan(text: line.substring(last)));
      return TextSpan(style: style, children: spans);
    }

    final blocks = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 8));
        continue;
      }

      final speaker = _speaker.firstMatch(line.trim());
      if (speaker != null &&
          speaker.group(1)!.trim().length <= 40 &&
          !RegExp(r'[.!?]$').hasMatch(speaker.group(1)!.trim())) {
        blocks.add(
          Text(
            speaker.group(1)!.trim(),
            style: base.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('> ') || line == '>') {
        blocks.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.6),
                  width: 3,
                ),
              ),
            ),
            child: Text.rich(
              inline(
                line.length > 2 ? line.substring(2) : '',
                base.copyWith(fontStyle: FontStyle.italic, color: soft),
              ),
            ),
          ),
        );
        continue;
      }

      final quote = RegExp(r'^«(.+)»[.,!?…]?$').firstMatch(line.trim());
      blocks.add(
        Text.rich(
          quote != null
              ? inline(line, base.copyWith(fontStyle: FontStyle.italic))
              : inline(line, base),
        ),
      );
    }

    // Копирование — через долгое нажатие на сообщение (меню на экране чата)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
