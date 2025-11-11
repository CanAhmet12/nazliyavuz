import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/teacher_card.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Teacher> _teachers = [];
  List<Teacher> _filteredTeachers = [];
  List<Category> _mainCategories = [];
  List<Category> _subCategories = [];
  Set<int> _favoriteTeacherIds = {}; // Track favorite teachers
  bool _isLoading = false;
  bool _isGridView = false;
  bool _showAdvancedFilters = false;
  List<Category> _selectedMainCategories = [];
  List<Category> _selectedSubCategories = [];
  String _sortBy = 'rating';
  String? _error;
  
  // Advanced filter variables
  List<Category> _categories = [];
  Set<int> _selectedCategories = {};
  double _minPrice = 0;
  double _maxPrice = 1000;
  int _experienceYears = 0;
  double _minRating = 0.0;
  List<String> _selectedLanguages = [];
  List<String> _selectedEducation = [];

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'rating', 'label': 'En Yüksek Puan'},
    {'value': 'price_low', 'label': 'En Düşük Fiyat'},
    {'value': 'price_high', 'label': 'En Yüksek Fiyat'},
    {'value': 'recent', 'label': 'En Yeni'},
    {'value': 'popular', 'label': 'En Popüler'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _loadTeachers(),
        _loadCategories(),
        _loadFavorites(),
      ]);

      if (mounted) {
        setState(() {
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

  Future<void> _loadTeachers() async {
    try {
      // Seçilen kategorilerin ID'lerini topla
      List<int> selectedCategoryIds = [];
      
      // Ana kategorileri ekle
      selectedCategoryIds.addAll(_selectedMainCategories.map((c) => c.id).toList());
      
      // Ana kategorilere ait alt kategorileri bul ve ekle
      for (var mainCategory in _selectedMainCategories) {
        var subCategories = _subCategories.where((cat) => cat.parentId == mainCategory.id).toList();
        selectedCategoryIds.addAll(subCategories.map((c) => c.id).toList());
      }
      
      // Manuel seçilen alt kategorileri ekle
      selectedCategoryIds.addAll(_selectedSubCategories.map((c) => c.id).toList());
      
      if (foundation.kDebugMode) {
        print('🔍 ====== FILTER DEBUG ======');
        print('🔍 Selected Main Categories: ${_selectedMainCategories.map((c) => '${c.name}(${c.id})').toList()}');
        print('🔍 Selected Sub Categories: ${_selectedSubCategories.map((c) => '${c.name}(${c.id})').toList()}');
        print('🔍 Combined Category IDs (including subcategories): $selectedCategoryIds');
        print('🔍 Sort By: $_sortBy');
        print('🔍 Search Text: ${_searchController.text}');
        print('🔍 ========================');
      }
      
      final teachers = await _apiService.getTeachers(
        categoryIds: selectedCategoryIds.isNotEmpty ? selectedCategoryIds : null,
        sortBy: _sortBy,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      if (foundation.kDebugMode) {
        print('🔍 Loaded ${teachers.length} teachers from API');
      }

      if (mounted) {
        setState(() {
          _teachers = teachers;
          _filteredTeachers = teachers;
          _isLoading = false;
        });
        
        // Fallback removed - show empty state if no teachers match filters
        if (foundation.kDebugMode) {
          print('🔍 ${teachers.length} teachers loaded with current filters');
        }
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        print('🔍 Error loading teachers: $e');
      }
      
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          // Ana kategorileri ve alt kategorileri ayır
          _mainCategories = categories.where((c) => c.parentId == null).toList();
          _subCategories = categories.where((c) => c.parentId != null).toList();
        });
      }
    } catch (e) {
      // Categories loading error, continue with empty list
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _apiService.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteTeacherIds = favorites.map((teacher) => teacher.id).where((id) => id != null).cast<int>().toSet();
        });
      }
    } catch (e) {
      // Favorites loading error, continue with empty set
      if (foundation.kDebugMode) {
        print('🔍 Error loading favorites: $e');
      }
    }
  }

  Future<void> _toggleFavorite(Teacher teacher) async {
    try {
      final teacherId = teacher.id;
      if (teacherId == null) {
        if (foundation.kDebugMode) {
          print('🔍 Teacher ID is null, cannot toggle favorite');
        }
        return;
      }
      
      final isFavorite = _favoriteTeacherIds.contains(teacherId);
      
      if (isFavorite) {
        await _apiService.removeFromFavorites(teacherId);
        if (mounted) {
          setState(() {
            _favoriteTeacherIds.remove(teacherId);
          });
        }
      } else {
        await _apiService.addToFavorites(teacherId);
        if (mounted) {
          setState(() {
            _favoriteTeacherIds.add(teacherId);
          });
        }
      }
      
      if (foundation.kDebugMode) {
        print('🔍 Toggled favorite for teacher $teacherId: ${!isFavorite}');
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        print('🔍 Error toggling favorite: $e');
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Favori durumu güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterTeachers() {
    // API'ye filtreleme parametrelerini gönder
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadTeachers();
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
              // Search and Filters
              _buildSearchAndFilters(),
              
              // Results
              Expanded(
                child: _isLoading
                    ? CustomWidgets.customLoading(message: 'Eğitimciler yükleniyor...')
                    : _error != null
                        ? _buildErrorState()
                        : _filteredTeachers.isEmpty
                            ? _buildEmptyState()
                            : _buildResults(),
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
        'Eğitimci Ara',
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
      actions: [
        IconButton(
          icon: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar - Tek sıra
          _buildSearchBar(),
          
          const SizedBox(height: 12),
          
          // Filter Buttons - Alt sıra, aynı genişlikte
          Row(
            children: [
              Expanded(child: _buildAdvancedFiltersButton()),
              const SizedBox(width: 8),
              Expanded(child: _buildSortButton()),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quick Filters
          _buildQuickFilters(),
          
          const SizedBox(height: 12),
          
          // Advanced Filters Panel - Only show when toggled
          if (_showAdvancedFilters) _buildAdvancedFiltersPanel(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          _filterTeachers();
        },
        decoration: InputDecoration(
          hintText: 'İsim, konu veya beceri ara...',
          hintStyle: TextStyle(
            color: Colors.grey[600], // Daha açık renk
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.grey400,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppTheme.grey400,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _filterTeachers();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            'Tümü',
            _selectedMainCategories.isEmpty && _selectedSubCategories.isEmpty,
            () {
              setState(() {
                _selectedMainCategories.clear();
                _selectedSubCategories.clear();
              });
              _filterTeachers();
            },
          ),
          const SizedBox(width: 6),
          ..._mainCategories.take(6).map((category) {
            final isSelected = _selectedMainCategories.contains(category);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterChip(
                category.name,
                isSelected,
                () {
                  setState(() {
                    if (isSelected) {
                      _selectedMainCategories.remove(category);
                      // Bu ana kategoriye ait alt kategorileri de kaldır
                      _selectedSubCategories.removeWhere((sub) => sub.parentId == category.id);
                    } else {
                      _selectedMainCategories.add(category);
                    }
                  });
                  _filterTeachers();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.grey100,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(color: AppTheme.grey300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.grey700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFiltersButton() {
    return Container(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _toggleAdvancedFilters,
        icon: Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryBlue),
        label: Text(
          'Filtreler',
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return Container(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _showSortOptions,
        icon: Icon(Icons.sort_rounded, size: 16, color: AppTheme.accentGreen),
        label: Text(
          _sortOptions.firstWhere((option) => option['value'] == _sortBy)['label'],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentGreen,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.accentGreen.withOpacity(0.3)),
          backgroundColor: AppTheme.accentGreen.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Results Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredTeachers.length} eğitimci',
                style: TextStyle(
                  color: AppTheme.grey700,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedMainCategories.clear();
                    _selectedSubCategories.clear();
                    _sortBy = 'rating';
                  });
                  _filterTeachers();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: Text(
                  'Temizle',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Teachers List/Grid
        Expanded(
          child: _isGridView
              ? _buildGridView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TeacherCard(
            teacher: teacher,
            isFavorite: teacher.id != null && _favoriteTeacherIds.contains(teacher.id),
            onTap: null, // Rezerve Et butonunun çalışması için null yapıyoruz
            onFavoriteToggle: () {
              HapticFeedback.lightImpact();
              _toggleFavorite(teacher);
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // Overflow için daha küçük
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];
        return TeacherGridCard(
          teacher: teacher,
          isFavorite: teacher.id != null && _favoriteTeacherIds.contains(teacher.id),
          onTap: null, // Rezerve Et butonunun çalışması için null yapıyoruz
          onFavoriteToggle: () {
            HapticFeedback.lightImpact();
            _toggleFavorite(teacher);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Eğitimci bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Arama kriterlerinizi değiştirerek tekrar deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedMainCategories.clear();
                  _selectedSubCategories.clear();
                });
                _filterTeachers();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Filtreleri Temizle'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Gelişmiş Filtreler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
              
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori Filtreleri
                      Text(
                        'Kategoriler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((category) {
                          final isSelected = _selectedCategories.contains(category.id);
                          return FilterChip(
                            label: Text(category.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedCategories.add(category.id);
                                } else {
                                  _selectedCategories.remove(category.id);
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                            checkmarkColor: AppTheme.primaryBlue,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primaryBlue : AppTheme.grey700,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Fiyat Aralığı
                      Text(
                        'Fiyat Aralığı',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _minPrice.toString()),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min Fiyat',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) {
                                _minPrice = double.tryParse(value) ?? 0;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _maxPrice.toString()),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max Fiyat',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) {
                                _maxPrice = double.tryParse(value) ?? 1000;
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Deneyim Yılı
                      Text(
                        'Deneyim Yılı',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _experienceYears.toDouble(),
                        min: 0,
                        max: 20,
                        divisions: 20,
                        label: '${_experienceYears} yıl',
                        onChanged: (value) {
                          setModalState(() {
                            _experienceYears = value.round();
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Konum
                      Text(
                        'Konum',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Location filter removed as requested
                    ],
                  ),
                ),
              ),
              
              // Apply Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Filtreleri Uygula',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyFilters() {
    // Apply advanced filters to teacher list
    _filteredTeachers = _teachers.where((teacher) {
      // Category filter
      if (_selectedCategories.isNotEmpty) {
        bool hasSelectedCategory = false;
        for (int categoryId in _selectedCategories) {
          if (teacher.categories?.any((cat) => cat.id == categoryId) ?? false) {
            hasSelectedCategory = true;
            break;
          }
        }
        if (!hasSelectedCategory) return false;
      }
      
      // Price filter
      final price = teacher.priceHour ?? 0;
      if (price < _minPrice || price > _maxPrice) {
        return false;
      }
      
      // Experience filter
      final experience = teacher.experienceYears ?? 0;
      if (experience < _experienceYears) {
        return false;
      }
      
      // Rating filter
      final rating = teacher.ratingAvg ?? 0;
      if (rating < _minRating) {
        return false;
      }
      
      // Language filter
      if (_selectedLanguages.isNotEmpty) {
        final teacherLanguages = (teacher.languages ?? '').toString();
        bool hasSelectedLanguage = false;
        for (String language in _selectedLanguages) {
          if (teacherLanguages.toLowerCase().contains(language.toLowerCase())) {
            hasSelectedLanguage = true;
            break;
          }
        }
        if (!hasSelectedLanguage) return false;
      }
      
      // Education filter
      if (_selectedEducation.isNotEmpty) {
        final teacherEducation = (teacher.education ?? '').toString();
        bool hasSelectedEducation = false;
        for (String education in _selectedEducation) {
          if (teacherEducation.toLowerCase().contains(education.toLowerCase())) {
            hasSelectedEducation = true;
            break;
          }
        }
        if (!hasSelectedEducation) return false;
      }
      
      return true;
    }).toList();
    
    // Apply sorting
    _applySorting();
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'rating':
        _filteredTeachers.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'price_low':
        _filteredTeachers.sort((a, b) => (a.priceHour ?? 0).compareTo(b.priceHour ?? 0));
        break;
      case 'price_high':
        _filteredTeachers.sort((a, b) => (b.priceHour ?? 0).compareTo(a.priceHour ?? 0));
        break;
      case 'recent':
        _filteredTeachers.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
        break;
      case 'popular':
        _filteredTeachers.sort((a, b) => (b.totalStudents ?? 0).compareTo(a.totalStudents ?? 0));
        break;
    }
  }

  void _showCategoryFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Kategori Filtreleri',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ana Kategoriler
                      _buildCategorySection(
                        'Ana Kategoriler',
                        _mainCategories,
                        _selectedMainCategories,
                        (category, isSelected) {
                          setModalState(() {
                            if (isSelected) {
                              _selectedMainCategories.remove(category);
                              _selectedSubCategories.removeWhere((sub) => sub.parentId == category.id);
                            } else {
                              _selectedMainCategories.add(category);
                            }
                          });
                        },
                      ),
                      
                      if (_selectedMainCategories.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        
                        // Alt Kategoriler
                        _buildSubCategorySection(
                          'Uzmanlık Alanları',
                          _selectedMainCategories,
                          _selectedSubCategories,
                          (category, isSelected) {
                            setModalState(() {
                              if (isSelected) {
                                _selectedSubCategories.remove(category);
                              } else {
                                _selectedSubCategories.add(category);
                              }
                            });
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Footer Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedMainCategories.clear();
                            _selectedSubCategories.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.grey300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Temizle',
                          style: TextStyle(
                            color: AppTheme.grey700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          _filterTeachers();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Uygula',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Category> categories,
    List<Category> selectedCategories,
    Function(Category, bool) onCategoryToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = selectedCategories.contains(category);
            return GestureDetector(
              onTap: () => onCategoryToggle(category, isSelected),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: AppTheme.grey300),
                ),
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.grey700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubCategorySection(
    String title,
    List<Category> selectedMainCategories,
    List<Category> selectedSubCategories,
    Function(Category, bool) onCategoryToggle,
  ) {
    // Seçilen ana kategorilere ait alt kategorileri filtrele
    final availableSubCategories = _subCategories.where((sub) =>
        selectedMainCategories.any((main) => main.id == sub.parentId)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        if (availableSubCategories.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Text(
              'Önce ana kategori seçin',
              style: TextStyle(
                color: AppTheme.grey500,
                fontSize: 14,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSubCategories.map((category) {
              final isSelected = selectedSubCategories.contains(category);
              return GestureDetector(
                onTap: () => onCategoryToggle(category, isSelected),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentGreen : AppTheme.grey100,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: AppTheme.grey300),
                  ),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.grey700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Sıralama Seçenekleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 24),
                
                ..._sortOptions.map((option) {
                  final isSelected = _sortBy == option['value'];
                  return ListTile(
                    title: Text(
                      option['label'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.grey700, // Daha koyu gri
                        fontSize: 15, // Biraz büyük yazı
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _sortBy = option['value'];
                      });
                      _filterTeachers();
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                  );
                }),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Eğitimci bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Arama kriterlerinizi değiştirerek tekrar deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInitialData,
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
      ),
    );
  }

  Widget _buildAdvancedFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gelişmiş Filtreler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedMainCategories.clear();
                    _selectedSubCategories.clear();
                    _selectedCategories.clear();
                    _selectedLanguages.clear();
                    _selectedEducation.clear();
                    _minPrice = 0;
                    _maxPrice = 1000;
                    _experienceYears = 0;
                    _minRating = 0.0;
                    _sortBy = 'rating';
                  });
                  _applyFilters();
                },
                child: const Text(
                  'Temizle',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Price Range Filter
          _buildPriceRangeFilter(),
          const SizedBox(height: 16),
          
          // Language Filter
          _buildLanguageFilter(),
          const SizedBox(height: 16),
          
          // Education Filter
          _buildEducationFilter(),
          const SizedBox(height: 16),
          
          // Experience Filter
          _buildExperienceFilter(),
          const SizedBox(height: 16),
          
          // Rating Filter
          _buildRatingFilter(),
          const SizedBox(height: 16),
          
          // Availability Filter
          _buildAvailabilityFilter(),
        ],
      ),
    );
  }

  Widget _buildPriceRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiyat Aralığı',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Min Fiyat',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minPrice = double.tryParse(value) ?? 0;
                  });
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Max Fiyat',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _maxPrice = double.tryParse(value) ?? 1000;
                  });
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _minPrice,
                min: 0,
                max: 1000,
                divisions: 100,
                label: '₺${_minPrice.toInt()}',
                onChanged: (value) {
                  setState(() {
                    _minPrice = value;
                  });
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Slider(
                value: _maxPrice,
                min: 0,
                max: 1000,
                divisions: 100,
                label: '₺${_maxPrice.toInt()}',
                onChanged: (value) {
                  setState(() {
                    _maxPrice = value;
                  });
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dil',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            'Türkçe',
            'İngilizce',
            'Almanca',
            'Fransızca',
            'İspanyolca',
          ].map((language) => _buildFilterChip(
            language,
            _selectedLanguages.contains(language),
            () {
              setState(() {
                if (_selectedLanguages.contains(language)) {
                  _selectedLanguages.remove(language);
                } else {
                  _selectedLanguages.add(language);
                }
              });
              _applyFilters();
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildEducationFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eğitim Seviyesi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            'Lisans',
            'Yüksek Lisans',
            'Doktora',
            'Sertifika',
          ].map((education) => _buildFilterChip(
            education,
            _selectedEducation.contains(education),
            () {
              setState(() {
                if (_selectedEducation.contains(education)) {
                  _selectedEducation.remove(education);
                } else {
                  _selectedEducation.add(education);
                }
              });
              _applyFilters();
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildExperienceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deneyim Yılı',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _experienceYears.toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                label: '${_experienceYears} yıl',
                onChanged: (value) {
                  setState(() {
                    _experienceYears = value.round();
                  });
                  _applyFilters();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_experienceYears} yıl',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minimum Puan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 10,
                label: '${_minRating.toStringAsFixed(1)} ⭐',
                onChanged: (value) {
                  setState(() {
                    _minRating = value;
                  });
                  _applyFilters();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_minRating.toStringAsFixed(1)} ⭐',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Müsaitlik',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text(
                  'Şimdi Müsait',
                  style: TextStyle(fontSize: 14),
                ),
                value: false, // You can track this state
                onChanged: (value) {
                  // Handle availability change
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: const Text(
                  'Online Ders',
                  style: TextStyle(fontSize: 14),
                ),
                value: false, // You can track this state
                onChanged: (value) {
                  // Handle online lesson preference
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}