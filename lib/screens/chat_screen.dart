import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String targetId; // studentId for teacher, teacherId for parent
  final String recipientName;
  final String userType; // 'teacher' or 'parent'

  const ChatScreen({
    super.key,
    required this.targetId,
    required this.recipientName,
    required this.userType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  
  bool _isLoading = true;
  List<dynamic> _messages = [];
  Timer? _pollTimer;
  bool _isSending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadMessages();
    
    // Poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadCurrentUserId() async {
    final uid = await _authService.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = uid;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && _messages.isEmpty) {
      setState(() => _isLoading = true);
    }

    final result = await _chatService.getUniversalMessages(widget.targetId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          final oldLen = _messages.length;
          _messages = result['data'] ?? [];
          
          // Scroll to bottom if new messages arrive
          if (_messages.length > oldLen) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final result = await _chatService.sendUniversalMessage(
      receiverId: widget.targetId,
      message: text,
      messageType: 'text',
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (result['success']) {
        _messages.add(result['data']);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to send message'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      final file = File(image.path);
      final sizeInMB = await file.length() / (1024 * 1024);
      if (sizeInMB > 2) {
        _showErrorToast('Images must be less than 2 MB.');
        return;
      }

      _showInfoToast('Processing image...');
      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      _uploadAttachment(base64Image, 'image');
    } catch (e) {
      _showErrorToast('Failed to select image: $e');
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final sizeInMB = await file.length() / (1024 * 1024);
      if (sizeInMB > 3) {
        _showErrorToast('Documents must be less than 3 MB.');
        return;
      }

      _showInfoToast('Processing document...');
      final bytes = await file.readAsBytes();
      final ext = result.files.single.extension ?? 'pdf';
      final base64File = 'data:application/$ext;base64,${base64Encode(bytes)}';

      _uploadAttachment(base64File, 'file');
    } catch (e) {
      _showErrorToast('Failed to select document: $e');
    }
  }

  Future<void> _uploadAttachment(String base64Data, String messageType) async {
    setState(() => _isSending = true);

    final result = await _chatService.sendUniversalMessage(
      receiverId: widget.targetId,
      message: base64Data,
      messageType: messageType,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (result['success']) {
        _messages.add(result['data']);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        _showSuccessToast('Attachment sent successfully!');
      } else {
        _showErrorToast(result['message'] ?? 'Failed to send attachment');
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send Attachment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.image,
                      label: 'Image',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendImage();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.description,
                      label: 'Document',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendDocument();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _openBase64File(String base64Data, String fallbackExtension) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening file...'), duration: Duration(milliseconds: 700)),
      );

      String base64String = base64Data;
      String extension = fallbackExtension;

      if (base64Data.startsWith('data:')) {
        final parts = base64Data.split(';base64,');
        if (parts.length == 2) {
          final mime = parts[0].replaceAll('data:', '');
          final mimeParts = mime.split('/');
          if (mimeParts.length == 2) {
            extension = mimeParts[1];
          }
          base64String = parts[1];
        }
      }

      final bytes = base64Decode(base64String);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_file_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await file.writeAsBytes(bytes);

      await OpenFilex.open(file.path);
    } catch (e) {
      _showErrorToast('Error opening file: $e');
    }
  }

  void _showFullscreenImage(String base64Data) {
    String base64String = base64Data;
    if (base64Data.startsWith('data:')) {
      final parts = base64Data.split(';base64,');
      if (parts.length == 2) {
        base64String = parts[1];
      }
    }
    final bytes = base64Decode(base64String);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfoToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF6B4EFF)),
    );
  }

  void _showSuccessToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.recipientName,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Messages Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
                : _messages.isEmpty
                    ? Center(child: Text('Start a conversation with ${widget.recipientName}'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFF6B4EFF)),
                  onPressed: _showAttachmentMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B4EFF),
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg) {
    final isMe = (msg['senderId'] != null && _currentUserId != null)
        ? msg['senderId'].toString() == _currentUserId
        : msg['senderType'] == widget.userType;
    final timeStr = msg['createdAt'] != null
        ? DateTime.parse(msg['createdAt'].toString()).toLocal().toString().split(' ')[1].substring(0, 5)
        : '';

    Widget content;
    final msgType = msg['messageType'] ?? 'text';
    final msgContent = msg['message'] ?? '';

    if (msgType == 'image') {
      String base64String = msgContent;
      if (msgContent.startsWith('data:')) {
        final parts = msgContent.split(';base64,');
        if (parts.length == 2) {
          base64String = parts[1];
        }
      }
      try {
        final bytes = base64Decode(base64String);
        content = GestureDetector(
          onTap: () => _showFullscreenImage(msgContent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 180,
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50),
            ),
          ),
        );
      } catch (e) {
        content = const Icon(Icons.broken_image, size: 50);
      }
    } else if (msgType == 'file') {
      String extension = 'file';
      if (msgContent.startsWith('data:')) {
        final parts = msgContent.split(';base64,');
        if (parts.length == 2) {
          final mime = parts[0].replaceAll('data:', '');
          final mimeParts = mime.split('/');
          if (mimeParts.length == 2) {
            extension = mimeParts[1];
          }
        }
      }
      content = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white24 : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : const Color(0xFF6B4EFF)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shared Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Format: ${extension.toUpperCase()}', style: const TextStyle(fontSize: 10)),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.download, color: isMe ? Colors.white : const Color(0xFF6B4EFF), size: 20),
              onPressed: () => _openBase64File(msgContent, extension),
            ),
          ],
        ),
      );
    } else {
      content = Text(
        msgContent,
        style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1A1A1A), fontSize: 14),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6B4EFF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(3),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[500], fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
