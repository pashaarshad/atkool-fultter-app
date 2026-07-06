import 'package:flutter/material.dart';
import '../services/parent_features_service.dart';

class ParentDateSheetsScreen extends StatefulWidget {
  const ParentDateSheetsScreen({super.key});

  @override
  State<ParentDateSheetsScreen> createState() => _ParentDateSheetsScreenState();
}

class _ParentDateSheetsScreenState extends State<ParentDateSheetsScreen> {
  final _featuresService = ParentFeaturesService();
  bool _isLoading = true;
  List<dynamic> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadDateSheets();
  }

  Future<void> _loadDateSheets() async {
    setState(() => _isLoading = true);
    final result = await _featuresService.getDateSheets();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _exams = result['data'] ?? [];
        }
      });
    }
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
        title: const Text(
          'DateSheets',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadDateSheets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _exams.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    return _buildExamCard(_exams[index]);
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
            child: const Icon(Icons.calendar_today, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Exams Scheduled',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('There are no upcoming exams listed at this time.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildExamCard(dynamic exam) {
    final dateStr = exam['examDate'] != null
        ? DateTime.parse(exam['examDate'].toString()).toLocal().toString().split(' ')[0]
        : 'N/A';
    final startTime = exam['startTime'] ?? 'N/A';
    final endTime = exam['endTime'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exam['examName'] ?? 'Scheduled Exam',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4EFF).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    exam['status'] ?? 'Scheduled',
                    style: const TextStyle(color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.book_outlined, 'Subject', exam['subject'] ?? 'N/A'),
            _buildDetailRow(Icons.calendar_month_outlined, 'Date', dateStr),
            _buildDetailRow(Icons.access_time_outlined, 'Time', '$startTime - $endTime'),
            _buildDetailRow(Icons.grade_outlined, 'Max Marks', exam['maxMarks']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }
}
