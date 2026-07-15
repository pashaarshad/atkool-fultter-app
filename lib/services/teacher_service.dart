import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class TeacherService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get all students for the teacher (optionally filtered by class)
  Future<Map<String, dynamic>> getStudents({
    String? className,
    String? section,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Build query parameters
      String url = '${ApiConfig.baseUrl}/teacher/students';
      if (className != null && section != null) {
        url += '?className=$className&section=$section';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch students',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Add a new student
  Future<Map<String, dynamic>> addStudent({
    required String name,
    required String className,
    required String section,
    String? rollNo,
    String? studentId,
    String? email,
    String? mobileNo,
    String? parentName,
    String? parentMobile,
    String? guardianMobile,
    String? vanId,
    String? pickupPoint,
    String? address,
    String? photo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/teacher/students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'className': className,
          'section': section,
          'rollNo': rollNo,
          'studentId': studentId,
          'email': email,
          'mobileNo': mobileNo,
          'parentName': parentName,
          'parentMobile': parentMobile,
          'guardianMobile': guardianMobile,
          'vanId': vanId,
          'pickupPoint': pickupPoint,
          'address': address,
          'photo': photo,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add student',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Get school vans list
  Future<Map<String, dynamic>> getVans() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/school-vans'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch vans',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Generate parent login credentials for a student
  Future<Map<String, dynamic>> generateParentLogin(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/teacher/generate-parent-login'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'studentId': studentId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to generate login',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Get teachers list for class assignment
  Future<Map<String, dynamic>> getTeachers() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch teachers',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // Get teacher's student requests (all statuses)
  Future<Map<String, dynamic>> getMyRequests() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/my-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch requests',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
