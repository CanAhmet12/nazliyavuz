import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import '../../models/user.dart';
import '../profile/profile_edit_screen.dart';
import '../profile/password_change_screen.dart';
import '../profile/notification_preferences_screen.dart';
import '../profile/activity_history_screen.dart';
import '../profile/account_settings_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  Map<String, dynamic> _learningStatistics = {};
  
  bool _isLoading = true;
  bool _isUpdatingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadLearningStatistics(),
      ]);

      if (mounted) {
        _animationController.forward();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _cardAnimationController.forward();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLearningStatistics() async {
    try {
      if (kDebugMode) {
        print('📊 [STUDENT_PROFILE] Loading learning statistics...');
      }
      
      final statistics = await _apiService.getReservationStatistics();
      
      if (kDebugMode) {
        print('📊 [STUDENT_PROFILE] Statistics loaded: $statistics');
      }
      
      if (mounted) {
        setState(() {
          _learningStatistics = statistics;
          _isLoading = false;
        });
        
        if (kDebugMode) {
          print('📊 [STUDENT_PROFILE] State updated with statistics');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [STUDENT_PROFILE] Error loading statistics: $e');
      }
      
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isUpdatingPhoto = true;
        });

        // Photo update logic would go here
        // For now, just update the loading state
        
        if (mounted) {
          setState(() {
            _isUpdatingPhoto = false;
          });
          
          // Update auth state
          context.read<AuthBloc>().add(const AuthLogoutRequested());
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil fotoğrafı güncellendi'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingPhoto = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
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
          backgroundColor: const Color(0xFFF8FAFC),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoading
                  ? _buildStudentLoadingState()
                  : _error != null
                      ? _buildStudentErrorState()
                      : _buildStudentProfileContent(user),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentProfileContent(User user) {
    return CustomScrollView(
      slivers: [
        _buildStudentProfileAppBar(user),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStudentProfileHeader(user),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStudentLearningStats(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStudentAchievements(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStudentProfileOptions(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStudentAccountSettings(),
          ),
        ),
        
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildStudentProfileAppBar(User user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue,
                AppTheme.accentPurple,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Öğrenci Profilim',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Öğrenme yolculuğunuz',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileEditScreen(userProfile: {}),
                            ),
                          );
                        },
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

  Widget _buildStudentProfileHeader(User user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUpdatingPhoto
                      ? const Center(child: CircularProgressIndicator())
                      : user.profilePhotoUrl != null
                          ? Image.network(
                              user.profilePhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(user);
                              },
                            )
                          : _buildDefaultAvatar(user),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _updateProfilePhoto,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Öğrenci',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: 50,
        color: AppTheme.primaryBlue,
      ),
    );
  }

  Widget _buildStudentLearningStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Öğrenme İstatistikleri',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStudentStatCard(
                  'Tamamlanan Dersler',
                  '${_learningStatistics['completed_lessons'] ?? 0}',
                  Icons.check_circle_rounded,
                  AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStudentStatCard(
                  'Aktif Dersler',
                  '${_learningStatistics['active_lessons'] ?? 0}',
                  Icons.play_circle_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStudentStatCard(
                  'Toplam Saat',
                  '${_learningStatistics['total_hours'] ?? 0}',
                  Icons.schedule_rounded,
                  AppTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStudentStatCard(
                  'Başarı Oranı',
                  '%${_learningStatistics['success_rate'] ?? 0}',
                  Icons.trending_up_rounded,
                  AppTheme.accentPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAchievements() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Başarılarım',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          _buildAchievementItem(
            'İlk Ders',
            'İlk dersinizi tamamladınız!',
            Icons.star_rounded,
            AppTheme.premiumGold,
            true,
          ),
          _buildAchievementItem(
            '5 Ders Tamamlama',
            '5 ders tamamladınız!',
            Icons.emoji_events_rounded,
            AppTheme.accentOrange,
            true,
          ),
          _buildAchievementItem(
            'Haftalık Hedef',
            'Bu hafta 3 ders alın',
            Icons.flag_rounded,
            AppTheme.accentGreen,
            false,
          ),
          _buildAchievementItem(
            'Aylık Hedef',
            'Bu ay 10 ders alın',
            Icons.calendar_month_rounded,
            AppTheme.accentPurple,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(String title, String description, IconData icon, Color color, bool isAchieved) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAchieved ? color.withOpacity(0.1) : AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAchieved ? color.withOpacity(0.3) : AppTheme.grey300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAchieved ? color : AppTheme.grey400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: Colors.white,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isAchieved ? color : AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isAchieved ? color : AppTheme.grey500,
                  ),
                ),
              ],
            ),
          ),
          if (isAchieved)
            Icon(
              Icons.check_circle_rounded,
              color: color,
              size: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildStudentProfileOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStudentProfileOption(
            'Profilimi Düzenle',
            'Kişisel bilgilerinizi güncelleyin',
            Icons.edit_rounded,
            AppTheme.primaryBlue,
            () {
              if (kDebugMode) {
                print('👤 [STUDENT_PROFILE] Profile Edit clicked');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(userProfile: {}),
                ),
              );
            },
          ),
          _buildStudentProfileOption(
            'Öğrenme Geçmişi',
            'Ders geçmişinizi görüntüleyin',
            Icons.history_rounded,
            AppTheme.accentGreen,
            () {
              if (kDebugMode) {
                print('📚 [STUDENT_PROFILE] Activity History clicked');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivityHistoryScreen(),
                ),
              );
            },
          ),
          _buildStudentProfileOption(
            'Bildirim Tercihleri',
            'Bildirim ayarlarınızı yönetin',
            Icons.notifications_rounded,
            AppTheme.accentOrange,
            () {
              if (kDebugMode) {
                print('🔔 [STUDENT_PROFILE] Notification Preferences clicked');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationPreferencesScreen(preferences: {}),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAccountSettings() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStudentProfileOption(
            'Şifre Değiştir',
            'Hesap güvenliğinizi artırın',
            Icons.lock_rounded,
            AppTheme.accentRed,
            () {
              if (kDebugMode) {
                print('🔒 [STUDENT_PROFILE] Password Change clicked');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PasswordChangeScreen(),
                ),
              );
            },
          ),
          _buildStudentProfileOption(
            'Hesap Ayarları',
            'Hesap tercihlerinizi yönetin',
            Icons.settings_rounded,
            AppTheme.grey600,
            () {
              if (kDebugMode) {
                print('⚙️ [STUDENT_PROFILE] Account Settings clicked');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsScreen(),
                ),
              );
            },
          ),
          _buildStudentProfileOption(
            'Çıkış Yap',
            'Hesabınızdan güvenle çıkış yapın',
            Icons.logout_rounded,
            AppTheme.accentRed,
            () {
              _showLogoutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProfileOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.grey400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Profil bilgileri yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentErrorState() {
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
            'Bir hata oluştu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}
