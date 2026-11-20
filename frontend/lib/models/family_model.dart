class FamilyModel {
  final int id;
  final String name;
  final String inviteCode;

  const FamilyModel({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
    };
  }
}
