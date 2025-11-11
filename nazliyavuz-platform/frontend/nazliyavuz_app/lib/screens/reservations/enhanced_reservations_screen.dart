import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/reservation.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../teachers/enhanced_teachers_screen.dart';

class EnhancedReservationsScreen extends StatefulWidget {
  const EnhancedReservationsScreen({super.key});

  @override
  State<EnhancedReservationsScreen> createState() => _EnhancedReservationsScreenState();
}

class _EnhancedReservationsScreenState extends State<EnhancedReservationsScreen>
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
    {'value': 'confirmed', 'label': 'Onaylı', 'icon': Icons.check_circle_rounded, 'color': AppTheme.accentGreen},
    {'value': 'completed', 'label': 'Tamamlanan', 'icon': Icons.done_all_rounded, 'color': AppTheme.primaryBlue},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    print('🔍 [ENHANCED_RESERVATIONS] initState - Starting data load');
    _setupScrollListener();
    
    // Start data loading after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
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
    print('🔍 [ENHANCED_RESERVATIONS] Scroll listener disabled');
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
      // Don't reload data on tab change - just filter existing data
    }
  }

  Future<void> _loadInitialData() async {
    print('🔍 [ENHANCED_RESERVATIONS] _loadInitialData called');
    
    // Prevent duplicate calls only if already loading
    if (_isLoading) {
      print('🔍 [ENHANCED_RESERVATIONS] Already loading, skipping call');
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load both data sources
      await Future.wait([
        _loadReservations(),
        _loadStatistics(),
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

  Future<void> _loadReservations() async {
    print('🔍 [ENHANCED_RESERVATIONS] _loadReservations called');
    
    try {
      final selectedStatus = _statusTabs[_tabController.index]['value'] as String;
      final reservations = await _apiService.getReservations(
        status: selectedStatus.isNotEmpty ? selectedStatus : null,
      );

      print('🔍 [ENHANCED_RESERVATIONS] API returned ${reservations.length} reservations');

      if (mounted) {
        // Clear existing data first to prevent duplicates
        _reservations.clear();
        
        setState(() {
          _reservations = List.from(reservations); // Create new list instance
          _isLoading = false;
          _isLoadingMore = false;
        });
        
        print('🔍 [ENHANCED_RESERVATIONS] State updated with ${_reservations.length} reservations');
      }
    } catch (e) {
      print('🔍 [ENHANCED_RESERVATIONS] Error loading reservations: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
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


  Future<void> _refreshData() async {
    print('🔍 [ENHANCED_RESERVATIONS] _refreshData called - MANUAL REFRESH ONLY');
    // Clear existing data first
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
                // Modern Hero App Bar
                _buildModernHeroAppBar(),
                
                // Statistics Cards
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildStatisticsSection(),
                    ),
                  ),
                
                // Tab Bar
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildTabBarSection(),
                  ),
                ),
              ],
              body: _buildReservationsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF3B82F6), // AppTheme.primaryBlue
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B82F6), // AppTheme.primaryBlue
                Color(0xFF8B5CF6), // AppTheme.accentPurple
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
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
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF3B82F6),
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
                        'Merhaba Eğitimci,',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        'Randevu Yönetimi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
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



  Widget _buildStatisticsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Randevu İstatistikleri',
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
                    'Toplam Randevu',
                    _reservations.length.toString(),
                    Icons.calendar_today_rounded,
                    const Color(0xFF3B82F6),
                    'Bu dönem',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: _buildModernStatCard(
                    'Bekleyen',
                    _reservations.where((r) => r.status == 'pending').length.toString(),
                    Icons.pending_rounded,
                    const Color(0xFFF59E0B),
                    'Onay bekliyor',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: _buildModernStatCard(
                    'Onaylı',
                    _reservations.where((r) => r.status == 'confirmed').length.toString(),
                    Icons.check_circle_rounded,
                    const Color(0xFF10B981),
                    'Bu dönem',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            color: color.withOpacity(0.08),
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
              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildTabBarSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrele',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusTabs.length,
              itemBuilder: (context, index) {
                final tab = _statusTabs[index];
                final isSelected = _tabController.index == index;
                
                return Container(
                  margin: EdgeInsets.only(
                    right: index < _statusTabs.length - 1 ? 8 : 0,
                  ),
                  child: FilterChip(
                    label: Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : tab['color'],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _tabController.index = index;
                      });
                      HapticFeedback.lightImpact();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: tab['color'] as Color,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? tab['color'] as Color : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildReservationsList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final filteredReservations = _getFilteredReservations();

    if (filteredReservations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReservations.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < filteredReservations.length) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _buildReservationCard(filteredReservations[index]),
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

  Widget _buildReservationCard(Reservation reservation) {
    final status = reservation.status;
    final student = reservation.student;
    final category = reservation.category;
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusInfo['color'].withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showReservationDetails(reservation),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusInfo['icon'] as IconData,
                        color: statusInfo['color'],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student?.name ?? 'Bilinmeyen Öğrenci',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category?.name ?? 'Kategori',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusInfo['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusInfo['color'],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tarih: ${DateFormat('dd/MM/yyyy HH:mm').format(reservation.proposedDatetime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'Bekleyen',
          'color': const Color(0xFF3B82F6),
          'icon': Icons.pending_rounded,
        };
      case 'confirmed':
        return {
          'label': 'Onaylı',
          'color': const Color(0xFF10B981),
          'icon': Icons.check_circle_rounded,
        };
      case 'completed':
        return {
          'label': 'Tamamlanan',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.done_all_rounded,
        };
      default:
        return {
          'label': 'Bilinmiyor',
          'color': Colors.grey,
          'icon': Icons.help_rounded,
        };
    }
  }



  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Rezervasyonlar yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Rezervasyon bulunmuyor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk rezervasyonunuzu oluşturmak için bir eğitimci bulun',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to teachers screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Eğitimci Bul'),
          ),
        ],
      ),
    );
  }



  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'accepted':
        return 'Kabul Edildi';
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

  void _showReservationDetails(Reservation reservation) {
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
                'Rezervasyon Detayları',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            // Add reservation details here
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eğitimci: ${reservation.teacher?.user?.name ?? "Bilinmiyor"}'),
                    Text('Ders: ${reservation.subject}'),
                    Text('Tarih: ${DateFormat('dd MMM yyyy').format(reservation.proposedDatetime)}'),
                    Text('Saat: ${DateFormat('HH:mm').format(reservation.proposedDatetime)} - ${DateFormat('HH:mm').format(reservation.proposedDatetime.add(Duration(minutes: reservation.durationMinutes ?? 60)))}'),
                    Text('Durum: ${_getStatusText(reservation.status)}'),
                    Text('Fiyat: ₺${(reservation.price).toInt()}'),
                    if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Notlar:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(reservation.notes!),
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

}