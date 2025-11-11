import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'assignment_detail_screen.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Assignment> _assignments = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  String? _error;
  
  final List<Map<String, dynamic>> _statusTabs = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'pending', 'label': 'Bekleyen', 'icon': Icons.pending_rounded, 'color': AppTheme.accentOrange},
    {'value': 'submitted', 'label': 'Gönderilen', 'icon': Icons.upload_rounded, 'color': AppTheme.accentGreen},
    {'value': 'graded', 'label': 'Notlanan', 'icon': Icons.grade_rounded, 'color': AppTheme.primaryBlue},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInitialData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _onTabChanged() {
    setState(() {
      // Trigger rebuild when tab changes to update filtered list
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadStudentAssignments(),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadStudentAssignments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Force token loading from SharedPreferences
      await _apiService.loadTokenFromStorage();
      
      // Check authentication after loading token
      if (!_apiService.isAuthenticated) {
        setState(() {
          _error = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.get('/assignments/student');
      if (mounted) {
        setState(() {
          try {
            // Handle different response structures
            List<dynamic> assignmentsData = [];
            if (response['success'] == true && response['assignments'] != null) {
              assignmentsData = response['assignments'] as List;
            } else if (response['data'] != null) {
              assignmentsData = response['data'] as List;
            } else if (response is List) {
              assignmentsData = response as List;
            }
            
            _assignments = assignmentsData
                .where((json) => json != null && json is Map<String, dynamic>)
                .map((json) {
                  try {
                    return Assignment.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    print('Assignment parsing error: $e');
                    print('JSON: $json');
                    return null;
                  }
                })
                .where((assignment) => assignment != null)
                .cast<Assignment>()
                .toList();
            _isLoading = false;
          } catch (e) {
            print('Assignments processing error: $e');
            _assignments = [];
            _isLoading = false;
            _error = 'Ödevler yüklenirken hata oluştu: $e';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        
        // Check if it's an authentication error
        if (e.toString().contains('401') || 
            e.toString().contains('Unauthenticated') ||
            e.toString().contains('Unauthorized')) {
          // Navigate to login screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
        }
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final response = await _apiService.get('/assignments/student/statistics');
      if (response['success'] == true && mounted) {
        setState(() {
          _statistics = response['statistics'] ?? {};
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Statistics loading error: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  List<Assignment> _getFilteredAssignments() {
    final selectedStatus = _statusTabs[_tabController.index]['value'] as String;
    if (selectedStatus.isEmpty) {
      return _assignments;
    }
    return _assignments.where((a) => a.status == selectedStatus).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              if (_isLoading) _buildLoadingState(),
              if (!_isLoading && _error != null) _buildErrorState(),
              if (!_isLoading && _error == null) _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80, // 100 -> 80 daha kompakt
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
                const Color(0xFF3B82F6), // AppTheme.primaryBlue
                const Color(0xFF8B5CF6), // AppTheme.accentPurple
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Ödevlerim Icon
                  Container(
                    width: 36, // 40 -> 36 daha küçük
                    height: 36, // 40 -> 36 daha küçük
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18), // 20 -> 18
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFF3B82F6),
                      size: 18, // 20 -> 18 daha küçük
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
                          'Ödevlerim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18, // 20 -> 18 daha küçük
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Ödevleriniz ve durumları',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12, // 14 -> 12 daha küçük
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // View Toggle Button
                  Container(
                    width: 32, // 36 -> 32 daha küçük
                    height: 32, // 36 -> 32 daha küçük
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.view_list_rounded,
                        color: Colors.white,
                        size: 16, // 18 -> 16 daha küçük
                      ),
                      onPressed: () {
                        // Toggle view logic can be added here
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Ödevler yüklenirken hata oluştu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ödevler yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filteredAssignments = _getFilteredAssignments();
    
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildStatistics(),
          _buildStatusTabs(),
          _buildAssignmentsList(filteredAssignments),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final completionRate = _statistics['completion_rate']?.toString() ?? '0';
    final averageGrade = _statistics['average_grade_letter']?.toString() ?? '-';
    final overdue = _statistics['overdue']?.toString() ?? '0';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 16 -> 12 daha kompakt
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödev İstatistikleri',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontSize: 16, // 18 -> 16 daha küçük
            ),
          ),
          const SizedBox(height: 12),
          // Ana istatistik kartları (Grid)
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Ortalama Not',
                  averageGrade,
                  Icons.star_rounded,
                  const Color(0xFF3B82F6), // AppTheme.primaryBlue
                ),
              ),
              const SizedBox(width: 8), // 12 -> 8 daha kompakt
              Expanded(
                child: _buildModernStatCard(
                  'Tamamlanma',
                  '${completionRate}%',
                  Icons.check_circle_rounded,
                  const Color(0xFF10B981), // AppTheme.accentGreen
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // 12 -> 8 daha kompakt
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Bekleyen',
                  '${_statistics['pending']?.toString() ?? '0'}',
                  Icons.hourglass_empty_rounded,
                  const Color(0xFFF59E0B), // AppTheme.accentOrange
                ),
              ),
              const SizedBox(width: 8), // 12 -> 8 daha kompakt
              Expanded(
                child: _buildModernStatCard(
                  'Gecikmiş',
                  '${overdue}',
                  Icons.warning_rounded,
                  const Color(0xFFEF4444), // AppTheme.accentRed
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 16 -> 12 daha küçük
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8, // 12 -> 8 daha küçük
            offset: const Offset(0, 2), // 4 -> 2 daha küçük
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // 16 -> 12 daha kompakt
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24), // 32 -> 24 daha küçük, white -> color
            const SizedBox(height: 6), // 8 -> 6 daha küçük
            Text(
              value,
              style: TextStyle(
                fontSize: 20, // 24 -> 20 daha küçük
                fontWeight: FontWeight.w800,
                color: color, // white -> color
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, // 12 -> 11 daha küçük
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B), // white.withOpacity(0.9) -> Color(0xFF64748B)
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 16 -> 12 daha kompakt
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödev Durumları',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontSize: 16, // 18 -> 16 daha küçük
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusTabs.map((tab) {
                final isSelected = _tabController.index == _statusTabs.indexOf(tab);
                return Container(
                  margin: const EdgeInsets.only(right: 8), // 12 -> 8 daha kompakt
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      final index = _statusTabs.indexOf(tab);
                      _tabController.animateTo(index);
                    },
                    label: Text(
                      tab['label'],
                      style: TextStyle(
                        fontSize: 12, // 14 -> 12 daha küçük
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : tab['color'],
                      ),
                    ),
                    avatar: Icon(
                      tab['icon'],
                      size: 16, // 18 -> 16 daha küçük
                      color: isSelected ? Colors.white : tab['color'],
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: tab['color'],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: tab['color'].withOpacity(0.3),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // 24 -> 20 daha küçük
                    ),
                    elevation: isSelected ? 2 : 0,
                    shadowColor: tab['color'].withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList(List<Assignment> assignments) {
    if (assignments.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz ödev yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Öğretmeniniz size ödev verdiğinde burada görünecek',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return _buildAssignmentCard(assignment);
        },
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final dueDate = assignment.dueDate;
    final safeStatus = assignment.status.isNotEmpty ? assignment.status : 'pending';
    final isOverdue = dueDate.isBefore(DateTime.now()) && safeStatus == 'pending';
    final statusInfo = _getStatusInfo(safeStatus, isOverdue);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 16 -> 12, bottom: 16 -> vertical: 6 daha kompakt
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 16 -> 12 daha küçük
        border: Border.all(
          color: statusInfo['color'].withOpacity(0.15), // 0.2 -> 0.15 daha hafif
          width: 1, // 1.5 -> 1 daha ince
        ),
        boxShadow: [
          BoxShadow(
            color: statusInfo['color'].withOpacity(0.08), // 0.1 -> 0.08 daha hafif
            blurRadius: 8, // 12 -> 8 daha küçük
            offset: const Offset(0, 2), // 4 -> 2 daha küçük
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03), // 0.05 -> 0.03 daha hafif
            blurRadius: 6, // 8 -> 6 daha küçük
            offset: const Offset(0, 1), // 2 -> 1 daha küçük
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignmentDetailScreen(assignment: assignment),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12), // 16 -> 12 daha kompakt
            child: Row(
              children: [
                // Sol taraf - Avatar ve durum
                Column(
                  children: [
                    Container(
                      width: 40, // 50 -> 40 daha küçük
                      height: 40, // 50 -> 40 daha küçük
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10), // 12 -> 10 daha küçük
                        border: Border.all(
                          color: statusInfo['color'].withOpacity(0.2), // 0.3 -> 0.2 daha hafif
                          width: 1, // 2 -> 1 daha ince
                        ),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        size: 20, // 24 -> 20 daha küçük
                        color: statusInfo['color'],
                      ),
                    ),
                    const SizedBox(height: 6), // 8 -> 6 daha küçük
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // 8,4 -> 6,3 daha küçük
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6), // 8 -> 6 daha küçük
                      ),
                      child: Text(
                        statusInfo['label'] ?? 'Bilinmiyor',
                        style: TextStyle(
                          fontSize: 9, // 10 -> 9 daha küçük
                          fontWeight: FontWeight.w600,
                          color: statusInfo['color'],
                        ),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(width: 12), // 16 -> 12 daha kompakt
              
              // Orta kısım - Ödev bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (assignment.title.isNotEmpty) ? assignment.title : 'Başlık Yok',
                      style: const TextStyle(
                        fontSize: 14, // 16 -> 14 daha küçük
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B), // 0xFF0F172A -> 0xFF1E293B daha yumuşak
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 8,3 -> 6,2 daha küçük
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1), // AppTheme.accentPurple -> Color(0xFF8B5CF6)
                        borderRadius: BorderRadius.circular(4), // 6 -> 4 daha küçük
                      ),
                      child: Text(
                        _getDifficultyText(assignment.difficulty.isNotEmpty ? assignment.difficulty : 'medium'),
                        style: const TextStyle(
                          fontSize: 10, // 11 -> 10 daha küçük
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B5CF6), // AppTheme.accentPurple -> Color(0xFF8B5CF6)
                        ),
                      ),
                    ),
                    const SizedBox(height: 6), // 8 -> 6 daha küçük
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12, // 14 -> 12 daha küçük
                          color: const Color(0xFF64748B), // AppTheme.grey600 -> Color(0xFF64748B)
                        ),
                        const SizedBox(width: 4), // 6 -> 4 daha kompakt
                        Text(
                          _formatDate(assignment.dueDate),
                          style: const TextStyle(
                            fontSize: 11, // 12 -> 11 daha küçük
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B), // AppTheme.grey600 -> Color(0xFF64748B)
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3), // 4 -> 3 daha küçük
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12, // 14 -> 12 daha küçük
                          color: const Color(0xFF64748B), // AppTheme.grey600 -> Color(0xFF64748B)
                        ),
                        const SizedBox(width: 4), // 6 -> 4 daha kompakt
                        Text(
                          _formatTime(assignment.dueDate),
                          style: const TextStyle(
                            fontSize: 11, // 12 -> 11 daha küçük
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B), // AppTheme.grey600 -> Color(0xFF64748B)
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Sağ taraf - Ok işareti
              Container(
                width: 28, // 32 -> 28 daha küçük
                height: 28, // 32 -> 28 daha küçük
                decoration: BoxDecoration(
                  color: statusInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // 8 -> 6 daha küçük
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14, // 16 -> 14 daha küçük
                  color: statusInfo['color'],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status, bool isOverdue) {
    // Null safety koruması
    final safeStatus = status.isNotEmpty ? status : 'pending';
    
    if (safeStatus == 'pending' && isOverdue) {
      return {
        'label': 'Süresi Geçmiş',
        'icon': Icons.warning_rounded,
        'color': const Color(0xFFEF5350),
      };
    }
    
    switch (safeStatus) {
      case 'pending':
        return {
          'label': 'Bekleyen',
          'icon': Icons.hourglass_empty_rounded,
          'color': const Color(0xFF42A5F5),
        };
      case 'submitted':
        return {
          'label': 'Teslim Edildi',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF66BB6A),
        };
      case 'graded':
        return {
          'label': 'Notlandı',
          'icon': Icons.grade_rounded,
          'color': const Color(0xFFFFA726),
        };
      default:
        return {
          'label': status,
          'icon': Icons.help_rounded,
          'color': Colors.grey,
        };
    }
  }




  String _getDifficultyText(String difficulty) {
    if (difficulty.isEmpty) return 'Bilinmiyor';
    
    try {
      switch (difficulty.toLowerCase()) {
        case 'easy':
          return 'Kolay';
        case 'medium':
          return 'Orta';
        case 'hard':
          return 'Zor';
        default:
          return 'Bilinmiyor';
      }
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'Bugün';
    } else if (difference.inDays == 1) {
      return 'Yarın';
    } else if (difference.inDays == -1) {
      return 'Dün';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün sonra';
    } else {
      return '${-difference.inDays} gün önce';
    }
  }

  String _formatTime(DateTime date) {
    final formatter = DateFormat('HH:mm');
    return formatter.format(date);
  }

}