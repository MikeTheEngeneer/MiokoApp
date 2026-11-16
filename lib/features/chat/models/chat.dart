import '../../../shared/models/media_avatar.dart';

class Chat {
  final String id;
  final String title;
  final String characterName;
  final String? lastMessage;
  final DateTime updatedAt;
  final MediaAvatar avatar;
  final bool isStory;
  final String? storyId;
  final String? characterId;

  const Chat({
    required this.id,
    required this.title,
    required this.characterName,
    this.lastMessage,
    required this.updatedAt,
    required this.avatar,
    required this.isStory,
    this.storyId,
    this.characterId,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'] as String,
    title: json['title'] as String,
    characterName: json['character_name'] as String,
    lastMessage: json['last_message'] as String?,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    avatar: MediaAvatar.fromJson(json['avatar'] as Map<String, dynamic>?),
    isStory: json['is_story'] as bool? ?? false,
    storyId: json['story_id'] as String?,
    characterId: json['character_id'] as String?,
  );
}
