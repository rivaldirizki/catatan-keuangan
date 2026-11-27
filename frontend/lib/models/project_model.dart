class ProjectModel {
  final int id;
  final int companyId;
  final int createdBy;
  final String? invoiceNumber;
  final String name;
  final String? description;
  final int targetBudget;
  final int billingAmount;
  final double feeManagementPercent;
  final int feeManagement;
  final double ppnPercent;
  final int ppnAmount;
  final double pphPercent;
  final int pphAmount;
  final int nettoAmount;
  final String paymentStatus; // 'unpaid', 'paid'
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
    this.invoiceNumber,
    required this.name,
    this.description,
    required this.targetBudget,
    this.billingAmount = 0,
    this.feeManagementPercent = 0,
    this.feeManagement = 0,
    this.ppnPercent = 0,
    this.ppnAmount = 0,
    this.pphPercent = 0,
    this.pphAmount = 0,
    this.nettoAmount = 0,
    this.paymentStatus = 'unpaid',
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

  bool get isPaid => paymentStatus == 'paid';

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final billing = int.tryParse(json['billing_amount']?.toString() ?? '0') ?? 0;
    final fee = int.tryParse(json['fee_management']?.toString() ?? '0') ?? 0;
    final ppn = int.tryParse(json['ppn_amount']?.toString() ?? '0') ?? 0;
    final pph = int.tryParse(json['pph_amount']?.toString() ?? '0') ?? 0;
    final netto = json['netto_amount'] != null
        ? (int.tryParse(json['netto_amount'].toString()) ?? 0)
        : (billing - fee - ppn - pph).clamp(0, billing);

    return ProjectModel(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      createdBy: json['created_by'] as int,
      invoiceNumber: json['invoice_number']?.toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      targetBudget: int.tryParse(json['target_budget']?.toString() ?? '0') ?? 0,
      billingAmount: billing,
      feeManagementPercent: double.tryParse(json['fee_management_percent']?.toString() ?? '0') ?? 0,
      feeManagement: fee,
      ppnPercent: double.tryParse(json['ppn_percent']?.toString() ?? '0') ?? 0,
      ppnAmount: ppn,
      pphPercent: double.tryParse(json['pph_percent']?.toString() ?? '0') ?? 0,
      pphAmount: pph,
      nettoAmount: netto,
      paymentStatus: (json['payment_status']?.toString() == 'paid') ? 'paid' : 'unpaid',
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
      'invoice_number': invoiceNumber,
      'name': name,
      'description': description,
      'target_budget': targetBudget,
      'billing_amount': billingAmount,
      'fee_management_percent': feeManagementPercent,
      'fee_management': feeManagement,
      'ppn_percent': ppnPercent,
      'ppn_amount': ppnAmount,
      'pph_percent': pphPercent,
      'pph_amount': pphAmount,
      'netto_amount': nettoAmount,
      'payment_status': paymentStatus,
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
