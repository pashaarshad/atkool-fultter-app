import 'package:flutter/material.dart';
import '../services/parent_features_service.dart';

class ParentHomeworkScreen extends StatefulWidget {
  const ParentHomeworkScreen({super.key});

  @override
  State<ParentHomeworkScreen> createState() => _ParentHomeworkScreenState();
}

class _ParentHomeworkScreenState extends State<ParentHomeworkScreen> {
  final _featuresService = ParentFeaturesService();
  bool _isLoading = true;
  List<dynamic> _homeworkList = [];

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    final result = await _featuresService.getHomework();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _homeworkList = result['data'] ?? [];
        }
      });
    }
  }

  Future<void> _openSubmitDialog(String homeworkId, String title, String existingContent) async {
    final controller = TextEditingController(text: existingContent);
    final isSubmitted = existingContent.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isSubmitted ? 'Update' : 'Submit'} Homework',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter your answer/content here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final content = controller.text.trim();
                      if (content.isEmpty) return;

                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      
                      final response = await _featuresService.submitHomework(homeworkId, content);
                      if (mounted) {
                        if (response['success']) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Homework submitted successfully!'), backgroundColor: Colors.green),
                          );
                          _loadHomework();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response['message'] ?? 'Submission failed'), backgroundColor: Colors.red),
                          );
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Answer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          'Homework',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadHomework,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _homeworkList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _homeworkList.length,
                  itemBuilder: (context, index) {
                    return _buildHomeworkCard(_homeworkList[index]);
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
            child: const Icon(Icons.menu_book, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Homework Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('No homework has been assigned to your class yet.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(dynamic hw) {
    final hasSubmission = hw['submission'] != null;
    final submission = hw['submission'] ?? {};
    final status = submission['status'] ?? 'Pending';
    final teacherName = hw['teacherId']?['name'] ?? 'Teacher';
    
    final dueDateStr = hw['dueDate'] != null
        ? DateTime.parse(hw['dueDate'].toString()).toLocal().toString().split(' ')[0]
        : 'N/A';

    Color statusColor;
    switch (status) {
      case 'Graded':
        statusColor = const Color(0xFF28A745);
        break;
      case 'Submitted':
        statusColor = const Color(0xFF007BFF);
        break;
      default:
        statusColor = const Color(0xFFFF9800);
    }

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hw['title'] ?? 'Homework Assignment',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hw['subject'] ?? 'N/A'} • $teacherName • Due $dueDateStr',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hw['description'] ?? '',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.4),
            ),
            if (hasSubmission) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SUBMITTED ANSWER', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 6),
                    Text(submission['content'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A))),
                    if (submission['grade'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Grade: ${submission['grade']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28A745), fontSize: 13),
                      ),
                    ],
                    if (submission['feedback'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Feedback: ${submission['feedback']}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () => _openSubmitDialog(
                  hw['_id'],
                  hw['title'] ?? 'Homework',
                  submission['content'] ?? '',
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6B4EFF), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  hasSubmission ? 'Update Submission' : 'Submit Homework',
                  style: const TextStyle(color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
