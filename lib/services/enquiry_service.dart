import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_config.dart';

class EnquirySubmissionResult {
  final bool success;
  final String message;
  final int? row;

  EnquirySubmissionResult({
    required this.success,
    required this.message,
    this.row,
  });
}

class EnquiryService {
  static const Duration _timeout = Duration(seconds: 18);

  /// Submits an enquiry to the Google Apps Script Webhook.
  /// Automatically handles HTTP 302 redirects from Google Script Web Apps.
  static Future<EnquirySubmissionResult> submitEnquiry({
    required String fullName,
    required String userType,
    required String enquiryType,
    required String mobile,
    String? email,
    required String address,
    required String message,
    String? customWebhookUrl,
  }) async {
    final targetUrl = (customWebhookUrl != null && customWebhookUrl.trim().isNotEmpty)
        ? customWebhookUrl.trim()
        : ApiConfig.enquiryWebhookUrl;

    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final payload = <String, dynamic>{
      'dateTime': nowStr,
      'fullName': fullName.trim(),
      'name': fullName.trim(),
      'userType': userType,
      'enquiryType': enquiryType,
      'mobile': mobile.trim(),
      'phone': mobile.trim(),
      'whatsapp': mobile.trim(),
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : '',
      'address': address.trim(),
      'city': address.trim(),
      'message': message.trim(),
      'enquiryMessage': message.trim(),
    };

    try {
      final uri = Uri.parse(targetUrl);
      var response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      // Follow Google Apps Script 302 redirect
      if (response.statusCode == 302 && response.headers['location'] != null) {
        final redirectUri = Uri.parse(response.headers['location']!);
        response = await http.get(redirectUri).timeout(_timeout);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final json = jsonDecode(response.body);
          if (json is Map) {
            final isSuccess = json['success'] == true || json['status'] == 'success';
            final msg = json['message']?.toString() ?? 'Enquiry submitted successfully!';
            final row = json['row'] is int ? json['row'] as int : null;
            return EnquirySubmissionResult(
              success: isSuccess,
              message: isSuccess ? msg : (json['error']?.toString() ?? 'Failed to record enquiry.'),
              row: row,
            );
          }
        } catch (_) {}

        return EnquirySubmissionResult(
          success: true,
          message: 'Enquiry submitted successfully!',
        );
      } else {
        return EnquirySubmissionResult(
          success: false,
          message: 'Server responded with status ${response.statusCode}. Please try again.',
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
        return EnquirySubmissionResult(
          success: false,
          message: 'No internet connection. Please check your network and try again.',
        );
      }
      return EnquirySubmissionResult(
        success: false,
        message: 'Could not connect to enquiry server. ($e)',
      );
    }
  }
}
