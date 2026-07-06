import 'package:flutter/material.dart';
import '../services/parent_features_service.dart';

class ParentNoticeBoardScreen extends StatefulWidget {
  const ParentNoticeBoardScreen({super.key});

  @override
  State<ParentNoticeBoardScreen> createState() => _ParentNoticeBoardScreenState();
}

class _ParentNoticeBoardScreenState extends State<ParentNoticeBoardScreen> {
  final _featuresService = ParentFeaturesService();
  bool _isLoading = true;
  List<dynamic> _notices = [];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    final result = await _featuresService.getNoticeBoard();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _notices = result['data'] ?? [];
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
          'Notice Board',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadNotices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _notices.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notices.length,
                  itemBuilder: (context, index) {
                    return _buildNoticeCard(_notices[index]);
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
            child: const Icon(Icons.campaign, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('There are no active notices or announcements.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(dynamic notice) {
    final title = notice['heading'] ?? 'Announcement';
    final msg = notice['message'] ?? '';
    final to = notice['sendTo'] ?? 'All';
    
    final dateStr = notice['createdAt'] != null
        ? DateTime.parse(notice['createdAt'].toString()).toLocal().toString().split(' ')[0]
        : 'N/A';

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
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'To: $to',
              style: const TextStyle(color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
