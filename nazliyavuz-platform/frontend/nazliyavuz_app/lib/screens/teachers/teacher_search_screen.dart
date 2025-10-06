import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../models/teacher.dart';
import '../../services/api_service.dart';
import 'teacher_detail_screen.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Teacher> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _popularSearches = [];
  List<Teacher> _trendingTeachers = [];
  
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
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
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadTrendingTeachers(),
        _loadPopularSearches(),
        _loadRecentSearches(),
      ]);
      
      if (mounted) {
        _animationController.forward();
      }
    } catch (e) {
      // Initial data loading error: $e
    }
  }

  Future<void> _loadTrendingTeachers() async {
    try {
      final teachers = await _apiService.getTrendingTeachers();
      if (mounted) {
        setState(() {
          _trendingTeachers = teachers;
        });
      }
    } catch (e) {
      // Trending teachers loading error: $e
    }
  }

  Future<void> _loadPopularSearches() async {
    try {
      // Gerçek kategorileri API'den çek
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _popularSearches = categories.take(8).map((cat) => cat.name).toList();
        });
      }
    } catch (e) {
      // Fallback to default categories
      if (mounted) {
        setState(() {
          _popularSearches = [
            'Matematik',
            'İngilizce',
            'Fizik',
            'Kimya',
            'Türkçe',
            'Tarih',
            'Coğrafya',
            'Biyoloji',
          ];
        });
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      // Load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getStringList('recent_searches') ?? [];
      
      if (mounted) {
        setState(() {
          _recentSearches = recentSearchesJson;
        });
      }
    } catch (e) {
      debugPrint('Recent searches loading error: $e');
      // Fallback to empty list
      if (mounted) {
        setState(() {
          _recentSearches = [];
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final results = await _apiService.searchTeachers(
        query: query.trim(),
        page: 1,
        perPage: 50,
      );
      
      if (mounted) {
        setState(() {
          _searchResults = (results['data'] as List)
              .map((json) => Teacher.fromJson(json))
              .toList();
          _isSearching = false;
        });
        
        // Recent searches'e ekle
        await _addToRecentSearches(query.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _addToRecentSearches(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearches = prefs.getStringList('recent_searches') ?? [];
      
      // Remove if already exists
      recentSearches.remove(query);
      
      // Add to beginning
      recentSearches.insert(0, query);
      
      // Keep only last 10 searches
      if (recentSearches.length > 10) {
        recentSearches.removeRange(10, recentSearches.length);
      }
      
      await prefs.setStringList('recent_searches', recentSearches);
      
      // Update local state
      if (mounted) {
        setState(() {
          _recentSearches = recentSearches;
        });
      }
    } catch (e) {
      debugPrint('Error saving recent search: $e');
      // Fallback to local state only
      if (_recentSearches.contains(query)) {
        _recentSearches.remove(query);
      }
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _hasSearched = false;
      _searchResults = [];
      _error = null;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Search Bar
              _buildSearchBar(),
              
              // Content
              Expanded(
                child: _hasSearched ? _buildSearchResults() : _buildSearchSuggestions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Öğretmen Ara',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF8FAFC),
      foregroundColor: AppTheme.textPrimary,
      toolbarHeight: 50,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Öğretmen, ders veya konu ara...',
          hintStyle: TextStyle(color: AppTheme.grey600, fontSize: 14), // Daha açık renk
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.grey600, size: 20), // Daha açık renk
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppTheme.grey500, size: 18),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (value) {
          setState(() {});
        },
        onSubmitted: _performSearch,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            _buildSectionTitle('Son Aramalar', Icons.history_rounded),
            const SizedBox(height: 8),
            _buildSearchChips(_recentSearches, isRecent: true),
            const SizedBox(height: 16),
          ],
          
          // Popular Searches
          if (_popularSearches.isNotEmpty) ...[
            _buildSectionTitle('Popüler Aramalar', Icons.trending_up_rounded),
            const SizedBox(height: 8),
            _buildSearchChips(_popularSearches),
            const SizedBox(height: 16),
          ],
          
          // Trending Teachers
          if (_trendingTeachers.isNotEmpty) ...[
            _buildSectionTitle('Trend Öğretmenler', Icons.local_fire_department_rounded),
            const SizedBox(height: 8),
            _buildTrendingTeachers(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChips(List<String> searches, {bool isRecent = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: searches.map((search) => _buildSearchChip(
        search,
        isRecent: isRecent,
        onTap: () {
          _searchController.text = search;
          _performSearch(search);
        },
      )).toList(),
    );
  }

  Widget _buildSearchChip(String search, {bool isRecent = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRecent ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRecent ? AppTheme.primaryBlue.withValues(alpha: 0.3) : AppTheme.grey300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecent ? Icons.history_rounded : Icons.trending_up_rounded,
              size: 14,
              color: isRecent ? AppTheme.primaryBlue : AppTheme.grey600,
            ),
            const SizedBox(width: 4),
            Text(
              search,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isRecent ? AppTheme.primaryBlue : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTeachers() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _trendingTeachers.length,
        itemBuilder: (context, index) {
          final teacher = _trendingTeachers[index];
          return Container(
            width: 100,
            margin: EdgeInsets.only(right: index == _trendingTeachers.length - 1 ? 0 : 12),
            child: _buildTrendingTeacherCard(teacher),
          );
        },
      ),
    );
  }

  Widget _buildTrendingTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () => _navigateToTeacherDetail(teacher),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha: 0.1),
                      AppTheme.primaryBlue.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    child: Text(
                      teacher.user?.name?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Teacher Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.user?.name ?? 'İsimsiz',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Aranıyor...',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyResults();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final teacher = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSearchResultCard(teacher),
        );
      },
    );
  }

  Widget _buildSearchResultCard(Teacher teacher) {
    return GestureDetector(
      onTap: () => _navigateToTeacherDetail(teacher),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Image
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              child: Text(
                teacher.user?.name?.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Teacher Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.user?.name ?? 'İsimsiz',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher.categories?.isNotEmpty == true 
                        ? teacher.categories!.first.name 
                        : 'Genel',
                    style: TextStyle(
                      color: AppTheme.grey600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.attach_money_rounded, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${teacher.priceHour?.toInt() ?? 0}/sa',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.grey400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Arama hatası',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Bilinmeyen hata',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _performSearch(_searchController.text),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arama teriminizi değiştirerek tekrar deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Temizle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
