class UserProfile {
  final String id;              // Profile ID (user may have multiple profiles)
  final String userId;          // Parent User ID
  final String name;            // Profile Name (e.g., "Mom", "Dad")
  final int age;                // Optional age
  final String gender;          // "Male", "Female", etc.
  final String avatarUrl;       // Profile Picture
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.age,
    required this.gender,
    required this.avatarUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'age': age,
      'gender': gender,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? 'Unknown',
      avatarUrl: map['avatarUrl'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
