class Persona {
  final String publicId;
  final String name;
  final String description;
  final String? avatarUrl;
  final bool isDefault;

  const Persona({
    required this.publicId,
    required this.name,
    required this.description,
    this.avatarUrl,
    required this.isDefault,
  });

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
        publicId: json['public_id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        isDefault: json['is_default'] as bool? ?? false,
      );
}

class PersonasData {
  final List<Persona> personas;
  final int limit;

  const PersonasData({required this.personas, required this.limit});

  bool get isFull => personas.length >= limit;
}
