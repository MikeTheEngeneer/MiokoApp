import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/mioko_icons.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../core/utils/format.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/media_avatar.dart';
import '../../../shared/widgets/catalog_card.dart';
import '../../catalog/models/catalog_item.dart';
import '../../lorebooks/providers/lorebooks_provider.dart';
import '../../personas/providers/personas_provider.dart';
import '../../lorebooks/widgets/lorebook_tile.dart';

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
            _WorksTab(stories: false),
            _WorksTab(stories: true),
            _GiftsTab(),
            _CollectionsTab(),
            _PersonasTab(),
            _LorebooksTab(),
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

// Свои лорбуки — как вкладка «Лорбуки» в профиле на сайте
class _LorebooksTab extends ConsumerWidget {
  const _LorebooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Снизу — плавающая панель вкладок
    final bottom = MediaQuery.paddingOf(context).bottom + 16;

    return ref
        .watch(myLorebooksProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(myLorebooksProvider),
          ),
          data: (m) => m.lorebooks.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'У тебя пока нет лорбуков',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push('/lorebooks'),
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Найти лорбуки'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
                  itemCount: m.lorebooks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final lb = m.lorebooks[i];
                    return LorebookTile(
                      lorebook: lb,
                      showAuthor: false,
                      onTap: () => context.push('/lorebook/${lb.publicId}'),
                    );
                  },
                ),
        );
  }
}

// ── Вкладки профиля: данные те же, что у сайта ───────────────────────

// Карточки сеткой, как на сайте: подпись с количеством сверху, пусто — текст
class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.items,
    required this.countText,
    required this.emptyText,
    required this.heroPrefix,
    required this.onRefresh,
    this.onTap,
  });

  final List<CatalogItem> items;
  final String countText;
  final String emptyText;
  final String heroPrefix;
  final Future<void> Function() onRefresh;
  final void Function(CatalogItem)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Снизу — плавающая панель вкладок
    final bottom = MediaQuery.paddingOf(context).bottom + 16;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                countText,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(32, 24, 32, bottom),
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 148 / 212,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return CatalogCard(
                    item: item,
                    heroTag: '$heroPrefix-${item.itemType}-${item.id}',
                    onTap: onTap == null ? null : () => onTap!(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Загрузка/ошибка одинаковые для всех вкладок
Widget _async<T>(
  AsyncValue<T> value,
  VoidCallback retry,
  Widget Function(T) data,
) => value.when(
  skipLoadingOnRefresh: true,
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => ErrorView(error: e, compact: true, onRetry: retry),
  data: data,
);

String _plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n $one';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n $few';
  return '$n $many';
}

// «Персонажи» / «Истории» — мои работы из GET /api/authors/<мой id>
class _WorksTab extends ConsumerWidget {
  const _WorksTab({required this.stories});
  final bool stories;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
    ref.watch(myWorksProvider),
    () => ref.invalidate(myWorksProvider),
    (w) {
      final items = stories ? w.stories : w.characters;
      return _CardsGrid(
        items: items,
        countText: stories
            ? _plural(items.length, 'история', 'истории', 'историй')
            : _plural(items.length, 'персонаж', 'персонажа', 'персонажей'),
        emptyText: stories
            ? 'У тебя пока нет историй'
            : 'У тебя пока нет персонажей',
        heroPrefix: stories ? 'profile-stories' : 'profile-characters',
        onRefresh: () => ref.refresh(myWorksProvider.future),
      );
    },
  );
}

// «Коллекции» — то, что добавил «В коллекцию» (GET /api/favorites)
class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
    ref.watch(favoritesProvider),
    () => ref.invalidate(favoritesProvider),
    (items) => _CardsGrid(
      items: items,
      countText: _plural(
        items.length,
        'сохранённый',
        'сохранённых',
        'сохранённых',
      ),
      emptyText: 'В коллекции пока пусто',
      heroPrefix: 'profile-collections',
      onRefresh: () => ref.refresh(favoritesProvider.future),
    ),
  );
}

// «Персоны» — карточками, как на сайте; тап — экран персон
class _PersonasTab extends ConsumerWidget {
  const _PersonasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _async(
    ref.watch(personasProvider),
    () => ref.invalidate(personasProvider),
    (data) => _CardsGrid(
      items: [
        for (final p in data.personas)
          CatalogItem(
            itemType: 'persona',
            id: p.publicId,
            name: p.name,
            subtitle: p.description.isEmpty ? null : p.description,
            // Градиент-заглушка — как у сайта для персон без картинки
            avatar: MediaAvatar(
              imageUrl: p.avatarUrl,
              initial: p.name.isEmpty ? '?' : p.name.characters.first,
              c1: const Color(0xFF7C5AC0),
              c2: const Color(0xFF2A1A55),
            ),
          ),
      ],
      countText: '${data.personas.length} из ${data.limit}',
      emptyText: 'Персон пока нет',
      heroPrefix: 'profile-personas',
      onRefresh: () => ref.refresh(personasProvider.future),
      onTap: (_) => context.push('/personas'),
    ),
  );
}

// «Подарки» — что мне подарили (GET /api/gifts/received/<id>), по страницам
class _GiftsTab extends ConsumerStatefulWidget {
  const _GiftsTab();

  @override
  ConsumerState<_GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends ConsumerState<_GiftsTab> {
  // Догруженные страницы («Показать ещё») поверх первой из провайдера
  final _more = <ReceivedGift>[];
  String? _next;
  bool _loadingMore = false;
  bool _usedFirstNext = false;

  Future<void> _loadMore(String before) async {
    setState(() => _loadingMore = true);
    try {
      final user = await ref.read(profileProvider.future);
      final resp = await ref
          .read(apiClientProvider)
          .get(
            '/api/gifts/received/${user.id}',
            queryParameters: {'before': before},
          );
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>;
      setState(() {
        _more.addAll([
          for (final g in (data['gifts'] as List? ?? const []))
            ReceivedGift.fromJson(g as Map<String, dynamic>),
        ]);
        _next = data['next']?.toString();
        _usedFirstNext = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить подарки')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _more.clear();
      _next = null;
      _usedFirstNext = false;
    });
    final _ = await ref.refresh(receivedGiftsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom + 16;

    return _async(
      ref.watch(receivedGiftsProvider),
      () => ref.invalidate(receivedGiftsProvider),
      (page) {
        final gifts = [...page.gifts, ..._more];
        final next = _usedFirstNext ? _next : page.next;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _plural(page.total, 'подарок', 'подарка', 'подарков'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (gifts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 24, 32, bottom),
                    child: Text(
                      'Тебе пока не дарили подарков',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 130,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: gifts.length,
                    itemBuilder: (_, i) => _GiftTile(gift: gifts[i]),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
                  sliver: SliverToBoxAdapter(
                    child: next == null
                        ? const SizedBox.shrink()
                        : Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : FilledButton.tonal(
                                    onPressed: () => _loadMore(next),
                                    child: const Text('Показать ещё'),
                                  ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift});
  final ReceivedGift gift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final from = gift.hidden || gift.senderName == null
        ? 'Аноним'
        : gift.senderName!;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Image.network(
              gift.imageUrl,
              fit: BoxFit.contain,
              // Нет картинки — показываем эмодзи подарка
              errorBuilder: (_, _, _) => Center(
                child: Text(gift.emoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gift.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'от $from',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
