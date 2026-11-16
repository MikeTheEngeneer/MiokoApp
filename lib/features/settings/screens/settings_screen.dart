import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/mioko_icons.dart';
import '../../../core/utils/open_url.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeSettingsProvider);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Заголовок с кнопкой назад
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, top + 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Настройки',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ── Аккаунт ──────────────────────────────
              _SectionHeader(label: 'Аккаунт'),
              _Tile(
                icon: Icons.face_outlined,
                label: 'Персоны',
                onTap: () => context.push('/personas'),
              ),
              _Tile(
                icon: Icons.book_outlined,
                label: 'Лорбуки',
                onTap: () => context.push('/lorebooks'),
              ),
              _Tile(icon: Icons.link, label: 'Способы входа', onTap: () {}),

              // ── Настройки приложения ──────────────────
              _SectionHeader(label: 'Настройки приложения'),
              _ThemeTile(
                dark: themeSettings.dark,
                onChanged: (v) =>
                    ref.read(themeSettingsProvider.notifier).setDark(v),
              ),
              _MonetTile(
                enabled: themeSettings.monet,
                onChanged: (v) =>
                    ref.read(themeSettingsProvider.notifier).setMonet(v),
              ),
              _Tile(
                icon: Icons.notifications_outlined,
                label: 'Уведомления',
                onTap: () {},
              ),

              // ── Подписка и покупки ────────────────────
              _SectionHeader(label: 'Подписка и покупки'),
              _Tile(
                icon: Icons.diamond_outlined,
                label: 'Подписка M.Wave',
                onTap: () => context.push('/pearls'),
              ),
              _Tile(
                leading: const PearlIcon(size: 22),
                label: 'Пакет жемчужин',
                onTap: () => context.push('/pearls?tab=packs'),
              ),

              // ── Помощь и информация ───────────────────
              _SectionHeader(label: 'Помощь и информация'),
              _Tile(
                icon: Icons.headset_mic_outlined,
                label: 'Связаться с поддержкой',
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {},
              ),
              _Tile(
                icon: Icons.description_outlined,
                label: 'Документы',
                onTap: () {},
              ),
              _Tile(
                icon: Icons.info_outline,
                label: 'О приложении',
                trailing: const SizedBox.shrink(),
                onTap: () => _showAbout(context),
              ),

              // ── Сообщество ────────────────────────────
              _SectionHeader(label: 'Сообщество'),
              _Tile(
                leading: const BrandIcon.telegram(size: 22),
                label: 'Telegram',
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => openUrl(context, Links.telegram),
              ),
              _Tile(
                leading: const BrandIcon.vk(size: 22),
                label: 'ВКонтакте',
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => openUrl(context, Links.vk),
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Выйти ────────────────────────────────
              ListTile(
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                leading: const Icon(Icons.logout),
                title: const Text(
                  'Выйти из аккаунта',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  static void _showAbout(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'О приложении',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => const _AboutDialog(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  static const _brandBlue = Color(0xFF0280FC);
  static const _brandCyan = Color(0xFF11E8FD);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Шапка с логотипом и мягким свечением в цветах бренда
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 32, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _brandBlue.withValues(alpha: 0.22),
                  _brandBlue.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: _brandCyan.withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const MiokoLogo(size: 64),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (rect) =>
                      const LinearGradient(colors: [_brandCyan, _brandBlue])
                          .createShader(rect),
                  child: const Text(
                    'MiokoApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Версия 1.0.0',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Нативный клиент для mioko.ai — персонажи, истории и чаты в удобном приложении.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _CreditTile(
                  leading: BrandIcon.github(size: 20, color: scheme.primary),
                  role: 'Разработчик приложения',
                  name: 'MikeTheEngeneer',
                  onTap: () => openUrl(context, Links.developerGithub),
                ),
                const SizedBox(height: 8),
                _CreditTile(
                  leading: BrandIcon.telegram(size: 20, color: scheme.primary),
                  role: 'Разработчик платформы',
                  name: 'Mioko',
                  onTap: () => openUrl(context, Links.telegram),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Неофициальное приложение. Не связано с командой Mioko.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({
    required this.leading,
    required this.role,
    required this.name,
    required this.onTap,
  });

  final Widget leading;
  final String role;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Вспомогательные виджеты ────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    this.icon,
    this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading ?? Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      dense: true,
      minLeadingWidth: 32,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.dark, required this.onChanged});

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.palette_outlined,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          const Expanded(child: Text('Тема', style: TextStyle(fontSize: 15))),
          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.light_mode_outlined, size: 16),
                label: Text('Светлая', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.dark_mode_outlined, size: 16),
                label: Text('Тёмная', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {dark},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}

class _MonetTile extends ConsumerWidget {
  const _MonetTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(monetSupportedProvider).valueOrNull ?? false;

    return SwitchListTile(
      secondary: const Icon(Icons.auto_awesome_outlined, size: 22),
      title: const Text('Цвета Monet', style: TextStyle(fontSize: 15)),
      subtitle: Text(
        supported ? 'Палитра из обоев системы' : 'Нужен Android 12 или новее',
        style: const TextStyle(fontSize: 12),
      ),
      value: supported && enabled,
      onChanged: supported ? onChanged : null,
      dense: true,
    );
  }
}
