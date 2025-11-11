import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Filtre seçeneği modeli
class FilterOption {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const FilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

/// Tarih aralığı filtresi
class DateRangeFilter {
  final DateTime? from;
  final DateTime? to;

  const DateRangeFilter({this.from, this.to});
}

/// Birleşik filtre widget'ı
class UnifiedFilterWidget extends StatefulWidget {
  final List<FilterOption> filterOptions;
  final Function(Map<String, dynamic>) onFilterChanged;
  final VoidCallback? onClearFilters;
  final String? title;
  final bool showDateRange;
  final bool showSearch;
  final String? searchHint;
  final Map<String, dynamic>? initialFilters;

  const UnifiedFilterWidget({
    super.key,
    required this.filterOptions,
    required this.onFilterChanged,
    this.onClearFilters,
    this.title,
    this.showDateRange = false,
    this.showSearch = false,
    this.searchHint,
    this.initialFilters,
  });

  @override
  State<UnifiedFilterWidget> createState() => _UnifiedFilterWidgetState();
}

class _UnifiedFilterWidgetState extends State<UnifiedFilterWidget> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, dynamic> _activeFilters = {};
  DateRangeFilter? _dateRange;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      _activeFilters.addAll(widget.initialFilters!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    setState(() {
      _activeFilters.clear();
      _dateRange = null;
      _searchController.clear();
    });
    widget.onClearFilters?.call();
    _applyFilters();
  }

  void _toggleFilter(String value) {
    setState(() {
      if (_activeFilters.containsKey(value)) {
        _activeFilters.remove(value);
      } else {
        _activeFilters[value] = true;
      }
    });
    _applyFilters();
  }

  void _showDateRangePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            _buildDateRangeSelector(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
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
                ),
                const SizedBox(width: 16),
                Expanded(
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: const Text('Başlangıç Tarihi'),
          subtitle: Text(_dateRange?.from != null
              ? DateFormat('dd.MM.yyyy').format(_dateRange!.from!)
              : 'Seçiniz'),
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
        ListTile(
          leading: const Icon(Icons.date_range),
          title: const Text('Bitiş Tarihi'),
          subtitle: Text(_dateRange?.to != null
              ? DateFormat('dd.MM.yyyy').format(_dateRange!.to!)
              : 'Seçiniz'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Arama çubuğu
          if (widget.showSearch) ...[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
              onChanged: (value) => _applyFilters(),
            ),
            const SizedBox(height: 16),
          ],
          
          // Filtre seçenekleri
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.filterOptions.map((option) {
                final isSelected = _activeFilters.containsKey(option.value);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.icon != null) ...[
                        Icon(
                          option.icon,
                          size: 16,
                          color: isSelected ? Colors.white : option.color,
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
                  ),
                );
              }),
              
              // Tarih aralığı butonu
              if (widget.showDateRange)
                FilterChip(
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
            ],
          ),
          
          // Aktif filtreler ve temizle butonu
          if (_activeFilters.isNotEmpty || _dateRange != null || _searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        Chip(
                          label: Text('Arama: ${_searchController.text}'),
                          onDeleted: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        ),
                      if (_dateRange != null)
                        Chip(
                          label: Text('Tarih: ${DateFormat('dd.MM').format(_dateRange!.from!)} - ${DateFormat('dd.MM').format(_dateRange!.to!)}'),
                          onDeleted: () {
                            setState(() {
                              _dateRange = null;
                            });
                            _applyFilters();
                          },
                        ),
                      ..._activeFilters.keys.map((key) {
                        final option = widget.filterOptions.firstWhere(
                          (opt) => opt.value == key,
                          orElse: () => FilterOption(value: key, label: key),
                        );
                        return Chip(
                          label: Text(option.label),
                          onDeleted: () => _toggleFilter(key),
                        );
                      }),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Temizle'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
