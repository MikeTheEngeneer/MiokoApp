import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/error_view.dart';
import '../../catalog/screens/item_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorsAsync = ref.watch(catalogAuthorsProvider);
    final hot = ref.watch(catalogFeedProvider(CatalogSort.hot));
    final fresh = ref.watch(catalogFeedProvider(CatalogSort.new_));
    final top = MediaQuery.of(context).padding.top;

    void retry() {
      ref.invalidate(catalogFeedProvider);
      ref.invalidate(catalogAuthorsProvider);
    }

    // Обе ленты упали — показываем одну ошибку на весь экран, а не две одинаковые
    final failed =
        hot.hasError && !hot.hasValue && fresh.hasError && !fresh.hasValue;

    return RefreshIndicator(
      onRefresh: () async {
        retry();
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
            SliverPadding(
              padding: EdgeInsets.only(
                top: top + 16,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Главная',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: authorsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (authors) => _AuthorsRow(authors: authors),
              ),
            ),

            const SliverToBoxAdapter(
              child: _FeedRow(sort: CatalogSort.hot, title: 'Популярное'),
            ),
            const SliverToBoxAdapter(
              child: _FeedRow(sort: CatalogSort.new_, title: 'Новинки'),
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

const _sectionTitleStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);

class _FeedRow extends ConsumerWidget {
  const _FeedRow({required this.sort, required this.title});
  final CatalogSort sort;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroPrefix = 'home-${sort.name}';
    return ref
        .watch(catalogFeedProvider(sort))
        .when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: _sectionTitleStyle),
              ),
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          // Одна лента упала, другая жива — маленький котик только на месте упавшей
          error: (e, _) => ErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(catalogFeedProvider(sort)),
          ),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : _CatalogRow(items: items, title: title, heroPrefix: heroPrefix),
        );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.items,
    required this.heroPrefix,
    this.title,
  });
  final List<CatalogItem> items;
  final String heroPrefix;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title!, style: _sectionTitleStyle),
          ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, i) => _CatalogCard(
              item: items[i],
              heroTag: '$heroPrefix-${items[i].id}',
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.heroTag});
  final CatalogItem item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => openItem(context, item, heroTag),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: heroTag,
                  child: AvatarImage(avatar: item.avatar, initialSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _AuthorsRow extends StatelessWidget {
  const _AuthorsRow({required this.authors});
  final List<CatalogAuthor> authors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Популярные авторы', style: _sectionTitleStyle),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: authors.length,
            itemBuilder: (context, i) {
              final a = authors[i];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage: a.avatarUrl != null
                          ? NetworkImage(a.avatarUrl!)
                          : null,
                      child: a.avatarUrl == null
                          ? Text(a.name.isNotEmpty ? a.name[0] : '?')
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.name,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      formatCount(a.interactions),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
