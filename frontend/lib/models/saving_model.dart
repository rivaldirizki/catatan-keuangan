class SavingContributor {
  final int userId;
  final String userName;
  final int totalContributed;

  const SavingContributor({
    required this.userId,
    required this.userName,
    required this.totalContributed,
  });

  factory SavingContributor.fromJson(Map<String, dynamic> json) {
    return SavingContributor(
      userId: json['user_id'] as int,
      userName: (json['user_name'] as String?) ?? 'Anggota',
      totalContributed: int.tryParse(json['total_contributed'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'total_contributed': totalContributed,
    };
  }
}

class SavingModel {
  final int id;
  final int userId;
  final int? familyId;
  final String goalName;
  final int targetAmount;
  final int currentAmount;
  final String? targetDate;
  final String scope;
  final String status;
  final int progressPercentage;
  final List<SavingContributor> contributors;

  const SavingModel({
    required this.id,
    required this.userId,
    this.familyId,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.scope,
    required this.status,
    required this.progressPercentage,
    this.contributors = const [],
  });

  bool get isFamilyShared => scope == 'family';

  factory SavingModel.fromJson(Map<String, dynamic> json) {
    final target = int.tryParse(json['target_amount'].toString()) ?? 0;
    final current = int.tryParse(json['current_amount'].toString()) ?? 0;
    final progress = target > 0 ? ((current / target) * 100).clamp(0, 100).toInt() : 0;

    List<SavingContributor> contributors = [];
    if (json['contributions'] is List) {
      contributors = (json['contributions'] as List)
          .map((c) => SavingContributor.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return SavingModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      familyId: json['family_id'] != null ? json['family_id'] as int : null,
      goalName: json['goal_name'] as String,
      targetAmount: target,
      currentAmount: current,
      targetDate: json['target_date'] != null ? json['target_date'].toString().split('T')[0] : null,
      scope: (json['scope'] as String?) ?? 'personal',
      status: (json['status'] as String?) ?? 'active',
      progressPercentage: (json['progress_percentage'] as int?) ?? progress,
      contributors: contributors,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'goal_name': goalName,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate,
      'scope': scope,
      'status': status,
      'progress_percentage': progressPercentage,
      'contributions': contributors.map((c) => c.toJson()).toList(),
    };
  }
}
