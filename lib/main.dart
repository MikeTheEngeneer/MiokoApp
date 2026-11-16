import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';

// Экран не гаснет в отладочной сборке — это делает MainActivity.kt
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Бесшовный запуск: пока Flutter не отдал первый кадр, Android держит свою
  // заставку (логотип на фоне приложения). Отдаём кадр, когда стало ясно,
  // вошёл ли пользователь, — и сразу видно главную или вход
  WidgetsBinding.instance.deferFirstFrame();
  runApp(const ProviderScope(child: MiokoApp()));
}

class MiokoApp extends ConsumerStatefulWidget {
  const MiokoApp({super.key});

  @override
  ConsumerState<MiokoApp> createState() => _MiokoAppState();
}

class _MiokoAppState extends ConsumerState<MiokoApp> {
  bool _shown = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (_, next) {
      if (next.status != AuthStatus.unknown) _show();
    }, fireImmediately: true);
    // Сервер долго молчит — не держим заставку вечно: покажем свой /splash
    _timeout = Timer(const Duration(seconds: 4), _show);
  }

  void _show() {
    if (_shown) return;
    _shown = true;
    _timeout?.cancel();
    // Ближайший кадр уже соберётся с новым статусом входа:
    // роутер уйдёт с /splash, и первым на экране окажется нужный экран
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(themeSettingsProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Без Monet (или если устройство его не поддерживает) — палитра сайта
        final light = settings.monet && lightDynamic != null
            ? lightDynamic
            : MiokoPalette.scheme(Brightness.light);
        final dark = settings.monet && darkDynamic != null
            ? darkDynamic
            : MiokoPalette.scheme(Brightness.dark);

        return MaterialApp.router(
          title: 'MiokoApp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(light),
          darkTheme: AppTheme.build(dark),
          themeMode: settings.dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}
