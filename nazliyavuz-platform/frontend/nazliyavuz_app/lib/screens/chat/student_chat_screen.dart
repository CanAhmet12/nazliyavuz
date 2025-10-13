import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/real_time_chat_service.dart';
import '../../theme/app_theme.dart';
import '../video_call/video_call_screen.dart';
import '../files/file_sharing_screen.dart';

class StudentChatScreen extends StatefulWidget {
  final User teacher;

  const StudentChatScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
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
    if (widget.teacher.id != 0) {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _isTyping = true;
        _realTimeService.startTypingIndicator(widget.teacher.id);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _isTyping = false;
        _realTimeService.stopTypingIndicator(widget.teacher.id);
      }
    }
  }

  Future<void> _initializeRealTimeService() async {
    await _realTimeService.initialize();
    // Subscribe to real-time updates for this conversation
    if (widget.teacher.id != 0) {
      await _realTimeService.subscribeToConversation(0, widget.teacher.id);
      
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
      _typingSubscription = _realTimeService.getTypingStream(widget.teacher.id).listen((data) {
        if (data['sender_id'] == widget.teacher.id) {
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

      // Validate teacher ID before making API call
      if (widget.teacher.id == 0) {
        throw Exception('Geçersiz eğitimci bilgisi');
      }

      final response = await _apiService.getOrCreateChat(widget.teacher.id);
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
      
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj gönderilirken hata oluştu: $e'),
            backgroundColor: AppTheme.accentRed,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildStudentChatAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _buildStudentMessagesList(),
          ),
          if (_otherUserTyping)
            _buildStudentTypingIndicator(),
          _buildStudentMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildStudentChatAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: widget.teacher.profilePhotoUrl != null
                  ? Image.network(
                      widget.teacher.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultTeacherAvatar();
                      },
                    )
                  : _buildDefaultTeacherAvatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Eğitimci',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () {
            HapticFeedback.mediumImpact();
            _showStudentVideoCallOptions();
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showStudentChatOptions();
          },
        ),
      ],
    );
  }

  Widget _buildDefaultTeacherAvatar() {
    return Container(
      color: AppTheme.accentGreen.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          color: AppTheme.accentGreen,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStudentMessagesList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Mesajlar yükleniyor...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
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
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Mesajlar yüklenirken hata oluştu',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
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
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.teacher.name} ile ilk mesajınızı gönderin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
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
        return _buildStudentMessageBubble(message);
      },
    );
  }

  Widget _buildStudentMessageBubble(Message message) {
    final isFromTeacher = message.senderId == widget.teacher.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromTeacher ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isFromTeacher) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: widget.teacher.profilePhotoUrl != null
                    ? Image.network(
                        widget.teacher.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildSmallTeacherAvatar();
                        },
                      )
                    : _buildSmallTeacherAvatar(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromTeacher 
                    ? Colors.white 
                    : AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isFromTeacher ? 4 : 20),
                  bottomRight: Radius.circular(isFromTeacher ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isFromTeacher 
                          ? AppTheme.grey800 
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isFromTeacher 
                          ? AppTheme.grey500 
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isFromTeacher) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withOpacity(0.1),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppTheme.primaryBlue,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallTeacherAvatar() {
    return Container(
      color: AppTheme.accentGreen.withOpacity(0.1),
      child: Icon(
        Icons.school_rounded,
        color: AppTheme.accentGreen,
        size: 16,
      ),
    );
  }

  Widget _buildStudentMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Eğitimcinize mesaj yazın...',
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
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentVideoCallOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Video Görüşme',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: AppTheme.accentGreen,
                ),
              ),
              title: const Text('Video Görüşme Başlat'),
              subtitle: Text('${widget.teacher.name} ile video görüşme yapın'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    otherUser: widget.teacher,
                    callType: 'video',
                  ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showStudentChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Chat Seçenekleri',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.file_present_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text('Dosya Paylaş'),
              subtitle: const Text('Eğitimcinizle dosya paylaşın'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileSharingScreen(
                      otherUser: widget.teacher,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: AppTheme.accentOrange,
                ),
              ),
              title: const Text('Eğitimciyi Engelle'),
              subtitle: const Text('Bu eğitimciyle iletişimi kesin'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eğitimciyi Engelle'),
        content: Text('${widget.teacher.name} eğitimcisini engellemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Block teacher logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.teacher.name} engellendi'),
                  backgroundColor: AppTheme.accentRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: widget.teacher.profilePhotoUrl != null
                  ? Image.network(
                      widget.teacher.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildSmallTeacherAvatar();
                      },
                    )
                  : _buildSmallTeacherAvatar(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.teacher.name} yazıyor',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
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
