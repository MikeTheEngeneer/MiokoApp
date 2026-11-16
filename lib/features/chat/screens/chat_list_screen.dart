import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/pressable.dart';
import '../models/chat.dart';
import '../providers/chats_provider.dart';
import 'chat_screen.dart';

enum _Filter { all, characters, stories }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Chat c) {
    if (_filter == _Filter.characters && c.isStory) return false;
    if (_filter == _Filter.stories && !c.isStory) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.characterName.toLowerCase().contains(q) ||
        c.title.toLowerCase().contains(q) ||
        (c.lastMessage?.toLowerCase().contains(q) ?? false);
  }

  void _open(Chat c) => openChat(context, c.id, ChatArgs.fromChat(c));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatsAsync = ref.watch(chatsProvider);
    final all = chatsAsync.valueOrNull;
    final top = MediaQuery.paddingOf(context).top;
    // Снизу: плавающая панель вкладок + место под кнопку «Новый чат»
    final bottom = 88 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Чаты',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (all != null && all.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${all.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Поиск и фильтры нужны, только когда есть что искать
          if (all != null && all.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Поиск по чатам',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                children: [
                  for (final (f, label, count) in [
                    (_Filter.all, 'Все', all.length),
                    (
                      _Filter.characters,
                      'Персонажи',
                      all.where((c) => !c.isStory).length,
                    ),
                    (
                      _Filter.stories,
                      'Истории',
                      all.where((c) => c.isStory).length,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterPill(
                        label: label,
                        count: count,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ],

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: chatsAsync.when(
                skipLoadingOnRefresh: true,
                loading: () => const _Skeleton(key: ValueKey('loading')),
                error: (e, _) => Padding(
                  key: const ValueKey('error'),
                  padding: EdgeInsets.only(bottom: bottom),
                  child: ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(chatsProvider),
                  ),
                ),
                data: (chats) {
                  if (chats.isEmpty) {
                    return _Empty(
                      key: const ValueKey('empty'),
                      bottom: bottom,
                      icon: Icons.forum_outlined,
                      title: 'Чатов пока нет',
                      text: 'Выбери персонажа или историю — и начни разговор',
                      action: FilledButton.icon(
                        onPressed: () => context.go('/explore'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Открыть каталог'),
                      ),
                    );
                  }
                  // Свежие сверху — иначе заголовки дней будут повторяться
                  final shown = chats.where(_matches).toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  final rows = _withHeaders(shown);

                  return RefreshIndicator(
                    key: const ValueKey('list'),
                    onRefresh: () => ref.refresh(chatsProvider.future),
                    child: shown.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 280,
                                child: _Empty(
                                  bottom: 0,
                                  icon: Icons.search_off_rounded,
                                  title: 'Ничего не нашлось',
                                  text: 'Попробуй другое слово или фильтр',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, bottom),
                            itemCount: rows.length,
                            itemBuilder: (context, i) => switch (rows[i]) {
                              final String header => _DayHeader(header),
                              final Chat chat => _AnimatedItem(
                                key: ValueKey(chat.id),
                                index: i,
                                child: _ChatCard(
                                  chat: chat,
                                  onTap: () => _open(chat),
                                ),
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Новый чат начинается с выбора персонажа в каталоге
        onPressed: () => context.go('/explore'),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Новый чат'),
      ),
    );
  }
}

// Вставляет в список заголовки «Сегодня / Вчера / На этой неделе / Раньше»
List<Object> _withHeaders(List<Chat> chats) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String group(DateTime dt) {
    final local = dt.toLocal();
    final days = today
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (days <= 0) return 'Сегодня';
    if (days == 1) return 'Вчера';
    if (days < 7) return 'На этой неделе';
    return 'Раньше';
  }

  final rows = <Object>[];
  String? last;
  for (final c in chats) {
    final g = group(c.updatedAt);
    if (g != last) rows.add(last = g);
    rows.add(c);
  }
  return rows;
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  String two(int n) => n.toString().padLeft(2, '0');
  if (days <= 0) return '${two(local.hour)}:${two(local.minute)}';
  if (days == 1) return 'вчера';
  if (days < 7) {
    return const ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'][local.weekday - 1];
  }
  final date = '${two(local.day)}.${two(local.month)}';
  return local.year == now.year ? date : '$date.${local.year % 100}';
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: fg.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Сервер шлёт разметку *действий* — в превью звёздочки не нужны
    final preview = chat.lastMessage
        ?.replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Название чата показываем, только если оно что-то добавляет к имени
    final title = chat.title.trim();
    final showTitle = title.isNotEmpty && title != chat.characterName.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AvatarImage(avatar: chat.avatar),
                      ),
                    ),
                    if (chat.isStory)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surfaceContainerHigh,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 11,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.characterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(chat.updatedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (showTitle) ...[
                        const SizedBox(height: 1),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        preview == null || preview.isEmpty
                            ? 'Сообщений пока нет'
                            : preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    super.key,
    required this.bottom,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final double bottom;
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.30),
                    scheme.primary.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(icon, size: 38, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

// Пока чаты грузятся — мерцающие заглушки на месте карточек
class _Skeleton extends StatefulWidget {
  const _Skeleton({super.key});

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
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
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          height: 82,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// Stagger-анимация: каждый элемент появляется чуть позже предыдущего
class _AnimatedItem extends StatefulWidget {
  const _AnimatedItem({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_AnimatedItem> createState() => _AnimatedItemState();
}

class _AnimatedItemState extends State<_AnimatedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Задержка зависит от позиции, но не больше 400мс суммарно
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 400));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
