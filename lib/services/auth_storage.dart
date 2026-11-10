import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

/// Persists JWT tokens, user identity, and session credentials
class AuthStorage {
  static const String _keyToken = 'jodo_jwt_token';
  static const String _keyRole = 'jodo_user_role';
  static const String _keyPhone = 'jodo_user_phone';
  static const String _keyUserId = 'jodo_user_id';
  static const String _keyUserName = 'jodo_user_name';
  static const String _keyLibraryName = 'jodo_library_name';
  static const String _keyAddress = 'jodo_address';
  static const String _keyCity = 'jodo_city';
  static const String _keyTotalSeats = 'jodo_total_seats';
  static const String _keyExamCategory = 'jodo_exam_category';
  static const String _keyEmergencyContact = 'jodo_emergency_contact';
  static const String _keyGender = 'jodo_gender';
  static const String _keyStudentCode = 'jodo_student_code';
  static const String _keyDob = 'jodo_dob';

  static Future<void> saveSession({
    required String token,
    required UserRole role,
    required String phone,
    String? userId,
    String? userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRole, role == UserRole.admin ? 'ADMIN' : 'STUDENT');
    await prefs.setString(_keyPhone, phone);
    if (userId != null) await prefs.setString(_keyUserId, userId);
    if (userName != null) await prefs.setString(_keyUserName, userName);
  }

  static Future<void> saveOwnerProfile({
    required String ownerName,
    required String libraryName,
    required String address,
    required String city,
    required int totalSeats,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, ownerName);
    await prefs.setString(_keyLibraryName, libraryName);
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyCity, city);
    await prefs.setInt(_keyTotalSeats, totalSeats);
  }

  static Future<void> saveStudentProfile({
    required String fullName,
    required String examCategory,
    required String emergencyContact,
    required String gender,
    String? studentCode,
    String? dob,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, fullName);
    await prefs.setString(_keyExamCategory, examCategory);
    await prefs.setString(_keyEmergencyContact, emergencyContact);
    await prefs.setString(_keyGender, gender);
    if (studentCode != null) await prefs.setString(_keyStudentCode, studentCode);
    if (dob != null) await prefs.setString(_keyDob, dob);
  }

  static Future<Map<String, dynamic>> getStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName),
      'phone': prefs.getString(_keyPhone),
      'libraryName': prefs.getString(_keyLibraryName),
      'address': prefs.getString(_keyAddress),
      'city': prefs.getString(_keyCity),
      'totalSeats': prefs.getInt(_keyTotalSeats),
      'examCategory': prefs.getString(_keyExamCategory),
      'emergencyContact': prefs.getString(_keyEmergencyContact),
      'gender': prefs.getString(_keyGender),
      'studentCode': prefs.getString(_keyStudentCode),
      'dob': prefs.getString(_keyDob),
    };
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<UserRole?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(_keyRole);
    if (roleStr == 'ADMIN') return UserRole.admin;
    if (roleStr == 'STUDENT') return UserRole.student;
    return null;
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyLibraryName);
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyCity);
    await prefs.remove(_keyTotalSeats);
    await prefs.remove(_keyExamCategory);
    await prefs.remove(_keyEmergencyContact);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyStudentCode);
    await prefs.remove(_keyDob);
  }
}
