import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../../models/assignment.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'create_assignment_screen.dart';
import 'teacher_assignment_detail_screen.dart';

class EnhancedTeacherAssignmentsScreen extends StatefulWidget {
  const EnhancedTeacherAssignmentsScreen({super.key});

  @override
  State<EnhancedTeacherAssignmentsScreen> createState() => _EnhancedTeacherAssignmentsScreenState();
}

class _EnhancedTeacherAssignmentsScreenState extends State<EnhancedTeacherAssignmentsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  List<Assignment> _assignments = [];
  List<User> _students = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  // _isLoadingMore removed to prevent duplicate data issues
  String? _error;
  
  // Pagination removed to prevent duplicate data loading

  final List<Map<String, dynamic>> _statusTabs = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'pending', 'label': 'Atanan', 'icon': Icons.assignment_rounded, 'color': AppTheme.accentOrange},
    {'value': 'submitted', 'label': 'Değerlendirilecek', 'icon': Icons.grade_rounded, 'color': AppTheme.accentGreen},
    {'value': 'graded', 'label': 'Değerlendirilen', 'icon': Icons.check_circle_rounded, 'color': AppTheme.accentPurple},
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
    print('🔍 [TEACHER_ASSIGNMENTS] Scroll listener disabled');
  }

  void _onTabChanged() {
    // Tab change handled by _getFilteredAssignments() method
    // No need for setState here to prevent infinite loops
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadTeacherAssignments(),
        _loadStudents(),
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

  Future<void> _loadTeacherAssignments() async {
    try {
      final response = await _apiService.getTeacherAssignments();
      final assignments = (response['assignments'] as List)
          .map((json) => Assignment.fromJson(json))
          .toList();

      if (mounted) {
        // Clear existing data first to prevent duplicates
        _assignments.clear();
        
        setState(() {
          _assignments = List.from(assignments); // Create new list instance
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

  Future<void> _loadStudents() async {
    try {
      final students = await _apiService.getTeacherStudents();
      if (mounted) {
        setState(() {
          _students = students;
        });
      }
    } catch (e) {
      // Students loading error: $e
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Mock statistics for now
      if (mounted) {
        setState(() {
          _statistics = {
            'total_assignments': _assignments.length,
            'pending_assignments': _assignments.where((a) => a.status == 'pending').length,
            'submitted_assignments': _assignments.where((a) => a.status == 'submitted').length,
            'graded_assignments': _assignments.where((a) => a.status == 'graded').length,
          };
        });
      }
    } catch (e) {
      // Statistics loading error: $e
    }
  }

  // Load more method removed to prevent duplicate data issues

  Future<void> _refreshData() async {
    setState(() {
      _assignments.clear();
      _isLoading = true;
      _error = null;
    });
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
                _buildHeroAppBar(),
                
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildStatisticsSection(),
                    ),
                  ),
                
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildTabBarSection(),
                  ),
                ),
              ],
              body: _buildAssignmentsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
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
                AppTheme.accentPurple,
                AppTheme.primaryBlue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPurple.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                          Icons.task_alt_rounded,
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
                              'Ödev Yönetimi',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '${_assignments.length} ödev atandı',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sadece + butonu
                      Row(
                        children: [
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
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CreateAssignmentScreen(),
                                  ),
                                ).then((_) => _refreshData());
                              },
                              tooltip: 'Yeni Ödev Oluştur',
                            ),
                          ),
                        ],
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

  Widget _buildStatisticsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // First row - 2 cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Ödev',
                  '${_statistics['total_assignments'] ?? 0}',
                  Icons.assignment_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Atanan',
                  '${_statistics['pending_assignments'] ?? 0}',
                  Icons.assignment_rounded,
                  AppTheme.accentOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row - 2 cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Değerlendirilecek',
                  '${_statistics['submitted_assignments'] ?? 0}',
                  Icons.grade_rounded,
                  AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Değerlendirilen',
                  '${_statistics['graded_assignments'] ?? 0}',
                  Icons.check_circle_rounded,
                  AppTheme.accentPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
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

  Widget _buildTabBarSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Tümü', ''),
            const SizedBox(width: 12),
            _buildFilterChip('Atanan', 'pending'),
            const SizedBox(width: 12),
            _buildFilterChip('Değerlendirilecek', 'submitted'),
            const SizedBox(width: 12),
            _buildFilterChip('Değerlendirilen', 'graded'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
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

  Widget _buildAssignmentsList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final filteredAssignments = _getFilteredAssignments();

    if (filteredAssignments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAssignments.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildAssignmentCard(filteredAssignments[index]),
        );
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final status = assignment.status;
    final student = _students.firstWhere(
      (s) => s.id == assignment.studentId,
      orElse: () => User(id: assignment.studentId ?? 0, name: 'Bilinmeyen Öğrenci', email: '', role: 'student'),
    );
    
    return GestureDetector(
      onTap: () => _showAssignmentDetails(assignment),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor(status).withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getStatusColor(status).withOpacity(0.08),
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
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: _getStatusColor(status).withOpacity(0.1),
                    backgroundImage: student.profilePhotoUrl != null
                        ? NetworkImage(student.profilePhotoUrl!)
                        : null,
                    child: student.profilePhotoUrl == null
                        ? Text(
                            student.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(status),
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
                        student.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Sınıf: ${assignment.difficulty}',
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
                    color: _getStatusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(status),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              assignment.title,
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
                        _formatDueDate(assignment.dueDate),
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
                if (assignment.grade != null && assignment.grade!.isNotEmpty) ...[
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
                          Icons.grade_rounded,
                          size: 14,
                          color: AppTheme.premiumGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${assignment.grade}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.premiumGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (status == 'submitted') ...[
                  const SizedBox(width: 8),
                  _buildActionButton(
                    'Değerlendir',
                    AppTheme.accentGreen,
                    () => _gradeAssignment(assignment),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
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


  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Ödevler yükleniyor...',
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
              backgroundColor: AppTheme.accentPurple,
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
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz ödev atamadınız',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Öğrencilerinize yeni ödevler atayabilirsiniz',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.accentOrange;
      case 'submitted':
        return AppTheme.accentGreen;
      case 'graded':
        return AppTheme.accentPurple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Atandı';
      case 'submitted':
        return 'Değerlendirilecek';
      case 'graded':
        return 'Değerlendirildi';
      default:
        return 'Bilinmiyor';
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (difference == 0) {
      return 'Bugün';
    } else if (difference == 1) {
      return 'Yarın';
    } else if (difference > 1) {
      return '$difference gün sonra';
    } else {
      return '${difference.abs()} gün önce';
    }
  }

  void _showAssignmentDetails(Assignment assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherAssignmentDetailScreen(assignment: assignment),
      ),
    ).then((_) => _refreshData());
  }

  void _gradeAssignment(Assignment assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherAssignmentDetailScreen(assignment: assignment),
      ),
    ).then((_) => _refreshData());
  }
}
