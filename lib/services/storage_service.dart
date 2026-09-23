import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static const String _keyToken = 'auth_token';
  static const String _keyOwnerToken = 'owner_token';
  static const String _keyUser = 'user_data';
  static const String _keyFirstName = 'first_name';
  static const String _keyLastName = 'last_name';
  static const String _keyEmail = 'email';
  static const String _keyRole = 'role';

  /// Initialize SharedPreferences once at startup
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Helper to ensure _prefs is initialized if init() wasn't called
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Save token
  static Future<bool> saveToken(String token) async {
    try {
      final prefs = await _instance;
      return await prefs.setString(_keyToken, token);
    } catch (e) {
      return false;
    }
  }

  // Get token
  static Future<String?> getToken() async {
    try {
      final prefs = await _instance;
      // print("Token: ${prefs.getString(_keyToken)}");
      return prefs.getString(_keyToken);
    } catch (e) {
      return null;
    }
  }

  // Save owner token
  static Future<bool> saveOwnerToken(String token) async {
    try {
      final prefs = await _instance;
      return await prefs.setString(_keyOwnerToken, token);
    } catch (e) {
      return false;
    }
  }

  // Get owner token
  static Future<String?> getOwnerToken() async {
    try {
      final prefs = await _instance;
      return prefs.getString(_keyOwnerToken);
    } catch (e) {
      return null;
    }
  }

  // Save user data
  static Future<bool> saveUser(User user) async {
    try {
      final prefs = await _instance;

      // Save as JSON
      await prefs.setString(_keyUser, jsonEncode(user.toJson()));

      // Save individual fields for easy access
      await prefs.setString(_keyFirstName, user.firstName ?? '');
      await prefs.setString(_keyLastName, user.lastName ?? '');
      await prefs.setString(_keyEmail, user.email ?? '');
      await prefs.setString(_keyRole, user.role);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get user data
  static Future<User?> getUser() async {
    try {
      final prefs = await _instance;
      final userJson = prefs.getString(_keyUser);

      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get individual user fields
  static Future<String?> getFirstName() async {
    final prefs = await _instance;
    return prefs.getString(_keyFirstName);
  }

  static Future<String?> getLastName() async {
    final prefs = await _instance;
    return prefs.getString(_keyLastName);
  }

  static Future<String?> getEmail() async {
    final prefs = await _instance;
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getRole() async {
    final prefs = await _instance;
    return prefs.getString(_keyRole);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all user data (logout)
  static Future<bool> clearUserData() async {
    try {
      final prefs = await _instance;
      await prefs.remove(_keyToken);
      await prefs.remove(_keyOwnerToken);
      await prefs.remove(_keyUser);
      await prefs.remove(_keyFirstName);
      await prefs.remove(_keyLastName);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyRole);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Save login credentials (for remember me)
  static Future<bool> saveCredentials(String email, String password) async {
    try {
      final prefs = await _instance;
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get saved credentials
  static Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final prefs = await _instance;
      final email = prefs.getString('saved_email');
      final password = prefs.getString('saved_password');

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Clear saved credentials
  static Future<bool> clearSavedCredentials() async {
    try {
      final prefs = await _instance;
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      return true;
    } catch (e) {
      return false;
    }
  }
}
