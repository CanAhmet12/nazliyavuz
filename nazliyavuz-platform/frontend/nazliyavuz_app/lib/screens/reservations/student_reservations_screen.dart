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
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildStudentFloatingActionButton(),
      ),
    );
  }

  Widget _buildStudentHeroAppBar() {
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ders Rezervasyonlarım',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_reservations.length} ders rezervasyonu',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          onPressed: _refreshData,
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

  Widget _buildStudentStatisticsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
          
          // Büyük ekranlarda horizontal layout
          return Row(
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
              const SizedBox(width: 12),
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
          );
        },
      ),
    );
  }

  Widget _buildStudentStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 120, // Sabit yükseklik ekle
      padding: const EdgeInsets.all(18),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.all(16),
      itemCount: filteredReservations.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < filteredReservations.length) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
    
    return GestureDetector(
      onTap: () => _showStudentReservationDetails(reservation),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStudentStatusColor(status).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getStudentStatusColor(status).withOpacity(0.1),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getStudentStatusColor(status).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: _getStudentStatusColor(status).withOpacity(0.1),
                    backgroundImage: teacher?.user?.profilePhotoUrl != null
                        ? NetworkImage(teacher!.user!.profilePhotoUrl!)
                        : null,
                    child: teacher?.user?.profilePhotoUrl == null
                        ? Text(
                            (teacher?.user?.name.substring(0, 1).toUpperCase()) ?? '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStudentStatusColor(status),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?.user?.name ?? 'Bilinmeyen Öğretmen',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category != null)
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStudentStatusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStudentStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStudentStatusColor(status).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _getStudentStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getStudentStatusColor(status),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reservation.subject,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.grey800,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.grey600.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.grey600.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppTheme.grey600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${reservation.proposedDatetime.day}/${reservation.proposedDatetime.month} ${reservation.proposedDatetime.hour}:${reservation.proposedDatetime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981), // Daha belirgin yeşil
                        const Color(0xFF059669),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_money_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₺${reservation.price.toInt()}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EnhancedTeachersScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Daha küçük border radius
        ),
        icon: const Icon(Icons.add_rounded, size: 18), // Daha küçük ikon
        label: const Text(
          'Yeni Ders Rezervasyonu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13, // Daha küçük font
          ),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Daha küçük padding
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
            onPressed: _refreshData,
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
            'İlk dersinizi almak için bir öğretmen bulun',
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
            label: const Text('Öğretmen Bul'),
          ),
        ],
      ),
    );
  }

  Color _getStudentStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'completed':
        return AppTheme.primaryBlue;
      default:
        return Colors.grey;
    }
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
                    _buildStudentDetailRow('Öğretmen', reservation.teacher?.user?.name ?? "Bilinmiyor"),
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
                        'Öğretmen Notları:',
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
}
