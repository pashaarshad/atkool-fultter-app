import 'package:flutter/material.dart';
import '../services/parent_features_service.dart';

class ParentReportCardScreen extends StatefulWidget {
  const ParentReportCardScreen({super.key});

  @override
  State<ParentReportCardScreen> createState() => _ParentReportCardScreenState();
}

class _ParentReportCardScreenState extends State<ParentReportCardScreen> {
  final _featuresService = ParentFeaturesService();
  bool _isLoading = true;
  List<dynamic> _results = [];

  // Computed metrics
  int _totalMarks = 0;
  int _obtainedMarks = 0;
  int _overallPercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadReportCard();
  }

  Future<void> _loadReportCard() async {
    setState(() => _isLoading = true);
    final result = await _featuresService.getReportCard();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _results = result['data'] ?? [];
          _calculateMetrics();
        }
      });
    }
  }

  void _calculateMetrics() {
    int total = 0;
    int obtained = 0;

    for (var r in _results) {
      final maxM = int.tryParse(r['maxMarks']?.toString() ?? '0') ?? 0;
      final obtM = int.tryParse(r['marksObtained']?.toString() ?? '0') ?? 0;
      total += maxM;
      obtained += obtM;
    }

    _totalMarks = total;
    _obtainedMarks = obtained;
    _overallPercentage = total > 0 ? ((obtained / total) * 100).round() : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF))),
      );
    }

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
          'Report Card',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadReportCard,
          ),
        ],
      ),
      body: _results.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Subjects',
                          '${_results.length}',
                          const Color(0xFF6B4EFF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Marks',
                          '$_obtainedMarks/$_totalMarks',
                          const Color(0xFF28A745),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Overall',
                          '$_overallPercentage%',
                          const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Subject Records',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      return _buildResultCard(_results[index]);
                    },
                  ),
                ],
              ),
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
            child: const Icon(Icons.assessment, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Marks Published',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('No report card details have been published yet.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
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
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(dynamic res) {
    final examName = res['examId']?['name'] ?? 'Exam';
    final subject = res['subject'] ?? 'N/A';
    final marks = '${res['marksObtained'] ?? 0}/${res['maxMarks'] ?? 100}';
    final grade = res['grade'] ?? '-';
    final remarks = res['remarks'] ?? '-';

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
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28A745).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Grade: $grade',
                    style: const TextStyle(color: Color(0xFF28A745), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.assignment_outlined, 'Exam', examName),
            _buildDetailRow(Icons.grade_outlined, 'Marks', marks),
            _buildDetailRow(Icons.feedback_outlined, 'Remarks', remarks),
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
