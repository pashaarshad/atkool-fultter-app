import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/teacher_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _teacherService = TeacherService();
  Map<String, dynamic>? _userData;
  int _studentCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Fetch fresh data from API
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher-auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final teacherData = jsonDecode(response.body);
        debugPrint('API Response: $teacherData');
        debugPrint(
          'classAssignments in response: ${teacherData['classAssignments']}',
        );
        setState(() {
          _userData = {'teacher': teacherData, 'school': teacherData['school']};
        });
      } else {
        // Fallback to cached data
        final userData = await _authService.getUserData();
        setState(() {
          _userData = userData;
        });
      }
    } catch (e) {
      // Fallback to cached data on error
      final userData = await _authService.getUserData();
      setState(() {
        _userData = userData;
      });
    }

    final studentsResult = await _teacherService.getStudents();
    setState(() {
      if (studentsResult['success']) {
        _studentCount = (studentsResult['data'] as List?)?.length ?? 0;
      }
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFDC3545)),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
        ),
      );
    }

    final teacher = _userData?['teacher'];
    final school = _userData?['school'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFDC3545)),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // School Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4EFF), Color(0xFF9B7EFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4EFF).withAlpha(50),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // School Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: _buildSchoolLogo(school?['logo']),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    school?['name'] ?? 'School Name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    school?['address'] ?? 'School Address',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Teacher Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF).withAlpha(20),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(teacher?['name'] ?? ''),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B4EFF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacher?['name'] ?? 'Teacher Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF28A745).withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Teacher',
                                style: TextStyle(
                                  color: Color(0xFF28A745),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email, 'Email', teacher?['email'] ?? '-'),
                  _buildInfoRow(
                    Icons.phone,
                    'Mobile',
                    teacher?['mobileNo'] ?? '-',
                  ),
                  _buildClassAssignmentsRow(teacher?['classAssignments']),
                  _buildInfoRow(
                    Icons.subject,
                    'Subject',
                    teacher?['subject'] ?? '-',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people,
                    label: 'My Students',
                    value: '$_studentCount',
                    color: const Color(0xFF6B4EFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.fact_check,
                    label: 'Attendance',
                    value: 'Today',
                    color: const Color(0xFF28A745),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Actions - Only About App
            _buildActionTile(
              icon: Icons.info_outline,
              label: 'About App',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'ATKool',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.school,
                    size: 50,
                    color: Color(0xFF6B4EFF),
                  ),
                  children: const [
                    Text(
                      'A comprehensive school management app for teachers and parents.',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC3545),
                  side: const BorderSide(color: Color(0xFFDC3545), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassAssignmentsRow(dynamic classAssignmentsData) {
    List<Widget> badges = [];

    if (classAssignmentsData != null &&
        classAssignmentsData is List &&
        classAssignmentsData.isNotEmpty) {
      for (int i = 0; i < classAssignmentsData.length; i++) {
        var ca = classAssignmentsData[i];
        badges.add(
          Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4EFF), Color(0xFF9B7EFF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${ca['className']}-${ca['section']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.class_, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          const Text('Classes', style: TextStyle(color: Colors.grey)),
          const Spacer(),
          if (badges.isEmpty)
            const Text(
              '-',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: badges),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B4EFF)),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildSchoolLogo(String? logoData) {
    if (logoData == null || logoData.isEmpty) {
      return const Icon(Icons.school, size: 45, color: Color(0xFF6B4EFF));
    }

    // Check if it's a Base64 data URL
    if (logoData.startsWith('data:image')) {
      try {
        final base64String = logoData.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.school, size: 45, color: Color(0xFF6B4EFF)),
        );
      } catch (e) {
        return const Icon(Icons.school, size: 45, color: Color(0xFF6B4EFF));
      }
    } else {
      // Regular URL
      return Image.network(
        logoData,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.school, size: 45, color: Color(0xFF6B4EFF)),
      );
    }
  }
}
