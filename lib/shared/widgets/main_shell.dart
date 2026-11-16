import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Главная',
      path: '/home',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Каталог',
      path: '/explore',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Чаты',
      path: '/chats',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Профиль',
      path: '/profile',
    ),
  ];

  int _currentIndex(String location) {
    for (var i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      // Контент уходит под панель; экраны получают её высоту в MediaQuery.padding.bottom
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(location), child: child),
      ),
      bottomNavigationBar: _FloatingNavBar(
        items: _items,
        selected: _currentIndex(location),
        onSelect: (i) => context.go(_items[i].path),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, safeBottom + 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              // Не Expanded: при равных долях капсула с подписью не помещалась в 1/4 ширины
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _NavButton(
                      item: items[i],
                      active: i == selected,
                      onTap: () {
                        if (i != selected) HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Вертикальный запас — чтобы попадать пальцем по всей высоте панели
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // Активный пункт — капсула с иконкой и подписью, остальные — только иконка
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: active ? 14 : 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  color: color,
                  size: 24,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: active
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
