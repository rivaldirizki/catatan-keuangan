class TransactionModel {
  final int id;
  final int userId;
  final int? familyId;
  final int walletId;
  final int? categoryId;
  final String type; // 'income', 'expense', 'transfer', 'saving_deposit', 'debt_payment'
  final int amount;
  final String transactionDate;
  final String? notes;
  final int? destinationWalletId;
  final int? destinationSavingId;
  final int? debtId;
  final String scope;

  const TransactionModel({
    required this.id,
    required this.userId,
    this.familyId,
    required this.walletId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    this.notes,
    this.destinationWalletId,
    this.destinationSavingId,
    this.debtId,
    required this.scope,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
      walletId: json['wallet_id'] as int,
      categoryId: json['category_id'] != null ? json['category_id'] as int : null,
      type: json['type'] as String,
      amount: int.tryParse(json['amount'].toString()) ?? 0,
      transactionDate: json['transaction_date'].toString().split('T')[0],
      notes: json['notes'] as String?,
      destinationWalletId: json['destination_wallet_id'] != null ? json['destination_wallet_id'] as int : null,
      destinationSavingId: json['destination_saving_id'] != null ? json['destination_saving_id'] as int : null,
      debtId: json['debt_id'] != null ? json['debt_id'] as int : null,
      scope: (json['scope'] as String?) ?? 'personal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'wallet_id': walletId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'transaction_date': transactionDate,
      'notes': notes,
      'destination_wallet_id': destinationWalletId,
      'destination_saving_id': destinationSavingId,
      'debt_id': debtId,
      'scope': scope,
    };
  }
}
