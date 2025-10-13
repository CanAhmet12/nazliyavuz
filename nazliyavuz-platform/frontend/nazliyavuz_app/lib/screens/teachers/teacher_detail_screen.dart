import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../models/teacher.dart';
import '../../models/user.dart';
import '../../models/rating.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../reservations/create_reservation_screen.dart';
import '../chat/chat_screen.dart';

class TeacherDetailScreen extends StatefulWidget {
  final Teacher teacher;

  const TeacherDetailScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabScaleAnimation;
  
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  
  // Ratings data
  List<Rating> _ratings = [];
  bool _isLoadingRatings = false;
  String? _ratingsError;
  
  // Lessons data
  List<dynamic> _lessons = [];
  bool _isLoadingLessons = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('📱 [TEACHER_DETAIL] initState called for teacher ID: ${widget.teacher.id}');
      print('📱 [TEACHER_DETAIL] Teacher user ID: ${widget.teacher.user?.id}');
      print('📱 [TEACHER_DETAIL] Teacher name: ${widget.teacher.user?.name}');
    }
    _initializeAnimations();
    _startAnimations();
    _loadRatings();
    _loadLessons();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
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

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _startAnimations() {
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  Future<void> _loadRatings() async {
    if (_isLoadingRatings) return;
    
    if (kDebugMode) {
      print('📱 [TEACHER_DETAIL] Loading ratings for teacher ID: ${widget.teacher.id}');
      print('📱 [TEACHER_DETAIL] Teacher user ID: ${widget.teacher.user?.id}');
      print('📱 [TEACHER_DETAIL] Teacher object: ${widget.teacher.toString()}');
    }
    
    // Teacher ID null ise user ID'yi kullan
    final teacherId = widget.teacher.id ?? widget.teacher.user?.id;
    
    if (teacherId == null) {
      if (kDebugMode) {
        print('❌ [TEACHER_DETAIL] Teacher ID is null, cannot load ratings');
      }
      setState(() {
        _ratingsError = 'Eğitimci bilgileri eksik';
        _isLoadingRatings = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingRatings = true;
      _ratingsError = null;
    });

    try {
      if (kDebugMode) {
        print('📱 [TEACHER_DETAIL] Calling API service with teacher ID: $teacherId');
      }
      final ratings = await _apiService.getTeacherRatings(teacherId);
      if (mounted) {
        setState(() {
          _ratings = ratings;
          _isLoadingRatings = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('📱 [TEACHER_DETAIL] Error loading ratings: $e');
      }
      if (mounted) {
        setState(() {
          _ratingsError = e.toString();
          _isLoadingRatings = false;
        });
      }
    }
  }

  Future<void> _loadLessons() async {
    if (_isLoadingLessons) return;
    
    // Teacher ID null ise user ID'yi kullan
    final teacherId = widget.teacher.id ?? widget.teacher.user?.id;
    
    if (teacherId == null) {
      if (kDebugMode) {
        print('❌ [TEACHER_DETAIL] Teacher ID is null, cannot load lessons');
      }
      return;
    }
    
    setState(() {
      _isLoadingLessons = true;
    });

    try {
      final response = await _apiService.get('/teachers/$teacherId/lessons');
      if (response['success'] && mounted) {
        setState(() {
          _lessons = response['lessons'] ?? [];
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLessons = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Modern Hero Header
              _buildModernHeroHeader(),
              
              // Teacher Info Cards
              SliverToBoxAdapter(
                child: _buildTeacherInfoSection(),
              ),
              
              // Stats Section
              SliverToBoxAdapter(
                child: _buildStatsSection(),
              ),
              
              // About Section
              SliverToBoxAdapter(
                child: _buildAboutSection(),
              ),
              
              // Categories Section
              SliverToBoxAdapter(
                child: _buildCategoriesSection(),
              ),
              
              // Reviews Section
              SliverToBoxAdapter(
                child: _buildReviewsSection(),
              ),
              
              // Bottom Padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: _buildFloatingActionButtons(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernHeroHeader() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.grey900,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.black87,
            size: 20,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _isFavorite = !_isFavorite);
            },
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryBlue.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative Elements
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppTheme.premiumGold.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              // Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Compact Profile Photo
                      Hero(
                        tag: 'teacher_detail_${widget.teacher.id}',
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                            backgroundImage: widget.teacher.user?.profilePhotoUrl != null
                                ? NetworkImage(widget.teacher.user!.profilePhotoUrl!)
                                : null,
                            child: widget.teacher.user?.profilePhotoUrl == null
                                ? Text(
                                    widget.teacher.user?.name?.substring(0, 1).toUpperCase() ?? '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Compact Name
                      Text(
                        widget.teacher.user?.name ?? 'İsimsiz Eğitimci',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Primary Category
                      if (widget.teacher.categories?.isNotEmpty == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlue.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.teacher.categories!.first.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Rating Card
          Expanded(
            child: _buildInfoCard(
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              title: 'Puan',
              value: widget.teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
              subtitle: '5 üzerinden',
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Price Card
          Expanded(
            child: _buildInfoCard(
              icon: Icons.attach_money_rounded,
              iconColor: AppTheme.accentGreen,
              title: 'Saatlik Ücret',
              value: '₺${widget.teacher.priceHour?.toInt() ?? 0}',
              subtitle: 'saat başına',
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Students Card
          Expanded(
            child: _buildInfoCard(
              icon: Icons.people_rounded,
              iconColor: AppTheme.primaryBlue,
              title: 'Öğrenci',
              value: widget.teacher.totalStudents?.toString() ?? '0',
              subtitle: 'aktif öğrenci',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 İstatistikler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatRow(
                  'Toplam Ders',
                  '${widget.teacher.totalLessons ?? 0}',
                  Icons.school_rounded,
                  AppTheme.primaryBlue,
                ),
                const SizedBox(height: 16),
                _buildStatRow(
                  'Deneyim',
                  '${widget.teacher.experienceYears ?? 0} yıl',
                  Icons.timeline_rounded,
                  AppTheme.accentOrange,
                ),
                const SizedBox(height: 16),
                _buildStatRow(
                  'Yanıt Süresi',
                  '~2 saat',
                  Icons.schedule_rounded,
                  AppTheme.accentGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
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
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👨‍🏫 Hakkında',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher.bio ?? 
                  'Bu eğitimci henüz kendisi hakkında bilgi paylaşmamış. Deneyimli ve özenli bir eğitim anlayışı ile öğrencilerine en iyi hizmeti sunmayı hedefliyor.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
                
                if (widget.teacher.education != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: AppTheme.primaryBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Eğitim',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              widget.teacher.education?.join(', ') ?? 'Belirtilmemiş',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (widget.teacher.languages?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: AppTheme.accentGreen,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Diller',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: (widget.teacher.languages ?? []).map((lang) => 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    lang,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    if (widget.teacher.categories?.isEmpty != false) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📚 Uzmanlık Alanları',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: (widget.teacher.categories ?? []).map((category) => 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.premiumGold.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '⭐ Değerlendirmeler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _showAllReviews();
                },
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Review Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      widget.teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) => 
                        Icon(
                          Icons.star,
                          size: 16,
                          color: index < (widget.teacher.ratingAvg?.round() ?? 0) 
                              ? Colors.amber 
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0 değerlendirme',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: List.generate(5, (index) {
                      final stars = 5 - index;
                      final percentage = _getReviewPercentage(stars);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '$stars',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: percentage / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${percentage.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Real Reviews from API
          if (_isLoadingRatings)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_ratingsError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[400],
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yorumlar yüklenemedi',
                      style: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadRatings,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            )
          else if (_ratings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      color: Colors.grey[400],
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Henüz yorum yapılmamış',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu eğitimci için ilk yorumu sen yap!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ratings.length,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ratings[index].studentName ?? 'Anonim',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Row(
                                children: [
                                  ...List.generate(5, (starIndex) => 
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: starIndex < _ratings[index].rating ? Colors.amber : Colors.grey[300],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _ratings[index].timeSinceCreated,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _ratings[index].comment ?? 'Yorum yapılmamış',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Message Button
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryBlue,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _navigateToChat();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Mesaj',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Book Lesson Button
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateReservationScreen(teacher: widget.teacher),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Rezervasyon',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₺${widget.teacher.priceHour?.toInt() ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }

  double _getReviewPercentage(int stars) {
    if (_ratings.isEmpty) return 0;
    
    final count = _ratings.where((rating) => rating.rating == stars).length;
    return (count / _ratings.length) * 100;
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Tüm Değerlendirmeler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _lessons.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              color: Colors.grey[400],
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz ders kaydı bulunmuyor',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bu eğitimci henüz ders vermeye başlamamış',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                                child: Text(
                                  'Ö${index + 1}',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Öğrenci ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (starIndex) {
                                        return Icon(
                                          starIndex < 4 ? Icons.star : Icons.star_border,
                                          color: AppTheme.premiumGold,
                                          size: 16,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Çok iyi bir eğitimci. Dersleri çok anlaşılır ve eğlenceli. Kesinlikle tavsiye ederim.',
                            style: TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUser: User(
            id: widget.teacher.id ?? 0,
            name: widget.teacher.user?.name ?? 'Eğitimci',
            email: widget.teacher.user?.email ?? '',
            role: 'teacher',
            profilePhotoUrl: widget.teacher.user?.profilePhotoUrl,
          ),
        ),
      ),
    );
  }
}