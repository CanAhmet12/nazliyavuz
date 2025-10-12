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
    // Tab changed - filtered data will be updated automatically via _getFilteredAssignments
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

      final response = await _apiService.get('/assignments/student');
      if (response['success'] == true && mounted) {
        setState(() {
          _assignments = (response['assignments'] as List)
              .map((json) => Assignment.fromJson(json as Map<String, dynamic>))
              .toList();
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
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        title: null, // Remove duplicate title
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue,
                AppTheme.accentPurple,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
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
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Ödevlerim',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 24,
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
                            '${_assignments.length} ödev',
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
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
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
                _error!,
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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Toplam',
              _statistics['total']?.toString() ?? '0',
              Icons.assignment_rounded,
              AppTheme.primaryBlue,
            ),
          ),
          Expanded(
            child: _buildStatCard(
              'Bekleyen',
              _statistics['pending']?.toString() ?? '0',
              Icons.pending_rounded,
              AppTheme.accentOrange,
            ),
          ),
          Expanded(
            child: _buildStatCard(
              'Teslim Edilen',
              _statistics['submitted']?.toString() ?? '0',
              Icons.upload_rounded,
              AppTheme.accentGreen,
            ),
          ),
          Expanded(
            child: _buildStatCard(
              'Notlanan',
              _statistics['graded']?.toString() ?? '0',
              Icons.grade_rounded,
              AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent, // Remove divider below tabs
        tabs: _statusTabs.map((tab) => Tab(
          icon: Icon(tab['icon'], size: 20),
          text: tab['label'],
        )).toList(),
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
    final isOverdue = dueDate.isBefore(DateTime.now()) && assignment.status == 'pending';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignmentDetailScreen(assignment: assignment),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignment.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    _buildStatusChip(assignment.status, isOverdue),
                  ],
                ),
                const SizedBox(height: 8),
                if (assignment.description.isNotEmpty)
                  Text(
                    assignment.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${assignment.teacherName ?? 'Öğretmen'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: isOverdue ? Colors.red[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(dueDate),
                      style: TextStyle(
                        color: isOverdue ? Colors.red[500] : Colors.grey[600],
                        fontSize: 14,
                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (assignment.grade != null && assignment.grade!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.grade_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Not: ${assignment.grade}',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isOverdue) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        backgroundColor = isOverdue ? Colors.red[50]! : AppTheme.accentOrange.withOpacity(0.1);
        textColor = isOverdue ? Colors.red[600]! : AppTheme.accentOrange;
        label = isOverdue ? 'Süresi Geçmiş' : 'Bekleyen';
        icon = isOverdue ? Icons.warning_rounded : Icons.pending_rounded;
        break;
      case 'submitted':
        backgroundColor = AppTheme.accentGreen.withOpacity(0.1);
        textColor = AppTheme.accentGreen;
        label = 'Teslim Edildi';
        icon = Icons.upload_rounded;
        break;
      case 'graded':
        backgroundColor = AppTheme.primaryBlue.withOpacity(0.1);
        textColor = AppTheme.primaryBlue;
        label = 'Notlandı';
        icon = Icons.grade_rounded;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[600]!;
        label = 'Bilinmiyor';
        icon = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}