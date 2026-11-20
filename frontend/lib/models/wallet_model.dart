class WalletModel {
  final int id;
  final int userId;
  final int? familyId;
  final String name;
  final int balance;
  final String scope;

  const WalletModel({
    required this.id,
    required this.userId,
    this.familyId,
    required this.name,
    required this.balance,
    required this.scope,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
      name: json['name'] as String,
      balance: int.tryParse(json['balance'].toString()) ?? 0,
      scope: (json['scope'] as String?) ?? 'personal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'name': name,
      'balance': balance,
      'scope': scope,
    };
  }
}
