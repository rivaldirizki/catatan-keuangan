class ApiConstants {
  // Production Backend URL (bcknd.linc-indo.com)
  static const String baseUrl = 'https://bcknd.linc-indo.com/api/v1';
  static const String emulatorBaseUrl = 'https://bcknd.linc-indo.com/api/v1';

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

  // Company
  static const String companyCreate = '/company/create';
  static const String companyJoin = '/company/join';
  static const String companyMembers = '/company/members';
  static const String companyCurrent = '/company/current';

  // Projects
  static const String projects = '/projects';
  static String projectDetail(int id) => '/projects/$id';
  static String projectTransaction(int id) => '/projects/$id/transaction';
  static String projectStatus(int id) => '/projects/$id/status';

  // Wallets & Transactions
  static const String wallets = '/wallets';
  static const String transactions = '/transactions';
  static const String transactionSummary = '/transactions/summary';
  static const String transactionIncome = '/transactions/income';
  static const String transactionExpense = '/transactions/expense';
  static const String transactionTransfer = '/transactions/transfer';

  // Categories
  static const String categories = '/categories';

  // Savings Vault
  static const String savings = '/savings';
  static const String savingsGoals = '/savings/goals';
  static const String savingsDeposit = '/savings/deposit';
  static const String savingsWithdraw = '/savings/withdraw';

  // Debts & Due Dates
  static const String debts = '/debts';
  static const String debtReminders = '/debts/reminders';
  static String debtPay(int id) => '/debts/$id/pay';

  // Chat
  static const String chatMyCode = '/chat/my-code';
  static const String chatRooms = '/chat/rooms';
  static const String chatInvitations = '/chat/invitations';
  static const String chatDirectInvite = '/chat/direct/invite';
  static String chatInvitationAccept(int id) => '/chat/invitations/$id/accept';
  static String chatInvitationReject(int id) => '/chat/invitations/$id/reject';
  static String chatRoomMessages(int id) => '/chat/rooms/$id/messages';
  static String chatRoomRead(int id) => '/chat/rooms/$id/read';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
}
