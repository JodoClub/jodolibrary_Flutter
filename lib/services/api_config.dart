/// Configuration for Jodo Library Backend API
class ApiConfig {
  /// Base API URL pointing to the Spring Boot backend
  /// - Android emulator uses 10.0.2.2 to access host machine's localhost:5000
  /// - Web / Windows desktop uses localhost:5000
  /// - Physical Android/iOS devices should use computer's LAN IP e.g. http://192.168.1.X:5000/api/v1
  static String defaultBaseUrl() {
    return 'http://130.210.33.128:5000/api/v1';
  }

  static String baseUrl = defaultBaseUrl();

  /// Mandatory multi-tenant EntityID required by Spring RequestContextFilter
  static const int entityId = 200;

  /// Webhook URL for Enquiry / List Your Library submissions (Google Apps Script Webhook)
  static String enquiryWebhookUrl =
      'https://script.google.com/macros/s/AKfycbzt9Mpl30eYf08PJDN1sw2YWUpqahOsmtMb8IUBHZlPIHSt_iI08A9pdzImcIk2fBS0tQ/exec';

  /// Development universal OTP configured in backend (application-dev.yml)
  static const String devFixedOtp = '4321';
}
