import 'package:flutter/material.dart';
import '../services/parent_features_service.dart';
import '../services/auth_service.dart';

class ParentTimetableScreen extends StatefulWidget {
  const ParentTimetableScreen({super.key});

  @override
  State<ParentTimetableScreen> createState() => _ParentTimetableScreenState();
}

class _ParentTimetableScreenState extends State<ParentTimetableScreen> {
  final _featuresService = ParentFeaturesService();
  final _authService = AuthService();
  
  bool _isLoading = true;
  List<dynamic> _timetable = [];
  String _className = '';
  String _section = 'A';

  @override
  void initState() {
    super.initState();
    _initTimetable();
  }

  Future<void> _initTimetable() async {
    final userData = await _authService.getUserData();
    if (userData != null && userData['student'] != null) {
      _className = userData['student']['className']?.toString() ?? '';
      _section = userData['student']['section']?.toString() ?? 'A';
    }
    await _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    if (_className.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _featuresService.getTimetable(_className, _section);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _timetable = result['data'] ?? [];
          _sortTimetable();
        }
      });
    }
  }

  void _sortTimetable() {
    const dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    _timetable.sort((a, b) {
      final dayA = a['dayOfWeek'] ?? '';
      final dayB = b['dayOfWeek'] ?? '';
      return dayOrder.indexOf(dayA).compareTo(dayOrder.indexOf(dayB));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Timetable${_className.isNotEmpty ? ' - Class $_className-$_section' : ''}',
          style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadTimetable,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _timetable.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _timetable.length,
                  itemBuilder: (context, index) {
                    return _buildDayCard(_timetable[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.table_chart, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Timetable Published',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('There is no timetable published for this class yet.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDayCard(dynamic dayData) {
    final dayName = dayData['dayOfWeek'] ?? 'N/A';
    final periods = dayData['periods'] as List? ?? [];
    
    // Sort periods by period number
    periods.sort((a, b) {
      final pA = int.tryParse(a['periodNumber']?.toString() ?? '0') ?? 0;
      final pB = int.tryParse(b['periodNumber']?.toString() ?? '0') ?? 0;
      return pA.compareTo(pB);
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          dayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
        ),
        subtitle: Text('${periods.length} Periods Scheduled', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        initiallyExpanded: true,
        children: [
          const Divider(height: 1),
          if (periods.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No periods scheduled for this day.', style: TextStyle(color: Colors.grey))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: periods.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = periods[idx];
                final pNo = p['periodNumber']?.toString() ?? '';
                final start = p['startTime'] ?? '';
                final end = p['endTime'] ?? '';
                final subject = p['subject'] ?? '';
                final teacher = p['teacherId']?['name'] ?? 'N/A';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF).withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'P$pNo',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B4EFF), fontSize: 14),
                    ),
                  ),
                  title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Teacher: $teacher', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  trailing: Text(
                    '$start\n-\n$end',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
