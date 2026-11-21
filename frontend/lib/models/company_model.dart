class CompanyModel {
  final int id;
  final String name;
  final String inviteCode;
  final int? createdBy;
  final String? createdAt;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.createdBy,
    this.createdAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      createdBy: json['created_by'] != null ? json['created_by'] as int : null,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }
}
