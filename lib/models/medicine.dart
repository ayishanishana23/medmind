class Medicine {
  final String id;
  final String name;
  final String dosage;
  final int stock;
  final int lowStockAlert;
  final List<Map<String, dynamic>> times;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime expiryDate;
  final bool active;

  // Multi-profile fields
  final String profileId;
  final String profileName;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.stock,
    required this.lowStockAlert,
    required this.times,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.expiryDate,
    this.active = true,
    this.profileId = '',
    this.profileName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'stock': stock,
      'lowStockAlert': lowStockAlert,
      'times': times,
      'imageUrl': imageUrl,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'active': active,
      'profileId': profileId,
      'profileName': profileName,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map, String id) {
    return Medicine(
      id: id,
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      stock: map['stock'] ?? 0,
      lowStockAlert: map['lowStockAlert'] ?? 0,
      times: (map['times'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          [],
      imageUrl: map['imageUrl'],
      startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['endDate'] ?? '') ?? DateTime.now(),
      expiryDate:
      DateTime.tryParse(map['expiryDate'] ?? '') ?? DateTime.now(),
      active: map['active'] ?? true,
      profileId: map['profileId'] ?? '',
      profileName: map['profileName'] ?? '',
    );
  }
}
