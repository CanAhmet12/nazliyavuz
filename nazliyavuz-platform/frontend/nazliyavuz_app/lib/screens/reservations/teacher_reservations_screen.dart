import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TeacherReservationsScreen extends StatefulWidget {
  const TeacherReservationsScreen({super.key});

  @override
  State<TeacherReservationsScreen> createState() => _TeacherReservationsScreenState();
}

class _TeacherReservationsScreenState extends State<TeacherReservationsScreen>
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
  // _isLoadingMore removed to prevent duplicate data issues
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
    print('🔍 [TEACHER_RESERVATIONS] Scroll listener disabled');
  }

  void _onTabChanged() {
    // Tab change handled by _getFilteredReservations() method
    // No need for setState here to prevent infinite loops
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadTeacherReservations(),
        _loadTeacherStatistics(),
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

  Future<void> _loadTeacherReservations() async {
    try {
      final reservations = await _apiService.getTeacherReservations();

      if (mounted) {
        // Clear existing data first to prevent duplicates
        _reservations.clear();
        
        setState(() {
          _reservations = List.from(reservations); // Create new list instance
          _isLoading = false;
          // _isLoadingMore removed
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          // _isLoadingMore removed
        });
      }
    }
  }

  Future<void> _loadTeacherStatistics() async {
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
                _buildTeacherHeroAppBar(),
                
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildTeacherStatisticsSection(),
                    ),
                  ),
                
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildTeacherTabBarSection(),
                  ),
                ),
              ],
              body: _buildTeacherReservationsList(),
            ),
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildTeacherFloatingActionButton(),
      ),
    );
  }

  Widget _buildTeacherHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 140, // Biraz daha yüksek yaptım
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
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), // Padding'i artırdım
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12), // Padding'i artırdım
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16), // Radius'u artırdım
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.schedule_rounded, // İkonu değiştirdim
                          color: Colors.white,
                          size: 28, // Boyutu artırdım
                        ),
                      ),
                      const SizedBox(width: 16), // Boşluğu artırdım
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ders Takvimim',
                              style: TextStyle(
                                fontSize: 26, // Font boyutunu artırdım
                                fontWeight: FontWeight.w800, // Font weight'i artırdım
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6), // Boşluğu artırdım
                            Text(
                              '${_reservations.length} ders randevusu',
                              style: const TextStyle(
                                fontSize: 15, // Font boyutunu artırdım
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
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

  Widget _buildTeacherStatisticsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Margin'i düzenledim
      child: Row(
        children: [
          Expanded(
            child: _buildTeacherStatCard(
              'Toplam Ders',
              '${_reservations.length}',
              Icons.school_rounded,
              AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTeacherStatCard(
              'Bekleyen',
              '${_reservations.where((r) => r.status == 'pending').length}',
              Icons.schedule_rounded,
              AppTheme.accentOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTeacherStatCard(
              'Bu Ay Kazanç',
              '₺${_calculateMonthlyEarnings()}',
              Icons.attach_money_rounded,
              AppTheme.premiumGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20), // Padding'i artırdım
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Radius'u artırdım
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // Padding'i artırdım
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12), // Radius'u artırdım
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 24), // İkon boyutunu artırdım
          ),
          const SizedBox(height: 12), // Boşluğu artırdım
          Text(
            value,
            style: TextStyle(
              fontSize: 22, // Font boyutunu artırdım
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6), // Boşluğu artırdım
          Text(
            title,
            style: const TextStyle(
              fontSize: 13, // Font boyutunu artırdım
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

  Widget _buildTeacherTabBarSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Margin'i düzenledim
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTeacherFilterChip('Tümü', ''),
            const SizedBox(width: 12), // Boşluğu artırdım
            _buildTeacherFilterChip('Bekleyen', 'pending'),
            const SizedBox(width: 12),
            _buildTeacherFilterChip('Onaylı', 'accepted'),
            const SizedBox(width: 12),
            _buildTeacherFilterChip('Tamamlanan', 'completed'),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherFilterChip(String label, String status) {
    final isSelected = _statusTabs[_tabController.index]['value'] == status;
    final color = _statusTabs.firstWhere((tab) => tab['value'] == status)['color'] as Color;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.index = _statusTabs.indexWhere((tab) => tab['value'] == status);
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : AppTheme.grey300,
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.grey600,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherReservationsList() {
    if (_isLoading) {
      return _buildTeacherLoadingState();
    }

    if (_error != null) {
      return _buildTeacherErrorState();
    }

    final filteredReservations = _getFilteredReservations();

    if (filteredReservations.isEmpty) {
      return _buildTeacherEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReservations.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildTeacherReservationCard(filteredReservations[index]),
        );
      },
    );
  }

  Widget _buildTeacherReservationCard(Reservation reservation) {
    final status = reservation.status;
    final student = reservation.student;
    final category = reservation.category;
    
    return GestureDetector(
      onTap: () => _showTeacherReservationDetails(reservation),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20), // Padding'i artırdım
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Radius'u artırdım
          border: Border.all(
            color: _getTeacherStatusColor(status).withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getTeacherStatusColor(status).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                        color: _getTeacherStatusColor(status).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: _getTeacherStatusColor(status).withOpacity(0.1),
                    backgroundImage: student?.profilePhotoUrl != null
                        ? NetworkImage(student!.profilePhotoUrl!)
                        : null,
                    child: student?.profilePhotoUrl == null
                        ? Text(
                            (student?.name.substring(0, 1).toUpperCase()) ?? '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getTeacherStatusColor(status),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student?.name ?? 'Bilinmeyen Öğrenci',
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getTeacherStatusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getTeacherStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getTeacherStatusColor(status).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _getTeacherStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getTeacherStatusColor(status),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.premiumGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.premiumGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_money_rounded,
                        size: 14,
                        color: AppTheme.premiumGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₺${reservation.price.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.premiumGold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reservation.status == 'pending') ...[
                  const SizedBox(width: 8),
                  _buildTeacherActionButton(
                    'Onayla',
                    AppTheme.accentGreen,
                    () => _updateReservationStatus(reservation, 'accepted'),
                  ),
                  const SizedBox(width: 4),
                  _buildTeacherActionButton(
                    'Reddet',
                    AppTheme.accentRed,
                    () => _updateReservationStatus(reservation, 'rejected'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherActionButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showTeacherAvailabilityDialog();
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Radius'u artırdım
        ),
        icon: const Icon(Icons.schedule_rounded, size: 20),
        label: const Text(
          'Müsaitlik Ayarla',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15, // Font boyutunu artırdım
            letterSpacing: 0.3,
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
            'Ders randevularınız yükleniyor...',
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
            onPressed: _refreshData,
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

  Widget _buildTeacherEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz ders randevunuz yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Öğrenciler sizinle ders randevusu alabilir',
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
              _showTeacherAvailabilityDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.schedule_rounded),
            label: const Text('Müsaitlik Ayarla'),
          ),
        ],
      ),
    );
  }

  Color _getTeacherStatusColor(String status) {
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
        return AppTheme.accentGreen;
      default:
        return Colors.grey;
    }
  }

  String _getTeacherStatusText(String status) {
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

  int _calculateMonthlyEarnings() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    
    return _reservations
        .where((r) => r.status == 'completed' && 
                     r.proposedDatetime.isAfter(thisMonth) && 
                     r.proposedDatetime.isBefore(nextMonth))
        .fold(0, (sum, r) => sum + r.price.toInt());
  }

  Future<void> _updateReservationStatus(Reservation reservation, String status) async {
    try {
      await _apiService.updateReservationStatus(reservation.id, status);
      
      setState(() {
        final index = _reservations.indexWhere((r) => r.id == reservation.id);
        if (index != -1) {
          _reservations[index] = reservation.copyWith(status: status);
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rezervasyon ${status == 'accepted' ? 'onaylandı' : 'reddedildi'}'),
          backgroundColor: status == 'accepted' ? AppTheme.accentGreen : AppTheme.accentRed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  void _showTeacherAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Müsaitlik Ayarları'),
        content: const Text('Müsaitlik ayarları sayfası yakında eklenecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showTeacherReservationDetails(Reservation reservation) {
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
                'Ders Randevu Detayları',
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
                    _buildTeacherDetailRow('Öğrenci', reservation.student?.name ?? "Bilinmiyor"),
                    _buildTeacherDetailRow('Ders Konusu', reservation.subject),
                    _buildTeacherDetailRow('Tarih', DateFormat('dd MMM yyyy').format(reservation.proposedDatetime)),
                    _buildTeacherDetailRow('Saat', '${DateFormat('HH:mm').format(reservation.proposedDatetime)} - ${DateFormat('HH:mm').format(reservation.proposedDatetime.add(Duration(minutes: reservation.durationMinutes ?? 60)))}'),
                    _buildTeacherDetailRow('Durum', _getTeacherStatusText(reservation.status)),
                    _buildTeacherDetailRow('Fiyat', '₺${reservation.price.toInt()}'),
                    if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Öğrenci Notları:',
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
                          color: AppTheme.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(reservation.teacherNotes!),
                      ),
                    ],
                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _updateReservationStatus(reservation, 'accepted');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Onayla'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _updateReservationStatus(reservation, 'rejected');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentRed,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reddet'),
                            ),
                          ),
                        ],
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

  Widget _buildTeacherDetailRow(String label, String value) {
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

