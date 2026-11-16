import 'package:material_ui/material_ui.dart';

// Палитра сайта mioko.ai (переменные --mk-* из его CSS)
class MiokoPalette {
  static const accent = Color(0xFF28C1EA);

  static ColorScheme scheme(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static final _dark =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF072A3A),
        onPrimaryContainer: accent,
        tertiary: const Color(0xFF9FC2E0),
        onTertiary: const Color(0xFF010D19),
        surface: const Color(0xFF010D19),
        onSurface: const Color(0xFFE8F0F8),
        onSurfaceVariant: const Color(0xFF9FB3C8),
        surfaceContainerLowest: const Color(0xFF000814),
        surfaceContainerLow: const Color(0xFF031424),
        surfaceContainer: const Color(0xFF061626),
        surfaceContainerHigh: const Color(0xFF0A1C30),
        surfaceContainerHighest: const Color(0xFF13273D),
        outline: const Color(0xFF293C4F),
        outlineVariant: const Color(0xFF192738),
        error: const Color(0xFFF090B4),
        onError: const Color(0xFF010D19),
        errorContainer: const Color(0xFF2A1424),
        onErrorContainer: const Color(0xFFF090B4),
      );

  static final _light =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE1F6FC),
        onPrimaryContainer: const Color(0xFF1592C0),
        tertiary: const Color(0xFF12A0B2),
        onTertiary: Colors.white,
        surface: const Color(0xFFF2F5FA),
        onSurface: const Color(0xFF21325A),
        onSurfaceVariant: const Color(0xFF6C86A3),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Colors.white,
        surfaceContainerHighest: const Color(0xFFE3EBF4),
        outline: const Color(0xFFD8E4F0),
        outlineVariant: const Color(0xFFE6EAED),
        error: const Color(0xFFC23D71),
        onError: Colors.white,
        errorContainer: const Color(0xFFFBE6EE),
        onErrorContainer: const Color(0xFFC23D71),
      );
}

class AppTheme {
  static ThemeData build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      // Всплывающие сообщения — «плавающая» скруглённая плашка в цветах темы
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
    );
  }
}
