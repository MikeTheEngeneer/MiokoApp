import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/error_view.dart';
import '../models/lorebook.dart';
import '../providers/lorebooks_provider.dart';

// Вертикальная обложка 2:3 — такие загружают на сайте
class LorebookCover extends StatelessWidget {
  const LorebookCover({super.key, required this.url, this.width = 48});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.menu_book_rounded,
        size: width * 0.45,
        color: scheme.onSurfaceVariant,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.18),
      child: SizedBox(
        width: width,
        height: width * 1.5,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: (width * 3).round(),
                errorBuilder: (_, _, _) => placeholder,
                frameBuilder: (_, child, frame, sync) =>
                    sync || frame != null ? child : placeholder,
              ),
      ),
    );
  }
}

class LorebookTile extends StatelessWidget {
  const LorebookTile({
    super.key,
    required this.lorebook,
    this.onTap,
    this.trailing,
    this.showAuthor = true,
  });

  final LorebookSummary lorebook;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = [
      if (!lorebook.isPublic) 'приватный',
      if (lorebook.entriesCount > 0) entriesLabel(lorebook.entriesCount),
      if (lorebook.entriesHidden) 'записи скрыты',
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              LorebookCover(url: lorebook.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lorebook.title.isEmpty ? 'Без названия' : lorebook.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showAuthor && lorebook.authorUsername != null) ...[
                      const SizedBox(height: 2),
                      AuthorLine(
                        username: lorebook.authorUsername!,
                        verified: lorebook.authorVerified,
                      ),
                    ],
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class AuthorLine extends StatelessWidget {
  const AuthorLine({super.key, required this.username, required this.verified});

  final String username;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '@$username',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
        ),
        if (verified) ...[
          const SizedBox(width: 3),
          Icon(Icons.verified_rounded, size: 13, color: scheme.primary),
        ],
      ],
    );
  }
}

// Поиск опубликованных лорбуков. Не скроллится сам — кладётся в список родителя.
// trailingBuilder рисует справа кнопку действия (подключить, выбрать)
class PublicLorebookSearch extends ConsumerStatefulWidget {
  const PublicLorebookSearch({
    super.key,
    required this.onOpen,
    this.trailingBuilder,
    this.exclude = const {},
  });

  final void Function(LorebookSummary) onOpen;
  final Widget Function(LorebookSummary)? trailingBuilder;
  // Уже показанные выше (подключённые, свои) — не дублируем
  final Set<String> exclude;

  @override
  ConsumerState<PublicLorebookSearch> createState() =>
      _PublicLorebookSearchState();
}

class _PublicLorebookSearchState extends ConsumerState<PublicLorebookSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  // Ответ на устаревший запрос (уже напечатали дальше) отбрасываем
  int _generation = 0;

  String _query = '';
  List<LorebookSummary> _items = [];
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(lorebookActionsProvider).search(_query);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = page.lorebooks;
        _next = page.next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(lorebookActionsProvider)
          .search(_query, before: _next);
      if (!mounted || gen != _generation) return;
      final seen = _items.map((e) => e.publicId).toSet();
      setState(() {
        _items = [
          ..._items,
          ...page.lorebooks.where((e) => seen.add(e.publicId)),
        ];
        _next = page.next;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOfflineError(e) ? 'Нет интернета' : 'Не удалось загрузить',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (text.trim() == _query.trim()) return;
      _query = text;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items
        .where((e) => !widget.exclude.contains(e.publicId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Название, описание или @ник',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          ErrorView(error: _error, onRetry: _load, compact: true)
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _query.trim().startsWith('@')
                  ? 'У ${_query.trim()} нет опубликованных лорбуков — или такого ника нет'
                  : _query.trim().isNotEmpty
                  ? 'Ничего не нашлось'
                  : 'Опубликованных лорбуков других авторов пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          for (final lb in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LorebookTile(
                lorebook: lb,
                onTap: () => widget.onOpen(lb),
                trailing: widget.trailingBuilder?.call(lb),
              ),
            ),
          if (_next != null)
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Загружаю…' : 'Показать ещё'),
              ),
            ),
        ],
      ],
    );
  }
}

// Кнопка справа в строке: «Подключить» ↔ «Отключить»
class ConnectButton extends StatelessWidget {
  const ConnectButton({
    super.key,
    required this.connected,
    required this.onPressed,
    this.busy = false,
    this.label = 'Подключить',
    this.connectedLabel = 'Отключить',
  });

  final bool connected;
  final bool busy;
  // null — кнопка неактивна (например, лимит исчерпан)
  final VoidCallback? onPressed;
  final String label;
  final String connectedLabel;

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
    final onTap = busy ? null : onPressed;
    final child = busy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(connected ? connectedLabel : label);
    return connected
        ? FilledButton.tonalIcon(
            style: style,
            onPressed: onTap,
            icon: busy ? null : const Icon(Icons.link_off_rounded, size: 18),
            label: child,
          )
        : OutlinedButton(style: style, onPressed: onTap, child: child);
  }
}
