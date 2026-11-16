class UserModel {
  final String uid;
  final String email;
  final String role; // 'admin' | 'vendor' | 'resident'
  final String name;
  final String? phone;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'resident',
      name: map['name'] ?? '',
      phone: map['phone'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}