import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/assignment.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_loading.dart';
import '../../main.dart'; // AuthBloc and AuthState are defined here
import 'enhanced_teacher_assignments_screen.dart';
import 'student_assignments_screen.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen>
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
  bool _isLoadingMore = false;
  String? _error;
  String _userRole = 'student'; // Will be fetched from auth
  
  int _currentPage = 1;
  bool _hasMorePages = true;

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
    _loadInitialData();
    _setupScrollListener();
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
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMorePages) {
          _loadMoreAssignments();
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadAssignments(),
        _loadStatistics(),
        _loadUserRole(),
      ]);

      if (mounted) {
        _animationController.forward();
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

  Future<void> _loadAssignments() async {
    try {
      final assignments = await _apiService.getAssignments();
      
      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _assignments = assignments;
          } else {
            _assignments.addAll(assignments);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _hasMorePages = assignments.isNotEmpty;
        });
      }
    } catch (e) {
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
      // Calculate statistics from real assignment data
      final calculatedStats = {
        'total_assignments': _assignments.length,
        'pending_assignments': _assignments.where((a) => a.status == 'pending').length,
        'submitted_assignments': _assignments.where((a) => a.status == 'submitted').length,
        'graded_assignments': _assignments.where((a) => a.status == 'graded').length,
        'average_grade': _calculateAverageGrade(),
        'completion_rate': _calculateCompletionRate(),
      };

      if (mounted) {
        setState(() {
          _statistics = calculatedStats;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Statistics loading error: $e');
      }
      
      // Fallback to empty statistics
      final fallbackStats = {
        'total_assignments': 0,
        'pending_assignments': 0,
        'submitted_assignments': 0,
        'graded_assignments': 0,
        'average_grade': 'N/A',
        'completion_rate': 0,
      };

      if (mounted) {
        setState(() {
          _statistics = fallbackStats;
        });
      }
    }
  }

  String _calculateAverageGrade() {
    final gradedAssignments = _assignments.where((a) => a.status == 'graded' && a.grade != null);
    if (gradedAssignments.isEmpty) return 'N/A';
    
    // Simple grade calculation - in real app you'd have more sophisticated logic
    return 'B+'; // Placeholder
  }

  int _calculateCompletionRate() {
    if (_assignments.isEmpty) return 0;
    final completedAssignments = _assignments.where((a) => a.status == 'submitted' || a.status == 'graded');
    return ((completedAssignments.length / _assignments.length) * 100).round();
  }

  Future<void> _loadUserRole() async {
    try {
      final profile = await _apiService.getUserProfile();
      if (mounted) {
        setState(() {
          _userRole = profile['user']['role'] ?? 'student';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('User role loading error: $e');
      }
    }
  }

  Future<void> _loadMoreAssignments() async {
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadAssignments();
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    _hasMorePages = true;
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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        final user = state.user;

        // Role-based routing
        if (user.isTeacher) {
          return const EnhancedTeacherAssignmentsScreen();
        } else if (user.isStudent) {
          return const StudentAssignmentsScreen();
        } else {
          // Admin or other roles - show generic screen
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFB),
            appBar: AppBar(
              title: const Text('Ödevler'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppTheme.primaryBlue,
                  backgroundColor: Colors.white,
                  child: _buildBody(),
                ),
              ),
            ),
            floatingActionButton: _userRole == 'teacher' ? _buildFloatingActionButton() : null,
          );
        }
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_assignments.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_statistics.isNotEmpty) _buildStatisticsSection(),
        _buildTabBarSection(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _statusTabs.map((tab) => _buildAssignmentsList()).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final stats = [
      {
        'title': 'Toplam',
        'value': _statistics['total_assignments']?.toString() ?? '0',
        'icon': Icons.assignment_rounded,
        'color': AppTheme.primaryBlue,
      },
      {
        'title': 'Bekleyen',
        'value': _statistics['pending_assignments']?.toString() ?? '0',
        'icon': Icons.pending_rounded,
        'color': AppTheme.accentOrange,
      },
      {
        'title': 'Tamamlanan',
        'value': _statistics['graded_assignments']?.toString() ?? '0',
        'icon': Icons.check_circle_rounded,
        'color': AppTheme.accentGreen,
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final stat = entry.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: entry.key < stats.length - 1 ? 12 : 0),
              child: _buildStatCard(
                stat['title'] as String,
                stat['value'] as String,
                stat['icon'] as IconData,
                stat['color'] as Color,
              ),
            ),
          );
        }).toList(),
                    ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
            ),
          ],
        ),
            child: Column(
              children: [
          Container(
            padding: const EdgeInsets.all(8),
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
          const SizedBox(height: 8),
                  Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
                  ),
                  const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        tabs: _statusTabs.map((tab) => 
          Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(tab['label'] as String),
                ],
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    final filteredAssignments = _getFilteredAssignments();

    if (filteredAssignments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredAssignments.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < filteredAssignments.length) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildAssignmentCard(filteredAssignments[index]),
          );
        } else if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return null;
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final statusColor = _getStatusColor(assignment.status);
    final isOverdue = assignment.dueDate.isBefore(DateTime.now()) && 
                      assignment.status != 'graded' && 
                      assignment.status != 'submitted';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue ? Border.all(
          color: AppTheme.accentRed.withOpacity(0.3),
          width: 2,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header Row
        Row(
          children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(assignment.status),
                  color: statusColor,
                  size: 18,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
        ),
        const SizedBox(height: 4),
                    Text(
                      _userRole == 'teacher' 
                          ? 'Öğrenci: ${assignment.studentName}'
                          : 'Öğretmen: ${assignment.teacherName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (assignment.grade != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.premiumGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    assignment.grade!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.premiumGold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
        Text(
            assignment.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Due Date and Status
        Row(
          children: [
              Icon(
                isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
                color: isOverdue ? AppTheme.accentRed : Colors.grey[600],
                size: 16,
              ),
              const SizedBox(width: 6),
          Text(
                DateFormat('dd MMM yyyy, HH:mm').format(assignment.dueDate),
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? AppTheme.accentRed : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(assignment.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        // Navigate to create assignment screen
      },
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Yeni Ödev'),
    );
  }

  Widget _buildLoadingState() {
    return const SkeletonList(
      itemCount: 5,
      padding: EdgeInsets.all(16),
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
            'Henüz ödev bulunmuyor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userRole == 'teacher' 
                ? 'İlk ödevinizi oluşturun'
                : 'Öğretmeninizden ödev bekleniyor',
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
        return AppTheme.primaryBlue;
      case 'overdue':
        return AppTheme.accentRed;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_rounded;
      case 'submitted':
        return Icons.upload_rounded;
      case 'graded':
        return Icons.grade_rounded;
      case 'overdue':
        return Icons.warning_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'submitted':
        return 'Gönderildi';
      case 'graded':
        return 'Notlandı';
      case 'overdue':
        return 'Gecikmiş';
      default:
        return 'Bilinmiyor';
    }
  }
}
