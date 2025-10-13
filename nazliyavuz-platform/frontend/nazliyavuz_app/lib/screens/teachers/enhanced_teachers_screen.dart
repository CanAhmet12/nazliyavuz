import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
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
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  List<Teacher> _teachers = [];
  List<Teacher> _featuredTeachers = [];
  List<Category> _categories = [];
  
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
  
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
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
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          
          // Filter Row
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  'Kategori',
                  Icons.category_rounded,
                  _selectedCategory.isNotEmpty,
                  () => _showFilters(),
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _navigateToTeacherDetail(_teachers[index]);
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
                  onTap: null, // Rezerve Et butonunun çalışması için null yapıyoruz
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
            _error ?? 'Bilinmeyen hata',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Debug: _teachers.length = ${_teachers.length}, _isLoading = $_isLoading',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
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
            'Arama kriterlerinizi değiştirmeyi deneyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Debug: _teachers.length = ${_teachers.length}, _isLoading = $_isLoading, _error = $_error, _selectedCategory = $_selectedCategory, categories.length = ${_categories.length}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Filtreler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fiyat Aralığı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Min Fiyat',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Max Fiyat',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Puan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _minRating = _minRating == 0 ? 4.0 : 0.0;
                            });
                            _loadTeachers();
                          },
                          child: Icon(
                            Icons.star,
                            color: index < 4 ? AppTheme.premiumGold : Colors.grey[300],
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Online Ders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Sadece online ders verenler'),
                      value: _onlineOnly,
                      onChanged: (value) {
                        setState(() {
                          _onlineOnly = value;
                        });
                        _loadTeachers();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _minRating = 0.0;
                          _onlineOnly = false;
                        });
                        _loadTeachers();
                        Navigator.pop(context);
                      },
                      child: const Text('Temizle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _loadTeachers();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                      child: const Text('Uygula'),
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

