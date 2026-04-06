class AppRoutesPath {
  AppRoutesPath._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signUp = '/sign-up';

  static const String main = '/';

  // Categories
  static const String manageCategories = '/categories';
  static const String createCategory = '/categories/create';

  // Groups
  static const String joinGroup = '/groups/join';
  static const String groupDetails = '/groups/:groupId';
  static const String groupSettings = '/groups/:groupId/settings';
  static const String groupAnalytics = '/groups/:groupId/analytics';
  static const String memberRoles = '/groups/:groupId/members';
  static const String activityFeed = '/groups/:groupId/activity';
  static const String joinConfirmation = '/groups/:groupId/join-confirmation';
  static const String settlementPlan = '/groups/:groupId/settlement';
  static const String setupRecurringExpense =
      '/groups/:groupId/recurring-expense';

  // Expenses
  static const String addExpense = '/expenses/add';
  static const String uploadPaymentProof = '/expenses/:expenseId/upload-proof';
  static const String verifyPaymentProof = '/expenses/:expenseId/verify-proof';
  static const String expenseDispute = '/expenses/:expenseId/dispute';

  // User
  static const String userProfile = '/profile';
  static const String transactionHistory = '/transactions';
  static const String notificationPreferences = '/notifications/preferences';
}

class AppRoutesName {
  AppRoutesName._();

  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String login = 'login';
  static const String signUp = 'signUp';
  static const String main = 'main';

  static const String manageCategories = 'manageCategories';
  static const String createCategory = 'createCategory';

  static const String joinGroup = 'joinGroup';
  static const String groupDetails = 'groupDetails';
  static const String groupSettings = 'groupSettings';
  static const String groupAnalytics = 'groupAnalytics';
  static const String memberRoles = 'memberRoles';
  static const String activityFeed = 'activityFeed';
  static const String joinConfirmation = 'joinConfirmation';
  static const String settlementPlan = 'settlementPlan';
  static const String setupRecurringExpense = 'setupRecurringExpense';

  static const String addExpense = 'addExpense';
  static const String uploadPaymentProof = 'uploadPaymentProof';
  static const String verifyPaymentProof = 'verifyPaymentProof';
  static const String expenseDispute = 'expenseDispute';

  static const String userProfile = 'userProfile';
  static const String transactionHistory = 'transactionHistory';
  static const String notificationPreferences = 'notificationPreferences';
}
