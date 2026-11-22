class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? familyId;
  final int? companyId;
  final String? chatInviteCode;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.familyId,
    this.companyId,
    this.chatInviteCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'user',
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
      companyId: json['company_id'] != null ? json['company_id'] as int : null,
      chatInviteCode: json['chat_invite_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'family_id': familyId,
      'company_id': companyId,
      'chat_invite_code': chatInviteCode,
    };
  }
}
