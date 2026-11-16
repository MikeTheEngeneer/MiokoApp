import 'package:material_ui/material_ui.dart';

import '../../core/utils/format.dart';
import '../../features/catalog/models/catalog_item.dart';
import '../../features/catalog/screens/item_detail_screen.dart';
import 'avatar_image.dart';
import 'pressable.dart';

// Карточка: картинка на весь размер, имя и подпись — поверх затемнения снизу
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.item,
    required this.heroTag,
    this.width,
    this.onTap,
  });
  final CatalogItem item;
  final String heroTag;
  // null — растягивается на всю ячейку (сетка в профиле)
  final double? width;
  // По умолчанию открывает страницу персонажа/истории
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Текст поверх картинки — белый, от темы не зависит
    const onImage = Colors.white;

    return Pressable(
      onTap: onTap ?? () => openItem(context, item, heroTag),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: heroTag,
                child: AvatarImage(avatar: item.avatar, initialSize: 36),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xD9000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    if (item.interactionsCount > 0)
                      _Chip(
                        icon: Icons.chat_bubble_rounded,
                        text: formatCount(item.interactionsCount),
                      ),
                    const Spacer(),
                    if (item.isStory)
                      const _Chip(
                        icon: Icons.auto_stories_rounded,
                        text: 'История',
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: onImage,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onImage.withValues(alpha: 0.78),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Полупрозрачная плашка поверх картинки
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x8C000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
