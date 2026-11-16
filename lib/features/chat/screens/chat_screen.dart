import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../shared/models/media_avatar.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/screens/item_detail_screen.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../providers/chat_room_provider.dart';
import '../providers/chats_provider.dart';
import '../widgets/message_text.dart';

// Что знаем о собеседнике заранее — чтобы шапка не ждала загрузки
class ChatArgs {
  final String name;
  final MediaAvatar avatar;
  final bool isStory;
  // id персонажа или истории — для перехода на их страницу
  final String? subjectId;

  const ChatArgs({
    required this.name,
    required this.avatar,
    required this.isStory,
    this.subjectId,
  });

  factory ChatArgs.fromChat(Chat c) => ChatArgs(
    name: c.characterName,
    avatar: c.avatar,
    isStory: c.isStory,
    subjectId: c.isStory ? c.storyId : c.characterId,
  );
}

void openChat(BuildContext context, String chatId, ChatArgs args) =>
    context.push('/chat/$chatId', extra: args);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.args});
  final String chatId;
  final ChatArgs? args;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final can = _input.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
    // Список перевёрнут: «конец» прокрутки — это самые старые сообщения
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(chatRoomProvider(widget.chatId).notifier).loadOlder();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatRoomProvider(widget.chatId).notifier).onNotice = _notice;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _notice(String text, {bool tideLimit = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: tideLimit
            ? SnackBarAction(
                label: 'M.Wave',
                onPressed: () => context.push('/pearls'),
              )
            : null,
      ),
    );
  }

  ChatArgs? get _args {
    if (widget.args != null) return widget.args;
    // Открыли по ссылке без данных — ищем чат в списке
    final chats = ref.watch(chatsProvider).valueOrNull;
    final c = chats?.where((c) => c.id == widget.chatId).firstOrNull;
    return c == null ? null : ChatArgs.fromChat(c);
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatRoomProvider(widget.chatId).notifier).send(text);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _openSubject(ChatArgs a) {
    if (a.subjectId == null) return;
    openItem(
      context,
      CatalogItem(
        itemType: a.isStory ? 'story' : 'character',
        id: a.subjectId!,
        name: a.name,
        avatar: a.avatar,
      ),
      'chat-${widget.chatId}',
    );
  }

  Future<void> _confirmDelete() async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: const Text(
          'Вся переписка удалится без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(chatRoomProvider(widget.chatId).notifier).deleteChat();
      if (!mounted) return;
      context.pop();
    } catch (_) {
      _notice('Не удалось удалить чат');
    }
  }

  // Меню действий с сообщением — всплывает рядом с местом нажатия,
  // как на сайте: Копировать / Редактировать / Новый чат отсюда | Пожаловаться / Удалить
  Future<void> _messageMenu(ChatMessage m, Offset at) async {
    final room = ref.read(chatRoomProvider(widget.chatId));
    final scheme = Theme.of(context).colorScheme;
    final hasText = m.content.trim().isNotEmpty;
    final saved = m.isSaved && !room.generating;

    final canCopy = hasText;
    final canEdit = hasText && saved;
    final canBranch = saved;
    final canReport = !m.fromUser && m.isSaved;
    final canDelete = saved && m.id != room.firstAssistantId;

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String title, {
      bool danger = false,
    }) {
      final color = danger ? scheme.error : null;
      return PopupMenuItem(
        value: value,
        height: 44,
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? scheme.error : scheme.primary),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: color)),
          ],
        ),
      );
    }

    HapticFeedback.selectionClick();
    // Точка нажатия → RelativeRect: меню само сдвинется, чтобы влезть в экран
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(at);
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        local & Size.zero,
        Offset.zero & overlay.size,
      ),
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      items: [
        if (canCopy) item('copy', Icons.copy_rounded, 'Копировать'),
        if (canEdit) item('edit', Icons.edit_outlined, 'Редактировать'),
        if (canBranch)
          item('branch', Icons.add_comment_outlined, 'Новый чат отсюда'),
        if ((canReport || canDelete) && (canCopy || canEdit || canBranch))
          const PopupMenuDivider(),
        if (canReport) item('report', Icons.flag_outlined, 'Пожаловаться'),
        if (canDelete)
          item('delete', Icons.delete_outline_rounded, 'Удалить', danger: true),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.content));
        _notice('Текст скопирован');
      case 'edit':
        await _editMessage(m);
      case 'branch':
        await _branchFrom(m);
      case 'report':
        await _reportMessage(m);
      case 'delete':
        await _deleteMessage(m);
    }
  }

  ChatRoomNotifier get _room =>
      ref.read(chatRoomProvider(widget.chatId).notifier);

  Future<void> _editMessage(ChatMessage m) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditMessageDialog(initial: m.content),
    );
    if (text == null || text.trim() == m.content.trim() || !mounted) return;
    try {
      await _room.editMessage(m.id, text.trim());
    } catch (e) {
      _notice(apiErrorMessage(e, 'Не удалось сохранить правку'));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
    bool danger = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    final ok = await _confirm(
      title: 'Удалить сообщение?',
      text: 'Оно исчезнет из переписки, а персонаж забудет то, что из него узнал',
      action: 'Удалить',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await _room.deleteMessage(m.id);
    } catch (e) {
      _notice(apiErrorMessage(e, 'Не удалось удалить сообщение'));
    }
  }

  Future<void> _branchFrom(ChatMessage m) async {
    final ok = await _confirm(
      title: 'Создать копию чата?',
      text:
          'Будет создана копия чата до этого момента, а текущий чат останется без изменений.',
      action: 'Создать',
    );
    if (!ok || !mounted) return;
    try {
      final newId = await _room.branchFrom(m.id);
      if (!mounted) return;
      _notice('Копия создана');
      // Как на сайте — сразу переходим в копию (старый чат остаётся в списке)
      context.pushReplacement('/chat/$newId', extra: _args);
    } catch (e) {
      _notice(apiErrorMessage(e, 'Не удалось создать копию'));
    }
  }

  Future<void> _reportMessage(ChatMessage m) async {
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReportSheet(),
    );
    if (r == null || !mounted) return;
    try {
      await _room.reportMessage(m.id, r.$1, r.$2);
      _notice('Спасибо, жалоба отправлена');
    } catch (e) {
      _notice(apiErrorMessage(e, 'Жалоба не отправилась'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final room = ref.watch(chatRoomProvider(widget.chatId));
    final args = _args;
    final notifier = ref.read(chatRoomProvider(widget.chatId).notifier);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: args == null ? null : () => _openSubject(args),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: args == null
                        ? ColoredBox(color: scheme.surfaceContainerHighest)
                        : AvatarImage(avatar: args.avatar, initialSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        args?.name ?? 'Чат',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          room.generating
                              ? 'печатает…'
                              : (args?.isStory ?? false)
                              ? 'история'
                              : 'персонаж',
                          key: ValueKey(room.generating),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: room.generating
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'profile' && args != null) _openSubject(args);
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (_) => [
              if (args?.subjectId != null)
                PopupMenuItem(
                  value: 'profile',
                  child: Text(
                    args!.isStory ? 'Страница истории' : 'Страница персонажа',
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Удалить чат',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: room.loading && room.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : room.error != null && room.messages.isEmpty
                ? ErrorView(error: room.error, onRetry: notifier.load)
                : _MessageList(
                    room: room,
                    controller: _scroll,
                    avatar: args?.avatar,
                    onLongPress: _messageMenu,
                    onRegenerate: notifier.regenerate,
                    onPickVariant: notifier.pickVariant,
                  ),
          ),
          if (room.tide case final tide? when tide.showWarning)
            _TideBanner(tide: tide),
          _Composer(
            controller: _input,
            canSend: _canSend && !room.generating,
            busy: room.generating,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.room,
    required this.controller,
    required this.avatar,
    required this.onLongPress,
    required this.onRegenerate,
    required this.onPickVariant,
  });

  final ChatRoomState room;
  final ScrollController controller;
  final MediaAvatar? avatar;
  final void Function(ChatMessage, Offset at) onLongPress;
  final VoidCallback onRegenerate;
  final ValueChanged<int> onPickVariant;

  @override
  Widget build(BuildContext context) {
    final msgs = room.messages;
    final extra = room.loadingOlder ? 1 : 0;

    // reverse: новые снизу, а при открытии сразу видно последнее сообщение
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: msgs.length + extra,
      itemBuilder: (context, i) {
        if (i == msgs.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final index = msgs.length - 1 - i;
        final m = msgs[index];
        final isLast = index == msgs.length - 1;
        // Аватар — только у первого из идущих подряд ответов персонажа
        final prev = index > 0 ? msgs[index - 1] : null;
        final showAvatar = !m.fromUser && (prev == null || prev.fromUser);

        return _Bubble(
          key: ValueKey(m.id),
          message: m,
          avatar: avatar,
          showAvatar: showAvatar,
          typing: isLast && !m.fromUser && room.waiting && m.content.isEmpty,
          // Под последним ответом — «ещё раз» и переключатель вариантов
          footer: isLast && !m.fromUser && !room.generating && msgs.length > 1
              ? _AnswerTools(
                  message: m,
                  canRegenerate: room.canRegenerate,
                  onRegenerate: onRegenerate,
                  onPickVariant: onPickVariant,
                )
              : null,
          onLongPress: (at) => onLongPress(m, at),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    required this.avatar,
    required this.showAvatar,
    required this.typing,
    required this.footer,
    required this.onLongPress,
  });

  final ChatMessage message;
  final MediaAvatar? avatar;
  final bool showAvatar;
  final bool typing;
  final Widget? footer;
  // Где нажали (глобальные координаты) — там и откроется меню
  final ValueChanged<Offset> onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.fromUser;
    final maxWidth = MediaQuery.sizeOf(context).width * (user ? 0.78 : 0.86);

    final bubble = GestureDetector(
      onLongPressStart: typing ? null : (d) => onLongPress(d.globalPosition),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: user ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(user ? 20 : 6),
            bottomRight: Radius.circular(user ? 6 : 20),
          ),
        ),
        child: typing
            ? const _TypingDots()
            : MessageText(
                message.content,
                color: user ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: showAvatar || user ? 10 : 4),
      child: Row(
        mainAxisAlignment: user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[
            SizedBox(
              width: 30,
              height: 30,
              child: showAvatar && avatar != null
                  ? ClipOval(
                      child: AvatarImage(avatar: avatar!, initialSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: user
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [bubble, ?footer],
            ),
          ),
        ],
      ),
    );
  }
}

// «Ответить заново» и стрелки между вариантами ответа
class _AnswerTools extends StatelessWidget {
  const _AnswerTools({
    required this.message,
    required this.canRegenerate,
    required this.onRegenerate,
    required this.onPickVariant,
  });

  final ChatMessage message;
  final bool canRegenerate;
  final VoidCallback onRegenerate;
  final ValueChanged<int> onPickVariant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = message.variants.length;
    final i = message.variant;
    const dense = VisualDensity(horizontal: -3, vertical: -3);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 1) ...[
            IconButton(
              visualDensity: dense,
              iconSize: 20,
              onPressed: i > 0 ? () => onPickVariant(i - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              '${i + 1} / $count',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            IconButton(
              visualDensity: dense,
              iconSize: 20,
              onPressed: i < count - 1 ? () => onPickVariant(i + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
          if (canRegenerate)
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: dense,
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Ещё вариант'),
            ),
        ],
      ),
    );
  }
}

// Три прыгающие точки, пока персонаж «думает»
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 22,
      width: 42,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                // Каждая точка подпрыгивает со сдвигом по фазе
                offset: Offset(
                  0,
                  -4 *
                      math.max(
                        0,
                        math.sin((_c.value - i * 0.18) * 2 * math.pi),
                      ),
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Предупреждение о дневном лимите без M.Wave
class _TideBanner extends StatelessWidget {
  const _TideBanner({required this.tide});
  final TideStatus tide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = tide.exhausted
        ? 'Сообщения на сегодня закончились'
        : 'Сегодня осталось сообщений: ${tide.left} из ${tide.limit}';
    return Material(
      color: scheme.tertiaryContainer,
      child: InkWell(
        onTap: () => context.push('/pearls'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.waves_rounded,
                size: 18,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                'M.Wave',
                style: TextStyle(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'Сообщение… *действие* курсивом',
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: canSend ? 1 : 0.9,
                child: IconButton.filled(
                  onPressed: canSend ? onSend : null,
                  style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
                  icon: busy
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Правка текста сообщения
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initial});
  final String initial;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _c,
          autofocus: true,
          minLines: 3,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ListenableBuilder(
          listenable: _c,
          builder: (context, _) => FilledButton(
            onPressed: _c.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _c.text),
            child: const Text('Сохранить'),
          ),
        ),
      ],
    );
  }
}

// Жалоба на ответ: причины и коды — как на сайте
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    ('obscene', 'Непристойность'),
    ('violence', 'Жестокость или угрозы'),
    ('impersonation', 'Выдаёт себя за реального человека'),
    ('illegal', 'Незаконное содержание'),
    ('other', 'Другое'),
  ];

  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        // Поднимаемся над клавиатурой
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Пожаловаться на ответ',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Модератор прочитает реплику и разберётся. Персонаж не узнает о жалобе.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              for (final (code, label) in _reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    _reason == code
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _reason == code
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  title: Text(label, style: theme.textTheme.bodyLarge),
                  onTap: () => setState(() => _reason = code),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Что именно не так — по желанию',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _reason == null
                          ? null
                          : () => Navigator.pop(context, (
                              _reason!,
                              _note.text.trim(),
                            )),
                      child: const Text('Отправить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
