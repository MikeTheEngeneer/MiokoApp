import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../../core/api/api_error.dart';
import '../providers/catalog_provider.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/catalog_item.dart';
import '../../chat/providers/chat_room_provider.dart';
import '../../chat/screens/chat_screen.dart';

// Hero-тег уникален для каждой карточки: один персонаж может стоять в нескольких лентах сразу
class ItemDetailArgs {
  final CatalogItem item;
  final String heroTag;
  const ItemDetailArgs(this.item, this.heroTag);
}

void openItem(BuildContext context, CatalogItem item, String heroTag) =>
    context.push('/item/${item.id}', extra: ItemDetailArgs(item, heroTag));

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.args});
  final ItemDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (isStory: args.item.isStory, id: args.item.id);
    // Сразу показываем данные из каталога, свежие подменяют их, когда придут
    final item = ref.watch(itemDetailProvider(key)).valueOrNull ?? args.item;
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final userName = ref.watch(profileProvider).valueOrNull?.displayName;

    String fill(String text) => text
        .replaceAll('{{user}}', userName ?? 'ты')
        .replaceAll('{{char}}', item.name);

    Future<void> refresh() async {
      try {
        ref.invalidate(itemDetailProvider(key));
        await ref.read(itemDetailProvider(key).future);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiErrorMessage(e, 'Не удалось обновить'))),
          );
        }
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          // Чтобы свайп вниз работал, даже если контента меньше экрана
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _CoverAppBar(
              item: item,
              heroTag: args.heroTag,
              expandedHeight: size.height * 0.55,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(item: item),
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final t in item.tags) _TagChip(label: t)],
                    ),
                  ],
                  if (item.authorName != null) ...[
                    const SizedBox(height: 16),
                    _AuthorRow(item: item),
                  ],
                  if (item.description != null)
                    _Section(title: 'Описание', text: fill(item.description!)),
                  if (item.appearance != null)
                    _Section(title: 'Внешность', text: fill(item.appearance!)),
                  if (item.personality != null)
                    _Section(title: 'Характер', text: fill(item.personality!)),
                  if (item.backstory != null)
                    _Section(title: 'Предыстория', text: fill(item.backstory!)),
                  if (item.firstMeeting != null)
                    _Section(
                      title: 'Первая встреча',
                      text: fill(item.firstMeeting!),
                      initiallyExpanded: true,
                    ),
                  if (item.description == null &&
                      item.personality == null &&
                      item.firstMeeting == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'Описания пока нет',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _StartChatBar(item: item),
    );
  }
}

class _CoverAppBar extends StatelessWidget {
  const _CoverAppBar({
    required this.item,
    required this.heroTag,
    required this.expandedHeight,
  });

  final CatalogItem item;
  final String heroTag;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _GlassButton(icon: Icons.arrow_back, onTap: () => context.pop()),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final collapsed = kToolbarHeight + topInset;
          // 1 — шапка раскрыта, 0 — свернулась в обычный app bar
          final t = ((c.maxHeight - collapsed) / (expandedHeight - collapsed))
              .clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: AvatarImage(avatar: item.avatar, initialSize: 96),
              ),
              // Картинка мягко перетекает в фон страницы снизу
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.25, 0.65, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      scheme.surface.withValues(alpha: 0.4),
                      scheme.surface,
                    ],
                  ),
                ),
              ),
              // При сворачивании шапка заливается фоном, и проявляется имя
              IgnorePointer(
                child: Opacity(
                  opacity: (1 - t * 2.5).clamp(0.0, 1.0),
                  child: ColoredBox(
                    color: scheme.surface,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: topInset,
                        left: 64,
                        right: 16,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, color: scheme.onSurface, size: 22),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.isStory
                    ? Icons.auto_stories_outlined
                    : Icons.person_outline,
                size: 14,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Text(
                item.isStory ? 'История' : 'Персонаж',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (item.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            item.subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        // AnimatedSwitcher — числа мягко сменяются, когда приходят свежие данные
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey((
              item.interactionsCount,
              item.likesCount,
              item.collectionsCount,
            )),
            children: [
              _Stat(
                icon: Icons.chat_bubble_outline,
                value: formatCount(item.interactionsCount),
              ),
              if (item.likesCount > 0) ...[
                const SizedBox(width: 18),
                _Stat(
                  icon: Icons.favorite_border,
                  value: formatCount(item.likesCount),
                ),
              ],
              if (item.collectionsCount > 0) ...[
                const SizedBox(width: 18),
                _Stat(
                  icon: Icons.bookmark_border,
                  value: formatCount(item.collectionsCount),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = item.authorName!;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.surfaceContainerHighest,
          backgroundImage: item.authorAvatar != null
              ? NetworkImage(item.authorAvatar!)
              : null,
          child: item.authorAvatar == null
              ? Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(fontSize: 13),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Автор',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
              Text(
                item.authorUsername != null
                    ? '$name · @${item.authorUsername}'
                    : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.text,
    this.initiallyExpanded = false,
  });

  final String title;
  final String text;
  final bool initiallyExpanded;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  static const _collapsedLines = 6;
  late bool _expanded = widget.initiallyExpanded;

  bool get _isLong =>
      widget.text.length > 320 || '\n'.allMatches(widget.text).length > 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyLarge!.copyWith(height: 1.5, fontSize: 15);
    final collapsed = _isLong && !_expanded;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Text.rich(
              roleplaySpan(widget.text, base, scheme.onSurfaceVariant),
              maxLines: collapsed ? _collapsedLines : null,
              overflow: collapsed ? TextOverflow.fade : TextOverflow.visible,
            ),
          ),
          if (_isLong)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(_expanded ? 'Свернуть' : 'Показать полностью'),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// *действия* в ролевых текстах — курсивом и приглушённым цветом, как на сайте
TextSpan roleplaySpan(String text, TextStyle base, Color actionColor) {
  final spans = <TextSpan>[];
  final re = RegExp(r'\*([^*]+)\*');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(
      TextSpan(
        text: m.group(1),
        style: TextStyle(fontStyle: FontStyle.italic, color: actionColor),
      ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: base, children: spans);
}

// «Начать чат»: открывает существующий чат с персонажем или создаёт новый
class _StartChatBar extends ConsumerStatefulWidget {
  const _StartChatBar({required this.item});
  final CatalogItem item;

  @override
  ConsumerState<_StartChatBar> createState() => _StartChatBarState();
}

class _StartChatBarState extends ConsumerState<_StartChatBar> {
  bool _busy = false;

  Future<void> _start() async {
    final item = widget.item;
    setState(() => _busy = true);
    try {
      final chatId = await openChatWith(
        ref,
        isStory: item.isStory,
        id: item.id,
      );
      if (!mounted) return;
      openChat(
        context,
        chatId,
        ChatArgs(
          name: item.name,
          avatar: item.avatar,
          isStory: item.isStory,
          subjectId: item.id,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, 'Не удалось открыть чат'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _start,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      item.isStory
                          ? Icons.play_arrow_rounded
                          : Icons.chat_bubble_rounded,
                    ),
              label: Text(item.isStory ? 'Начать историю' : 'Начать чат'),
            ),
          ),
        ),
      ),
    );
  }
}
