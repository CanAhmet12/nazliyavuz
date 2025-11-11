import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../teachers/enhanced_teachers_screen.dart';

class StudentReservationsScreen extends StatefulWidget {
  const StudentReservationsScreen({super.key});

  @override
  State<StudentReservationsScreen> createState() => _StudentReservationsScreenState();
}

class _StudentReservationsScreenState extends State<StudentReservationsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  List<Reservation> _reservations = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  
  // Pagination removed to prevent duplicate data loading

  final List<Map<String, dynamic>> _statusTabs = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'pending', 'label': 'Bekleyen', 'icon': Icons.pending_rounded, 'color': AppTheme.accentOrange},
    {'value': 'accepted', 'label': 'Onaylı', 'icon': Icons.check_circle_rounded, 'color': AppTheme.accentGreen},
    {'value': 'completed', 'label': 'Tamamlanan', 'icon': Icons.done_all_rounded, 'color': AppTheme.primaryBlue},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _setupScrollListener();
    
    // Load data immediately to prevent infinite loops
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

  void _setupScrollListener() {
    // Scroll listener disabled to prevent duplicate data issues
    print('🔍 [STUDENT_RESERVATIONS] Scroll listener disabled');
  }

  void _onTabChanged() {
    // Tab change handled by _getFilteredReservations() method
    // No need for setState here to prevent infinite loops
  }

  Future<void> _loadInitialData() async {
    print('🔍 [STUDENT_RESERVATIONS] _loadInitialData called');
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadStudentReservations(),
        _loadStudentStatistics(),
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

  Future<void> _loadStudentReservations() async {
    print('🔍 [STUDENT_RESERVATIONS] _loadStudentReservations called');
    
    try {
      final reservations = await _apiService.getStudentReservations();

      print('🔍 [STUDENT_RESERVATIONS] API returned ${reservations.length} reservations');

      if (mounted) {
        // Clear existing data first to prevent duplicates
        _reservations.clear();
        
        setState(() {
          _reservations = List.from(reservations); // Create new list instance
          _isLoading = false;
          _isLoadingMore = false;
        });
        
        print('🔍 [STUDENT_RESERVATIONS] State updated with ${_reservations.length} reservations');
      }
    } catch (e) {
      print('🔍 [STUDENT_RESERVATIONS] Error loading reservations: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadStudentStatistics() async {
    try {
      final statistics = await _apiService.getReservationStatistics();

      if (mounted) {
        setState(() {
          _statistics = statistics;
        });
      }
    } catch (e) {
      // Statistics loading error: $e
    }
  }

  // Load more method removed to prevent duplicate data issues

  Future<void> _refreshData() async {
    print('🔍 [STUDENT_RESERVATIONS] _refreshData called - MANUAL REFRESH ONLY');
    setState(() {
      _reservations.clear();
      _isLoading = true;
      _error = null;
    });
    await _loadInitialData();
  }

  List<Reservation> _getFilteredReservations() {
    final selectedStatus = _statusTabs[_tabController.index]['value'] as String;
    if (selectedStatus.isEmpty) {
      return _reservations;
    }
    return _reservations.where((r) => r.status == selectedStatus).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _tabController.dispose();
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
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.primaryBlue,
            backgroundColor: Colors.white,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildStudentHeroAppBar(),
                
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildStudentStatisticsSection(),
                    ),
                  ),
                
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildStudentTabBarSection(),
                  ),
                ),
              ],
              body: _buildStudentReservationsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
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
                AppTheme.accentGreen.withOpacity(0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Row(
              children: [
                // Rezervasyonlarım Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppTheme.accentGreen,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Rezervasyonlarım',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Ders rezervasyonlarınız ve durumları',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Add New Reservation Button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnhancedTeachersScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentStatisticsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Daha kompakt margin
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Küçük ekranlarda vertical layout kullan
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStudentStatCard(
                        'Toplam Ders',
                        '${_reservations.length}',
                        Icons.school_rounded,
                        AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStudentStatCard(
                        'Bekleyen',
                        '${_reservations.where((r) => r.status == 'pending').length}',
                        Icons.schedule_rounded,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStudentStatCard(
                        'Onaylı',
                        '${_reservations.where((r) => r.status == 'accepted').length}',
                        Icons.check_circle_rounded,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStudentStatCard(
                        'Tamamlandı',
                        '${_reservations.where((r) => r.status == 'completed').length}',
                        Icons.done_all_rounded,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          
          // 2x2 grid düzeni
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStudentStatCard(
                      'Toplam Rezervasyon',
                      '${_reservations.length}',
                      Icons.calendar_today_rounded,
                      AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStudentStatCard(
                      'Bekleyen',
                      '${_reservations.where((r) => r.status == 'pending').length}',
                      Icons.schedule_rounded,
                      AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStudentStatCard(
                      'Onaylı',
                      '${_reservations.where((r) => r.status == 'accepted').length}',
                      Icons.check_circle_rounded,
                      AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStudentStatCard(
                      'Tamamlandı',
                      '${_reservations.where((r) => r.status == 'completed').length}',
                      Icons.done_all_rounded,
                      AppTheme.accentPurple,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 110, // Daha büyük yükseklik
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // İçeriği ortala
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTabBarSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4), // Daha kompakt margin
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4), // Daha kompakt padding
        child: Row(
          children: [
            _buildStudentFilterChip('Tümü', ''),
            const SizedBox(width: 8),
            _buildStudentFilterChip('Bekleyen', 'pending'),
            const SizedBox(width: 8),
            _buildStudentFilterChip('Onaylı', 'accepted'),
            const SizedBox(width: 8),
            _buildStudentFilterChip('Tamamlanan', 'completed'),
            const SizedBox(width: 16), // Son eleman için extra padding
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFilterChip(String label, String status) {
    final isSelected = _statusTabs[_tabController.index]['value'] == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _tabController.index = _statusTabs.indexWhere((tab) => tab['value'] == status);
        });
      },
    );
  }

  Widget _buildStudentReservationsList() {
    if (_isLoading) {
      return _buildStudentLoadingState();
    }

    if (_error != null) {
      return _buildStudentErrorState();
    }

    final filteredReservations = _getFilteredReservations();

    if (filteredReservations.isEmpty) {
      return _buildStudentEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Daha kompakt padding
      itemCount: filteredReservations.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < filteredReservations.length) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8), // Daha kompakt margin
            child: _buildStudentReservationCard(filteredReservations[index]),
          );
        } else if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return null;
      },
    );
  }

  Widget _buildStudentReservationCard(Reservation reservation) {
    final status = reservation.status;
    final teacher = reservation.teacher;
    final category = reservation.category;
    final statusColor = _getStudentStatusColor(status);
    final statusText = _getStudentStatusText(status);
    
    return GestureDetector(
      onTap: () => _showStudentReservationDetails(reservation),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sol taraf - Avatar ve durum
              Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: teacher?.user?.profilePhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              teacher!.user!.profilePhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    teacher!.user!.name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              (teacher?.user?.name.substring(0, 1).toUpperCase()) ?? '?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Orta kısım - Rezervasyon bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher?.user?.name ?? 'Bilinmeyen Eğitimci',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category?.name ?? 'Genel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppTheme.grey600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(reservation.proposedDatetime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppTheme.grey600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(reservation.proposedDatetime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Sağ taraf - Ok işareti
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: statusColor,
                ),
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
            'Ders rezervasyonlarınız yükleniyor...',
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
    // Check if error is authentication related
    final isAuthError = _error?.contains('401') == true || 
                       _error?.contains('Unauthenticated') == true ||
                       _error?.contains('Unauthorized') == true;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAuthError ? Icons.lock_outline : Icons.error_outline,
            size: 64,
            color: isAuthError ? Colors.orange[400] : Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            isAuthError ? 'Oturum Süresi Doldu' : 'Bir hata oluştu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isAuthError ? Colors.orange[400] : Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAuthError 
              ? 'Güvenlik nedeniyle oturumunuz sonlandırıldı.\nLütfen tekrar giriş yapın.'
              : 'Rezervasyonlar yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isAuthError) ...[
                ElevatedButton(
                  onPressed: () {
                    // Navigate to login screen
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
                onPressed: _refreshData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(isAuthError ? 'Tekrar Dene' : 'Tekrar Dene'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz ders rezervasyonunuz yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk dersinizi almak için bir eğitimci bulun',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EnhancedTeachersScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Eğitimci Bul'),
          ),
        ],
      ),
    );
  }


  String _getStudentStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'accepted':
        return 'Onaylı';
      case 'rejected':
        return 'Reddedildi';
      case 'cancelled':
        return 'İptal Edildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return 'Bilinmiyor';
    }
  }

  void _showStudentReservationDetails(Reservation reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
                'Ders Rezervasyon Detayları',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStudentDetailRow('Eğitimci', reservation.teacher?.user?.name ?? "Bilinmiyor"),
                    _buildStudentDetailRow('Ders Konusu', reservation.subject),
                    _buildStudentDetailRow('Tarih', DateFormat('dd MMM yyyy').format(reservation.proposedDatetime)),
                    _buildStudentDetailRow('Saat', '${DateFormat('HH:mm').format(reservation.proposedDatetime)} - ${DateFormat('HH:mm').format(reservation.proposedDatetime.add(Duration(minutes: reservation.durationMinutes ?? 60)))}'),
                    _buildStudentDetailRow('Durum', _getStudentStatusText(reservation.status)),
                    _buildStudentDetailRow('Fiyat', '₺${reservation.price.toInt()}'),
                    if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Notlar:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(reservation.notes!),
                      ),
                    ],
                    if (reservation.teacherNotes != null && reservation.teacherNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Eğitimci Notları:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(reservation.teacherNotes!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.grey600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStudentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.accentOrange;
      case 'accepted':
        return AppTheme.primaryBlue;
      case 'rejected':
        return Colors.red[600] ?? Colors.red;
      case 'cancelled':
        return AppTheme.grey600;
      case 'completed':
        return AppTheme.accentGreen;
      default:
        return AppTheme.grey600;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
