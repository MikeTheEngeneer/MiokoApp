import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/widgets/error_view.dart';
import '../models/lorebook.dart';
import '../providers/lorebooks_provider.dart';
import '../widgets/lorebook_tile.dart';

// Страница лорбука: обложка, теги, описание, где работает, записи
class LorebookScreen extends ConsumerWidget {
  const LorebookScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lorebookProvider(id));
    final loaded = async.valueOrNull != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Лорбук')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(lorebookProvider(id)),
        ),
        data: (lb) => RefreshIndicator(
          onRefresh: () => ref.refresh(lorebookProvider(id).future),
          child: _Body(lb: lb),
        ),
      ),
      bottomNavigationBar: loaded
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _ConnectBar(lorebookId: id),
            )
          : null,
    );
  }
}

// Низ страницы. Не подключён — одна кнопка «Подключить».
// Подключён — строка «Подключён: …» и две кнопки: «Отключить» и «Изменить»
class _ConnectBar extends ConsumerStatefulWidget {
  const _ConnectBar({required this.lorebookId});
  final String lorebookId;

  @override
  ConsumerState<_ConnectBar> createState() => _ConnectBarState();
}

class _ConnectBarState extends ConsumerState<_ConnectBar> {
  bool _busy = false;

  void _openSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ConnectLorebookSheet(lorebookId: widget.lorebookId),
  );

  // Подключён в одном месте — отключаем сразу, в нескольких — даём выбрать
  Future<void> _disconnect(List<LorePlace> places) async {
    if (places.length != 1) return _openSheet();
    setState(() => _busy = true);
    try {
      await ref
          .read(lorebookActionsProvider)
          .setConnected(
            place: places.single,
            lorebookId: widget.lorebookId,
            connect: false,
          );
      await ref.read(lorebookTargetsProvider(widget.lorebookId).future);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Лорбук отключён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, 'Не удалось отключить'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final targets = ref
        .watch(lorebookTargetsProvider(widget.lorebookId))
        .valueOrNull;
    final names = targets?.connectedTo ?? const <String>[];
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    if (targets == null || names.isEmpty) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: shape,
        ),
        onPressed: _openSheet,
        icon: const Icon(Icons.link_rounded),
        label: const Text('Подключить'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Подключён: ${names.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: shape,
                  foregroundColor: scheme.error,
                ),
                onPressed: _busy
                    ? null
                    : () => _disconnect(targets.connectedPlaces),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off_rounded),
                label: const Text('Отключить'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: shape,
                ),
                onPressed: _busy ? null : _openSheet,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Изменить'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.lb});
  final LorebookDetail lb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = lb.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LorebookCover(url: s.coverUrl, width: 110),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title.isEmpty ? 'Без названия' : s.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (s.authorUsername != null) ...[
                    const SizedBox(height: 6),
                    AuthorLine(
                      username: s.authorUsername!,
                      verified: s.authorVerified,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (lb.own)
                        s.isPublic
                            ? 'Опубликован'
                            : 'Приватный — видишь только ты',
                      entriesLabel(s.entriesCount),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (lb.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in lb.tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t, style: theme.textTheme.labelMedium),
                ),
            ],
          ),
        ],

        if (lb.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            lb.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],

        _Header('Работает в карточках'),
        if (lb.cards.isEmpty)
          _Hint('Пока ни к одной карточке не подключён.')
        else
          for (final c in lb.cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    c.isStory
                        ? Icons.auto_stories_outlined
                        : Icons.person_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${c.title.isEmpty ? 'Без названия' : c.title}'
                      ' · ${c.isStory ? 'история' : 'персонаж'}'
                      '${c.isPublic ? '' : ' · приватная'}',
                    ),
                  ),
                ],
              ),
            ),

        _Header('Записи'),
        if (s.entriesHidden && lb.entries.isEmpty)
          _Hint(
            'Автор скрыл записи. Персонаж мир знает, а тексты видит только автор.',
          )
        else if (lb.entries.isEmpty)
          _Hint('Записей пока нет.')
        else
          for (final e in lb.entries) _EntryTile(entry: e),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final LoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = switch (entry.kind) {
      LoreEntryKind.always => 'всегда',
      LoreEntryKind.semantic => 'по смыслу',
      LoreEntryKind.keys =>
        entry.keys.isEmpty ? 'нет ключевых слов' : entry.keys.join(', '),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            entry.title.isEmpty ? 'Без названия' : entry.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [kind, if (entry.disabled) 'выключена'].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: entry.kind == LoreEntryKind.always
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedAlignment: Alignment.topLeft,
          children: [
            SelectableText(
              entry.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.4,
    ),
  );
}

// Окно «Подключить лорбук»: ко всем моим чатам и к персонам — как на сайте
class ConnectLorebookSheet extends ConsumerStatefulWidget {
  const ConnectLorebookSheet({super.key, required this.lorebookId});
  final String lorebookId;

  @override
  ConsumerState<ConnectLorebookSheet> createState() =>
      _ConnectLorebookSheetState();
}

class _ConnectLorebookSheetState extends ConsumerState<ConnectLorebookSheet> {
  // 'mine' или 'persona:<id>' — что сейчас переключается
  String? _busy;

  Future<void> _toggle(String key, LorePlace place, bool connect) async {
    setState(() => _busy = key);
    try {
      await ref
          .read(lorebookActionsProvider)
          .setConnected(
            place: place,
            lorebookId: widget.lorebookId,
            connect: connect,
          );
      await ref.read(lorebookTargetsProvider(widget.lorebookId).future);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              connect ? 'Не удалось подключить' : 'Не удалось отключить',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(lorebookTargetsProvider(widget.lorebookId));

    final header = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => ErrorView(
          error: e,
          compact: true,
          onRetry: () =>
              ref.invalidate(lorebookTargetsProvider(widget.lorebookId)),
        ),
        data: (t) => ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Подключить лорбук',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Отметь, где персонаж будет знать этот мир. Подключается сразу.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),

            if (t.mine case final mine?) ...[
              const SizedBox(height: 20),
              Text('Ко всем моим чатам', style: header),
              const SizedBox(height: 4),
              _SwitchRow(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                title: 'Все мои чаты',
                subtitle: mine.isFull
                    ? 'Уже подключено ${mine.count} из ${mine.limit} — сперва '
                          'отключи один в «Настройки → Лорбуки»'
                    : mine.connected
                    ? 'Подключён — работает в каждом твоём чате'
                    : 'С любым персонажем и историей · '
                          'лорбуков ${mine.count} из ${mine.limit}',
                value: mine.connected,
                busy: _busy == 'mine',
                onChanged: mine.isFull || _busy != null
                    ? null
                    : (v) => _toggle('mine', allChatsPlace, v),
              ),
            ],

            const SizedBox(height: 20),
            Text('К персоне', style: header),
            const SizedBox(height: 4),
            if (t.personas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'У тебя пока нет персон — их заводят в «Настройки → Персоны».',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final p in t.personas)
                _SwitchRow(
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: p.avatarUrl != null
                        ? NetworkImage(p.avatarUrl!)
                        : null,
                    child: p.avatarUrl == null
                        ? Text(p.name.isNotEmpty ? p.name[0] : '?')
                        : null,
                  ),
                  title: p.name.isEmpty ? 'Персона' : p.name,
                  subtitle: p.connected
                      ? 'Подключён — работает во всех чатах с этой персоной'
                      : p.count > 0
                      ? 'Подключён другой лорбук — этот его заменит'
                      : 'Персона — один лорбук',
                  value: p.connected,
                  busy: _busy == 'persona:${p.publicId}',
                  onChanged: _busy != null
                      ? null
                      : (v) => _toggle(
                          'persona:${p.publicId}',
                          personaPlace(p.publicId),
                          v,
                        ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: leading,
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Switch(value: value, onChanged: onChanged),
  );
}
