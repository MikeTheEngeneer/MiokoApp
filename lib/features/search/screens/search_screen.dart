import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/pressable.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../../catalog/screens/item_detail_screen.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Подгружаем следующую страницу заранее, за ~600px до конца
      if (_scroll.position.extentAfter < 600) {
        ref.read(searchProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {}); // показать/скрыть крестик
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  void _search(String text) {
    _debounce?.cancel();
    ref.read(searchProvider.notifier).search(text);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _useSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    FocusScope.of(context).unfocus();
    setState(() {});
    _search(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: _search,
              onClear: () {
                _controller.clear();
                _onChanged('');
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _body(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(SearchState state) {
    if (state.query.isEmpty) {
      return _Suggestions(key: const ValueKey('hint'), onTap: _useSuggestion);
    }
    if (state.items.isEmpty && state.loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (state.items.isEmpty && state.error != null) {
      return ErrorView(
        key: const ValueKey('error'),
        error: state.error,
        onRetry: () => _search(state.query),
      );
    }
    if (state.items.isEmpty) {
      return _Message(
        key: const ValueKey('empty'),
        icon: Icons.search_off_rounded,
        text: 'По запросу «${state.query}» ничего не нашлось',
      );
    }
    return _Results(
      key: ValueKey('results-${state.query}'),
      state: state,
      scroll: _scroll,
      onRetry: () => ref.read(searchProvider.notifier).loadMore(retry: true),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: 'Персонажи и истории',
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({super.key, required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Попробуй поискать',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in catalogGenres)
              ActionChip(
                label: Text(g),
                onPressed: () => onTap(g),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: scheme.outlineVariant),
                backgroundColor: scheme.surfaceContainer,
              ),
          ],
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.state,
    required this.scroll,
    required this.onRetry,
  });

  final SearchState state;
  final ScrollController scroll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (state.total != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Найдено: ${state.total}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, i) => _ResultCard(item: state.items[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
            child: Center(
              child: state.loading
                  ? const CircularProgressIndicator()
                  : state.error != null
                  ? TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        isOfflineError(state.error)
                            ? 'Нет интернета — повторить'
                            : 'Не удалось загрузить ещё — повторить',
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

// Картинка на всю карточку, имя поверх затемнения снизу — больше места под обложку
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final heroTag = 'search-${item.id}';
    return Pressable(
      onTap: () => openItem(context, item, heroTag),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: AvatarImage(avatar: item.avatar, initialSize: 40),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [Colors.transparent, Color(0xD9000000)],
                ),
              ),
            ),
            if (item.isStory)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'История',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
