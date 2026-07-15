import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ChatService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // --- PARENT CHAT ---
  Future<Map<String, dynamic>> getParentConversations() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/parent/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['conversations'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load conversations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> getParentMessages(String teacherId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/parent/messages?teacherId=$teacherId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load messages'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> sendParentMessage({
    required String teacherId,
    required String message,
    required String messageType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/parent/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'teacherId': teacherId,
          'message': message,
          'messageType': messageType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // --- TEACHER CHAT ---
  Future<Map<String, dynamic>> getTeacherConversations() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/teacher/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load conversations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> getTeacherMessages(String studentId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/teacher/messages/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load messages'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> sendTeacherMessage({
    required String studentId,
    required String message,
    required String messageType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/teacher/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'studentId': studentId,
          'message': message,
          'messageType': messageType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // --- UNIVERSAL CHAT ---
  Future<Map<String, dynamic>> getUniversalContacts() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/universal/contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load contacts'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> getUniversalConversations() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/universal/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load conversations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> getUniversalMessages(String partnerId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/universal/messages/$partnerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load messages'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> sendUniversalMessage({
    required String receiverId,
    required String message,
    required String messageType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/universal/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiverId': receiverId,
          'message': message,
          'messageType': messageType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
