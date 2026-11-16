import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/open_url.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/mioko_icons.dart';
import '../../../shared/widgets/pressable.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../catalog/screens/item_detail_screen.dart';
import '../../profile/providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorsAsync = ref.watch(catalogAuthorsProvider);
    final hot = ref.watch(catalogFeedProvider(CatalogSort.hot));
    final fresh = ref.watch(catalogFeedProvider(CatalogSort.new_));
    final payment = ref.watch(paymentProvider).valueOrNull;
    final top = MediaQuery.of(context).padding.top;

    void retry() {
      ref.invalidate(catalogFeedProvider);
      ref.invalidate(catalogAuthorsProvider);
    }

    // Обе ленты упали — показываем одну ошибку на весь экран, а не две одинаковые
    // Ошибка может прийти поверх старых данных (были загружены, потом пропал интернет) —
    // поэтому смотрим только на hasError, иначе каждая лента рисует своего котика
    final failed = hot.hasError && fresh.hasError;

    return RefreshIndicator(
      edgeOffset: top,
      onRefresh: () async {
        retry();
        ref.invalidate(paymentProvider);
        // Ошибку покажет котик на экране — здесь её только гасим
        await ref
            .read(catalogFeedProvider(CatalogSort.hot).future)
            .catchError((_) => <CatalogItem>[]);
      },
      child: CustomScrollView(
        slivers: [
          if (failed) ...[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: top,
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: ErrorView(error: hot.error, onRetry: retry),
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, top + 12, 8, 14),
                child: const _Header(),
              ),
            ),

            // Баннеры с главной сайта. Wave не предлагаем тем, у кого он уже есть
            SliverToBoxAdapter(
              child: _Banners(showWave: !(payment?.hasWave ?? false)),
            ),

            const SliverToBoxAdapter(
              child: _FeedRow(
                sort: CatalogSort.hot,
                title: 'Популярное',
                icon: Icons.local_fire_department_rounded,
              ),
            ),

            SliverToBoxAdapter(
              child: authorsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (authors) => authors.isEmpty
                    ? const SizedBox.shrink()
                    : _AuthorsRow(authors: authors),
              ),
            ),

            const SliverToBoxAdapter(
              child: _FeedRow(
                sort: CatalogSort.new_,
                title: 'Новинки',
                icon: Icons.auto_awesome_rounded,
              ),
            ),

            // Место под плавающую панель снизу
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Приветствие, баланс жемчужин и поиск
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = ref.watch(profileProvider).valueOrNull?.displayName.trim();
    final payment = ref.watch(paymentProvider).valueOrNull;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null || name.isEmpty ? 'Привет!' : 'Привет, $name!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'С кем поговорим сегодня?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (payment != null)
          Pressable(
            onTap: () => context.push('/pearls?tab=packs'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PearlIcon(size: 16),
                  const SizedBox(width: 6),
                  Text(
                    formatCount(payment.pearls),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          onPressed: () => context.push('/search'),
          tooltip: 'Поиск',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }
}

// ── Баннеры ──────────────────────────────────────────────────────────

class _Banners extends StatefulWidget {
  const _Banners({required this.showWave});
  final bool showWave;

  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  int get _count => widget.showWave ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  // Листаем сами раз в 7 секунд; после ручного свайпа отсчёт начинается заново
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_controller.hasClients || _count < 2) return;
      _controller.animateToPage(
        (_page + 1) % _count,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final banners = [
      _Banner(
        image: 'assets/images/banner_mioko.webp',
        alignment: const Alignment(0.55, -0.55),
        badge: 'Mioko AI',
        title: 'Привет, я Миоко!',
        text: 'Заглядывай в Telegram и VK — там новости, идеи и вдохновение.',
        actions: [
          _BannerButton(
            icon: const BrandIcon.telegram(size: 16),
            label: 'Telegram',
            onTap: () => openUrl(context, Links.telegram),
          ),
          _BannerButton(
            icon: const BrandIcon.vk(size: 16),
            label: 'ВКонтакте',
            onTap: () => openUrl(context, Links.vk),
          ),
        ],
      ),
      if (widget.showWave)
        _Banner(
          image: 'assets/images/banner_wave.webp',
          alignment: const Alignment(0.75, -0.2),
          badge: 'Mioko Wave',
          title: 'Поймай волну',
          text: 'Общение без дневных лимитов и жемчужины для твоих историй.',
          actions: [
            _BannerButton(
              label: 'Подписаться на M.Wave',
              primary: true,
              onTap: () => context.push('/pearls'),
            ),
          ],
        ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _controller,
            // Число страниц может уменьшиться, когда подгрузится подписка
            itemCount: banners.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _restartTimer();
            },
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: banners[i],
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page.clamp(0, banners.length - 1) ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page.clamp(0, banners.length - 1)
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.image,
    required this.alignment,
    required this.badge,
    required this.title,
    required this.text,
    required this.actions,
  });

  final String image;
  final Alignment alignment;
  final String badge;
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // Текст лежит поверх картинки — поэтому белый, а не из темы
    const onImage = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover, alignment: alignment),
          // Затемнение слева, чтобы текст читался на любой картинке
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6061626),
                  Color(0x99061626),
                  Color(0x00061626),
                ],
                stops: [0, 0.5, 0.85],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: onImage.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: onImage,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: onImage,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onImage.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Wrap(spacing: 8, runSpacing: 6, children: actions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? icon;
  // Главная кнопка — акцентным цветом, остальные — «стеклянные»
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = primary ? scheme.onPrimary : Colors.white;

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? scheme.primary : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: fg, size: 16),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ленты ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon, this.onMore});

  final String title;
  final IconData icon;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 6, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Каталог'),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

const _cardWidth = 148.0;
const _cardHeight = 212.0;

class _FeedRow extends ConsumerWidget {
  const _FeedRow({required this.sort, required this.title, required this.icon});
  final CatalogSort sort;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroPrefix = 'home-${sort.name}';
    final header = _SectionTitle(
      title: title,
      icon: icon,
      onMore: () => context.go('/explore'),
    );

    return ref
        .watch(catalogFeedProvider(sort))
        // skipError: если поверх ошибки остались старые данные — показываем их, а не котика
        .when(
          skipError: true,
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, const _SkeletonRow()],
          ),
          // Одна лента упала, другая жива — маленький котик только на месте упавшей
          error: (e, _) => ErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(catalogFeedProvider(sort)),
          ),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    SizedBox(
                      height: _cardHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => _CatalogCard(
                          item: items[i],
                          heroTag: '$heroPrefix-${items[i].id}',
                        ),
                      ),
                    ),
                  ],
                ),
        );
  }
}

// Карточка: картинка на весь размер, имя и подпись — поверх затемнения снизу
class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.heroTag});
  final CatalogItem item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    // Текст поверх картинки — белый, от темы не зависит
    const onImage = Colors.white;

    return Pressable(
      onTap: () => openItem(context, item, heroTag),
      child: SizedBox(
        width: _cardWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: AvatarImage(avatar: item.avatar, initialSize: 36),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xD9000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    if (item.interactionsCount > 0)
                      _Chip(
                        icon: Icons.chat_bubble_rounded,
                        text: formatCount(item.interactionsCount),
                      ),
                    const Spacer(),
                    if (item.isStory)
                      const _Chip(
                        icon: Icons.auto_stories_rounded,
                        text: 'История',
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: onImage,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onImage.withValues(alpha: 0.78),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Полупрозрачная плашка поверх картинки
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x8C000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// Пока лента грузится — мягко мерцающие заглушки на месте карточек
class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _cardHeight,
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Container(
            width: _cardWidth,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Авторы ───────────────────────────────────────────────────────────

class _AuthorsRow extends StatelessWidget {
  const _AuthorsRow({required this.authors});
  final List<CatalogAuthor> authors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Популярные авторы',
          icon: Icons.emoji_events_rounded,
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: authors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _AuthorItem(author: authors[i]),
          ),
        ),
      ],
    );
  }
}

class _AuthorItem extends StatelessWidget {
  const _AuthorItem({required this.author});
  final CatalogAuthor author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Кольцо акцентного цвета вокруг аватара
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: author.avatarUrl != null
                        ? NetworkImage(author.avatarUrl!)
                        : null,
                    child: author.avatarUrl == null
                        ? Text(author.name.isNotEmpty ? author.name[0] : '?')
                        : null,
                  ),
                ),
              ),
              if (author.verified)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            author.name.isEmpty ? '@${author.username}' : author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 10,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                formatCount(author.interactions),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
