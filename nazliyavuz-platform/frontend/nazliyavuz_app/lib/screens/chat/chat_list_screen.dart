import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import 'chat_screen.dart';
import 'student_chat_screen.dart';
import 'teacher_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _apiService = ApiService();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final chats = await _apiService.getChats();
      
      setState(() {
        _chats = chats;
        _filteredChats = chats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshChats() async {
    await _loadChats();
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
          appBar: AppBar(
            title: const Text('Mesajlar'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  _showSearchDialog();
                },
              ),
            ],
          ),
          body: _buildBody(user),
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
              onPressed: _loadChats,
              child: const Text('Tekrar Dene'),
            ),
          ],
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

    return RefreshIndicator(
      onRefresh: _refreshChats,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredChats.length,
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          return _buildChatItem(chat, user);
        },
      ),
    );
  }

  Widget _buildChatItem(Chat chat, User currentUser) {
    final isUnread = chat.unreadCount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Role-based navigation to appropriate chat screen
            if (currentUser.isStudent) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentChatScreen(
                    teacher: chat.otherUser,
                  ),
                ),
              );
            } else if (currentUser.isTeacher) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeacherChatScreen(
                    student: chat.otherUser,
                  ),
                ),
              );
            } else {
              // Fallback to generic chat screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    otherUser: chat.otherUser,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isUnread ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: isUnread 
                  ? Border.all(color: AppTheme.primaryBlue.withOpacity(0.1), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isUnread 
                      ? AppTheme.primaryBlue.withOpacity(0.08)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: isUnread ? 15 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          child: Row(
            children: [
              // Profile Photo with Online Status
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.accentPurple,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: chat.otherUser.profilePhotoUrl == null
                        ? Center(
                            child: Text(
                              chat.otherUser.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.network(
                              chat.otherUser.profilePhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    chat.otherUser.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  // Online Status Indicator
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Chat Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.otherUser.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chat.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue,
                                  AppTheme.accentPurple,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              chat.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: chat.otherUser.role == 'teacher' 
                            ? AppTheme.accentOrange.withOpacity(0.1)
                            : AppTheme.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        chat.otherUser.role == 'teacher' ? '👨‍🏫 Öğretmen' : '👨‍🎓 Öğrenci',
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.otherUser.role == 'teacher' 
                              ? AppTheme.accentOrange
                              : AppTheme.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (chat.lastMessage != null)
                      Text(
                        chat.lastMessage!.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: isUnread ? const Color(0xFF1E293B) : Colors.grey[600],
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        '💬 Henüz mesaj yok',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Time and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(chat.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (chat.lastMessage != null)
                    Icon(
                      chat.lastMessage!.isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: chat.lastMessage!.isRead 
                          ? AppTheme.primaryBlue 
                          : Colors.grey[400],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbet Ara'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Kullanıcı adı veya mesaj ara...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _searchQuery = value;
            _filterChats();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _filterChats();
              Navigator.pop(context);
            },
            child: const Text('Ara'),
          ),
        ],
      ),
    );
  }

  void _filterChats() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredChats = _chats;
      });
    } else {
      setState(() {
        _filteredChats = _chats.where((chat) {
          return chat.otherUser.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 (chat.lastMessage?.content.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();
      });
    }
  }
}
