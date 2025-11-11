import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import 'student_chat_screen.dart';
import 'teacher_chat_screen.dart';
import '../notifications/notification_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _apiService = ApiService();
  List<Chat> _filteredChats = [];
  bool _isLoading = true;
  String? _error;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [CHAT_LIST] Failed to load notification count: $e');
      }
    }
  }

  Future<void> _loadChats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final chats = await _apiService.getChats();
      
      setState(() {
        _filteredChats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      if (kDebugMode) {
        print('❌ [CHAT_LIST] Error loading chats: $e');
      }
    }
  }

  Future<void> _refreshChats() async {
    await _loadChats();
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Mesajların',
        style: TextStyle(
          fontSize: 20, // Anasayfa ile uyumlu font boyutu
          fontWeight: FontWeight.w700, // Anasayfa ile uyumlu font weight
          color: Colors.black87,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                ).then((_) {
                  // Bildirim sayfasından döndükten sonra sayıyı güncelle
                  _loadNotificationCount();
                });
              },
              icon: const Icon(
                Icons.notifications,
                color: Colors.black87,
                size: 20, // Anasayfa ile uyumlu icon boyutu
              ),
            ),
            if (_unreadNotificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11, // Anasayfa ile uyumlu font boyutu
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }




  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
          appBar: _buildModernAppBar(),
          body: Column(
            children: [
              // Arama çubuğu
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF5F7FA),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Mesaj ara...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              Expanded(child: _buildBody(user)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(User user) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      final isAuthError = _error!.contains('401') || 
                         _error!.contains('Unauthenticated') ||
                         _error!.contains('Unauthorized') ||
                         _error!.contains('Oturum süresi doldu');
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAuthError ? Icons.lock_outline : Icons.error_outline,
                size: 64,
                color: isAuthError ? Colors.orange[400] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                isAuthError ? 'Oturum Süresi Doldu' : 'Mesajlar yüklenirken hata oluştu',
                style: TextStyle(
                  fontSize: 16,
                  color: isAuthError ? Colors.orange[600] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAuthError 
                  ? 'Güvenlik nedeniyle oturumunuz sonlandırıldı.\nLütfen tekrar giriş yapın.'
                  : _error!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isAuthError) ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Giriş Yap'),
                    ),
                    const SizedBox(width: 16),
                  ],
                  ElevatedButton(
                    onPressed: _loadChats,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredChats.isEmpty) {
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
              'Öğretmenlerle konuşmaya başlayın!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F7FA), // Anasayfa ile uyumlu arka plan
      child: RefreshIndicator(
        onRefresh: _refreshChats,
        color: const Color(0xFF8B5CF6), // Mor accent
        backgroundColor: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: _filteredChats.length,
          itemBuilder: (context, index) {
            final chat = _filteredChats[index];
            return _buildModernChatItem(chat, user);
          },
        ),
      ),
    );
  }

  Widget _buildModernChatItem(Chat chat, User currentUser) {
    final isUnread = chat.unreadCount > 0;
    final lastMessageTime = _formatTime(chat.updatedAt);
    
    return Container(
      margin: EdgeInsets.zero, // Boşluk kaldırıldı
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero, // Köşeleri tamamen kaldırıldı
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChat(chat, currentUser),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Avatar - Figma tasarımına uygun
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: chat.otherUser?.profilePhotoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(
                            chat.otherUser!.profilePhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.grey[500],
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: Colors.grey[500],
                          size: 30,
                        ),
                ),
                const SizedBox(width: 16),
                // Chat Content - Figma tasarımına uygun
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                                chat.otherUser?.name ?? 'Buse Köse',
                                style: const TextStyle(
                                  fontSize: 16, // Anasayfa ile uyumlu font boyutu
                                  fontWeight: FontWeight.w700, // Anasayfa ile uyumlu font weight
                                  color: Colors.black87,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ),
                          Text(
                            lastMessageTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                                chat.lastMessage?.content ?? '✓✓ Thanks',
                                style: TextStyle(
                                  fontSize: 14, // Anasayfa ile uyumlu font boyutu
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6), // Mor renk
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11, // Anasayfa ile uyumlu font boyutu
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(Chat chat, User currentUser) {
    final otherUser = chat.otherUser;
    if (otherUser == null) return;
    
    if (currentUser.isStudent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentChatScreen(
            teacher: otherUser,
          ),
        ),
      );
    } else if (currentUser.isTeacher) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeacherChatScreen(
            student: otherUser,
          ),
        ),
      );
    } else {
      if (otherUser.role == 'teacher') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentChatScreen(
              teacher: otherUser,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherChatScreen(
              student: otherUser,
            ),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return DateFormat('dd MMM', 'tr').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}sa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk';
    } else {
      return 'Şimdi';
    }
  }
}
