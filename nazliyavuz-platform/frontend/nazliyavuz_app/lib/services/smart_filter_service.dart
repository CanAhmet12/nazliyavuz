import 'dart:async';
import 'package:flutter/foundation.dart';
import 'filter_cache_service.dart';

/// Akıllı filtre önerileri servisi
class SmartFilterService {
  static final SmartFilterService _instance = SmartFilterService._internal();
  factory SmartFilterService() => _instance;
  SmartFilterService._internal();

  final FilterCacheService _cacheService = FilterCacheService();
  final Map<String, int> _filterUsageCount = {};
  final Map<String, List<String>> _filterCombinations = {};

  /// Kullanıcının filtre geçmişini analiz et
  Future<List<Map<String, dynamic>>> getSmartSuggestions({
    required String context,
    required List<String> availableFilters,
    int maxSuggestions = 5,
  }) async {
    try {
      final savedFilters = await _cacheService.getSavedFilters();
      final contextFilters = savedFilters
          .where((filter) => filter['context'] == context)
          .toList();

      // Kullanım sıklığına göre sırala
      contextFilters.sort((a, b) {
        final aCount = _filterUsageCount[a['name']] ?? 0;
        final bCount = _filterUsageCount[b['name']] ?? 0;
        return bCount.compareTo(aCount);
      });

      // Son kullanılan filtreleri öncelikle
      final recentFilters = contextFilters.take(3).toList();
      
      // Popüler kombinasyonları öner
      final popularCombinations = _getPopularCombinations(context);
      
      // Akıllı öneriler oluştur
      final suggestions = <Map<String, dynamic>>[];
      
      // Son kullanılan filtreler
      for (final filter in recentFilters) {
        if (suggestions.length < maxSuggestions) {
          suggestions.add({
            'type': 'recent',
            'name': filter['name'],
            'filters': filter['filters'],
            'icon': 'history',
            'description': 'Son kullanılan filtre',
            'priority': 1,
          });
        }
      }
      
      // Popüler kombinasyonlar
      for (final combination in popularCombinations) {
        if (suggestions.length < maxSuggestions) {
          suggestions.add({
            'type': 'popular',
            'name': combination['name'],
            'filters': combination['filters'],
            'icon': 'trending_up',
            'description': 'Popüler kombinasyon',
            'priority': 2,
          });
        }
      }
      
      // Akıllı öneriler
      final smartSuggestions = _generateSmartSuggestions(
        availableFilters,
        context,
      );
      
      for (final suggestion in smartSuggestions) {
        if (suggestions.length < maxSuggestions) {
          suggestions.add({
            'type': 'smart',
            'name': suggestion['name'],
            'filters': suggestion['filters'],
            'icon': 'lightbulb',
            'description': suggestion['description'],
            'priority': 3,
          });
        }
      }
      
      return suggestions;
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [SMART_FILTER] Error getting smart suggestions: $e');
      }
      return [];
    }
  }

  /// Popüler filtre kombinasyonlarını getir
  List<Map<String, dynamic>> _getPopularCombinations(String context) {
    final combinations = <Map<String, dynamic>>[];
    
    // Context'e göre popüler kombinasyonlar
    switch (context) {
      case 'teachers':
        combinations.addAll([
          {
            'name': 'Yüksek Puanlı Eğitimciler',
            'filters': {'min_rating': 4.5, 'sort_by': 'rating'},
          },
          {
            'name': 'Online Eğitimciler',
            'filters': {'online_only': true, 'sort_by': 'availability'},
          },
          {
            'name': 'Uygun Fiyatlı',
            'filters': {'max_price': 100, 'sort_by': 'price'},
          },
        ]);
        break;
      case 'reservations':
        combinations.addAll([
          {
            'name': 'Bu Hafta',
            'filters': {'date_from': DateTime.now().toIso8601String()},
          },
          {
            'name': 'Bekleyen Rezervasyonlar',
            'filters': {'status': 'pending'},
          },
          {
            'name': 'Tamamlanan',
            'filters': {'status': 'completed'},
          },
        ]);
        break;
      case 'assignments':
        combinations.addAll([
          {
            'name': 'Son Teslim Tarihi',
            'filters': {'sort_by': 'due_date', 'status': 'pending'},
          },
          {
            'name': 'Yüksek Puanlı',
            'filters': {'min_grade': 80, 'status': 'graded'},
          },
          {
            'name': 'Geciken Ödevler',
            'filters': {'status': 'overdue'},
          },
        ]);
        break;
    }
    
    return combinations;
  }

  /// Akıllı öneriler oluştur
  List<Map<String, dynamic>> _generateSmartSuggestions(
    List<String> availableFilters,
    String context,
  ) {
    final suggestions = <Map<String, dynamic>>[];
    
    // Zaman bazlı öneriler
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final thisWeek = today.add(const Duration(days: 7));
    
    if (availableFilters.contains('date_from')) {
      suggestions.add({
        'name': 'Bugün',
        'filters': {'date_from': today.toIso8601String()},
        'description': 'Bugünkü kayıtları göster',
      });
      
      suggestions.add({
        'name': 'Bu Hafta',
        'filters': {
          'date_from': today.toIso8601String(),
          'date_to': thisWeek.toIso8601String(),
        },
        'description': 'Bu haftaki kayıtları göster',
      });
    }
    
    // Durum bazlı öneriler
    if (availableFilters.contains('status')) {
      switch (context) {
        case 'reservations':
          suggestions.add({
            'name': 'Acil İşlem Gereken',
            'filters': {'status': 'pending'},
            'description': 'Bekleyen rezervasyonlar',
          });
          break;
        case 'assignments':
          suggestions.add({
            'name': 'Geciken Ödevler',
            'filters': {'status': 'overdue'},
            'description': 'Teslim tarihi geçen ödevler',
          });
          break;
      }
    }
    
    // Performans bazlı öneriler
    if (availableFilters.contains('rating')) {
      suggestions.add({
        'name': 'En İyi Performans',
        'filters': {'min_rating': 4.8, 'sort_by': 'rating'},
        'description': 'En yüksek puanlı kayıtlar',
      });
    }
    
    return suggestions;
  }

  /// Filtre kullanımını kaydet
  void recordFilterUsage(String filterName, Map<String, dynamic> filters) {
    _filterUsageCount[filterName] = (_filterUsageCount[filterName] ?? 0) + 1;
    
    // Kombinasyon analizi
    final filterKeys = filters.keys.toList()..sort();
    final combinationKey = filterKeys.join('+');
    
    if (_filterCombinations.containsKey(combinationKey)) {
      _filterCombinations[combinationKey]!.add(filterName);
    } else {
      _filterCombinations[combinationKey] = [filterName];
    }
    
    if (kDebugMode) {
      print('📊 [SMART_FILTER] Recorded usage for: $filterName');
    }
  }

  /// Filtre geçmişini temizle
  Future<void> clearFilterHistory() async {
    _filterUsageCount.clear();
    _filterCombinations.clear();
    
    if (kDebugMode) {
      print('🧹 [SMART_FILTER] Filter history cleared');
    }
  }

  /// Filtre istatistikleri
  Map<String, dynamic> getFilterStats() {
    return {
      'total_filters_used': _filterUsageCount.length,
      'total_combinations': _filterCombinations.length,
      'most_used_filter': _getMostUsedFilter(),
      'most_popular_combination': _getMostPopularCombination(),
    };
  }

  String? _getMostUsedFilter() {
    if (_filterUsageCount.isEmpty) return null;
    
    return _filterUsageCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? _getMostPopularCombination() {
    if (_filterCombinations.isEmpty) return null;
    
    return _filterCombinations.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b)
        .key;
  }

  /// Context'e özel öneriler
  Future<List<Map<String, dynamic>>> getContextualSuggestions(
    String context,
    Map<String, dynamic> currentFilters,
  ) async {
    final suggestions = <Map<String, dynamic>>[];
    
    switch (context) {
      case 'teachers':
        if (currentFilters.containsKey('category')) {
          suggestions.add({
            'name': 'Bu Kategoride Online',
            'filters': {
              ...currentFilters,
              'online_only': true,
            },
            'description': 'Seçili kategoride online eğitimciler',
          });
        }
        
        if (currentFilters.containsKey('min_rating')) {
          suggestions.add({
            'name': 'Daha Yüksek Puan',
            'filters': {
              ...currentFilters,
              'min_rating': (currentFilters['min_rating'] as num) + 0.5,
            },
            'description': 'Daha yüksek puanlı eğitimciler',
          });
        }
        break;
        
      case 'reservations':
        if (currentFilters.containsKey('status') && 
            currentFilters['status'] == 'pending') {
          suggestions.add({
            'name': 'Bu Hafta Bekleyen',
            'filters': {
              ...currentFilters,
              'date_from': DateTime.now().toIso8601String(),
              'date_to': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            },
            'description': 'Bu haftaki bekleyen rezervasyonlar',
          });
        }
        break;
        
      case 'assignments':
        if (currentFilters.containsKey('status') && 
            currentFilters['status'] == 'pending') {
          suggestions.add({
            'name': 'Yaklaşan Teslim',
            'filters': {
              ...currentFilters,
              'sort_by': 'due_date',
            },
            'description': 'Teslim tarihine göre sırala',
          });
        }
        break;
    }
    
    return suggestions;
  }
}
