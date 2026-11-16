import 'package:material_ui/material_ui.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat.dart';
import '../../../shared/models/media_avatar.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/chats_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Чаты')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: chatsAsync.when(
          loading: () => const Center(
            key: ValueKey('loading'),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => ErrorView(
            key: const ValueKey('error'),
            error: e,
            onRetry: () => ref.invalidate(chatsProvider),
          ),
          data: (chats) => chats.isEmpty
              ? const Center(
                  key: ValueKey('empty'),
                  child: Text('Чатов пока нет'),
                )
              : material.RefreshIndicator(
                  key: const ValueKey('list'),
                  onRefresh: () => ref.refresh(chatsProvider.future),
                  child: ListView.separated(
                    // Снизу: высота плавающей панели + место под кнопку «Новый чат»
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: 88 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) => _AnimatedItem(
                      index: i,
                      child: _ChatTile(chat: chats[i]),
                    ),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Новый чат'),
      ),
    );
  }
}

// Stagger-анимация: каждый элемент появляется чуть позже предыдущего
class _AnimatedItem extends StatefulWidget {
  const _AnimatedItem({required this.index, required this.child});
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

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(avatar: chat.avatar),
      title: Text(
        chat.characterName,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chat.lastMessage != null
          ? Text(
              chat.lastMessage!.replaceAll(RegExp(r'\*+'), '').trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            )
          : null,
      trailing: Text(
        _formatTime(chat.updatedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {},
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return '${diff.inHours} ч';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar});

  final MediaAvatar avatar;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 52,
    child: ClipOval(child: AvatarImage(avatar: avatar)),
  );
}
