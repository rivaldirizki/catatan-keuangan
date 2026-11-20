class DebtModel {
  final int id;
  final int userId;
  final int? familyId;
  final String type; // 'payable' (hutang) or 'receivable' (piutang)
  final String personName;
  final int totalAmount;
  final int remainingAmount;
  final String dueDate;
  final String status; // 'unpaid', 'partially_paid', 'paid', 'overdue'
  final String computedStatus;
  final String scope;
  final String? notes;

  const DebtModel({
    required this.id,
    required this.userId,
    this.familyId,
    required this.type,
    required this.personName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.dueDate,
    required this.status,
    required this.computedStatus,
    required this.scope,
    this.notes,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    final total = int.tryParse(json['total_amount'].toString()) ?? 0;
    final remaining = int.tryParse(json['remaining_amount'].toString()) ?? 0;
    return DebtModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
      type: json['type'] as String,
      personName: json['person_name'] as String,
      totalAmount: total,
      remainingAmount: remaining,
      dueDate: json['due_date'].toString().split('T')[0],
      status: (json['status'] as String?) ?? 'unpaid',
      computedStatus: (json['computed_status'] as String?) ?? (json['status'] as String?) ?? 'unpaid',
      scope: (json['scope'] as String?) ?? 'personal',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'type': type,
      'person_name': personName,
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'due_date': dueDate,
      'status': status,
      'computed_status': computedStatus,
      'scope': scope,
      'notes': notes,
    };
  }

  String get dueStatus => computedStatus;
}
