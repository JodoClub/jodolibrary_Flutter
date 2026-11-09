import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';
import 'api_config.dart';
import 'auth_storage.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? code;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.code,
  });
}

class ApiService {
  static const Duration _timeout = Duration(seconds: 12);

  static Map<String, String> _buildHeaders({String? token, String? customTxnId}) {
    final txn = customTxnId ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}';
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

      final response = await http
          .post(uri, headers: _buildHeaders(), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(
          success: false,
          code: json['code'] as String?,
          message: json['message'] as String? ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Could not connect to backend server: $e',
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

      final response = await http
          .post(uri, headers: _buildHeaders(), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final token = json['token'] as String;
        final user = json['user'] as Map<String, dynamic>?;
        await AuthStorage.saveSession(
          token: token,
          role: role,
          phone: cleanMobile,
          userId: user?['id'] as String?,
          userName: user?['name'] as String?,
        );
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
        message: 'Backend connection error: $e',
      );
    }
  }

  /// Student initial profile setup
  static Future<ApiResponse<Map<String, dynamic>>> studentSetup({
    required String fullName,
    required String examCategory,
    required String emergencyContact,
    required String gender,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/student-setup');
      final body = jsonEncode({
        'fullName': fullName.trim(),
        'examCategory': examCategory,
        'emergencyContact': emergencyContact.startsWith('+') ? emergencyContact : '+91$emergencyContact',
        'gender': gender,
      });

      final response = await http
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
      return ApiResponse(success: false, message: '$e');
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
      });

      final response = await http
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
      return ApiResponse(success: false, message: '$e');
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
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
      final body = jsonEncode({
        'qrPayload': qrPayload,
        'latitude': latitude ?? 25.6093,
        'longitude': longitude ?? 85.1376,
      });

      final response = await http
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
      return ApiResponse(success: false, message: '$e');
    }
  }

  /// Punch out of current study session
  static Future<ApiResponse<Map<String, dynamic>>> punchOut() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/attendance/punch-out');
      final response = await http
          .post(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
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

      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
    }
  }

  /// Get student study productivity metrics
  static Future<ApiResponse<Map<String, dynamic>>> getStudentProductivity() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/student/analytics/productivity');
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
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

      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
    }
  }

  /// Fetch floor map seat allocations
  static Future<ApiResponse<Map<String, dynamic>>> getFloorMap({
    String filter = 'all',
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/seats/floor-map?filter=$filter');
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
      }
    } catch (e) {
      return ApiResponse(success: false, message: '$e');
    }
  }

  /// Onboard / admit new member
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

      final response = await http
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
      return ApiResponse(success: false, message: '$e');
    }
  }

  /// Logout from backend session
  static Future<void> logout() async {
    try {
      final token = await AuthStorage.getToken();
      if (token != null) {
        final uri = Uri.parse('${ApiConfig.baseUrl}/auth/logout');
        await http.post(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    await AuthStorage.clearSession();
  }
}
