class AppUser {
  final String id;         // Firestore UID
  final String name;
  final String email;
  final String role;       // "admin" or "user"
  final bool approved;     // Admin approval
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': name,
      'email': email,
      'role': role,
      'approved': approved,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      name: map['displayName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      approved: map['approved'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
