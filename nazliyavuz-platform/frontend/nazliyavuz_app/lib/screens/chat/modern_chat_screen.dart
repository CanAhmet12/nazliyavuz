import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:location/location.dart';
// import 'package:record/record.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/real_time_chat_service.dart';
import '../../widgets/modern_message_bubble.dart';
import '../../widgets/modern_chat_input.dart';
import '../../widgets/message_actions_widget.dart';
import '../video_call/video_call_screen.dart';
import '../files/file_sharing_screen.dart';

class ModernChatScreen extends StatefulWidget {
  final User teacher;

  const ModernChatScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<ModernChatScreen> createState() => _ModernChatScreenState();
}

class _ModernChatScreenState extends State<ModernChatScreen>
    with TickerProviderStateMixin {
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
  
  // Animation controllers
  late AnimationController _typingAnimationController;
  late AnimationController _messageAnimationController;
  late Animation<double> _typingAnimation;
  late Animation<double> _messageAnimation;
  
  // UI State

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRealTimeService();
    _loadChat();
    _messageController.addListener(_onTextChanged);
  }

  void _initializeAnimations() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
    _messageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _messageAnimationController, curve: Curves.easeOut),
    );
  }

  void _onTextChanged() {
    if (widget.teacher.id != 0) {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _isTyping = true;
        _realTimeService.startTypingIndicator(widget.teacher.id);
        _typingAnimationController.repeat(reverse: true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _isTyping = false;
        _realTimeService.stopTypingIndicator(widget.teacher.id);
        _typingAnimationController.stop();
      }
    }
  }

  Future<void> _initializeRealTimeService() async {
    await _realTimeService.initialize();
    if (widget.teacher.id != 0) {
      await _realTimeService.subscribeToConversation(0, widget.teacher.id);
      
      _newMessageSubscription = _realTimeService.getNewMessageStream().listen((data) {
        if (data['message'] != null) {
          final message = Message.fromJson(data['message']);
          if (message.senderId != 0) {
            setState(() {
              _messages.add(message);
            });
            _scrollToBottom();
            _messageAnimationController.forward();
          }
        }
      });
      
      _typingSubscription = _realTimeService.getTypingStream(widget.teacher.id).listen((data) {
        if (data['sender_id'] == widget.teacher.id) {
          setState(() {
            _otherUserTyping = data['is_typing'] ?? false;
          });
        }
      });
      
      // Listen for message read status updates
      // TODO: Implement message read status updates when RealTimeChatService supports it
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _newMessageSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    try {
      setState(() => _isLoading = true);
      
      // Get or create chat
      final response = await _apiService.getOrCreateChat(widget.teacher.id);
      final chatData = response['chat'];
      
      setState(() {
        _chatId = chatData['id'];
        _messages = (chatData['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        _isLoading = false;
      });
      
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    
    final content = _messageController.text.trim();
    _messageController.clear();
    
    setState(() => _isSending = true);
    
    try {
      final message = await _apiService.sendMessage(
        _chatId!,
        content,
      );
      
      setState(() {
        _messages.add(message);
        _isSending = false;
      });
      
      _scrollToBottom();
      _messageAnimationController.forward();
      
      // Update message status to delivered after successful send
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            // Find the message and update its status
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i].id == message.id) {
                _messages[i] = Message(
                  id: _messages[i].id,
                  chatId: _messages[i].chatId,
                  senderId: _messages[i].senderId,
                  receiverId: _messages[i].receiverId,
                  content: _messages[i].content,
                  messageType: _messages[i].messageType,
                  fileUrl: _messages[i].fileUrl,
                  fileName: _messages[i].fileName,
                  fileSize: _messages[i].fileSize,
                  fileType: _messages[i].fileType,
                  isRead: _messages[i].isRead,
                  readAt: _messages[i].readAt,
                  isDeleted: _messages[i].isDeleted,
                  deletedAt: _messages[i].deletedAt,
                  voiceDuration: _messages[i].voiceDuration,
                  reactions: _messages[i].reactions,
                  parentMessageId: _messages[i].parentMessageId,
                  threadId: _messages[i].threadId,
                  mentions: _messages[i].mentions,
                  replyToMessageId: _messages[i].replyToMessageId,
                  forwardedFromMessageId: _messages[i].forwardedFromMessageId,
                  forwardedFromUserId: _messages[i].forwardedFromUserId,
                  forwardedAt: _messages[i].forwardedAt,
                  isPinned: _messages[i].isPinned,
                  pinnedAt: _messages[i].pinnedAt,
                  pinnedBy: _messages[i].pinnedBy,
                  originalContent: _messages[i].originalContent,
                  editedAt: _messages[i].editedAt,
                  editCount: _messages[i].editCount,
                  translations: _messages[i].translations,
                  originalLanguage: _messages[i].originalLanguage,
                  isEncrypted: _messages[i].isEncrypted,
                  encryptionKeyId: _messages[i].encryptionKeyId,
                  messageStatus: 'delivered',
                  deliveredAt: DateTime.now(),
                  metadata: _messages[i].metadata,
                  parentMessage: _messages[i].parentMessage,
                  repliedMessage: _messages[i].repliedMessage,
                  forwardedFromMessage: _messages[i].forwardedFromMessage,
                  forwardedFromUser: _messages[i].forwardedFromUser,
                  pinnedByUser: _messages[i].pinnedByUser,
                  messageMentions: _messages[i].messageMentions,
                  thread: _messages[i].thread,
                  createdAt: _messages[i].createdAt,
                );
                break;
              }
            }
          });
        }
      });
    } catch (e) {
      setState(() => _isSending = false);
      _messageController.text = content; // Restore message
      _showErrorSnackBar('Mesaj gönderilemedi: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  PreferredSizeWidget _buildMinimalAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: widget.teacher.profilePhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      widget.teacher.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    color: Colors.grey[400],
                    size: 20,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Çevrimiçi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _startVideoCall(),
          icon: const Icon(
            Icons.videocam_rounded,
            color: Colors.black54,
            size: 24,
          ),
        ),
        IconButton(
          onPressed: () => _openFileSharing(),
          icon: const Icon(
            Icons.attach_file_rounded,
            color: Colors.black54,
            size: 24,
          ),
        ),
      ],
    );
  }

  void _showMessageActions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageActionsWidget(
        message: message,
        onReply: (msg) => _replyToMessage(msg),
        onForward: (msg) => _forwardMessage(msg),
        onPin: (msg) => _pinMessage(msg),
        onUnpin: (msg) => _unpinMessage(msg),
        onEdit: (msg) => _editMessage(msg),
        onDelete: (msg) => _deleteMessage(msg),
        onTranslate: (msg) => _translateMessage(msg),
        onCreateThread: (msg) => _createThread(msg),
      ),
    );
  }

  void _replyToMessage(Message message) {
    Navigator.pop(context);
    _messageController.text = '@${message.senderId} ';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _forwardMessage(Message message) {
    Navigator.pop(context);
    // TODO: Implement message forwarding
    _showErrorSnackBar('Mesaj iletme özelliği yakında eklenecek');
  }

  void _pinMessage(Message message) async {
    Navigator.pop(context);
    try {
      await _apiService.pinMessage(message.id);
      _showSuccessSnackBar('Mesaj sabitlendi');
    } catch (e) {
      _showErrorSnackBar('Mesaj sabitlenemedi');
    }
  }

  void _unpinMessage(Message message) async {
    Navigator.pop(context);
    try {
      await _apiService.unpinMessage(message.id);
      _showSuccessSnackBar('Sabitleme kaldırıldı');
    } catch (e) {
      _showErrorSnackBar('Sabitleme kaldırılamadı');
    }
  }

  void _editMessage(Message message) {
    Navigator.pop(context);
    // TODO: Implement message editing
    _showErrorSnackBar('Mesaj düzenleme özelliği yakında eklenecek');
  }

  void _deleteMessage(Message message) async {
    Navigator.pop(context);
    try {
      await _apiService.deleteMessage(message.id);
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
      _showSuccessSnackBar('Mesaj silindi');
    } catch (e) {
      _showErrorSnackBar('Mesaj silinemedi');
    }
  }

  void _translateMessage(Message message) {
    Navigator.pop(context);
    // TODO: Implement message translation
    _showErrorSnackBar('Mesaj çeviri özelliği yakında eklenecek');
  }

  void _createThread(Message message) async {
    Navigator.pop(context);
    try {
      await _apiService.createThread(message.id);
      _showSuccessSnackBar('Konu oluşturuldu');
    } catch (e) {
      _showErrorSnackBar('Konu oluşturulamadı');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
      appBar: _buildMinimalAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: _buildMessagesList(),
            ),
            
            // Typing Indicator
            if (_otherUserTyping) _buildTypingIndicator(),
            
            // Chat Input
            ModernChatInput(
              controller: _messageController,
              onSend: _sendMessage,
              isSending: _isSending,
              onAttachment: _showAttachmentOptions,
              onVoiceRecord: _startVoiceRecording,
            ),
          ],
        ),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Mesajlar yüklenemedi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
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
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk mesajınızı gönderin',
              style: TextStyle(color: Colors.grey[600]),
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
        final isMe = message.senderId == 0; // Assuming 0 is current user
        final showAvatar = index == 0 || 
            _messages[index - 1].senderId != message.senderId;
        
        return AnimatedBuilder(
          animation: _messageAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _messageAnimation.value,
              child: ModernMessageBubble(
                message: message,
                isMe: isMe,
                showAvatar: showAvatar,
                onTap: () => _showMessageActions(message),
                onLongPress: () => _showMessageActions(message),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: widget.teacher.profilePhotoUrl != null
                ? NetworkImage(widget.teacher.profilePhotoUrl!)
                : null,
            child: widget.teacher.profilePhotoUrl == null
                ? Text(widget.teacher.name.substring(0, 1).toUpperCase())
                : null,
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _typingAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _typingAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.teacher.name} yazıyor',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
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
              );
            },
          ),
        ],
      ),
    );
  }

  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          otherUser: widget.teacher,
          callType: 'video',
        ),
      ),
    );
  }

  void _openFileSharing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileSharingScreen(
          otherUser: widget.teacher,
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo,
                    label: 'Fotoğraf',
                    color: Colors.green,
                    onTap: () => _selectImage(),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.purple,
                    onTap: () => _selectVideo(),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.attach_file,
                    label: 'Dosya',
                    color: Colors.blue,
                    onTap: () => _selectFile(),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.location_on,
                    label: 'Konum',
                    color: Colors.red,
                    onTap: () => _shareLocation(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _selectImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final message = await _apiService.uploadMessageFile(
          _chatId!,
          image,
          'image',
        );
        
        setState(() {
          _messages.add(message);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      _showErrorSnackBar('Resim yüklenemedi: ${e.toString()}');
    }
  }

  void _selectVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        final message = await _apiService.uploadMessageFile(
          _chatId!,
          video,
          'video',
        );
        
        setState(() {
          _messages.add(message);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      _showErrorSnackBar('Video yüklenemedi: ${e.toString()}');
    }
  }

  void _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final XFile xFile = XFile(file.path!);
        
        final message = await _apiService.uploadMessageFile(
          _chatId!,
          xFile,
          'file',
        );
        
        setState(() {
          _messages.add(message);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      _showErrorSnackBar('Dosya yüklenemedi: ${e.toString()}');
    }
  }

  void _shareLocation() async {
    try {
      // TODO: Implement location sharing when location package is available
      _showErrorSnackBar('Konum paylaşımı henüz desteklenmiyor');
    } catch (e) {
      _showErrorSnackBar('Konum paylaşılamadı: ${e.toString()}');
    }
  }

  void _startVoiceRecording() async {
    try {
      // Show voice recording dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sesli Mesaj'),
          content: const Text('Sesli mesaj özelliği yakında eklenecek.\nŞu anda sadece metin mesajları desteklenmektedir.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Ses kaydı başlatılamadı: ${e.toString()}');
    }
  }
}
