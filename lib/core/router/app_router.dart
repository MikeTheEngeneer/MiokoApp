import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/pearls/screens/pearls_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/personas/screens/personas_screen.dart';
import '../../features/personas/screens/create_persona_screen.dart';
import '../../features/catalog/screens/item_detail_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../shared/widgets/main_shell.dart';

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
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) => _buildPage(const LoginScreen()),
      ),

      // Вне ShellRoute — страница персонажа открывается во весь экран, без нижнего меню
      GoRoute(
        path: '/item/:id',
        pageBuilder: (_, state) {
          final args = state.extra;
          return _buildPage(args is ItemDetailArgs
              ? ItemDetailScreen(args: args)
              : const Scaffold(body: Center(child: Text('Персонаж не найден'))));
        },
      ),

      GoRoute(
        path: '/search',
        pageBuilder: (_, _) => _buildPage(const SearchScreen()),
      ),
      GoRoute(
        path: '/pearls',
        // /pearls?tab=packs — сразу на вкладке жемчужин
        pageBuilder: (_, state) => _buildPage(PearlsScreen(
          initialTab: state.uri.queryParameters['tab'] == 'packs'
              ? BillingTab.packs
              : BillingTab.plans,
        )),
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
