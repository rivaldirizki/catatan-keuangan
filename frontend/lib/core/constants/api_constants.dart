class ApiConstants {
  // Default to localhost for Android emulator (10.0.2.2) or desktop/web (localhost)
  static const String baseUrl = 'http://localhost:3000/api/v1';
  static const String emulatorBaseUrl = 'http://10.0.2.2:3000/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Family
  static const String familyCreate = '/family/create';
  static const String familyJoin = '/family/join';
  static const String familyMembers = '/family/members';
  static const String familyCurrent = '/family/current';
  static String familyMemberSummary(int id) => '/family/members/$id/summary';

  // Wallets & Transactions
  static const String wallets = '/wallets';
  static const String transactions = '/transactions';
  static const String transactionSummary = '/transactions/summary';
  static const String transactionIncome = '/transactions/income';
  static const String transactionExpense = '/transactions/expense';
  static const String transactionTransfer = '/transactions/transfer';

  // Savings Vault
  static const String savings = '/savings';
  static const String savingsGoals = '/savings/goals';
  static const String savingsDeposit = '/savings/deposit';
  static const String savingsWithdraw = '/savings/withdraw';

  // Debts & Due Dates
  static const String debts = '/debts';
  static String debtPay(int id) => '/debts/$id/pay';
}
