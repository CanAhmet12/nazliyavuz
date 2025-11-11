import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/filter_cache_service.dart';
import '../../services/smart_filter_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_filter_widget.dart';
import '../../widgets/unified_filter_widget.dart';

/// Gelişmiş filtre yönetim ekranı
class AdvancedFilterScreen extends StatefulWidget {
  final String context;
  final List<FilterOption> availableFilters;
  final Function(Map<String, dynamic>) onFiltersApplied;
  final Map<String, dynamic>? initialFilters;

  const AdvancedFilterScreen({
    super.key,
    required this.context,
    required this.availableFilters,
    required this.onFiltersApplied,
    this.initialFilters,
  });

  @override
  State<AdvancedFilterScreen> createState() => _AdvancedFilterScreenState();
}

class _AdvancedFilterScreenState extends State<AdvancedFilterScreen>
    with TickerProviderStateMixin {
  final FilterCacheService _cacheService = FilterCacheService();
  final SmartFilterService _smartService = SmartFilterService();
  final TextEditingController _filterNameController = TextEditingController();
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  List<Map<String, dynamic>> _savedFilters = [];
  List<Map<String, dynamic>> _smartSuggestions = [];
  Map<String, dynamic> _currentFilters = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _currentFilters = widget.initialFilters ?? {};
    _loadSavedFilters();
    _loadSmartSuggestions();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _filterNameController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFilters() async {
    setState(() => _isLoading = true);
    
    try {
      final savedFilters = await _cacheService.getSavedFilters();
      setState(() {
        _savedFilters = savedFilters
            .where((filter) => filter['context'] == widget.context)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSmartSuggestions() async {
    try {
      final suggestions = await _smartService.getSmartSuggestions(
        context: widget.context,
        availableFilters: widget.availableFilters.map((f) => f.value).toList(),
      );
      setState(() => _smartSuggestions = suggestions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Öneriler yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() => _currentFilters = filters);
    widget.onFiltersApplied(filters);
  }

  Future<void> _saveCurrentFilters() async {
    if (_filterNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen filtre adı girin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _cacheService.saveFilter(
        _filterNameController.text.trim(),
        {
          ..._currentFilters,
          'context': widget.context,
        },
      );
      
      _filterNameController.clear();
      await _loadSavedFilters();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSavedFilter(String name) async {
    try {
      await _cacheService.deleteSavedFilter(name);
      await _loadSavedFilters();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applySmartSuggestion(Map<String, dynamic> suggestion) {
    HapticFeedback.lightImpact();
    _applyFilters(suggestion['filters'] as Map<String, dynamic>);
    
    // Kullanımı kaydet
    _smartService.recordFilterUsage(
      suggestion['name'] as String,
      suggestion['filters'] as Map<String, dynamic>,
    );
  }

  Widget _buildSmartSuggestions() {
    if (_smartSuggestions.isEmpty) return const SizedBox.shrink();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akıllı Öneriler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 12),
            ..._smartSuggestions.map((suggestion) => _buildSuggestionCard(suggestion)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _applySmartSuggestion(suggestion),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getSuggestionColor(suggestion['type'] as String),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getSuggestionIcon(suggestion['type'] as String),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSuggestionColor(String type) {
    switch (type) {
      case 'recent':
        return AppTheme.primaryBlue;
      case 'popular':
        return AppTheme.accentOrange;
      case 'smart':
        return AppTheme.accentGreen;
      default:
        return Colors.grey;
    }
  }

  IconData _getSuggestionIcon(String type) {
    switch (type) {
      case 'recent':
        return Icons.history;
      case 'popular':
        return Icons.trending_up;
      case 'smart':
        return Icons.lightbulb;
      default:
        return Icons.filter_list;
    }
  }

  Widget _buildSavedFilters() {
    if (_savedFilters.isEmpty) return const SizedBox.shrink();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kayıtlı Filtreler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 12),
            ..._savedFilters.map((filter) => _buildSavedFilterCard(filter)),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedFilterCard(Map<String, dynamic> filter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bookmark,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filter['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kaydedildi: ${_formatDate(filter['created_at'] as String)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _applyFilters(filter['filters'] as Map<String, dynamic>),
                    icon: const Icon(Icons.play_arrow),
                    color: AppTheme.primaryBlue,
                  ),
                  IconButton(
                    onPressed: () => _deleteSavedFilter(filter['name'] as String),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Gelişmiş Filtreler'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saveCurrentFilters,
            icon: const Icon(Icons.save),
            tooltip: 'Mevcut Filtreleri Kaydet',
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
                  // Akıllı öneriler
                  _buildSmartSuggestions(),
                  
                  if (_smartSuggestions.isNotEmpty) const SizedBox(height: 24),
                  
                  // Kayıtlı filtreler
                  _buildSavedFilters(),
                  
                  if (_savedFilters.isNotEmpty) const SizedBox(height: 24),
                  
                  // Mevcut filtreler
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: AnimatedFilterWidget(
                        title: 'Mevcut Filtreler',
                        filterOptions: widget.availableFilters,
                        showDateRange: true,
                        showSearch: true,
                        searchHint: 'Ara...',
                        initialFilters: _currentFilters,
                        onFilterChanged: _applyFilters,
                        enableHapticFeedback: true,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Filtre kaydetme
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            const Text(
                              'Filtre Kaydet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.grey900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _filterNameController,
                              decoration: InputDecoration(
                                hintText: 'Filtre adı girin...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.label),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveCurrentFilters,
                                icon: const Icon(Icons.save),
                                label: const Text('Kaydet'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
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
    );
  }
}
