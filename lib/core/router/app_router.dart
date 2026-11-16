import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/login_methods_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/pearls/screens/pearls_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/notifications_screen.dart';
import '../../features/settings/screens/documents_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/personas/screens/personas_screen.dart';
import '../../features/personas/screens/create_persona_screen.dart';
import '../../features/catalog/screens/item_detail_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/lorebooks/screens/lorebooks_screen.dart';
import '../../features/lorebooks/screens/lorebook_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../shared/widgets/mioko_icons.dart';

// Fade + лёгкий slide снизу — используется для всех push-переходов
Page<void> _buildPage(Widget child) => CustomTransitionPage(
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  },
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // Пока проверяем сохранённый токен — заставка, а не экран входа
      // (иначе при запуске на секунду мелькал вход)
      if (authState.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isOnLogin = loc == '/login';

      if (loc == '/splash') return isLoggedIn ? '/home' : '/login';
      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) => const NoTransitionPage(child: _Splash()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) => _buildPage(const LoginScreen()),
      ),

      // Вне ShellRoute — страница персонажа открывается во весь экран, без нижнего меню
      GoRoute(
        path: '/item/:id',
        pageBuilder: (_, state) {
          final args = state.extra;
          return _buildPage(
            args is ItemDetailArgs
                ? ItemDetailScreen(args: args)
                : const Scaffold(
                    body: Center(child: Text('Персонаж не найден')),
                  ),
          );
        },
      ),

      // Переписка — на весь экран, без нижней панели
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (_, state) => _buildPage(
          ChatScreen(
            chatId: state.pathParameters['id']!,
            args: state.extra is ChatArgs ? state.extra as ChatArgs : null,
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, _) => _buildPage(const SearchScreen()),
      ),
      GoRoute(
        path: '/pearls',
        // /pearls?tab=packs — сразу на вкладке жемчужин
        pageBuilder: (_, state) => _buildPage(
          PearlsScreen(
            initialTab: state.uri.queryParameters['tab'] == 'packs'
                ? BillingTab.packs
                : BillingTab.plans,
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, _) => _buildPage(const SettingsScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (_, _) => _buildPage(const EditProfileScreen()),
      ),
      GoRoute(
        path: '/personas',
        pageBuilder: (_, _) => _buildPage(const PersonasScreen()),
      ),
      GoRoute(
        path: '/personas/new',
        pageBuilder: (_, _) => _buildPage(const CreatePersonaScreen()),
      ),
      GoRoute(
        path: '/documents',
        pageBuilder: (_, _) => _buildPage(const DocumentsScreen()),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (_, _) => _buildPage(const NotificationsScreen()),
      ),
      GoRoute(
        path: '/settings/login-methods',
        pageBuilder: (_, _) => _buildPage(const LoginMethodsScreen()),
      ),
      GoRoute(
        path: '/lorebooks',
        pageBuilder: (_, _) => _buildPage(const LorebooksScreen()),
      ),
      GoRoute(
        path: '/lorebook/:id',
        pageBuilder: (_, state) =>
            _buildPage(LorebookScreen(id: state.pathParameters['id']!)),
      ),

      // Только 4 корневых раздела живут внутри оболочки с плавающей панелью
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, _) => _buildPage(const HomeScreen()),
          ),
          GoRoute(
            path: '/explore',
            pageBuilder: (_, _) => _buildPage(const ExploreScreen()),
          ),
          GoRoute(
            path: '/chats',
            pageBuilder: (_, _) => _buildPage(const ChatListScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, _) => _buildPage(const ProfileScreen()),
          ),
        ],
      ),
    ],
  );
});

// Заставка на время проверки входа (обычно доли секунды)
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: const Center(child: MiokoLogo(size: 88)),
  );
}
