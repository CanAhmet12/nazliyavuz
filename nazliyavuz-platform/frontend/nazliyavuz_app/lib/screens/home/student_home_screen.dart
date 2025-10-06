import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../../models/user.dart';
import '../../models/teacher.dart';
import '../../models/lesson.dart';
import '../../services/api_service.dart';
import '../teachers/enhanced_teachers_screen.dart';
import '../teachers/teacher_detail_screen.dart';
import '../reservations/student_reservations_screen.dart';
import '../profile/student_profile_screen.dart';
import '../search/search_screen.dart';
import '../notifications/notification_screen.dart';
import '../lessons/student_lessons_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../chat/chat_list_screen.dart';
import '../assignments/student_assignments_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  
  // Performance optimization
  late AnimationController _fabAnimationController;
  
  // Recommended teachers data
  List<Teacher> _recommendedTeachers = [];
  bool _isLoadingTeachers = false;
  
  // Recent lessons data
  List<Lesson> _recentLessons = [];
  bool _isLoadingLessons = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced duration
      vsync: this,
    );
    
    // Start animation after build for better performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fabAnimationController.forward();
        _loadRecommendedTeachers();
        _loadRecentLessons();
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendedTeachers() async {
    if (_isLoadingTeachers) return;
    
    setState(() {
      _isLoadingTeachers = true;
    });

    try {
      final apiService = ApiService();
      final teachers = await apiService.getTeachers(
        sortBy: 'rating_desc',
        page: 1,
      );
      
      if (mounted) {
        setState(() {
          _recommendedTeachers = teachers.take(3).toList();
          _isLoadingTeachers = false;
        });
        print('✅ Loaded ${_recommendedTeachers.length} recommended teachers');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTeachers = false;
        });
      }
      print('❌ Error loading recommended teachers: $e');
    }
  }

  Future<void> _loadRecentLessons() async {
    if (_isLoadingLessons) return;
    
    setState(() {
      _isLoadingLessons = true;
    });

    try {
      final apiService = ApiService();
      final lessons = await apiService.getUserLessons(
        page: 1,
      );
      
      if (mounted) {
        setState(() {
          // Get last 3 completed or in-progress lessons
          _recentLessons = lessons
              .where((lesson) {
                final status = lesson.status;
                if (kDebugMode) {
                  print('🔍 [RECENT_LESSONS] Checking lesson status: $status');
                }
                return status == 'completed' || status == 'in_progress';
              })
              .take(3)
              .toList();
          _isLoadingLessons = false;
        });
        if (kDebugMode) {
          print('✅ [RECENT_LESSONS] Loaded ${_recentLessons.length} recent lessons');
          for (var lesson in _recentLessons) {
            print('🔍 [RECENT_LESSONS] Lesson: ${lesson.subject}, Status: ${lesson.status}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLessons = false;
        });
      }
      print('❌ Error loading recent lessons: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return Scaffold(
            body: CustomWidgets.customLoading(
              message: 'Yükleniyor...',
            ),
          );
        }

        final user = state.user;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              RepaintBoundary(child: _buildStudentHomeTab(user)),
              const RepaintBoundary(child: EnhancedTeachersScreen()),
              const RepaintBoundary(child: StudentLessonsScreen()),
              const RepaintBoundary(child: StudentReservationsScreen()),
              const RepaintBoundary(child: StudentProfileScreen()),
            ],
          ),
          bottomNavigationBar: _buildStudentBottomNavigationBar(),
          floatingActionButton: _buildStudentFloatingActionButton(),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );
      },
      ),
    );
  }

  Widget _buildStudentBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppTheme.grey200,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Ana Sayfa')),
              Expanded(child: _buildNavItem(1, Icons.school_outlined, Icons.school, 'Öğretmenler')),
              Expanded(child: _buildNavItem(2, Icons.book_outlined, Icons.book, 'Dersler')),
              Expanded(child: _buildNavItem(3, Icons.calendar_today_outlined, Icons.calendar_today, 'Rezervasyonlar')),
              Expanded(child: _buildNavItem(4, Icons.person_outlined, Icons.person, 'Profil')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          HapticFeedback.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : AppTheme.grey500,
                  size: 20, // Daha büyük ikon
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.grey500,
                  fontSize: 11, // Daha büyük yazı
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentFloatingActionButton() {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.premiumGold.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: "student_fab",
          onPressed: () {
            HapticFeedback.mediumImpact();
            _showStudentQuickActions(context);
          },
          backgroundColor: AppTheme.premiumGold,
          foregroundColor: AppTheme.grey900,
          elevation: 0, // Custom shadow instead
          mini: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showStudentQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Hızlı İşlemler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Quick Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildQuickActionCard(
                      context,
                      icon: Icons.search_rounded,
                      title: 'Öğretmen Ara',
                      subtitle: 'Yeni öğretmen bul',
                      color: AppTheme.premiumGold,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: 'Ders Rezervasyonu',
                      subtitle: 'Yeni ders planla',
                      color: AppTheme.amberAccent,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentIndex = 3; // Rezervasyonlar tab'ine geç
                        });
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.chat_rounded,
                      title: 'Mesajlar',
                      subtitle: 'Öğretmenlerle konuş',
                      color: AppTheme.primaryBlue,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to chat with proper user selection
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const ChatScreen(),
                        //   ),
                        // );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.notifications_rounded,
                      title: 'Bildirimler',
                      subtitle: 'Yeni mesajlar',
                      color: AppTheme.accentRed,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CustomWidgets.customCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100], // Açık gri arka plan
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.grey700,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHomeTab(User user) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Daha nötr gri ton
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar
          _buildStudentSliverAppBar(user),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildStudentWelcomeSection(user),
                  
                  const SizedBox(height: 20),
                  
                  // Quick Actions Grid
                  _buildStudentQuickActionsGrid(),
                  
                  const SizedBox(height: 20),
                  
                  // Learning Stats
                  _buildLearningStats(),
                  
                  const SizedBox(height: 20),
                  
                  // Recent Lessons
                  _buildRecentLessons(),
                  
                  const SizedBox(height: 20),
                  
                  // Recommended Teachers
                  _buildRecommendedTeachers(),
                  
                  const SizedBox(height: 20), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSliverAppBar(User user) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Profile Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: user.profilePhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              user.profilePhotoUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Welcome Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Merhaba Öğrenci,',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentWelcomeSection(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.accentPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ${user.name}! 📚',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bugün hangi konuyu öğrenmek istiyorsun?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentQuickActionsGrid() {
        
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğrenci İşlemleri',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStudentQuickActionCard(
                icon: Icons.search_rounded,
                title: 'Öğretmen Ara',
                subtitle: 'Yeni öğretmen bul',
                color: AppTheme.premiumGold,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStudentQuickActionCard(
                icon: Icons.calendar_today_rounded,
                title: 'Ders Rezervasyonu',
                subtitle: 'Yeni ders planla',
                color: AppTheme.amberAccent,
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentReservationsScreen(),
                  ),
                );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStudentQuickActionCard(
                icon: Icons.chat_rounded,
                title: 'Mesajlar',
                subtitle: 'Öğretmenlerle konuş',
                color: AppTheme.primaryBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatListScreen(),
                          ),
                        );
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStudentQuickActionCard(
                icon: Icons.assignment_rounded,
                title: 'Ödevler',
                subtitle: 'Ödevlerimi görüntüle',
                color: AppTheme.accentGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentAssignmentsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğrenme İstatistikleri',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Aktif Dersler',
                  '3',
                  Icons.play_circle_filled_rounded,
                  const Color(0xFF10B981),
                  'Bu hafta',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Tamamlanan',
                  '12',
                  Icons.check_circle_rounded,
                  const Color(0xFF3B82F6),
                  'Bu ay',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Öğretmenler',
                  '5',
                  Icons.people_rounded,
                  const Color(0xFF8B5CF6),
                  'Toplam',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              fontSize: 20,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLessons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Son Dersler',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 3; // Rezervasyonlar tab'ine geç
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tümü',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isLoadingLessons 
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _recentLessons.isEmpty
                  ? _buildNoLessonsPlaceholder()
                  : Column(
                      children: [
                        ...(_recentLessons.asMap().entries.map((entry) {
                          final index = entry.key;
                          final lesson = entry.value;
                          return Column(
                            children: [
                              _buildRealLessonItem(lesson),
                              if (index < _recentLessons.length - 1) 
                                const SizedBox(height: 12),
                            ],
                          );
                        }).toList()),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildRealLessonItem(Lesson lesson) {
    if (kDebugMode) {
      print('🔍 [RECENT_LESSONS] Building lesson item: $lesson');
      print('🔍 [RECENT_LESSONS] Lesson type: ${lesson.runtimeType}');
    }
    
    final title = lesson.subject;
    final teacherName = lesson.teacherName;
    final status = lesson.status;
    final scheduledAt = lesson.scheduledAt;
    
    if (kDebugMode) {
      print('🔍 [RECENT_LESSONS] Parsed - title: $title, teacher: $teacherName, status: $status');
    }
    
    // Determine icon and colors based on lesson type
    IconData icon;
    Color iconColor;
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'completed':
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF10B981);
        statusColor = const Color(0xFF10B981);
        statusText = 'Tamamlandı';
        break;
      case 'in_progress':
        icon = Icons.play_circle_rounded;
        iconColor = const Color(0xFFF59E0B);
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Devam Ediyor';
        break;
      case 'scheduled':
        icon = Icons.schedule_rounded;
        iconColor = const Color(0xFF3B82F6);
        statusColor = const Color(0xFF3B82F6);
        statusText = 'Planlandı';
        break;
      default:
        icon = Icons.help_outline_rounded;
        iconColor = const Color(0xFF6B7280);
        statusColor = const Color(0xFF6B7280);
        statusText = 'Bilinmiyor';
    }
    
    return _buildModernActivityItem(
      title,
      teacherName,
      _formatLessonTime(scheduledAt),
      icon,
      iconColor,
      statusText,
      statusColor,
    );
  }

  Widget _buildNoLessonsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz ders bulunmuyor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'İlk dersinizi almak için bir öğretmen bulun',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatLessonTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Bugün ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildModernActivityItem(String title, String teacher, String time, IconData icon, Color iconColor, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTeachers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Önerilen Öğretmenler',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 1; // Navigate to teachers screen
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tümü',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: _isLoadingTeachers 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _recommendedTeachers.isEmpty ? 3 : _recommendedTeachers.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 160,
                      margin: EdgeInsets.only(right: index == (_recommendedTeachers.isEmpty ? 2 : _recommendedTeachers.length - 1) ? 0 : 16),
                      child: _recommendedTeachers.isEmpty 
                          ? _buildPlaceholderTeacherCard(_getTeacherColor(index))
                          : _buildRealTeacherCard(_recommendedTeachers[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }


  Widget _buildRealTeacherCard(Teacher teacher) {
    final categoryName = (teacher.categories?.isNotEmpty == true) 
        ? teacher.categories!.first.name 
        : 'Genel';
    final categoryColors = _getCategoryColors(categoryName);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherDetailScreen(teacher: teacher),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: categoryColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: teacher.user?.profilePhotoUrl != null
                      ? NetworkImage(teacher.user!.profilePhotoUrl!)
                      : null,
                  child: teacher.user?.profilePhotoUrl == null
                      ? Text(
                          (teacher.user?.name.substring(0, 1).toUpperCase()) ?? '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name ?? 'İsimsiz',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${teacher.rating?.toStringAsFixed(1) ?? '0.0'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₺${teacher.priceHour?.toInt() ?? 0}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTeacherCard(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.grey200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 12,
                          width: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getTeacherColor(int index) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    return colors[index % colors.length];
  }

  List<Color> _getCategoryColors(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'matematik':
      case 'fizik':
      case 'kimya':
      case 'biyoloji':
        return [const Color(0xFF3B82F6), const Color(0xFF3B82F6).withOpacity(0.8)];
      case 'türkçe':
      case 'edebiyat':
      case 'tarih':
      case 'coğrafya':
        return [const Color(0xFF10B981), const Color(0xFF10B981).withOpacity(0.8)];
      case 'ingilizce':
      case 'almanca':
      case 'fransızca':
        return [const Color(0xFFF59E0B), const Color(0xFFF59E0B).withOpacity(0.8)];
      case 'programlama':
      case 'web tasarımı':
      case 'bilgisayar':
        return [const Color(0xFF8B5CF6), const Color(0xFF8B5CF6).withOpacity(0.8)];
      case 'müzik':
      case 'resim':
      case 'sanat':
        return [const Color(0xFFEF4444), const Color(0xFFEF4444).withOpacity(0.8)];
      case 'spor':
      case 'fitness':
      case 'yoga':
        return [const Color(0xFFEC4899), const Color(0xFFEC4899).withOpacity(0.8)];
      default:
        return [const Color(0xFF6B7280), const Color(0xFF6B7280).withOpacity(0.8)];
    }
  }

}