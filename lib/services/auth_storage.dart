import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

/// Persists JWT tokens, user identity, and session credentials
class AuthStorage {
  static const String _keyToken = 'jodo_jwt_token';
  static const String _keyRole = 'jodo_user_role';
  static const String _keyPhone = 'jodo_user_phone';
  static const String _keyUserId = 'jodo_user_id';
  static const String _keyUserName = 'jodo_user_name';

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
  }
}
