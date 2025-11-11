import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_card.dart';
import 'teacher_detail_screen.dart';

class EnhancedTeachersScreen extends StatefulWidget {
  const EnhancedTeachersScreen({super.key});

  @override
  State<EnhancedTeachersScreen> createState() => _EnhancedTeachersScreenState();
}

class _EnhancedTeachersScreenState extends State<EnhancedTeachersScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _searchAnimation;
  
  List<Teacher> _teachers = [];
  List<Teacher> _featuredTeachers = [];
  List<Category> _categories = [];
  Set<int> _favoriteTeacherIds = {}; // Track favorite teachers
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isGridView = true;
  String? _error;
  
  // Filters
  String _selectedCategory = '';
  double _minRating = 0;
  bool _onlineOnly = false;
  String _sortBy = 'rating';
  String _searchQuery = '';
  
  // Advanced search and filtering
  List<String> _selectedLanguages = [];
  List<String> _selectedEducation = [];
  String _locationFilter = '';
  bool _availableNow = false;
  double _minPrice = 0;
  double _maxPrice = 1000;
  
  // Performance optimization
  String _lastSearchQuery = '';
  
  // Real-time features
  bool _isOnline = true;
  bool _notificationsEnabled = false;
  Map<String, dynamic> _userPreferences = {};
  
  // Analytics & Statistics
  Map<String, dynamic> _searchAnalytics = {};
  Map<String, dynamic> _userBehavior = {};
  List<String> _recommendedTeachers = [];
  
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRealTimeFeatures();
    _loadInitialData();
    _setupScrollListener();
  }

  void _initializeRealTimeFeatures() async {
    // Check connectivity
    _checkConnectivity();
    
    // Request notification permissions
    await _requestNotificationPermissions();
    
    // Load user preferences
    await _loadUserPreferences();
    
    // Initialize analytics
    _initializeAnalytics();
    
    // Setup real-time listeners
    _setupRealTimeListeners();
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      });
      
      if (_isOnline && _teachers.isEmpty) {
        _loadInitialData();
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _loadUserPreferences() async {
    // Load user preferences from local storage
    // This would typically use SharedPreferences or similar
    setState(() {
      _userPreferences = {
        'favoriteCategories': [],
        'preferredPriceRange': {'min': 0, 'max': 1000},
        'notificationSettings': {
          'newTeachers': true,
          'priceChanges': false,
          'availability': true,
        },
      };
    });
  }

  void _initializeAnalytics() {
    setState(() {
      _searchAnalytics = {
        'totalSearches': 0,
        'popularCategories': [],
        'averageSearchTime': 0,
        'conversionRate': 0.0,
      };
      
      _userBehavior = {
        'timeSpent': 0,
        'filtersUsed': [],
        'teachersViewed': [],
        'searchesPerformed': [],
      };
    });
  }

  void _setupRealTimeListeners() {
    // Setup real-time updates for teacher availability
    // This would typically use WebSocket or similar
    _startRealTimeUpdates();
  }

  void _startRealTimeUpdates() {
    // Simulate real-time updates
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        _checkForUpdates();
      }
    });
  }

  void _checkForUpdates() async {
    try {
      // Check for new teachers or availability changes
      // TODO: Implement getTeacherUpdates method in ApiService
      final updates = <Map<String, dynamic>>[];
      if (updates.isNotEmpty && mounted) {
        _showUpdateNotification(updates);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showUpdateNotification(List<Map<String, dynamic>> updates) {
    if (_notificationsEnabled && updates.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updates.length} yeni güncelleme mevcut'),
          backgroundColor: AppTheme.primaryBlue,
          action: SnackBarAction(
            label: 'Güncelle',
            textColor: Colors.white,
            onPressed: _loadInitialData,
          ),
        ),
      );
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _searchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMorePages) {
          _loadMoreTeachers();
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
        _loadTeachers(),
        _loadFeaturedTeachers(),
        _loadCategories(),
        _loadFavorites(),
      ]);

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animationController.forward();
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

  Future<void> _loadTeachers() async {
    try {
      if (kDebugMode) {
        print('🔍 Loading teachers with params: page=$_currentPage, category=$_selectedCategory, minRating=$_minRating, onlineOnly=$_onlineOnly, sortBy=$_sortBy, search=$_searchQuery');
        print('🏷️ Category filter: $_selectedCategory');
      }
      
      final teachers = await _apiService.getTeachers(
        page: _currentPage,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        minRating: _minRating > 0 ? _minRating : null,
        onlineOnly: _onlineOnly,
        sortBy: _sortBy,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (kDebugMode) {
        print('📊 Loaded ${teachers.length} teachers');
        if (teachers.isEmpty && _selectedCategory.isNotEmpty) {
          print('⚠️ No teachers found for category: $_selectedCategory');
        }
      }

      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _teachers = teachers;
          } else {
            _teachers.addAll(teachers);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _hasMorePages = teachers.isNotEmpty;
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
      if (kDebugMode) {
        print('Teachers loading error: $e');
      }
    }
  }

  Future<void> _loadFeaturedTeachers() async {
    try {
      final featured = await _apiService.getFeaturedTeachers();
      if (mounted) {
        setState(() {
          _featuredTeachers = featured;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Featured teachers loading error: $e');
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories.where((cat) => cat.parentId == null).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Categories loading error: $e');
      }
      // Kategori yükleme hatası kullanıcıya bildirilir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kategoriler yüklenirken bir sorun oluştu'),
            backgroundColor: AppTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: _loadCategories,
            ),
          ),
        );
      }
    }
  }


  Future<void> _loadFavorites() async {
    try {
      final favorites = await _apiService.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteTeacherIds = favorites.map((teacher) => teacher.id ?? teacher.userId).where((id) => id != 0).toSet();
        });
      }
    } catch (e) {
      // Favorites loading error, continue with empty set
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    }
  }

  Future<void> _toggleFavorite(Teacher teacher) async {
    try {
      // Try to use teacher.id first, fallback to userId
      final teacherId = teacher.id ?? teacher.userId;
      if (teacherId == 0) {
        if (kDebugMode) {
          print('⚠️ [FAVORITE] Teacher ID is 0, cannot toggle favorite');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Öğretmen bilgisi eksik'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final isFavorite = _favoriteTeacherIds.contains(teacherId);
      
      if (kDebugMode) {
        print('❤️ [FAVORITE] Toggling favorite for teacher $teacherId, current state: $isFavorite');
      }
      
      if (isFavorite) {
        await _apiService.removeFromFavorites(teacherId);
        if (mounted) {
          setState(() {
            _favoriteTeacherIds.remove(teacherId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Favorilerden çıkarıldı'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await _apiService.addToFavorites(teacherId);
        if (mounted) {
          setState(() {
            _favoriteTeacherIds.add(teacherId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Favorilere eklendi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      
      if (kDebugMode) {
        print('✅ [FAVORITE] Successfully toggled favorite for teacher $teacherId: ${!isFavorite}');
        print('📊 [FAVORITE] Current favorite count: ${_favoriteTeacherIds.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FAVORITE] Error toggling favorite: $e');
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Favori durumu güncellenirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreTeachers() async {
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadTeachers();
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    _hasMorePages = true;
    await _loadInitialData();
  }

  void _applyFilters() {
    if (kDebugMode) {
      print('🔧 _applyFilters called with category: $_selectedCategory');
    }
    _currentPage = 1;
    _hasMorePages = true;
    setState(() {
      _teachers = []; // Clear existing teachers before loading new ones
    });
    _loadTeachers();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = '';
      _minRating = 0;
      _onlineOnly = false;
      _sortBy = 'rating';
      _searchQuery = '';
      _selectedLanguages.clear();
      _selectedEducation.clear();
      _locationFilter = '';
      _availableNow = false;
      _minPrice = 0;
      _maxPrice = 1000;
      _searchController.clear();
    });
    
    _searchAnimationController.reverse();
    _applyFilters();
  }


  void _performAdvancedSearch() async {
    if (_searchQuery != _lastSearchQuery) {
      setState(() {
        _lastSearchQuery = _searchQuery;
      });
      
      _searchAnimationController.forward();
    }
    
    // Track search analytics
    _trackSearchAnalytics();
    
    try {
      final response = await _apiService.searchTeachers(
        query: _searchQuery,
        category: _selectedCategory,
        onlineOnly: _onlineOnly,
        sortBy: _sortBy,
      );
      
      final teachers = response['teachers'] as List<Teacher>;
      
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _isLoading = false;
        });
        
        // Generate smart recommendations
        _generateSmartRecommendations(teachers);
        
        // Update user behavior
        _updateUserBehavior();
        
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

  void _trackSearchAnalytics() {
    setState(() {
      _searchAnalytics['totalSearches'] = (_searchAnalytics['totalSearches'] as int) + 1;
      _searchAnalytics['popularCategories'].add(_selectedCategory);
      _userBehavior['searchesPerformed'].add({
        'query': _searchQuery,
        'category': _selectedCategory,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  void _generateSmartRecommendations(List<Teacher> teachers) async {
    try {
      // Get AI-powered recommendations based on user behavior
      // TODO: Implement getSmartRecommendations method in ApiService
      final recommendations = <String>[];
      
      if (mounted) {
        setState(() {
          _recommendedTeachers = recommendations;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _updateUserBehavior() {
    setState(() {
      _userBehavior['timeSpent'] = (_userBehavior['timeSpent'] as int) + 1;
      _userBehavior['filtersUsed'].addAll([
        if (_selectedCategory.isNotEmpty) 'category',
        if (_onlineOnly) 'online',
        if (_minRating > 0) 'rating',
      ]);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.primaryBlue,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Modern Hero App Bar
                _buildModernHeroAppBar(),
                
                // Search & Filter Section
                SliverToBoxAdapter(
                  child: _buildSearchAndFilterSection(),
                ),
                
                // Featured Teachers Section
                if (_featuredTeachers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedTeachersSection(),
                  ),
                
                // Categories Section
                if (_categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildCategoriesSection(),
                  ),
                
                // Results Header
                SliverToBoxAdapter(
                  child: _buildResultsHeader(),
                ),
                
                // Teachers Grid/List
                _isLoading
                    ? SliverFillRemaining(
                        child: _buildLoadingState(),
                      )
                    : _error != null
                        ? SliverFillRemaining(
                            child: _buildErrorState(),
                          )
                        : _teachers.isEmpty
                            ? SliverFillRemaining(
                                child: _buildEmptyState(),
                              )
                            : _buildTeachersGrid(),
              ],
            ),
          ),
        ),
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
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.grey900,
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
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
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
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Eğitimciler',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_teachers.length} uzman eğitimci',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() => _isGridView = !_isGridView);
                        HapticFeedback.lightImpact();
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

  Widget _buildSearchAndFilterSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.grey200.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
              decoration: InputDecoration(
                hintText: 'Eğitimci ara...',
                hintStyle: TextStyle(
                  color: AppTheme.grey500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                        icon: Icon(
                          Icons.clear_rounded,
                          color: AppTheme.grey500,
                          size: 18,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                // Add a small delay to avoid too many API calls while typing
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchQuery == value) {
                _applyFilters();
                  }
                });
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Simple Filter Row
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  'Kategori',
                  Icons.category_rounded,
                  _selectedCategory.isNotEmpty,
                  () => _showCategoryFilter(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  'Sıralama',
                  Icons.sort_rounded,
                  false,
                  () => _showSortOptions(),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(
                'Temizle',
                Icons.clear_all_rounded,
                false,
                _clearFilters,
              ),
            ],
          ),
          
          // Smart Recommendations Section
          if (_recommendedTeachers.isNotEmpty) _buildSmartRecommendationsSection(),
          
          // Analytics Dashboard (for admin users)
          if (_userPreferences['showAnalytics'] == true) _buildAnalyticsDashboard(),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.primaryBlue : AppTheme.grey300,
            width: 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: AppTheme.grey200.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppTheme.grey600,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedTeachersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Öne Çıkan Eğitimciler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _featuredTeachers.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(right: index == _featuredTeachers.length - 1 ? 0 : 12),
                  child: _buildFeaturedTeacherCard(_featuredTeachers[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeaturedTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToTeacherDetail(teacher);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.accentPurple,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: teacher.user?.profilePhotoUrl != null
                        ? NetworkImage(teacher.user!.profilePhotoUrl!)
                        : null,
                    child: teacher.user?.profilePhotoUrl == null
                        ? Text(
                            teacher.user!.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: AppTheme.premiumGold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          teacher.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                teacher.user?.name ?? 'İsimsiz',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                (teacher.categories?.isNotEmpty == true) 
                    ? teacher.categories!.first.name 
                    : 'Genel',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₺${teacher.priceHour?.toInt() ?? 0}/saat',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentGreen, AppTheme.accentGreen.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kategoriler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category.slug;
                
                return Container(
                  margin: EdgeInsets.only(right: index == _categories.length - 1 ? 0 : 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = isSelected ? '' : category.slug;
                      });
                      if (kDebugMode) {
                        print('🏷️ Category selected: ${category.slug}, isSelected: $isSelected, new category: $_selectedCategory');
                        print('🏷️ About to call _applyFilters()');
                      }
                      _applyFilters();
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.grey300,
                          width: 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          else
                            BoxShadow(
                                color: AppTheme.grey200.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                        ],
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.grey700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Tüm Eğitimciler (${_teachers.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.grey200.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: const EdgeInsets.all(8),
              onPressed: () {
                setState(() => _isGridView = !_isGridView);
                HapticFeedback.lightImpact();
              },
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersGrid() {
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // Daha yüksek oran - buton için yer açtık
            crossAxisSpacing: 8, // Daha az boşluk
            mainAxisSpacing: 8, // Daha az boşluk
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index < _teachers.length) {
                return TeacherGridCard(
                  teacher: _teachers[index],
                  isFavorite: (_teachers[index].id ?? _teachers[index].userId) != 0 && _favoriteTeacherIds.contains(_teachers[index].id ?? _teachers[index].userId),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _navigateToTeacherDetail(_teachers[index]);
                  },
                  onFavoriteToggle: () {
                    HapticFeedback.lightImpact();
                    _toggleFavorite(_teachers[index]);
                  },
                );
              } else if (_isLoadingMore) {
                return const Center(child: CircularProgressIndicator());
              }
              return null;
            },
            childCount: _teachers.length + (_isLoadingMore ? 1 : 0),
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16), // Minimal padding
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index < _teachers.length) {
                return TeacherCard(
                  teacher: _teachers[index],
                  isFavorite: (_teachers[index].id ?? _teachers[index].userId) != 0 && _favoriteTeacherIds.contains(_teachers[index].id ?? _teachers[index].userId),
                  onTap: null, // Rezerve Et butonunun çalışması için null yapıyoruz
                  onFavoriteToggle: () {
                    HapticFeedback.lightImpact();
                    _toggleFavorite(_teachers[index]);
                  },
                );
              } else if (_isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return null;
            },
            childCount: _teachers.length + (_isLoadingMore ? 1 : 0),
          ),
        ),
      );
    }
  }



  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Eğitimciler yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Debug: _teachers.length = ${_teachers.length}, _isLoading = $_isLoading, _error = $_error',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
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
            'Veriler yüklenirken bir sorun oluştu.\nLütfen tekrar deneyin.',
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
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Eğitimci bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory.isNotEmpty
                ? 'Bu kategoride eğitimci bulunamadı.\nBaşka bir kategori deneyin.'
                : _searchQuery.isNotEmpty
                    ? 'Arama için sonuç bulunamadı.\nFarklı kelimeler deneyin.'
                    : 'Arama kriterlerinizi değiştirmeyi deneyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Filtreleri Temizle'),
          ),
        ],
      ),
    );
  }







  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategori Seçin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Category List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            title: const Text('Tüm Kategoriler'),
                            leading: const Icon(Icons.all_inclusive),
                            trailing: _selectedCategory.isEmpty
                                ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCategory = '';
                              });
                              Navigator.pop(context);
                              _applyFilters();
                            },
                          );
                        }
                        
                        final category = _categories[index - 1];
                        final isSelected = _selectedCategory == category.id.toString();
                        
                        return ListTile(
                          title: Text(category.name),
                          leading: Icon(
                            Icons.category,
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.grey600,
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCategory = category.id.toString();
                            });
                            Navigator.pop(context);
                            _applyFilters();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendationsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.1),
            AppTheme.accentPurple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sizin İçin Önerilenler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _refreshRecommendations,
                child: const Text(
                  'Yenile',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedTeachers.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recommendedTeachers[index],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Önerisi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 16,
                              color: AppTheme.accentGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Popüler',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildAnalyticsDashboard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Arama Analitikleri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Toplam Arama',
                  '${_searchAnalytics['totalSearches']}',
                  Icons.search,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  'Geçen Süre',
                  '${_userBehavior['timeSpent']} dk',
                  Icons.timer,
                  AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Kullanılan Filtreler',
                  '${(_userBehavior['filtersUsed'] as List).length}',
                  Icons.filter_list,
                  AppTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  'Dönüşüm Oranı',
                  '${(_searchAnalytics['conversionRate'] * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  AppTheme.accentPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _refreshRecommendations() async {
    setState(() {
      _isLoading = true;
    });
    
    _generateSmartRecommendations(_teachers);
    
    setState(() {
      _isLoading = false;
    });
  }


  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sıralama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...['rating', 'price_low', 'price_high', 'newest'].map(
              (sort) => ListTile(
                title: Text(_getSortTitle(sort)),
                trailing: _sortBy == sort 
                    ? Icon(Icons.check, color: AppTheme.primaryBlue)
                    : null,
                onTap: () {
                  setState(() => _sortBy = sort);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getSortTitle(String sort) {
    switch (sort) {
      case 'rating':
        return 'En Yüksek Puan';
      case 'price_low':
        return 'En Düşük Fiyat';
      case 'price_high':
        return 'En Yüksek Fiyat';
      case 'newest':
        return 'En Yeni';
      default:
        return 'Varsayılan';
    }
  }


  void _navigateToTeacherDetail(Teacher teacher) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherDetailScreen(teacher: teacher),
      ),
    );
  }
}

