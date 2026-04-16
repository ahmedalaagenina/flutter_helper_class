class ApiConstant {
  ApiConstant._();
  // Base paths
  static const String baseUrl = 'https://api.idara.app/api/v1';

  // Auth endpoints
  static const String requestOtp = '/user/auth/request-otp';
  static const String verifyOtp = '/user/auth/verify-otp';
  static const String resendOtp = '/user/auth/resend-otp';
  static const String userProfile = '/user/profile';
  static const String logout = '/user/auth/logout';
  static const String refreshToken = '/user/auth/refresh';
}
