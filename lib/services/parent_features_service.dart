import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ParentFeaturesService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 1. DateSheets
  Future<Map<String, dynamic>> getDateSheets() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/parent-auth/exams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load DateSheets'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // 2. Notice Board
  Future<Map<String, dynamic>> getNoticeBoard() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/parent-auth/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load notices'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // 3. Homework
  Future<Map<String, dynamic>> getHomework() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/homework/parent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load homework'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> submitHomework(String homeworkId, String content) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/homework/parent/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'homeworkId': homeworkId,
          'content': content,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to submit homework'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // 4. Report Card (Results)
  Future<Map<String, dynamic>> getReportCard() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/results/parent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['results'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load report card'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // 5. Timetable
  Future<Map<String, dynamic>> getTimetable(String className, String section) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/timetable?className=${Uri.encodeComponent(className)}&section=${Uri.encodeComponent(section)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load timetable'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // 6. Settings
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/parent-auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Password updated successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to change password'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> changeEmail(String newEmail) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/parent-auth/change-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'newEmail': newEmail,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Email updated successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to change email'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
