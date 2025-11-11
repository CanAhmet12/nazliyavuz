import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/real_time_chat_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_system.dart';
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

class _StudentChatScreenState extends State<StudentChatScreen> with RouteAware {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();
  final _realTimeService = RealTimeChatService();
  
  // Global image cache to persist images across page refreshes
  static final Map<String, ImageProvider> _imageCache = {};
  
  List<Message> _messages = [];
  int? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _typingSubscription;
  
  // Voice recording variables
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  // Audio player variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeRealTimeService();
    _loadChat();
    
    // Add listener for typing indicator
    _messageController.addListener(_onTextChanged);
    _initializeRecorder();
    
    // Record activity when chat screen is opened
    _apiService.recordActivity();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // This helps detect when we return from another screen
    }
  }
  
  @override
  void didPopNext() {
    // Called when returning from another route (like video call)
    // Reload messages to show latest data
    if (mounted) {
      _loadChat();
    }
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
    _recorder?.closeRecorder();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Initialize voice recorder
  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  // Select and send image
  Future<void> _selectImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && _chatId != null) {
        setState(() {
          _isSending = true;
        });
        
        final message = await _apiService.uploadMessageFile(
          _chatId!,
          image,
          'image',
        );
        
        setState(() {
          _messages.add(message);
          _isSending = false;
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      _showErrorSnackBar('Fotoğraf yüklenemedi: ${e.toString()}');
    }
  }

  // Select and send video
  Future<void> _selectVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null && _chatId != null) {
        setState(() {
          _isSending = true;
        });
        
        final message = await _apiService.uploadMessageFile(
          _chatId!,
          video,
          'video',
        );
        
        setState(() {
          _messages.add(message);
          _isSending = false;
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      _showErrorSnackBar('Video yüklenemedi: ${e.toString()}');
    }
  }

  // Start voice recording
  Future<void> _startVoiceRecording() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showErrorSnackBar('Mikrofon izni gerekli');
        return;
      }

      // Get directory for recording
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      
      // Start timer for recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
      
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showErrorSnackBar('Ses kaydı başlatılamadı: ${e.toString()}');
    }
  }

  // Stop voice recording and send
  Future<void> _stopVoiceRecording() async {
    try {
      await _recorder!.stopRecorder();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
      });
      
      if (_recordingPath != null && _chatId != null && _recordingDuration > 0) {
        setState(() {
          _isSending = true;
        });
        
        final audioFile = XFile(_recordingPath!);
        final message = await _apiService.sendVoiceMessage(
          _chatId!,
          audioFile,
          _recordingDuration,
        );
        
        setState(() {
          _messages.add(message);
          _isSending = false;
        });
        
        _scrollToBottom();
      }
      
      _recordingPath = null;
      _recordingDuration = 0;
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isSending = false;
      });
      _showErrorSnackBar('Ses kaydı gönderilemedi: ${e.toString()}');
    }
  }

  // Cancel voice recording
  void _cancelVoiceRecording() {
    _recorder?.stopRecorder();
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
    _recordingPath = null;
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

      // Preload images for better performance
      _preloadImages();

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

  Widget _buildCachedImage(String imageUrl) {
    // Check if image is already cached
    if (_imageCache.containsKey(imageUrl)) {
      return Image(
        image: _imageCache[imageUrl]!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );
    }
    
    // If not cached, load and cache it
    final imageProvider = NetworkImage(imageUrl);
    _imageCache[imageUrl] = imageProvider;
    
    return Image(
      image: imageProvider,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 200,
          height: 200,
          color: Colors.white.withOpacity(0.1),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Image load error: $error');
        print('Image URL: $imageUrl');
        // Remove from cache if failed
        _imageCache.remove(imageUrl);
        return Container(
          width: 200,
          height: 200,
          color: Colors.white.withOpacity(0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.white,
                size: 50,
              ),
              const SizedBox(height: 8),
              const Text(
                'Resim yüklenemedi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _chatId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final message = await _apiService.sendMessage(_chatId!, content);
      
      // Record activity when message is sent
      _apiService.recordActivity();
      
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

  void _preloadImages() {
    for (final message in _messages) {
      if (message.messageType == 'image' && message.fileUrl != null) {
        // Preload image into cache
        if (!_imageCache.containsKey(message.fileUrl!)) {
          _imageCache[message.fileUrl!] = NetworkImage(message.fileUrl!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
      appBar: _buildModernStudentChatAppBar(),
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

  PreferredSizeWidget _buildModernStudentChatAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
      foregroundColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), // Anasayfa ile uyumlu icon boyutu
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
                     ClipOval(
             child: Container(
              width: 40,
              height: 40,
              color: Colors.grey[200],
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
                    fontSize: 16, // Anasayfa ile uyumlu font boyutu
                    fontWeight: FontWeight.w700, // Anasayfa ile uyumlu font weight
                     color: Colors.black87,
                   ),
                 ),
                 const Text(
                  'Online',
                   style: TextStyle(
                    fontSize: 11, // Anasayfa ile uyumlu font boyutu
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
             actions: [
         IconButton(
          icon: const Icon(Icons.videocam_rounded, color: Colors.black87, size: 20), // Anasayfa ile uyumlu icon boyutu
           onPressed: () {
             HapticFeedback.mediumImpact();
             _showStudentVideoCallOptions();
           },
         ),
         IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.black87, size: 20), // Anasayfa ile uyumlu icon boyutu
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
      color: const Color(0xFFE8E0D5),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          color: Colors.grey[700],
          size: DesignSystem.iconLarge,
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isFromTeacher ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Show video outside the bubble if it's a video message
          if (message.messageType == 'video' && message.fileUrl != null) ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildVideoPlayer(message.fileUrl!),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Show image outside the bubble if it's an image message
          if (message.messageType == 'image' && message.fileUrl != null) ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildCachedImage(message.fileUrl!),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Show voice message OUTSIDE bubble (no background color)
          if ((message.messageType == 'voice' || message.messageType == 'audio') && message.fileUrl != null) ...[
            Row(
              mainAxisAlignment: isFromTeacher ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        print('🎵 Voice message tapped: ${message.fileUrl}');
                        print('🎵 Message ID: ${message.id}');
                        print('🎵 Message Type: ${message.messageType}');
                        print('🎵 File Name: ${message.fileName}');
                        print('🎵 File URL: ${message.fileUrl}');
                        if (message.fileUrl != null && message.fileUrl!.isNotEmpty) {
                          _playVoiceMessage(message.fileUrl!);
                        } else {
                          print('❌ File URL is null or empty!');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            Icon(
                              _isPlaying && _currentlyPlayingUrl == message.fileUrl
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: const Color(0xFF6B46C1),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              message.voiceDuration != null 
                                  ? 'Sesli mesaj (${message.voiceDuration}s)'
                                  : 'Sesli mesaj',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Message bubble for text content (only for non-voice messages)
          if (message.content.isNotEmpty && !((message.messageType == 'voice' || message.messageType == 'audio') && message.fileUrl != null)) ...[
            Row(
              mainAxisAlignment: isFromTeacher ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFromTeacher 
                          ? Colors.grey[300] // Gri renk öğretmen mesajları için
                          : const Color(0xFF8B5CF6), // Mor renk öğrenci mesajları için
                      borderRadius: BorderRadius.circular(8), // Daha az yuvarlak
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show file if message type is file
                        if (message.messageType == 'file' && message.fileUrl != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isFromTeacher ? Colors.grey[400] : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file,
                                  color: isFromTeacher ? Colors.black87 : Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  message.fileName ?? 'Dosya',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isFromTeacher ? Colors.black87 : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Show text content (but not for media messages)
                        if (message.content.isNotEmpty && 
                            message.messageType != 'video' && 
                            message.messageType != 'image' && 
                            message.messageType != 'voice' && 
                            message.messageType != 'audio')
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 14, // Anasayfa ile uyumlu font boyutu
                              color: isFromTeacher ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 11, // Anasayfa ile uyumlu font boyutu
                            color: isFromTeacher ? Colors.grey[600] : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
        border: Border(
          top: BorderSide(
            color: Colors.grey,
            width: 0.5,
          ),
        ),
      ),
              child: SafeArea(
        child: _isRecording ? _buildVoiceRecordingUI() : _buildNormalMessageInput(),
      ),
    );
  }

  Widget _buildVoiceRecordingUI() {
    return Row(
      children: [
        // Cancel button
        IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.red,
            size: 20,
          ),
          onPressed: _cancelVoiceRecording,
        ),
        
        // Recording indicator and duration
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
        child: Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kayıt yapılıyor... ${_formatDuration(_recordingDuration)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Send button
        IconButton(
          icon: const Icon(
            Icons.send,
            color: Colors.green,
            size: 20,
          ),
          onPressed: _stopVoiceRecording,
        ),
      ],
    );
  }

  Widget _buildNormalMessageInput() {
    return Row(
          children: [
            // Attachment button with menu
            IconButton(
              icon: const Icon(
                Icons.attach_file_rounded,
                color: Colors.black87,
            size: 20, // Anasayfa ile uyumlu icon boyutu
              ),
              onPressed: () {
                _showAttachmentOptions();
              },
            ),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                fontSize: 14, // Anasayfa ile uyumlu font boyutu
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                hintText: 'Mesajını yaz',
                    hintStyle: TextStyle(
                  fontSize: 14, // Anasayfa ile uyumlu font boyutu
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                prefixIcon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.grey[500],
                  size: 20, // Anasayfa ile uyumlu icon boyutu
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Send button
            Container(
          width: 50,
          height: 50,
              decoration: BoxDecoration(
                color: _messageController.text.isNotEmpty 
                ? const Color(0xFF8B5CF6) // Mor renk
                    : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
              size: 20, // Anasayfa ile uyumlu icon boyutu
                ),
                onPressed: _isSending || _messageController.text.isEmpty 
                    ? null 
                    : _sendMessage,
              ),
            ),
          ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Play voice message
  Future<void> _playVoiceMessage(String audioUrl) async {
    try {
      if (kDebugMode) {
        print('🎵 [AUDIO_PLAYER] Attempting to play audio: $audioUrl');
        print('🎵 [AUDIO_PLAYER] Current playing state: $_isPlaying');
        print('🎵 [AUDIO_PLAYER] Current playing URL: $_currentlyPlayingUrl');
      }
      
      if (_isPlaying && _currentlyPlayingUrl == audioUrl) {
        // If same audio is playing, pause it
        if (kDebugMode) {
          print('⏸️ [AUDIO_PLAYER] Pausing current audio');
        }
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      } else {
        // Stop current audio if playing
        if (_isPlaying) {
          if (kDebugMode) {
            print('⏹️ [AUDIO_PLAYER] Stopping current audio');
          }
          await _audioPlayer.stop();
        }
        
        // Play new audio
        if (kDebugMode) {
          print('▶️ [AUDIO_PLAYER] Starting new audio playback');
        }
        
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _isPlaying = true;
          _currentlyPlayingUrl = audioUrl;
        });
        
        if (kDebugMode) {
          print('✅ [AUDIO_PLAYER] Audio playback started successfully');
        }
        
        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (kDebugMode) {
            print('🏁 [AUDIO_PLAYER] Audio playback completed');
          }
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingUrl = null;
            });
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AUDIO_PLAYER] Error playing audio: $e');
        print('❌ [AUDIO_PLAYER] Audio URL: $audioUrl');
      }
      _showErrorSnackBar('Ses oynatılamadı: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
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
                'Eklenti Seç',
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
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text('Fotoğraf'),
              onTap: () {
                Navigator.pop(context);
                _selectImage();
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
                  Icons.video_library_rounded,
                  color: AppTheme.accentOrange,
                ),
              ),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _selectVideo();
              },
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
                  Icons.mic_rounded,
                  color: AppTheme.accentGreen,
                ),
              ),
              title: const Text('Ses Kaydı'),
              onTap: () {
                Navigator.pop(context);
                _startVoiceRecording();
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
          color: Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
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

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: VideoPlayerWidget(videoUrl: videoUrl),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (kDebugMode) {
        print('🎥 [VIDEO_PLAYER] Initializing video: ${widget.videoUrl}');
      }
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      // Add listener for initialization
      _controller!.addListener(_videoListener);
      
      // Set timeout for initialization
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video yükleme zaman aşımına uğradı');
        },
      );
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        if (kDebugMode) {
          print('✅ [VIDEO_PLAYER] Video initialized successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [VIDEO_PLAYER] Video initialization error: $e');
      }
      
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller != null && mounted) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error state
    if (_hasError) {
      return Container(
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 8),
            const Text(
              'Video yüklenemedi',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekrar deneyin',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializeVideo();
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    
    // Show loading state
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Video yükleniyor...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (!_isPlaying)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

