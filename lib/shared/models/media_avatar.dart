import 'package:material_ui/material_ui.dart';

// Аватар персонажа/истории/чата: картинка + градиент c1→c2 с буквой на случай, если картинки нет
class MediaAvatar {
  final String? imageUrl;
  final String initial;
  final Color c1;
  final Color c2;
  final Alignment alignment;

  const MediaAvatar({
    this.imageUrl,
    required this.initial,
    required this.c1,
    required this.c2,
    this.alignment = Alignment.center,
  });

  factory MediaAvatar.fromJson(Map<String, dynamic>? json) => MediaAvatar(
    imageUrl: json?['image_url'] as String?,
    initial: json?['initial'] as String? ?? '?',
    c1: _hex(json?['c1'] as String?, const Color(0xFF3A6B8C)),
    c2: _hex(json?['c2'] as String?, const Color(0xFF16263A)),
    alignment: _alignment(json?['pos'] as String?),
  );

  static Color _hex(String? hex, Color fallback) {
    final h = hex?.replaceFirst('#', '');
    if (h == null || h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  // CSS object-position "50% 20%" → Alignment(0, -0.6)
  static Alignment _alignment(String? pos) {
    final parts = pos?.split(' ') ?? const [];
    double axis(int i) {
      if (i >= parts.length) return 0;
      final p = double.tryParse(parts[i].replaceAll('%', ''));
      return p == null ? 0 : (p / 50 - 1).clamp(-1.0, 1.0);
    }

    return Alignment(axis(0), axis(1));
  }
}
