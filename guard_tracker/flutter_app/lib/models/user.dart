class User {
  final int id;
  final String username;
  final String displayName;
  final String role;
  final double? latitude;
  final double? longitude;
  final String createdAt;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      displayName: json['display_name'],
      role: json['role'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }
}
