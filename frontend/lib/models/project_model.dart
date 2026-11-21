class ProjectModel {
  final int id;
  final int companyId;
  final int createdBy;
  final String name;
  final String? description;
  final int targetBudget;
  final int currentIncome;
  final int currentExpense;
  final int netProfit;
  final int budgetProgress;
  final String status; // 'active', 'completed', 'on_hold'
  final String? startDate;
  final String? endDate;
  final String? createdAt;
  final String? createdByName;

  const ProjectModel({
    required this.id,
    required this.companyId,
    required this.createdBy,
    required this.name,
    this.description,
    required this.targetBudget,
    required this.currentIncome,
    required this.currentExpense,
    required this.netProfit,
    required this.budgetProgress,
    required this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.createdByName,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      createdBy: json['created_by'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetBudget: int.tryParse(json['target_budget']?.toString() ?? '0') ?? 0,
      currentIncome: int.tryParse(json['current_income']?.toString() ?? '0') ?? 0,
      currentExpense: int.tryParse(json['current_expense']?.toString() ?? '0') ?? 0,
      netProfit: int.tryParse(json['net_profit']?.toString() ?? '0') ??
          ((int.tryParse(json['current_income']?.toString() ?? '0') ?? 0) -
              (int.tryParse(json['current_expense']?.toString() ?? '0') ?? 0)),
      budgetProgress: int.tryParse(json['budget_progress']?.toString() ?? '0') ?? 0,
      status: (json['status'] as String?) ?? 'active',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      createdAt: json['created_at']?.toString(),
      createdByName: json['created_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'created_by': createdBy,
      'name': name,
      'description': description,
      'target_budget': targetBudget,
      'current_income': currentIncome,
      'current_expense': currentExpense,
      'net_profit': netProfit,
      'budget_progress': budgetProgress,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'created_at': createdAt,
      'created_by_name': createdByName,
    };
  }
}
