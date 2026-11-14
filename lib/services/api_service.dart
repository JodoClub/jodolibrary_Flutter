import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';
import 'api_config.dart';
import 'auth_storage.dart';
import 'network_service.dart';

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

class ApiService {
  static const Duration _timeout = Duration(seconds: 12);

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

  static String _formatNetworkError(dynamic e, [String defaultPrefix = 'Could not connect to backend server']) {
    _checkNetworkError(e);
    if (e is SocketException ||
        e.toString().contains('SocketException') ||
        e.toString().contains('Failed host lookup') ||
        e.toString().contains('Network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return '$defaultPrefix: $e';
  }

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
      return ApiResponse(success: false, message: _formatNetworkError(e));
    }
  }

  /// Get authenticated user and role profile (GET /auth/me)
  static Future<ApiResponse<Map<String, dynamic>>> getMe() async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/me');
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        final user = json['user'] as Map<String, dynamic>?;
        final profile = json['profile'] as Map<String, dynamic>?;
        if (user != null) {
          final role = await AuthStorage.getRole();
          if (role == UserRole.admin && profile != null) {
            await AuthStorage.saveOwnerProfile(
              ownerName: user['name']?.toString() ?? '',
              libraryName: profile['name']?.toString() ?? '',
              address: profile['address']?.toString() ?? '',
              city: profile['city']?.toString() ?? 'Patna',
              totalSeats: profile['totalSeats'] is int ? profile['totalSeats'] as int : 60,
            );
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
        return ApiResponse(success: false, message: json['message']?.toString());
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
      });

      final response = await http
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

      final response = await http
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
      return ApiResponse(success: false, message: _formatNetworkError(e));
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
      return ApiResponse(success: false, message: _formatNetworkError(e));
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
      return ApiResponse(success: false, message: _formatNetworkError(e));
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
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
      });

      final response = await http
          .put(uri, headers: _buildHeaders(token: token), body: body)
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
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

  /// Upload photo for library via camera or gallery
  static Future<ApiResponse<String>> uploadLibraryPhoto(File imageFile) async {
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/owner/library/photos/upload');
      final request = http.MultipartRequest('POST', uri);

      final headers = _buildHeaders(token: token);
      headers.remove('Content-Type'); // Multipart sets boundary automatically
      request.headers.addAll(headers);

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
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
      final response = await http
          .get(uri, headers: _buildHeaders(token: token))
          .timeout(_timeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && json['success'] == true) {
        return ApiResponse(success: true, data: json);
      } else {
        return ApiResponse(success: false, message: json['message']?.toString());
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
        await http.post(uri, headers: _buildHeaders(token: token)).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
    await AuthStorage.clearSession();
  }
}
