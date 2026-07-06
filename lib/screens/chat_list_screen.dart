import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  bool _isLoading = true;
  String _userType = '';
  List<dynamic> _conversations = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initChatList();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initChatList() async {
    final userType = await _authService.getUserType();
    setState(() {
      _userType = userType ?? '';
    });
    await _loadConversations();
    
    // Poll for new messages/conversations every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadConversations(silent: true);
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    Map<String, dynamic> result;
    if (_userType == 'teacher') {
      result = await _chatService.getTeacherConversations();
    } else {
      result = await _chatService.getParentConversations();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _conversations = result['data'] ?? [];
        }
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
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
          'Messages',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: () => _loadConversations(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: const Color(0xFF6B4EFF),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildConversationCard(_conversations[index]);
                    },
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
            child: const Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Messages Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          const Text('Your conversation history will appear here', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildConversationCard(dynamic conv) {
    final isTeacherRole = _userType == 'teacher';
    
    // Recipient Details
    final String name = isTeacherRole 
        ? (conv['student']?['name'] ?? 'Student')
        : (conv['teacher']?['name'] ?? 'Teacher');
        
    final String subtitleLabel = isTeacherRole
        ? 'Parent: ${conv['student']?['parentName'] ?? 'N/A'} • Class ${conv['student']?['className'] ?? ''}'
        : (conv['teacher']?['subject'] != null 
            ? '${conv['teacher']?['subject']} Teacher' 
            : 'Class Teacher');

    // Last Message Preview
    final lastMsg = conv['lastMessage'];
    String lastMsgText = 'No messages yet';
    if (lastMsg != null) {
      final prefix = lastMsg['senderType'] == _userType ? 'You: ' : '';
      if (lastMsg['messageType'] == 'image') {
        lastMsgText = '$prefix📷 Sent an image';
      } else if (lastMsg['messageType'] == 'file') {
        lastMsgText = '$prefix📄 Sent a document';
      } else {
        final rawMsg = lastMsg['message'] ?? '';
        lastMsgText = prefix + (rawMsg.length > 35 ? '${rawMsg.substring(0, 35)}...' : rawMsg);
      }
    }

    final unreadCount = conv['unreadCount'] ?? 0;

    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF6B4EFF),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              _getInitials(name),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lastMsgText,
              style: TextStyle(
                color: unreadCount > 0 ? const Color(0xFF1A1A1A) : Colors.grey[600],
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(subtitleLabel, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
        trailing: unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          final String targetId = isTeacherRole 
              ? (conv['student']?['_id'] ?? '')
              : (conv['teacher']?['_id'] ?? '');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                targetId: targetId,
                recipientName: name,
                userType: _userType,
              ),
            ),
          ).then((_) => _loadConversations());
        },
      ),
    );
  }
}
