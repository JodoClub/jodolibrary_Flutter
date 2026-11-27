/// Configuration for Jodo Library Backend API.
///
/// Values are injected at build time so no environment is hard-wired:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1
///   flutter build appbundle --dart-define-from-file=env/prod.json
///
/// `env/prod.json` example (git-ignored):
///   { "API_BASE_URL": "https://api.example.com/api/v1",
///     "ENQUIRY_WEBHOOK_URL": "https://script.google.com/macros/s/.../exec",
///     "ENQUIRY_WEBHOOK_SECRET": "..." }
///
/// NOTE: if API_BASE_URL is plain HTTP, its host must also be listed in
/// android/app/src/main/res/xml/network_security_config.xml.
class ApiConfig {
  static const String _defaultBaseUrl = 'https://api.jodolibrary.in/api/v1';

  /// Base API URL pointing to the Spring Boot backend.
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);

  /// Mandatory multi-tenant EntityID required by Spring RequestContextFilter
  static const int entityId = int.fromEnvironment('ENTITY_ID', defaultValue: 200);

  /// Webhook URL for Enquiry / List Your Library submissions (Google Apps Script Webhook)
  static const String enquiryWebhookUrl = String.fromEnvironment(
    'ENQUIRY_WEBHOOK_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbwRXbsdAonmXKZ6VcUfJc9WK7hLUyz82jTXUV7SjNVFGxyd_EQLXfPl6o-PGlPVc20L/exec',
  );

  /// Optional shared secret sent with enquiries; must match WEBHOOK_SECRET in
  /// scripts/google_sheet_enquiry_webhook.js when that is set.
  static const String enquiryWebhookSecret =
      String.fromEnvironment('ENQUIRY_WEBHOOK_SECRET');
}
