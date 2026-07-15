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

    final result = await _chatService.getUniversalConversations();

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

  void _showContactsSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactsSearchBottomSheet(),
    ).then((_) => _loadConversations());
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showContactsSearch,
        backgroundColor: const Color(0xFF6B4EFF),
        child: const Icon(Icons.message, color: Colors.white),
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showContactsSearch,
            icon: const Icon(Icons.search, color: Colors.white),
            label: const Text('SEARCH CONTACTS', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(dynamic conv) {
    final partner = conv['partner'];
    final String name = partner?['name'] ?? 'User';
    final String subtitleLabel = partner?['details'] ?? '';
        
    // Last Message Preview
    final lastMsg = conv['lastMessage'];
    String lastMsgText = 'No messages yet';
    if (lastMsg != null) {
      if (lastMsg['messageType'] == 'image') {
        lastMsgText = '📷 Sent an image';
      } else if (lastMsg['messageType'] == 'file') {
        lastMsgText = '📄 Sent a document';
      } else {
        final rawMsg = lastMsg['message'] ?? '';
        lastMsgText = rawMsg.length > 35 ? '${rawMsg.substring(0, 35)}...' : rawMsg;
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
          final String targetId = partner?['id'] ?? '';

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

// Contacts Search Bottom Sheet
class ContactsSearchBottomSheet extends StatefulWidget {
  const ContactsSearchBottomSheet({super.key});

  @override
  State<ContactsSearchBottomSheet> createState() => _ContactsSearchBottomSheetState();
}

class _ContactsSearchBottomSheetState extends State<ContactsSearchBottomSheet> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  List<dynamic> _contacts = [];
  List<dynamic> _filteredContacts = [];
  String _userType = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final type = await _authService.getUserType();
    final result = await _chatService.getUniversalContacts();
    setState(() {
      _userType = type ?? '';
      _isLoading = false;
      if (result['success']) {
        _contacts = result['data'] ?? [];
        _filteredContacts = _contacts;
      }
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          final details = (c['details'] ?? '').toString().toLowerCase();
          final type = (c['type'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || details.contains(q) || type.contains(q);
        }).toList();
      }
    });
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              style: const TextStyle(color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
                : _filteredContacts.isEmpty
                    ? const Center(child: Text('No contacts found'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredContacts.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final c = _filteredContacts[index];
                          final name = c['name'] ?? '';
                          final details = c['details'] ?? '';
                          final type = c['type'] ?? 'student';
                          
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: type == 'teacher'
                                    ? const Color(0xFF6B4EFF).withAlpha(30)
                                    : const Color(0xFF28A745).withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(name),
                                  style: TextStyle(
                                    color: type == 'teacher'
                                        ? const Color(0xFF6B4EFF)
                                        : const Color(0xFF28A745),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            subtitle: Text(details, style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: type == 'teacher'
                                    ? const Color(0xFF6B4EFF).withAlpha(20)
                                    : const Color(0xFF28A745).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: type == 'teacher'
                                      ? const Color(0xFF6B4EFF)
                                      : const Color(0xFF28A745),
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    targetId: c['id'] ?? '',
                                    recipientName: name,
                                    userType: _userType,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
