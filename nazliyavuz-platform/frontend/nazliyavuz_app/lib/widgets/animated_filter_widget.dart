import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'unified_filter_widget.dart';

/// Animasyonlu filtre widget'ı
class AnimatedFilterWidget extends StatefulWidget {
  final List<FilterOption> filterOptions;
  final Function(Map<String, dynamic>) onFilterChanged;
  final VoidCallback? onClearFilters;
  final String? title;
  final bool showDateRange;
  final bool showSearch;
  final String? searchHint;
  final Map<String, dynamic>? initialFilters;
  final bool enableHapticFeedback;
  final Duration animationDuration;

  const AnimatedFilterWidget({
    super.key,
    required this.filterOptions,
    required this.onFilterChanged,
    this.onClearFilters,
    this.title,
    this.showDateRange = false,
    this.showSearch = false,
    this.searchHint,
    this.initialFilters,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedFilterWidget> createState() => _AnimatedFilterWidgetState();
}

class _AnimatedFilterWidgetState extends State<AnimatedFilterWidget>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, dynamic> _activeFilters = {};
  DateRangeFilter? _dateRange;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.initialFilters != null) {
      _activeFilters.addAll(widget.initialFilters!);
    }
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Başlangıç animasyonları
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filters = Map<String, dynamic>.from(_activeFilters);
    if (_dateRange != null) {
      filters['date_from'] = _dateRange!.from;
      filters['date_to'] = _dateRange!.to;
    }
    if (_searchController.text.isNotEmpty) {
      filters['search'] = _searchController.text;
    }
    widget.onFilterChanged(filters);
  }

  void _clearFilters() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    setState(() {
      _activeFilters.clear();
      _dateRange = null;
      _searchController.clear();
    });
    
    widget.onClearFilters?.call();
    _applyFilters();
    
    // Temizleme animasyonu
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  void _toggleFilter(String value) {
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
    
    setState(() {
      if (_activeFilters.containsKey(value)) {
        _activeFilters.remove(value);
      } else {
        _activeFilters[value] = true;
      }
    });
    
    // Seçim animasyonu
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    _applyFilters();
  }

  void _showDateRangePicker() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Tarih Aralığı Seçin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAnimatedDateRangeSelector(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _dateRange = null;
                              });
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            child: const Text('Temizle'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Uygula'),
                          ),
                        );
                      },
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

  Widget _buildAnimatedDateRangeSelector() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Column(
            children: [
              _buildAnimatedDateTile(
                icon: Icons.date_range,
                title: 'Başlangıç Tarihi',
                subtitle: _dateRange?.from != null
                    ? DateFormat('dd.MM.yyyy').format(_dateRange!.from!)
                    : 'Seçiniz',
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateRange?.from ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _dateRange = DateRangeFilter(
                        from: date,
                        to: _dateRange?.to,
                      );
                    });
                  }
                },
              ),
              _buildAnimatedDateTile(
                icon: Icons.date_range,
                title: 'Bitiş Tarihi',
                subtitle: _dateRange?.to != null
                    ? DateFormat('dd.MM.yyyy').format(_dateRange!.to!)
                    : 'Seçiniz',
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateRange?.to ?? DateTime.now(),
                    firstDate: _dateRange?.from ?? DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _dateRange = DateRangeFilter(
                        from: _dateRange?.from,
                        to: date,
                      );
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDateTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hoverColor: AppTheme.primaryBlue.withOpacity(0.1),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedFilterChip(FilterOption option) {
    final isSelected = _activeFilters.containsKey(option.value);
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? _scaleAnimation.value : 1.0,
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: Curves.easeInOut,
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.icon != null) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        option.icon,
                        size: 16,
                        key: ValueKey(isSelected),
                        color: isSelected ? Colors.white : option.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(option.label),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => _toggleFilter(option.value),
              backgroundColor: Colors.grey[100],
              selectedColor: option.color ?? AppTheme.primaryBlue,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected 
                    ? (option.color ?? AppTheme.primaryBlue)
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSearchField() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          key: const ValueKey('clear'),
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {});
                _applyFilters();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null) ...[
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        widget.title!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Arama çubuğu
                if (widget.showSearch) ...[
                  _buildAnimatedSearchField(),
                  const SizedBox(height: 16),
                ],
                
                // Filtre seçenekleri
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...widget.filterOptions.map((option) => 
                          _buildAnimatedFilterChip(option)),
                        
                        // Tarih aralığı butonu
                        if (widget.showDateRange)
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: FilterChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.date_range, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_dateRange != null
                                          ? 'Tarih: ${DateFormat('dd.MM').format(_dateRange!.from!)} - ${DateFormat('dd.MM').format(_dateRange!.to!)}'
                                          : 'Tarih Aralığı'),
                                    ],
                                  ),
                                  selected: _dateRange != null,
                                  onSelected: (_) => _showDateRangePicker(),
                                  backgroundColor: Colors.grey[100],
                                  selectedColor: AppTheme.accentOrange,
                                  checkmarkColor: Colors.white,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Aktif filtreler ve temizle butonu
                if (_activeFilters.isNotEmpty || _dateRange != null || _searchController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              children: [
                                if (_searchController.text.isNotEmpty)
                                  AnimatedContainer(
                                    duration: widget.animationDuration,
                                    child: Chip(
                                      label: Text('Arama: ${_searchController.text}'),
                                      onDeleted: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                if (_dateRange != null)
                                  AnimatedContainer(
                                    duration: widget.animationDuration,
                                    child: Chip(
                                      label: Text('Tarih: ${DateFormat('dd.MM').format(_dateRange!.from!)} - ${DateFormat('dd.MM').format(_dateRange!.to!)}'),
                                      onDeleted: () {
                                        setState(() {
                                          _dateRange = null;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ..._activeFilters.keys.map((key) {
                                  final option = widget.filterOptions.firstWhere(
                                    (opt) => opt.value == key,
                                    orElse: () => FilterOption(value: key, label: key),
                                  );
                                  return AnimatedContainer(
                                    duration: widget.animationDuration,
                                    child: Chip(
                                      label: Text(option.label),
                                      onDeleted: () => _toggleFilter(key),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: TextButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Temizle'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.accentOrange,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
