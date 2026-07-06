import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/teacher_service.dart';
import '../config/api_config.dart';
import 'login_screen.dart';
import 'add_student_screen.dart';
import 'my_students_screen.dart';
import 'take_attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'profile_screen.dart';
import 'school_events_screen.dart';
import 'upcoming_exams_screen.dart';
import 'notifications_screen.dart';
import 'parent_attendance_screen.dart';
import 'student_requests_screen.dart';
import 'parent_fees_screen.dart';
import 'chat_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _teacherService = TeacherService();
  Map<String, dynamic>? _userData;
  String? _userType;
  bool _isLoading = true;
  int _currentIndex = 0;
  int _studentCount = 0;
  int _presentToday = 0;
  int _totalToday = 0;
  int _unreadNotifications = 0;
  List<dynamic> _classAssignments = [];
  Map<String, dynamic>? _selectedClass;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getUserData();
    final userType = await _authService.getUserType();

    // Check subscription for teachers only
    if (userType == 'teacher') {
      final hasActiveSubscription = await _checkSubscription();
      if (!hasActiveSubscription) {
        return; // Already handled logout in _checkSubscription
      }
    }

    // Load class assignments for teachers
    List<dynamic> classAssignments = [];
    Map<String, dynamic>? selectedClass;
    if (userType == 'teacher') {
      classAssignments = userData?['teacher']?['classAssignments'] ?? [];
      if (classAssignments.isNotEmpty) {
        selectedClass = classAssignments[0] as Map<String, dynamic>;
      }
    }

    // Fetch student count (filtered by selected class if available)
    int studentCount = 0;
    if (selectedClass != null) {
      final studentsResult = await _teacherService.getStudents(
        className: selectedClass['className']?.toString(),
        section: selectedClass['section']?.toString(),
      );
      if (studentsResult['success']) {
        studentCount = (studentsResult['data'] as List?)?.length ?? 0;
      }
    } else {
      final studentsResult = await _teacherService.getStudents();
      if (studentsResult['success']) {
        studentCount = (studentsResult['data'] as List?)?.length ?? 0;
      }
    }

    // Fetch today's attendance
    await _fetchTodayAttendance();

    setState(() {
      _userData = userData;
      _userType = userType;
      _classAssignments = classAssignments;
      _selectedClass = selectedClass;
      _studentCount = studentCount;
      _isLoading = false;
    });
  }

  Future<bool> _checkSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/subscription-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['active'] != true) {
          // No active subscription - show message and logout
          if (mounted) {
            await _authService.logout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No active subscription plan. Please contact your school administrator.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          }
          return false;
        }
        return true;
      }
      return true; // Allow login if API fails (fail-open)
    } catch (e) {
      return true; // Allow login if exception (fail-open)
    }
  }

  Future<void> _fetchTodayAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Build URL with optional class filter
      String url = '${ApiConfig.baseUrl}/teacher/attendance?date=$dateStr';
      if (_selectedClass != null) {
        url +=
            '&className=${_selectedClass!['className']}&section=${_selectedClass!['section']}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final allData = jsonDecode(response.body) as List;

        // Filter by selected class if provided
        List<dynamic> data;
        if (_selectedClass != null) {
          data = allData.where((r) {
            final recordClassName = r['className']?.toString() ?? '';
            final recordSection = r['section']?.toString() ?? '';
            final selectedClassName =
                _selectedClass!['className']?.toString() ?? '';
            final selectedSection =
                _selectedClass!['section']?.toString() ?? '';
            return recordClassName == selectedClassName &&
                recordSection == selectedSection;
          }).toList();
        } else {
          data = allData;
        }

        final presentCount = data.where((r) => r['status'] == 'present').length;
        setState(() {
          _presentToday = presentCount;
          _totalToday = data.length;
        });
      }
    } catch (e) {
      // Ignore errors
    }

    // Load unread notification count
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/messages/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _unreadNotifications = data['count'] ?? 0;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void _showClassSwitcher() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final navBarHeight = MediaQuery.of(context).padding.bottom;
        final screenHeight = MediaQuery.of(context).size.height;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          // Max 75% of screen, but always leaves room above nav bar
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: Color(0xFF6B4EFF), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Switch Class',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Text(
                  'Select a class to view its students and attendance',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              // Scrollable list — takes remaining space, adds nav bar padding at bottom
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + navBarHeight),
                  children: _classAssignments.map((classItem) {
                    final isSelected =
                        _selectedClass != null &&
                        _selectedClass!['className'] == classItem['className'] &&
                        _selectedClass!['section'] == classItem['section'];
                    return GestureDetector(
                      onTap: () async {
                        final newClass = classItem as Map<String, dynamic>;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switching to Class ${classItem['className']}-${classItem['section']}...'),
                            backgroundColor: const Color(0xFF6B4EFF),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        setState(() { _selectedClass = newClass; });
                        final studentsResult = await _teacherService.getStudents(
                          className: newClass['className']?.toString(),
                          section: newClass['section']?.toString(),
                        );
                        setState(() {
                          if (studentsResult['success']) {
                            _studentCount = (studentsResult['data'] as List?)?.length ?? 0;
                          }
                        });
                        await _fetchTodayAttendance();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6B4EFF) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6B4EFF) : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white24 : const Color(0xFF6B4EFF).withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.class_, color: isSelected ? Colors.white : const Color(0xFF6B4EFF)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Class ${classItem['className']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  Text(
                                    'Section ${classItem['section']}',
                                    style: TextStyle(fontSize: 14, color: isSelected ? Colors.white70 : Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
        ),
      );
    }

    final isTeacher = _userType == 'teacher';
    final name = isTeacher
        ? _userData?['teacher']?['name'] ?? 'Teacher'
        : _userData?['student']?['name'] ?? 'Student';
    final schoolName = _userData?['school']?['name'] ?? 'School';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(name, schoolName, isTeacher),

            // Stats Cards
            if (isTeacher) _buildTeacherStats(),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    if (isTeacher) ...[
                      _buildSectionHeader('Quick Actions'),
                      const SizedBox(height: 12),
                      _buildQuickActionGrid(),
                    ] else ...[
                      _buildParentInfoCard(),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Menu'),
                      const SizedBox(height: 12),
                      _buildParentQuickActions(),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (isTeacher && _classAssignments.length > 1)
          ? FloatingActionButton.extended(
              onPressed: _showClassSwitcher,
              backgroundColor: const Color(0xFF6B4EFF),
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: Text(
                _selectedClass != null
                    ? '${_selectedClass!['className']}-${_selectedClass!['section']}'
                    : 'Switch Class',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: isTeacher ? _buildBottomNav() : null,
    );
  }

  Widget _buildHeader(String name, String schoolName, bool isTeacher) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Welcome Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Notification Bell - Only for teachers
          if (isTeacher)
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
                _loadUnreadCount();
              },
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF1A1A1A),
                      size: 24,
                    ),
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _unreadNotifications > 9
                                ? '9+'
                                : '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (isTeacher) const SizedBox(width: 12),

          // School Logo - Clickable to Profile (teachers only)
          GestureDetector(
            onTap: isTeacher
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  }
                : null,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF6B4EFF), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildSchoolLogo(_userData?['school']?['logo']),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherStats() {
    final attendancePercent = _totalToday > 0
        ? ((_presentToday / _totalToday) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              value: '$_studentCount',
              label: 'Students',
              color: const Color(0xFFDC3545),
              icon: Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              value: _totalToday > 0 ? '$attendancePercent%' : 'N/A',
              label: 'Attendance',
              color: const Color(0xFF28A745),
              icon: Icons.check_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQuickActionGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.fact_check,
                label: 'Take\nAttendance',
                color: const Color(0xFF28A745),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TakeAttendanceScreen(selectedClass: _selectedClass),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.people,
                label: 'My\nStudents',
                color: const Color(0xFF007BFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyStudentsScreen(
                        classAssignments: _classAssignments,
                        selectedClass: _selectedClass,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.event,
                label: 'School\nEvents',
                color: const Color(0xFFFF9800),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SchoolEventsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.assignment,
                label: 'Upcoming\nExams',
                color: const Color(0xFF6B4EFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UpcomingExamsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Student Requests Row
        Row(
          children: [
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.pending_actions,
                label: 'Student\nRequests',
                color: const Color(0xFF17A2B8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentRequestsScreen(selectedClass: _selectedClass),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildClickableActionTile(
                icon: Icons.chat,
                label: 'Chat with\nParents',
                color: const Color(0xFFE83E8C),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClickableActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildActionTile(icon: icon, label: label, color: color),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentInfoCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4EFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.child_care,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Info',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      _userData?['student']?['name'] ?? 'Student',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _buildInfoItem(
            'Class',
            '${_userData?['student']?['className'] ?? '-'} ${_userData?['student']?['section'] ?? ''}',
          ),
          _buildInfoItem(
            'Roll No',
            _userData?['student']?['rollNo']?.toString() ?? '-',
          ),
          _buildInfoItem('Status', 'Active'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentQuickActions() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ParentAttendanceScreen(),
              ),
            );
          },
          child: _buildMenuTile(
            icon: Icons.fact_check,
            label: 'View Attendance History',
            color: const Color(0xFF28A745),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ParentFeesScreen(),
              ),
            );
          },
          child: _buildMenuTile(
            icon: Icons.payment,
            label: 'Fees & Payments',
            color: const Color(0xFF6B4EFF),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatListScreen(),
              ),
            );
          },
          child: _buildMenuTile(
            icon: Icons.chat,
            label: 'Chat with Teacher',
            color: const Color(0xFF007BFF),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await _authService.logout();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          },
          child: _buildMenuTile(
            icon: Icons.logout,
            label: 'Logout',
            color: const Color(0xFFDC3545),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.history, 'History', 1),
              _buildNavItem(Icons.person_add, 'Add Student', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          // Navigate to Attendance History
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AttendanceHistoryScreen(selectedClass: _selectedClass),
            ),
          );
        } else if (index == 2) {
          // Navigate to Add Student
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddStudentScreen(classAssignments: _classAssignments),
            ),
          );
        } else {
          setState(() => _currentIndex = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B4EFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolLogo(String? logoData) {
    if (logoData == null || logoData.isEmpty) {
      return const Icon(Icons.school, color: Colors.white, size: 28);
    }

    // Check if it's a Base64 data URL
    if (logoData.startsWith('data:image')) {
      try {
        final base64String = logoData.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.school, color: Colors.white, size: 28),
        );
      } catch (e) {
        return const Icon(Icons.school, color: Colors.white, size: 28);
      }
    } else {
      // Regular URL
      return Image.network(
        logoData,
        fit: BoxFit.cover,
        width: 50,
        height: 50,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.school, color: Colors.white, size: 28),
      );
    }
  }
}
