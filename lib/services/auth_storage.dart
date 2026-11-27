import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

/// Persists JWT tokens, user identity, and session credentials.
///
/// The JWT and personal data (phone, DOB, address, emergency contact, gender)
/// live in the platform keystore/keychain via [FlutterSecureStorage]. Only
/// non-sensitive display values stay in SharedPreferences.
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
  static const String _keyOwnerPhoto = 'jodo_owner_photo';
  static const String _keyFcmToken = 'jodo_fcm_token';
  static const String _keyAppBuild = 'jodo_app_installed_build';
  static const String currentAppBuild = 'v2_clean_release';

  /// Keys that must never be written to SharedPreferences.
  static const Set<String> _secureKeys = {
    _keyToken,
    _keyPhone,
    _keyAddress,
    _keyEmergencyContact,
    _keyGender,
    _keyDob,
  };

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> _setString(String key, String value) async {
    if (_secureKeys.contains(key)) {
      await _secure.write(key: key, value: value);
      // Remove any legacy plain-text copy.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(key)) await prefs.remove(key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  static Future<String?> _getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_secureKeys.contains(key)) return prefs.getString(key);

    String? value;
    try {
      value = await _secure.read(key: key);
    } catch (_) {
      value = null;
    }
    // One-time migration from older builds that stored this in plain text.
    final legacy = prefs.getString(key);
    if (value == null && legacy != null) {
      await _secure.write(key: key, value: legacy);
      value = legacy;
    }
    if (legacy != null) await prefs.remove(key);
    return value;
  }

  static Future<void> _clearSecure() async {
    try {
      await _secure.deleteAll();
    } catch (_) {}
  }

  /// Ensures old stale cache from prior APK versions is purged on first run of a new APK build
  static Future<bool> checkAndMigrateBuildCache() async {
    final prefs = await SharedPreferences.getInstance();
    final installedBuild = prefs.getString(_keyAppBuild);
    if (installedBuild != currentAppBuild) {
      await prefs.clear();
      // Keychain entries survive app reinstall on iOS, so wipe them too.
      await _clearSecure();
      await prefs.setString(_keyAppBuild, currentAppBuild);
      return true; // cache was purged
    }
    return false;
  }

  static Future<void> saveSession({
    required String token,
    required UserRole role,
    required String phone,
    String? userId,
    String? userName,
  }) async {
    await _setString(_keyToken, token);
    await _setString(_keyRole, role == UserRole.admin ? 'ADMIN' : 'STUDENT');
    await _setString(_keyPhone, phone);
    if (userId != null) await _setString(_keyUserId, userId);
    if (userName != null) await _setString(_keyUserName, userName);
  }

  static Future<void> saveOwnerProfile({
    required String ownerName,
    required String libraryName,
    required String address,
    required String city,
    required int totalSeats,
    String? ownerPhoto,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(_keyUserName, ownerName);
    await _setString(_keyLibraryName, libraryName);
    await _setString(_keyAddress, address);
    await _setString(_keyCity, city);
    await prefs.setInt(_keyTotalSeats, totalSeats);
    if (ownerPhoto != null) {
      await _setString(_keyOwnerPhoto, ownerPhoto);
    }
  }

  static Future<void> saveOwnerPhoto(String photoUrl) async {
    await _setString(_keyOwnerPhoto, photoUrl);
  }

  static Future<void> saveStudentProfile({
    required String fullName,
    required String examCategory,
    required String emergencyContact,
    required String gender,
    String? studentCode,
    String? dob,
  }) async {
    await _setString(_keyUserName, fullName);
    await _setString(_keyExamCategory, examCategory);
    await _setString(_keyEmergencyContact, emergencyContact);
    await _setString(_keyGender, gender);
    if (studentCode != null) await _setString(_keyStudentCode, studentCode);
    if (dob != null) await _setString(_keyDob, dob);
  }

  static Future<Map<String, dynamic>> getStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': await _getString(_keyUserName),
      'phone': await _getString(_keyPhone),
      'libraryName': await _getString(_keyLibraryName),
      'address': await _getString(_keyAddress),
      'city': await _getString(_keyCity),
      'totalSeats': prefs.getInt(_keyTotalSeats),
      'examCategory': await _getString(_keyExamCategory),
      'emergencyContact': await _getString(_keyEmergencyContact),
      'gender': await _getString(_keyGender),
      'studentCode': await _getString(_keyStudentCode),
      'dob': await _getString(_keyDob),
      'ownerPhoto': await _getString(_keyOwnerPhoto),
    };
  }

  static Future<String?> getToken() => _getString(_keyToken);

  static Future<UserRole?> getRole() async {
    final roleStr = await _getString(_keyRole);
    if (roleStr == 'ADMIN') return UserRole.admin;
    if (roleStr == 'STUDENT') return UserRole.student;
    return null;
  }

  static Future<String?> getPhone() => _getString(_keyPhone);
  static Future<void> savePhone(String phone) => _setString(_keyPhone, phone);

  static Future<String?> getUserName() => _getString(_keyUserName);

  static Future<String?> getUserId() => _getString(_keyUserId);

  static Future<void> saveFcmToken(String token) => _setString(_keyFcmToken, token);
  static Future<String?> getFcmToken() => _getString(_keyFcmToken);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final build = prefs.getString(_keyAppBuild);
    await prefs.clear();
    await _clearSecure();
    if (build != null) {
      await prefs.setString(_keyAppBuild, build);
    }
  }
}
