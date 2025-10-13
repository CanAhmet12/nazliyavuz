import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import '../../models/user.dart';
import '../profile/profile_edit_screen.dart';
import '../profile/password_change_screen.dart';
import '../profile/notification_preferences_screen.dart';
import '../profile/activity_history_screen.dart';
import '../profile/account_settings_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  Map<String, dynamic> _teachingStatistics = {};
  
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
        _loadTeachingStatistics(),
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

  Future<void> _loadTeachingStatistics() async {
    try {
      final statistics = await _apiService.getReservationStatistics();
      
      if (mounted) {
        setState(() {
          _teachingStatistics = statistics;
          _isLoading = false;
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

        // Backend'e yükle
        await _apiService.updateProfilePhoto(image);
        
        // Profil bilgilerini yeniden yükle
        final authBloc = context.read<AuthBloc>();
        authBloc.add(const AuthRefreshRequested());
        
        if (mounted) {
          setState(() {
            _isUpdatingPhoto = false;
          });
          
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
                  ? _buildTeacherLoadingState()
                  : _error != null
                      ? _buildTeacherErrorState()
                      : _buildTeacherProfileContent(user),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeacherProfileContent(User user) {
    return CustomScrollView(
      slivers: [
        _buildTeacherProfileAppBar(user),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherProfileHeader(user),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherTeachingStats(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherCertifications(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherEarnings(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherProfileOptions(),
          ),
        ),
        
        SliverToBoxAdapter(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildTeacherAccountSettings(),
          ),
        ),
        
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildTeacherProfileAppBar(User user) {
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
                AppTheme.accentGreen,
                AppTheme.primaryBlue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withOpacity(0.3),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Eğitimci Profilim',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Eğitimcilik yolculuğunuz',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileEditScreen(userProfile: {}),
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

  Widget _buildTeacherProfileHeader(User user) {
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
                    color: AppTheme.accentGreen.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGreen.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUpdatingPhoto
                      ? const Center(child: CircularProgressIndicator())
                      : user.profilePhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user.profilePhotoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return _buildDefaultTeacherAvatar(user);
                              },
                            )
                          : _buildDefaultTeacherAvatar(user),
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
                      color: AppTheme.accentGreen,
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
              color: AppTheme.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  color: AppTheme.accentGreen,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Eğitimci',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTeacherAvatar(User user) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.school_rounded,
        size: 50,
        color: AppTheme.accentGreen,
      ),
    );
  }

  Widget _buildTeacherTeachingStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Eğitimcilik İstatistikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Professional stats grid
            Row(
              children: [
                Expanded(
                  child: _buildTeacherStatCard(
                    'Verdiğim Dersler',
                    '${_teachingStatistics['total_lessons'] ?? 0}',
                    Icons.school_outlined,
                    const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTeacherStatCard(
                    'Aktif Öğrenciler',
                    '${_teachingStatistics['active_students'] ?? 0}',
                    Icons.people_outline,
                    const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTeacherStatCard(
                    'Toplam Saat',
                    '${_teachingStatistics['total_hours'] ?? 0}',
                    Icons.access_time_outlined,
                    const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTeacherStatCard(
                    'Değerlendirme',
                    '${_teachingStatistics['rating'] ?? 0}/5',
                    Icons.star_outline,
                    const Color(0xFFCA8A04),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and value
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCertifications() {
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
            'Sertifikalarım',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          _buildCertificationItem(
            'Matematik Eğitimciliği',
            'Lisans',
            '2020',
            true,
          ),
          _buildCertificationItem(
            'Pedagojik Formasyon',
            'Sertifika',
            '2021',
            true,
          ),
          _buildCertificationItem(
            'Online Eğitim Uzmanlığı',
            'Sertifika',
            '2022',
            true,
          ),
          _buildCertificationItem(
            'Özel Eğitim Uzmanlığı',
            'Yüksek Lisans',
            'Yakında',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationItem(String title, String type, String date, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.accentGreen.withOpacity(0.1) : AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.grey300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.accentGreen : AppTheme.grey400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.verified_rounded,
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
                    color: isCompleted ? AppTheme.accentGreen : AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$type • $date',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted ? AppTheme.accentGreen : AppTheme.grey500,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Icon(
              Icons.check_circle_rounded,
              color: AppTheme.accentGreen,
              size: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildTeacherEarnings() {
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
            'Kazançlarım',
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
                child: _buildEarningCard(
                  'Bu Ay',
                  '₺${_teachingStatistics['monthly_earnings'] ?? 0}',
                  Icons.calendar_month_rounded,
                  AppTheme.premiumGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEarningCard(
                  'Toplam',
                  '₺${_teachingStatistics['total_earnings'] ?? 0}',
                  Icons.account_balance_wallet_rounded,
                  AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.premiumGold.withOpacity(0.1),
                  AppTheme.accentOrange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.premiumGold.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: AppTheme.premiumGold,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hedef: ₺5000/ay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.premiumGold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kalan: ₺${5000 - (_teachingStatistics['monthly_earnings'] ?? 0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildTeacherProfileOptions() {
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
          _buildTeacherProfileOption(
            'Profilimi Düzenle',
            'Eğitimci bilgilerinizi güncelleyin',
            Icons.edit_rounded,
            AppTheme.accentGreen,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(userProfile: {}),
                ),
              );
            },
          ),
          _buildTeacherProfileOption(
            'Ders Geçmişi',
            'Verdiğiniz derslerin geçmişini görüntüleyin',
            Icons.history_rounded,
            AppTheme.primaryBlue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivityHistoryScreen(),
                ),
              );
            },
          ),
          _buildTeacherProfileOption(
            'Müsaitlik Takvimi',
            'Ders saatlerinizi yönetin',
            Icons.calendar_month_rounded,
            AppTheme.accentOrange,
            () {
              _showAvailabilityDialog();
            },
          ),
          _buildTeacherProfileOption(
            'Bildirim Tercihleri',
            'Bildirim ayarlarınızı yönetin',
            Icons.notifications_rounded,
            AppTheme.accentPurple,
            () {
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

  Widget _buildTeacherAccountSettings() {
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
          _buildTeacherProfileOption(
            'Şifre Değiştir',
            'Hesap güvenliğinizi artırın',
            Icons.lock_rounded,
            AppTheme.accentRed,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PasswordChangeScreen(),
                ),
              );
            },
          ),
          _buildTeacherProfileOption(
            'Hesap Ayarları',
            'Hesap tercihlerinizi yönetin',
            Icons.settings_rounded,
            AppTheme.grey600,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsScreen(),
                ),
              );
            },
          ),
          _buildTeacherProfileOption(
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

  Widget _buildTeacherProfileOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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

  Widget _buildTeacherLoadingState() {
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

  Widget _buildTeacherErrorState() {
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
              backgroundColor: AppTheme.accentGreen,
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

  void _showAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Müsaitlik Takvimi'),
        content: const Text('Müsaitlik takvimi özelliği yakında eklenecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
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
