class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? familyId;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.familyId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'user',
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'family_id': familyId,
    };
  }
}
