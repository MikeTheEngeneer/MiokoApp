class User {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String bio;
  final String? avatarUrl;
  final DateTime? birthDate;
  final bool verified;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    required this.bio,
    this.avatarUrl,
    this.birthDate,
    required this.verified,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        username: json['username'] as String,
        bio: json['bio'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        birthDate: json['birth_date'] != null
            ? DateTime.parse(json['birth_date'] as String)
            : null,
        verified: json['verified'] as bool? ?? false,
      );
}
