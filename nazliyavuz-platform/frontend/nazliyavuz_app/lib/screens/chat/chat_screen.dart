import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/real_time_chat_service.dart';
import '../../theme/app_theme.dart';
import '../video_call/video_call_screen.dart';
import '../files/file_sharing_screen.dart';

class ChatScreen extends StatefulWidget {
  final User otherUser;

  const ChatScreen({
    super.key,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();
  final _realTimeService = RealTimeChatService();
  
  List<Message> _messages = [];
  int? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRealTimeService();
    _loadChat();
    
    // Add listener for typing indicator
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (widget.otherUser.id != 0) {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _isTyping = true;
        _realTimeService.startTypingIndicator(widget.otherUser.id);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _isTyping = false;
        _realTimeService.stopTypingIndicator(widget.otherUser.id);
      }
    }
  }

  Future<void> _initializeRealTimeService() async {
    await _realTimeService.initialize();
    // Subscribe to real-time updates for this conversation
    if (widget.otherUser.id != 0) {
      await _realTimeService.subscribeToConversation(0, widget.otherUser.id);
      
      // Listen for new messages
      _newMessageSubscription = _realTimeService.getNewMessageStream().listen((data) {
        if (data['message'] != null) {
          final message = Message.fromJson(data['message']);
          if (message.senderId != 0) { // Not from current user
            setState(() {
              _messages.add(message);
            });
            _scrollToBottom();
          }
        }
      });
      
      // Listen for typing indicators
      _typingSubscription = _realTimeService.getTypingStream(widget.otherUser.id).listen((data) {
        if (data['sender_id'] == widget.otherUser.id) {
          setState(() {
            _otherUserTyping = data['is_typing'] ?? false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _newMessageSubscription?.cancel();
    _typingSubscription?.cancel();
    _realTimeService.disconnect();
    super.dispose();
  }

  Future<void> _loadChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Validate other user ID before making API call
      if (widget.otherUser.id == 0) {
        throw Exception('Geçersiz kullanıcı bilgisi');
      }

      final response = await _apiService.getOrCreateChat(widget.otherUser.id);
      final chatData = response['chat'];
      
      setState(() {
        _chatId = chatData['id'];
        _messages = (chatData['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        _isLoading = false;
      });

      // Mark messages as read
      if (_chatId != null) {
        await _apiService.markMessagesAsRead(_chatId!);
      }
      
      // Mark messages as read when chat is loaded
      _markMessagesAsRead();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _chatId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final message = await _apiService.sendMessage(_chatId!, content);
      
      setState(() {
        _messages.add(message);
      });

      _messageController.clear();
      _scrollToBottom();
      
      // Stop typing indicator
      if (widget.otherUser.id != 0) {
        _realTimeService.stopTypingIndicator(widget.otherUser.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj gönderilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
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

  Future<void> _markMessagesAsRead() async {
    if (_chatId != null) {
      try {
        await _apiService.markMessagesAsRead(_chatId!);
      } catch (e) {
        debugPrint('Error marking messages as read: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Profile Photo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                ),
              ),
              child: widget.otherUser.profilePhotoUrl == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        widget.otherUser.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            widget.otherUser.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.otherUser.role == 'teacher' ? 'Öğretmen' : 'Öğrenci',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    otherUser: widget.otherUser,
                    callType: 'video',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FileSharingScreen(
                    otherUser: widget.otherUser,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          if (_otherUserTyping)
            _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chat yüklenirken hata oluştu',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChat,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk mesajı siz gönderin!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentUser = message.senderId != widget.otherUser.id;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildMessageBubble(message, isCurrentUser),
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    return Row(
      mainAxisAlignment: isCurrentUser 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
      children: [
        if (!isCurrentUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Text(
              widget.otherUser.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentUser 
                  ? AppTheme.primaryBlue 
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCurrentUser ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentUser 
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isCurrentUser) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryBlue,
            child: const Text(
              'A',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Kullanıcıyı Engelle'),
            onTap: () {
              Navigator.pop(context);
              _blockUser();
            },
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Şikayet Et'),
            onTap: () {
              Navigator.pop(context);
              _reportUser();
            },
          ),
        ],
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text('${widget.otherUser.name} kullanıcısını engellemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement block user API call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kullanıcı engellendi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Engelle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Şikayet Et'),
        content: const Text('Bu kullanıcıyı şikayet etmek için bir neden seçin:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement report user API call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Şikayet gönderildi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Şikayet Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Text(
              widget.otherUser.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.otherUser.name} yazıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}