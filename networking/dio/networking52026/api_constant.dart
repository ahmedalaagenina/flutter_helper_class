class ApiConstant {
  ApiConstant._();
  // Base paths
  static const String baseUrl = 'https://umra.net/idara_driver/api/v1';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String verifyOtp = '/auth/verify';
  static const String logout = '/user/auth/logout';
  static const String refreshToken = '/user/auth/refresh';

  // user endpoints
  static const String userProfile = '/user/profile';

  // Notifications endpoints
  static const String notifications = '/user/notifications';
  static const String unreadNotificationsCount =
      '/user/notifications/unread-count';
  static const String markAllNotificationsRead =
      '/user/notifications/mark-all-read';
  static String readNotification(String id) => '/user/notifications/$id/read';

  // Home endpoints
  static const String home = '/home';

  // Trips endpoints
  static const String trips = '/trips';
}
