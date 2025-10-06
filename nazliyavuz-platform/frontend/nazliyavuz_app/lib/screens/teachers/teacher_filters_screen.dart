import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';

class TeacherFiltersScreen extends StatefulWidget {
  final String selectedCategory;
  final double minPrice;
  final double maxPrice;
  final double minRating;
  final bool onlineOnly;
  final String sortBy;
  final Function(Map<String, dynamic>) onFiltersApplied;

  const TeacherFiltersScreen({
    super.key,
    required this.selectedCategory,
    required this.minPrice,
    required this.maxPrice,
    required this.minRating,
    required this.onlineOnly,
    required this.sortBy,
    required this.onFiltersApplied,
  });

  @override
  State<TeacherFiltersScreen> createState() => _TeacherFiltersScreenState();
}

class _TeacherFiltersScreenState extends State<TeacherFiltersScreen> {
  final ApiService _apiService = ApiService();
  
  late String _selectedCategory;
  late double _minPrice;
  late double _maxPrice;
  late double _minRating;
  late bool _onlineOnly;
  late String _sortBy;
  
  List<Category> _categories = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'rating', 'label': 'En Yüksek Puan', 'icon': Icons.star_rounded},
    {'value': 'price_low', 'label': 'En Düşük Fiyat', 'icon': Icons.attach_money_rounded},
    {'value': 'price_high', 'label': 'En Yüksek Fiyat', 'icon': Icons.monetization_on_rounded},
    {'value': 'recent', 'label': 'En Yeni', 'icon': Icons.schedule_rounded},
    {'value': 'popular', 'label': 'En Popüler', 'icon': Icons.trending_up_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _minRating = widget.minRating;
    _onlineOnly = widget.onlineOnly;
    _sortBy = widget.sortBy;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final filters = {
      'category': _selectedCategory,
      'minPrice': _minPrice,
      'maxPrice': _maxPrice,
      'minRating': _minRating,
      'onlineOnly': _onlineOnly,
      'sortBy': _sortBy,
    };
    
    widget.onFiltersApplied(filters);
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = '';
      _minPrice = 0;
      _maxPrice = 1000;
      _minRating = 0;
      _onlineOnly = false;
      _sortBy = 'rating';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gelişmiş Filtreler',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              'Sıfırla',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategori Seçimi
                  _buildSection(
                    title: 'Kategori',
                    icon: Icons.category_rounded,
                    child: _buildCategorySection(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Fiyat Aralığı
                  _buildSection(
                    title: 'Fiyat Aralığı',
                    icon: Icons.attach_money_rounded,
                    child: _buildPriceSection(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Minimum Puan
                  _buildSection(
                    title: 'Minimum Puan',
                    icon: Icons.star_rounded,
                    child: _buildRatingSection(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Online Müsaitlik
                  _buildSection(
                    title: 'Online Müsaitlik',
                    icon: Icons.online_prediction_rounded,
                    child: _buildOnlineSection(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sıralama
                  _buildSection(
                    title: 'Sıralama',
                    icon: Icons.sort_rounded,
                    child: _buildSortSection(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Uygula Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Filtreleri Uygula',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildCategoryChip(
          label: 'Tümü',
          isSelected: _selectedCategory.isEmpty,
          onTap: () => setState(() => _selectedCategory = ''),
        ),
        ..._categories.map((category) => _buildCategoryChip(
          label: category.name,
          isSelected: _selectedCategory == category.slug,
          onTap: () => setState(() => _selectedCategory = category.slug),
        )),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.grey300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₺${_minPrice.toInt()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '₺${_maxPrice.toInt()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000,
          divisions: 100,
          activeColor: AppTheme.primaryBlue,
          inactiveColor: AppTheme.grey300,
          onChanged: (values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₺0',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
            Text(
              '₺1000',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Minimum Puan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_minRating.toStringAsFixed(1)}+',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Slider(
          value: _minRating,
          min: 0,
          max: 5,
          divisions: 50,
          activeColor: AppTheme.primaryBlue,
          inactiveColor: AppTheme.grey300,
          onChanged: (value) {
            setState(() {
              _minRating = value;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
            Text(
              '5.0',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sadece Online Öğretmenler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Şu anda müsait olan öğretmenleri göster',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
        Switch(
          value: _onlineOnly,
          onChanged: (value) {
            setState(() {
              _onlineOnly = value;
            });
            HapticFeedback.lightImpact();
          },
          activeColor: AppTheme.primaryBlue,
        ),
      ],
    );
  }

  Widget _buildSortSection() {
    return Column(
      children: _sortOptions.map((option) => _buildSortOption(
        option: option,
        isSelected: _sortBy == option['value'],
        onTap: () => setState(() => _sortBy = option['value']),
      )).toList(),
    );
  }

  Widget _buildSortOption({
    required Map<String, dynamic> option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.grey300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option['icon'],
              color: isSelected ? AppTheme.primaryBlue : AppTheme.grey600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option['label'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
