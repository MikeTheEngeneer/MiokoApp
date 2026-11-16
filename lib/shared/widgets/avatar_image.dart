import 'package:material_ui/material_ui.dart';
import '../models/media_avatar.dart';

// Заполняет родителя целиком; форму (круг, скругление) задаёт обёртка
class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.avatar, this.initialSize = 20});

  final MediaAvatar avatar;
  final double initialSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [avatar.c1, avatar.c2],
            ),
          ),
          child: Center(
            child: Text(
              avatar.initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: initialSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (avatar.imageUrl != null)
          Image.network(
            avatar.imageUrl!,
            fit: BoxFit.cover,
            alignment: avatar.alignment,
            // Плавное появление поверх градиента вместо резкого «щелчка»
            frameBuilder: (_, child, frame, syncLoaded) => syncLoaded
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: child,
                  ),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
