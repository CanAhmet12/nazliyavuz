import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../teachers/teacher_detail_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Teacher> _teachers = [];
  List<Category> _categories = [];
  List<String> _languages = [];
  List<String> _suggestions = [];
  List<String> _popularSearches = [];
  
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  
  // Filter states
  String? _selectedCategory;
  double? _priceMin;
  double? _priceMax;
  double? _ratingMin;
  String? _selectedLanguage;
  String? _selectedLocation;
  bool _onlineOnly = false;
  String _sortBy = 'rating_desc';
  
  int _currentPage = 1;
  int _totalResults = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final filters = await _apiService.getSearchFilters();
      final popular = await _apiService.getPopularSearches();
      
      setState(() {
        _categories = (filters['categories'] as List)
            .map((json) => Category.fromJson(json))
            .toList();
        _languages = List<String>.from(filters['languages']);
        _popularSearches = popular.map((p) => p.toString()).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performSearch({bool isNewSearch = true}) async {
    if (isNewSearch) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.searchTeachers(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: _selectedCategory,
        minPrice: _priceMin,
        maxPrice: _priceMax,
        rating: _ratingMin,
        location: _selectedLocation,
        sortBy: _sortBy,
        page: _currentPage,
        perPage: 20,
      );

      setState(() {
        if (isNewSearch) {
          _teachers = (result['data'] as List)
              .map((json) => Teacher.fromJson(json))
              .toList();
        } else {
          _teachers.addAll((result['data'] as List)
              .map((json) => Teacher.fromJson(json))
              .toList());
        }
        
        _totalResults = result['meta']['total'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await _apiService.getSearchSuggestions(query);
      setState(() {
        _suggestions = suggestions.map((s) => s['text'] as String).toList();
        _showSuggestions = true;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişmiş Arama'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showSuggestions) _buildSuggestionsList(),
          _buildFilterChips(),
          Expanded(
            child: _teachers.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Öğretmen, kategori veya beceri ara...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isLoadingSuggestions
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          _getSuggestions(value);
        },
        onSubmitted: (value) {
          _showSuggestions = false;
          _performSearch();
        },
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_suggestions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Öneriler',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._suggestions.map((suggestion) => ListTile(
              title: Text(suggestion),
              onTap: () {
                _searchController.text = suggestion;
                _showSuggestions = false;
                _performSearch();
              },
            )),
          ],
          if (_popularSearches.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Popüler Aramalar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._popularSearches.take(5).map((search) => ListTile(
              title: Text(search),
              leading: const Icon(Icons.trending_up, size: 16),
              onTap: () {
                _searchController.text = search;
                _showSuggestions = false;
                _performSearch();
              },
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedCategory != null)
            _buildFilterChip(
              'Kategori: ${_getCategoryName(_selectedCategory!)}',
              () => setState(() => _selectedCategory = null),
            ),
          if (_priceMin != null || _priceMax != null)
            _buildFilterChip(
              'Fiyat: ${_priceMin?.toStringAsFixed(0) ?? '0'}-${_priceMax?.toStringAsFixed(0) ?? '∞'} TL',
              () => setState(() {
                _priceMin = null;
                _priceMax = null;
              }),
            ),
          if (_ratingMin != null)
            _buildFilterChip(
              'Rating: ${_ratingMin!.toStringAsFixed(1)}+',
              () => setState(() => _ratingMin = null),
            ),
          if (_selectedLanguage != null)
            _buildFilterChip(
              'Dil: $_selectedLanguage',
              () => setState(() => _selectedLanguage = null),
            ),
          if (_onlineOnly)
            _buildFilterChip(
              'Sadece Online',
              () => setState(() => _onlineOnly = false),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
        ),
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
            'Arama sonucu bulunamadı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı anahtar kelimeler veya filtreler deneyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: [
        if (_totalResults > 0)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalResults sonuç bulundu',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'rating_desc', child: Text('En Yüksek Puan')),
                    DropdownMenuItem(value: 'rating_asc', child: Text('En Düşük Puan')),
                    DropdownMenuItem(value: 'price_asc', child: Text('En Ucuz')),
                    DropdownMenuItem(value: 'price_desc', child: Text('En Pahalı')),
                    DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
                    DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
                  ],
                  onChanged: (value) {
                    setState(() => _sortBy = value!);
                    _performSearch();
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _teachers.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _teachers.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final teacher = _teachers[index];
              return _buildTeacherCard(teacher);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherCard(Teacher teacher) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TeacherDetailScreen(teacher: teacher),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: teacher.user?.profilePhotoUrl != null
                    ? NetworkImage(teacher.user!.profilePhotoUrl!)
                    : null,
                child: teacher.user?.profilePhotoUrl == null
                    ? Text(
                        teacher.user?.name.isNotEmpty ?? false
                            ? teacher.user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name.isNotEmpty ?? false ? teacher.user!.name : 'İsimsiz',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (teacher.bio?.isNotEmpty ?? false)
                      Text(
                        teacher.bio!.length > 100
                            ? '${teacher.bio!.substring(0, 100)}...'
                            : teacher.bio!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (teacher.ratingAvg > 0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${teacher.ratingAvg.toStringAsFixed(1)} (${teacher.ratingCount})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Text(
                          '${teacher.priceHour?.toStringAsFixed(0) ?? '0'} TL/saat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterBottomSheet(
        categories: _categories,
        languages: _languages,
        selectedCategory: _selectedCategory,
        priceMin: _priceMin,
        priceMax: _priceMax,
        ratingMin: _ratingMin,
        selectedLanguage: _selectedLanguage,
        selectedLocation: _selectedLocation,
        onlineOnly: _onlineOnly,
        sortBy: _sortBy,
        onApplyFilters: (filters) {
          setState(() {
            _selectedCategory = filters['category'];
            _priceMin = filters['priceMin'];
            _priceMax = filters['priceMax'];
            _ratingMin = filters['ratingMin'];
            _selectedLanguage = filters['language'];
            _selectedLocation = filters['location'];
            _onlineOnly = filters['onlineOnly'];
            _sortBy = filters['sortBy'];
          });
          _performSearch();
        },
      ),
    );
  }

  String _getCategoryName(String slug) {
    final category = _categories.firstWhere(
      (cat) => cat.slug == slug,
      orElse: () => Category(
        id: 0,
        name: slug,
        slug: slug,
      ),
    );
    return category.name;
  }

}

class _FilterBottomSheet extends StatefulWidget {
  final List<Category> categories;
  final List<String> languages;
  final String? selectedCategory;
  final double? priceMin;
  final double? priceMax;
  final double? ratingMin;
  final String? selectedLanguage;
  final String? selectedLocation;
  final bool onlineOnly;
  final String sortBy;
  final Function(Map<String, dynamic>) onApplyFilters;

  const _FilterBottomSheet({
    required this.categories,
    required this.languages,
    required this.selectedCategory,
    required this.priceMin,
    required this.priceMax,
    required this.ratingMin,
    required this.selectedLanguage,
    required this.selectedLocation,
    required this.onlineOnly,
    required this.sortBy,
    required this.onApplyFilters,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _selectedCategory;
  late double? _priceMin;
  late double? _priceMax;
  late double? _ratingMin;
  late String? _selectedLanguage;
  late String? _selectedLocation;
  late bool _onlineOnly;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _priceMin = widget.priceMin;
    _priceMax = widget.priceMax;
    _ratingMin = widget.ratingMin;
    _selectedLanguage = widget.selectedLanguage;
    _selectedLocation = widget.selectedLocation;
    _onlineOnly = widget.onlineOnly;
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtreler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _priceMin = null;
                    _priceMax = null;
                    _ratingMin = null;
                    _selectedLanguage = null;
                    _selectedLocation = null;
                    _onlineOnly = false;
                    _sortBy = 'rating_desc';
                  });
                },
                child: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryFilter(),
                  const SizedBox(height: 24),
                  _buildPriceFilter(),
                  const SizedBox(height: 24),
                  _buildRatingFilter(),
                  const SizedBox(height: 24),
                  _buildLanguageFilter(),
                  const SizedBox(height: 24),
                  _buildOnlineFilter(),
                  const SizedBox(height: 24),
                  _buildSortFilter(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApplyFilters({
                  'category': _selectedCategory,
                  'priceMin': _priceMin,
                  'priceMax': _priceMax,
                  'ratingMin': _ratingMin,
                  'language': _selectedLanguage,
                  'location': _selectedLocation,
                  'onlineOnly': _onlineOnly,
                  'sortBy': _sortBy,
                });
                Navigator.of(context).pop();
              },
              child: const Text('Filtreleri Uygula'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.categories.map((category) {
            final isSelected = _selectedCategory == category.slug;
            return FilterChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category.slug : null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiyat Aralığı (TL/saat)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _priceMin = double.tryParse(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _priceMax = double.tryParse(value);
                },
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
          'Minimum Rating',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('4.5+ ⭐'),
              selected: _ratingMin == 4.5,
              onSelected: (selected) {
                setState(() {
                  _ratingMin = selected ? 4.5 : null;
                });
              },
            ),
            FilterChip(
              label: const Text('4.0+ ⭐'),
              selected: _ratingMin == 4.0,
              onSelected: (selected) {
                setState(() {
                  _ratingMin = selected ? 4.0 : null;
                });
              },
            ),
            FilterChip(
              label: const Text('3.5+ ⭐'),
              selected: _ratingMin == 3.5,
              onSelected: (selected) {
                setState(() {
                  _ratingMin = selected ? 3.5 : null;
                });
              },
            ),
            FilterChip(
              label: const Text('3.0+ ⭐'),
              selected: _ratingMin == 3.0,
              onSelected: (selected) {
                setState(() {
                  _ratingMin = selected ? 3.0 : null;
                });
              },
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.languages.map((language) {
            final isSelected = _selectedLanguage == language;
            return FilterChip(
              label: Text(language),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedLanguage = selected ? language : null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOnlineFilter() {
    return Row(
      children: [
        Checkbox(
          value: _onlineOnly,
          onChanged: (value) {
            setState(() {
              _onlineOnly = value ?? false;
            });
          },
        ),
        const Text('Sadece Online Dersler'),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sıralama',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'rating_desc', child: Text('En Yüksek Puan')),
            DropdownMenuItem(value: 'rating_asc', child: Text('En Düşük Puan')),
            DropdownMenuItem(value: 'price_asc', child: Text('En Ucuz')),
            DropdownMenuItem(value: 'price_desc', child: Text('En Pahalı')),
            DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
            DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
          ],
          onChanged: (value) {
            setState(() {
              _sortBy = value!;
            });
          },
        ),
      ],
    );
  }
}
