import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  static String _limit(String v, int max) {
    final t = v.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  /// Apps Script answers with a 302 to script.googleusercontent.com; only
  /// follow redirects that stay on Google-owned hosts.
  static bool _isTrustedRedirect(Uri uri) {
    if (uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    return h == 'script.google.com' ||
        h == 'script.googleusercontent.com' ||
        h.endsWith('.googleusercontent.com');
  }

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

    final name = _limit(fullName, 100);
    final phone = _limit(mobile, 20);
    final mail = _limit(email ?? '', 120);
    final addr = _limit(address, 300);
    final msg = _limit(message, 1500);

    final payload = <String, dynamic>{
      'dateTime': nowStr,
      'fullName': name,
      'name': name,
      'userType': _limit(userType, 40),
      'enquiryType': _limit(enquiryType, 60),
      'mobile': phone,
      'phone': phone,
      'whatsapp': phone,
      'email': mail,
      'address': addr,
      'city': addr,
      'message': msg,
      'enquiryMessage': msg,
      if (ApiConfig.enquiryWebhookSecret.isNotEmpty) 'secret': ApiConfig.enquiryWebhookSecret,
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
        if (!_isTrustedRedirect(redirectUri)) {
          return EnquirySubmissionResult(
            success: false,
            message: 'Could not submit enquiry. Please try again later.',
          );
        }
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
      if (kDebugMode) debugPrint('[EnquiryService] submit failed: $e');
      return EnquirySubmissionResult(
        success: false,
        message: 'Could not connect to enquiry server. Please try again.',
      );
    }
  }
}
