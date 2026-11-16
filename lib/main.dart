import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Только в отладке: экран не гаснет, пока приложение открыто, —
  // телефон не блокируется и `flutter run` не теряет связь.
  // В релизной сборке kDebugMode = false, и всё как обычно
  if (kDebugMode) WakelockPlus.enable();
  runApp(const ProviderScope(child: MiokoApp()));
}

class MiokoApp extends ConsumerWidget {
  const MiokoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
