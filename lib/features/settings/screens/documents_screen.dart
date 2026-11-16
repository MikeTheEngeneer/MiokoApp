import 'package:material_ui/material_ui.dart';

import '../../../core/utils/open_url.dart';

// Список и порядок — как на сайте (mioko.ai/documents). Страницы открываются в браузере
const _docs = [
  (
    path: '/privacy',
    icon: Icons.verified_user_outlined,
    label: 'Политика конфиденциальности',
  ),
  (path: '/rules', icon: Icons.balance_rounded, label: 'Правила сервиса'),
  (
    path: '/terms',
    icon: Icons.handshake_outlined,
    label: 'Пользовательское соглашение',
  ),
  (path: '/offer', icon: Icons.assignment_outlined, label: 'Публичная оферта'),
  (
    path: '/contest/rules',
    icon: Icons.card_giftcard_rounded,
    label: 'Правила конкурса',
  ),
  (path: '/licenses', icon: Icons.description_outlined, label: 'Лицензии'),
];

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget card(List<Widget> rows) => Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 66,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            row,
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Документы')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              'Правовое и политики',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          card([
            for (final d in _docs)
              _DocTile(
                icon: d.icon,
                label: d.label,
                color: scheme.primary,
                onTap: () => openUrl(context, '${Links.site}${d.path}'),
              ),
          ]),
          const SizedBox(height: 16),
          // Отдельно и красным — чтобы не нажать случайно среди документов
          card([
            _DocTile(
              icon: Icons.delete_outline_rounded,
              label: 'Удаление аккаунта',
              color: scheme.error,
              onTap: () => openUrl(context, '${Links.site}/account/delete'),
            ),
          ]),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Документы открываются на сайте mioko.ai в браузере.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = color == scheme.error;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: danger ? scheme.error : null,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
