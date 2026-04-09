import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _userDataKey = 'user_data';

  // Get unique device ID and name
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';
    String deviceName = '';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? 'browser';
        deviceName = webInfo.browserName.toString();
      } else {
        // Safe for mobile
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      }
    } catch (e) {
      deviceId = 'web-browser';
      deviceName = 'Chrome/Edge';
    }

    return {'deviceId': deviceId, 'deviceName': deviceName};
  }

  // Teacher Login
  Future<Map<String, dynamic>> teacherLogin(
    String email,
    String password,
  ) async {
    try {
      // Get device info
      final deviceInfo = await _getDeviceInfo();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/teacher-auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceId': deviceInfo['deviceId'],
          'deviceName': deviceInfo['deviceName'],
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(data['token'], 'teacher', data);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 403 && data['deviceLocked'] == true) {
        return {
          'success': false,
          'message': data['message'] ?? 'Device locked. Contact admin.',
          'deviceLocked': true,
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please check your network.',
      };
    }
  }

  // Parent Login
  Future<Map<String, dynamic>> parentLogin(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/parent-auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(data['token'], 'parent', data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please check your network.',
      };
    }
  }

  // Save session to local storage
  Future<void> _saveSession(
    String token,
    String userType,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userTypeKey, userType);
    await prefs.setString(_userDataKey, jsonEncode(userData));
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  // Get current token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get user type (teacher/parent)
  Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userTypeKey);
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_userDataKey);
    if (dataStr != null) {
      return jsonDecode(dataStr);
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userTypeKey);
    await prefs.remove(_userDataKey);
  }
}
