import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/pressable.dart';
import '../../catalog/screens/item_detail_screen.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(catalogSectionsProvider);
    final top = MediaQuery.of(context).padding.top;

    return RefreshIndicator(
      onRefresh: () async {
        // Новый seed → новая перетасовка карточек; секции пересоберутся сами
        ref.invalidate(catalogSeedProvider);
        await ref
            .read(catalogSectionsProvider.future)
            .catchError((_) => <String, List<CatalogItem>>{});
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: top + 16,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Каталог',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverToBoxAdapter(child: _SearchBar()),
          ),

          sectionsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(catalogSeedProvider),
              ),
            ),
            data: (sections) {
              final entries = sections.entries.toList();
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _SectionRow(
                    title: entries[i].key,
                    items: entries[i].value,
                  ),
                  childCount: entries.length,
                ),
              );
            },
          ),

          // Место под плавающую панель снизу
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/search'),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search, color: scheme.onSurfaceVariant, size: 22),
              const SizedBox(width: 10),
              Text(
                'Поиск персонажей и историй…',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.title, required this.items});
  final String title;
  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  'Все',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, i) => _SectionCard(
                item: items[i],
                heroTag: 'explore-$title-${items[i].id}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.item, required this.heroTag});
  final CatalogItem item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => openItem(context, item, heroTag),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Hero(
                  tag: heroTag,
                  child: AvatarImage(avatar: item.avatar, initialSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
