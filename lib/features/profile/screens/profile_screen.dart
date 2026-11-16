import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/mioko_icons.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../core/utils/format.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final paymentAsync = ref.watch(paymentProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 6,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: profileAsync.when(
                loading: () => const SizedBox(
                  key: ValueKey('loading'),
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  key: const ValueKey('error'),
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 24,
                  ),
                  child: ErrorView(
                    error: e,
                    onRetry: () {
                      ref.invalidate(profileProvider);
                      ref.invalidate(paymentProvider);
                    },
                  ),
                ),
                data: (user) => _ProfileHeader(
                  key: const ValueKey('data'),
                  user: user,
                  paymentAsync: paymentAsync,
                  onSettings: () => context.push('/settings'),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: scheme.primary,
                labelColor: scheme.onSurface,
                unselectedLabelColor: scheme.onSurfaceVariant,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Персонажи'),
                  Tab(text: 'Истории'),
                  Tab(text: 'Подарки'),
                  Tab(text: 'Коллекции'),
                  Tab(text: 'Персоны'),
                  Tab(text: 'Лорбуки'),
                ],
              ),
            ),
          ),
        ],
        body: const TabBarView(
          children: [
            _EmptyTab(text: 'У тебя пока нет персонажей'),
            _EmptyTab(text: 'У тебя пока нет историй'),
            _EmptyTab(text: 'У тебя пока нет подарков'),
            _EmptyTab(text: 'У тебя пока нет коллекций'),
            _EmptyTab(text: 'У тебя пока нет персон'),
            _EmptyTab(text: 'У тебя пока нет лорбуков'),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    super.key,
    required this.user,
    required this.paymentAsync,
    required this.onSettings,
  });

  final User user;
  final AsyncValue<PaymentInfo> paymentAsync;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = MediaQuery.of(context).padding.top;
    final initial = user.displayName.isNotEmpty ? user.displayName[0] : '?';
    final initialText = Text(
      initial,
      style: TextStyle(fontSize: 28, color: scheme.onSurface),
    );

    final outlinedStyle = OutlinedButton.styleFrom(
      side: BorderSide(color: scheme.outline),
      foregroundColor: scheme.onSurface,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Профиль',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onSettings,
                tooltip: 'Настройки',
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: scheme.surfaceContainerHighest,
                child: user.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user.avatarUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => initialText,
                        ),
                      )
                    : initialText,
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Wave + жемчужины → тап открывает экран жемчужин
              paymentAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (payment) => GestureDetector(
                  onTap: () => context.push('/pearls'),
                  child: Row(
                    children: [
                      if (payment.hasWave) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scheme.tertiary),
                          ),
                          child: Text(
                            'Wave',
                            style: TextStyle(
                              color: scheme.tertiary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const PearlIcon(size: 16),
                            const SizedBox(width: 5),
                            Text(
                              '${payment.pearls}',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const _StatsRow(),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/profile/edit'),
                  style: outlinedStyle,
                  child: const Text('Редактировать профиль'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: outlinedStyle,
                child: const Icon(Icons.bar_chart, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileStatsProvider).valueOrNull;
    // Пока грузится или если запрос не удался — прочерк, а не выдуманные цифры
    String v(int Function(ProfileStats s) pick) =>
        stats == null ? '—' : formatCount(pick(stats));

    return Row(
      children: [
        _StatItem(value: v((s) => s.followers), label: 'Подписчики'),
        const SizedBox(width: 32),
        _StatItem(value: v((s) => s.following), label: 'Подписки'),
        const SizedBox(width: 32),
        _StatItem(value: v((s) => s.interactions), label: 'Взаимодействий'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) =>
      Container(color: Theme.of(context).colorScheme.surface, child: tabBar);

  // TabBar пересоздаётся со свежими цветами при смене темы
  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}
