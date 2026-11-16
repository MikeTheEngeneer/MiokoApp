import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/error_view.dart';
import '../providers/notification_prefs_provider.dart';

// Виды уведомлений — названия и подсказки с сайта
const _kinds = [
  (
    key: 'chat',
    icon: Icons.chat_bubble_outline_rounded,
    title: 'Ответы в чатах',
    hint: 'Персонаж или история ответили тебе',
  ),
  (
    key: 'comment',
    icon: Icons.mode_comment_outlined,
    title: 'Комментарии',
    hint: 'Новые комментарии к твоим работам',
  ),
  (
    key: 'reply',
    icon: Icons.reply_rounded,
    title: 'Ответы на комментарии',
    hint: 'Тебе ответили на комментарий',
  ),
  (
    key: 'moderation',
    icon: Icons.verified_user_outlined,
    title: 'Модерация',
    hint: 'Решения по твоим работам и лорбукам',
  ),
  (
    key: 'new_work',
    icon: Icons.auto_awesome_outlined,
    title: 'Новые работы авторов',
    hint: 'От авторов, на которых ты подписан',
  ),
  (
    key: 'gift',
    icon: Icons.card_giftcard_rounded,
    title: 'Подарки',
    hint: 'Тебе подарили подарок',
  ),
  (
    key: 'tip',
    icon: Icons.diamond_outlined,
    title: 'Жемчужины работам',
    hint: 'Твоей работе подарили жемчужины',
  ),
  (
    key: 'lore_split',
    icon: Icons.menu_book_outlined,
    title: 'Документы лорбуков',
    hint: 'Документ для лорбука разложен на записи',
  ),
];

// «Настройки → Уведомления»: общий выключатель и восемь видов, как на сайте
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(notificationPrefsProvider);

    Future<void> toggle(String key, bool value) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(notificationPrefsProvider.notifier).set(key, value);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить — попробуй ещё раз'),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.read(notificationPrefsProvider.notifier).load(),
        ),
        data: (prefs) {
          final all = prefs['all'] ?? false;
          final onCount = _kinds.where((k) => prefs[k.key] ?? false).length;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _MasterCard(
                on: all,
                subtitle: all
                    ? 'Включено видов: $onCount из ${_kinds.length}'
                    : 'На телефон не придёт ни одного уведомления',
                onChanged: (v) => toggle('all', v),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
                child: Text(
                  'Присылать уведомления',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Пока общий выключатель выключен, виды приглушены и не нажимаются
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: all ? 1 : 0.45,
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, k) in _kinds.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 66,
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        _KindTile(
                          icon: k.icon,
                          title: k.title,
                          hint: k.hint,
                          value: prefs[k.key] ?? false,
                          onChanged: all ? (v) => toggle(k.key, v) : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Уведомления приходят в официальное приложение Mioko на '
                      'телефоне — это приложение их пока не показывает. '
                      'Настройки общие для аккаунта. В колокольчике на сайте '
                      'видно всё — и то, что здесь выключено.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// Большая карточка общего выключателя: колокольчик «загорается», когда включено
class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.on,
    required this.subtitle,
    required this.onChanged,
  });

  final bool on;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        border: Border.all(
          color: on
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!on),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? scheme.primary : scheme.surfaceContainerHighest,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Icon(
                      on
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      key: ValueKey(on),
                      size: 26,
                      color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Все уведомления',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: on
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: on
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: on, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool value;
  // null — общий выключатель выключен
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lit = value && onChanged != null;

    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: lit
                    ? scheme.primary.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: lit ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
