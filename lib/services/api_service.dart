import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';
import 'api_config.dart';
import 'auth_storage.dart';
import 'network_service.dart';
import 'notification_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? code;
  final int? retryAfterSeconds;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.code,
    this.retryAfterSeconds,
  });
}

/// HTTP client that detects an expired/invalid session (HTTP 401 on an
/// authenticated request) in one place for every endpoint.
class _AuthAwareClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final hadToken = request.headers['Authorization']?.isNotEmpty ?? false;
    if (response.statusCode == 401 &&
        hadToken &&
        !request.url.path.endsWith('/auth/logout')) {
      // Fire and forget; the caller still receives the 401 response.
      ApiService._handleUnauthorized();
    }
    return response;
  }
}

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static const Duration _timeout = Duration(seconds: 12);

  /// Register device FCM token with backend
  Future<bool> registerFcmToken(String fcmToken) => registerDeviceFcmToken(fcmToken);

  static Future<bool> registerDeviceFcmToken(String fcmToken) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/fcm-token');
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(token: token),
            body: jsonEncode({'fcmToken': fcmToken}),
          )
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] registerDeviceFcmToken error: $e');
      return false;
    }
  }

  /// Max accepted size for a library photo upload (bytes).
  static const int maxUploadBytes = 8 * 1024 * 1024;

  static final http.Client _client = _AuthAwareClient();
  static final Random _random = Random.secure();

  /// Set by the root widget; called once when the backend rejects the session.
  static void Function()? onSessionExpired;
  static bool _sessionExpiredHandled = false;

  static Future<void> _handleUnauthorized() async {
    if (_sessionExpiredHandled) return;
    _sessionExpiredHandled = true;
    await AuthStorage.clearSession();
    onSessionExpired?.call();
  }

  static void _checkNetworkError(dynamic e) {
    if (e is SocketException ||
        e.toString().contains('SocketException') ||
        e.toString().contains('Failed host lookup') ||
        e.toString().contains('ClientException') ||
        e.toString().contains('Network is unreachable') ||
        e.toString().contains('Connection refused') ||
        e.toString().contains('TimeoutException')) {
      NetworkService.instance.notifyNetworkError();
    }
  }

  /// Returns a user-safe message. Raw exception details (hosts, IPs, parse
  /// errors) are only logged in debug builds, never shown to users.
  static String _formatNetworkError(dynamic e, [String defaultPrefix = 'Could not connect to server']) {
    _checkNetworkError(e);
    if (kDebugMode) debugPrint('[ApiService] $defaultPrefix: $e');
    final s = e.toString();
    if (e is SocketException ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (s.contains('TimeoutException')) {
      return 'The server is taking too long to respond. Please try again.';
    }
    if (e is FormatException) {
      return 'Unexpected response from server. Please try again later.';
    }
    return '$defaultPrefix. Please try again.';
  }

  static String _newTransactionId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'TXN-${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  static Map<String, String> _buildHeaders({String? token, String? customTxnId}) {
    final txn = customTxnId ?? _newTransactionId();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'TransactionID': txn,
      'EntityID': ApiConfig.entityId.toString(),
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --------------------------------------------------------------------------
  // AUTHENTICATION
  // --------------------------------------------------------------------------

  /// Send OTP to user phone number
  static Future<ApiResponse<Map<String, dynamic>>> sendOtp({
    required String mobile,
    required UserRole role,
  }) async {
    try {
      final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/send-otp');
      final body = jsonEncode({
        'mobile': cleanMobile,
        'countryCode': '+91',
        'role': role == UserRole.admin ? 'ADMIN' : 'STUDENT',
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        return ApiResponse(success: true, data: json);
      } else {
        int? retrySec = (json['retryAfterSeconds'] as num?)?.toInt();
        if (retrySec == null && response.headers['retry-after'] != null) {
          retrySec = int.tryParse(response.headers['retry-after']!);
        }
        final msg = json['message'] as String? ?? 'Failed to send OTP';
        if (retrySec == null) {
          final match = RegExp(r'(\d+)\s*(?:s|seconds)', caseSensitive: false).firstMatch(msg);
          if (match != null) {
            retrySec = int.tryParse(match.group(1)!);
          }
        }
        // If HTTP 429 or OTP_RATE_LIMIT, default to 60 seconds (1 minute lock)
        if (retrySec == null && (response.statusCode == 429 || json['code'] == 'OTP_RATE_LIMIT')) {
          retrySec = 60;
        }

        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: msg,
          retryAfterSeconds: retrySec,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: _formatNetworkError(e),
      );
    }
  }

  /// Verify 4-digit OTP and retrieve JWT token
  static Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String mobile,
    required String otp,
    required UserRole role,
  }) async {
    try {
      final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/verify-otp');
      final body = jsonEncode({
        'mobile': cleanMobile,
        'countryCode': '+91',
        'otp': otp.trim(),
        'role': role == UserRole.admin ? 'ADMIN' : 'STUDENT',
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final token = json['token'] as String;
        final user = json['user'] as Map<String, dynamic>?;
        _sessionExpiredHandled = false;
        await AuthStorage.saveSession(
          token: token,
          role: role,
          phone: cleanMobile,
          userId: user?['id'] as String?,
          userName: user?['name'] as String?,
        );
        final avatar = user?['avatarUrl']?.toString() ?? user?['avatar']?.toString() ?? user?['photo']?.toString();
        if (avatar != null && avatar.trim().isNotEmpty) {
          await AuthStorage.saveOwnerPhoto(avatar.trim());
        }
        // Sync device FCM token for push notifications
        NotificationService.instance.syncTokenWithBackend();
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Invalid verification code',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: _formatNetworkError(e, 'Backend connection error'),
      );
    }
  }

  /// Authenticate using Firebase Google ID Token
  static Future<ApiResponse<Map<String, dynamic>>> googleLogin({
    required String idToken,
    required UserRole role,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/google');
      final body = jsonEncode({
        'idToken': idToken,
        'role': role == UserRole.admin ? 'ADMIN' : 'STUDENT',
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final token = json['token'] as String;
        final user = json['user'] as Map<String, dynamic>?;
        final phone = user?['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
        _sessionExpiredHandled = false;
        await AuthStorage.saveSession(
          token: token,
          role: role,
          phone: phone,
          userId: user?['id'] as String?,
          userName: user?['name'] as String?,
        );
        final avatar = user?['avatarUrl']?.toString() ?? user?['avatar']?.toString() ?? user?['photo']?.toString();
        if (avatar != null && avatar.trim().isNotEmpty) {
          await AuthStorage.saveOwnerPhoto(avatar.trim());
        }
        // Sync device FCM token for push notifications
        NotificationService.instance.syncTokenWithBackend();
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Google sign-in failed',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: _formatNetworkError(e, 'Backend connection error'),
      );
    }
  }

  /// Student initial profile setup
  static Future<ApiResponse<Map<String, dynamic>>> studentSetup({
    required String fullName,
    required String examCategory,
    required String emergencyContact,
    required String gender,
    String? mobile,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/student-setup');
      final body = jsonEncode({
        'fullName': fullName.trim(),
        'examCategory': examCategory,
        'emergencyContact': emergencyContact.startsWith('+') ? emergencyContact : '+91$emergencyContact',
        'gender': gender,
        if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim().replaceAll(RegExp(r'\D'), ''),
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Profile setup failed',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Owner initial library setup
  static Future<ApiResponse<Map<String, dynamic>>> ownerSetup({
    required String ownerName,
    required String libraryName,
    required String address,
    String? city,
    required int totalSeats,
    double? latitude,
    double? longitude,
    String? mobile,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/owner-setup');
      final body = jsonEncode({
        'ownerName': ownerName.trim(),
        'libraryName': libraryName.trim(),
        'address': address.trim(),
        'city': city?.trim().isNotEmpty == true ? city!.trim() : 'Patna',
        'totalSeats': totalSeats,
        'latitude': latitude ?? 25.6093,
        'longitude': longitude ?? 85.1376,
        if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim().replaceAll(RegExp(r'\D'), ''),
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Owner setup failed',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get authenticated user and role profile (GET /auth/me)
  static Future<ApiResponse<Map<String, dynamic>>> getMe() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/me');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final user = json['user'] as Map<String, dynamic>?;
        final profile = json['profile'] as Map<String, dynamic>?;
        if (user != null) {
          final role = await AuthStorage.getRole();
          if (role == UserRole.admin && profile != null) {
            final avatarUrl = user['avatarUrl']?.toString() ?? user['avatar']?.toString() ?? user['photo']?.toString();
            await AuthStorage.saveOwnerProfile(
              ownerName: user['name']?.toString() ?? '',
              libraryName: profile['name']?.toString() ?? '',
              address: profile['address']?.toString() ?? '',
              city: profile['city']?.toString() ?? 'Patna',
              totalSeats: profile['totalSeats'] is int ? profile['totalSeats'] as int : 60,
              ownerPhoto: avatarUrl,
            );
            if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
              await AuthStorage.saveOwnerPhoto(avatarUrl.trim());
            }
          } else if (role == UserRole.student && profile != null) {
            await AuthStorage.saveStudentProfile(
              fullName: user['name']?.toString() ?? '',
              examCategory: profile['examCategory']?.toString() ?? 'UPSC / Civil Services',
              emergencyContact: profile['emergencyContact']?.toString() ?? '',
              gender: profile['gender']?.toString() ?? 'Other',
              studentCode: profile['code']?.toString(),
            );
          }
        }
        return ApiResponse(success: true, data: json);
      } else {
        if (response.statusCode == 401) {
          await AuthStorage.clearSession();
        }
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Update owner contact and library details (PUT /owner/profile)
  static Future<ApiResponse<Map<String, dynamic>>> updateOwnerProfile({
    required String ownerName,
    required String libraryName,
    required String address,
    required String city,
    required int totalSeats,
    String? mobile,
    String? ownerPhoto,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final cleanMobile = mobile?.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/profile');
      final body = jsonEncode({
        'ownerName': ownerName.trim(),
        'libraryName': libraryName.trim(),
        'branchName': 'Branch 1',
        'address': address.trim(),
        'city': city.trim(),
        'totalSeats': totalSeats,
        if (cleanMobile != null && cleanMobile.length == 10) 'mobile': cleanMobile,
        if (cleanMobile != null && cleanMobile.length == 10) 'countryCode': '+91',
        if (ownerPhoto != null && ownerPhoto.isNotEmpty) 'ownerPhoto': ownerPhoto.trim(),
      });

      final response = await _client
          .put(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await AuthStorage.saveOwnerProfile(
          ownerName: ownerName,
          libraryName: libraryName,
          address: address,
          city: city,
          totalSeats: totalSeats,
          ownerPhoto: ownerPhoto,
        );
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to update owner profile',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Update student profile (PUT /student/profile)
  static Future<ApiResponse<Map<String, dynamic>>> updateStudentProfile({
    required String fullName,
    required String examCategory,
    String? emergencyContact,
    required String gender,
    String? mobile,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final cleanMobile = mobile?.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/profile');

      String? cleanEmergency;
      if (emergencyContact != null && emergencyContact.trim().isNotEmpty) {
        final digits = emergencyContact.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10) {
          cleanEmergency = '+91$digits';
        } else if (digits.length > 10 && digits.length <= 13) {
          cleanEmergency = emergencyContact.trim().startsWith('+') ? '+$digits' : digits;
        }
      }

      final body = jsonEncode({
        'fullName': fullName.trim(),
        'examCategory': examCategory,
        if (cleanEmergency != null) 'emergencyContact': cleanEmergency,
        'gender': gender,
        if (cleanMobile != null && cleanMobile.length == 10) 'mobile': cleanMobile,
        if (cleanMobile != null && cleanMobile.length == 10) 'countryCode': '+91',
      });

      final response = await _client
          .put(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await AuthStorage.saveStudentProfile(
          fullName: fullName,
          examCategory: examCategory,
          emergencyContact: cleanEmergency ?? emergencyContact ?? '',
          gender: gender,
        );
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to update student profile',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  // --------------------------------------------------------------------------
  // STUDENT APIS
  // --------------------------------------------------------------------------

  /// Fetch active student dashboard
  static Future<ApiResponse<Map<String, dynamic>>> getStudentDashboard() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/dashboard');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Punch-in via QR scan
  static Future<ApiResponse<Map<String, dynamic>>> scanAttendanceQr({
    required String qrPayload,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/attendance/scan-qr');
      final bodyMap = <String, dynamic>{
        'qrPayload': qrPayload,
      };
      if (latitude != null && longitude != null) {
        bodyMap['latitude'] = latitude;
        bodyMap['longitude'] = longitude;
      }
      final body = jsonEncode(bodyMap);

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to record attendance',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Punch out of current study session
  static Future<ApiResponse<Map<String, dynamic>>> punchOut() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/attendance/punch-out');
      final response = await _client
          .post(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get student monthly attendance calendar logs
  static Future<ApiResponse<Map<String, dynamic>>> getStudentMonthlyAttendance({
    int? month,
    int? year,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}/student/attendance/monthly')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get student study productivity metrics
  static Future<ApiResponse<Map<String, dynamic>>> getStudentProductivity() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/analytics/productivity');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Public library explore list
  static Future<ApiResponse<Map<String, dynamic>>> exploreLibraries({
    String? city,
    String? query,
    double? lat,
    double? lng,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      if (lat != null && lng != null) {
        queryParams['lat'] = lat.toString();
        queryParams['lng'] = lng.toString();
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/libraries/explore')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  // --------------------------------------------------------------------------
  // OWNER APIS
  // --------------------------------------------------------------------------

  /// Fetch owner dashboard KPIs
  static Future<ApiResponse<Map<String, dynamic>>> getOwnerDashboard() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/dashboard');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Fetch floor map seat allocations
  static Future<ApiResponse<Map<String, dynamic>>> getFloorMap({
    String filter = 'all',
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/seats/floor-map?filter=$filter');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Fetch members list
  static Future<ApiResponse<Map<String, dynamic>>> getMembers({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members?page=$page&size=$size');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Onboard / admit new member (legacy / direct walk-in)
  static Future<ApiResponse<Map<String, dynamic>>> addMember({
    required String fullName,
    required String mobile,
    required String assignedSeat,
    required double monthlyFee,
    String duration = '1m',
    String? planName,
    String? shiftTiming,
    String paymentMethod = 'CASH',
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/add');
      final body = jsonEncode({
        'fullName': fullName.trim(),
        'mobile': mobile.replaceAll(RegExp(r'\D'), ''),
        'assignedSeat': assignedSeat,
        'monthlyFee': monthlyFee,
        'duration': duration,
        'planName': planName ?? 'Full Day Shift',
        'shiftTiming': shiftTiming ?? '08:00 AM - 08:00 PM',
        'paymentMethod': paymentMethod,
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to admit member',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Search student by mobile number for library admission
  static Future<ApiResponse<Map<String, dynamic>>> searchStudentByPhone(String phone) async {
    try {
      final token = await AuthStorage.getToken();
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/search-student?phone=$clean');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString() ?? 'Student lookup failed');
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Quick register a student by owner during walk-in admission
  static Future<ApiResponse<Map<String, dynamic>>> quickRegisterStudent({
    required String fullName,
    required String mobile,
    String? examCategory,
    String? gender,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/quick-register');
      final body = jsonEncode({
        'fullName': fullName.trim(),
        'mobile': mobile.replaceAll(RegExp(r'\D'), ''),
        if (examCategory != null && examCategory.isNotEmpty) 'examCategory': examCategory.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender,
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to register student',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Send admission request to student profile
  static Future<ApiResponse<Map<String, dynamic>>> sendAdmissionRequest({
    String? studentId,
    String? mobile,
    String? fullName,
    required String assignedSeat,
    String? planName,
    String? shiftTiming,
    required double monthlyFee,
    String duration = '1m',
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/send-request');
      final body = jsonEncode({
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile.replaceAll(RegExp(r'\D'), ''),
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName.trim(),
        'assignedSeat': assignedSeat,
        'planName': planName ?? 'Monthly Seat',
        'shiftTiming': shiftTiming ?? 'Full Day (8:00 AM - 8:00 PM)',
        'monthlyFee': monthlyFee,
        'duration': duration,
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to send admission request',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// List admission requests for owner's library
  static Future<ApiResponse<List<dynamic>>> getOwnerAdmissionRequests() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/requests');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return ApiResponse(success: true, data: list);
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Remove or release member from owner library
  static Future<ApiResponse<Map<String, dynamic>>> removeMember(
    String studentId, {
    String action = 'REMOVE',
    String? reason,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/$studentId/remove');
      final body = jsonEncode({
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to remove member');
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get list of removed / ex-members with enroll-in and enroll-out dates
  static Future<ApiResponse<List<Map<String, dynamic>>>> getRemovedMembers() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/removed');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) {
          final list = decoded.map((e) => e as Map<String, dynamic>).toList();
          return ApiResponse(success: true, data: list);
        }
        return ApiResponse(success: true, data: []);
      } else {
        return ApiResponse(
          success: false,
          message: decoded is Map ? decoded['message']?.toString() : 'Failed to fetch removed members',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get owner entrance standee QR code data
  static Future<ApiResponse<Map<String, dynamic>>> getStandeeQr() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/attendance/standee-qr');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Generate dynamic rolling 2-minute attendance QR for library owner
  static Future<ApiResponse<Map<String, dynamic>>> generateDynamicAttendanceQr() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/attendance/dynamic-qr');
      final response = await _client
          .post(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get student past memberships and library leave history
  static Future<ApiResponse<List<Map<String, dynamic>>>> getStudentMembershipHistory() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/memberships/history');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) {
          final list = decoded.map((e) => e as Map<String, dynamic>).toList();
          return ApiResponse(success: true, data: list);
        }
        return ApiResponse(success: true, data: []);
      } else {
        return ApiResponse(
          success: false,
          message: decoded is Map ? decoded['message']?.toString() : 'Failed to fetch membership history',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Change/reallot seat for a member
  static Future<ApiResponse<Map<String, dynamic>>> changeMemberSeat({
    required String studentId,
    required int newSeatNumber,
    String? shiftTiming,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/$studentId/change-seat');
      final body = jsonEncode({
        'newSeatNumber': newSeatNumber,
        if (shiftTiming != null && shiftTiming.isNotEmpty) 'shiftTiming': shiftTiming,
      });
      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          message: json['message']?.toString() ?? 'Failed to reallot seat',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Toggle member status between ACTIVE and INACTIVE
  static Future<ApiResponse<Map<String, dynamic>>> toggleMemberStatus(String studentId) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/$studentId/toggle-status');
      final response = await _client
          .post(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          message: json['message']?.toString() ?? 'Failed to toggle status',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get member's detailed profile
  static Future<ApiResponse<Map<String, dynamic>>> getMemberProfile(String studentId) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/members/$studentId/profile');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          message: json['message']?.toString() ?? 'Failed to get member profile',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  // --------------------------------------------------------------------------
  // STUDENT ADMISSION REQUESTS & SEATS APIS
  // --------------------------------------------------------------------------

  /// Get pending admission requests sent to student
  static Future<ApiResponse<List<dynamic>>> getStudentAdmissionRequests() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/memberships/requests');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return ApiResponse(success: true, data: list);
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Accept an admission request
  static Future<ApiResponse<Map<String, dynamic>>> acceptAdmissionRequest(String requestId) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/memberships/requests/$requestId/accept');
      final response = await _client
          .post(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to accept admission offer',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Reject an admission request
  static Future<ApiResponse<Map<String, dynamic>>> rejectAdmissionRequest(String requestId, {String? reason}) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/memberships/requests/$requestId/reject');
      final body = jsonEncode({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      final response = await _client
          .post(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to reject admission offer',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get seats of a library (vacant / full + shift timing)
  static Future<ApiResponse<Map<String, dynamic>>> getLibrarySeats(String libraryId) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/libraries/$libraryId/seats');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final list = decoded;
          int occupied = 0;
          int reserved = 0;
          int available = 0;
          for (final item in list) {
            final st = (item is Map ? item['status']?.toString() : '')?.toLowerCase() ?? '';
            if (st.contains('occupied')) {
              occupied++;
            } else if (st.contains('reserved')) {
              reserved++;
            } else {
              available++;
            }
          }
          final map = <String, dynamic>{
            'totalSeats': list.length,
            'availableSeats': available,
            'occupiedSeats': occupied,
            'reservedSeats': reserved,
            'seats': list,
          };
          return ApiResponse(success: true, data: map);
        } else if (decoded is Map<String, dynamic>) {
          return ApiResponse(success: true, data: decoded);
        }
        return ApiResponse(success: true, data: {'totalSeats': 0, 'seats': []});
      } else {
        try {
          final json = jsonDecode(response.body);
          final msg = json is Map ? json['message']?.toString() : 'Failed to load seats';
          return ApiResponse(success: false, message: msg);
        } catch (_) {
          return ApiResponse(success: false, message: 'Server returned error ${response.statusCode}');
        }
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  // --------------------------------------------------------------------------
  // GOOGLE MAPS BUSINESS PROFILE & FACILITIES APIS
  // --------------------------------------------------------------------------

  /// Get owner library Google Business profile
  static Future<ApiResponse<Map<String, dynamic>>> getOwnerBusinessProfile() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/library/business-profile');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Update owner library Google Business profile
  static Future<ApiResponse<Map<String, dynamic>>> updateOwnerBusinessProfile({
    String? ownerName,
    String? mobile,
    String? libraryName,
    String? branchName,
    String? address,
    String? area,
    String? city,
    int? totalSeats,
    double? monthlyPrice,
    List<String>? photos,
    String? googleMapsUrl,
    String? timing,
    String? operatingDays,
    String? contactPhone,
    String? contactEmail,
    String? websiteUrl,
    String? whatsappNumber,
    String? instagramUrl,
    String? facebookUrl,
    String? youtubeUrl,
    List<String>? amenities,
    String? ownerPhoto,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/library/business-profile');
      final body = jsonEncode({
        if (ownerName != null) 'ownerName': ownerName.trim(),
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile.replaceAll(RegExp(r'\D'), ''),
        if (libraryName != null) 'libraryName': libraryName.trim(),
        if (branchName != null) 'branchName': branchName.trim(),
        if (address != null) 'address': address.trim(),
        if (area != null) 'area': area.trim(),
        if (city != null) 'city': city.trim(),
        if (totalSeats != null) 'totalSeats': totalSeats,
        if (monthlyPrice != null) 'monthlyPrice': monthlyPrice,
        if (photos != null) 'photos': photos,
        if (googleMapsUrl != null) 'googleMapsUrl': googleMapsUrl.trim(),
        if (timing != null) 'timing': timing.trim(),
        if (operatingDays != null) 'operatingDays': operatingDays.trim(),
        if (contactPhone != null) 'contactPhone': contactPhone.trim(),
        if (contactEmail != null) 'contactEmail': contactEmail.trim(),
        if (websiteUrl != null) 'websiteUrl': websiteUrl.trim(),
        if (whatsappNumber != null) 'whatsappNumber': whatsappNumber.trim(),
        if (instagramUrl != null) 'instagramUrl': instagramUrl.trim(),
        if (facebookUrl != null) 'facebookUrl': facebookUrl.trim(),
        if (youtubeUrl != null) 'youtubeUrl': youtubeUrl.trim(),
        if (amenities != null) 'amenities': amenities,
        if (ownerPhoto != null && ownerPhoto.isNotEmpty) 'ownerPhoto': ownerPhoto.trim(),
      });

      final response = await _client
          .put(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (ownerPhoto != null && ownerPhoto.isNotEmpty) {
          await AuthStorage.saveOwnerPhoto(ownerPhoto.trim());
        }
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to update business profile',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Update owner photo directly (PUT /owner/profile/photo)
  static Future<ApiResponse<Map<String, dynamic>>> updateOwnerPhoto(String photoUrl) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/profile/photo');
      final body = jsonEncode({'photoUrl': photoUrl.trim()});

      final response = await _client
          .put(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await AuthStorage.saveOwnerPhoto(photoUrl.trim());
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to update owner photo',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Upload photo for library via camera or gallery
  static Future<ApiResponse<String>> uploadLibraryPhoto(File imageFile) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/library/photos/upload');
      final fileSize = await imageFile.length();
      if (fileSize > maxUploadBytes) {
        return ApiResponse(success: false, message: 'Photo is too large. Please choose an image under 8 MB.');
      }
      final request = http.MultipartRequest('POST', uri);

      final headers = _buildHeaders(token: token);
      headers.remove('Content-Type'); // Multipart sets boundary automatically
      request.headers.addAll(headers);

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && json['url'] != null) {
        String url = json['url'].toString();
        if (url.startsWith('/')) {
          url = '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$url';
        }
        return ApiResponse(success: true, data: url);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString() ?? 'Upload failed');
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e, 'Photo upload failed'));
    }
  }

  /// Get public/student library Google Business profile by ID
  static Future<ApiResponse<Map<String, dynamic>>> getPublicLibraryDetails(String libraryId) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/libraries/$libraryId');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get student's active enrolled library details
  static Future<ApiResponse<Map<String, dynamic>>> getActiveLibraryDetails() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/active-library');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getStudentActiveLibrary() => getActiveLibraryDetails();

  /// Get fee collection summary and list of all fee receipts
  static Future<ApiResponse<Map<String, dynamic>>> getOwnerCollections() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/collections');
      final response = await _client
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message']?.toString(),
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Record offline fee collection from student
  static Future<ApiResponse<Map<String, dynamic>>> recordFeeCollection({
    required String studentId,
    String? membershipId,
    required num originalAmount,
    required num collectedAmount,
    required String collectionDate, // 'YYYY-MM-DD'
    String paymentMode = 'CASH',
    String? remarks,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/collections');
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(token: token),
            body: jsonEncode({
              'studentId': studentId,
              if (membershipId != null) 'membershipId': membershipId,
              'originalAmount': originalAmount,
              'collectedAmount': collectedAmount,
              'collectionDate': collectionDate,
              'paymentMode': paymentMode,
              if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
            }),
          )
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(success: true, data: json['data'] as Map<String, dynamic>? ?? json, message: json['message']?.toString() ?? 'Fee collection recorded successfully');
      } else {
        return ApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to record collection');
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Update fee collection amount and date only
  static Future<ApiResponse<Map<String, dynamic>>> updateFeeCollection(
    String collectionId, {
    required num collectedAmount,
    required String collectionDate, // 'YYYY-MM-DD'
    String? remarks,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/collections/$collectionId');
      final response = await _client
          .put(
            uri,
            headers: _buildHeaders(token: token),
            body: jsonEncode({
              'collectedAmount': collectedAmount,
              'collectionDate': collectionDate,
              if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
            }),
          )
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json['data'] as Map<String, dynamic>? ?? json, message: json['message']?.toString() ?? 'Fee collection updated successfully');
      } else {
        return ApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to update collection');
      }
    } catch (e) {
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Logout from backend session
  static Future<void> logout() async {
    try {
      final token = await AuthStorage.getToken();
      if (token != null) {
        final uri = Uri.parse('${ApiConfig.baseUrl}/auth/logout');
        await _client.post(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    await AuthStorage.clearSession();
  }
}
