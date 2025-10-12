import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/lesson.dart';
import 'lesson_detail_screen.dart';

class StudentLessonsScreen extends StatefulWidget {
  const StudentLessonsScreen({super.key});

  @override
  State<StudentLessonsScreen> createState() => _StudentLessonsScreenState();
}

class _StudentLessonsScreenState extends State<StudentLessonsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  // Animation controllers removed for performance
  
  List<Lesson> _lessons = [];
  List<Lesson> _upcomingLessons = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isListView = true;
  String? _error;
  
  // Filters
  String _selectedStatus = '';
  
  bool _hasMorePages = true;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'upcoming', 'label': 'Yaklaşan', 'icon': Icons.schedule_rounded, 'color': AppTheme.accentOrange},
    {'value': 'in_progress', 'label': 'Devam Eden', 'icon': Icons.play_circle_rounded, 'color': AppTheme.accentGreen},
    {'value': 'completed', 'label': 'Tamamlanan', 'icon': Icons.check_circle_rounded, 'color': AppTheme.accentPurple},
  ];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🚀 [LESSONS_SCREEN] initState called');
      print('🚀 [LESSONS_SCREEN] API Service: $_apiService');
      print('🚀 [LESSONS_SCREEN] API Service authenticated: ${_apiService.isAuthenticated}');
    }
    _initializeAnimations();
    _loadInitialData();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    // Animations removed for performance
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMorePages) {
          _loadMoreLessons();
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (kDebugMode) {
      print('🚀 [LESSONS_SCREEN] _loadInitialData called');
    }
    await Future.wait([
      _loadLessons(),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) {
        print('🚀 [LESSONS_SCREEN] Loading lessons...');
        print('🚀 [LESSONS_SCREEN] Current state: isLoading=$_isLoading, error=$_error');
        print('🚀 [LESSONS_SCREEN] API Service base URL: ${ApiService.baseUrl}');
        print('🚀 [LESSONS_SCREEN] API Service authenticated: ${_apiService.isAuthenticated}');
      }
      
      // Authentication is already checked by StudentHomeScreen
      // No need to check again here
      
      final lessons = await _apiService.getUserLessons();
      
      if (kDebugMode) {
        print('📡 [LESSONS_SCREEN] Loaded ${lessons.length} lessons');
      }
      
      if (mounted) {
        setState(() {
          _lessons = lessons;
          _upcomingLessons = lessons.where((lesson) {
            try {
              return lesson.scheduledAt.isAfter(DateTime.now()) && 
                     lesson.status == 'scheduled';
            } catch (e) {
              if (kDebugMode) {
                print('❌ [LESSONS_SCREEN] Error filtering lesson: $e');
              }
              return false;
            }
          }).toList();
          _isLoading = false;
          _isLoadingMore = false;
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
      if (kDebugMode) {
        print('📊 [STATISTICS] Loading user statistics...');
      }
      
      // Authentication is already checked by StudentHomeScreen
      // No need to check again here
      
      final stats = await _apiService.getUserStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
      if (kDebugMode) {
        print('📊 [STATISTICS] Loaded statistics: $stats');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [STATISTICS] Error loading statistics: $e');
      }
      if (mounted) {
        setState(() {
          _statistics = {};
        });
      }
    }
  }

  Future<void> _loadMoreLessons() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      if (kDebugMode) {
        print('📡 [LOAD_MORE] Loading more lessons...');
      }
      
      // Get current page number
      final currentPage = (_lessons.length ~/ 20) + 1;
      final moreLessons = await _apiService.getUserLessons(page: currentPage);
      
      if (mounted) {
        setState(() {
          // Remove duplicates by ID
          final existingIds = _lessons.map((l) => l.id).toSet();
          final newLessons = moreLessons.where((lesson) => !existingIds.contains(lesson.id)).toList();
          
          _lessons.addAll(newLessons);
          _hasMorePages = moreLessons.length >= 20;
          _isLoadingMore = false;
        });
      }
      if (kDebugMode) {
        print('📡 [LOAD_MORE] Loaded ${moreLessons.length} more lessons, added ${moreLessons.where((lesson) => !_lessons.map((l) => l.id).contains(lesson.id)).length} new lessons');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LOAD_MORE] Error loading more lessons: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _hasMorePages = true;
    });
    await _loadInitialData();
  }

  List<Lesson> _getFilteredLessons() {
    if (_selectedStatus.isEmpty) return _lessons;
    
    return _lessons.where((lesson) {
      try {
        switch (_selectedStatus) {
          case 'upcoming':
            return lesson.scheduledAt.isAfter(DateTime.now()) && 
                   lesson.status == 'scheduled';
          case 'in_progress':
            return lesson.status == 'in_progress';
          case 'completed':
            return lesson.status == 'completed';
          default:
            return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ [FILTER] Error filtering lesson: $e');
        }
        return false;
      }
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  // Removed excessive debug logging for performance
  return Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    body: RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryBlue,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern Hero App Bar
          _buildModernHeroAppBar(),

          // Statistics Cards
          if (_statistics.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildStatisticsSection(),
            ),

          // Upcoming Lessons
          if (_upcomingLessons.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildUpcomingLessonsSection(),
            ),

          // Filter Section
          SliverToBoxAdapter(
            child: _buildFilterSection(),
          ),

          // Results Header
          SliverToBoxAdapter(
            child: _buildResultsHeader(),
          ),

          // Lessons List
          _isLoading
              ? SliverToBoxAdapter(
                  child: _buildLoadingState(),
                )
              : _error != null
                  ? SliverToBoxAdapter(
                      child: _buildErrorState(),
                    )
                  : _getFilteredLessons().isEmpty
                      ? SliverToBoxAdapter(
                          child: _buildEmptyState(),
                        )
                      : _buildLessonsList(),

          // Load More Indicator
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: _buildLoadMoreIndicator(),
            ),
        ],
      ),
    ),
  );
}


  Widget _buildModernHeroAppBar() {
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
                AppTheme.primaryBlue.withOpacity(0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.book_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Derslerim',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Öğrenci dersleri ve ilerleme',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İstatistikler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Ders',
                  '${_statistics['total_reservations'] ?? _lessons.length}',
                  Icons.book_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Tamamlanan',
                  '${_statistics['completed_lessons'] ?? _lessons.where((l) => l.status == 'completed').length}',
                  Icons.check_circle_rounded,
                  AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Yaklaşan',
                  '${_statistics['upcoming_lessons'] ?? _upcomingLessons.length}',
                  Icons.schedule_rounded,
                  AppTheme.accentOrange,
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

  Widget _buildUpcomingLessonsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yaklaşan Dersler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _upcomingLessons.length,
              itemBuilder: (context, index) {
                final lesson = _upcomingLessons[index];
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(
                    right: index < _upcomingLessons.length - 1 ? 12 : 0,
                  ),
                  child: _buildUpcomingLessonCard(lesson),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessonCard(Lesson lesson) {
    final teacher = lesson.teacher;
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: (teacher != null && teacher['profile_photo_url'] != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              teacher['profile_photo_url'].toString(),
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  (teacher['name'] != null && teacher['name'].toString().isNotEmpty)
                                      ? teacher['name'].toString().substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            (teacher != null && teacher['name'] != null && teacher['name'].toString().isNotEmpty)
                                ? teacher['name'].toString().substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (teacher != null && teacher['name'] != null) ? teacher['name'].toString() : 'Bilinmiyor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ders',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${lesson.scheduledAt.day.toString().padLeft(2, '0')}/${lesson.scheduledAt.month.toString().padLeft(2, '0')} ${lesson.scheduledAt.hour.toString().padLeft(2, '0')}:${lesson.scheduledAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
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
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrele',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length,
              itemBuilder: (context, index) {
                final option = _statusOptions[index];
                final isSelected = _selectedStatus == option['value'];
                
                return Container(
                  margin: EdgeInsets.only(
                    right: index < _statusOptions.length - 1 ? 8 : 0,
                  ),
                  child: FilterChip(
                    label: Text(
                      option['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : option['color'],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = selected ? option['value'] : '';
                      });
                      HapticFeedback.lightImpact();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: option['color'],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? option['color'] : AppTheme.grey300,
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

  Widget _buildResultsHeader() {
    final filteredLessons = _getFilteredLessons();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${filteredLessons.length} ders bulundu',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey600,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _isListView = true;
                  });
                  HapticFeedback.lightImpact();
                },
                icon: Icon(
                  Icons.list_rounded,
                  color: _isListView ? AppTheme.primaryBlue : AppTheme.grey400,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isListView = false;
                  });
                  HapticFeedback.lightImpact();
                },
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: !_isListView ? AppTheme.primaryBlue : AppTheme.grey400,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList() {
    final filteredLessons = _getFilteredLessons();
    
    if (_isListView) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final lesson = filteredLessons[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _buildLessonCard(lesson),
            );
          },
          childCount: filteredLessons.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          addSemanticIndexes: false,
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final lesson = filteredLessons[index];
          return _buildLessonCard(lesson, isGrid: true);
        },
        childCount: filteredLessons.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        addSemanticIndexes: false,
      ),
        ),
      );
    }
  }

  Widget _buildLessonCard(Lesson lesson, {bool isGrid = false}) {
    try {
      final teacher = lesson.teacher;
      final status = lesson.status;
      final statusColor = _getStatusColor(status);
      final statusText = _getStatusText(status);
      final teacherName = (teacher != null && teacher['name'] != null) ? teacher['name'].toString() : 'Bilinmiyor';
      final teacherInitial = teacherName.isNotEmpty ? teacherName.substring(0, 1).toUpperCase() : '?';
      final teacherPhotoUrl = teacher?['profile_photo_url']?.toString();
      
      // Grid görünümü için farklı tasarım
      if (isGrid) {
        return GestureDetector(
          onTap: () => _navigateToLessonDetail(lesson),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF3F4F6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: statusColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst kısım - Öğretmen bilgisi
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: teacherPhotoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  teacherPhotoUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        teacherInitial,
                                        style: TextStyle(
                                          fontSize: 16,
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
                                  teacherInitial,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacherName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Özel Ders',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Orta kısım - Tarih ve saat
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${lesson.scheduledAt.day.toString().padLeft(2, '0')}/${lesson.scheduledAt.month.toString().padLeft(2, '0')}/${lesson.scheduledAt.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: AppTheme.accentGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${lesson.scheduledAt.hour.toString().padLeft(2, '0')}:${lesson.scheduledAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Alt kısım - Durum ve buton
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.visibility_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
      
      // Liste görünümü için mevcut tasarım
      return GestureDetector(
        onTap: () => _navigateToLessonDetail(lesson),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF3F4F6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: statusColor.withOpacity(0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with enhanced gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.15),
                      statusColor.withOpacity(0.08),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Enhanced Teacher Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: statusColor.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: teacherPhotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: Image.network(
                                teacherPhotoUrl,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildEnhancedTeacherInitial(teacherInitial, statusColor);
                                },
                              ),
                            )
                          : _buildEnhancedTeacherInitial(teacherInitial, statusColor),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Enhanced Teacher Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacherName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue.withOpacity(0.12),
                                  AppTheme.primaryBlue.withOpacity(0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Özel Ders',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Enhanced Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Enhanced Content Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Date and Time
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF8FAFC),
                            const Color(0xFFF1F5F9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Date Section
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryBlue.withOpacity(0.15),
                                        AppTheme.primaryBlue.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryBlue.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tarih',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.grey600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${lesson.scheduledAt.day.toString().padLeft(2, '0')}/${lesson.scheduledAt.month.toString().padLeft(2, '0')}/${lesson.scheduledAt.year}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Divider
                          Container(
                            width: 1,
                            height: 40,
                            color: const Color(0xFFE2E8F0),
                          ),
                          
                          // Time Section
                          Expanded(
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.accentGreen.withOpacity(0.15),
                                        AppTheme.accentGreen.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.accentGreen.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.access_time_rounded,
                                    size: 20,
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Saat',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.grey600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${lesson.scheduledAt.hour.toString().padLeft(2, '0')}:${lesson.scheduledAt.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.2,
                                      ),
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Enhanced Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _navigateToLessonDetail(lesson),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlue.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.visibility_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Ders Detaylarını Görüntüle',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LESSON_CARD] Error building lesson card: $e');
        print('❌ [LESSON_CARD] Lesson data: ${lesson.toString()}');
      }
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200] ?? Colors.red),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Ders kartı yüklenirken hata oluştu',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Hata: ${e.toString()}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }


  Widget _buildEnhancedTeacherInitial(String initial, Color statusColor) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: statusColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }


  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'Dersler yüklenirken hata oluştu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.book_outlined,
            size: 48,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz ders bulunmuyor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Öğretmenlerinizden ders rezervasyonu yaparak başlayabilirsiniz.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return AppTheme.primaryBlue;
      case 'in_progress':
        return AppTheme.accentOrange;
      case 'completed':
        return AppTheme.accentGreen;
      case 'cancelled':
        return Colors.red[600] ?? Colors.red;
      default:
        return AppTheme.grey600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return '';
      case 'in_progress':
        return 'Devam Eden';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return 'Bilinmiyor';
    }
  }

  void _navigateToLessonDetail(Lesson lesson) {
    try {
      if (kDebugMode) {
        print('🧭 [NAVIGATION] Navigating to lesson detail: ${lesson.id}');
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LessonDetailScreen(lesson: lesson),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [NAVIGATION] Error navigating to lesson detail: $e');
      }
    }
  }
}
