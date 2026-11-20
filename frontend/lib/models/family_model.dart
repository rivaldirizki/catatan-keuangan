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
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] as String?) ?? 'Keluarga',
      inviteCode: (json['invite_code'] as String?) ?? '',
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
