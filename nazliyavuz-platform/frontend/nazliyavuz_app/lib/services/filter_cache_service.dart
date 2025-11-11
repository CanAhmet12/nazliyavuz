import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Filtre cache servisi
class FilterCacheService {
  static const String _cachePrefix = 'filter_cache_';
  static const String _userFiltersKey = 'user_saved_filters';
  static const Duration _defaultCacheTimeout = Duration(hours: 1);
  
  static final FilterCacheService _instance = FilterCacheService._internal();
  factory FilterCacheService() => _instance;
  FilterCacheService._internal();

  /// Cache'den filtre sonuçlarını getir
  Future<Map<String, dynamic>?> getCachedResults(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_cachePrefix$cacheKey');
      
      if (cachedData != null) {
        final data = jsonDecode(cachedData) as Map<String, dynamic>;
        final timestamp = DateTime.parse(data['timestamp'] as String);
        
        // Cache timeout kontrolü
        if (DateTime.now().difference(timestamp) < _defaultCacheTimeout) {
          if (kDebugMode) {
            print('🎯 [FILTER_CACHE] Cache hit for key: $cacheKey');
          }
          return data['results'] as Map<String, dynamic>;
        } else {
          // Expired cache'i temizle
          await _removeCachedResults(cacheKey);
        }
      }
      
      if (kDebugMode) {
        print('❌ [FILTER_CACHE] Cache miss for key: $cacheKey');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error getting cached results: $e');
      }
      return null;
    }
  }

  /// Filtre sonuçlarını cache'e kaydet
  Future<void> cacheResults(String cacheKey, Map<String, dynamic> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'results': results,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('$_cachePrefix$cacheKey', jsonEncode(cacheData));
      
      if (kDebugMode) {
        print('✅ [FILTER_CACHE] Results cached for key: $cacheKey');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error caching results: $e');
      }
    }
  }

  /// Cache'den sonuçları kaldır
  Future<void> _removeCachedResults(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$cacheKey');
      
      if (kDebugMode) {
        print('🗑️ [FILTER_CACHE] Removed expired cache for key: $cacheKey');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error removing cached results: $e');
      }
    }
  }

  /// Kullanıcının kayıtlı filtrelerini getir
  Future<List<Map<String, dynamic>>> getSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFiltersJson = prefs.getString(_userFiltersKey);
      
      if (savedFiltersJson != null) {
        final List<dynamic> savedFilters = jsonDecode(savedFiltersJson);
        return savedFilters.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error getting saved filters: $e');
      }
      return [];
    }
  }

  /// Kullanıcının filtrelerini kaydet
  Future<void> saveFilter(String name, Map<String, dynamic> filters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilters = await getSavedFilters();
      
      final newFilter = {
        'name': name,
        'filters': filters,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      savedFilters.add(newFilter);
      
      // Maksimum 10 kayıtlı filtre
      if (savedFilters.length > 10) {
        savedFilters.removeAt(0);
      }
      
      await prefs.setString(_userFiltersKey, jsonEncode(savedFilters));
      
      if (kDebugMode) {
        print('✅ [FILTER_CACHE] Filter saved: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error saving filter: $e');
      }
    }
  }

  /// Kayıtlı filtreyi sil
  Future<void> deleteSavedFilter(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilters = await getSavedFilters();
      
      savedFilters.removeWhere((filter) => filter['name'] == name);
      
      await prefs.setString(_userFiltersKey, jsonEncode(savedFilters));
      
      if (kDebugMode) {
        print('🗑️ [FILTER_CACHE] Filter deleted: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error deleting filter: $e');
      }
    }
  }

  /// Tüm cache'i temizle
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
      
      if (kDebugMode) {
        print('🧹 [FILTER_CACHE] All cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error clearing cache: $e');
      }
    }
  }

  /// Cache istatistikleri
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int cacheCount = 0;
      int totalSize = 0;
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          cacheCount++;
          final value = prefs.getString(key);
          if (value != null) {
            totalSize += value.length;
          }
        }
      }
      
      return {
        'cache_count': cacheCount,
        'total_size_bytes': totalSize,
        'total_size_kb': (totalSize / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [FILTER_CACHE] Error getting cache stats: $e');
      }
      return {
        'cache_count': 0,
        'total_size_bytes': 0,
        'total_size_kb': '0.00',
      };
    }
  }

  /// Cache key oluştur
  String generateCacheKey(String baseKey, Map<String, dynamic> filters) {
    final sortedFilters = Map.fromEntries(
      filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    final filterString = sortedFilters.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    
    return '${baseKey}_${filterString.hashCode}';
  }

  /// Debounced search için timer
  Timer? _searchTimer;
  
  void debouncedSearch(
    String query,
    Duration delay,
    Function(String) onSearch,
  ) {
    _searchTimer?.cancel();
    _searchTimer = Timer(delay, () {
      onSearch(query);
    });
  }
  
  void cancelDebouncedSearch() {
    _searchTimer?.cancel();
  }
}
